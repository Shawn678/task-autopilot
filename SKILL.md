---
name: shipping-a-task
description: Use when implementation is complete and passing self-checks, and a finished task needs to go through manual testing, PR creation, merge, and cleanup all the way to done - especially when the user wants the merge itself handled (not just the PR), including situations with merge conflicts or a GitHub Projects board/CLAUDE.md to update afterward
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

- If the user confirms it's good: proceed to Step 4.
- If the user reports a problem:
  - Fix it on the same branch.
  - Judge for yourself, based on what actually changed, whether the fix
    warrants re-running the full Step 1 self-check and/or looping back
    through Step 2 for another manual-test handoff, or whether it's narrow
    enough to confirm inline with the user and move on. There is no fixed
    rule here — use your judgment on the specific diff.
  - If a PR already exists for this task (see Step 4), push the fix to the
    same branch to update that PR. Do not open a second PR for the same
    task — see the one-PR-per-task rule in Step 4.

### Step 4: Open PR

**One PR per task/branch.** A single task/worktree corresponds to exactly
one PR for its entire lifecycle, whether the PR is opened before or after
a round of fixes. If a PR already exists for this branch (check with
`gh pr view` or `gh pr list --head <branch>`), do not run `gh pr create`
again — just `git push` the new commits, which updates the existing PR
automatically. Only open a genuinely new PR when the prior one for this
task has already been merged and a *different, later* issue is found
(that's a new task, not a continuation).

If no PR exists yet for this branch:

```bash
gh pr create --title "<title>" --body "<summary>"
```

Base this on the same PR-creation approach as superpowers:finishing-a-development-branch (concise title, summary + test plan in the body).

### Step 5: Merge

**Determine the merge method from the project itself** — check the
repo's branch protection rules (`gh api repos/{owner}/{repo}` or the
GitHub UI settings if accessible), an existing CONTRIBUTING doc, or the
pattern of recent merge commits on this repo (`git log --merges`), and
use whichever of merge-commit/squash/rebase the project actually expects.
Do not default to any one method — a project that only allows squash
merges will reject `--merge` outright. If genuinely no signal exists
either way, ask the user once rather than guessing.

**Before running any merge command, check for conflicts:**

```bash
git fetch origin
git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main
```

**If no conflicts:** proceed to the confirmation gate below.

**If conflicts exist, look at every conflicting hunk and judge whether it's
a mechanical difference (formatting, import order, lockfile regeneration —
no ambiguity about intent) or a genuine logic divergence (both sides
changed the same behavior with different intent, and you cannot tell
which matches what the user actually wants).**

