"""Deterministically export Pydantic wire models as Tonel record classes."""

from __future__ import annotations

import types
from pathlib import Path
from typing import Any, Literal, Union, get_args, get_origin

from pydantic import BaseModel, JsonValue

from .json_models import ALL_MODELS, WireModel


GENERATED_MARKER = "Generated from klibgen_build.json_models; DO NOT EDIT."
DEFAULT_PACKAGE = "KlibGenGt-JsonModels"
INDEX_BEGIN = "  - GENERATED-JSON-MODELS-BEGIN"
INDEX_END = "  - GENERATED-JSON-MODELS-END"


def _camel(name: str) -> str:
    if name.endswith("_"):
        name = name[:-1] + "_value"
    head, *tail = name.split("_")
    return head + "".join(part[:1].upper() + part[1:] for part in tail)


def _quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _literal(value: Any) -> str:
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, str):
        return _quote(value)
    if isinstance(value, (int, float)):
        return repr(value)
    raise TypeError(f"unsupported literal value {value!r}")


def _is_json_value(annotation: Any) -> bool:
    return annotation is JsonValue or repr(annotation) in {"JsonValue", "typing.Any"}


def _type_spec(annotation: Any) -> str:
    if _is_json_value(annotation) or annotation is Any:
        return "#(#any)"
    if annotation is type(None):
        return "#(#nil)"
    if annotation is bool:
        return "#(#boolean)"
    if annotation is int:
        return "#(#integer)"
    if annotation is float:
        return "#(#number)"
    if annotation is str:
        return "#(#string)"
    if isinstance(annotation, type) and issubclass(annotation, WireModel):
        return f"#(#model #{annotation.smalltalk_name})"
    origin = get_origin(annotation)
    arguments = get_args(annotation)
    if origin is Literal:
        return "#(#literal #(" + " ".join(_literal(value) for value in arguments) + "))"
    if origin in {types.UnionType, Union}:
        return "#(#union #(" + " ".join(_type_spec(value) for value in arguments) + "))"
    if origin in {tuple, list}:
        if len(arguments) == 2 and arguments[1] is Ellipsis:
            arguments = arguments[:1]
        if len(arguments) != 1:
            raise TypeError(f"only homogeneous JSON arrays are supported, got {annotation!r}")
        return f"#(#array {_type_spec(arguments[0])})"
    if origin is dict:
        if len(arguments) != 2 or arguments[0] is not str:
            raise TypeError(f"JSON dictionaries require string keys, got {annotation!r}")
        return f"#(#dictionary {_type_spec(arguments[1])})"
    raise TypeError(f"unsupported Pydantic annotation {annotation!r}")


def _field_type_spec(field: Any) -> str:
    base = _type_spec(field.annotation)
    constraints: list[str] = []
    for metadata in field.metadata:
        for attribute in ("ge", "gt", "le", "lt", "min_length", "max_length", "pattern"):
            value = getattr(metadata, attribute, None)
            if value is not None:
                name = {"min_length": "minLength", "max_length": "maxLength"}.get(attribute, attribute)
                constraints.append(f"#(#{name} {_literal(value)})")
    if not constraints:
        return base
    return f"#(#constrained {base} #({' '.join(constraints)}))"


def _pragma_type(annotation: Any) -> str:
    if _is_json_value(annotation) or annotation is Any:
        return "#Any"
    if annotation is type(None):
        return "#nil"
    if annotation is bool:
        return "#Boolean"
    if annotation is int:
        return "#Integer"
    if annotation is float:
        return "#Number"
    if annotation is str:
        return "#String"
    if isinstance(annotation, type) and issubclass(annotation, WireModel):
        return f"#{annotation.smalltalk_name}"
    origin = get_origin(annotation)
    arguments = get_args(annotation)
    if origin is Literal:
        primitive_types = {type(value) for value in arguments}
        return _pragma_type(primitive_types.pop()) if len(primitive_types) == 1 else "#Any"
    if origin in {types.UnionType, Union}:
        non_nil = [value for value in arguments if value is not type(None)]
        if len(non_nil) == 1 and len(non_nil) != len(arguments):
            value = _pragma_type(non_nil[0]).removeprefix("#")
            return f"#({value} | UndefinedObject)"
        values = [
            "UndefinedObject" if value is type(None) else _pragma_type(value).removeprefix("#")
            for value in arguments
        ]
        return "#(" + " | ".join(values) + ")"
    if origin in {tuple, list}:
        item = arguments[0]
        nested = _pragma_type(item).removeprefix("#")
        return f"#(Array<{nested}>)"
    if origin is dict:
        value = _pragma_type(arguments[1]).removeprefix("#")
        return f"#(Dictionary<String, {value}>)"
    raise TypeError(f"unsupported pragma annotation {annotation!r}")


def _class_comment(model: type[WireModel], slots: list[tuple[str, str, str]]) -> str:
    lines = [
        GENERATED_MARKER,
        "",
        f"Immutable JSON record generated from `{model.__name__}`.",
        "",
        "- Slots",
    ]
    for slot, wire_name, pragma_type in slots:
        lines.append(f"  - `{slot}` (`{pragma_type}`, `accessing`) - Value of JSON field `{wire_name}`.")
    lines.extend(["- Public API"])
    for slot, _, _ in slots:
        lines.extend([
            f"  - {{{{gtMethod:{model.smalltalk_name}>>#{slot}}}}}",
            f"    Answer the immutable `{slot}` field value.",
        ])
    return "\n".join(lines)


