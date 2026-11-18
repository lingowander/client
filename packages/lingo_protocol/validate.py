#!/usr/bin/env python3
"""Validate lingo_protocol v0 examples against the draft 2020-12 schemas.

One command, from the client repository root:

    python3 packages/lingo_protocol/validate.py

Valid examples must pass. Invalid examples must fail. The script does not
call a model and does not use the network.
"""

from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

ROOT = Path(__file__).resolve().parent
SCHEMA_DIR = ROOT / "schema"
EXAMPLES_DIR = ROOT / "examples"

PAYLOAD_SCHEMAS = ("turn_output", "turn_analysis", "weakness_plan")
EXPRESSION_ENUM = ("neutral", "smile", "happy", "surprised", "sad", "troubled")
FORBIDDEN_COMBINATORS = ("oneOf", "anyOf", "allOf")

# Each invalid example must fail at these paths and validators, and nowhere else.
# A sample that fails for a different reason does not count as a pass.
EXPECTED_INVALID = {
    "examples/turn_output/invalid_expression.json": (
        (("lines", 0, "expression"), "enum"),
    ),
    "examples/turn_analysis/invalid_kind.json": (
        (("observations", 0, "kind"), "enum"),
    ),
    "examples/weakness_plan/invalid_strategy.json": (
        (("targets", 0, "strategy"), "enum"),
    ),
}


