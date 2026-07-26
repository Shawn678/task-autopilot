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

See [`design.md`](design.md) for the full design rationale and
[`docs/superpowers/plans/`](docs/superpowers/plans/) for the
implementation plan. The actual skill content Claude Code reads is
[`SKILL.md`](SKILL.md).

## Installing on a new device

This skill is a global Claude Code skill — it needs to live at
`~/.claude/skills/task-autopilot/` (on Windows,
`C:\Users\<you>\.claude\skills\task-autopilot\`) so Claude Code picks it
up in every project.

### 0. Prerequisite skills

`SKILL.md` isn't fully self-contained — it explicitly hands off to a few
other skills instead of duplicating their logic. Claude Code does **not**
warn you if these are missing; it will just try to follow a reference to
a skill that doesn't exist, which can produce confused or improvised
behavior instead of a clear error. Install these first:

- **superpowers plugin** (provides `using-git-worktrees`,
  `finishing-a-development-branch`, `requesting-code-review`) — install
  via the Claude Code plugin marketplace:
  ```
  /plugin marketplace add claude-plugins-official
  /plugin install superpowers
  ```
  (Or whatever source you originally installed superpowers from, if
  different — check with `/plugin list` on your existing machine before
  moving to the new one.)
- **`run` skill** — this one isn't part of any plugin bundle; it's a
  standalone skill some Claude Code environments ship with built in.
  Check whether it's already available on the new device (look for it in
  the available-skills listing, or ask Claude "do you have a `run`
  skill?"). If it's missing, Step 2 (manual-test handoff) will fail to
  resolve — the reader will need to do the project-type detection
  manually and adapt that step by hand until it's added.

### 1. Install GitHub CLI (`gh`)

The skill drives PR creation, merging, and GitHub Projects updates
through `gh`, so it must be installed and authenticated first.

**Windows (winget):**
```powershell
winget install --id GitHub.cli -e
```
If winget complains about a broken/missing source (`Failed when opening
source(s)`), you need admin rights to fix it:
```powershell
# In an Administrator PowerShell:
winget source reset --force
```
Then retry the install from a normal (non-admin) PowerShell.

**If winget isn't usable at all:** download the installer directly from
https://github.com/cli/cli/releases/latest (the `gh_x.x.x_windows_amd64.msi`
file) and run it.

**macOS:**
```bash
brew install gh
```

**Linux:** see https://github.com/cli/cli#installation for your
distribution's package manager.

After installing, **open a new terminal window** (PATH needs to refresh
before the `gh` command is recognized).

### 2. Authenticate gh CLI

```bash
gh auth login
```

Answer the prompts:
- `What account do you want to log into?` → **GitHub.com**
- `What is your preferred protocol for Git operations?` → **HTTPS**
- `Authenticate Git with your GitHub credentials?` → **Yes**
- `How would you like to authenticate GitHub CLI?` → **Login with a web browser**

It will show a one-time code and offer to open your browser automatically.
If it doesn't, go to **https://github.com/login/device** manually and
enter the code shown in the terminal, then authorize.

Verify it worked:
```bash
gh auth status
```
Expected: `✓ Logged in to github.com account <your-username>`

### 3. Set git identity (only if this machine has never used git before)

```bash
git config --global user.name "Shawn678"
git config --global user.email "yangzixing00@gmail.com"
```

### 4. Clone this repo into the global skills directory

```bash
# Windows (Git Bash / PowerShell with git installed)
git clone https://github.com/Shawn678/task-autopilot.git "$HOME/.claude/skills/task-autopilot"

# macOS/Linux
git clone https://github.com/Shawn678/task-autopilot.git ~/.claude/skills/task-autopilot
```

If `~/.claude/skills/` doesn't exist yet, create it first:
```bash
mkdir -p ~/.claude/skills
```

### 5. Confirm Claude Code sees it

Start (or restart) a Claude Code session and check that `task-autopilot`
appears in the available-skills listing. If it doesn't show up, double
check the clone landed at exactly `~/.claude/skills/task-autopilot/`
(the folder name must match, and `SKILL.md` must be directly inside it,
not nested one level deeper).

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

## Optional: main-branch edit guard hook

[`hooks/block-main-branch-edits.sh`](hooks/block-main-branch-edits.sh) is a
separate, optional add-on — a Claude Code `PreToolUse` hook that refuses
Write/Edit calls while checked out on `main`/`master` in a real dev project
(detected by the presence of `package.json`, `pyproject.toml`,
`requirements.txt`, `setup.py`, `Pipfile`, `environment.yml`, `go.mod`,
`Cargo.toml`, `pom.xml`, `build.gradle`(`.kts`), `Gemfile`, or
`composer.json` at the repo root). It exists to stop the failure mode
where a new task starts without first creating a worktree/branch and ends
up editing the shared main branch directly, affecting other parallel
sessions. It is global config, not part of the skill itself, so it isn't
picked up automatically just by cloning this repo into `~/.claude/skills/`.

**Requires:** `bash` and `node` on PATH (used to parse the hook's JSON
stdin/output without depending on `jq`).

### Install on a new device

1. Clone this repo first per the steps above (or if already cloned, `git
   pull` to get the latest `hooks/` script).

2. Copy (or symlink) both the wrapper and its logic file into
   `~/.claude/hooks/` (the `.sh` wrapper `exec`s the `.js` file next to it,
   so both must be copied together):
   ```bash
   mkdir -p ~/.claude/hooks
   cp ~/.claude/skills/task-autopilot/hooks/block-main-branch-edits.sh ~/.claude/hooks/
   cp ~/.claude/skills/task-autopilot/hooks/block-main-branch-edits.js ~/.claude/hooks/
   chmod +x ~/.claude/hooks/block-main-branch-edits.sh
   ```

3. Add the hook to `~/.claude/settings.json` (merge into the existing
   `hooks` key if one is already present — don't overwrite unrelated
   hooks/settings):
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Write|Edit|Bash",
           "hooks": [
             {
               "type": "command",
               "command": "bash \"$HOME/.claude/hooks/block-main-branch-edits.sh\"",
               "shell": "bash",
               "statusMessage": "Checking branch isn't main/master..."
             }
           ]
         }
       ]
     }
   }
   ```

4. Reload hooks in any already-running Claude Code session by opening
   `/hooks` once, or just start a new session — new sessions pick up the
   config automatically.

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

## Updating the skill later

Since this is a normal git repo, changes made on any device sync the
usual way:
```bash
cd ~/.claude/skills/task-autopilot
git pull            # get changes made elsewhere
# ...edit SKILL.md...
git add -A && git commit -m "..." && git push   # publish changes
```
