"""Check that games saved by an older revision still load with this one (the save-compatibility CI job).

    python tools/save_compat.py write <checkout> <out>    play and save three games with the hexa package of
                                                          <checkout> (the merge base, say), into the folder <out>
    python tools/save_compat.py check <out>               load them with this checkout's hexa and play a season each
    python tools/save_compat.py check <out> --checkout <dir>     the same with the hexa package of another tree

To run it locally against master (any revision works; the worktree needs no tools/ folder of its own):

    git worktree add --detach /tmp/hexa-base master
    python tools/save_compat.py write /tmp/hexa-base /tmp/hexa-compat
    python tools/save_compat.py check /tmp/hexa-compat
    git worktree remove --force /tmp/hexa-base

``python -m tools.save_compat ...`` from the repository root works too. Run each command in a fresh interpreter:
write puts <checkout> first on sys.path before it imports hexa, so the saves are made by that revision's own world,
AI and save code, and it prints hexa.__file__ and stops if hexa came from anywhere else. Nothing else from
<checkout> is used (it may predate tools/ and tests/).

The saves (game save files in <out>/saves/, written by the checkout's saves.save under HEXA_HOME=<out>, plus
<out>/manifest.json with the checkout's saves.VERSION, its hexa.__file__ and git revision, and what was saved):

    1       Europe 1480 as Portugal, after 3 seasons
    2       a random world (seed 7) as its largest country, after 2 seasons
    quick   the quicksave of a war: Portugal declares war on Castile, 4 seasons later (sieges and occupations)

In every season the AI moves every country, the player's own too, then the world ends the round (as
CampaignApp.end_turn does for the countries it doesn't leave to the player).

check reads the manifest and compares the saves' saves.VERSION with this checkout's:

    unchanged   every save must load (meta() and load() return it), pass the world invariants of the checkout's
                tests/support/invariants.py when it has one (known open bugs are only noted), and play one more
                season. A save that is refused or breaks is an incompatible change without a VERSION bump.
    changed     loading must never raise or crash. A save may be refused quietly (load() returns None); one that is
                still read (saves.load reads every version from 1 to VERSION and CampaignWorld._migrate fills in
                what older ones lack) must play a season like an unchanged one.

Exit status: 0 compatible; 1 a save broke (the report names the save file, the step that failed and the exception,
and says how to fix it); 2 usage error (bad arguments, no hexa package in the checkout, hexa already imported from
elsewhere, no manifest: run write first); 3 write only: the checkout's code could not make the saves (an exception in
that revision, or an API this tool uses is gone). check appends a markdown table to $GITHUB_STEP_SUMMARY when that is
set. No pygame needed.
"""
import argparse
import contextlib
import io
import json
import os
import platform
import subprocess
import sys
import time
import traceback

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))     # the checkout this tool belongs to
MANIFEST = "manifest.json"
MANIFEST_FORMAT = 1
PLAYER = "POR"                # Europe saves: Portugal
EUROPE_SEASONS = 3
RANDOM_SEED = 7
RANDOM_SEASONS = 2
ENEMY = "CAS"                 # the quicksave's war: Portugal against Castile (or another neighbour)
WAR_SEASONS = 4
SHOWN_FRAMES = 6              # innermost traceback frames shown for a failure
SHOWN_PROBLEMS = 8            # broken invariants listed for a failure

OK, BROKEN, USAGE, WRITE_FAILED = 0, 1, 2, 3


class Usage(Exception):
    """Bad arguments or a missing input: exit status 2."""


def say(line=""):
    print(line, flush=True)


# ----- importing hexa from a given checkout -------------------------------------------------------------------------
def _under(path, folder):
    return os.path.realpath(path).startswith(os.path.join(os.path.realpath(folder), ""))


def import_hexa(checkout):
    """Import the hexa package of checkout (put first on sys.path) and return the path of its __init__.py.

    Raises Usage if checkout has no hexa package, or if hexa is already imported from somewhere else (a second
    import in the same interpreter would get the cached package: run the tool in a fresh interpreter)."""
    checkout = os.path.realpath(checkout)
    if not os.path.isfile(os.path.join(checkout, "hexa", "__init__.py")):
        raise Usage(f"{checkout} has no hexa package (hexa/__init__.py)")
    if "hexa" not in sys.modules:
        sys.path.insert(0, checkout)
    import hexa
    where = os.path.realpath(hexa.__file__)
    if not _under(where, checkout):
        raise Usage(f"hexa was imported from {where}, not from {checkout}; run the tool in a fresh interpreter "
                    f"(python tools/save_compat.py ...)")
    return where


