"""A temporary HEXA_HOME, so no test reads or writes the real ``~/.hexa``."""
import os
import shutil
import tempfile
import unittest


class TempHome(unittest.TestCase):
    """Base class: every test gets a fresh empty folder as ``self.home`` and HEXA_HOME points at it."""

    def setUp(self):
        self.home = tempfile.mkdtemp()
        self.old = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = self.home

    def tearDown(self):
        if self.old is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = self.old
        shutil.rmtree(self.home, ignore_errors=True)
