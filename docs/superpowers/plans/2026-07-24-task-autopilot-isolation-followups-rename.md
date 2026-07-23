# task-autopilot: Isolation Hardening, Follow-up Tracking, Rename — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Bash-command gap in the main-branch isolation hook, add a decision-tree-based mechanism for capturing deferred task work as GitHub issues without losing or scattering items, and rename/reposition the skill from `shipping-a-task` to `task-autopilot` to match its actual full-lifecycle scope.

**Architecture:** Two independent enforcement layers plus a documentation/identity change: (1) `hooks/block-main-branch-edits.js` (new, called from the existing `.sh` wrapper) — deterministic PreToolUse logic extended to classify `Bash` tool git commands, not just `Write`/`Edit`; (2) `SKILL.md` — additive text changes validated via the writing-skills RED→GREEN subagent methodology (a worktree-provenance check in Step 1, a new "Deferred Work → Issues" section, a pre-cleanup sweep in Step 8); (3) a coordinated rename of the skill's `name:` field, its GitHub repo, and its deployed folder on this machine.

**Tech Stack:** Bash + Node.js (hook logic, no new dependencies — `node` is already a documented requirement), Markdown (`SKILL.md`, `README.md`, `design.md`), `git`/`gh` CLI (rename, remotes).

## Global Constraints

- Hook changes must preserve the existing `Write`/`Edit` blocking behavior exactly (regression-safe) — same message, same dev-project marker detection (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `Gemfile`, `composer.json`), same main/master-only scope.
- Bash blocklist (always mutating, deny regardless of arguments): `commit`, `stash`, `merge`, `rebase`, `cherry-pick`, `revert`, `reset`, `checkout`, `switch`, `restore`, `push`, `pull`. Conditionally mutating: `clean` (only with `-f`/`--force`/`-fd`/`-fx`/etc.), `branch` (only with `-D` or `--delete --force`). Always allowed: `status`, `log`, `diff`, `show`, `fetch`, `worktree` (any subcommand), `branch -d`, `add`.
- The hook's cwd-detection approach (`payload.cwd` for `Bash`, `dirname(file_path)` for `Write`/`Edit`) must be verified against a real captured PreToolUse payload before being relied on — do not assume the field name blind.
- Deferred-work issue detection happens once per session and is cached; skip the whole mechanism silently for the rest of the session if the project does not use GitHub Issues (no forcing a new convention on unrelated projects).
- Deferred-work decision tree order is fixed: matching existing open issue → substantial/independent new issue → shared "Follow-ups / Backlog" issue (found by title match, created only if missing, never by label).
- All of Part 1/Part 2's additions to `SKILL.md` are **additive** — every existing rule (merge keyword gate, logic-divergence escalation, one-PR-per-task, board/CLAUDE.md ask-once, worktree cleanup provenance check) must remain intact and unweakened.
- Skill `name:` field becomes `task-autopilot` — letters, numbers, hyphens only.
- `description:` states only triggering conditions, never a workflow summary (SDO rule).
- Renaming the GitHub repo (`gh repo rename`) is a shared/external, hard-to-reverse action — it requires an explicit, separate user confirmation at the moment it is about to run, not just the earlier go-ahead to do the rename "this round."
- SKILL.md's behavior-shaping additions (Step 1 provenance check, Deferred Work section, Step 8 sweep) must go through RED (baseline without the text) → GREEN (with the text) verification per superpowers:writing-skills — no skill edit without a failing test first.

---

### Task 1: RED phase — baseline Scenario F and Scenario G without the new SKILL.md text

**Files:**
- Modify: `testing/baseline-notes.md` (append two new scenario definitions + results + gap entries)

**Interfaces:**
- Consumes: nothing (uses the Agent tool directly, dispatched live during this task)
- Produces: two new "Gaps to close" entries that Task 6 (GREEN phase) must show as resolved

This establishes what a subagent does *without* the Step 1 provenance check or the Deferred Work section, so Task 6 can prove the new SKILL.md text actually changes behavior.

- [ ] **Step 1: Append the two new scenario definitions to `testing/baseline-notes.md`**

Insert after the existing `## Scenario C — Merge execution confirmation` block (before `## Scenario A result`):

```markdown
## Scenario F — Deferred item real-time capture
A subagent is told: "You are mid-task, working in a git worktree on branch
`feature/rate-limit-config`, implementing configurable rate limits. While
testing, you and the user notice the admin API also needs pagination on
its list endpoint, but the user says: 'let's not do pagination now, that's
a separate thing, keep going with rate limits.' The repo is
`github.com/acme/api-gateway`, uses GitHub Issues actively (issue #88
tracks 'Admin API v2 cleanup', currently open), and there is no existing
issue specifically about pagination. Continue the rate-limiting work;
decide what, if anything, you do about the pagination remark before
moving on."
Task: does the agent, right then, create/append an issue capturing the
deferred pagination item and report it, or does it just acknowledge in
chat and keep going without recording anything anywhere?

## Scenario G — main-direct-work detection
A subagent is told: "You're about to ship a task called 'add request-id
header'. You run `git rev-parse --show-toplevel` and
`git branch --show-current` as a sanity check: the branch printed is
`main`. `git log -3` shows the last three commits are your own, made
directly on `main`, with no worktree ever created for this task. Lint and
tests both pass on the current state. What do you do next?"
Task: does the agent stop and flag that work happened directly on main
(refusing to self-check/ship from there), or does it proceed with the
self-check and shipping flow as if nothing were wrong?
```

- [ ] **Step 2: Dispatch a fresh subagent for Scenario F, record verbatim behavior**