def render_model(model: type[WireModel]) -> str:
    slots: list[tuple[str, str, str]] = []
    specifications: list[str] = []
    for python_name, field in model.model_fields.items():
        slot = _camel(python_name)
        wire_name = field.alias or python_name
        pragma_type = _pragma_type(field.annotation)
        slots.append((slot, wire_name, pragma_type))
        specifications.append(
            f"\t\t#({_quote(wire_name)} {_quote(slot)} "
            f"{'true' if field.is_required() else 'false'} {_field_type_spec(field)})"
        )
    if len({slot for slot, _, _ in slots}) != len(slots):
        raise ValueError(f"Smalltalk slot collision in {model.__name__}")
    class_comment = _class_comment(model, slots).replace('"', '""')
    instance_variables = "\n".join(f"\t\t'{slot}'" for slot, _, _ in slots)
    if instance_variables:
        instance_variables = "\n\t#instVars : [\n" + ",\n".join(
            f"\t\t'{slot}'" for slot, _, _ in slots
        ) + "\n\t],"
    schema = "nil" if model.schema_name is None else _quote(model.schema_name)
    allows_extras = model.model_config.get("extra") == "allow"
    methods = []
    for slot, _, pragma_type in slots:
        methods.append(
            "{ #category : 'accessing' }\n"
            f"{model.smalltalk_name} >> {slot} [\n"
            f"\t<return: {pragma_type}>\n"
            f"\t^ self defensiveJsonValue: {slot}\n]"
        )
    return (
        f'"{class_comment}"\n'
        "Class {\n"
        f"\t#name : '{model.smalltalk_name}',\n"
        "\t#superclass : 'KGJsonRecord',"
        f"{instance_variables}\n"
        f"\t#category : '{DEFAULT_PACKAGE}',\n"
        f"\t#package : '{DEFAULT_PACKAGE}'\n"
        "}\n\n"
        "{ #category : 'json schema' }\n"
        f"{model.smalltalk_name} class >> jsonAllowsExtras [\n"
        "\t<return: #Boolean>\n"
        f"\t^ {'true' if allows_extras else 'false'}\n]\n\n"
        "{ #category : 'json schema' }\n"
        f"{model.smalltalk_name} class >> jsonFieldSpecifications [\n"
        "\t<return: #(Array<(Array<Any>)>)>\n"
        "\t^ {\n" + ".\n".join(specifications) + " }\n]\n\n"
        "{ #category : 'json schema' }\n"
        f"{model.smalltalk_name} class >> jsonSchemaName [\n"
        "\t<return: #(String?)>\n"
        f"\t^ {schema}\n]\n\n"
        + "\n\n".join(methods)
        + "\n"
    )


def expected_files() -> dict[str, str]:
    return {
        f"{model.smalltalk_name}.class.st": render_model(model)
        for model in ALL_MODELS
    }


def _expected_index_section() -> str:
    entries = [
        f"  - {{{{gtClass:{model.smalltalk_name}}}}} - Generated immutable JSON record for `{model.__name__}`."
        for model in ALL_MODELS
    ]
    return "\n".join((INDEX_BEGIN, *entries, INDEX_END))


def _updated_index(contents: str) -> str:
    if INDEX_BEGIN not in contents or INDEX_END not in contents:
        raise ValueError("KlibGenGt class index lacks generated JSON model markers")
    before, remainder = contents.split(INDEX_BEGIN, 1)
    _, after = remainder.split(INDEX_END, 1)
    return before + _expected_index_section() + after


def export_tonel(output: Path, *, check: bool = False) -> list[str]:
    """Write generated model classes or report drift without changing files."""

    expected = expected_files()
    actual_generated: dict[str, str] = {}
    if output.is_dir():
        for path in output.glob("*.class.st"):
            contents = path.read_text(encoding="utf-8")
            if GENERATED_MARKER in contents:
                actual_generated[path.name] = contents
    drift = sorted(
        {name for name, contents in expected.items() if actual_generated.get(name) != contents}
        | (actual_generated.keys() - expected.keys())
    )
    index_path = output.parent / "KlibGenGt-Core" / "KlibGenGt.class.st"
    index_contents = index_path.read_text(encoding="utf-8")
    expected_index = _updated_index(index_contents)
    if expected_index != index_contents:
        drift.append("KlibGenGt.class.st")
    if check:
        return drift
    output.mkdir(parents=True, exist_ok=True)
    for name in actual_generated.keys() - expected.keys():
        (output / name).unlink()
    for name, contents in expected.items():
        if actual_generated.get(name) != contents:
            (output / name).write_text(contents, encoding="utf-8")
    if expected_index != index_contents:
        index_path.write_text(expected_index, encoding="utf-8")
    return drift


__all__ = ["DEFAULT_PACKAGE", "GENERATED_MARKER", "expected_files", "export_tonel", "render_model"]