def _campaign(checkout):
    """The checkout's campaign modules (ai, saves, world), each checked to come from checkout."""
    from hexa.campaign import ai, saves, world
    for module in (ai, saves, world):
        if not _under(module.__file__, checkout):
            raise Usage(f"{module.__name__} was imported from {module.__file__}, not from {checkout}")
    return ai, saves, world


def _revision(checkout):
    """The checkout's git commit (short), or None when git can't tell."""
    try:
        done = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=checkout, capture_output=True, text=True,
                              timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None
    if done.returncode != 0:
        return None
    return done.stdout.strip() or None


# ----- the games --------------------------------------------------------------------------------------------------
def season(world, ai):
    """One season: the AI moves every country (the player's too), then the world ends the round."""
    for tag in list(world.countries):
        ai.run(world, tag)
    world.end_round()


def _europe(world_module, ai):
    world = world_module.CampaignWorld(player=PLAYER)
    for _ in range(EUROPE_SEASONS):
        season(world, ai)
    return "1", f"Europe 1480 as {PLAYER}, after {EUROPE_SEASONS} seasons", world, {}


def _random(world_module, ai):
    built = world_module.CampaignWorld(RANDOM_SEED, map="random")
    tag = max(sorted(built.countries), key=lambda t: sum(1 for p in built.provinces.values() if p.owner == t))
    world = world_module.CampaignWorld(RANDOM_SEED, player=tag, map="random")
    for _ in range(RANDOM_SEASONS):
        season(world, ai)
    return "2", f"random world seed {RANDOM_SEED} as {tag}, after {RANDOM_SEASONS} seasons", world, {}


def _war(world_module, ai):
    world = world_module.CampaignWorld(player=PLAYER)
    enemies = [ENEMY] + sorted(world.countries)
    enemy = next((t for t in enemies if world.war_check(PLAYER, t)[0]), None)
    if enemy is None or not world.declare_war(PLAYER, enemy):
        raise RuntimeError(f"{PLAYER} can't declare war on anyone")
    for _ in range(WAR_SEASONS):
        season(world, ai)
    at_war = world.at_war(PLAYER, enemy)
    occupied = sum(1 for p in world.provinces.values() if p.owner is not None and p.controller != p.owner)
    what = f"quicksave, {PLAYER} at war with {enemy} for {WAR_SEASONS} seasons"
    return "quick", what, world, {"enemy": enemy, "at_war": at_war, "occupied": occupied}


GAMES = (_europe, _random, _war)


