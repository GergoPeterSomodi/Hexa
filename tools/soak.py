"""Long all-AI games with the world invariants checked after every turn: the nightly soak, and bug hunting.

    python -m tools.soak                          every suite at full scale (the nightly run, about 10 minutes)
    python -m tools.soak --quick                  every suite, a few short games (a smoke run, about 20 seconds)
    python -m tools.soak colony                   one suite at full scale
    python -m tools.soak colony 0-9 --turns 20    chosen seeds ("17", a range "0-49" or a list "3,8,12") and turns
    python -m tools.soak conquest 17              replay one game: the line a failure prints
    python -m tools.soak random 2 --digest        the end of the game's digest (the same seed plays the same game)

Suites (their full scale; --quick in brackets):
    conquest   Conquest, the AI against the AI to the end, seeds 0-199 (0-9)
    colony     Colonisation, every side played by the AI, seeds 0-49 x 40 rounds (0-2 x 10); the start (sea, land)
               and the goal (survive, independence, endless) vary with the seed
    europe     Age of Discovery on the 1480 map, every country played by the AI, seed 1480 x 100 seasons (x 8)
    random     Age of Discovery on random worlds, seeds 1-3 x 40 seasons (seed 1 x 4)

After every turn (Conquest and Colonisation: every side's turn; the campaign: every season) and at the start the world
must pass the checks of tests/support/invariants.py, and a Conquest game must have a winner by the turn limit. A game
fails on an exception or on a broken invariant that no known open bug explains; it stops there and prints its report,
which ends with the command that replays it. Broken invariants that a known open bug explains (invariants.KNOWN_OPEN)
are reported as "known open" and don't fail. The same seed always plays the same game.

Prints a line per game, then a summary table (also appended to $GITHUB_STEP_SUMMARY when that is set), and exits
with status 1 if any game failed. No pygame needed.
"""
import argparse
import os
import sys
import time
import traceback

from tests.support import invariants
from tests.support.monkey import parse_seeds

SHOWN_TRACE = 16            # traceback lines in a report
SHOWN_KNOWN = 5             # games listed per known open bug in the summary


class Suite:
    def __init__(self, name, mode, what, seeds, turns, quick_seeds, quick_turns, unit):
        self.name, self.mode, self.what = name, mode, what
        self.seeds, self.turns = seeds, turns
        self.quick_seeds, self.quick_turns = quick_seeds, quick_turns
        self.unit = unit                      # what a turn is called in this suite


SUITES = {s.name: s for s in (
    Suite("conquest", "conquest", "Conquest, AI against AI", range(0, 200), None, range(0, 10), None, "turns"),
    Suite("colony", "colony", "Colonisation, every side by the AI", range(0, 50), 40, range(0, 3), 10, "rounds"),
    Suite("europe", "campaign", "Age of Discovery, Europe 1480, every country by the AI", (1480,), 100, (1480,), 8,
          "seasons"),
    Suite("random", "campaign", "Age of Discovery, random worlds, every country by the AI", range(1, 4), 40, (1,), 4,
          "seasons"),
)}


class _Stop(Exception):
    """Raised by a check to end the game at its first new problem."""


