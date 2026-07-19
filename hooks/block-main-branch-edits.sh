#!/usr/bin/env bash
# PreToolUse guard for Write|Edit: refuse edits while checked out on main/master.
# Rationale: new tasks should branch/worktree first; editing main directly
# leaks into other parallel sessions working off main.
set -u

input="$(cat)"
file_path="$(printf '%s' "$input" | node -e '
let d="";
process.stdin.on("data",c=>d+=c);
process.stdin.on("end",()=>{
  try { const j=JSON.parse(d); process.stdout.write(j.tool_input && j.tool_input.file_path ? j.tool_input.file_path : ""); }
  catch(e){ process.stdout.write(""); }
});
' <<< "$input")"

if [ -z "$file_path" ]; then
  exit 0
fi

dir="$(dirname "$file_path")"
[ -d "$dir" ] || dir="$(pwd)"

git_dir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null)"
if [ -z "$git_dir" ]; then
  exit 0
fi

branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null)"

repo_root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"
is_dev_project=0
if [ -n "$repo_root" ]; then
  for marker in package.json pyproject.toml go.mod Cargo.toml pom.xml build.gradle build.gradle.kts Gemfile composer.json; do
    if [ -f "$repo_root/$marker" ]; then
      is_dev_project=1
      break
    fi
  done
fi

if [ "$is_dev_project" -ne 1 ]; then
  exit 0
fi

case "$branch" in
  main|master)
    reason="Refusing to edit $file_path: currently checked out on '$branch'. Create a worktree/branch for this task first (see superpowers:using-git-worktrees) instead of editing the shared main branch directly."
    node -e '
      const reason = process.argv[1];
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: reason
        }
      }));
    ' "$reason"
    ;;
  *)
    exit 0
    ;;
esac
