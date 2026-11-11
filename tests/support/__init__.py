"""Helpers shared by the test modules (discovery only collects ``test_*.py``, so nothing here runs as a test).

Nothing in this package may import pygame at module level; the unit suite has to pass without it.

    worlds   europe(), fresh(), random_world(), play_seasons(), pristine()
    home     TempHome: a test case whose HEXA_HOME is a temporary folder
    slow     @slow: skipped when HEXA_FAST=1
"""
