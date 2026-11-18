#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Lingowander
#
# 语遇 Lingowander 客户端的一部分。
# 本文件以 GNU General Public License v3.0 授权（仅此版本）。
# 完整文本见仓库根目录 LICENSE。

"""校验 evals/cases 下的评测用例。

只检查用例文件是否符合 schema 和少量跨字段规则。
不调用模型，不读取真实用户数据。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError, ValidationError

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CASES_DIR = REPO_ROOT / "evals" / "cases"
DEFAULT_SCHEMA_PATH = REPO_ROOT / "evals" / "schema" / "eval_case.schema.json"

CASE_SUFFIXES = {".yaml", ".yml", ".json"}
FORBIDDEN_KINDS = {"score", "level", "percentage"}
FORBIDDEN_SURFACES = {"structured_fields", "player_visible_text"}
_BOOL_ONLY = re.compile(r"^(?:true|false)$", re.IGNORECASE)


class EvalLoader(yaml.SafeLoader):
    """只把 true/false 当作布尔，避免把语言标记 no 读成 False。"""


EvalLoader.yaml_implicit_resolvers = {
    key: [
        (tag, pattern)
        for tag, pattern in resolvers
        if tag != "tag:yaml.org,2002:bool"
    ]
    for key, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items()
}
EvalLoader.add_implicit_resolver(
    "tag:yaml.org,2002:bool",
    _BOOL_ONLY,
    list("tTfF"),
)


def load_document(path: Path) -> object:
    text = path.read_text(encoding="utf-8")
    if path.suffix == ".json":
        import json

        return json.loads(text)
    return yaml.load(text, Loader=EvalLoader)


def load_schema(schema_path: Path) -> Draft202012Validator:
    import json

    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema)


def iter_case_files(cases_dir: Path) -> list[Path]:
    if not cases_dir.is_dir():
        raise FileNotFoundError(f"用例目录不存在：{cases_dir}")
    files = [
        path
        for path in sorted(cases_dir.rglob("*"))
        if path.is_file() and path.suffix in CASE_SUFFIXES
    ]
    return files


def _location(error: ValidationError) -> str:
    parts: list[str] = []
    for item in error.absolute_path:
        if isinstance(item, int):
            parts.append(f"[{item}]")
        elif parts:
            parts.append(f".{item}")
        else:
            parts.append(str(item))
    return "".join(parts) or "<root>"


def format_schema_error(path: Path, error: ValidationError) -> str:
    detail = error.message
    if error.context:
        nested = min(error.context, key=lambda item: len(item.absolute_path))
        detail = f"{detail}；{_location(nested)}: {nested.message}"
    return f"{path}: {_location(error)}: {detail}"


def semantic_errors(path: Path, document: object) -> list[str]:
    if not isinstance(document, dict):
        return [f"{path}: 用例必须是对象"]

    errors: list[str] = []
    expectations = document.get("expectations")
    if not isinstance(expectations, dict):
        return errors
    deterministic = expectations.get("deterministic")
    if not isinstance(deterministic, list):
        return errors

    types = [item.get("type") for item in deterministic if isinstance(item, dict)]

    def fail(message: str) -> None:
        errors.append(f"{path}: {message}")

    if "schema_conforms" not in types:
        fail("每条用例至少要有一条 schema_conforms")

    forbidden = [
        item
        for item in deterministic
        if isinstance(item, dict) and item.get("type") == "forbidden_content"
    ]
    kinds: set[str] = set()
    surfaces: set[str] = set()
    for item in forbidden:
        kinds.update(item.get("kinds") or [])
        surfaces.update(item.get("surfaces") or [])
    if not FORBIDDEN_KINDS <= kinds or not FORBIDDEN_SURFACES <= surfaces:
        fail(
            "forbidden_content 必须同时覆盖 score、level、percentage，"
            "以及 structured_fields 与 player_visible_text"
        )

    tags = set(document.get("tags") or [])
    if "reward" in tags and "reward_key_once" not in types:
        fail("标签 reward 需要 reward_key_once")
    if "language-pair" in tags and "language_pair_isolation" not in types:
        fail("标签 language-pair 需要 language_pair_isolation")
    if "budget" in tags and not ({"length_budget", "latency_budget"} & set(types)):
        fail("标签 budget 需要 length_budget 或 latency_budget")

    pair = document.get("language_pair") or {}
    source = pair.get("source")
    target = pair.get("target")
    isolations = [
        item
        for item in deterministic
        if isinstance(item, dict) and item.get("type") == "language_pair_isolation"
    ]

    def isolates(item: dict, pair_source: object, pair_target: object, learning: bool) -> bool:
        return (
            item.get("source") == pair_source
            and item.get("target") == pair_target
            and item.get("expect_learning_profile") is learning
        )

    if source is not None and source == target:
        if not any(isolates(item, source, target, False) for item in isolations):
            fail("源语言等于目标语言时，必须断言该纯游戏桶不产生学习档案")

    for item in isolations:
        if item.get("source") == item.get("target") and item.get("expect_learning_profile") is True:
            fail("纯游戏桶的 expect_learning_profile 必须为 false")

    if "pure-game" in tags:
        if source != target:
            fail("标签 pure-game 要求源语言等于目标语言")
        absent = [
            item
            for item in deterministic
            if isinstance(item, dict) and item.get("type") == "schema_absent"
        ]
        if not any(item.get("target") == "weakness_plan" for item in absent):
            fail("标签 pure-game 需要 schema_absent 指向 weakness_plan")

    switches = document.get("language_switches") or []
    if switches:
        first = switches[0]
        from_pair = first.get("from_pair") or {}
        if from_pair.get("source") != source or from_pair.get("target") != target:
            fail("第一条语言切换的 from_pair 必须等于用例起始语言对")
        for index, switch in enumerate(switches):
            to_pair = switch.get("to_pair") or {}
            if not any(
                item.get("source") == to_pair.get("source")
                and item.get("target") == to_pair.get("target")
                for item in isolations
            ):
                fail(f"language_switches[{index}] 的 to_pair 缺少 language_pair_isolation")

    return errors


def validate_case_dir(cases_dir: Path, schema_path: Path) -> list[str]:
    try:
        validator = load_schema(schema_path)
    except (OSError, SchemaError, ValueError) as exc:
        return [f"{schema_path}: 无法加载 schema：{exc}"]

    try:
        files = iter_case_files(cases_dir)
    except FileNotFoundError as exc:
        return [str(exc)]
    if not files:
        return [f"{cases_dir}: 没有用例文件"]

    errors: list[str] = []
    seen_ids: dict[str, Path] = {}
    for path in files:
        try:
            document = load_document(path)
        except (OSError, yaml.YAMLError, ValueError) as exc:
            errors.append(f"{path}: 无法解析：{exc}")
            continue

        for error in validator.iter_errors(document):
            errors.append(format_schema_error(path, error))
        errors.extend(semantic_errors(path, document))

        if isinstance(document, dict) and isinstance(document.get("id"), str):
            case_id = document["id"]
            previous = seen_ids.get(case_id)
            if previous is not None:
                errors.append(f"{path}: 重复 id {case_id}，已在 {previous} 出现")
            else:
                seen_ids[case_id] = path
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="校验 evals/cases 下的评测用例")
    parser.add_argument("--cases", type=Path, default=DEFAULT_CASES_DIR)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA_PATH)
    args = parser.parse_args(argv)
    errors = validate_case_dir(args.cases, args.schema)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f"失败：{len(errors)} 个问题", file=sys.stderr)
        return 1
    files = iter_case_files(args.cases)
    print(f"通过：{len(files)} 个用例符合 eval case schema v0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