# ----- write --------------------------------------------------------------------------------------------------------
def write(checkout, out):
    """Play and save the games with the checkout's code; returns the exit status."""
    checkout, out = os.path.realpath(checkout), os.path.abspath(out)
    manifest_path = os.path.join(out, MANIFEST)
    os.makedirs(out, exist_ok=True)
    if os.path.exists(manifest_path):
        os.remove(manifest_path)               # a failed write leaves no manifest for check to trust
    os.environ["HEXA_HOME"] = out              # saves.folder() is <out>/saves
    try:
        where = import_hexa(checkout)
        say(f"write: hexa from {where}")
        ai, saves, world_module = _campaign(checkout)
    except Usage:
        raise
    except Exception as error:                 # noqa: BLE001 - the checkout's code is reported, not trusted
        _report_failure("write", "importing the checkout's hexa.campaign", error, checkout)
        return WRITE_FAILED
    version = getattr(saves, "VERSION", None)
    if not isinstance(version, int):
        say(f"write: FAILED: {saves.__file__} has no integer VERSION")
        return WRITE_FAILED
    say(f"write: saves.VERSION {version}, saving into {saves.folder()}")
    written = []
    for game in GAMES:
        started = time.perf_counter()
        try:
            slot, what, world, extra = game(world_module, ai)
            meta = saves.save(world, slot)
        except Exception as error:             # noqa: BLE001
            _report_failure("write", f"playing or saving the {game.__name__.strip('_')} game", error, checkout)
            return WRITE_FAILED
        seconds = time.perf_counter() - started
        path = saves.path(slot)
        entry = {"slot": slot, "file": os.path.relpath(path, out), "what": what, "map": getattr(world, "map", None),
                 "seed": getattr(world, "seed", None), "tag": world.player, "turn": world.turn, "date": world.date(),
                 "header_version": meta.get("version") if isinstance(meta, dict) else None,
                 "bytes": os.path.getsize(path), "seconds": round(seconds, 2)}
        entry.update(extra)
        written.append(entry)
        note = "" if extra.get("at_war", True) else " (the war ended before the quicksave)"
        say(f"write: {entry['file']}  {what}: {entry['date']} (turn {entry['turn']}), "
            f"{entry['bytes'] / 1e6:.1f} MB, {seconds:.1f} s{note}")
    manifest = {"format": MANIFEST_FORMAT, "version": version, "hexa": where, "checkout": checkout,
                "revision": _revision(checkout), "python": platform.python_version(),
                "written": time.strftime("%Y-%m-%d %H:%M:%S"), "saves": written}
    with open(manifest_path + ".tmp", "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    os.replace(manifest_path + ".tmp", manifest_path)
    say(f"write: {len(written)} saves and {MANIFEST} in {out}")
    return OK


def _report_failure(command, step, error, checkout):
    say(f"{command}: FAILED while {step}: {type(error).__name__}: {error}")
    for line in _trace(error, checkout):
        say("    " + line)


def _short(filename, checkout):
    """A traceback's file name, relative to the checkout or to this tool's tree when it is in one."""
    for tree in (checkout, ROOT):
        if _under(filename, tree):
            return os.path.relpath(os.path.realpath(filename), os.path.realpath(tree))
    return filename


def _trace(error, checkout):
    """The innermost frames of the error's traceback, one line each: 'file:line in function: code'."""
    frames = traceback.extract_tb(error.__traceback__)[-SHOWN_FRAMES:]
    return [f"{_short(f.filename, checkout)}:{f.lineno} in {f.name}: {(f.line or '').strip()}" for f in frames]


def _where(error, checkout):
    """'hexa/campaign/world.py:2490 in end_round': the innermost frame of the error in the checkout's hexa."""
    hexa_dir = os.path.join(os.path.realpath(checkout), "hexa")
    for frame in reversed(traceback.extract_tb(error.__traceback__)):
        if _under(frame.filename, hexa_dir):
            return f"{_short(frame.filename, checkout)}:{frame.lineno} in {frame.name}"
    return None


# ----- check --------------------------------------------------------------------------------------------------------
class Result:
    """What check found for one save."""

    def __init__(self, entry):
        self.entry = entry
        self.ok = True
        self.outcome = ""             # one line: what happened
        self.details = []             # more lines for a failure (traceback, problems)
        self.notes = []               # things worth saying that don't fail (known open bugs)

    def fail(self, outcome, details=()):
        self.ok, self.outcome, self.details = False, outcome, list(details)
        return self

    def passed(self, outcome):
        self.outcome = outcome
        return self

    @property
    def name(self):
        return f"{self.entry['file']} ({self.entry['what']})"


def read_manifest(out):
    path = os.path.join(out, MANIFEST)
    try:
        with open(path, encoding="utf-8") as f:
            manifest = json.load(f)
    except FileNotFoundError:
        raise Usage(f"no {MANIFEST} in {out}: run 'python tools/save_compat.py write <checkout> {out}' first")
    except (OSError, ValueError) as error:
        raise Usage(f"{path} can't be read ({type(error).__name__}: {error}); run write again")
    saves = manifest.get("saves") if isinstance(manifest, dict) else None
    if not isinstance(manifest.get("version") if isinstance(manifest, dict) else None, int) or \
            not isinstance(saves, list) or not saves or \
            not all(isinstance(e, dict) and {"slot", "file", "what", "turn", "tag"} <= e.keys() for e in saves):
        raise Usage(f"{path} is not a manifest this tool wrote; run write again")
    for entry in saves:
        if not os.path.isfile(os.path.join(out, entry["file"])):
            raise Usage(f"{entry['file']} is listed in {path} but missing; run write again")
    return manifest


def _invariants(checkout):
    """The checkout's tests/support/invariants.py, or None when it has none (the checks are then skipped)."""
    if not os.path.isfile(os.path.join(checkout, "tests", "support", "invariants.py")):
        return None
    try:
        from tests.support import invariants
    except Exception:                          # noqa: BLE001 - optional
        return None
    if not _under(invariants.__file__, checkout) or not hasattr(invariants, "campaign_problems"):
        return None
    return invariants


def _problems(invariants, world):
    """(new, known): broken world invariants, split into new ones and those a known open bug explains."""
    if invariants is None:
        return [], []
    try:
        found = invariants.campaign_problems(world)
    except Exception as error:                 # noqa: BLE001 - a checker that crashes on the world is a problem too
        found = [f"checker: {type(error).__name__}: {error}"]
    known_open = getattr(invariants, "known_open", lambda mode, problem: None)
    known = [p for p in found if known_open("campaign", p)]
    return [p for p in found if p not in known], known


def check_save(entry, same, saves, ai, invariants, checkout):
    """Load one save with this code and play a season. Returns a Result."""
    result = Result(entry)
    slot = entry["slot"]
    said = io.StringIO()
    try:
        with contextlib.redirect_stderr(said):
            header = saves.meta(slot)
            world = saves.load(slot)
    except Exception as error:                 # noqa: BLE001
        return result.fail(f"saves.meta()/load() raised {type(error).__name__}: {error} instead of returning None "
                           f"({_where(error, checkout) or 'outside hexa'})", _trace(error, checkout))
    told = " ".join(said.getvalue().split())   # what load() printed (it says why it refused a save)
    if world is None:
        why = f": {told}" if told else (" (its header was refused)" if header is None else "")
        looked = os.path.abspath(saves.path(slot)) if hasattr(saves, "path") else None
        if looked and not os.path.exists(looked):
            why += f" (this code looks for it at {looked}, but it was written to {entry['file']})"
        if same:
            return result.fail(f"saves.load() refused it{why}")
        listed = "; the start menu still lists it" if header is not None else ""
        return result.passed(f"refused quietly{why}{listed}")
    if same and header is None:
        return result.fail("saves.load() read it but saves.meta() refused its header (the menus would not list it)")
    if world.turn != entry["turn"] or world.player != entry["tag"]:
        return result.fail(f"loaded turn {world.turn} as {world.player!r}, but turn {entry['turn']} as "
                           f"{entry['tag']!r} was saved")
    new, known = _problems(invariants, world)
    result.notes += [f"known open bug, after loading: {p}" for p in known]
    if new:
        return result.fail(f"the loaded world breaks {len(new)} invariant(s): {new[0]}", new[1:SHOWN_PROBLEMS])
    loaded, turn = world.date(), world.turn
    try:
        season(world, ai)
    except Exception as error:                 # noqa: BLE001
        where = _where(error, checkout)
        return result.fail(f"loaded {loaded}, then playing a season raised {type(error).__name__}: {error}"
                           + (f" (at {where})" if where else ""), _trace(error, checkout))
    if world.turn != turn + 1:
        return result.fail(f"a season took the loaded game from turn {turn} to {world.turn}")
    new, known = _problems(invariants, world)
    result.notes += [f"known open bug, after a season: {p}" for p in known]
    if new:
        return result.fail(f"after a season the world breaks {len(new)} invariant(s): {new[0]}", new[1:SHOWN_PROBLEMS])
    still = "" if same else "still read (older saves are migrated); "
    return result.passed(f"{still}loaded {loaded} and played to {world.date()}")


def advice(same, base, now):
    if same:
        return (f"saves.VERSION is still {now}, so players' saves from before this change must keep working. Either "
                f"keep them loading: give a new world attribute a default in WORLD_DEFAULTS (hexa/campaign/world.py), "
                f"give a new dataclass field a default, or read a lazily added attribute with getattr or "
                f"__dict__.setdefault; or, if old saves can't be supported, bump VERSION in hexa/campaign/saves.py "
                f"so that they are refused quietly (saves.load reads every version from 1 to VERSION, so it must "
                f"then refuse version {base} too).")
    return (f"saves.VERSION changed from {base} to {now}, but saves.load() still reads version-{base} saves, and "
            f"these fail after loading. Either migrate them (WORLD_DEFAULTS and dataclass field defaults in "
            f"hexa/campaign/world.py, CampaignWorld._migrate) or make saves.py refuse version {base} quietly.")


def check(out, checkout):
    """Load the saves in out with the checkout's code; returns the exit status."""
    out, checkout = os.path.abspath(out), os.path.realpath(checkout)
    manifest = read_manifest(out)
    os.environ["HEXA_HOME"] = out
    try:
        where = import_hexa(checkout)
        say(f"check: hexa from {where}")
        ai, saves, _ = _campaign(checkout)
    except Usage:
        raise
    except Exception as error:                 # noqa: BLE001 - a checkout whose hexa can't even be imported
        _report_failure("check", "importing this checkout's hexa.campaign", error, checkout)
        return BROKEN
    invariants = _invariants(checkout)
    base, now = manifest["version"], saves.VERSION
    same = base == now
    revision = manifest.get("revision") or "an unknown revision"
    rule = "unchanged: every save must load and play a season" if same else "changed: old saves may be refused quietly"
    say(f"check: saves written by {revision} with saves.VERSION {base}; this code has VERSION {now} ({rule})")
    say("check: world invariants " + (f"from {invariants.__file__}" if invariants else "not checked (no "
                                      "tests/support/invariants.py in the checkout)"))
    results = []
    for entry in manifest["saves"]:
        started = time.perf_counter()
        result = check_save(entry, same, saves, ai, invariants, checkout)
        results.append(result)
        say(f"check: {result.name}: {'ok' if result.ok else 'FAILED'}: {result.outcome} "
            f"({time.perf_counter() - started:.1f} s)")
        for line in result.details:
            say("    " + line)
        for line in result.notes:
            say("    note: " + line)
    failed = [r for r in results if not r.ok]
    say(f"check: {len(results) - len(failed)} of {len(results)} saves compatible")
    if failed:
        say("check: " + advice(same, base, now))
    _step_summary(results, revision, base, now, same)
    return BROKEN if failed else OK


def _step_summary(results, revision, base, now, same):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    failed = [r for r in results if not r.ok]
    verdict = f"**{len(failed)} of {len(results)} broke**" if failed else "**compatible**"
    lines = ["## Save compatibility", "",
             f"Saves written by `{revision}` (saves.VERSION {base}), loaded by this code (saves.VERSION {now}"
             f"{'' if same else ', changed'}): {verdict}", "",
             "| Save | Game | Result |", "|---|---|---|"]
    for r in results:
        outcome = r.outcome.replace("|", "\\|")
        lines.append(f"| `{r.entry['file']}` | {r.entry['what']} | {'ok' if r.ok else 'FAILED'}: {outcome} |")
    if failed:
        lines += ["", advice(same, base, now)]
    with open(path, "a", encoding="utf-8") as summary:
        summary.write("\n".join(lines) + "\n\n")


# ----- the command --------------------------------------------------------------------------------------------------
def _parser():
    parser = argparse.ArgumentParser(prog="python tools/save_compat.py",
                                     description="Write saves with one checkout's code and load them with another's.")
    commands = parser.add_subparsers(dest="command", required=True)
    w = commands.add_parser("write", help="play and save three games with the hexa package of CHECKOUT")
    w.add_argument("checkout", help="a source tree with a hexa package, e.g. a git worktree of the merge base")
    w.add_argument("out", help="the folder for the saves and manifest.json (created if needed)")
    c = commands.add_parser("check", help="load the saves in OUT with this checkout's hexa and play a season each")
    c.add_argument("out", help="the folder write filled")
    c.add_argument("--checkout", default=ROOT, help="the tree whose hexa loads the saves (default: the one this "
                                                    f"tool is in, {ROOT})")
    return parser


def main(argv=None):
    args = _parser().parse_args(argv)
    try:
        if args.command == "write":
            return write(args.checkout, args.out)
        return check(args.out, args.checkout)
    except Usage as error:
        print(f"{args.command}: {error}", file=sys.stderr)
        return USAGE


if __name__ == "__main__":
    sys.exit(main())
