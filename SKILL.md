---
name: shipping-a-task
description: Use when implementation is complete and passing self-checks, and a finished task needs to go through manual testing, PR creation, merge, and cleanup all the way to done - especially when the user wants the merge itself handled (not just the PR), including situations with merge conflicts or a GitHub Projects board/CLAUDE.md to update afterward; also use mid-task, whenever a discussion identifies follow-up work to defer rather than do now, so it gets captured before it's lost
---

# Shipping a Task

## Overview

Carries a single completed task from self-check through merge and cleanup, so you don't have to re-explain the same handoff steps every time you finish work in a worktree. Fills the gap after PR creation: this skill also drives the actual merge (including conflict handling) and the post-merge housekeeping (board status, CLAUDE.md), which superpowers:finishing-a-development-branch stops short of.

**Announce at start:** "I'm using the shipping-a-task skill to ship this task."

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

**Before removing anything**, do the deferred-work sweep described in
"Deferred Work → Issues" above — confirm every item raised during this
task that will not be done now has landed in an issue. Once the worktree
is gone, the conversation's working context goes with it.

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
| 1 | Verify work is in a worktree (not main/master), then self-check (lint/test/review) | Must pass before Step 2; stop if work happened on main |
| 2 | Hand off for manual test | Wait for user response |
| 3 | User confirms, or reports a problem to fix (judge re-check scope yourself) | Problem → fix, judge whether to redo 1/2 |
| 4 | Open PR — only if one doesn't already exist for this branch | One PR per task, ever |
| 5 | Merge (method determined from project; conflicts judged mechanical vs. logic-divergence) | Literal `merge` keyword required; logic divergence always asks |
| 6 | Board update | Only if project uses a board; ask once per session |
| 7 | CLAUDE.md update | Only if project has a tracking section; ask once per session |
| 8 | Cleanup | Deferred-work sweep first, then provenance check |
| ongoing | Deferred work → issue (real-time, whenever raised) | Only if project uses GitHub Issues; detect once per session |

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

## Red Flags - STOP and Ask

- About to run `gh pr merge` without the user having typed the literal word `merge` at this point in the conversation
- About to treat an earlier blanket instruction ("just merge when ready") as satisfying the merge keyword gate
- About to resolve a conflict where you're not fully sure both intents are compatible, even if your resolution feels like "the standard/correct way"
- About to run `gh pr create` when a PR already exists for this branch
- About to assume the merge method instead of checking what the project actually accepts
- About to ask the board/CLAUDE.md question when neither is actually in use on this project
- About to re-ask a board/CLAUDE.md question the user already answered earlier this session
- About to remove a worktree you didn't verify the provenance of
- About to run a Bash git command (`commit`, `stash`, `merge`, etc.) directly against `main`/`master` because "it's just this once"
- About to run `git reset --hard`, branch/checkout surgery, or any other "cleanup" command against `main`/`master` to fix a provenance problem you just found, before the user has said how they want it handled
- About to move on from a "let's do this later" moment without creating or updating an issue first
- About to open a brand-new issue for something that would fit as one checklist line on an existing or backlog issue
- About to run `git worktree remove` in Step 8 without having swept the conversation for uncaptured deferred items

**All of these mean: stop, ask the user, do not proceed on assumption.**
