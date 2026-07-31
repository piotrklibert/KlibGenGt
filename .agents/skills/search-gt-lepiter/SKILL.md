---
name: search-gt-lepiter
description: Search documentation pages in Lepiter databases loaded by a fresh Glamorous Toolkit image and export exact pages as Markdown. Use when looking up GT Book documentation, project Lepiter notes, examples, explanations, or page content by title, text, database, or UID.
---

# Search GT Lepiter

Search in-image documentation instead of guessing GT APIs or relying only on web search. The default run includes every loaded database, including the GT Book and copied local Lepiter databases.

## Search, then export

Start with text search unless the request names a page:

```sh
just lepiter-search 'search filters' text default
just lepiter-search 'Moldable Agent Harness' title default
```

Search results include database, UID, title, and a short preview. Use the complete CLI to restrict databases, bound results, or consume JSON:

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image lepiter search 'search filters' \
  --in text --database 'Glamorous Toolkit Book' --limit 20 --context default --json
```

Use `--in title` for named pages and `--in text` for concepts or API fragments. Repeat `--database` to search several selected databases.

Export the full page after identifying the best result:

```sh
just lepiter-export 5iztl0m2zpym86t35lxj1xovw default
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image lepiter export \
  --uid 5iztl0m2zpym86t35lxj1xovw --context default --json
```

Exact titles are also accepted:

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image lepiter export \
  --title 'Querying with GT search filters by example' \
  --database 'Glamorous Toolkit Book' --context default
```

Prefer UID after discovery. If an exact title is ambiguous, use the candidate database/UID pairs from the error rather than guessing.

## Use the result

- Base claims about GT behavior on the exported page, not only its preview.
- Follow links by searching their page titles and exporting the relevant pages.
- Keep quotations short; summarize examples and verify APIs with `$search-gt-code` when implementation details matter.
- If the required page is absent, report which databases and search terms were checked before using another documentation source.