# ----- one game ----------------------------------------------------------------------------------------------------
class Game:
    """What one game did and found.

    problems   {invariant: (when, text)} broken invariants no open bug explains (the first check that found any)
    known      {invariant: (when, text, bug)} broken invariants that invariants.KNOWN_OPEN explains, as first seen
    error      the exception the game raised (None), with trace (its traceback); now says where the game was
    """

    def __init__(self, suite, seed, turns):
        self.suite, self.seed, self.turns = suite, seed, turns
        self.mode = SUITES[suite].mode
        self.problems, self.known = {}, {}
        self.error, self.trace = None, ""
        self.now = "while setting up the game"    # where the game is: an exception is reported there
        self.checks = 0
        self.turn = None
        self.note = ""
        self.digest = None
        self.seconds = 0.0

    @property
    def failed(self):
        return self.error is not None or bool(self.problems)

    def watch(self, world, when):
        """Check the invariants now; a broken one that no open bug explains ends the game."""
        self.turn = getattr(world, "turn", None)
        try:
            found = getattr(invariants, f"{self.mode}_problems")(world)
        except Exception as error:                                          # noqa: BLE001 - reported as a problem
            found = [f"checker: {type(error).__name__}: {error}"]
        self.checks += 1
        new = False
        for text in found:
            name = text.split(":", 1)[0]
            bug = invariants.known_open(self.mode, text)
            if bug:
                self.known.setdefault(name, (when, text, bug))
            else:
                self.problems.setdefault(name, (when, text))
                new = True
        if new:
            raise _Stop

    def problem(self, when, text):
        """A game-level problem the invariants can't see (no winner by the turn limit)."""
        self.problems.setdefault(text.split(":", 1)[0], (when, text))
        raise _Stop

    def repro(self):
        return repro(self.suite, self.seed, self.turns)

    def summary(self):
        """One line: the result, how far the game got, how long it took."""
        if self.error is not None:
            state = f"FAILED {self.now}: {type(self.error).__name__}: {self.error}"
        elif self.problems:
            first = next(iter(self.problems.values()))
            state = f"FAILED {first[0]}: {first[1]}" + (f" (+{len(self.problems) - 1} more)"
                                                       if len(self.problems) > 1 else "")
        else:
            state = "ok"
        extra = f", {len(self.known)} known open" if self.known else ""
        note = f"{self.note}, " if self.note else ""
        return (f"{self.suite} seed {self.seed}: {state} ({note}{self.checks} checks{extra}, "
                f"{self.seconds:.1f} s)")

    def report(self):
        """Everything about the game, ending with the command that replays it."""
        unit = SUITES[self.suite].unit
        length = f", {self.turns} {unit}" if self.turns is not None else ", to the end"
        lines = [f"{SUITES[self.suite].what}, seed {self.seed}{length}: {'FAILED' if self.failed else 'passed'} "
                 f"({self.checks} checks)"]
        if self.error is not None:
            lines.append(f"  {type(self.error).__name__} {self.now}: {self.error}")
            lines.extend("    " + line for line in self.trace.rstrip().splitlines()[-SHOWN_TRACE:])
        if self.problems:
            lines.append("  broken invariants (when: problem):")
            lines.extend(f"    {when}: {text}" for when, text in self.problems.values())
        if self.known:
            lines.append("  known open bugs seen (tolerated, see invariants.KNOWN_OPEN):")
            lines.extend(f"    {when}: {text}  [{bug}]" for when, text, bug in self.known.values())
        lines.append(f"Replay: {self.repro()}")
        return "\n".join(lines)


def repro(suite, seed, turns):
    """The command that plays this game again."""
    default = SUITES[suite].turns
    return f"python -m tools.soak {suite} {seed}" + (f" --turns {turns}" if turns != default else "")


def play_game(suite, seed, turns=None, digest=False):
    """Play one game of a suite (turns: None for the suite's full length) and return its Game."""
    turns = SUITES[suite].turns if turns is None else turns
    game = Game(suite, seed, turns)
    started = time.perf_counter()
    world = None
    try:
        world = _PLAY[SUITES[suite].mode](game, seed, turns, suite)
    except _Stop:
        pass
    except Exception as error:                                              # noqa: BLE001 - reported as a failure
        game.error, game.trace = error, traceback.format_exc()
    game.seconds = time.perf_counter() - started
    if digest and world is not None and not game.failed:
        from tests.support.digests import world_digest
        game.digest = world_digest(world)
    return game


def _conquest(game, seed, turns, suite):
    from hexa.rules import TURN_LIMIT
    from hexa.world import World
    from tests.support.games import play_conquest
    world = World(seed)
    ends = [0]

    def after_turn(w):
        ends[0] += 1
        game.watch(w, f"on turn {w.turn}, before {w.current}'s move")
        if not w.winner and ends[0] > 2 * TURN_LIMIT:
            game.problem(f"on turn {w.turn}", f"winner: nobody has won after turn {TURN_LIMIT}")
        game.now = f"in {w.current}'s move on turn {w.turn}"

    game.watch(world, "at the start")
    game.now = f"in {world.current}'s move on turn {world.turn}"
    play_conquest(world, after_turn)
    game.note = f"{world.winner} won on turn {world.turn}"
    return world


