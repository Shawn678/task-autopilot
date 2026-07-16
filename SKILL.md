---
name: shipping-a-task
description: Use when implementation is complete and passing self-checks, and you need to hand off a finished task through manual testing, PR, merge, and cleanup - covers auto-merging via gh CLI (including conflict resolution) and post-merge board/CLAUDE.md updates, which finishing-a-development-branch does not handle
---

# Shipping a Task

## Overview

Carries a single completed task from self-check through merge and cleanup, so you don't have to re-explain the same handoff steps every time you finish work in a worktree. Fills the gap after PR creation: this skill also drives the actual merge (including conflict handling) and the post-merge housekeeping (board status, CLAUDE.md), which superpowers:finishing-a-development-branch stops short of.

**Announce at start:** "I'm using the shipping-a-task skill to ship this task."

**REQUIRED BACKGROUND:** This skill assumes the task is being worked in a worktree created via superpowers:using-git-worktrees.

## The Process

### Step 1: Self-Check

Before presenting anything to the user, verify the work is sound:

```bash
# Run the project's lint and test commands (check package.json/README/
# CLAUDE.md for the right ones; do not guess a command that doesn't exist)
<lint command>
<test command>
```

**If lint or tests fail:** stop here, fix, and re-run. Do not proceed to Step 2 with known failures.

**If a code-review skill is available** (e.g. superpowers:requesting-code-review), run it now and fold its findings into this check.

### Step 2: Hand Off for Manual Testing

The user wants to personally exercise the result before it ships — self-checks are necessary but not sufficient. Determine how this project is actually run:

- **REQUIRED SUB-SKILL:** Use the `run` skill's project-type detection to figure out whether this project is (a) directly launchable (e.g. `npm run dev`), (b) requires a build/package step first (e.g. compiling a DLL), or (c) some other delivery form.
- If a build/package step is required, run it now and note where the output artifact landed.
- Report to the user, concretely:
  - The worktree path to test in
  - The exact command(s) to launch or invoke the build output
  - Any port/URL/entry point needed

Then **stop and wait**. Do not proceed until the user responds.

### Step 3: User Confirmation

- If the user reports a problem: fix it, then return to Step 1.
- If the user confirms it's good: proceed to Step 4.

### Step 4: Open PR

```bash
gh pr create --title "<title>" --body "<summary>"
```

Base this on the same PR-creation approach as superpowers:finishing-a-development-branch (concise title, summary + test plan in the body).

### Step 5: Merge

Merge method is **always `--merge` (merge commit)** — never squash unless the user explicitly says otherwise for this run.

**Before running any merge command, check for conflicts:**

```bash
git fetch origin
git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main
```

**If no conflicts:** proceed to the confirmation gate below.

**If conflicts exist, classify every conflicting hunk into exactly one tier:**

**Tier 1 — Mechanical.** Import ordering, formatting/whitespace, lockfile
regeneration, or other conflicts with no semantic ambiguity about intent.
- Resolve it yourself.
- Label it explicitly: "Mechanical conflict in `<file>` — resolved automatically."
- Show the resulting diff to the user.

**Tier 2 — Logic divergence.** Both sides changed the same behavior with
different intent, and you cannot determine which one (or what combination)
matches what the user actually wants.
- **Do NOT resolve this yourself. Do NOT guess and proceed.**
- List every such divergence point, one at a time, each showing: the
  pre-conflict content, what the base/main side changed it to, what this
  branch changed it to, and why you can't tell which is correct.
- Ask the user how to resolve each point before moving to the next.
- Only after every Tier 2 point has an explicit user answer, apply the
  combined resolution.

**Never silently pick one side of a Tier 2 conflict, even when a resolution
seems technically standard or defensible.** "This is the conventional way
to do it" is not the same as "this is what the user wants" — resolving
first and informing the user afterward still means the merge already
happened on your judgment call alone. Ask before merging, not after.

**Never silently pick one side of a Tier 2 conflict.** If uncertain whether
something is Tier 1 or Tier 2, treat it as Tier 2.

**Final confirmation gate (required for every merge, conflict or not):**