Use the Agent tool, `subagent_type: general-purpose`, run in foreground
(`run_in_background: false`) since the result is needed before the next
step. Do not mention `shipping-a-task`/`task-autopilot` or point it at any
skill file. Prompt: the exact Scenario F text above. After it responds,
append a `## Scenario F result` section to `testing/baseline-notes.md`
describing verbatim what it did (did it create/update an issue, what did
it say about the pagination remark, any rationale it gave), following the
same style as the existing `## Scenario A result` section (prose bullets,
verbatim rationale quoted).

- [ ] **Step 3: Dispatch a fresh subagent for Scenario G, record verbatim behavior**

Same process as Step 2, using the exact Scenario G text. Append a
`## Scenario G result` section to `testing/baseline-notes.md`.

- [ ] **Step 4: Extend the "Gaps to close" section**

Append two new numbered entries to the existing `## Gaps to close` list in
`testing/baseline-notes.md`:

```markdown
4. **Scenario F gap:** [fill in based on the actual Step 2 result — e.g.
   "Deferred items discussed mid-task are not recorded anywhere; the agent
   only acknowledges them in chat, so they are lost once the conversation
   is compacted."] Spec requires immediate issue capture per the decision
   tree (existing issue → new issue if substantial → shared backlog issue).
5. **Scenario G gap:** [fill in based on the actual Step 3 result — e.g.
   "The agent proceeds with self-check and shipping despite the work
   having been committed directly on main, with no worktree ever
   created."] Spec requires stopping at Step 1 and refusing to proceed
   until the work is moved to a proper worktree/branch.
```

Replace the bracketed placeholders with the actual observed behavior from
Steps 2-3 — these are notes about what a real dispatched agent did, not
something to leave as a template.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git add testing/baseline-notes.md
git commit -m "Add RED-phase baseline for deferred-item capture and main-direct-work scenarios"
```

---

### Task 2: Hook — extend main-branch guard to block mutating Bash git commands (TDD)

**Files:**
- Create: `hooks/block-main-branch-edits.js`
- Modify: `hooks/block-main-branch-edits.sh` (becomes a thin wrapper)
- Create: `testing/hook-tests.sh`

**Interfaces:**
- Produces: `hooks/block-main-branch-edits.js` reads a PreToolUse hook JSON payload from stdin and either writes a `{hookSpecificOutput: {...permissionDecision: "deny"...}}` JSON to stdout (deny) or exits 0 with no output (allow) — same contract the existing `.sh` script already implements for `Write`/`Edit`.
- Consumes: nothing new — same PreToolUse hook stdin contract Claude Code already uses for this hook.

The existing script does its JSON parsing and message-building by shelling
out to `node -e '...'` with the JS embedded inside a single-quoted bash
string. Extending that in place would require embedding a much larger,
apostrophe-free JS program inside bash single-quotes — fragile and hard to
verify without live testing. Moving the logic to its own `.js` file removes
the quoting hazard entirely and makes the logic directly testable with
`node hooks/block-main-branch-edits.js < payload.json`.

- [ ] **Step 1: Verify the actual PreToolUse payload shape for a `Bash` call**

Run a throwaway check to confirm the hook stdin JSON's top-level `cwd`
field exists and means what the design assumes (the Bash tool's current
session working directory). Temporarily add this single line to the
*existing* `hooks/block-main-branch-edits.sh`, right after `input="$(cat)"`:

```bash
printf '%s\n' "$input" >> /tmp/hook-payload-debug.log
```

Then, in this same Claude Code session, run any harmless `Bash` tool
command (e.g. `pwd`) so the hook fires, and inspect the log:

```bash
cat /tmp/hook-payload-debug.log
```

Confirm the JSON contains a top-level `cwd` key matching this session's
current working directory, and a `tool_name` key equal to `"Bash"` with a
`tool_input.command` key holding the command string. Remove the debug line
from `hooks/block-main-branch-edits.sh` afterward (revert it — do not
leave debug logging in the shipped hook) and delete
`/tmp/hook-payload-debug.log`. If the field names differ from what's
assumed here, adjust every reference to `payload.cwd` / `payload.tool_name`
/ `payload.tool_input` in Steps 3-4 below to match what was actually
observed before proceeding.

- [ ] **Step 2: Write `testing/hook-tests.sh` (the failing test)**

```bash
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

run_case "4: dev repo, main, Write -> deny" \
  "Write" "$DEV_REPO" "{\"file_path\":\"$DEV_REPO/src/index.js\"}" "deny"

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
```

- [ ] **Step 3: Run the test script to verify it fails**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
bash testing/hook-tests.sh
```

Expected: fails immediately — `hooks/block-main-branch-edits.js` does not
exist yet, so `node "$HOOK"` errors on every case (all 10 report FAIL, or
the script errors out before printing a summary).

- [ ] **Step 4: Create `hooks/block-main-branch-edits.js`**

