"""Compare transform.xsl with klibgen.transform_xsl_shim.

Run with:
    cd scripts && uv run pytest
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import cast

from lxml import etree, html

from klibgen.transform_xsl_shim import transform_html_file

REPO_ROOT = Path(__file__).resolve().parents[3]
POSTS_DIR = REPO_ROOT / "legacy" / "klibert_pl" / "posts"
XSLT_PATH = REPO_ROOT / "legacy" / "klibert_pl" / "build" / "templates" / "transform.xsl"


@dataclass(frozen=True)
class Difference:
    path: str
    message: str


def transform_with_xslt(path: Path, stylesheet: etree.XSLT) -> etree._Element:
    root = html.fromstring(path.read_text())
    name = path.stem
    result = stylesheet(
        root,
        fname=etree.XSLT.strparam(name),
        link=etree.XSLT.strparam(name),
        pubdate=etree.XSLT.strparam(""),
    )
    return result.getroot()


def compare_dom(expected: etree._Element, actual: etree._Element, path: str = "/") -> Difference | None:
    difference = None
    expected_attrs = {cast(str, name): cast(str, value) for name, value in expected.attrib.items()}
    actual_attrs = {cast(str, name): cast(str, value) for name, value in actual.attrib.items()}

    if _node_tag(expected) != _node_tag(actual):
        difference = Difference(path, f"tag differs: expected {_node_tag(expected)!r}, got {_node_tag(actual)!r}")
    elif expected.text != actual.text:
        difference = Difference(path, f"text differs: expected {expected.text!r}, got {actual.text!r}")
    elif expected.tail != actual.tail:
        difference = Difference(path, f"tail differs: expected {expected.tail!r}, got {actual.tail!r}")
    elif expected_attrs != actual_attrs:
        difference = Difference(
            path,
            f"attributes differ: expected {expected_attrs!r}, got {actual_attrs!r}",
        )
    elif len(expected) != len(actual):
        difference = Difference(path, f"child count differs: expected {len(expected)}, got {len(actual)}")
    if difference is not None:
        return difference

    for index, (expected_child, actual_child) in enumerate(zip(expected, actual, strict=False), start=1):
        child_path = f"{path}/{_node_tag(expected_child)}[{index}]"
        difference = compare_dom(expected_child, actual_child, child_path)
        if difference is not None:
            return difference
    return None


def _node_tag(node: etree._Element) -> str:
    if isinstance(node.tag, str):
        return etree.QName(node).localname
    return str(node.tag)

blacklist = [
    "/home/cji/priv/klibgen-gt/legacy/klibert_pl/posts/raspi-elixir.html",
]

def collect_posts(paths: list[Path]) -> list[Path]:
    if not paths:
        paths = [POSTS_DIR]

    posts: list[Path] = []
    for path in paths:
        if path.is_dir():
            posts.extend(sorted(path.glob("*.html")))
        else:
            posts.append(path)
    return [path for path in posts if path.read_text().strip() and str(path) not in blacklist]


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compare the XSLT transform with the Python shim.")
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="HTML files or directories. Defaults to legacy/klibert_pl/posts/.",
    )
    parser.add_argument(
        "--keep-going",
        action="store_true",
        help="Report all mismatches instead of stopping at the first one.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    posts = collect_posts(args.paths)
    stylesheet = etree.XSLT(etree.parse(str(XSLT_PATH)))

    failures = 0
    for post in posts:
        expected = transform_with_xslt(post, stylesheet)
        actual = transform_html_file(post)
        difference = compare_dom(expected, actual)
        if difference is None:
            continue

        failures += 1
        print(f"FAIL {post.relative_to(REPO_ROOT)}: {difference.path}: {difference.message}", file=sys.stderr)
        print("XSLT snippet:", html.tostring(expected, encoding="unicode")[:600], file=sys.stderr)
        print("Shim snippet:", html.tostring(actual, encoding="unicode")[:600], file=sys.stderr)
        if not args.keep_going:
            return 1

    if failures:
        print(f"{failures} transform comparison(s) failed out of {len(posts)}.", file=sys.stderr)
        return 1

    print(f"All {len(posts)} non-empty post transform comparison(s) matched.")
    return 0


def test_python_transform_matches_xslt_for_legacy_posts() -> None:
    stylesheet = etree.XSLT(etree.parse(str(XSLT_PATH)))

    for post in collect_posts([POSTS_DIR]):
        expected = transform_with_xslt(post, stylesheet)
        print(post)
        actual = transform_html_file(post)
        difference = compare_dom(expected, actual)
        assert difference is None, (
            f"{post.relative_to(REPO_ROOT)}: {difference.path}: {difference.message}\n"
            f"XSLT snippet: {html.tostring(expected, encoding='unicode')[:600]}\n"
            f"Shim snippet: {html.tostring(actual, encoding='unicode')[:600]}"
        )


if __name__ == "__main__":
    raise SystemExit(main())
