#!/usr/bin/env python3
"""Generate immutable Dart types from the lingo_protocol JSON Schemas.

The schema files are the source of truth. This script emits the libraries
under lib/src/generated and the package barrel. It understands the keyword
subset v0 actually uses. A schema change that adds a keyword this script
does not implement fails the generator, so CI cannot go green on a silent
drift.

    python3 packages/lingo_protocol/tool/generate_types.py
    python3 packages/lingo_protocol/tool/generate_types.py --check

--check formats a fresh copy and diffs it against the files in the tree.
It does not modify the tree.
"""

from __future__ import annotations

import difflib
import json
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_DIR = ROOT / "schema"
REPO_ROOT = ROOT.parents[1]

SCHEMA_KEYWORDS = {
    "$schema",
    "$id",
    "$defs",
    "$ref",
    "title",
    "description",
    "type",
    "properties",
    "required",
    "additionalProperties",
    "items",
    "enum",
    "const",
    "minLength",
    "maxLength",
    "pattern",
    "format",
    "minimum",
    "maximum",
    "minItems",
    "maxItems",
    "minProperties",
    "maxProperties",
}

REF_ANNOTATIONS = {"description", "title"}

RESERVED = {
    "assert",
    "async",
    "await",
    "base",
    "break",
    "case",
    "catch",
    "class",
    "const",
    "continue",
    "covariant",
    "default",
    "deferred",
    "do",
    "else",
    "enum",
    "export",
    "extends",
    "extension",
    "external",
    "factory",
    "false",
    "final",
    "finally",
    "for",
    "get",
    "hide",
    "if",
    "implements",
    "import",
    "in",
    "interface",
    "is",
    "late",
    "library",
    "mixin",
    "new",
    "null",
    "of",
    "on",
    "operator",
    "part",
    "required",
    "rethrow",
    "return",
    "sealed",
    "set",
    "show",
    "static",
    "super",
    "switch",
    "sync",
    "this",
    "throw",
    "true",
    "try",
    "typedef",
    "var",
    "void",
    "when",
    "while",
    "with",
    "yield",
}

CLASS_NAMES = {
    ("common", "pair"): "LanguagePair",
    ("turn_output", "line"): "TurnLine",
    ("turn_output", "choice"): "TurnChoice",
    ("turn_output", "scene_state"): "SceneState",
    ("turn_output", "proposed_event"): "ProposedEvent",
    ("turn_output", "image_request"): "ImageRequest",
    ("turn_output", "memory_note"): "MemoryNote",
    ("turn_output", "meta"): "PromptMeta",
    ("turn_analysis", "observation"): "Observation",
    ("turn_analysis", "level_evidence"): "LevelEvidence",
    ("turn_analysis", "engagement_signals"): "EngagementSignals",
    ("weakness_plan", "target"): "WeaknessTarget",
    ("weakness_plan", "scene_constraints"): "SceneConstraints",
    ("weakness_plan", "cooldown"): "WeaknessCooldown",
}

ROOT_CLASS = {
    "turn_output": "TurnOutput",
    "turn_analysis": "TurnAnalysis",
    "weakness_plan": "WeaknessPlan",
}

INLINE_ENUM_NAMES = {
    ("turn_output", "line", "expression"): "TurnLineExpression",
    ("turn_output", None, "input_mode_hint"): "InputModeHint",
    ("turn_output", "scene_state", "goal_progress"): "GoalProgress",
    ("turn_output", "image_request", "slot"): "ImageSlot",
    ("turn_output", "image_request", "priority"): "ImagePriority",
    ("turn_output", "memory_note", "kind"): "MemoryKind",
    ("weakness_plan", "target", "strategy"): "WeaknessStrategy",
}

HEADER = """// Generated from packages/lingo_protocol/schema/*.schema.json.
// Do not edit by hand. Regenerate with:
//
//   python3 packages/lingo_protocol/tool/generate_types.py
//
// CI runs that script with --check and fails when this file is stale.
"""


def fail(message: str) -> None:
    raise SystemExit(f"generate_types.py: {message}")


def pascal(snake: str) -> str:
    parts = [part for part in snake.split("_") if part]
    if not parts:
        fail(f"cannot name {snake!r}")
    return "".join(part[:1].upper() + part[1:] for part in parts)


def camel(snake: str) -> str:
    parts = [part for part in snake.split("_") if part]
    if not parts:
        fail(f"cannot name {snake!r}")
    head = parts[0]
    tail = "".join(part[:1].upper() + part[1:] for part in parts[1:])
    name = head + tail
    if name in RESERVED:
        fail(f"JSON name {snake} becomes reserved Dart identifier {name}")
    return name


def dart_ident(name: str) -> str:
    if name in RESERVED or not name:
        fail(f"reserved or empty Dart identifier {name}")
    return name


def dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def dart_raw(value: str) -> str:
    if "'" in value or value.endswith("\\"):
        fail(f"pattern cannot be emitted as a Dart raw string: {value}")
    return "r'" + value + "'"


def dart_number(value: object) -> str:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        fail(f"not a number: {value!r}")
    if isinstance(value, float) and not value.is_integer():
        return repr(value)
    return str(int(value))


def doc_comment(text: str) -> list[str]:
    collapsed = " ".join(text.split())
    if not collapsed:
        return []
    width = 76
    lines: list[str] = []
    remaining = collapsed
    while remaining:
        if len(remaining) <= width:
            lines.append(remaining)
            break
        cut = remaining.rfind(" ", 0, width + 1)
        if cut < 24:
            cut = width
        lines.append(remaining[:cut].rstrip())
        remaining = remaining[cut:].lstrip()
    return [f"/// {line}" for line in lines]


