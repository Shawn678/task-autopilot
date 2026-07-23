# task-autopilot（原 shipping-a-task）三項優化設計文件

日期：2026-07-24

## 背景與動機

`shipping-a-task` 實際使用幾天後，使用者回報三個問題：

1. **隔離不完整**：即使已經在用 worktree 平行跑任務，仍會出現 session 忘記開
   worktree、直接在 main 上工作的情況；即使只是 `commit`、`stash` 這類動作，
   也會透過共用的 `.git`（refs、`refs/stash`）或共用的 main 工作目錄影響其他
   平行 session。現有的 `hooks/block-main-branch-edits.sh` 只攔 `Write`/`Edit`
   工具，攔不住 `Bash` 工具直接下的 `git commit`/`git stash` 等指令——這正是
   `design.md` 文末「未決事項」提到、當時延後處理的 hook 化需求。
2. **代辦事項容易遺漏或亂開**：任務進行中討論到「這個先不做，之後再處理」的
   項目，沒有結構化的紀錄機制，容易在對話變長、被壓縮摘要後遺失；但如果每個
   小事項都各自開一張 issue，又會讓 issue 列表雜亂到失去追蹤價值。
3. **定位跟命名不符**：這個 skill 當初的設計動機是「減少重複溝通成本、優化
   整體任務生命週期的自動化與效率」（見 `design.md` 開頭），但命名
   `shipping-a-task` 只反映了收尾出貨這一段，跟現在要加入的「隔離安全」等
   橫跨全生命週期的內容對不上。

本文件涵蓋三項調整的完整設計，經與使用者逐項確認。

---

## Part 1：main 目錄完全隔離

### 問題範圍確認

Git worktree 機制：所有 worktree 共用同一個 `.git`（objects、refs），但各自有
獨立的工作目錄與 index/HEAD。這代表：

- 忘記開 worktree、直接在 main repo 目錄工作時，該目錄是**共用資源**——另一個
  同時要從 main 建立自己 worktree 的 session 會直接撞到檔案被改動或 HEAD 被
  移動。
- `git stash` 的 `refs/stash` 是**整個 repo 共用、不分 worktree**，main 目錄和
  某個 worktree 幾乎同時 stash/pop 會互相撞到彼此的 stash。

這是真實存在的 git 行為，不是誤解。

### 責任範圍界定

`using-git-worktrees`（任務開始時該建立 worktree 的職責）屬於 superpowers 內建
skill，不在這個 repo 的控制範圍內，無法直接修改其文字。因此本次調整的主力
放在這個 repo 確實擁有的兩個槓桿：

1. **Hook（主力，通用、不分任務階段）**——`hooks/block-main-branch-edits.sh`
2. **SKILL.md（次要，僅覆蓋 task-autopilot 自己被讀取到的範圍）**——收尾流程
   的 Step 1 自檢前防線

### Hook 擴充設計

現有 hook 只匹配 `Write|Edit` 的 `tool_input.file_path`。擴充後同時匹配
`Bash` 的 `tool_input.command`，判斷邏輯：

- **沿用現有前提**：目前分支是 `main`/`master`，且所在目錄是「真實開發專案」
  （沿用現有的 marker file 偵測：`package.json`/`pyproject.toml`/`go.mod`/
  `Cargo.toml`/`pom.xml`/`build.gradle(.kts)`/`Gemfile`/`composer.json`）。
  非 dev 專案（例如 task-autopilot 這個 repo 自己）維持現有例外，不攔。
- **判斷 cwd**：使用 hook stdin JSON 的頂層 `cwd` 欄位（Bash 工具的 session
  持續性工作目錄），沒有的話 fallback 到 `pwd`。**待實作階段驗證**：先用一次
  真實的 `Bash` PreToolUse 呼叫印出完整 stdin JSON，確認 `cwd` 欄位確實存在
  且語意如預期，再動手寫判斷邏輯——不要沒驗證就假設欄位名稱正確。
- **Bash 指令中，以下子指令視為 mutating，一律 deny**（不論搭配什麼參數，
  除非另有註明）：
  - `commit`
  - `stash`（任何子命令，包含 `list`/`show` 也一併擋，簡化判斷）
  - `merge`、`rebase`、`cherry-pick`、`revert`、`reset`
  - `checkout`、`switch`（任何形式）
  - `restore`
  - `clean`（僅當指令含 `-f`/`--force`/`-fd`/`-fx` 等強制旗標；`git clean`
    沒有強制旗標時 git 本身就會拒絕執行，風險低，不擋）
  - `push`、`pull`（`pull` 等同 fetch+merge，一樣會移動 HEAD／改動工作目錄，
    跟 `push` 同等級對待）
  - `branch`（僅當含 `-D`/`--delete --force`；一般 `-d` 保留允許，見下）
- **明確允許（allowlist，因為是這個 skill 流程本身需要在 main 根目錄執行的
  合法操作）**：
  - `status`、`log`、`diff`、`show`
  - `fetch`（更新 remote-tracking refs，不影響其他 worktree 的工作目錄）
  - `worktree add`/`list`/`remove`/`prune`
  - `branch -d`（刪除已合併分支——Step 8 清理要用）
  - `add`（純 staging，只影響 main 自己的 index，不影響其他 worktree）