- **Mechanical:** resolve it yourself, label it explicitly ("Mechanical
  conflict in `<file>` — resolved automatically"), and show the resulting
  diff to the user.
- **Logic divergence — this is a hard rule, not a judgment call:** do
  NOT resolve it and do NOT guess and proceed, no matter how standard or
  defensible one resolution seems. List every such divergence point, one
  at a time, showing the pre-conflict content, what the base/main side
  changed it to, what this branch changed it to, and why you can't tell
  which is correct. Ask the user how to resolve each point before moving
  to the next. Only after every point has an explicit user answer, apply
  the combined resolution.
- **If you're not sure which category a hunk falls into, treat it as
  logic divergence.** The cost of asking unnecessarily is small; the cost
  of silently merging incompatible intent is not.

**"This is the conventional way to do it" is not the same as "this is
what the user wants."** Resolving a logic divergence first and informing
the user afterward still means the merge already happened on your
judgment call alone. Ask before merging, not after.

**Final confirmation gate (required for every merge, conflict or not):**

State clearly what is about to happen, naming the actual merge method
determined above (e.g. "This will merge `<branch>` into `<base>` via
<merge commit/squash/rebase> — this cannot be undone"), then require the
user to type the literal word `merge` before running:

```bash
gh pr merge <pr-number> --merge    # or --squash / --rebase, matching the method determined above
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

**First check whether this project actually uses a GitHub Projects
board at all** (e.g. `gh project list` scoped to the repo/owner, or a
board already referenced earlier in this conversation). If there's no
sign this project tracks work in a Projects board, skip this step
silently — don't ask about a system the project doesn't use.

If a board is in use, ask: "Update this task's GitHub Projects item to
Done (or your completion column)?"

- If yes: find the project item for this issue/PR and update its status
  field via `gh project item-edit` (or the GraphQL API if item-edit can't
  address the field directly).
- If the item can't be found despite the board existing: say so plainly
  and move on. Do not fail the overall flow over this.

**Ask at most once per conversation/session.** If this exact question has
already been asked and answered earlier in this session (e.g. an earlier
shipping-a-task run in the same conversation), reuse that answer instead
of asking again — unless the user says the preference changed. Within a
single run, still ask every time the board's existence is confirmed;
"this task is clearly done, so I'll just update it" is exactly the
shortcut that skips the user's chance to say no.

### Step 7: Update CLAUDE.md

**First check whether CLAUDE.md exists and has anything resembling an
in-progress/task-tracking section** (e.g. an "In Progress" heading or
similar). If there's no CLAUDE.md, or it exists but has no such section,
skip this step silently — don't ask about a convention this project
isn't using.

If a matching section exists, ask: "Remove/update the in-progress entry
for this task in CLAUDE.md?"

- If yes: edit it out or mark it done.

**Ask at most once per conversation/session** under the same reuse rule
as Step 6 — if the user already answered this question earlier in the
same session, don't ask again unless they indicate the preference changed.

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
| 3 | User confirms, or reports a problem to fix (judge re-check scope yourself) | Problem → fix, judge whether to redo 1/2 |
| 4 | Open PR — only if one doesn't already exist for this branch | One PR per task, ever |
| 5 | Merge (method determined from project; conflicts judged mechanical vs. logic-divergence) | Literal `merge` keyword required; logic divergence always asks |
| 6 | Board update | Only if project uses a board; ask once per session |
| 7 | CLAUDE.md update | Only if project has a tracking section; ask once per session |
| 8 | Cleanup | Provenance check first |

## Common Mistakes

**Treating a logic-divergence conflict as mechanical**
- Problem: silently merges two incompatible intents, corrupting behavior
- Fix: when unsure which category a hunk falls into, always treat it as logic divergence and ask

**Resolving a logic-divergence conflict "the standard way" and informing the user afterward**
- Problem: the merge already happened on your judgment call before the user had a chance to object — informing after the fact doesn't undo it
- Fix: list every divergence point and get the user's answer *before* applying any resolution or merging

**Accepting "looks good" or a blanket earlier instruction as the merge confirmation**
- Problem: merge is irreversible; casual or pre-authorized confirmation isn't a deliberate act taken at the actual moment of merging
- Fix: require the literal keyword `merge`, typed at the confirmation gate itself, every time

**Defaulting to `--merge` without checking what the project actually accepts**
- Problem: a repo configured for squash-only merges will reject a plain `--merge`, and forcing the "usual" method may not match the project's actual policy
- Fix: check branch protection / recent merge history / CONTRIBUTING docs first; ask if genuinely no signal exists

**Opening a second PR for the same task after a post-test fix**
- Problem: fragments the task's history across multiple PRs and confuses reviewers/board tracking about which PR is authoritative
- Fix: check whether a PR already exists for this branch before running `gh pr create`; push fixes to the same branch instead

**Asking the board/CLAUDE.md questions when the project doesn't use either**
- Problem: wastes the user's attention on a system that isn't in use
- Fix: check for an actual board / tracking section first; skip silently if neither exists

**Asking the board/CLAUDE.md questions again after the user already answered this session**
- Problem: repeats a question the user already settled, reads as not listening
- Fix: reuse the earlier answer within the same conversation unless the user says it changed

**Cleaning up a worktree the skill didn't create**
- Problem: destroys a harness-managed or user-managed workspace
- Fix: provenance-check before removal (see finishing-a-development-branch)

## Red Flags - STOP and Ask

- About to run `gh pr merge` without the user having typed the literal word `merge` at this point in the conversation
- About to treat an earlier blanket instruction ("just merge when ready") as satisfying the merge keyword gate
- About to resolve a conflict where you're not fully sure both intents are compatible, even if your resolution feels like "the standard/correct way"
- About to run `gh pr create` when a PR already exists for this branch
- About to assume the merge method instead of checking what the project actually accepts
- About to ask the board/CLAUDE.md question when neither is actually in use on this project
- About to re-ask a board/CLAUDE.md question the user already answered earlier this session
- About to remove a worktree you didn't verify the provenance of

**All of these mean: stop, ask the user, do not proceed on assumption.**