def load_docs() -> tuple[dict[str, dict], dict[str, str]]:
    docs: dict[str, dict] = {}
    by_id: dict[str, str] = {}
    paths = sorted(SCHEMA_DIR.glob("*.schema.json"))
    if len(paths) != 4:
        fail(f"expected 4 schema files, found {len(paths)}")
    for path in paths:
        schema = json.loads(path.read_text(encoding="utf-8"))
        key = path.name[: -len(".schema.json")]
        schema_id = schema.get("$id")
        if not isinstance(schema_id, str) or not schema_id:
            fail(f"{path.name} is missing $id")
        docs[key] = schema
        by_id[schema_id] = key
        assert_keywords(schema, key)
    return docs, by_id


def assert_keywords(schema: object, where: str) -> None:
    if not isinstance(schema, dict):
        fail(f"{where} is not a schema object")
    for key in schema:
        if key not in SCHEMA_KEYWORDS:
            fail(f"{where} uses unsupported keyword {key}")
    if isinstance(schema.get("type"), list):
        fail(f"{where} uses a type union; v0 schemas do not")
    if "$ref" in schema:
        extra = set(schema) - {"$ref"} - REF_ANNOTATIONS
        if extra:
            fail(f"{where} has non-annotation keyword(s) beside $ref: {sorted(extra)}")
        return
    if schema.get("type") == "object" and schema.get("additionalProperties") is not False:
        fail(f"{where} object must set additionalProperties to false")
    properties = schema.get("properties")
    if isinstance(properties, dict):
        for name, prop in properties.items():
            assert_keywords(prop, f"{where}.{name}")
    if "items" in schema:
        items = schema["items"]
        if isinstance(items, list):
            fail(f"{where} uses tuple items")
        assert_keywords(items, f"{where}[]")
    defs = schema.get("$defs")
    if isinstance(defs, dict):
        for name, prop in defs.items():
            assert_keywords(prop, f"{where}.${name}")
    if "enum" in schema:
        if schema.get("type") != "string":
            fail(f"{where} enum must be type string")
        if not schema["enum"] or not all(isinstance(item, str) for item in schema["enum"]):
            fail(f"{where} enum values must be non-empty strings")
    if schema.get("type") == "array" and "items" not in schema:
        fail(f"{where} array has no items schema")
    if "format" in schema and schema["format"] != "uuid":
        fail(f"{where} uses unsupported format {schema['format']}")


def lookup_pointer(document: dict, pointer: str) -> dict:
    if pointer in ("", "/"):
        return document
    if not pointer.startswith("/"):
        fail(f"bad JSON pointer {pointer}")
    node: object = document
    for raw in pointer.split("/")[1:]:
        token = raw.replace("~1", "/").replace("~0", "~")
        if isinstance(node, dict) and token in node:
            node = node[token]
        else:
            fail(f"unresolved pointer {pointer}")
    if not isinstance(node, dict):
        fail(f"pointer {pointer} does not land on a schema")
    return node


def split_ref(ref: str, current: str, by_id: dict[str, str]) -> tuple[str, str]:
    if ref.startswith("#"):
        return current, ref[1:]
    doc_id, hash_sign, fragment = ref.partition("#")
    if hash_sign != "#" or doc_id not in by_id:
        fail(f"unresolved $ref {ref}")
    pointer = fragment if fragment.startswith("/") else f"/{fragment}"
    return by_id[doc_id], pointer


def def_key(pointer: str) -> str | None:
    parts = [part for part in pointer.split("/") if part]
    if len(parts) == 2 and parts[0] == "$defs":
        return parts[1]
    return None


@dataclass
class EnumType:
    name: str
    values: list[str]
    description: str


@dataclass
class Checker:
    name: str
    kind: str
    description: str
    min_length: int | None = None
    max_length: int | None = None
    pattern: str | None = None
    format: str | None = None
    minimum: float | None = None
    maximum: float | None = None


@dataclass
class Field:
    json_name: str
    dart_name: str
    kind: str
    optional: bool
    description: str
    type_name: str | None = None
    checker: str | None = None
    const_value: object | None = None
    min_length: int | None = None
    max_length: int | None = None
    pattern: str | None = None
    format: str | None = None
    minimum: float | None = None
    maximum: float | None = None
    integer_minimum: int | None = None
    integer_maximum: int | None = None
    min_items: int | None = None
    max_items: int | None = None
    item: Field | None = None


@dataclass
class ClassType:
    name: str
    doc_key: str
    def_name: str | None
    description: str
    fields: list[Field] = field(default_factory=list)
    min_properties: int | None = None
    max_properties: int | None = None


def class_name(doc_key: str, def_name: str | None) -> str:
    if def_name is None:
        if doc_key not in ROOT_CLASS:
            fail(f"{doc_key} is not a payload schema")
        return dart_ident(ROOT_CLASS[doc_key])
    name = CLASS_NAMES.get((doc_key, def_name), pascal(def_name))
    return dart_ident(name)


def file_for(doc_key: str) -> str:
    return {
        "common": "common.dart",
        "turn_output": "turn_output.dart",
        "turn_analysis": "turn_analysis.dart",
        "weakness_plan": "weakness_plan.dart",
    }[doc_key]


def as_int(value: object, where: str) -> int:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or (
        isinstance(value, float) and not value.is_integer()
    ):
        fail(f"{where} must be an integer, found {value!r}")
    return int(value)