```javascript
#!/usr/bin/env node
'use strict';

const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const MUTATING_SUBCOMMANDS = [
  'commit', 'stash', 'merge', 'rebase', 'cherry-pick', 'revert', 'reset',
  'checkout', 'switch', 'restore', 'push', 'pull'
];

const DEV_PROJECT_MARKERS = [
  'package.json', 'pyproject.toml', 'go.mod', 'Cargo.toml', 'pom.xml',
  'build.gradle', 'build.gradle.kts', 'Gemfile', 'composer.json'
];

function gitOutput(dir, args) {
  try {
    return execFileSync('git', ['-C', dir, ...args], { encoding: 'utf8' }).trim();
  } catch (e) {
    return '';
  }
}

function splitCommandSegments(command) {
  return command.split(/&&|\|\||;|\n|\|/);
}

function findGitSubcommand(segment) {
  const match = segment.match(/\bgit\b(.*)/s);
  if (!match) return null;
  const tokens = match[1].trim().split(/\s+/).filter(Boolean);
  for (const token of tokens) {
    if (!token.startsWith('-')) return { subcommand: token, segment };
  }
  return null;
}

function isMutatingSegment(parsed) {
  const { subcommand, segment } = parsed;
  if (MUTATING_SUBCOMMANDS.includes(subcommand)) return true;
  if (subcommand === 'clean' && /(-f|--force|-fd|-fx|-df|-xf)/.test(segment)) return true;
  if (subcommand === 'branch' && /((^|\s)-D(\s|$))|(--delete\s+--force)|(--force\s+--delete)/.test(segment)) return true;
  return false;
}

function findMutatingSegment(command) {
  for (const segment of splitCommandSegments(command)) {
    const parsed = findGitSubcommand(segment);
    if (parsed && isMutatingSegment(parsed)) return segment.trim();
  }
  return null;
}

function deny(reason) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: reason
    }
  }));
}

let raw = '';
process.stdin.on('data', chunk => { raw += chunk; });
process.stdin.on('end', () => {
  let payload;
  try {
    payload = JSON.parse(raw);
  } catch (e) {
    process.exit(0);
  }

  const toolName = payload.tool_name || '';
  if (toolName !== 'Write' && toolName !== 'Edit' && toolName !== 'Bash') {
    process.exit(0);
  }

  const filePath = (payload.tool_input && payload.tool_input.file_path) || '';
  const command = (payload.tool_input && payload.tool_input.command) || '';
  const sessionCwd = payload.cwd || '';

  const targetDir = toolName === 'Bash'
    ? (sessionCwd || process.cwd())
    : (filePath ? path.dirname(filePath) : process.cwd());

  const gitDir = gitOutput(targetDir, ['rev-parse', '--git-dir']);
  if (!gitDir) process.exit(0);

  const branch = gitOutput(targetDir, ['symbolic-ref', '--quiet', '--short', 'HEAD']);
  if (branch !== 'main' && branch !== 'master') process.exit(0);

  const repoRoot = gitOutput(targetDir, ['rev-parse', '--show-toplevel']);
  const isDevProject = repoRoot
    ? DEV_PROJECT_MARKERS.some(marker => fs.existsSync(path.join(repoRoot, marker)))
    : false;
  if (!isDevProject) process.exit(0);

  if (toolName === 'Write' || toolName === 'Edit') {
    deny(
      `Refusing to edit ${filePath}: currently checked out on branch ${branch}. ` +
      'Create a worktree/branch for this task first (see superpowers:using-git-worktrees) ' +
      'instead of editing the shared main branch directly.'
    );
    return;
  }

  const matchedSegment = findMutatingSegment(command);
  if (matchedSegment) {
    deny(
      `Refusing to run "${matchedSegment}": currently checked out on branch ${branch}. ` +
      'This repo uses git worktrees for isolation - create one first, e.g. ' +
      '"git worktree add .worktrees/<branch-name> -b <branch-name>", then retry this command inside that worktree.'
    );
  } else {
    process.exit(0);
  }
});
```

- [ ] **Step 5: Replace `hooks/block-main-branch-edits.sh` with a thin wrapper**

```bash
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
```

- [ ] **Step 6: Run the test script to verify it passes**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
chmod +x hooks/block-main-branch-edits.sh testing/hook-tests.sh
bash testing/hook-tests.sh
```

Expected: `10 passed, 0 failed`. If any case fails, fix
`hooks/block-main-branch-edits.js` and re-run — do not proceed with a
failing test case.

- [ ] **Step 7: Regression-check the wrapper end-to-end**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
echo '{"tool_name":"Write","cwd":"'"$PWD"'","tool_input":{"file_path":"'"$PWD"'/foo.txt"}}' | bash hooks/block-main-branch-edits.sh
```

Expected: no output, exit 0 (this repo has no dev-project marker file, so
the existing exemption still applies — confirms the `.sh` wrapper actually
invokes the new `.js` correctly end-to-end, not just the direct `node`
calls in `hook-tests.sh`).

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git add hooks/block-main-branch-edits.js hooks/block-main-branch-edits.sh testing/hook-tests.sh
git commit -m "Extend main-branch guard hook to block mutating Bash git commands"
```

---

### Task 3: SKILL.md — Part 1: Step 1 worktree-provenance check

**Files:**
- Modify: `SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: updated Step 1 text that Task 6's Scenario G GREEN run reads

- [ ] **Step 1: Insert the provenance check at the start of Step 1**

In `SKILL.md`, find:

```markdown
### Step 1: Self-Check

Before presenting anything to the user, verify the work is sound:
```

Replace with:

```markdown
### Step 1: Self-Check

**Before anything else, confirm this task actually happened in a worktree,
not directly on `main`/`master`:**

```bash
git rev-parse --show-toplevel
git branch --show-current
```

If the branch shown is `main` or `master`, the work was done directly on
the shared trunk instead of an isolated worktree — stop here. Do not
self-check or ship from `main` directly, and **do not attempt to fix this
yourself** — do not run `git reset --hard`, `git branch` + checkout
surgery, or any other command that rewrites `main`'s history or moves
commits off it, even as a "helpful" first step before asking. Tell the
user plainly what happened and that the changes need to move to a proper
worktree/branch first (see superpowers:using-git-worktrees) before this
skill can continue — let the user decide how that happens. This is a
backstop for cases the main-branch-edit-guard hook (if installed) did not
catch — see `hooks/block-main-branch-edits.sh` in this skill's own repo.

Once confirmed to be on a task branch/worktree, verify the work is sound:
```

(The rest of the existing Step 1 — the lint/test code block, the
"If lint or tests fail" line, the code-review line — stays exactly as-is,
unchanged, immediately after this new text.)

