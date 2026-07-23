#!/usr/bin/env bash
# PreToolUse guard: refuse Write/Edit and mutating git Bash commands while
# checked out on main/master in a real dev project. Rationale: worktrees
# share the same .git (refs, refs/stash, objects) even though each has its
# own working directory/index. Mutating main directly - whether via
# Write/Edit or via a Bash git command like commit/stash/merge - leaks into
# other parallel sessions working off main. New tasks should branch/worktree
# first (see superpowers:using-git-worktrees). Actual logic lives in
# block-main-branch-edits.js (kept in JS to avoid fragile shell quoting
# around JSON parsing and git subprocess handling).
set -u
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$dir/block-main-branch-edits.js"