def compile_model(
    docs: dict[str, dict], by_id: dict[str, str]
) -> tuple[list[EnumType], list[Checker], list[ClassType]]:
    enums: list[EnumType] = []
    checkers: list[Checker] = []
    classes: list[ClassType] = []
    enum_names: dict[tuple[str, str], str] = {}
    checker_names: dict[tuple[str, str], str] = {}
    taken: set[str] = set()

    def take(name: str) -> str:
        if name in taken:
            fail(f"duplicate generated type name {name}")
        taken.add(name)
        return name

    for doc_key, schema in docs.items():
        for def_name, def_schema in schema.get("$defs", {}).items():
            if "enum" in def_schema:
                name = take(dart_ident(pascal(def_name)))
                enum_names[(doc_key, def_name)] = name
                enums.append(
                    EnumType(name, list(def_schema["enum"]), def_schema.get("description", ""))
                )
            elif def_schema.get("type") == "object":
                continue
            elif def_schema.get("type") in {"string", "number", "integer"}:
                name = take(dart_ident("check" + pascal(def_name)))
                checker_names[(doc_key, def_name)] = name
                checkers.append(compile_checker(name, def_schema))
            else:
                fail(f"{doc_key}.{def_name} is not an object, enum, or scalar")

    for doc_key, schema in docs.items():
        defs = schema.get("$defs", {})
        for def_name, def_schema in defs.items():
            if def_schema.get("type") != "object":
                continue
            classes.append(blank_class(doc_key, def_name, def_schema, take))
        if schema.get("type") == "object":
            classes.append(blank_class(doc_key, None, schema, take))

    by_class = {(item.doc_key, item.def_name): item for item in classes}

    def resolve(schema: dict, current: str) -> tuple[dict, str, str | None]:
        if "$ref" not in schema:
            return schema, current, None
        doc_key, pointer = split_ref(schema["$ref"], current, by_id)
        target = lookup_pointer(docs[doc_key], pointer)
        merged = dict(target)
        for key, value in schema.items():
            if key == "$ref":
                continue
            merged[key] = value
        return merged, doc_key, def_key(pointer)

    def compile_type(
        schema: dict,
        current: str,
        owner: tuple[str, str | None],
        json_name: str,
        optional: bool,
    ) -> Field:
        resolved, doc_key, def_name = resolve(schema, current)
        description = resolved.get("description", "")
        dart_name = camel(json_name)
        if "enum" in resolved and def_name is not None and (doc_key, def_name) in enum_names:
            return Field(
                json_name=json_name,
                dart_name=dart_name,
                kind="enum",
                optional=optional,
                description=description,
                type_name=enum_names[(doc_key, def_name)],
            )
        if "enum" in resolved:
            inline_key = (owner[0], owner[1], json_name)
            enum_name = INLINE_ENUM_NAMES.get(inline_key)
            if enum_name is None:
                owner_name = class_name(owner[0], owner[1])
                enum_name = owner_name + pascal(json_name)
            enum_name = dart_ident(enum_name)
            if enum_name not in taken:
                take(enum_name)
                enums.append(EnumType(enum_name, list(resolved["enum"]), description))
            else:
                existing = next(item for item in enums if item.name == enum_name)
                if existing.values != list(resolved["enum"]):
                    fail(f"enum name {enum_name} is reused for different values")
            return Field(
                json_name=json_name,
                dart_name=dart_name,
                kind="enum",
                optional=optional,
                description=description,
                type_name=enum_name,
            )
        if def_name is not None and (doc_key, def_name) in by_class:
            return Field(
                json_name=json_name,
                dart_name=dart_name,
                kind="object",
                optional=optional,
                description=description,
                type_name=by_class[(doc_key, def_name)].name,
            )
        if resolved.get("type") == "object":
            fail(f"{current}.{json_name} is an inline object; give it a $def")
        if resolved.get("type") == "array":
            item = compile_type(resolved["items"], doc_key, owner, json_name + "_item", False)
            item.dart_name = "item"
            return Field(
                json_name=json_name,
                dart_name=dart_name,
                kind="list",
                optional=optional,
                description=description,
                min_items=as_int(resolved["minItems"], json_name) if "minItems" in resolved else None,
                max_items=as_int(resolved["maxItems"], json_name) if "maxItems" in resolved else None,
                item=item,
            )
        checker = checker_names.get((doc_key, def_name)) if def_name is not None else None
        kind = {
            "string": "string",
            "integer": "int",
            "number": "double",
            "boolean": "bool",
        }.get(resolved.get("type"))
        if kind is None:
            fail(f"{current}.{json_name} has unsupported type {resolved.get('type')!r}")
        const_value = resolved.get("const")
        if const_value is not None and kind == "string" and not isinstance(const_value, str):
            fail(f"{current}.{json_name} const is not a string")
        if const_value is not None and kind == "int":
            const_value = as_int(const_value, f"{current}.{json_name}")
        if "const" in resolved and kind not in {"string", "int"}:
            fail(f"{current}.{json_name} const on {kind} is not supported")
        compiled = Field(
            json_name=json_name,
            dart_name=dart_name,
            kind=kind,
            optional=optional,
            description=description,
            checker=checker,
            const_value=const_value,
        )
        if checker is None and kind == "string":
            compiled.min_length = resolved.get("minLength")
            compiled.max_length = resolved.get("maxLength")
            compiled.pattern = resolved.get("pattern")
            compiled.format = resolved.get("format")
        if checker is None and kind == "int":
            if "minimum" in resolved:
                compiled.integer_minimum = as_int(resolved["minimum"], json_name)
            if "maximum" in resolved:
                compiled.integer_maximum = as_int(resolved["maximum"], json_name)
        if checker is None and kind == "double":
            if "minimum" in resolved:
                compiled.minimum = resolved["minimum"]
            if "maximum" in resolved:
                compiled.maximum = resolved["maximum"]
        return compiled

    for cls in classes:
        source = docs[cls.doc_key]
        schema = source if cls.def_name is None else source["$defs"][cls.def_name]
        required = set(schema.get("required", []))
        properties = schema.get("properties", {})
        missing = required - set(properties)
        if missing:
            fail(f"{cls.name} requires unknown properties {sorted(missing)}")
        for json_name, prop in properties.items():
            cls.fields.append(
                compile_type(
                    prop,
                    cls.doc_key,
                    (cls.doc_key, cls.def_name),
                    json_name,
                    json_name not in required,
                )
            )
        if "minProperties" in schema:
            cls.min_properties = as_int(schema["minProperties"], cls.name)
        if "maxProperties" in schema:
            cls.max_properties = as_int(schema["maxProperties"], cls.name)
        for item in cls.fields:
            if item.optional and item.kind in {"int", "bool"}:
                fail(f"{cls.name}.{item.json_name} optional {item.kind} is not generated")
    return enums, checkers, classes