- [ ] **Step 2: Commit**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git add SKILL.md
git commit -m "Add worktree-provenance backstop check to Step 1"
```

---

### Task 4: SKILL.md — Part 2: description trigger, Deferred Work section, Step 8 sweep

**Files:**
- Modify: `SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: the "Deferred Work → Issues" section and description clause that Task 6's Scenario F GREEN run reads

- [ ] **Step 1: Extend the frontmatter description**

Find:

```yaml
description: Use when implementation is complete and passing self-checks, and a finished task needs to go through manual testing, PR creation, merge, and cleanup all the way to done - especially when the user wants the merge itself handled (not just the PR), including situations with merge conflicts or a GitHub Projects board/CLAUDE.md to update afterward
```

Replace with:

```yaml
description: Use when implementation is complete and passing self-checks, and a finished task needs to go through manual testing, PR creation, merge, and cleanup all the way to done - especially when the user wants the merge itself handled (not just the PR), including situations with merge conflicts or a GitHub Projects board/CLAUDE.md to update afterward; also use mid-task, whenever a discussion identifies follow-up work to defer rather than do now, so it gets captured before it's lost
```

- [ ] **Step 2: Insert the "Deferred Work → Issues" section**

Find (the end of the Overview block, right before "## The Process"):

```markdown
**REQUIRED BACKGROUND:** This skill assumes the task is being worked in a worktree created via superpowers:using-git-worktrees.

## The Process
```

Replace with:

```markdown
**REQUIRED BACKGROUND:** This skill assumes the task is being worked in a worktree created via superpowers:using-git-worktrees. Step 1 below verifies this rather than just assuming it.

## Deferred Work → Issues

This applies throughout the whole task, not just during the steps below:
the moment a discussion with the user settles on "not doing this now,
doing it later," capture it immediately — do not wait until Step 8 to
remember it. Conversations get compacted; things mentioned once and never
written down get lost.

**First time this comes up in a session**, detect whether the project
actually uses GitHub Issues:

```bash
gh issue list --limit 1
```

If this comes back empty and there is no other sign issues are in use,
this project does not use GitHub Issues — skip this whole mechanism
silently for the rest of the session, the same way Steps 6/7 skip an
unused board/CLAUDE.md convention. Do not ask the user to start using
issues; do not re-check this more than once per session.

If issues are in use, apply this decision tree to every deferred item,
immediately when it comes up:

1. **Is there a clearly relevant open issue already?** (same feature/bug
   area) — add the item there as a comment or checklist line. Do not open
   a new one.
2. **No matching issue, but is this substantial** — needs its own
   acceptance criteria, will take more than a quick follow-up to resolve,
   or involves an independent design decision? — open a new issue for it.
3. **Neither of the above** (a one-line note, a small fix, no clear owner
   issue) — add it as a new checklist line on the shared
   "Follow-ups / Backlog" issue. Find it by searching open issue titles
   for "Follow-ups" or "Backlog" first; only create it (with that title)
   if no match exists. Do not rely on a label for this search — a missing
   label would make the search silently fail.

After recording the item, report the issue number/URL to the user in one
line and continue the original work — this is not a detour that needs its
own task switch.

**Before Step 8 (cleanup) runs**, do one more pass: review the whole
conversation for anything that was identified as deferred, and confirm
each one actually landed in an issue. This catches anything raised before
this skill was invoked, when real-time capture would not have applied yet.

## The Process
```

- [ ] **Step 3: Add the sweep reminder to Step 8**

Find:

```markdown
### Step 8: Clean Up

**REQUIRED SUB-SKILL:** Reuse the worktree cleanup logic from
```

Replace with:

```markdown
### Step 8: Clean Up

**Before removing anything**, do the deferred-work sweep described in
"Deferred Work → Issues" above — confirm every item raised during this
task that will not be done now has landed in an issue. Once the worktree
is gone, the conversation's working context goes with it.

**REQUIRED SUB-SKILL:** Reuse the worktree cleanup logic from
```

- [ ] **Step 4: Update the Quick Reference table**

Find:

```markdown
| Step | Action | Blocking gate |
|---|---|---|
| 1 | Self-check (lint/test/review) | Must pass before Step 2 |
| 2 | Hand off for manual test | Wait for user response |
| 3 | User confirms, or reports a problem to fix (judge re-check scope yourself) | Problem → fix, judge whether to redo 1/2 |
| 4 | Open PR — only if one doesn't already exist for this branch | One PR per task, ever |
| 5 | Merge (method determined from project; conflicts judged mechanical vs. logic-divergence) | Literal `merge` keyword required; logic divergence always asks |
| 6 | Board update | Only if project uses a board; ask once per session |
| 7 | CLAUDE.md update | Only if project has a tracking section; ask once per session |
| 8 | Cleanup | Provenance check first |
```

Replace with:

```markdown
| Step | Action | Blocking gate |
|---|---|---|
| 1 | Verify work is in a worktree (not main/master), then self-check (lint/test/review) | Must pass before Step 2; stop if work happened on main |
| 2 | Hand off for manual test | Wait for user response |
| 3 | User confirms, or reports a problem to fix (judge re-check scope yourself) | Problem → fix, judge whether to redo 1/2 |
| 4 | Open PR — only if one doesn't already exist for this branch | One PR per task, ever |
| 5 | Merge (method determined from project; conflicts judged mechanical vs. logic-divergence) | Literal `merge` keyword required; logic divergence always asks |
| 6 | Board update | Only if project uses a board; ask once per session |
| 7 | CLAUDE.md update | Only if project has a tracking section; ask once per session |
| 8 | Cleanup | Deferred-work sweep first, then provenance check |
| ongoing | Deferred work → issue (real-time, whenever raised) | Only if project uses GitHub Issues; detect once per session |
```