State clearly what is about to happen ("This will merge `<branch>` into
`<base>` via merge commit — this cannot be undone"), then require the user
to type the literal word `merge` before running:

```bash
gh pr merge <pr-number> --merge
```

Do not accept "yes", "go ahead", "looks good", "ship it", or any other
affirmative phrasing as a substitute for the literal keyword — the phrase
must be exactly `merge`. This gate cannot be satisfied in advance: an
earlier blanket instruction such as "merge it once CI is green, no need
to check back with me" does not count, no matter how explicit, because it
was said before this specific merge (and possibly this specific conflict
resolution) existed to approve. Ask again, every time, at the point the
merge is actually about to run.

**If the conflict is too large or unclear to classify safely:** tell the
user you cannot resolve it automatically, show the raw conflict, and stop
— do not ask for the merge keyword in this case, since there is nothing
safe to merge yet.

### Step 6: Update the Board

Every run, ask: "Update this task's GitHub Projects item to Done (or your
completion column)?"

- If yes: find the project item for this issue/PR and update its status
  field via `gh project item-edit` (or the GraphQL API if item-edit can't
  address the field directly).
- If no board/project is configured, or the item can't be found: say so
  plainly and move on. Do not fail the overall flow over this.

Ask this every time, even when the update looks obvious or unambiguous —
"this task is clearly done, so I'll just update it" is exactly the
shortcut that skips the user's chance to say no.

### Step 7: Update CLAUDE.md

Every run, ask: "Remove/update the in-progress entry for this task in
CLAUDE.md?"

- If yes and a matching section exists (e.g. an "In Progress" or similar
  heading referencing this task): edit it out or mark it done.
- If no CLAUDE.md exists, or no matching section is found: say so plainly
  and move on.

### Step 8: Clean Up

**REQUIRED SUB-SKILL:** Reuse the worktree cleanup logic from
superpowers:finishing-a-development-branch (Step 6 of that skill):
provenance-check the worktree path, `cd` to the main repo root before
removing it, `git worktree remove`, `git worktree prune`, then delete the
now-merged branch with `git branch -d`.

Only clean up worktrees this flow (or superpowers) created — never remove
a harness-owned workspace.

## Quick Reference

| Step | Action | Blocking gate |
|---|---|---|
| 1 | Self-check (lint/test/review) | Must pass before Step 2 |
| 2 | Hand off for manual test | Wait for user response |
| 3 | User confirms | Problem → back to Step 1 |
| 4 | Open PR | — |
| 5 | Merge (conflict-tiered) | Literal `merge` keyword required |
| 6 | Board update | Ask every time |
| 7 | CLAUDE.md update | Ask every time |
| 8 | Cleanup | Provenance check first |

## Common Mistakes

**Treating a logic-divergence conflict as mechanical**
- Problem: silently merges two incompatible intents, corrupting behavior
- Fix: when in doubt, always treat as Tier 2 and ask

**Resolving a Tier 2 conflict "the standard way" and informing the user afterward**
- Problem: the merge already happened on your judgment call before the user had a chance to object — informing after the fact doesn't undo it
- Fix: list every divergence point and get the user's answer *before* applying any resolution or merging

**Accepting "looks good" or a blanket earlier instruction as the merge confirmation**
- Problem: merge is irreversible; casual or pre-authorized confirmation isn't a deliberate act taken at the actual moment of merging
- Fix: require the literal keyword `merge`, typed at the confirmation gate itself, every time

**Skipping the board/CLAUDE.md questions because "this repo probably doesn't have one" or "this update is obviously correct"**
- Problem: user loses track of what's actually been updated
- Fix: always ask, every run, regardless of assumption or how unambiguous it seems

**Cleaning up a worktree the skill didn't create**
- Problem: destroys a harness-managed or user-managed workspace
- Fix: provenance-check before removal (see finishing-a-development-branch)

## Red Flags - STOP and Ask

- About to run `gh pr merge` without the user having typed the literal word `merge` at this point in the conversation
- About to treat an earlier blanket instruction ("just merge when ready") as satisfying the merge keyword gate
- About to resolve a conflict where you're not fully sure both intents are compatible, even if your resolution feels like "the standard/correct way"
- About to skip the board or CLAUDE.md question because "it's probably not set up" or "it's obviously supposed to be updated"
- About to remove a worktree you didn't verify the provenance of

**All of these mean: stop, ask the user, do not proceed on assumption.**