def compile_checker(name: str, schema: dict) -> Checker:
    kind = {"string": "string", "number": "double", "integer": "int"}[schema["type"]]
    checker = Checker(name=name, kind=kind, description=schema.get("description", ""))
    if kind == "string":
        checker.min_length = schema.get("minLength")
        checker.max_length = schema.get("maxLength")
        checker.pattern = schema.get("pattern")
        checker.format = schema.get("format")
    else:
        if "minimum" in schema:
            checker.minimum = schema["minimum"]
        if "maximum" in schema:
            checker.maximum = schema["maximum"]
    return checker


def blank_class(doc_key: str, def_name: str | None, schema: dict, take) -> ClassType:
    name = take(class_name(doc_key, def_name))
    return ClassType(
        name=name,
        doc_key=doc_key,
        def_name=def_name,
        description=schema.get("description", ""),
    )


class Writer:
    def __init__(self) -> None:
        self.lines: list[str] = []

    def line(self, text: str = "") -> None:
        self.lines.append(text)

    def text(self) -> str:
        return "\n".join(self.lines) + "\n"


def emit_enum(item: EnumType) -> list[str]:
    writer = Writer()
    for line in doc_comment(item.description):
        writer.line(line)
    writer.line(f"enum {item.name} {{")
    for value in item.values:
        writer.line(f"  {camel(value)}({dart_string(value)}),")
    writer.line("  ;")
    writer.line("")
    writer.line(f"  const {item.name}(this.wire);")
    writer.line("")
    writer.line("  /// JSON string for this value.")
    writer.line("  final String wire;")
    writer.line("")
    writer.line(f"  static const Map<String, {item.name}> byWire = {{")
    for value in item.values:
        writer.line(f"    {dart_string(value)}: {item.name}.{camel(value)},")
    writer.line("  };")
    writer.line("")
    writer.line(f"  static {item.name} fromWire(String wire, {{String path = ''}}) {{")
    writer.line("    return enumFromWire(wire, byWire, path);")
    writer.line("  }")
    writer.line("}")
    return writer.lines


def string_args(item: Field | Checker, indent: str) -> list[str]:
    args: list[str] = []
    if getattr(item, "checker", None):
        return [f"check: {item.checker}"]
    if item.min_length is not None:
        args.append(f"minLength: {item.min_length}")
    if item.max_length is not None:
        args.append(f"maxLength: {item.max_length}")
    if item.pattern is not None:
        args.append(f"pattern: {pattern_var(item)}")
    if item.format is not None:
        args.append(f"format: {dart_string(item.format)}")
    return args


def pattern_var(item: Field | Checker) -> str:
    if isinstance(item, Field):
        return f"_{item.dart_name}Pattern"
    tail = item.name.removeprefix("check")
    return "_" + tail[:1].lower() + tail[1:] + "Pattern"


def number_args(item: Field) -> list[str]:
    if item.checker:
        return [f"check: {item.checker}"]
    args = []
    if item.minimum is not None:
        args.append(f"minimum: {dart_number(item.minimum)}")
    if item.maximum is not None:
        args.append(f"maximum: {dart_number(item.maximum)}")
    return args


def integer_args(item: Field) -> list[str]:
    args = []
    if item.integer_minimum is not None:
        args.append(f"minimum: {item.integer_minimum}")
    if item.integer_maximum is not None:
        args.append(f"maximum: {item.integer_maximum}")
    return args


def list_bounds(item: Field) -> str:
    parts = []
    if item.min_items is not None:
        parts.append(f"minItems: {item.min_items}")
    if item.max_items is not None:
        parts.append(f"maxItems: {item.max_items}")
    if not parts:
        return ""
    return ", " + ", ".join(parts)


def item_decoder(item: Field) -> str:
    assert item.item is not None
    inner = item.item
    if inner.kind == "object":
        return f"(item, itemPath) => {inner.type_name}.fromJson(item, path: itemPath)"
    if inner.kind == "enum":
        return (
            "(item, itemPath) => "
            f"{inner.type_name}.fromWire(readStringItem(item, itemPath), path: itemPath)"
        )
    if inner.kind == "string":
        args = ", ".join(string_args(inner, ""))
        suffix = f", {args}" if args else ""
        return f"(item, itemPath) => readStringItem(item, itemPath{suffix})"
    fail(f"list items of kind {inner.kind} are not generated")
    return ""