def _colony(game, seed, turns, suite):
    from hexa.colony.rules import GOAL_ENDLESS, GOAL_INDEPENDENCE, GOAL_SURVIVE, START_LAND, START_SEA
    from hexa.colony.world import ColonyWorld
    from tests.support.games import play_colony
    start = (START_SEA, START_LAND)[seed % 2]
    goal = (GOAL_SURVIVE, GOAL_INDEPENDENCE, GOAL_ENDLESS)[seed // 2 % 3]
    game.note = f"{start} start, {goal}"
    world = ColonyWorld(seed, start, goal)

    def after_turn(w):
        game.watch(w, f"on turn {w.turn}, before {w.current}'s move")
        game.now = f"in {w.current}'s move on turn {w.turn}"

    game.watch(world, "at the start")
    game.now = f"in {world.current}'s move on turn {world.turn}"
    play_colony(world, turns, after_turn)
    game.note += f", turn {world.turn}" + (f", {world.winner} won" if world.winner else "")
    return world


def _campaign(game, seed, turns, suite):
    from hexa.campaign.data import date
    from hexa.campaign.world import CampaignWorld
    from tests.support.worlds import play_seasons
    world = CampaignWorld(seed, map="random") if suite == "random" else CampaignWorld(seed)
    game.watch(world, f"at the start ({world.date()})")
    for _ in range(turns):
        if world.over:
            break
        game.now = f"in {world.date()} (turn {world.turn})"
        play_seasons(world, 1)
        game.watch(world, f"after {date(world.turn - 1)} (turn {world.turn - 1})")
    alive = sum(c.alive for c in world.countries.values())
    game.note = f"until {world.date()}, {alive} countries alive, {len(world.units)} units, {len(world.wars)} wars"
    return world


_PLAY = {"conquest": _conquest, "colony": _colony, "campaign": _campaign}


# ----- many games ----------------------------------------------------------------------------------------------------
def plan(suite_names, seeds=None, turns=None, quick=False):
    """[(suite, [seeds], turns)] for these suites: the given seeds and turns, or the suite's (quick) defaults.
    Conquest games always play to the end (turns None)."""
    out = []
    for name in suite_names:
        suite = SUITES[name]
        chosen = seeds if seeds is not None else (suite.quick_seeds if quick else suite.seeds)
        if suite.turns is None:
            length = None
        else:
            length = turns if turns is not None else (suite.quick_turns if quick else suite.turns)
        out.append((name, list(chosen), length))
    return out


def say(line=""):
    print(line, flush=True)


def run(planned, out=say, digest=False):
    """Play every planned game, printing a line per game and each failure's report. Returns the Games."""
    games = []
    for suite, seeds, turns in planned:
        for seed in seeds:
            game = play_game(suite, seed, turns, digest=digest)
            games.append(game)
            out(game.summary())
            if game.digest:
                out(f"  world {game.digest}")
            if game.failed:
                out(game.report())
    return games


def summary_rows(games):
    """[(suite, games, failed, known open, checks, seconds)] in suite order."""
    rows = []
    for name in SUITES:
        mine = [g for g in games if g.suite == name]
        if mine:
            rows.append((name, len(mine), sum(g.failed for g in mine), sum(bool(g.known) for g in mine),
                         sum(g.checks for g in mine), sum(g.seconds for g in mine)))
    return rows


def known_seen(games):
    """{bug: [(suite, seed, when, text)]}: every known open bug the games ran into."""
    seen = {}
    for game in games:
        for when, text, bug in game.known.values():
            seen.setdefault(bug, []).append((game.suite, game.seed, when, text))
    return seen


def text_summary(games, seconds=None):
    header = ("suite", "games", "failed", "known open", "checks", "seconds")
    rows = [header] + [(s, str(n), str(f), str(k), str(c), f"{t:.1f}") for s, n, f, k, c, t in summary_rows(games)]
    widths = [max(len(row[i]) for row in rows) for i in range(len(header))]
    lines = ["  ".join(cell.ljust(w) if i == 0 else cell.rjust(w) for i, (cell, w) in enumerate(zip(row, widths)))
             for row in rows]
    for bug, where in known_seen(games).items():
        lines.append(f"known open: {bug}: {len(where)} game(s), e.g. "
                     + "; ".join(f"{s} seed {seed} {when}" for s, seed, when, _ in where[:SHOWN_KNOWN]))
    failed = [g for g in games if g.failed]
    took = f" in {seconds:.0f} s" if seconds is not None else ""
    lines.append(f"{len(games) - len(failed)} of {len(games)} games passed{took}")
    lines.extend(f"FAILED {g.suite} seed {g.seed}: Replay: {g.repro()}" for g in failed)
    return "\n".join(lines)


def markdown_summary(games):
    lines = ["## Soak (all-AI games, invariants checked every turn)", "",
             "| Suite | Games | Failed | Known open | Checks | Seconds |", "|---|--:|--:|--:|--:|--:|"]
    lines += [f"| {s} | {n} | {f} | {k} | {c} | {t:.1f} |" for s, n, f, k, c, t in summary_rows(games)]
    seen = known_seen(games)
    if seen:
        lines += ["", "Known open bugs seen (they don't fail the run):", ""]
        lines += [f"- {bug}: {len(where)} game(s), e.g. "
                  + "; ".join(f"`{s}` seed {seed} {when}" for s, seed, when, _ in where[:SHOWN_KNOWN])
                  for bug, where in seen.items()]
    failed = [g for g in games if g.failed]
    if failed:
        lines += ["", f"**{len(failed)} game(s) failed.** Replay each with:", "", "```"]
        lines += [f"{g.repro()}    # {g.summary()}" for g in failed]
        lines += ["```"]
    return "\n".join(lines) + "\n"


def write_step_summary(text, env=None):
    """Append to the GitHub Actions job summary when GITHUB_STEP_SUMMARY names one."""
    path = (os.environ if env is None else env).get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as summary:
            summary.write(text + "\n")


# ----- the command ---------------------------------------------------------------------------------------------------
def _parser():
    parser = argparse.ArgumentParser(prog="python -m tools.soak",
                                     description="Long all-AI games with the world invariants checked every turn.")
    parser.add_argument("suite", nargs="?", default="all", choices=tuple(SUITES) + ("all",),
                        help="which games to play (default: all)")
    parser.add_argument("seeds", nargs="?", help='a seed, a range ("0-49") or a list ("3,8,12")')
    parser.add_argument("--turns", type=int, help="Colonisation rounds or campaign seasons per game (Conquest always "
                                                  "plays to the end)")
    parser.add_argument("--quick", action="store_true", help="a few short games per suite (a smoke run)")
    parser.add_argument("--digest", action="store_true", help="print each game's world digest at the end")
    return parser


def main(argv=None, out=say):
    parser = _parser()
    args = parser.parse_args(argv)
    names = tuple(SUITES) if args.suite == "all" else (args.suite,)
    seeds = None
    if args.seeds is not None:
        if args.suite == "all":
            parser.error("give a suite with the seeds, e.g. python -m tools.soak conquest 17")
        try:
            seeds = parse_seeds(args.seeds, "seeds", count=False)
        except ValueError as error:
            parser.error(str(error))
    if args.turns is not None:
        if args.turns < 1:
            parser.error("--turns: at least 1")
        if args.suite == "conquest":
            parser.error("Conquest games always play to the end: --turns is for colony, europe and random")
    started = time.perf_counter()
    games = run(plan(names, seeds, args.turns, args.quick), out=out, digest=args.digest)
    out("")
    out(text_summary(games, time.perf_counter() - started))
    write_step_summary(markdown_summary(games))
    return 1 if any(g.failed for g in games) else 0


if __name__ == "__main__":
    sys.exit(main())
