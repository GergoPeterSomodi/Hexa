"""The behaviour oracle: does this checkout play exactly the same games as a base checkout? (refactor PRs)

    python tools/same_behaviour.py <base-checkout>
    python tools/same_behaviour.py <base-checkout> --only conquest      only the suites whose name has "conquest"
    python tools/same_behaviour.py <base-checkout> --quick              one season per suite (for the tests)

Plays fixed-seed games with the hexa package of this checkout and with that of <base-checkout> (tools/oracle_runner.py,
one fresh interpreter per suite and checkout: PYTHONHASHSEED=0, only that checkout's hexa on sys.path, its own
HEXA_HOME) and compares a digest of the whole game state after every season or round. A refactor changes no
behaviour, so every digest must be equal. Exit status:

    0  every suite and every step is identical
    1  BEHAVIOUR CHANGED: the digests differ (the report names the suite and the first step that differs), or
       ORACLE FAILED: a suite crashed or timed out in one of the checkouts, so nothing could be compared
    2  usage error (the base checkout has no hexa package, or the arguments are wrong)

The suites run in parallel, well under 30 s in all:

    campaign europe 1480    12 seasons of Europe 1480, every country by the AI
    campaign random 7       12 seasons of a random world, seed 7
    campaign random 11      the same with seed 11
    colony 5                30 rounds of Colonisation
    conquest 3              Conquest, played to the end
    midgame (turn 160)      prepared Europe: every country holds the techs of its age (new age, idea cards,
                            cartography), forced wars, 4 AI seasons, peace on every kind of terms, drilling,
                            refits, disbanding, 6 more seasons
    debt                    prepared Europe: half the countries lose their troops and own costly castles, all are
                            200,000 ducats in debt: desertion, disbanding, creditors seizing buildings

WHAT IT COVERS. The whole game state after each step: every public attribute of the world, its units, provinces,
countries, markets, wars, log and random generator. The generated map (roads, road_paths, rivers, river_at, cities,
landmass, sea_body, colonial, cols, rows, map, seed) is hashed once at the first and once at the last step. So
anything the AI, the economy, war, peace, research, ages, debt and founding do to the state is compared.
WHAT IT DOES NOT COVER: drawing and input (use the golden screenshots and the ui tests), saves (save-compat), the
player-only paths of the UI, anything the all-AI games and the prepared states never reach (a rule that only a
human move triggers), private caches (names starting with "_"; a wrong cache shows up in the state through what it
feeds), and speed (tools/perf.py).

The runner is self-contained (it imports nothing from tests/ or tools/), so the base checkout needs nothing but its
hexa/ folder; it may predate tests/ and tools/. To run it locally against master:

    git worktree add --detach /tmp/hexa-base master
    python tools/same_behaviour.py /tmp/hexa-base
    git worktree remove --force /tmp/hexa-base

CI runs it in .github/workflows/same-behaviour.yml, on pull requests labelled "refactor", with the merge base.
No pygame needed.
"""
import argparse
import concurrent.futures
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUNNER = os.path.join(ROOT, "tools", "oracle_runner.py")
TIMEOUT = 300
LINE = re.compile(r"^\d+ \d+ [0-9a-f]{64}$")

# (label, runner suite, seed, steps)
SUITES = [
    ("campaign europe 1480", "campaign", 1480, 12),
    ("campaign random 7", "random", 7, 12),
    ("campaign random 11", "random", 11, 12),
    ("colony 5", "colony", 5, 30),
    ("conquest 3", "conquest", 3, 0),
    ("midgame (turn 160)", "midgame", 1480, 6),
    ("debt", "debt", 1480, 6),
]