- **拒絕訊息**：比照現有 Write/Edit 訊息風格，但直接附上建議指令，例如：

  > Refusing to run `<command>`: currently checked out on `<branch>`. This
  > repo uses git worktrees for isolation — create one first, e.g.
  > `git worktree add .worktrees/<branch-name> -b <branch-name>`, then retry
  > this command inside that worktree.

  目的：讓 agent 看到訊息當下就知道下一步，不需要試錯多輪才摸索出來
  （避免浪費 token）。

- **已知限制**：hook 用「目前 session 的 cwd」判斷分支，如果單一指令內先
  `cd` 到別的地方再操作 git（例如 `cd ../other-worktree && git commit`），
  hook 抓不到真正執行的目錄。這是盡力而為的安全網，用來擋「不小心忘記」，
  不是防蓄意繞過的機制，需要在 README 中明確註記這個限制。

### SKILL.md 防線（次要）

在 Step 1（自檢）最前面加一道檢查：確認目前工作目錄確實是任務用的 worktree、
不是 main 本身（例如檢查 `git rev-parse --show-toplevel` 是否落在
`.worktrees/`/`worktrees/` 底下，或分支不是 main/master）。如果發現工作其實
是直接在 main 上做的（不管什麼原因），停下來告知使用者，不能直接進入自檢
與收尾——需要先把變更移到正確的 worktree/分支。這是收尾端的最後一道防線，
無法取代 hook（因為等到收尾階段，可能已經來不及），但可以在 hook 之外多一層
保障（例如 hook 因為某種邊界情況沒攔到時）。

---

## Part 2：代辦事項一定要記錄進 issue

### 使用前提

不同專案是否使用 GitHub Issues 追蹤任務不一定，因專案而異。因此比照現有
Step 6（Projects 看板）/ Step 7（CLAUDE.md）的模式：**先偵測這個專案是否
真的有在用，沒有就整套靜默跳過，不建立新習慣、不打擾使用者**。

偵測方式：`gh issue list --limit 1`（或 `gh repo view --json hasIssuesEnabled`
確認功能有開啟且過去有使用紀錄）。**同一 session 內只偵測一次，快取判斷結果**
——不像 Step 6/7 是「問使用者一次」，這裡是「偵測一次」，因為這不是使用者
偏好問題，而是專案客觀事實，不需要每次都重新確認。

### 觸發時機：當下即時記錄

任務進行中，任何時間點，只要使用者和 agent 討論後達成「這個先不處理、之後
再說」的共識，就要**當下立刻**記錄進 issue，不要累積到最後才處理——避免
對話拉長、中途被壓縮摘要後想不起來而漏掉。

**Description 需要擴充觸發條件**：因為現有 description 只描述「實作完成、
準備出貨」的情境，agent 在任務進行中途根本不會想到要讀這個 skill。需要加入
類似「或當任務討論中識別出要延後處理的代辦事項時」的觸發子句，讓 skill 在
更早的時間點就被納入考慮。

### 分派邏輯（決策樹）

```
代辦事項出現
   │
   ▼
有明確相關的既有 open issue？──是──▶ 加註在該 issue（comment/checklist）
   │否
   ▼
夠獨立/夠份量，值得自己的驗收範圍？──是──▶ 開新 issue
   │否
   ▼
寫進常駐 "Follow-ups / Backlog" issue
（用標題比對找既有的，找不到才建立；不依賴 label，避免因 repo 沒有該
label 而建立/搜尋失敗）
```

三層判斷分別對應使用者提出的三個限制：「一定要記錄」（第一層找既有）、
「不要亂七八糟到處開」（第二層才給新 issue，且要求夠份量）、「小事不單開」
（第三層集中進常駐 backlog issue）。

「夠獨立/夠份量」判準舉例（寫進 SKILL.md 供 agent 對照，而非留給臨場自由
心證）：需要自己的驗收標準、預期要花超過一次對話/一個小任務才能完成、或
涉及獨立的設計決策 → 夠份量，開新 issue。單行敘述就能講完、修改範圍在幾行
程式碼內、不需要額外討論就知道怎麼做 → 不夠份量，進 backlog issue。

記錄完成後，立刻回報 issue 編號/連結給使用者，然後**原地繼續**原本正在做的
工作——不要把這個岔題當成需要跳出去的新任務。

### Step 8 前的掃描關卡

清理 worktree 前（Step 8 之前），加一道掃描步驟：回顧整段對話，確認所有
討論過要延後的代辦事項都已經落地到 issue（作為即時記錄機制的保險，涵蓋
「skill 還沒被載入前就討論過的代辦」這種即時記錄機制覆蓋不到的情況）。
全部確認後才繼續清理。

---

## Part 3：改名與重新定位

### 新名字

`task-autopilot`（kebab-case，符合 skill 命名規則：僅英數字與連字號）。

### 新標題與定位

