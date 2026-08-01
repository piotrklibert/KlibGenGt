export UV_CACHE_DIR := justfile_directory() / "tmp/uv-cache"

bootstrap: bootstrap-download

doctor context="default":
    uv run klibgen-build doctor {{quote(context)}}

doctor-json context="default":
    uv run klibgen-build doctor {{quote(context)}} --json

status context="default":
    uv run klibgen-build status {{quote(context)}}

status-json context="default":
    uv run klibgen-build status {{quote(context)}} --json

resolve context="default":
    uv run klibgen-build resolve {{quote(context)}}

resolve-update context="default":
    uv run klibgen-build resolve {{quote(context)}} --update

build target="l02" context="default":
    uv run klibgen-build build {{quote(target)}} {{quote(context)}}

rebuild target="l02" context="default":
    uv run klibgen-build build {{quote(target)}} {{quote(context)}} --force

run profile="base" context="default":
    uv run klibgen-build run {{quote(profile)}} {{quote(context)}}

clean-runs context="default":
    uv run klibgen-build clean-runs {{quote(context)}}

snapshot run_id:
    uv run klibgen-build snapshot {{quote(run_id)}}

resume snapshot_id:
    uv run klibgen-build resume {{quote(snapshot_id)}}

discard run_or_snapshot_id:
    uv run klibgen-build discard {{quote(run_or_snapshot_id)}}

promote source_id packages context="default":
    uv run klibgen-build promote {{quote(source_id)}} {{quote(packages)}} {{quote(context)}}

context-list:
    uv run klibgen-build context-list

context-create context revision="@" template="default":
    uv run klibgen-build context-create {{quote(context)}} {{quote(revision)}} {{quote(template)}}

context-remove context:
    uv run klibgen-build context-remove {{quote(context)}}

worktree-add context role repository revision="HEAD":
    uv run klibgen-build worktree-add {{quote(context)}} {{quote(role)}} {{quote(repository)}} {{quote(revision)}}

worktree-remove context role:
    uv run klibgen-build worktree-remove {{quote(context)}} {{quote(role)}}

pin context layer name="":
    uv run klibgen-build pin {{quote(context)}} {{quote(layer)}} {{quote(name)}}

unpin name:
    uv run klibgen-build unpin {{quote(name)}}

gc:
    uv run klibgen-build gc

gc-dry-run:
    uv run klibgen-build gc --dry-run

prune:
    uv run klibgen-build prune

prune-dry-run:
    uv run klibgen-build prune --dry-run

# Open a timestamped, read-only map of committed build definitions and generated state.
build-map context="gui":
    uv run klibgen-build build-map {{quote(context)}}

# Render both the aggregate overview and complete relationship graph to PNG.
build-map-png output_dir="":
    uv run klibgen-build build-map-png {{quote(output_dir)}}

# Export the versioned host inventory consumed by the Mondrian presentation.
build-map-json output="tmp/build-map/inventory.json":
    uv run klibgen-build build-map-json {{quote(output)}}

test-build-tools:
    uv run python -m unittest discover -s build/tests -v

check: test-build-tools doctor test

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

push-src-to-export:
    ./scripts/push-src-to-export.sh

pull-export-to-src:
    ./scripts/pull-export-to-src.sh

gui:
    uv run klibgen-build launch gui gui

gui-context context:
    uv run klibgen-build launch gui {{quote(context)}}

gui-fresh context="gui":
    uv run klibgen-build gui-fresh {{quote(context)}}

gui-snapshot snapshot_id:
    uv run klibgen-build gui-snapshot {{quote(snapshot_id)}}

snapshot-list context="gui":
    uv run klibgen-build snapshot-list {{quote(context)}}

snapshot-current context="gui":
    uv run klibgen-build snapshot-current {{quote(context)}}

snapshot-select snapshot_id context="gui":
    uv run klibgen-build snapshot-select {{quote(snapshot_id)}} {{quote(context)}}

snapshot-clear context="gui":
    uv run klibgen-build snapshot-clear {{quote(context)}}

gui-refresh-clear context="gui":
    uv run klibgen-build gui-refresh-clear {{quote(context)}}

load context="default":
    uv run klibgen-build load {{quote(context)}}

test context="default":
    uv run klibgen-build test {{quote(context)}}

test-one test_class selector context="default":
    uv run klibgen-build test-one {{quote(test_class)}} {{quote(selector)}} {{quote(context)}}

test-one-json test_class selector context="default":
    uv run klibgen-build test-one {{quote(test_class)}} {{quote(selector)}} {{quote(context)}} --json

test-diagnose run_or_attempt_id:
    uv run klibgen-build test-diagnose {{quote(run_or_attempt_id)}}

test-diagnose-json run_or_attempt_id:
    uv run klibgen-build test-diagnose {{quote(run_or_attempt_id)}} --json

test-fresh context="default":
    KLIBGEN_STATE_ROOT=artifacts/fresh-layered uv run klibgen-build test {{quote(context)}} --fresh

check-type-pragmas context="default":
    uv run klibgen-build check-type-pragmas {{quote(context)}}

smoke context="default":
    uv run klibgen-build smoke {{quote(context)}}

eval expr profile="cli" context="default":
    GT_EVAL={{quote(expr)}} uv run klibgen-build eval {{quote(profile)}} {{quote(context)}}

# List real managed desktop clients with PID, geometry, title, and command.
windows title_regex=".*":
    uv run klibgen-build host windows list --title-regex {{quote(title_regex)}}

# Capture the one visible window matching the title into tmp/screenshots/.
screenshot title_regex="^Glamorous Toolkit$":
    uv run klibgen-build host windows screenshot --title-regex {{quote(title_regex)}}

code-search query kind="all" context="default":
    uv run klibgen-build image code search {{quote(query)}} --kind {{quote(kind)}} --context {{quote(context)}}

code-class class_name context="default":
    uv run klibgen-build image code class {{quote(class_name)}} --context {{quote(context)}}

code-method class_name selector side="instance" context="default":
    uv run klibgen-build image code method {{quote(class_name)}} {{quote(selector)}} --side {{quote(side)}} --context {{quote(context)}}

lepiter-search query search_in="text" context="default":
    uv run klibgen-build image lepiter search {{quote(query)}} --in {{quote(search_in)}} --context {{quote(context)}}

lepiter-export uid context="default":
    uv run klibgen-build image lepiter export --uid {{quote(uid)}} --context {{quote(context)}}

profile command:
    uv run klibgen-build host profile -- sh -c {{quote(command)}}

clean-runtime:
    rm -rf vendor/gt vendor/gt.zip vendor/gt.unpack vendor/gt-build/workspaces pharo-local gt-local *.image *.changes *.sources *.log *.fuel *.ombu *.bak
    find artifacts -mindepth 1 ! -name .gitkeep -exec rm -rf {} +