- [ ] **Step 5: Add Common Mistakes entries**

Find the end of the `## Common Mistakes` section — the last entry, which
ends with:

```markdown
**Cleaning up a worktree the skill didn't create**
- Problem: destroys a harness-managed or user-managed workspace
- Fix: provenance-check before removal (see finishing-a-development-branch)
```

Append immediately after it (still inside `## Common Mistakes`):

```markdown

**Continuing to work directly on `main`/`master` because the hook didn't catch it**
- Problem: file edits and Bash git commands both leak into other parallel sessions sharing the same `.git`
- Fix: Step 1 now verifies the branch itself before doing anything else — treat a `main`/`master` result as a hard stop, not a warning to note and move past

**Self-remediating with `git reset --hard` or branch surgery when work is found directly on `main`, then telling the user afterward**
- Problem: rewrites shared trunk history unilaterally before the user had any chance to weigh in — this is worse than doing nothing, not better, even though it "fixes" the isolation problem
- Fix: stop and describe the situation to the user first; let them decide how the work moves to a worktree/branch, don't pre-empt that decision with your own git surgery

**Mentioning a deferred item in conversation without recording it anywhere**
- Problem: once the conversation is compacted or the worktree is cleaned up, the item is gone with no trace
- Fix: record it in an issue the moment it's agreed to be deferred, not at the end of the session

**Opening a new issue for a one-line, trivial deferred item**
- Problem: clutters the issue tracker with noise, defeats the purpose of tracking follow-ups
- Fix: route anything small/without a clear owner into the shared Follow-ups/Backlog issue instead
```

- [ ] **Step 6: Add Red Flags entries**

Find the end of the `## Red Flags - STOP and Ask` list — the last bullet
before the closing "All of these mean" line:

```markdown
- About to remove a worktree you didn't verify the provenance of

**All of these mean: stop, ask the user, do not proceed on assumption.**
```

Replace with:

```markdown
- About to remove a worktree you didn't verify the provenance of
- About to run a Bash git command (`commit`, `stash`, `merge`, etc.) directly against `main`/`master` because "it's just this once"
- About to move on from a "let's do this later" moment without creating or updating an issue first
- About to open a brand-new issue for something that would fit as one checklist line on an existing or backlog issue
- About to run `git worktree remove` in Step 8 without having swept the conversation for uncaptured deferred items
- About to run `git reset --hard`, branch/checkout surgery, or any other "cleanup" command against `main`/`master` to fix a provenance problem you just found, before the user has said how they want it handled

**All of these mean: stop, ask the user, do not proceed on assumption.**
```

- [ ] **Step 7: Commit**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git add SKILL.md
git commit -m "Add Deferred Work -> Issues section, Step 8 sweep, and description trigger"
```

---

### Task 5: SKILL.md — Part 3: rename to task-autopilot and reposition Overview

**Files:**
- Modify: `SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: `name: task-autopilot` frontmatter, which Task 9's rename operations key off of

- [ ] **Step 1: Rename the frontmatter `name` field**

Find:

```yaml
name: shipping-a-task
```

Replace with:

```yaml
name: task-autopilot
```

- [ ] **Step 2: Rewrite the title and Overview**

Find:

```markdown
# Shipping a Task

## Overview

Carries a single completed task from self-check through merge and cleanup, so you don't have to re-explain the same handoff steps every time you finish work in a worktree. Fills the gap after PR creation: this skill also drives the actual merge (including conflict handling) and the post-merge housekeeping (board status, CLAUDE.md), which superpowers:finishing-a-development-branch stops short of.

**Announce at start:** "I'm using the shipping-a-task skill to ship this task."
```

Replace with:

```markdown
# Task Autopilot

## Overview

Runs a task's full lifecycle on autopilot once implementation is underway: keeps work isolated to its worktree, captures any deferred follow-up work as GitHub issues as soon as it comes up, then carries the task from self-check through manual testing, PR, merge, and cleanup — so you don't have to re-explain the same handoff steps every time you finish work in a worktree, and nothing discussed along the way gets silently dropped. Fills the gap after PR creation: this skill also drives the actual merge (including conflict handling) and the post-merge housekeeping (board status, CLAUDE.md), which superpowers:finishing-a-development-branch stops short of.

**Announce at start:** "I'm using the task-autopilot skill to ship this task" (or, when only capturing a deferred item mid-task: "I'm using the task-autopilot skill to record this as a follow-up before continuing").
```

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git add SKILL.md
git commit -m "Rename skill to task-autopilot and reposition Overview around full task lifecycle"
```

---

### Task 6: GREEN phase — re-verify Scenario F and Scenario G with the updated SKILL.md

**Files:**
- Modify: `testing/green-phase-notes.md` (append a new dated revision section)
- Modify: `SKILL.md` (only if Step 3 finds a gap requiring a refactor)

**Interfaces:**
- Consumes: `testing/baseline-notes.md` Scenario F/G results (Task 1), `SKILL.md` as of Task 5 (Tasks 3+4+5 combined)
- Produces: pass/fail confirmation for both scenarios; drives an in-task refactor loop if either fails

- [ ] **Step 1: Re-run Scenario F with the updated skill available**

Dispatch a fresh subagent (Agent tool, `subagent_type: general-purpose`,
foreground). Point it at the file directly, since it is not registered as
a discoverable skill under its new name yet: include in the prompt
"Read and follow the instructions in
`C:\Users\USER\Desktop\One_Piece\SkillCreater\SKILL.md` as the
`task-autopilot` skill, then handle this situation:" followed by the exact
Scenario F text from `testing/baseline-notes.md`. Record the result under
a new `## Scenario F result` heading (see Step 4 below for where this
goes). Pass criterion: the agent detects GitHub Issues are in use, applies
the decision tree, creates or updates an issue for the pagination item
immediately (not just chat acknowledgment), and reports the issue
number/URL before continuing the rate-limiting work.

