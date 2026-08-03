from __future__ import annotations

import json
import logging
import os
import re
import sys
from pathlib import Path
from typing import Any, Callable

import click

from ..core import BuildPaths
from ..json_models import validate_named_record
from ..processes import ProcessExecutionError
from ..recipes import DEFAULT_TARGETS, STANDARD_ROLES


ERRORS = (OSError, ValueError, RuntimeError, TimeoutError, ProcessExecutionError)
POSITIVE_FLOAT = click.FloatRange(min=0.0, min_open=True)
POSITIVE_INT = click.IntRange(min=1)
TARGET = click.Choice(sorted(DEFAULT_TARGETS))
ROLE = click.Choice(STANDARD_ROLES)
JSON_OPTION = click.option("--json", "as_json", is_flag=True, help="Emit the structured result as JSON.")
logger = logging.getLogger(__name__)


class ArtifactKey(click.ParamType):
    name = "64-HEX-KEY"

    def convert(self, value: Any, param: click.Parameter | None, ctx: click.Context | None) -> str:
        value = str(value)
        if re.fullmatch(r"[0-9a-fA-F]{64}", value) is None:
            self.fail("must contain exactly 64 hexadecimal characters", param, ctx)
        return value.lower()


class BaseZeroInteger(click.ParamType):
    name = "INTEGER"

    def convert(self, value: Any, param: click.Parameter | None, ctx: click.Context | None) -> int:
        try:
            result = int(str(value), 0)
        except ValueError:
            self.fail(f"{value!r} is not a base-0 integer", param, ctx)
        if result < 1:
            self.fail("must be at least 1", param, ctx)
        return result


ARTIFACT_KEY = ArtifactKey()
WINDOW_ID = BaseZeroInteger()


def _regex(_ctx: click.Context, param: click.Parameter, value: str | None) -> str | None:
    if value is not None:
        try:
            re.compile(value)
        except re.error as error:
            raise click.BadParameter(f"invalid regular expression: {error}", param=param) from error
    return value


def _paths() -> BuildPaths:
    return BuildPaths.discover()


def _finish(ctx: click.Context, result: dict[str, Any], as_json: bool) -> None:
    emit(result, as_json)
    if not result.get("ok", True):
        ctx.exit(1)


def _run(ctx: click.Context, as_json: bool, operation: Callable[[], dict[str, Any]]) -> None:
    logger.debug("dispatching CLI command path=%s json=%s", ctx.command_path, as_json)
    try:
        _finish(ctx, operation(), as_json)
    except click.exceptions.Exit:
        raise
    except ERRORS as error:
        logger.debug("CLI command failed path=%s", ctx.command_path, exc_info=True)
        click.echo(f"{ctx.command_path}: {error}", err=True)
        ctx.exit(2)


def _expression(expression: str | None, file: Path | None, stdin: bool, *, allow_environment: bool = False) -> str:
    choices = sum((expression is not None, file is not None, stdin))
    if choices == 0 and allow_environment and os.environ.get("GT_EVAL") is not None:
        return os.environ["GT_EVAL"]
    if choices != 1:
        raise ValueError("provide exactly one expression, --file, or --stdin")
    if file is not None:
        return file.read_text(encoding="utf-8")
    if stdin:
        return sys.stdin.read()
    assert expression is not None
    return expression


def source_options(function: Callable[..., Any]) -> Callable[..., Any]:
    function = click.option("--file", type=click.Path(path_type=Path, exists=True, file_okay=True, dir_okay=False, readable=True), help="Read the expression or request from this file.")(function)
    function = click.option("--stdin", is_flag=True, help="Read the expression or request from standard input.")(function)
    return function


def _emit_code_scope(data: dict[str, Any]) -> None:
    scope = data.get("scope")
    if scope is None:
        return
    print(
        f"scope: {scope['set']} "
        f"({scope['effectivePackageCount']} packages; {scope['fingerprint']})"
    )
    counts = data.get("counts")
    if counts:
        print(
            f"matches: total={counts['total']} in-scope={counts['inScope']} "
            f"out-of-scope={counts['outOfScope']} displayed={counts['displayed']} "
            f"truncated={counts['inScopeTruncated']}"
        )

