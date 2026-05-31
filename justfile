# ©AngelaMos | 2026
# justfile

default:
    @just --list

build:
    zig build

run *ARGS:
    zig build run -- {{ARGS}}

scrape *ARGS:
    zig build -Doptimize=ReleaseSafe && ./zig-out/bin/erhm scrape {{ARGS}}

analyze *ARGS:
    zig build -Doptimize=ReleaseSafe && ./zig-out/bin/erhm analyze {{ARGS}}

static:
    zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl
    @echo "binary -> zig-out/bin/erhm"
    @file zig-out/bin/erhm

test:
    zig build test

fmt:
    zig fmt build.zig build.zig.zon src/

fmt-check:
    zig fmt --check build.zig src/

clean:
    rm -rf .zig-cache zig-out zig-pkg