def load_json(path: Path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def schema_key(path: Path) -> str:
    suffix = ".schema.json"
    if not path.name.endswith(suffix):
        raise SystemExit(f"unexpected schema file name: {path.name}")
    return path.name[: -len(suffix)]


def build_registry() -> tuple[dict[str, dict], Registry]:
    schemas: dict[str, dict] = {}
    resources = []
    for path in sorted(SCHEMA_DIR.glob("*.schema.json")):
        schema = load_json(path)
        schema_id = schema.get("$id")
        if not isinstance(schema_id, str) or not schema_id:
            raise SystemExit(f"{path.name} is missing $id")
        schemas[schema_key(path)] = schema
        resources.append(
            (
                schema_id,
                Resource.from_contents(schema, default_specification=DRAFT202012),
            )
        )
    return schemas, Registry().with_resources(resources)


def validator_for(schema: dict, registry: Registry) -> Draft202012Validator:
    try:
        Draft202012Validator.check_schema(schema)
    except SchemaError as exc:
        raise SystemExit(f"schema is not valid draft 2020-12: {exc.message}") from exc
    return Draft202012Validator(
        schema,
        registry=registry,
        format_checker=Draft202012Validator.FORMAT_CHECKER,
    )


def walk(node):
    if isinstance(node, dict):
        yield node
        for value in node.values():
            yield from walk(value)
    elif isinstance(node, list):
        for item in node:
            yield from walk(item)


def check_schema_shape(schemas: dict[str, dict]) -> list[str]:
    problems = []
    if "common" not in schemas:
        problems.append("common.schema.json is missing")
    for name, schema in schemas.items():
        for node in walk(schema):
            for keyword in FORBIDDEN_COMBINATORS:
                if keyword in node:
                    problems.append(f"{name} uses {keyword}, which this package avoids")
            if node.get("type") == "object" and node.get("additionalProperties") is not False:
                problems.append(f"{name} has an object schema without additionalProperties: false")
            properties = node.get("properties")
            if isinstance(properties, dict) and "emotion" in properties:
                problems.append(f"{name} still has an emotion field")
        if name == "common":
            continue
        if name not in PAYLOAD_SCHEMAS:
            problems.append(f"unexpected schema file: {name}")
            continue
        version = schema.get("properties", {}).get("schema_version", {})
        if version.get("type") != "integer" or version.get("const") != 0:
            problems.append(f"{name}.schema_version must be an integer const 0")
        schema_name = schema.get("properties", {}).get("schema_name", {})
        schema_name_ref = "urn:lingowander:lingo_protocol:v0:common#/$defs/SchemaName"
        if schema_name.get("$ref") != schema_name_ref:
            problems.append(f"{name}.schema_name must $ref SchemaName")
        if "const" in schema_name:
            problems.append(f"{name}.schema_name must not lock a const; schema_version does")
    prefixes = {
        "turn_output": "TurnOutput",
        "turn_analysis": "TurnAnalysis",
        "weakness_plan": "WeaknessPlan",
    }
    for name, prefix in prefixes.items():
        for def_name in schemas.get(name, {}).get("$defs", {}):
            rest = def_name[len(prefix):] if def_name.startswith(prefix) else ""
            if not rest or not rest[0].isupper():
                problems.append(f"{name} $def {def_name} must be {prefix} plus a PascalCase name")
    for def_name in schemas.get("common", {}).get("$defs", {}):
        if not def_name[:1].isupper() or def_name.startswith(("TurnOutput", "TurnAnalysis", "WeaknessPlan")):
            problems.append(f"common $def {def_name} must be PascalCase without a contract prefix")
    expression = (
        schemas.get("turn_output", {})
        .get("$defs", {})
        .get("TurnOutputLine", {})
        .get("properties", {})
        .get("expression", {})
    )
    if tuple(expression.get("enum", [])) != EXPRESSION_ENUM:
        problems.append(
            "turn_output lines[].expression enum must be "
            + ", ".join(EXPRESSION_ENUM)
        )
    return problems


def error_signature(error) -> tuple[tuple, str]:
    return (tuple(error.absolute_path), error.validator)


def format_signature(signature: tuple[tuple, str]) -> str:
    path, validator = signature
    location = "/".join(str(part) for part in path) or "<root>"
    return f"{location} ({validator})"


def check_examples(schemas: dict[str, dict], registry: Registry) -> list[str]:
    problems = []
    for name in PAYLOAD_SCHEMAS:
        validator = validator_for(schemas[name], registry)
        directory = EXAMPLES_DIR / name
        files = sorted(directory.glob("*.json")) if directory.is_dir() else []
        valid_count = 0
        invalid_count = 0
        if not files:
            problems.append(f"no examples for {name}")
        for path in files:
            instance = load_json(path)
            errors = sorted(
                validator.iter_errors(instance),
                key=lambda error: (list(error.absolute_path), error.message),
            )
            relative = path.relative_to(ROOT).as_posix()
            if path.name.startswith("valid_"):
                valid_count += 1
                if errors:
                    problems.append(f"expected pass, got failure: {relative}: {errors[0].message}")
                else:
                    print(f"PASS {relative}")
            elif path.name.startswith("invalid_"):
                invalid_count += 1
                actual = tuple(sorted(error_signature(error) for error in errors))
                expected = tuple(sorted(EXPECTED_INVALID.get(relative, ())))
                if relative not in EXPECTED_INVALID:
                    problems.append(f"no expected error is declared for {relative}")
                elif actual != expected:
                    problems.append(
                        f"{relative} errors were {[format_signature(item) for item in actual]}, "
                        f"expected {[format_signature(item) for item in expected]}"
                    )
                else:
                    print(f"PASS {relative} rejected at {format_signature(expected[0])}")
            else:
                problems.append(f"example name must start with valid_ or invalid_: {relative}")
        if valid_count < 2:
            problems.append(f"{name} needs at least 2 valid examples, found {valid_count}")
        if invalid_count < 1:
            problems.append(f"{name} needs at least 1 invalid example, found {invalid_count}")
    return problems


def accepts(registry: Registry, ref: str, instance) -> bool:
    validator = Draft202012Validator(
        {"$ref": ref},
        registry=registry,
        format_checker=Draft202012Validator.FORMAT_CHECKER,
    )
    return validator.is_valid(instance)


def check_aligned_conventions(schemas: dict[str, dict], registry: Registry) -> list[str]:
    """Conventions agreed with the server. See the package README."""
    problems = []
    common = schemas["common"]["$defs"]
    pair = common["LangPair"]
    if pair.get("required") != ["src", "tgt"]:
        problems.append("pair must require src and tgt")
    if set(pair.get("properties", {})) != {"src", "tgt"}:
        problems.append("pair properties must be exactly src and tgt")
    if common["TaskType"]["enum"] != [
        "scene_plan",
        "turn",
        "bridge",
        "turn_analysis",
        "summarize",
        "skeleton",
    ]:
        problems.append("task_type enum does not match the server alignment")
    if common["SceneId"]["pattern"] != r"^s_[0-9]{4,}$":
        problems.append("SceneId pattern drifted")
    if common["LangPairKey"]["pattern"] != (
        r"^[a-z]{2,3}(-[A-Za-z0-9]+)*>[a-z]{2,3}(-[A-Za-z0-9]+)*$"
    ):
        problems.append("LangPairKey pattern drifted")
    if common["PromptId"]["pattern"] != r"^[a-z][a-z0-9_]*$":
        problems.append("PromptId pattern drifted")
    if common["PromptVersion"]["pattern"] != (
        r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"
    ):
        problems.append("PromptVersion pattern drifted")
    if common["SchemaName"]["enum"] != ["turn_output", "turn_analysis", "weakness_plan"]:
        problems.append("SchemaName enum drifted")
    for name in ("TurnId", "ProfileId", "EventId"):
        definition = common[name]
        if definition.get("type") != "string" or definition.get("format") != "uuid":
            problems.append(f"{name} must be a uuid string")
    for name in PAYLOAD_SCHEMAS:
        version = schemas[name]["properties"]["schema_version"]
        if version.get("type") != "integer" or not isinstance(version.get("const"), int):
            problems.append(f"{name} schema_version must be its own integer const")
        if "pair" not in schemas[name]["required"]:
            problems.append(f"{name} must require pair")
    for name in ("turn_output", "turn_analysis"):
        if "turn_id" not in schemas[name]["required"]:
            problems.append(f"{name} must require turn_id")
    if "turn_id" in schemas["weakness_plan"]["properties"]:
        problems.append("weakness_plan does not echo turn_id")
    line = schemas["turn_output"]["$defs"]["TurnOutputLine"]
    if "translation" in line["required"]:
        problems.append("translation must stay optional")
    if "translation" not in line["properties"]:
        problems.append("translation should exist as an optional field")
    if "待定：译文由谁生成" not in line["properties"]["translation"].get("description", ""):
        problems.append("translation must be marked 待定：译文由谁生成")
    budget = schemas["weakness_plan"]["$defs"]["WeaknessPlanTarget"]["properties"]["budget_per_scene"]
    if budget.get("minimum") != 1:
        problems.append("budget_per_scene minimum must be 1; 0 is not defined as skipping a target")
    if "不织入" not in budget.get("description", ""):
        problems.append("budget_per_scene must say that 0 does not mean skipping the target")

    common_id = schemas["common"]["$id"]
    cases = [
        (f"{common_id}#/$defs/LangPairKey", "zh>en", True),
        (f"{common_id}#/$defs/LangPairKey", "zh-Hans>en", True),
        (f"{common_id}#/$defs/LangPairKey", "zh>zh", True),
        (f"{common_id}#/$defs/LangPairKey", "zh=zh", False),
        (f"{common_id}#/$defs/SceneId", "s_0042", True),
        (f"{common_id}#/$defs/SceneId", "s_cafe_opening", False),
        (f"{common_id}#/$defs/LangPair", {"src": "zh", "tgt": "en"}, True),
        (f"{common_id}#/$defs/LangPair", {"source_lang": "zh", "target_lang": "en"}, False),
        (f"{common_id}#/$defs/TurnId", "00000000-0000-4000-8000-000000000001", True),
        (f"{common_id}#/$defs/TaskType", "turn", True),
        (f"{common_id}#/$defs/TaskType", "quiz", False),
        (f"{common_id}#/$defs/PromptId", "turn", True),
        (f"{common_id}#/$defs/PromptId", "turn@0.3.1", False),
        (f"{common_id}#/$defs/PromptVersion", "0.3.1", True),
        (f"{common_id}#/$defs/SchemaName", "turn_output", True),
        (f"{common_id}#/$defs/SchemaName", "turn_output@1", False),
    ]
    for ref, instance, should_pass in cases:
        valid = accepts(registry, ref, instance)
        if valid != should_pass:
            problems.append(f"{ref} accepted {instance!r}: {valid}, expected {should_pass}")
    return problems


def check_expression_rules(schemas: dict[str, dict], registry: Registry) -> list[str]:
    """Lock the single expression field: warm and emotion are not accepted."""
    problems = []
    validator = validator_for(schemas["turn_output"], registry)
    opening_path = EXAMPLES_DIR / "turn_output" / "valid_cafe_opening.json"
    opening = load_json(opening_path)

    warm = copy.deepcopy(opening)
    warm["lines"][0]["expression"] = "warm"
    warm_errors = tuple(sorted(error_signature(error) for error in validator.iter_errors(warm)))
    if warm_errors != ((("lines", 0, "expression"), "enum"),):
        problems.append(f"expression warm must fail only at lines/0/expression enum, got {warm_errors}")

    aliased = copy.deepcopy(opening)
    aliased["lines"][0]["emotion"] = aliased["lines"][0].pop("expression")
    alias_errors = tuple(sorted(error_signature(error) for error in validator.iter_errors(aliased)))
    expected_alias = tuple(
        sorted(
            (
                (("lines", 0), "additionalProperties"),
                (("lines", 0), "required"),
            )
        )
    )
    if alias_errors != expected_alias:
        problems.append(f"emotion alias must fail only as listed, got {alias_errors}")

    legacy = copy.deepcopy(opening)
    legacy["schema"] = "turn_output@1"
    legacy_errors = tuple(sorted(error_signature(error) for error in validator.iter_errors(legacy)))
    if legacy_errors != (((), "additionalProperties"),):
        problems.append(f"legacy schema field must fail only at the root, got {legacy_errors}")

    plan = load_json(EXAMPLES_DIR / "weakness_plan" / "valid_zh_en_cafe.json")
    plan["targets"][0]["budget_per_scene"] = 0
    budget_errors = tuple(
        sorted(
            error_signature(error)
            for error in validator_for(schemas["weakness_plan"], registry).iter_errors(plan)
        )
    )
    if budget_errors != ((("targets", 0, "budget_per_scene"), "minimum"),):
        problems.append(f"budget 0 must fail only minimum at targets/0/budget_per_scene, got {budget_errors}")
    return problems


def collect_problems() -> list[str]:
    schemas, registry = build_registry()
    return (
        check_schema_shape(schemas)
        + check_aligned_conventions(schemas, registry)
        + check_examples(schemas, registry)
        + check_expression_rules(schemas, registry)
    )


def main() -> int:
    problems = collect_problems()
    if problems:
        print("FAILED", file=sys.stderr)
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
