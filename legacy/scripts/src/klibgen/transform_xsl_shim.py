#!/usr/bin/env python3
"""Apply the legacy blog post transform without invoking XSLT.

Example:
    uv run --project scripts transform-xsl-shim legacy/klibert_pl/posts/blog-changes.html

For many posts:
    uv run --project scripts transform-xsl-shim --output-dir /tmp/transformed-posts legacy/klibert_pl/posts/
"""

from __future__ import annotations

import argparse
import copy
import sys
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import cast
from xml.sax.saxutils import escape as xml_escape
from xml.sax.saxutils import quoteattr

from lxml import etree, html

REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_POSTS_DIR = REPO_ROOT / "legacy" / "klibert_pl" / "posts"


@dataclass(frozen=True)
class TransformParams:
    fname: str
    link: str
    pubdate: str = ""


TransformHandler = Callable[[etree._Element, TransformParams], etree._Element]


def transform_html_text(
    html_text: str,
    *,
    fname: str,
    link: str | None = None,
    pubdate: str = "",
) -> etree._Element:
    """Parse HTML and return the transformed DOM root."""
    root = html.fromstring(html_text)
    return transform_dom(root, TransformParams(fname=fname, link=link or fname, pubdate=pubdate))


def transform_html_file(
    path: Path,
    *,
    fname: str | None = None,
    link: str | None = None,
    pubdate: str = "",
) -> etree._Element:
    """Read an HTML file and return the transformed DOM root."""
    resolved_fname = fname if fname is not None else path.stem
    return transform_html_text(
        path.read_text(),
        fname=resolved_fname,
        link=link if link is not None else resolved_fname,
        pubdate=pubdate,
    )


def transform_dom(root: etree._Element, params: TransformParams) -> etree._Element:
    """Transform an already parsed DOM root."""
    return _transform_element(root, params)


def serialize_html(root: etree._Element) -> str:
    return cast(str, html.tostring(root, encoding="unicode"))


def _fragment(markup: str) -> etree._Element:
    return cast(etree._Element, html.fragment_fromstring(markup))


def _xpath_one(node: etree._Element, path: str) -> etree._Element:
    results = cast(list[etree._Element], node.xpath(path))
    return results[0]


def _transform_element(node: etree._Element, params: TransformParams) -> etree._Element:
    if not isinstance(node.tag, str):
        copied = copy.deepcopy(node)
        copied.tail = None
        return copied

    tag = etree.QName(node).localname
    handler: TransformHandler | None
    if tag == "note" and "outdated" in node.get("class", ""):
        handler = _transform_outdated_note
    else:
        handlers: dict[str, TransformHandler] = {
            "sub-header": _transform_sub_header,
            "h3": _transform_h3,
            "my-header": _transform_my_header,
            "header": _transform_legacy_header,
            "my-img": _transform_my_img,
            "bq": _transform_bq,
            "notice": _transform_notice,
            "note": _transform_note,
        }
        handler = handlers.get(tag)

    if handler is not None:
        return handler(node, params)

    copied = etree.Element(node.tag)
    _copy_attributes(node, copied)
    _append_child_nodes(copied, node, params)
    return copied


def _transform_sub_header(node: etree._Element, params: TransformParams) -> etree._Element:
    out = _fragment('<h3 class="sub"></h3>')
    _copy_attributes(node, out)
    _append_child_nodes(out, node, params)
    return out


def _transform_h3(node: etree._Element, params: TransformParams) -> etree._Element:
    out = _fragment('<h3 class="sub"></h3>')
    if "id" in node.attrib:
        out.set("id", f"{params.fname}-{cast(str, node.attrib['id'])}")
    for name, value in node.attrib.items():
        if etree.QName(name).localname != "id":
            out.set(name, value)
    _append_child_nodes(out, node, params)
    return out


def _transform_my_header(node: etree._Element, params: TransformParams) -> etree._Element:
    source_time = node.find("time")
    out = _fragment(
        f'<header><h1 class="entry-title"><a class="title-link" id={quoteattr(params.fname)}'
        f' href={quoteattr(f"/posts/{params.link}.html")} title="Read on separate page"></a>'
        f'<a href={quoteattr(f"#{params.link}")} class="robaczek"'
        ' title="Link to this place on current page">\n          \u00b6\n        </a></h1>'
        f'<p class="meta">\n        Last updated on: <time>{xml_escape(_string_value(source_time))}</time></p>'
        "</header>"
    )
    title_link = _xpath_one(out, "./h1/a")
    _append_my_header_title_nodes(title_link, node, params)

    subtitle = node.find("sub-title")
    if subtitle is not None and _has_child_nodes(subtitle):
        subtitle_h3 = _fragment('<h3 class="subtitle"></h3>')
        _append_child_nodes(subtitle_h3, subtitle, params)
        out.insert(1, subtitle_h3)

    return out


def _transform_legacy_header(node: etree._Element, params: TransformParams) -> etree._Element:
    return _fragment(
        f'<header><h1 class="entry-title"><a class="title-link" id={quoteattr(params.fname)}'
        f' href={quoteattr(f"posts/{params.link}.html")} title="Read on separate page">'
        f'{xml_escape(_first_direct_text(node.find("h1")))}</a><a href={quoteattr(f"#{params.link}")}'
        ' class="robaczek" title="Link to this place on current page">\n          \u00b6\n        </a></h1>'
        f'<p class="meta"><time>{xml_escape(_first_direct_text(node.find("p/time")))}</time></p></header>'
    )


