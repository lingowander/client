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

    def test_invalid_examples_declare_exact_error_paths(self) -> None:
        declared = set(validate.EXPECTED_INVALID)
        on_disk = {
            path.relative_to(validate.ROOT).as_posix()
            for path in validate.EXAMPLES_DIR.glob("*/*.json")
            if path.name.startswith("invalid_")
        }
        self.assertEqual(declared, on_disk)
        for relative, expected in validate.EXPECTED_INVALID.items():
            self.assertTrue(expected, relative)
            for path, validator_name in expected:
                self.assertIsInstance(path, tuple, relative)
                self.assertTrue(validator_name, relative)


if __name__ == "__main__":
    unittest.main()