- [ ] **Step 2: Re-run Scenario G with the updated skill available**

Same process, using the exact Scenario G text. Pass criterion: the agent
stops at the provenance check, states plainly that the work was done
directly on `main` with no worktree, and refuses to proceed with
self-check/shipping until the changes move to a proper worktree — it does
not run lint/tests and continue as if nothing were wrong.

- [ ] **Step 3: If either scenario fails, refactor and re-run just that scenario**

If Step 1 or Step 2 did not meet its pass criterion, identify the specific
rationalization the agent used (quote it), add a targeted counter to
`SKILL.md`'s Common Mistakes or Red Flags section following the existing
pattern (see Task 4 Steps 5-6 for the pattern to extend), then re-dispatch
a fresh subagent for only the failing scenario. Repeat until it passes —
do not weaken the pass criterion to make a failing result look like a
pass.

- [ ] **Step 4: Append the revision section to `testing/green-phase-notes.md`**

Append at the end of the file, after the existing
`## 2026-07-19 Revision` section:

```markdown

## 2026-07-24 Revision — isolation hardening and deferred-work capture

Two new behaviors were added: (1) a Step 1 backstop that refuses to
self-check/ship when the work was done directly on `main` with no
worktree, and (2) a "Deferred Work → Issues" section requiring immediate,
decision-tree-routed issue capture whenever the task discussion identifies
something to defer. Two fresh subagents (no shared context) were run
against the updated `SKILL.md` to verify both.

### Scenario F (new) — deferred item real-time capture

[Fill in with the actual Step 1 result: pass/fail, what the agent did,
verbatim reasoning, whether it correctly applied the decision tree —
same level of detail as the existing Scenario A/B/C/D/E write-ups above.]

### Scenario G (new) — main-direct-work detection

[Fill in with the actual Step 2 result: pass/fail, what the agent said,
whether it correctly refused to proceed — same level of detail as the
existing write-ups above.]

### Gaps comparison

[State whether both of Task 1's new "Gaps to close" entries (Scenario F,
Scenario G) are now resolved, and whether any refactor pass from Step 3
was needed, following the same closing-summary style as the existing
"Gaps comparison" section above.]
```

Replace every bracketed placeholder with the real observed results —
these must reflect what the dispatched subagents actually did in Steps
1-3, not a template left unfilled.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git add testing/green-phase-notes.md
git add SKILL.md
git commit -m "Add GREEN-phase verification for isolation and deferred-work capture"
```

(If Step 3 made no `SKILL.md` changes, `git add SKILL.md` stages nothing
new — that's fine, the commit still captures the notes.)

---

### Task 7: Update README.md for the new name and the hardened hook

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: final skill name/repo URL from Task 5, hook behavior from Task 2
- Produces: install/usage docs future devices will follow

- [ ] **Step 1: Update the title, intro, and install paths**

Find:

```markdown
# shipping-a-task

A Claude Code skill that carries a single development task from
self-check through manual testing, PR creation, merge (including
conflict resolution), post-merge board/CLAUDE.md updates, and worktree
cleanup — so you don't have to re-explain the same handoff steps every
time you finish work in a worktree.
```

Replace with:

```markdown
# task-autopilot

A Claude Code skill that runs a development task's full lifecycle on
autopilot: keeps work isolated to its worktree (including blocking
mutating git commands run directly against `main`/`master`), captures
deferred follow-up work as GitHub issues as it comes up, then carries the
task from self-check through manual testing, PR creation, merge
(including conflict resolution), post-merge board/CLAUDE.md updates, and
worktree cleanup — so you don't have to re-explain the same handoff steps
every time you finish work in a worktree, and nothing discussed along the
way gets silently dropped.

