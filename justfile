# ©AngelaMos | 2026
# justfile

default:
    @just --list

build:
    zig build

run *ARGS:
    zig build run -- {{ARGS}}

scrape *ARGS:
    zig build -Doptimize=ReleaseSafe && ./zig-out/bin/t3miner scrape {{ARGS}}

analyze *ARGS:
    zig build -Doptimize=ReleaseSafe && ./zig-out/bin/t3miner analyze {{ARGS}}

static:
    zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl
    @echo "binary -> zig-out/bin/t3miner"
    @file zig-out/bin/t3miner

test:
    zig build test

clean:
    rm -rf .zig-cache zig-out zig-pkg
