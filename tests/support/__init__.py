"""Helpers shared by the test modules (discovery only collects ``test_*.py``, so nothing here runs as a test).

Nothing in this package may import pygame at module level; the unit suite has to pass without it
(harness.py imports it lazily, when a window test starts).

    worlds       europe(), fresh(), random_world(), play_seasons(), pristine()
    home         TempHome: a test case whose HEXA_HOME is a temporary folder
    slow         @slow: skipped when HEXA_FAST=1
    invariants   check_conquest(), check_colony(), check_campaign(): what must hold after any action
    agents       seeded random players and the Judge of the x_check / x contract
    digests      world_digest() (comparable across processes), quick_digest() (within one), canonical()
    games        play_conquest(), play_colony(): whole all-AI games with a callback after every turn
    digest_run   python3 -m tests.support.digest_run MODE SEED...: digests of fixed-seed games (determinism test)
    pg           HAVE_PYGAME, @requires_pygame (skip without pygame unless HEXA_REQUIRE_PYGAME=1)
    harness      UITestCase and the Driver: the real windows run headless on fake time with scripted input
    monkey       seeded random-input sessions through a real window (tests/ui/test_monkey.py, tools/monkey.py)
    golden       golden screenshots: check(), require_environment(), MANIFEST.json, UPDATE_GOLDEN (tests/ui/test_screenshots.py)
"""
