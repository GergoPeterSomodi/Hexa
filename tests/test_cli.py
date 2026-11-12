"""hexa/cli.py: the command line of play.py, parsed without pygame.

Covers the defaults, every choice of every option, an invalid choice or a non-integer --seed (argparse exits with
code 2), and --nation passed through as typed. Matching --nation to a country (tag or name in any case, #11) is
done by CampaignApp once a world exists, so it is not tested here. A subprocess check confirms that importing
hexa.cli does not import pygame. Run with: python -m unittest tests.test_cli
"""
import contextlib
import io
import os
import subprocess
import sys
import unittest

from hexa import cli

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def parse(*argv):
    return cli.parse(list(argv))


def parse_error(*argv):
    """Parse argv, expecting argparse to reject it: returns (exit code, what it printed to stderr)."""
    err = io.StringIO()
    try:
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            cli.parse(list(argv))
    except SystemExit as exit_:
        return exit_.code, err.getvalue()
    raise AssertionError(f"parse{argv!r} did not exit")


class DefaultsTest(unittest.TestCase):
    def test_no_arguments_start_the_menu_with_default_settings(self):
        settings, skip_menu, nation, seed = parse()
        self.assertEqual(settings, {"mode": "campaign", "start": "sea", "goal": "survive", "map": "europe"})
        self.assertFalse(skip_menu)
        self.assertIsNone(nation)
        self.assertIsNone(seed)

    def test_build_parser_returns_a_fresh_parser_each_time(self):
        self.assertIsNot(cli.build_parser(), cli.build_parser())


class ChoicesTest(unittest.TestCase):
    def test_every_mode_skips_the_menu(self):
        for mode in ("campaign", "conquest", "colony"):
            with self.subTest(mode=mode):
                settings, skip_menu, _, _ = parse("--mode", mode)
                self.assertEqual(settings["mode"], mode)
                self.assertTrue(skip_menu)

    def test_every_map(self):
        for name in ("europe", "random"):
            with self.subTest(map=name):
                settings, skip_menu, _, _ = parse("--map", name)
                self.assertEqual(settings["map"], name)
                self.assertFalse(skip_menu, "only --mode skips the menu")

    def test_every_start(self):
        for start in ("sea", "land"):
            with self.subTest(start=start):
                self.assertEqual(parse("--start", start)[0]["start"], start)

    def test_every_goal(self):
        for goal in ("survive", "independence", "endless"):
            with self.subTest(goal=goal):
                self.assertEqual(parse("--goal", goal)[0]["goal"], goal)

    def test_options_combine(self):
        settings, skip_menu, nation, seed = parse("--mode", "colony", "--start", "land", "--goal", "endless",
                                                  "--map", "random", "--nation", "POR", "--seed", "7")
        self.assertEqual(settings, {"mode": "colony", "start": "land", "goal": "endless", "map": "random"})
        self.assertTrue(skip_menu)
        self.assertEqual((nation, seed), ("POR", 7))

    def test_equals_form_works(self):
        settings, _, _, seed = parse("--mode=conquest", "--seed=3")
        self.assertEqual((settings["mode"], seed), ("conquest", 3))

    def test_an_invalid_choice_exits_with_code_2(self):
        for option, bad in (("--mode", "chess"), ("--map", "mars"), ("--start", "air"), ("--goal", "fun")):
            with self.subTest(option=option):
                code, err = parse_error(option, bad)
                self.assertEqual(code, 2)
                self.assertIn("invalid choice", err)
                self.assertIn(bad, err)

    def test_choices_are_case_sensitive(self):
        self.assertEqual(parse_error("--mode", "Conquest")[0], 2)

    def test_an_unknown_option_exits_with_code_2(self):
        self.assertEqual(parse_error("--bogus")[0], 2)

    def test_a_missing_value_exits_with_code_2(self):
        self.assertEqual(parse_error("--mode")[0], 2)


class SeedTest(unittest.TestCase):
    def test_seed_is_an_int(self):
        seed = parse("--seed", "42")[3]
        self.assertEqual(seed, 42)
        self.assertIsInstance(seed, int)

    def test_zero_and_negative_seeds_are_kept(self):
        self.assertEqual(parse("--seed", "0")[3], 0)
        self.assertEqual(parse("--seed=-5")[3], -5)

    def test_a_non_integer_seed_exits_with_code_2(self):
        for bad in ("abc", "1.5", "", "0x10"):
            with self.subTest(seed=bad):
                code, err = parse_error("--seed", bad)
                self.assertEqual(code, 2)
                self.assertIn("--seed", err)


class NationTest(unittest.TestCase):
    def test_nation_is_passed_through_as_typed(self):
        for text in ("POR", "eng", "Venice", "  spain ", "No Such Land"):
            with self.subTest(nation=text):
                self.assertEqual(parse("--nation", text)[2], text)

    def test_nation_alone_does_not_skip_the_menu(self):
        self.assertFalse(parse("--nation", "POR")[1])


class HelpTest(unittest.TestCase):
    def test_help_exits_with_code_0_and_lists_every_option(self):
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out):
                cli.parse(["--help"])
        except SystemExit as exit_:
            self.assertEqual(exit_.code, 0)
        else:
            self.fail("--help did not exit")
        for option in ("--mode", "--nation", "--map", "--start", "--goal", "--seed"):
            self.assertIn(option, out.getvalue())


class PygameFreeTest(unittest.TestCase):
    def test_importing_hexa_cli_does_not_import_pygame(self):
        code = "import hexa.cli, sys; sys.exit(1 if 'pygame' in sys.modules else 0)"
        done = subprocess.run([sys.executable, "-c", code], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, f"hexa.cli pulled in pygame\n{done.stderr}")


if __name__ == "__main__":
    unittest.main()
