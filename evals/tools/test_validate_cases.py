#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Lingowander
#
# 语遇 Lingowander 客户端的一部分。
# 本文件以 GNU General Public License v3.0 授权（仅此版本）。
# 完整文本见仓库根目录 LICENSE。

"""校验脚本的自测：正式用例通过，故意写坏的夹具失败。"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import validate_cases

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "invalid"


class ValidateCasesTest(unittest.TestCase):
    def test_repository_cases_pass(self) -> None:
        errors = validate_cases.validate_case_dir(
            validate_cases.DEFAULT_CASES_DIR,
            validate_cases.DEFAULT_SCHEMA_PATH,
        )
        self.assertEqual(errors, [])

    def test_invalid_fixtures_fail(self) -> None:
        files = sorted(FIXTURES.glob("*.yaml"))
        self.assertGreaterEqual(len(files), 4)
        for path in files:
            with self.subTest(path=path.name):
                errors = validate_cases.validate_case_dir(path.parent, validate_cases.DEFAULT_SCHEMA_PATH)
                own = [error for error in errors if str(path) in error or path.name in error]
                self.assertTrue(own, msg=f"{path.name} 应失败，实际：{errors}")

    def test_duplicate_ids_fail(self) -> None:
        source = next(validate_cases.DEFAULT_CASES_DIR.glob("*.yaml"))
        text = source.read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp)
            (dest / "a.yaml").write_text(text, encoding="utf-8")
            (dest / "b.yaml").write_text(text, encoding="utf-8")
            errors = validate_cases.validate_case_dir(dest, validate_cases.DEFAULT_SCHEMA_PATH)
        self.assertTrue(any("重复 id" in error for error in errors), msg=errors)

    def test_language_code_no_stays_text(self) -> None:
        document = validate_cases.load_document(
            validate_cases.DEFAULT_CASES_DIR / "placeholder_pure_game.yaml"
        )
        self.assertIsInstance(document, dict)
        assert isinstance(document, dict)
        self.assertEqual(document["language_pair"]["source"], "zh")
        loaded = validate_cases.yaml.load("source: no\n", Loader=validate_cases.EvalLoader)
        self.assertEqual(loaded["source"], "no")


if __name__ == "__main__":
    unittest.main()
