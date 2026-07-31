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

gui:
    ./scripts/gt

load:
    ./scripts/gt --headless ./scripts/load-project.st

test:
    ./scripts/gt --headless ./scripts/test.st

test-fresh: push-src-to-export bootstrap
    ./scripts/test-fresh.sh

check-type-pragmas: push-src-to-export
    ./scripts/gt --headless ./scripts/check-type-pragmas.st

smoke:
    ./scripts/gt --headless ./scripts/smoke.st

eval expr:
    GT_EVAL={{quote(expr)}} ./scripts/gt --headless ./scripts/eval.st

clean-runtime:
    rm -rf vendor/gt vendor/gt.zip vendor/gt.unpack vendor/gt-build/workspaces pharo-local gt-local *.image *.changes *.sources *.log *.fuel *.ombu *.bak
    find artifacts -mindepth 1 ! -name .gitkeep -exec rm -rf {} +
