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

smoke:
    ./scripts/gt --headless ./scripts/smoke.st

eval expr:
    GT_EVAL='{{expr}}' ./scripts/gt --headless ./scripts/eval.st

clean-runtime:
    rm -rf vendor/gt vendor/gt.zip vendor/gt.unpack vendor/gt-build/workspaces pharo-local gt-local *.image *.changes *.sources *.log *.fuel *.ombu *.bak
    find artifacts -mindepth 1 ! -name .gitkeep -exec rm -rf {} +