Formerly named `shipping-a-task` — renamed 2026-07-24 to match its actual
scope (see "Migrating from shipping-a-task" below if you have an older
clone).
```

- [ ] **Step 2: Update the global-install path references**

Find:

```markdown
This skill is a global Claude Code skill — it needs to live at
`~/.claude/skills/shipping-a-task/` (on Windows,
`C:\Users\<you>\.claude\skills\shipping-a-task\`) so Claude Code picks it
up in every project.
```

Replace with:

```markdown
This skill is a global Claude Code skill — it needs to live at
`~/.claude/skills/task-autopilot/` (on Windows,
`C:\Users\<you>\.claude\skills\task-autopilot\`) so Claude Code picks it
up in every project.
```

- [ ] **Step 3: Update the clone command**

Find:

```markdown
### 4. Clone this repo into the global skills directory

```bash
# Windows (Git Bash / PowerShell with git installed)
git clone https://github.com/Shawn678/shipping-a-task.git "$HOME/.claude/skills/shipping-a-task"

# macOS/Linux
git clone https://github.com/Shawn678/shipping-a-task.git ~/.claude/skills/shipping-a-task
```
```

Replace with:

```markdown
### 4. Clone this repo into the global skills directory

```bash
# Windows (Git Bash / PowerShell with git installed)
git clone https://github.com/Shawn678/task-autopilot.git "$HOME/.claude/skills/task-autopilot"

# macOS/Linux
git clone https://github.com/Shawn678/task-autopilot.git ~/.claude/skills/task-autopilot
```
```

- [ ] **Step 4: Update the "Confirm Claude Code sees it" section**

Find:

```markdown
Start (or restart) a Claude Code session and check that `shipping-a-task`
appears in the available-skills listing. If it doesn't show up, double
check the clone landed at exactly `~/.claude/skills/shipping-a-task/`
(the folder name must match, and `SKILL.md` must be directly inside it,
not nested one level deeper).
```

Replace with:

```markdown
Start (or restart) a Claude Code session and check that `task-autopilot`
appears in the available-skills listing. If it doesn't show up, double
check the clone landed at exactly `~/.claude/skills/task-autopilot/`
(the folder name must match, and `SKILL.md` must be directly inside it,
not nested one level deeper).
```

- [ ] **Step 5: Add a migration section for devices with the old clone**

Find:

```markdown
## Using the skill
```

Replace with:

```markdown
## Migrating from shipping-a-task

If a device already has the old clone at
`~/.claude/skills/shipping-a-task/` from before the 2026-07-24 rename,
bring it up to date instead of re-cloning from scratch:

```bash
cd ~/.claude/skills/shipping-a-task
git remote set-url origin https://github.com/Shawn678/task-autopilot.git
git pull
cd ..
mv shipping-a-task task-autopilot
```

Then restart Claude Code and confirm `task-autopilot` (not
`shipping-a-task`) appears in the available-skills listing.

## Using the skill
```

- [ ] **Step 6: Update the "Using the skill" paragraph**

Find:

```markdown
Once installed, Claude Code will offer to use `shipping-a-task` when a
task is implemented and ready to ship — or you can explicitly ask for it
(e.g. "use the shipping-a-task skill to wrap this up"). It walks through
self-check → manual test handoff → PR → merge (asking before resolving
any conflict that isn't purely mechanical, and requiring you to type the
literal word `merge` before it actually merges) → asking about board and
CLAUDE.md updates → cleanup.
```

Replace with:

```markdown
Once installed, Claude Code will offer to use `task-autopilot` when a task
is implemented and ready to ship, or as soon as a task-in-progress
discussion identifies something to defer for later — or you can explicitly
ask for it (e.g. "use the task-autopilot skill to wrap this up"). It walks
through self-check (including a check that the work actually happened in a
worktree, not directly on `main`) → manual test handoff → PR → merge
(asking before resolving any conflict that isn't purely mechanical, and
requiring you to type the literal word `merge` before it actually merges)
→ asking about board and CLAUDE.md updates → a sweep for any deferred
items that still need to land in an issue → cleanup.
```

- [ ] **Step 7: Update the hook section's coverage description**

Find:

```markdown
### What it does and doesn't cover

- Blocks: Claude's `Write`/`Edit` tools targeting a file inside a real dev
  project (has one of the marker files above) while `main`/`master` is
  checked out.
- Does **not** block: `Bash`-tool invocations that write files or run
  `git commit` directly, or projects without one of the recognized marker
  files (e.g. this `shipping-a-task` repo itself, which is plain
  Markdown/shell and has none of them — you can still edit it on `master`).
```

Replace with:

```markdown
### What it does and doesn't cover

- Blocks: Claude's `Write`/`Edit` tools targeting a file inside a real dev
  project (has one of the marker files above) while `main`/`master` is
  checked out.
- Blocks: `Bash`-tool invocations of mutating git commands (`commit`,
  `stash`, `merge`, `rebase`, `cherry-pick`, `revert`, `reset`, `checkout`,
  `switch`, `restore`, `push`, `pull`, force `clean`, force `branch`
  delete) against a real dev project while `main`/`master` is checked out.
  Read-only/safe operations (`status`, `log`, `diff`, `fetch`,
  `git worktree ...`, non-force `branch -d`, `add`) remain allowed, since
  worktree cleanup and setup need to run from the main checkout.
- Does **not** block: projects without one of the recognized marker files
  (e.g. this `task-autopilot` repo itself, which is plain Markdown/JS/shell
  and has none of them — you can still edit it on `master`), or a single
  `Bash` command that `cd`s to a different directory before running git
  (the hook only inspects the session's tracked working directory at
  invocation time, not any `cd` inside the command string itself).
```

- [ ] **Step 8: Update the `chmod`/copy step to include the new `.js` file**

Find:

```markdown
2. Copy (or symlink) the script into `~/.claude/hooks/`:
   ```bash
   mkdir -p ~/.claude/hooks
   cp ~/.claude/skills/shipping-a-task/hooks/block-main-branch-edits.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/block-main-branch-edits.sh
   ```
```

Replace with:

```markdown
2. Copy (or symlink) both the wrapper and its logic file into
   `~/.claude/hooks/` (the `.sh` wrapper `exec`s the `.js` file next to it,
   so both must be copied together):
   ```bash
   mkdir -p ~/.claude/hooks
   cp ~/.claude/skills/task-autopilot/hooks/block-main-branch-edits.sh ~/.claude/hooks/
   cp ~/.claude/skills/task-autopilot/hooks/block-main-branch-edits.js ~/.claude/hooks/
   chmod +x ~/.claude/hooks/block-main-branch-edits.sh
   ```
```

- [ ] **Step 9: Update the remaining `shipping-a-task` path references**

Search the rest of `README.md` for any remaining literal occurrences of
`shipping-a-task` (the "Optional: main-branch edit guard hook" intro
paragraph, the "Updating the skill later" section's `cd` command) and
replace each with `task-autopilot`, keeping surrounding text unchanged.

- [ ] **Step 10: Commit**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git add README.md
git commit -m "Update README for task-autopilot rename and hardened hook coverage"
```

---

### Task 8: Add a dated addendum note to design.md

**Files:**
- Modify: `design.md`

**Interfaces:**
- Consumes: nothing
- Produces: a pointer from the historical design doc to the new spec, without altering prior content

- [ ] **Step 1: Append the addendum**

Append at the very end of `design.md`, after the existing
`## 2026-07-19 優化修訂` section (and its subsections) — do not edit any
existing content above this point:

```markdown

## 2026-07-24 更名為 task-autopilot

因應這次隔離強化／代辦事項追蹤／整體定位調整（完整設計見
`docs/superpowers/specs/2026-07-24-isolation-followups-reposition-design.md`），
這個 skill 從 `shipping-a-task` 更名為 `task-autopilot`，反映其涵蓋整個任務
生命週期（隔離安全、代辦事項不遺漏、收尾出貨）而非只有出貨階段的實際定位。
GitHub repo 與各裝置上 `~/.claude/skills/` 底下的資料夾路徑也同步更名，細節
見 `README.md` 的「Migrating from shipping-a-task」段落。本文件其餘內容維持
原始歷史記錄，不回溯修改。
```

- [ ] **Step 2: Commit**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git add design.md
git commit -m "Add dated addendum noting the task-autopilot rename"
```

---

### Task 9: Rename the GitHub repo and sync both local clones

**Files:**
- No file content changes — git/gh operations only, across this dev clone and the deployed clone at `~/.claude/skills/shipping-a-task/`

**Interfaces:**
- Consumes: `name: task-autopilot` (Task 5), all prior commits (Tasks 1-8) already pushed by the time this runs
- Produces: `Shawn678/task-autopilot` on GitHub, both local clones pointing at it, deployed clone renamed and up to date

This is the one task in this plan that touches a shared, external resource
in a way that is not easily reversible from this session — do not run
Step 2 without the explicit confirmation described in that step, even
though the user already agreed to do the rename "this round" during
brainstorming. That earlier agreement was about scope/timing, not a
substitute for confirming the specific irreversible action at the moment
it's about to run.

- [ ] **Step 1: Push all prior work under the current name first**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git status
git push origin master
```

Expected: `git status` shows a clean working tree (everything from Tasks
1-8 committed); push succeeds. Do not proceed to Step 2 with uncommitted
or unpushed changes — the rename should happen on top of a fully-synced
`master`.

- [ ] **Step 2: Confirm the exact `gh repo rename` behavior, then get explicit user confirmation**

```bash
gh repo rename --help
```

Read the output to confirm the exact syntax for renaming a repo that
isn't the current directory's remote by default (e.g. a `--repo` flag) and
whether it offers a non-interactive flag for auto-confirming the local
remote update. Then present the exact command to the user (substituting
in whatever flags Step 2's `--help` output actually showed) and require
an explicit go-ahead before running it — this renames
`github.com/Shawn678/shipping-a-task` to `github.com/Shawn678/task-autopilot`,
a shared external resource other devices' clones point at.

- [ ] **Step 3: Run the rename (only after explicit confirmation)**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
gh repo rename task-autopilot --repo Shawn678/shipping-a-task
```

(Adjust flags to match what Step 2's `--help` actually documented, e.g.
adding a non-interactive confirmation flag if one exists.)

- [ ] **Step 4: Verify and, if needed, manually fix this dev clone's remote**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git remote -v
```

Expected: `origin` now points at
`https://github.com/Shawn678/task-autopilot.git`. If `gh repo rename`
didn't update it automatically, fix it manually:

```bash
git remote set-url origin https://github.com/Shawn678/task-autopilot.git
git remote -v
```

- [ ] **Step 5: Rename and sync the deployed clone**

```bash
mv "$HOME/.claude/skills/shipping-a-task" "$HOME/.claude/skills/task-autopilot"
cd "$HOME/.claude/skills/task-autopilot"
git remote set-url origin https://github.com/Shawn678/task-autopilot.git
git fetch origin
git status
git pull origin master
```

Expected: `git status` before the pull shows the deployed clone is behind
`origin/master` (it was last synced before this round of changes); the
pull fast-forwards cleanly with no conflicts (this repo has a single
contributor and linear history). If it does not fast-forward cleanly,
stop and investigate before forcing anything — do not discard whatever
is different without understanding why first.

- [ ] **Step 6: Confirm the deployed clone matches**

```bash
cd "$HOME/.claude/skills/task-autopilot"
git log --oneline -3
head -5 SKILL.md
```

Expected: the log shows this plan's commits, and `SKILL.md`'s frontmatter
shows `name: task-autopilot`.

---

### Task 10: Final sanity pass

**Files:**
- No new files — final verification of everything from Tasks 1-9

**Interfaces:**
- Consumes: all prior task outputs
- Produces: a confirmed-working, pushed, renamed skill ready for use and for migrating other devices later

- [ ] **Step 1: Re-run both test suites one more time from the dev clone**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
bash testing/hook-tests.sh
```

Expected: `10 passed, 0 failed`.

- [ ] **Step 2: Confirm both clones are clean and in sync**

```bash
cd "C:/Users/USER/Desktop/One_Piece/SkillCreater"
git status
git log --oneline -1
cd "$HOME/.claude/skills/task-autopilot"
git status
git log --oneline -1
```

Expected: both show `nothing to commit, working tree clean` and the same
commit hash for `git log --oneline -1`.

- [ ] **Step 3: Report completion to the user**

Summarize: hook now blocks mutating Bash git commands on main/master
(functionally tested, 10/10 passing), `SKILL.md` has the worktree
provenance backstop and Deferred Work → Issues mechanism (RED→GREEN
verified against Scenarios F and G), the skill is renamed to
`task-autopilot` with `README.md`/`design.md` updated accordingly, the
GitHub repo is renamed, and both this device's clones (dev copy and
deployed copy) are in sync. Note explicitly that other devices still
running the old `shipping-a-task` clone need to follow the
"Migrating from shipping-a-task" section in `README.md` themselves — this
session cannot reach them.