`# Task Autopilot`。Overview 從「收尾出貨」改寫為涵蓋整個任務生命週期的
自動化與效率：平行 session 的隔離安全、自檢、親測交接、PR、合併（含衝突
處理）、代辦事項不遺漏、看板/CLAUDE.md 更新、worktree 清理，全部視為同一條
自動化流水線的一部分，而不只是「出貨」這一段。

### Description 調整

在原本「實作完成、準備出貨」的觸發條件之外，加入 Part 2 談好的觸發子句
（任務中討論到要延後的代辦事項）。維持 SDO 原則：只描述觸發條件，不概述
工作流程步驟。

### 改名的實際操作範圍

目前佈署狀況：`~/.claude/skills/shipping-a-task/`（此機器上 Claude Code 實際
讀取的部署位置）與這份開發用副本 `Desktop/One_Piece/SkillCreater`
（資料夾名稱本來就跟 skill 名字沒綁定，這次**不**跟著改名，維持
`SkillCreater`），兩者都指向同一個 GitHub remote `Shawn678/shipping-a-task`。

執行步驟：

1. `gh repo rename task-autopilot`——GitHub 上的 repo 改名。這是對外部共享
   資源的操作，**執行前需要另外向使用者確認一次**，不在這次批准範圍內直接
   跑。
2. 這台機器上兩份 clone（部署位置＋開發副本）的 `git remote set-url` 同步
   更新為新的 repo URL。
3. 這台機器上 `~/.claude/skills/shipping-a-task/` 資料夾改名成
   `~/.claude/skills/task-autopilot/`。
4. `README.md` 的安裝步驟改用新名字/新路徑，並新增一段「已有舊版
   shipping-a-task clone 的裝置如何遷移」的操作步驟（資料夾改名＋
   `git remote set-url`＋`git pull`）——其他裝置這個 session 碰不到，只能
   寫成文件讓使用者之後自己在那些機器上執行。
5. `design.md`、`docs/superpowers/plans/2026-07-17-shipping-a-task-skill.md`
   等歷史文件**不改內容**，只在文末加一條簡短註記說明改名這件事與生效日期，
   保留原始決策脈絡（比照 `design.md` 現有的「2026-07-19 優化修訂」附註
   模式）。

### Out of scope（本次不處理）

- 不修改 `using-git-worktrees`（不在此 repo 控制範圍）。
- 不強制專案採用 GitHub Issues 慣例——沒在用的專案，Part 2 整套靜默跳過。
- 其他裝置上舊 clone 的實際 rename 操作，本次只產出文件步驟，不代為執行。

---

## 測試計畫

### Hook（決定性程式碼，用功能測試，不用 subagent 壓力測試）

新增 `testing/hook-tests.sh`（或等效腳本），模擬 hook stdin JSON，斷言
allow/deny 結果，至少涵蓋：

| # | 情境 | 預期 |
|---|---|---|
| 1 | dev-marker 專案、main 分支、`Bash` 執行 `git commit` | deny |
| 2 | dev-marker 專案、main 分支、`Bash` 執行 `git worktree add ...` | allow |
| 3 | dev-marker 專案、feature 分支（worktree 內）、`Bash` 執行 `git commit` | allow |
| 4 | dev-marker 專案、main 分支、`Write`/`Edit` | deny（既有行為迴歸測試） |
| 5 | dev-marker 專案、main 分支、`Bash` 執行 `git stash` | deny |
| 6 | dev-marker 專案、main 分支、`Bash` 執行 `git status`/`git log` | allow |
| 7 | 非 dev-marker 專案（例如 task-autopilot 這個 repo 自己）、master 分支、`Bash` 執行 `git commit` | allow（既有例外迴歸測試） |
| 8 | dev-marker 專案、main 分支、`Bash` 執行 `git branch -d merged-branch` | allow |
| 9 | dev-marker 專案、main 分支、`Bash` 執行 `git branch -D unmerged-branch` | deny |
| 10 | dev-marker 專案、main 分支、`Bash` 執行 `git pull origin main` | deny |

### SKILL.md 新增文字（行為引導，照 writing-skills RED→GREEN 驗證）

比照現有 `testing/baseline-notes.md`/`green-phase-notes.md` 的模式，新增
「2026-07-24 Revision」段落，補兩個新情境：

- **Scenario F（代辦即時記錄）**：任務進行中，使用者說「這個 edge case
  先不修，之後再處理」。驗證重點：agent 是否當下就建立/更新 issue 並回報
  編號，而不是只在對話中口頭帶過、期待自己之後記得。
- **Scenario G（main 上直接工作）**：進入 Step 1 自檢時，diff 顯示工作其實
  是直接 commit 在 `main` 上完成的（從未建立 worktree）。驗證重點：agent
  是否停下來明確告知使用者，而不是照常自檢並準備收尾。

兩個情境都先跑 baseline（沒有新文字時的行為），再跑有新文字時的版本，
確認差異，並在發現新的迴避理由（rationalization）時，比照現有 Common
Mistakes/Red Flags 的寫法補上明確反制。
