#!/usr/bin/env bash
# Functional tests for hooks/block-main-branch-edits.js
# Run: bash testing/hook-tests.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$SCRIPT_DIR/hooks/block-main-branch-edits.js"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

pass=0
fail=0

# Dev-marker repo on main, with a linked worktree on a feature branch
DEV_REPO="$WORKDIR/dev-repo"
mkdir -p "$DEV_REPO"
git -C "$DEV_REPO" init -q -b main
git -C "$DEV_REPO" config user.email "test@example.com"
git -C "$DEV_REPO" config user.name "Test"
echo '{}' > "$DEV_REPO/package.json"
git -C "$DEV_REPO" add package.json
git -C "$DEV_REPO" commit -q -m "init"

WORKTREE_DIR="$WORKDIR/dev-repo-feature"
git -C "$DEV_REPO" worktree add -q -b feature/x "$WORKTREE_DIR" >/dev/null

# Node's fs/path calls (unlike git itself) don't understand Git Bash's
# POSIX-style /tmp/... paths on Windows - they need a real Windows path for
# file_path (Write/Edit), which resolves via path.dirname()/fs.existsSync()
# in pure Node rather than through git's own MSYS-aware path handling.
if command -v cygpath >/dev/null 2>&1; then
  DEV_REPO_WIN="$(cygpath -w "$DEV_REPO")"
else
  DEV_REPO_WIN="$DEV_REPO"
fi

# Non-dev-marker repo on master (no package.json etc.)
PLAIN_REPO="$WORKDIR/plain-repo"
mkdir -p "$PLAIN_REPO"
git -C "$PLAIN_REPO" init -q -b master
git -C "$PLAIN_REPO" config user.email "test@example.com"
git -C "$PLAIN_REPO" config user.name "Test"
echo "hello" > "$PLAIN_REPO/README.md"
git -C "$PLAIN_REPO" add README.md
git -C "$PLAIN_REPO" commit -q -m "init"

run_case() {
  local description="$1" tool_name="$2" cwd="$3" extra_json="$4" expected="$5"
  local payload
  payload="$(node -e '
    const cwd = process.argv[1];
    const extra = JSON.parse(process.argv[2]);
    const toolName = process.argv[3];
    process.stdout.write(JSON.stringify({ tool_name: toolName, cwd, tool_input: extra }));
  ' "$cwd" "$extra_json" "$tool_name")"

  local output decision
  output="$(printf '%s' "$payload" | node "$HOOK")"
  if [ -z "$output" ]; then
    decision="allow"
  else
    decision="$(printf '%s' "$output" | node -e '
      let d="";
      process.stdin.on("data", c => d += c);
      process.stdin.on("end", () => {
        try { process.stdout.write(JSON.parse(d).hookSpecificOutput.permissionDecision); }
        catch (e) { process.stdout.write("parse-error"); }
      });
    ')"
  fi

  if [ "$decision" = "$expected" ]; then
    pass=$((pass+1))
    echo "PASS: $description"
  else
    fail=$((fail+1))
    echo "FAIL: $description (expected $expected, got $decision)"
  fi
}

run_case "1: dev repo, main, Bash git commit -> deny" \
  "Bash" "$DEV_REPO" '{"command":"git commit -am wip"}' "deny"

run_case "2: dev repo, main, Bash git worktree add -> allow" \
  "Bash" "$DEV_REPO" '{"command":"git worktree add ../x -b y"}' "allow"

run_case "3: dev repo, feature worktree, Bash git commit -> allow" \
  "Bash" "$WORKTREE_DIR" '{"command":"git commit -am wip"}' "allow"

WRITE_EXTRA_JSON="$(node -e 'process.stdout.write(JSON.stringify({file_path: require("path").join(process.argv[1], "index.js")}))' "$DEV_REPO_WIN")"
run_case "4: dev repo, main, Write -> deny" \
  "Write" "$DEV_REPO" "$WRITE_EXTRA_JSON" "deny"

run_case "5: dev repo, main, Bash git stash -> deny" \
  "Bash" "$DEV_REPO" '{"command":"git stash"}' "deny"

run_case "6: dev repo, main, Bash git status -> allow" \
  "Bash" "$DEV_REPO" '{"command":"git status"}' "allow"

run_case "7: plain repo, master, Bash git commit -> allow" \
  "Bash" "$PLAIN_REPO" '{"command":"git commit -am wip"}' "allow"

run_case "8: dev repo, main, Bash git branch -d merged -> allow" \
  "Bash" "$DEV_REPO" '{"command":"git branch -d merged-branch"}' "allow"

run_case "9: dev repo, main, Bash git branch -D unmerged -> deny" \
  "Bash" "$DEV_REPO" '{"command":"git branch -D unmerged-branch"}' "deny"

run_case "10: dev repo, main, Bash git pull -> deny" \
  "Bash" "$DEV_REPO" '{"command":"git pull origin main"}' "deny"

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
