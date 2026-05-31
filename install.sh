#!/usr/bin/env bash
# ©AngelaMos | 2026
# install.sh

set -euo pipefail

setup_colors() {
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
        YELLOW=$'\033[33m'; CYAN=$'\033[36m'; MAGENTA=$'\033[35m'; RESET=$'\033[0m'
    else
        BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; MAGENTA=""; RESET=""
    fi
}

banner() {
    printf '%s' "${CYAN}${BOLD}"
    cat <<'ART'

   __ _____           _
  / /|__  /____ ___  (_)___  ___  _____
 / __//_ </ __ `__ \/ / __ \/ _ \/ ___/
/ /____/ / / / / / / / / / /  __/ /
\__/____/_/ /_/ /_/_/_/ /_/\___/_/
ART
    printf '%s\n' "${RESET}"
    printf '%s\n\n' "  ${DIM}reddit research miner · zig · zero dependencies${RESET}"
}

say()  { printf '%s\n' "${GREEN}▸${RESET} $*"; }
warn() { printf '%s\n' "${YELLOW}!${RESET} $*" >&2; }
die()  { printf '%s\n' "${RED}✗ $*${RESET}" >&2; exit 1; }

usage() {
    cat <<'USAGE'
install.sh — build and install t3miner

usage:
  ./install.sh [options]

options:
  --prefix DIR    install directory (default: ~/.local/bin)
  --static        build a static x86_64-linux-musl binary
  --no-install    build only, do not copy the binary
  -h, --help      show this help
USAGE
}

require_zig() {
    command -v zig >/dev/null 2>&1 || die "Zig not found. Get 0.16+ from https://ziglang.org/download/ (or: snap install zig --classic --beta)"
    local v major rest minor
    v="$(zig version)"
    major="${v%%.*}"; rest="${v#*.}"; minor="${rest%%.*}"
    if [ "$major" -eq 0 ] && [ "$minor" -lt 16 ]; then
        die "Zig $v is too old — t3miner needs 0.16.0 or newer."
    fi
    say "Zig $v detected."
}

build() {
    if [ -n "${STATIC:-}" ]; then
        say "Building ${BOLD}ReleaseSafe${RESET}, static ${MAGENTA}x86_64-linux-musl${RESET} ..."
        zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl
    else
        say "Building ${BOLD}ReleaseSafe${RESET} for your native target ..."
        zig build -Doptimize=ReleaseSafe
    fi
}

main() {
    setup_colors
    trap 'printf "%s\n" "${RED}✗ install failed${RESET}" >&2' ERR

    local prefix="${PREFIX:-$HOME/.local/bin}"
    STATIC=""
    local do_install=1
    while [ $# -gt 0 ]; do
        case "$1" in
            --prefix) prefix="$2"; shift 2 ;;
            --prefix=*) prefix="${1#*=}"; shift ;;
            --static) STATIC=1; shift ;;
            --no-install) do_install=0; shift ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown option: $1" ;;
        esac
    done

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$script_dir"
    [ -f build.zig ] || die "run install.sh from inside the t3miner repo (no build.zig here)."

    banner
    require_zig
    build

    local src="$script_dir/zig-out/bin/t3miner"
    [ -f "$src" ] || die "build produced no binary at $src"
    local size; size="$(du -h "$src" | cut -f1)"

    if [ "$do_install" -eq 0 ]; then
        say "Built ${BOLD}$src${RESET} (${size}). Skipping install (--no-install)."
        return 0
    fi

    mkdir -p "$prefix"
    install -m 0755 "$src" "$prefix/t3miner"
    say "Installed ${BOLD}t3miner${RESET} → ${CYAN}$prefix/t3miner${RESET} (${size})"

    case ":$PATH:" in
        *":$prefix:"*) : ;;
        *) warn "$prefix is not on your PATH. Add this to your shell rc:"
           printf '%s\n' "      ${DIM}export PATH=\"$prefix:\$PATH\"${RESET}" ;;
    esac

    printf '\n'
    printf '%s\n' "  ${GREEN}done.${RESET} mine some reddit:"
    printf '%s\n' "    ${DIM}t3miner scrape --subs quant,cpp,fpga${RESET}"
    printf '%s\n' "    ${DIM}t3miner analyze${RESET}"
}

main "$@"