def read_call(item: Field) -> str:
    key = dart_string(item.json_name)
    if item.const_value is not None and item.kind == "string":
        return f"readConstString(jsonMap, {key}, path, {dart_string(item.const_value)})"
    if item.const_value is not None and item.kind == "int":
        return f"readConstInt(jsonMap, {key}, path, {item.const_value})"
    if item.kind == "string":
        fn = "readOptionalString" if item.optional else "readRequiredString"
        extra = string_args(item, "")
        tail = "".join(f", {arg}" for arg in extra)
        return f"{fn}(jsonMap, {key}, path{tail})"
    if item.kind == "int":
        extra = integer_args(item)
        tail = "".join(f", {arg}" for arg in extra)
        return f"readRequiredInteger(jsonMap, {key}, path{tail})"
    if item.kind == "double":
        fn = "readOptionalNumber" if item.optional else "readRequiredNumber"
        extra = number_args(item)
        tail = "".join(f", {arg}" for arg in extra)
        return f"{fn}(jsonMap, {key}, path{tail})"
    if item.kind == "bool":
        return f"readRequiredBool(jsonMap, {key}, path)"
    if item.kind == "enum":
        fn = "readOptionalEnum" if item.optional else "readRequiredEnum"
        return f"{fn}(jsonMap, {key}, path, {item.type_name}.byWire)"
    if item.kind == "object":
        fn = "readOptionalModel" if item.optional else "readRequiredModel"
        return f"{fn}(jsonMap, {key}, path, {item.type_name}.fromJson)"
    if item.kind == "list":
        fn = "readOptionalList" if item.optional else "readRequiredList"
        return f"{fn}(jsonMap, {key}, path, {item_decoder(item)}{list_bounds(item)})"
    fail(f"cannot read {item.kind}")
    return ""


def dart_type(item: Field) -> str:
    if item.kind == "string":
        base = "String"
    elif item.kind == "int":
        base = "int"
    elif item.kind == "double":
        base = "double"
    elif item.kind == "bool":
        base = "bool"
    elif item.kind == "enum" or item.kind == "object":
        base = item.type_name or ""
    elif item.kind == "list":
        assert item.item is not None
        inner = dart_type(item.item)
        base = f"List<{inner}>"
    else:
        fail(f"no dart type for {item.kind}")
        base = ""
    if item.optional:
        return f"{base}?"
    return base


def json_value(item: Field, receiver: str) -> str:
    if item.kind == "enum":
        return f"{receiver}.wire"
    if item.kind == "object":
        return f"{receiver}.toJson()"
    if item.kind == "list":
        assert item.item is not None
        if item.item.kind == "object":
            return f"[for (final item in {receiver}) item.toJson()]"
        if item.item.kind == "enum":
            return f"[for (final item in {receiver}) item.wire]"
        return f"[...{receiver}]"
    return receiver


def emit_class(cls: ClassType, patterns: dict[str, str]) -> list[str]:
    writer = Writer()
    description = cls.description.strip()
    blurb = description + " 实例不可变，相等性按字段值比较。"
    for line in doc_comment(blurb):
        writer.line(line)
    writer.line(f"final class {cls.name} {{")
    writer.line(f"  factory {cls.name}({{")
    for item in cls.fields:
        dtype = dart_type(item)
        if item.const_value is not None:
            literal = (
                dart_string(item.const_value)
                if isinstance(item.const_value, str)
                else str(item.const_value)
            )
            writer.line(f"    {dtype} {item.dart_name} = {literal},")
        elif item.optional:
            writer.line(f"    {dtype} {item.dart_name},")
        else:
            writer.line(f"    required {dtype} {item.dart_name},")
    writer.line("  }) {")
    for item in cls.fields:
        emit_factory_check(writer, item)
    if cls.min_properties is not None or cls.max_properties is not None:
        emit_property_count(writer, cls, path_expr=dart_string(cls.name))
    writer.line(f"    return {cls.name}._(")
    for item in cls.fields:
        value = item.dart_name
        if item.kind == "list":
            value = f"frozen{pascal(item.json_name)}"
        writer.line(f"      {item.dart_name}: {value},")
    writer.line("    );")
    writer.line("  }")
    writer.line("")
    writer.line(f"  const {cls.name}._({{")
    for item in cls.fields:
        if item.optional:
            writer.line(f"    this.{item.dart_name},")
        else:
            writer.line(f"    required this.{item.dart_name},")
    writer.line("  });")
    writer.line("")
    writer.line("  factory " + cls.name + ".fromJson(Object? json, {String path = ''}) {")
    keys = ", ".join(dart_string(item.json_name) for item in cls.fields)
    writer.line(f"    final jsonMap = readObject(json, path, const {{{keys}}});")
    for item in cls.fields:
        writer.line(f"    final {item.dart_name} = {read_call(item)};")
    if cls.min_properties is not None or cls.max_properties is not None:
        emit_property_count(writer, cls, path_expr="path")
    writer.line(f"    return {cls.name}._(")
    for item in cls.fields:
        writer.line(f"      {item.dart_name}: {item.dart_name},")
    writer.line("    );")
    writer.line("  }")
    writer.line("")
    for item in cls.fields:
        for line in doc_comment(item.description):
            writer.line(f"  {line}")
        writer.line(f"  final {dart_type(item)} {item.dart_name};")
        writer.line("")
    writer.line("  Map<String, Object?> toJson() {")
    writer.line("    return {")
    for item in cls.fields:
        encoded = json_value(item, item.dart_name if not item.optional else f"{item.dart_name}!")
        if item.optional:
            writer.line(
                f"      if ({item.dart_name} != null) {dart_string(item.json_name)}: {encoded},"
            )
        else:
            writer.line(f"      {dart_string(item.json_name)}: {json_value(item, item.dart_name)},")
    writer.line("    };")
    writer.line("  }")
    writer.line("")
    writer.line("  @override")
    writer.line("  bool operator ==(Object other) {")
    writer.line("    return identical(this, other) ||")
    writer.line(f"        other is {cls.name} &&")
    comparisons = []
    for item in cls.fields:
        if item.kind == "list":
            comparisons.append(f"deepListEquals({item.dart_name}, other.{item.dart_name})")
        else:
            comparisons.append(f"{item.dart_name} == other.{item.dart_name}")
    for index, comparison in enumerate(comparisons):
        suffix = ";" if index == len(comparisons) - 1 else " &&"
        writer.line(f"            {comparison}{suffix}")
    writer.line("  }")
    writer.line("")
    writer.line("  @override")
    writer.line("  int get hashCode => Object.hashAll([")
    for item in cls.fields:
        if item.kind == "list":
            writer.line(f"    deepListHash({item.dart_name}),")
        else:
            writer.line(f"    {item.dart_name},")
    writer.line("  ]);")
    writer.line("")
    writer.line("  @override")
    writer.line("  String toString() => '$runtimeType(${jsonEncode(toJson())})';")
    writer.line("}")
    for item in cls.fields:
        if item.pattern and item.checker is None:
            patterns.setdefault(item.dart_name, item.pattern)
        if item.item is not None and item.item.pattern and item.item.checker is None:
            patterns.setdefault(item.item.dart_name, item.item.pattern)
    return writer.lines


