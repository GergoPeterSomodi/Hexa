"""Hunt for bugs with the monkey of tests/ui/test_monkey.py, or replay a session a test failed.

    python -m tools.monkey colony 7 800 --burst 0.5          replay one session (the line a failed test prints)
    python -m tools.monkey campaign 1-30 300 --burst 0.5     a batch: seeds 1 to 30 ("3,8,12" works too)
    python -m tools.monkey all 1-10 --burst 0.5              every mode, each with its default frame budget
    python -m tools.monkey conquest 3 300 --log 40 --digest  the last 40 actions, the action log's and world's digests
    python -m tools.monkey --issues                          the input withheld for known open crashes
    python -m tools.monkey campaign 25 300 --burst 0.5 --hit card-toast   let one known crash's input through

Run it from the repository root with pygame installed (a Python 3.12 or 3.13 venv, see README, Window tests). The
windows run headless on fake time, each session in its own temporary HEXA_HOME, through the same code as the test
(tests/support/monkey.py). It prints one line per session and the report of each failure, saves the report and the
last frame of a failed session to test-artifacts/ (HEXA_TEST_ARTIFACTS), and exits with status 1 if any failed.
"""
import argparse
import sys

from tests.support import monkey


def _parser():
    parser = argparse.ArgumentParser(prog="python -m tools.monkey",
                                     description="Seeded random input into the game's windows, headless.")
    parser.add_argument("mode", nargs="?", choices=monkey.MODES + ("all",))
    parser.add_argument("seed", nargs="?", help="a seed, a range (1-30) or a list (3,8,12)")
    parser.add_argument("frames", nargs="?", type=int,
                        help="frames per session (default: " + ", ".join(f"{m} {n}" for m, n in
                                                                       monkey.DEFAULT_FRAMES.items()) + ")")
    parser.add_argument("--burst", type=float, default=monkey.DEFAULT_BURST,
                        help=f"chance that a frame gets a burst of actions (default {monkey.DEFAULT_BURST})")
    parser.add_argument("--log", type=int, default=0, metavar="N", help="print the last N actions of each session")
    parser.add_argument("--digest", action="store_true",
                        help="print each session's action-log hash and world digest (same seed, same digests)")
    parser.add_argument("--issues", action="store_true", help="print the KNOWN_ISSUES table and exit")
    parser.add_argument("--hit", action="append", default=[], choices=monkey.issue_ids() + ("all",), metavar="ISSUE",
                        help="let the input of a known open crash through instead of withholding it (repeatable; "
                             "all: every one): " + ", ".join(monkey.issue_ids()))
    return parser


def main(argv=None):
    parser = _parser()
    args = parser.parse_args(argv)
    if args.issues:
        print(monkey.issues_table())
        return 0
    if args.mode is None or args.seed is None:
        parser.error("give a mode and a seed, e.g. python -m tools.monkey colony 7 800 --burst 0.5")
    try:
        seeds = monkey.parse_seeds(args.seed, "seed", count=False)
    except ValueError as error:
        parser.error(str(error))
    if not 0 <= args.burst <= 1:
        parser.error(f"--burst {args.burst:g} is not between 0 and 1")
    if args.frames is not None and args.frames < 2:
        parser.error("frames: at least 2")
    modes = monkey.MODES if args.mode == "all" else (args.mode,)
    ran = failed = 0
    for mode in modes:
        for seed in seeds:
            try:
                outcome = monkey.run_session(mode, seed, args.frames or monkey.DEFAULT_FRAMES[mode], args.burst,
                                             hit=args.hit)
            except ImportError as error:              # no pygame
                print(error, file=sys.stderr)
                return 2
            ran += 1
            print(outcome.summary(), flush=True)
            if args.digest:
                print(f"  log {outcome.log_hash()}  world {outcome.world_digest()}", flush=True)
            for entry in outcome.log[-args.log:] if args.log else ():
                print(f"  {entry}")
            if outcome.failed:
                failed += 1
                print(outcome.report())
                for path in monkey.save_artifacts(outcome):
                    print(f"Saved {path}")
                print(flush=True)
    if ran > 1:
        print(f"{ran - failed} of {ran} sessions passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
