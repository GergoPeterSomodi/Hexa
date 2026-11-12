"""Is pygame there? Tests that need it skip without it, unless ``HEXA_REQUIRE_PYGAME=1`` says they must run.

    HAVE_PYGAME        True when pygame can be imported (found on the path; it is never imported here)
    requires_pygame    decorator for a test method or TestCase class: skipped when pygame is missing
    REQUIRE_VAR        "HEXA_REQUIRE_PYGAME": with the value 1 nothing is skipped, so a test without pygame
                       errors on its pygame import instead. The CI ui job sets it, so that job can't pass by
                       skipping every test.

Like ``@slow``, the decision is made when the test is decorated, i.e. when its module is imported.
No pygame import here: the unit suite imports this module.
"""
import importlib.util
import os
import unittest

REQUIRE_VAR = "HEXA_REQUIRE_PYGAME"
HAVE_PYGAME = importlib.util.find_spec("pygame") is not None


def required():
    """True when HEXA_REQUIRE_PYGAME=1: pygame tests must run (and fail) rather than skip."""
    return os.environ.get(REQUIRE_VAR) == "1"


def requires_pygame(test):
    """Skip a test method or a whole TestCase class when pygame is not installed (subclasses inherit it)."""
    reason = f"pygame is not installed ({REQUIRE_VAR}=1 makes this an error)"
    return unittest.skipUnless(HAVE_PYGAME or required(), reason)(test)