def emit(result: dict[str, Any], as_json: bool) -> None:
    """Format one structured result without performing any CLI dispatch."""
    if "schema" in result:
        result = validate_named_record(result)
    if as_json:
        print(json.dumps(result, indent=2, sort_keys=True))
        return
    if not result.get("ok", True):
        error = result.get("error")
        if isinstance(error, dict):
            message = error.get("message")
        else:
            message = None
        print(message or result.get("message") or "operation failed")
        return
    operation = result["operation"]
    if operation == "v2.recipe.list":
        for target in result["targets"]:
            print(f"{target['name']:12} recipe={target['recipe']} roles={','.join(target['roles'])}")
    elif operation == "v2.recipe.resolve":
        print(f"target: {result['target']} -> {result['outputKey']}")
        for step in result["steps"]:
            print(f"{step['role']:24} {step['checkpoint']:8} {step['outputKey']}")
    elif operation == "v2.build":
        for artifact in result["artifacts"]:
            print(f"{'reused' if artifact['reused'] else 'built ':6} {artifact['role']:24} {artifact['path']}")
    elif operation in {"test", "test-one", "check-type-pragmas", "agentic"}:
        report = result.get("data", {})
        print(f"Tests run: {report.get('runCount', 0)}, failures: {report.get('failureCount', 0)}, errors: {report.get('errorCount', 0)}")
    elif operation in {"eval", "smoke"}:
        print(result.get("data", {}).get("result", ""))
    elif operation == "inventory":
        print(f"inventory: {len(result['artifacts'])} artifacts, {len(result['references'])} refs, {len(result['workspaces'])} workspaces, {len(result['stagingAreas'])} staging areas")
        for item in result["artifacts"]:
            print(f"artifact {item.get('producingRole', '?'):24} {item.get('outputKey', '?')} {item['storage']['allocatedBytes']} allocated")
    elif operation == "gc":
        print(f"{result['mode']}: {len(result['remove'])} paths, {len(result['warnings'])} warnings")
        for item in result["remove"]:
            print(f"  {item['path']}")
    elif operation == "staging.list":
        for area in result["stagingAreas"]:
            print(f"{area['name']:20} {area['state']}")
    elif operation.startswith("staging."):
        print(f"{operation}: {result['path']}")
    elif operation == "source.lint":
        print(f"Tonel source is canonical ({result['fileCount']} .st files)")
    elif operation == "status":
        print(f"workspace: {result['workspace'].get('workspace', {}).get('state', 'missing')}")
        for status in result["statuses"]:
            print(f"{status.get('state', '?'):10} {status.get('outputKey', '?')}")
    elif operation == "doctor":
        for item in result["tools"] + result["checks"]:
            print(f"{'ok' if item['ok'] else 'FAIL':4} {item.get('name', item.get('path'))}")
    elif operation.startswith("ui.") or operation.startswith("host."):
        if operation in {"host.windows.list", "host.windows.wait"}:
            for window in result["data"]["windows"]:
                pid = "-" if window["pid"] is None else str(window["pid"])
                geometry = f"{window['width']}x{window['height']}+{window['x']}+{window['y']}"
                print(f"{window['idHex']}\t{pid}\t{geometry}\t{window['title']}\t{window['command']}")
        else:
            print(json.dumps(result.get("data", result), indent=2, sort_keys=True))
    elif operation in {"code.class", "code.method", "lepiter.export"}:
        print(result["data"]["text"], end="")
    elif operation == "code.search":
        _emit_code_scope(result["data"])
        for item in result["data"]["results"]:
            print(json.dumps(item, sort_keys=True))
    elif operation == "code.class-methods":
        _emit_code_scope(result["data"])
        for item in result["data"]["methods"]:
            print(
                f"\n--- {item['class']} {item['side']}>>#{item['selector']} "
                f"[{item['classification']}; {item['package']}] ---"
            )
            source = item.get("source", "")
            print(source, end="" if source.endswith("\n") else "\n")
    elif operation == "code.analyze":
        data = result["data"]
        _emit_code_scope(data)
        root = data["root"]
        print(f"root: {root['identity']}")
        analysis = root["analysis"]
        if "source" in analysis:
            print("\n--- root source ---")
            print(analysis["source"])
        graph = data["graph"]
        print(
            f"\ngraph: {len(graph['nodes'])} methods, {len(graph['edges'])} edges; "
            f"excluded candidates: {data['excludedCandidateCount']}"
        )
        for edge in graph["edges"]:
            cycle = " (cycle)" if edge["cycle"] else ""
            print(
                f"{edge['from']} --{edge['selector']} [{edge['resolution']}]--> "
                f"{edge['to']}{cycle}"
            )
    elif operation == "code.package-sets":
        for item in result["data"]["sets"]:
            print(f"{item['name']}\t{item['count']}\t{item['description']}")
            for package in item["packages"]:
                distance = item.get("distances", {}).get(package)
                print(f"  {package}" + (f"\tdepth={distance}" if distance is not None else ""))
    elif operation in {"code.class-info", "code.package-info"}:
        _emit_code_scope(result["data"])
        print(json.dumps(
            {key: value for key, value in result["data"].items() if key != "scope"},
            indent=2,
            sort_keys=True,
        ))
    elif operation in {"code.implementors", "code.senders", "code.references", "code.pragmas"}:
        _emit_code_scope(result["data"])
        for item in result["data"]["results"]:
            print(f"{item['class']}\t{item['side']}\t{item['selector']}\t{item['package']}")
    elif operation == "lepiter.search":
        for item in result["data"]["results"]:
            print(f"{item['database']}\t{item['uid']}\t{item['title']}\t{item['preview']}")
    else:
        print(json.dumps(result, indent=2, sort_keys=True))
