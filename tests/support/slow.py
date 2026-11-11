"""``@slow`` marks a test that takes several seconds; ``HEXA_FAST=1`` skips it for a quick local loop.

CI never sets HEXA_FAST, so it always runs everything.
"""
import os
import unittest

FAST_VAR = "HEXA_FAST"


def fast_mode():
    """True when HEXA_FAST=1 asks for the quick loop (read when a test is decorated, i.e. at import)."""
    return os.environ.get(FAST_VAR) == "1"


def slow(test):
    """Skip a test method or a whole TestCase class under HEXA_FAST=1. Skipped tests still count as tests."""
    return unittest.skipIf(fast_mode(), f"slow ({FAST_VAR}=1)")(test)
