"""Run the lingo_protocol example validator as a unit test."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import validate


class LingoProtocolExamplesTest(unittest.TestCase):
    def test_examples_match_their_schemas(self) -> None:
        self.assertEqual(validate.collect_problems(), [])


if __name__ == "__main__":
    unittest.main()