def emit_factory_check(writer: Writer, item: Field) -> None:
    name = item.dart_name
    path = dart_string(name)
    if item.const_value is not None and isinstance(item.const_value, str):
        writer.line(f"    if ({name} != {dart_string(item.const_value)}) {{")
        writer.line(
            "      throw LingoProtocolException("
            f"path: {path}, message: '{item.json_name} 必须是 "
            f"{item.const_value}。不认识的取值会被拒绝。');"
        )
        writer.line("    }")
        return
    if item.const_value is not None and isinstance(item.const_value, int):
        writer.line(f"    if ({name} != {item.const_value}) {{")
        writer.line(
            "      throw LingoProtocolException("
            f"path: {path}, message: '{item.json_name} 必须是 {item.const_value}，"
            f"实际是 ${name}。不认识的契约版本会被拒绝，不会按别的版本猜测。');"
        )
        writer.line("    }")
        return
    if item.kind == "string":
        if item.optional:
            writer.line(f"    if ({name} != null) {{")
            emit_string_check(writer, item, name, path, indent="      ")
            writer.line("    }")
        else:
            emit_string_check(writer, item, name, path, indent="    ")
        return
    if item.kind == "int":
        extra = integer_args(item)
        tail = "".join(f", {arg}" for arg in extra)
        writer.line(f"    validateInteger({name}, {path}{tail});")
        return
    if item.kind == "double":
        if item.optional:
            writer.line(f"    if ({name} != null) {{")
            emit_number_check(writer, item, name, path, indent="      ")
            writer.line("    }")
        else:
            emit_number_check(writer, item, name, path, indent="    ")
        return
    if item.kind == "list":
        frozen = f"frozen{pascal(item.json_name)}"
        element = dart_type(item).removesuffix("?")
        if item.optional:
            writer.line(
                f"    final {frozen} = {name} == null ? null : {element}.unmodifiable({name});"
            )
            writer.line(f"    if ({frozen} != null) {{")
            emit_length_check(writer, item, frozen, path, indent="      ")
            emit_list_item_checks(writer, item, frozen, path, indent="      ")
            writer.line("    }")
        else:
            writer.line(f"    final {frozen} = {element}.unmodifiable({name});")
            emit_length_check(writer, item, frozen, path, indent="    ")
            emit_list_item_checks(writer, item, frozen, path, indent="    ")
        return
    # enums, bools, and nested objects are checked by their own constructors.


def emit_string_check(writer: Writer, item: Field, name: str, path: str, indent: str) -> None:
    if item.checker:
        writer.line(f"{indent}{item.checker}({name}, {path});")
        return
    extra = string_args(item, "")
    tail = "".join(f", {arg}" for arg in extra)
    writer.line(f"{indent}validateString({name}, {path}{tail});")


def emit_number_check(writer: Writer, item: Field, name: str, path: str, indent: str) -> None:
    if item.checker:
        writer.line(f"{indent}{item.checker}({name}, {path});")
        return
    extra = number_args(item)
    tail = "".join(f", {arg}" for arg in extra)
    writer.line(f"{indent}validateNumber({name}, {path}{tail});")


def emit_list_item_checks(
    writer: Writer, item: Field, receiver: str, path: str, indent: str
) -> None:
    inner = item.item
    if inner is None or inner.kind != "string":
        return
    writer.line(f"{indent}for (final item in {receiver}) {{")
    emit_string_check(writer, inner, "item", path, indent + "  ")
    writer.line(f"{indent}}}")


