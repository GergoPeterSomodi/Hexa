"""Tests that drive the real pygame windows headless (tests/support/harness.py).

Every module here must import without pygame: import pygame and the window modules (play, hexa.menu,
hexa.*.app) inside the tests or setUpClass, never at module top, and base the test classes on
``harness.UITestCase`` (or decorate them with ``tests.support.pg.requires_pygame``). Without pygame they
show as skipped; with HEXA_REQUIRE_PYGAME=1 they error instead, so the CI ui job can't pass by skipping.

    python -m unittest discover -s tests/ui -t .        # only these tests (the CI ui job)
"""