def _transform_my_img(node: etree._Element, params: TransformParams) -> etree._Element:
    del params
    src = node.get("src", "")
    out = _fragment(
        f'<div style="text-align: center" class="post-image">'
        f'<a title="click to enlarge" href={quoteattr(src)}><img></a></div>'
    )
    img = _xpath_one(out, "./a/img")
    _copy_attributes(node, img)
    img.set("src", src)
    return out


def _transform_bq(node: etree._Element, params: TransformParams) -> etree._Element:
    out = _fragment('<div><blockquote class="no-quote"><code></code></blockquote></div>')
    code = _xpath_one(out, "./blockquote/code")
    _append_child_nodes(code, node, params)
    return out


def _transform_notice(node: etree._Element, params: TransformParams) -> etree._Element:
    out = _fragment('<div class="alert alert-info"></div>')
    _append_child_nodes(out, node, params)
    return out


def _transform_note(node: etree._Element, params: TransformParams) -> etree._Element:
    out = _fragment('<div class="note"><strong>NOTE: </strong></div>')
    _append_child_nodes(out, node, params)
    return out


def _transform_outdated_note(node: etree._Element, params: TransformParams) -> etree._Element:
    class_attr = f" class={quoteattr(cast(str, node.attrib['class']))}" if "class" in node.attrib else ""
    out = _fragment(f'<div{class_attr}><div class="outdated"><strong>NOTE:</strong></div></div>')
    inner = _xpath_one(out, "./div")
    _append_child_nodes(inner, node, params)
    return out


def _copy_attributes(source: etree._Element, target: etree._Element) -> None:
    for name, value in source.attrib.items():
        target.set(name, value)


def _append_my_header_title_nodes(
    target: etree._Element,
    source: etree._Element,
    params: TransformParams,
) -> None:
    _append_text(target, source.text)
    for child in source:
        if isinstance(child.tag, str) and etree.QName(child).localname == "l":
            target.append(_transform_element(child, params))
        _append_text(target, child.tail)


def _append_child_nodes(
    target: etree._Element,
    source: etree._Element,
    params: TransformParams,
) -> None:
    _append_text(target, source.text)
    for child in source:
        target.append(_transform_element(child, params))
        _append_text(target, child.tail)


def _append_text(target: etree._Element, text: str | None) -> None:
    if text is None:
        return
    if len(target):
        last_child = target[-1]
        last_child.tail = (last_child.tail or "") + text
    else:
        target.text = (target.text or "") + text


def _has_child_nodes(node: etree._Element) -> bool:
    return node.text is not None or len(node) > 0


def _string_value(node: etree._Element | None) -> str:
    if node is None:
        return ""
    return cast(str, node.xpath("string()"))


def _first_direct_text(node: etree._Element | None) -> str:
    if node is None:
        return ""
    return node.text or ""


def _collect_inputs(paths: list[Path]) -> list[Path]:
    if not paths:
        paths = [DEFAULT_POSTS_DIR]

    files: list[Path] = []
    for path in paths:
        if path.is_dir():
            files.extend(sorted(path.glob("*.html")))
        else:
            files.append(path)
    return files


def _write_output(root: etree._Element, source: Path, output: Path | None, output_dir: Path | None) -> None:
    rendered = serialize_html(root)
    if output is not None:
        output.write_text(rendered)
    elif output_dir is not None:
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / source.name).write_text(rendered)
    else:
        print(rendered, end="")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Transform legacy post HTML using a Python shim equivalent to transform.xsl.",
        epilog=(
            "Copy/paste example: "
            "uv run --project scripts transform-xsl-shim legacy/klibert_pl/posts/blog-changes.html"
        ),
    )
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="HTML files or directories of .html files. Defaults to legacy/klibert_pl/posts/.",
    )
    parser.add_argument("--output", type=Path, help="Write one transformed file here.")
    parser.add_argument("--output-dir", type=Path, help="Write transformed files into this directory.")
    parser.add_argument("--fname", help="Override the XSLT fname parameter. Only valid for one input.")
    parser.add_argument("--link", help="Override the XSLT link parameter. Only valid for one input.")
    parser.add_argument("--pubdate", default="", help="Accepted for parity with transform.xsl; currently unused.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    inputs = _collect_inputs(args.paths)

    if args.output and args.output_dir:
        print("--output and --output-dir are mutually exclusive", file=sys.stderr)
        return 2
    if args.output and len(inputs) != 1:
        print("--output can only be used with one input file", file=sys.stderr)
        return 2
    if len(inputs) > 1 and not args.output_dir:
        print("multiple inputs require --output-dir", file=sys.stderr)
        return 2
    if (args.fname or args.link) and len(inputs) != 1:
        print("--fname and --link can only be used with one input", file=sys.stderr)
        return 2

    for source in inputs:
        if not source.read_text().strip():
            if len(inputs) == 1:
                print(f"{source} is empty", file=sys.stderr)
                return 1
            continue
        root = transform_html_file(
            source,
            fname=args.fname,
            link=args.link,
            pubdate=args.pubdate,
        )
        _write_output(root, source, args.output, args.output_dir)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