def emit_length_check(writer: Writer, item: Field, receiver: str, path: str, indent: str) -> None:
    if item.min_items is not None:
        if item.min_items == 1:
            condition = f"{receiver}.isEmpty"
        else:
            condition = f"{receiver}.length < {item.min_items}"
        writer.line(f"{indent}if ({condition}) {{")
        writer.line(
            f"{indent}  throw LingoProtocolException(path: {path}, "
            f"message: '至少需要 {item.min_items} 项，实际有 ${{{receiver}.length}} 项。');"
        )
        writer.line(f"{indent}}}")
    if item.max_items is not None:
        writer.line(f"{indent}if ({receiver}.length > {item.max_items}) {{")
        writer.line(
            f"{indent}  throw LingoProtocolException(path: {path}, "
            f"message: '最多允许 {item.max_items} 项，实际有 ${{{receiver}.length}} 项。');"
        )
        writer.line(f"{indent}}}")


def emit_property_count(writer: Writer, cls: ClassType, path_expr: str) -> None:
    writer.line("    final present = <Object?>[")
    for item in cls.fields:
        if item.optional:
            writer.line(f"      {item.dart_name},")
        else:
            writer.line("      true,")
    writer.line("    ].where((item) => item != null).length;")
    args = [f"present: present"]
    if cls.min_properties is not None:
        args.append(f"minProperties: {cls.min_properties}")
    if cls.max_properties is not None:
        args.append(f"maxProperties: {cls.max_properties}")
    writer.line(f"    checkPropertyCount({path_expr}, {', '.join(args)});")


def emit_checker(item: Checker, patterns: dict[str, str]) -> list[str]:
    writer = Writer()
    for line in doc_comment(item.description):
        writer.line(line)
    if item.kind == "string":
        writer.line(f"void {item.name}(String value, String path) {{")
        extra = []
        if item.min_length is not None:
            extra.append(f"minLength: {item.min_length}")
        if item.max_length is not None:
            extra.append(f"maxLength: {item.max_length}")
        if item.pattern is not None:
            var = f"_{camel(item.name.removeprefix('check'))[0].lower() + camel(item.name.removeprefix('check'))[1:]}Pattern"
            # checkLanguageCode -> languageCode
            tail = item.name.removeprefix("check")
            var = "_" + tail[:1].lower() + tail[1:] + "Pattern"
            patterns[var] = item.pattern
            extra.append(f"pattern: {var}")
        if item.format is not None:
            extra.append(f"format: {dart_string(item.format)}")
        tail = "".join(f", {arg}" for arg in extra)
        writer.line(f"  validateString(value, path{tail});")
        writer.line("}")
        return writer.lines
    writer.line(f"void {item.name}(double value, String path) {{")
    extra = []
    if item.minimum is not None:
        extra.append(f"minimum: {dart_number(item.minimum)}")
    if item.maximum is not None:
        extra.append(f"maximum: {dart_number(item.maximum)}")
    tail = "".join(f", {arg}" for arg in extra)
    writer.line(f"  validateNumber(value, path{tail});")
    writer.line("}")
    return writer.lines


def needs_of(classes: list[ClassType], own_file: str, class_files: dict[str, str]) -> set[str]:
    needs = {"decode"}
    for cls in classes:
        for item in cls.fields:
            needs |= field_needs(item, own_file, class_files)
    return needs


def field_needs(item: Field, own_file: str, class_files: dict[str, str]) -> set[str]:
    needs: set[str] = set()
    if item.checker:
        needs.add("common")
    if item.kind == "enum":
        needs.add("enums")
    if item.kind == "object" and item.type_name is not None:
        token = class_files[item.type_name].removesuffix(".dart")
        if f"{token}.dart" != own_file:
            needs.add(token)
    if item.item is not None:
        needs |= field_needs(item.item, own_file, class_files)
    if item.pattern and item.checker is None:
        needs.add("patterns")
    return needs


def emit_library(
    file_name: str,
    classes: list[ClassType],
    checkers: list[Checker],
    needs: set[str],
) -> str:
    patterns: dict[str, str] = {}
    body: list[str] = []
    for checker in checkers:
        body.extend(emit_checker(checker, patterns))
        body.append("")
    for cls in classes:
        body.extend(emit_class(cls, patterns))
        body.append("")
    writer = Writer()
    writer.line(HEADER.rstrip("\n"))
    writer.line("")
    writer.line("import 'dart:convert';")
    writer.line("")
    writer.line("import '../decode.dart';")
    for imported in sorted(need for need in needs if need not in {"decode", "patterns"}):
        if imported == "enums":
            writer.line("import 'enums.dart';")
        elif imported == "common":
            writer.line("import 'common.dart';")
        else:
            writer.line(f"import '{imported}';")
    if patterns or body:
        writer.line("")
    for var, pattern in patterns.items():
        # patterns collected from checkers use the full var name already.
        var_name = var if var.startswith("_") else f"_{var}Pattern"
        writer.line(f"final RegExp {var_name} = RegExp({dart_raw(pattern)});")
        writer.line("")
    # The class emitter stored field dart names, not `_namePattern`, via setdefault(item.dart_name).
    # Checker emitter stores the full `_languageCodePattern` key. Normalize below if needed.
    writer.lines.extend(body)
    text = writer.text()
    return text


