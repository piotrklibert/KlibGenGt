bootstrap:
    ./scripts/bootstrap-gt.sh

gui: bootstrap
    ./scripts/gt

load: bootstrap
    ./scripts/gt --headless ./scripts/load-project.st

test: bootstrap
    ./scripts/gt --headless ./scripts/test.st

smoke: bootstrap
    ./scripts/gt --headless ./scripts/smoke.st

eval expr: bootstrap
    GT_EVAL='{{expr}}' ./scripts/gt --headless ./scripts/eval.st

clean-runtime:
    rm -rf vendor/gt vendor/gt.zip vendor/gt.unpack pharo-local gt-local *.image *.changes *.sources *.log *.fuel *.ombu *.bak
    find artifacts -mindepth 1 ! -name .gitkeep -exec rm -rf {} +
