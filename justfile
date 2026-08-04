export UV_CACHE_DIR := justfile_directory() / "tmp/uv-cache"

bootstrap: bootstrap-download

bootstrap-download:
    ./scripts/bootstrap-gt.sh

bootstrap-build-clean:
    ./scripts/bootstrap-gt-source.sh clean

bootstrap-build-patched:
    ./scripts/bootstrap-gt-source.sh patched

fetch-gt-sources-clean:
    ./scripts/fetch-gt-sources.sh clean

fetch-gt-sources-patched:
    ./scripts/fetch-gt-sources.sh patched

doctor:
    uv run klibgen-build doctor

doctor-json:
    uv run klibgen-build doctor --json

status:
    uv run klibgen-build status

status-json:
    uv run klibgen-build status --json

recipe-list:
    uv run klibgen-build recipe list

recipe-resolve target="cli":
    uv run klibgen-build recipe resolve {{quote(target)}}

build target="cli":
    uv run klibgen-build build {{quote(target)}}

load:
    uv run klibgen-build load

test:
    uv run klibgen-build test

test-one test_class selector:
    uv run klibgen-build test-one {{quote(test_class)}} {{quote(selector)}}

test-one-json test_class selector:
    uv run klibgen-build test-one {{quote(test_class)}} {{quote(selector)}} --json

# A fresh disposable session always materializes from the canonical artifact.
test-fresh:
    uv run klibgen-build test --fresh

check-type-pragmas:
    uv run klibgen-build check-type-pragmas

lint-source:
    uv run klibgen-build lint-source

lint-source-fix:
    uv run klibgen-build lint-source --fix

smoke:
    uv run klibgen-build smoke

eval expr:
    uv run klibgen-build eval {{quote(expr)}}

gui:
    uv run klibgen-build gui

gui-fresh:
    uv run klibgen-build gui --fresh

workspace-status:
    uv run klibgen-build workspace status

workspace-reset:
    uv run klibgen-build workspace reset --confirm

staging-list:
    uv run klibgen-build staging list

staging-create name:
    uv run klibgen-build staging create {{quote(name)}}

staging-reset name:
    uv run klibgen-build staging reset {{quote(name)}}

staging-promote name:
    uv run klibgen-build staging promote {{quote(name)}}

agentic name:
    uv run klibgen-build agentic {{quote(name)}} --test

refactor-catalog:
    uv run klibgen-build refactor catalog

refactor-describe refactoring_id:
    uv run klibgen-build refactor describe {{quote(refactoring_id)}}

refactor-applicable name request_file:
    uv run klibgen-build refactor applicable {{quote(name)}} --file {{quote(request_file)}}

refactor-preview name request_file:
    uv run klibgen-build refactor preview {{quote(name)}} --file {{quote(request_file)}}

refactor-apply name request_file plan_id:
    uv run klibgen-build refactor apply {{quote(name)}} --file {{quote(request_file)}} --expect {{quote(plan_id)}}

inventory:
    uv run klibgen-build inventory

# Inspect recipe sequences, artifacts, refs, workspace, staging, and storage.
build-map:
    uv run klibgen-build build-map

# Render the generic recipe/artifact relationship graph.
build-map-png output_dir="tmp/build-map":
    uv run klibgen-build build-map-png {{quote(output_dir)}}

gc: gc-dry-run

gc-dry-run:
    uv run klibgen-build gc --dry-run

gc-apply:
    uv run klibgen-build gc --apply

# Delete all project-local generated build state so the next operation rebuilds from scratch.
prune:
    uv run klibgen-build prune

ui-status:
    uv run klibgen-build ui status

ui-spaces:
    uv run klibgen-build ui spaces

ui-tree:
    uv run klibgen-build ui tree

ui-click node:
    uv run klibgen-build ui act click --node {{quote(node)}}

ui-wait state node:
    uv run klibgen-build ui wait {{quote(state)}} --node {{quote(node)}}

ui-eval expr:
    uv run klibgen-build ui eval {{quote(expr)}}

windows title_regex=".*":
    uv run klibgen-build host windows list --title-regex {{quote(title_regex)}}

screenshot title_regex="^Glamorous Toolkit$":
    uv run klibgen-build host windows screenshot --title-regex {{quote(title_regex)}}

code-search query kind="all":
    uv run klibgen-build image code search {{quote(query)}} --kind {{quote(kind)}}

code-class class_name:
    uv run klibgen-build image code class {{quote(class_name)}}

code-method class_name selector side="instance":
    uv run klibgen-build image code method {{quote(class_name)}} {{quote(selector)}} --side {{quote(side)}}

code-class-methods class_name:
    uv run klibgen-build image code class-methods {{quote(class_name)}}

code-analyze class_name selector side="instance" depth="1":
    uv run klibgen-build image code analyze {{quote(class_name)}} {{quote(selector)}} --side {{quote(side)}} --depth {{quote(depth)}}

code-implementors selector:
    uv run klibgen-build image code implementors {{quote(selector)}}

code-senders selector:
    uv run klibgen-build image code senders {{quote(selector)}}

code-package-sets set_name="default":
    uv run klibgen-build image code package-sets {{quote(set_name)}}

lepiter-search query search_in="text":
    uv run klibgen-build image lepiter search {{quote(query)}} --in {{quote(search_in)}}

lepiter-export uid:
    uv run klibgen-build image lepiter export --uid {{quote(uid)}}

profile command:
    uv run klibgen-build host profile -- sh -c {{quote(command)}}

test-build-tools: check-json-models
    uv run python -m unittest discover -s build/tests -v

generate-json-models:
    uv run klibgen-build models export-tonel

check-json-models:
    uv run klibgen-build models export-tonel --check

check: test-build-tools doctor lint-source check-type-pragmas test
