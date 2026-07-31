bootstrap: bootstrap-download

doctor context="default":
    python3 -m build.klibgen_build doctor {{quote(context)}}

doctor-json context="default":
    python3 -m build.klibgen_build doctor {{quote(context)}} --json

status context="default":
    python3 -m build.klibgen_build status {{quote(context)}}

status-json context="default":
    python3 -m build.klibgen_build status {{quote(context)}} --json

resolve context="default":
    python3 -m build.klibgen_build resolve {{quote(context)}}

resolve-update context="default":
    python3 -m build.klibgen_build resolve {{quote(context)}} --update

build target="l02" context="default":
    python3 -m build.klibgen_build build {{quote(target)}} {{quote(context)}}

rebuild target="l02" context="default":
    python3 -m build.klibgen_build build {{quote(target)}} {{quote(context)}} --force

run profile="base" context="default":
    python3 -m build.klibgen_build run {{quote(profile)}} {{quote(context)}}

clean-runs context="default":
    python3 -m build.klibgen_build clean-runs {{quote(context)}}

snapshot run_id:
    python3 -m build.klibgen_build snapshot {{quote(run_id)}}

resume snapshot_id:
    python3 -m build.klibgen_build resume {{quote(snapshot_id)}}

discard run_id:
    python3 -m build.klibgen_build discard {{quote(run_id)}}

promote source_id packages context="default":
    python3 -m build.klibgen_build promote {{quote(source_id)}} {{quote(packages)}} {{quote(context)}}

test-build-tools:
    python3 -m unittest discover -s build/tests -v

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

gui context="gui":
    python3 -m build.klibgen_build launch gui {{quote(context)}}

load context="default":
    python3 -m build.klibgen_build load {{quote(context)}}

test context="default":
    python3 -m build.klibgen_build test {{quote(context)}}

test-fresh context="default":
    KLIBGEN_STATE_ROOT=artifacts/fresh-layered python3 -m build.klibgen_build test {{quote(context)}} --fresh

check-type-pragmas context="default":
    python3 -m build.klibgen_build check-type-pragmas {{quote(context)}}

smoke context="default":
    python3 -m build.klibgen_build smoke {{quote(context)}}

eval expr profile="cli" context="default":
    GT_EVAL={{quote(expr)}} python3 -m build.klibgen_build eval {{quote(profile)}} {{quote(context)}}

clean-runtime:
    rm -rf vendor/gt vendor/gt.zip vendor/gt.unpack vendor/gt-build/workspaces pharo-local gt-local *.image *.changes *.sources *.log *.fuel *.ombu *.bak
    find artifacts -mindepth 1 ! -name .gitkeep -exec rm -rf {} +