def render() -> dict[str, str]:
    docs, by_id = load_docs()
    enums, checkers, classes = compile_model(docs, by_id)
    class_files = {cls.name: file_for(cls.doc_key) for cls in classes}
    files: dict[str, str] = {}

    enum_writer = Writer()
    enum_writer.line(HEADER.rstrip("\n"))
    enum_writer.line("")
    enum_writer.line("import '../decode.dart';")
    enum_writer.line("")
    for item in enums:
        enum_writer.lines.extend(emit_enum(item))
        enum_writer.line("")
    files["lib/src/generated/enums.dart"] = enum_writer.text()

    grouped: dict[str, list[ClassType]] = {
        "common.dart": [],
        "turn_output.dart": [],
        "turn_analysis.dart": [],
        "weakness_plan.dart": [],
    }
    for cls in classes:
        grouped[file_for(cls.doc_key)].append(cls)

    for file_name, group in grouped.items():
        needs = needs_of(group, file_name, class_files)
        needs.discard(file_name.removesuffix(".dart"))
        file_checkers = checkers if file_name == "common.dart" else []
        files[f"lib/src/generated/{file_name}"] = emit_library(
            file_name, group, file_checkers, needs
        )

    payload = Writer()
    payload.line(HEADER.rstrip("\n"))
    payload.line("")
    payload.line("import 'dart:convert';")
    payload.line("")
    payload.line("import '../decode.dart';")
    payload.line("import 'turn_analysis.dart';")
    payload.line("import 'turn_output.dart';")
    payload.line("import 'weakness_plan.dart';")
    payload.line("")
    payload.line("/// Decodes one v0 payload by its `schema_name`.")
    payload.line("///")
    payload.line("/// 不认识的 `schema_name` 会抛出 [LingoProtocolException]，不会猜测类型。")
    payload.line("Object decodePayload(Object? json) {")
    payload.line("  if (json is! Map) {")
    payload.line("    throw const LingoProtocolException(path: '/', message: '期望 JSON 对象。');")
    payload.line("  }")
    payload.line("  final name = json['schema_name'] as Object?;")
    payload.line("  switch (name) {")
    payload.line("    case 'turn_output':")
    payload.line("      return TurnOutput.fromJson(json);")
    payload.line("    case 'turn_analysis':")
    payload.line("      return TurnAnalysis.fromJson(json);")
    payload.line("    case 'weakness_plan':")
    payload.line("      return WeaknessPlan.fromJson(json);")
    payload.line("    default:")
    payload.line("      throw LingoProtocolException(")
    payload.line("        path: '/schema_name',")
    payload.line("        message:")
    payload.line("            '未知的 schema_name ${jsonEncode(name)}。'")
    payload.line("            '允许：turn_output、turn_analysis、weakness_plan。'")
    payload.line("            '不认识的契约不会被猜测。',")
    payload.line("      );")
    payload.line("  }")
    payload.line("}")
    payload.line("")
    files["lib/src/generated/payload.dart"] = payload.text()

    barrel = Writer()
    barrel.line("/// Immutable Dart types for the lingo_protocol v0 turn contracts.")
    barrel.line("///")
    barrel.line("/// The files under `src/generated` come from `schema/*.schema.json`.")
    barrel.line("/// Regenerate them with `tool/generate_types.py`. Unknown JSON fields")
    barrel.line("/// and unknown enum values throw [LingoProtocolException].")
    barrel.line("library;")
    barrel.line("")
    barrel.line("export 'src/decode.dart' show LingoProtocolException;")
    barrel.line("export 'src/generated/common.dart';")
    barrel.line("export 'src/generated/enums.dart';")
    barrel.line("export 'src/generated/payload.dart';")
    barrel.line("export 'src/generated/turn_analysis.dart';")
    barrel.line("export 'src/generated/turn_output.dart';")
    barrel.line("export 'src/generated/weakness_plan.dart';")
    barrel.line("export 'src/turn_id.dart' show generateTurnId;")
    barrel.line("")
    files["lib/lingo_protocol.dart"] = barrel.text()
    return files


def format_tree(paths: list[Path]) -> None:
    subprocess.run(["dart", "format", *[str(path) for path in paths]], check=True)


def write_files(files: dict[str, str], root: Path) -> list[Path]:
    written = []
    for relative, content in files.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        written.append(path)
    format_tree(written)
    return written


def check_files(files: dict[str, str]) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_root = Path(tmp)
        # dart format follows the package language version in
        # .dart_tool/package_config.json. A bare temp directory is formatted
        # as the latest SDK and will not match this package.
        for name in ("pubspec.yaml", "pubspec.lock"):
            source = ROOT / name
            if source.is_file():
                (tmp_root / name).write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
        written = []
        for relative, content in files.items():
            path = tmp_root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            written.append(path)
        subprocess.run(
            ["dart", "pub", "get", "--offline"],
            cwd=tmp_root,
            check=True,
            stdout=subprocess.DEVNULL,
        )
        format_tree(written)
        failed = False
        for path in written:
            relative = path.relative_to(tmp).as_posix()
            expected = ROOT / relative
            actual = path.read_text(encoding="utf-8")
            if not expected.is_file():
                print(f"missing {relative}", file=sys.stderr)
                failed = True
                continue
            current = expected.read_text(encoding="utf-8")
            if current != actual:
                print(f"stale {relative}", file=sys.stderr)
                diff = difflib.unified_diff(
                    current.splitlines(keepends=True),
                    actual.splitlines(keepends=True),
                    fromfile=f"a/{relative}",
                    tofile=f"b/{relative}",
                )
                sys.stderr.writelines(diff)
                failed = True
        if failed:
            print(
                "Generated Dart is stale. Run python3 packages/lingo_protocol/tool/generate_types.py",
                file=sys.stderr,
            )
            return 1
    print("generated Dart matches the schema")
    return 0


def main() -> int:
    files = render()
    if "--check" in sys.argv:
        return check_files(files)
    write_files(files, ROOT)
    for relative in files:
        print(f"wrote {relative}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
