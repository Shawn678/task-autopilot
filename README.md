# shipping-a-task

A Claude Code skill that carries a single development task from
self-check through manual testing, PR creation, merge (including
conflict resolution), post-merge board/CLAUDE.md updates, and worktree
cleanup — so you don't have to re-explain the same handoff steps every
time you finish work in a worktree.

See [`design.md`](design.md) for the full design rationale and
[`docs/superpowers/plans/`](docs/superpowers/plans/) for the
implementation plan. The actual skill content Claude Code reads is
[`SKILL.md`](SKILL.md).

## Installing on a new device

This skill is a global Claude Code skill — it needs to live at
`~/.claude/skills/shipping-a-task/` (on Windows,
`C:\Users\<you>\.claude\skills\shipping-a-task\`) so Claude Code picks it
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
git clone https://github.com/Shawn678/shipping-a-task.git "$HOME/.claude/skills/shipping-a-task"

# macOS/Linux
git clone https://github.com/Shawn678/shipping-a-task.git ~/.claude/skills/shipping-a-task
```

If `~/.claude/skills/` doesn't exist yet, create it first:
```bash
mkdir -p ~/.claude/skills
```

### 5. Confirm Claude Code sees it

Start (or restart) a Claude Code session and check that `shipping-a-task`
appears in the available-skills listing. If it doesn't show up, double
check the clone landed at exactly `~/.claude/skills/shipping-a-task/`
(the folder name must match, and `SKILL.md` must be directly inside it,
not nested one level deeper).

## Using the skill

Once installed, Claude Code will offer to use `shipping-a-task` when a
task is implemented and ready to ship — or you can explicitly ask for it
(e.g. "use the shipping-a-task skill to wrap this up"). It walks through
self-check → manual test handoff → PR → merge (asking before resolving
any conflict that isn't purely mechanical, and requiring you to type the
literal word `merge` before it actually merges) → asking about board and
CLAUDE.md updates → cleanup.

## Updating the skill later

Since this is a normal git repo, changes made on any device sync the
usual way:
```bash
cd ~/.claude/skills/shipping-a-task
git pull            # get changes made elsewhere
# ...edit SKILL.md...
git add -A && git commit -m "..." && git push   # publish changes
```
