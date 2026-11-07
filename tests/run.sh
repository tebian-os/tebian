#!/bin/bash
# ==============================================================================
# TEBIAN CHECKS
# Fast, side-effect-free checks for the whole tree: every shell script must
# parse and pass shellcheck at error level, Python helpers must compile, and
# a few invariants that have bitten us before are pinned down here so they
# can't quietly come back. Run from anywhere: bash tests/run.sh
#
# tests/ is left out of the ISO (build-iso.sh) — it's for developers only.
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fails=0
pass() { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; fails=$((fails + 1)); }

# Shell scripts are found by shebang, not extension: most tools in scripts/
# have none. Tracked files only, so local junk doesn't fail the run.
shell_files=()
py_files=()
while IFS= read -r f; do
    [ -f "$f" ] || continue
    first=$(head -c 64 "$f" 2>/dev/null | tr -d '\0' | head -n1 || true)
    case "$first" in
        '#!'*python*) py_files+=("$f") ;;
        '#!'*bash*|'#!'*/sh*) shell_files+=("$f") ;;
        *) [[ "$f" == *.sh ]] && shell_files+=("$f") ;;
    esac
done < <(git ls-files 2>/dev/null || find . -type f -not -path './.git/*')

# 1. Syntax
bad=0
for f in "${shell_files[@]}"; do
    bash -n "$f" 2>/dev/null || { fail "bash -n: $f"; bad=1; }
done
[ "$bad" = 0 ] && pass "bash -n: ${#shell_files[@]} scripts parse"

# 2. shellcheck at error level (warnings are a judgement call; errors aren't)
if command -v shellcheck >/dev/null; then
    if out=$(shellcheck -S error -s bash "${shell_files[@]}" 2>&1); then
        pass "shellcheck -S error: clean"
    else
        echo "$out" | head -40
        fail "shellcheck reported errors"
    fi
else
    echo -e "${YELLOW}!${NC} shellcheck not installed — skipped (sudo apt install shellcheck)"
fi

# 3. Python helpers compile (no bytecode written into the tree)
for f in "${py_files[@]}"; do
    python3 -I -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$f" \
        || fail "python syntax: $f"
done
[ "${#py_files[@]}" -gt 0 ] && pass "python: ${#py_files[@]} files parse"

# 4. Patched sway must rank above Debian's base package but below any Debian
#    stable/security update, or those updates never install.
if command -v dpkg >/dev/null; then
    rev=$(grep -oE '\+[0-9a-z]*tebian' scripts/tebian-build-sway | head -1 || true)
    v="1.10.1-2${rev}1"
    if [ -z "$rev" ]; then
        fail "sway version: can't find the +…tebian suffix in tebian-build-sway"
    elif dpkg --compare-versions "$v" gt 1.10.1-2 &&
         dpkg --compare-versions "$v" lt 1.10.1-2+deb13u1; then
        pass "sway version $v sits between Debian's base and its updates"
    else
        fail "sway version $v blocks Debian updates or loses to the base package"
    fi
fi

# 4b. greetd's own config parser is stricter than TOML (no multi-line
#     strings): a file it can't read means no login screen at all. greetd
#     stops later on (no greeter user here) — only parse errors count.
if command -v greetd >/dev/null; then
    out=$(timeout 5 greetd -c configs/greetd/config.toml 2>&1 || true)
    if grep -qiE 'configuration error|unable to read|expected' <<< "$out"; then
        fail "greetd can't parse configs/greetd/config.toml:"; echo "$out" | head -3
    else
        pass "greetd parses configs/greetd/config.toml"
    fi
else
    echo -e "${YELLOW}!${NC} greetd not installed — login-screen config not checked"
fi

# 5. Nothing that doesn't belong to users may ship: scratch notes and TODO
#    files in the tree are rsync'd straight into the ISO.
stray=$(git ls-files | grep -iE '(^|/)(TODO|NOTES|scratch)[^/]*$|(^|/)CLAUDE\.md$' || true)
if [ -n "$stray" ]; then
    fail "stray dev files would ship in the ISO:"; echo "$stray"
else
    pass "no stray notes/TODO files in the tree"
fi

# 6. Install docs must use HTTPS (tebian.org/install over plain HTTP is
#    a tamperable first hop).
# A bare "curl tebian.org/..." counts too: curl defaults to http://.
plain=$(git grep -nE 'http://(www\.)?tebian\.org|(curl|wget)[^|]*[[:space:]](www\.)?tebian\.org' \
            -- ':!tests' || true)
if [ -n "$plain" ]; then
    fail "plain-http tebian.org links:"; echo "$plain"
else
    pass "tebian.org links are https"
fi

echo
if [ "$fails" -eq 0 ]; then
    echo -e "${GREEN}All checks passed.${NC}"
else
    echo -e "${RED}$fails check(s) failed.${NC}"; exit 1
fi