def run_suite(checkout, suite):
    """Play one suite with one checkout's hexa. Returns (digest lines, error text or None, seconds)."""
    _label, name, seed, steps = suite
    start = time.time()
    with tempfile.TemporaryDirectory(prefix="hexa-same-") as home:
        env = dict(os.environ, PYTHONHASHSEED="0", HEXA_HOME=home, PYTHONDONTWRITEBYTECODE="1",
                   PYGAME_HIDE_SUPPORT_PROMPT="1")
        env.pop("PYTHONPATH", None)
        args = [sys.executable, RUNNER, checkout, name, str(seed), str(steps)]
        try:
            done = subprocess.run(args, cwd=home, env=env, capture_output=True, text=True, timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            return [], f"timed out after {TIMEOUT} s", time.time() - start
    lines = [line.strip() for line in done.stdout.splitlines() if LINE.match(line.strip())]
    if done.returncode != 0:
        tail = (done.stderr.strip().splitlines() or ["no output"])[-4:]
        return lines, f"exit status {done.returncode}: " + " | ".join(tail), time.time() - start
    if not lines:
        return lines, "no digests were printed", time.time() - start
    return lines, None, time.time() - start


def compare(label, ours, base):
    """(failures, differences) for one suite: failures are crashes (nothing compared), differences are real."""
    (a, a_err, _), (b, b_err, _) = ours, base
    failures = []
    if a_err:
        failures.append(f"{label}: this checkout failed: {a_err}")
    if b_err:
        failures.append(f"{label}: the base checkout failed: {b_err}")
    if failures:
        return failures, []
    for x, y in zip(a, b):
        if x != y:
            step, turn, digest = x.split()
            return [], [f"{label}: differs at step {step} (turn {turn}): this checkout {digest[:12]}, "
                        f"base {y.split()[2][:12]}" + (" (the starting state, or the generated map)"
                                                       if step == "0" else "")]
    if len(a) != len(b):
        return [], [f"{label}: the games have different lengths: {len(a)} digests here, {len(b)} in the base "
                    f"(identical as far as both go)"]
    return [], []


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tools/same_behaviour.py", description=__doc__.split("\n")[0])
    parser.add_argument("base", help="a checkout (or git worktree) of the revision to compare with")
    parser.add_argument("--only", action="append", metavar="TEXT",
                        help="run only the suites whose name contains TEXT (repeatable; the tests use it)")
    parser.add_argument("--quick", action="store_true",
                        help="only one season or round after each suite's preparation (the tests use it)")
    args = parser.parse_args(argv)
    suites = [s for s in SUITES if not args.only or any(t in s[0] for t in args.only)]
    if args.quick:
        suites = [(label, name, seed, min(steps, 1)) for label, name, seed, steps in suites]
    if not suites:
        print("no suite matches --only " + ", ".join(args.only), file=sys.stderr)
        return 2
    base = os.path.abspath(args.base)
    if not os.path.isfile(os.path.join(base, "hexa", "__init__.py")):
        print(f"{base} has no hexa package: pass the folder that contains hexa/", file=sys.stderr)
        return 2
    if os.path.normcase(os.path.realpath(base)) == os.path.normcase(os.path.realpath(ROOT)):
        print("the base checkout is this checkout: nothing to compare", file=sys.stderr)
        return 2
    start = time.time()
    workers = max(2, min(14, os.cpu_count() or 2))
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        jobs = {s[0]: (pool.submit(run_suite, ROOT, s), pool.submit(run_suite, base, s)) for s in suites}
        results = {label: (a.result(), b.result()) for label, (a, b) in jobs.items()}
    failures, differences = [], []
    for suite in suites:
        label = suite[0]
        ours, theirs = results[label]
        broke, differ = compare(label, ours, theirs)
        failures += broke
        differences += differ
        state = "FAILED   " if broke else "DIFFERENT" if differ else "same     "
        print(f"{state}  {label:<22} {max(len(ours[0]) - 1, 0):>3} steps  {max(ours[2], theirs[2]):5.1f} s")
    total = time.time() - start
    if failures:
        print(f"\nORACLE FAILED ({total:.0f} s): a suite could not be played, so nothing was compared:")
        for line in failures + differences:
            print("  " + line)
        return 1
    if differences:
        print(f"\nBEHAVIOUR CHANGED ({total:.0f} s):")
        for line in differences:
            print("  " + line)
        print("A refactor must not change what the game does. If the change is meant, take the 'refactor' label off.")
        return 1
    print(f"\nSame behaviour as {base} in all {len(suites)} suites ({total:.0f} s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
