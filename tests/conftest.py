"""Keep test runs from writing bytecode into the source tree (profiles/, scripts/)."""

import sys

sys.dont_write_bytecode = True
