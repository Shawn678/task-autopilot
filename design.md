# shipping-a-task 設計文件

日期：2026-07-17

## 背景與動機

使用者大量使用 Claude Code，慣用工作方式是同時開 2~3 個 worktree/分支平行跑不同任務。每個任務走到收尾階段時，都要重複提醒 Claude 走完同一串手動步驟：

1. 完成實作
2. 經使用者確認沒問題
3. 開 PR
4. 使用者手動合併（有時要處理合併衝突）
5. 合併完成後更新 CLAUDE.md
6. 更新 GitHub Projects 看板的狀態欄位
7. 清理 worktree / 分支等善後檔案

這一串流程每次都要口頭提醒，希望寫成 skill 自動走完，減少重複溝通成本。

## 範圍界定

- **只處理單一任務的完整生命週期**（從開發完成到善後清理），不處理跨分支的協調或總覽功能。
- 使用者會平行呼叫這個 skill 多次（每個 worktree/session 各自跑一份），彼此不需要感知對方狀態。GitHub Projects 看板本身就是天然的總覽，不需要額外構建協調層。

## 與既有 skills 的關係

這個 skill 不重造輪子，而是在既有 superpowers skills 的空隙上補完整條流水線：

| 既有 skill | 覆蓋範圍 | 本 skill 的處理方式 |
|---|---|---|
| `using-git-worktrees` | 建立 worktree | 沿用，作為前置條件（任務開始前已建立） |
| `run` | 偵測專案類型、啟動/驅動 app | 複用於「親測交接」步驟，判斷交付形式 |
| `finishing-a-development-branch` | 呈現 merge/PR/keep/discard 選項；PR 建立；worktree 清理（含 provenance 檢查） | 參考其 PR 建立邏輯與 worktree 清理邏輯；但**不使用**它的合併邏輯（它不處理自動合併與衝突解決，也不管合併後續） |

關鍵空白：`finishing-a-development-branch` 開完 PR 或本地 merge 後就結束了，完全不處理「使用者去 GitHub 網頁手動合併、可能要解衝突、合併後看板/CLAUDE.md 善後」這一段。這正是本 skill 要補上的核心價值。

## 整體流程

```
1. 完成度自檢
   Claude 執行 lint / test / 既有 code-review 類 skill 做自我檢查。

2. 親測交接
   複用 `run` skill 的專案類型偵測能力，判斷這個專案的交付形式：
     - 直接啟動（如 npm run dev）
     - 需要建置產物（如編譯成 DLL、打包）
     - 其他形式
   根據判斷結果準備對應的操作說明，或先執行必要的建置步驟。
   然後暫停，明確告知使用者「在哪個 worktree 路徑、用什麼指令/方式可以本地測試」，
   等待使用者回饋。

3. 使用者確認
   - 若有問題：Claude 修正後回到步驟 1 重新自檢。
   - 若確認 OK：進入步驟 4。

4. 開 PR
   使用 gh pr create。可參考 finishing-a-development-branch 的 PR 建立邏輯。

5. 自動合併
   使用 gh pr merge --merge（merge commit，保留完整分支歷史）。
   - 合併前先偵測是否有衝突（如 git merge-tree 或試合併），依衝突性質分兩級處理：

     **機械式衝突**（如 import 排序、格式化、鎖檔案等無語意歧義的衝突）：
       a. Claude 自行解決。
       b. 標註「機械式衝突，已自動解決」。
       c. 呈現解法變更內容給使用者確認。

     **邏輯分歧衝突**（雙方對同一段邏輯有不同修改意圖，Claude 無法確定哪種改法
     才符合使用者原意）：
       a. 不自行決定，而是逐點列出每一個分歧點：修改前內容、分支A的改法、
          分支B的改法、以及為何無法自動判斷。
       b. 針對每個分歧點分別詢問使用者要保留哪一邊、如何整合，或提出第三種寫法。
       c. 等所有分歧點都確認完畢後，才套用整合結果並繼續合併流程。
       d. 這個過程視為在合併流程中「就地」進行，不需要跳出去開新的任務/對話。

   - 不論是機械式還是邏輯分歧衝突，在真正執行合併指令前，都要求使用者輸入明確
     關鍵字（如輸入 "merge"）才會真正送出，作為不可逆操作前的最終確認關卡。

6. 看板狀態更新
   每次都詢問使用者「要不要把這個項目在 GitHub Projects 的狀態改成 Done（或使用者
   指定的完成欄位）」。若同意，使用 gh project item-edit 或對應 GraphQL API 更新。
   若專案沒有設定 GitHub Projects 或找不到對應項目，如實告知，不靜默跳過也不報錯中斷。

7. CLAUDE.md 更新
   每次都詢問使用者「要不要清除/更新 CLAUDE.md 中『目前進行中任務』相關紀錄」。
   若同意且該檔案存在對應段落，進行編輯。若專案沒有 CLAUDE.md 或沒有相關段落，
   如實告知，不靜默跳過。

8. 清理善後
   套用 finishing-a-development-branch 的 worktree 清理邏輯：
     - provenance 檢查（只清理 skill 自己建立、位於 .worktrees/ 或 worktrees/ 下的 worktree）
     - cd 回主 repo 根目錄再執行 git worktree remove
     - git worktree prune
     - 刪除已合併的分支（git branch -d）
```

## 關鍵設計決策

| 決策點 | 選擇 | 理由 |
|---|---|---|
| Skill 範圍 | 單一任務生命週期 | 多分支只是平行呼叫多次；看板即總覽，不需額外協調層 |
| 親測交接 | Claude 先自檢，再自動偵測交付形式準備測試環境，暫停等回饋 | 使用者要親自驗證成果，但不想自己每次都要找路徑/指令/組建置 |
| 合併執行者 | Claude 直接用 gh CLI 執行合併，不要求使用者去網頁點按鈕 | 消除「使用者手動合併再回報」的斷點，這是原本流程中最繁瑣的一環 |
| 合併衝突分級 | 機械式衝突：自解後呈現確認；邏輯分歧衝突：逐點就地詢問使用者，全部確認後才繼續 | 機械式衝突效率優先；邏輯分歧沒有客觀正確答案，Claude 不該替使用者做決定 |
| 合併方式 | Merge commit | 保留完整分支歷史（使用者明確選擇，非 squash） |
| 合併前最終確認 | 要求輸入明確關鍵字（如 "merge"）才真正執行 | 合併是不可逆操作，需要比一般確認更高的門檻，避免誤觸發 |
| 看板 / CLAUDE.md 更新 | 每次都詢問，不做靜默判斷或自動跳過 | 避免「以為做了但沒做」的落差感；不同專案設定差異大 |
| 清理邏輯 | 複用 finishing-a-development-branch 的 worktree 清理與 provenance 檢查 | 避免重複造輪子，並繼承其已考慮過的邊界情況 |
| 安裝範圍 | 全域安裝（~/.claude/skills） | 使用者大量且跨專案使用 Claude Code，通用性優先 |

## 容錯與邊界情況

- **沒有 GitHub Projects 看板的專案**：步驟 6 詢問後，若使用者想更新但找不到對應設定，如實回報「找不到看板項目」，不阻斷後續流程。
- **沒有 CLAUDE.md 或無相關段落的專案**：步驟 7 詢問後如實回報，不阻斷後續流程。
- **worktree 不是本 skill/superpowers 建立的（harness 託管）**：沿用 finishing-a-development-branch 的 provenance 規則，不清理非自己建立的 worktree。
- **測試失敗 / lint 失敗**：比照 finishing-a-development-branch 的原則，停在步驟 1，不得進入後續步驟。
- **合併衝突涉及大量檔案或 Claude 判斷無法安全解決**：如實告知「無法自動解決，需要使用者手動介入」，展示衝突內容，不要求輸入 "merge" 確認強行推進。

## 交付形式（跨裝置使用）

這個 skill 需要能帶到其他裝置上使用，因此以獨立 git repo 的形式交付：

- 在 `~/.claude/skills/shipping-a-task/` 建立獨立 git repo（與此設計文件同一目錄）。
- push 到 GitHub 上的 private repo `shipping-a-task`。
- 其他裝置只需要 `git clone` 這個 repo 到自己的 `~/.claude/skills/shipping-a-task/`，即可讓 Claude Code 讀到這個全域 skill。
- 之後對 skill 的修改，透過一般的 git commit + push / pull 在多裝置間同步，不需要額外的分發機制。

## 未決事項 / 待實作階段細化

以下細節留待寫實作計畫（writing-plans）時具體化：

- gh project item-edit 的具體欄位名稱與 project number 如何自動探測（可能需要在專案內尋找設定，或每次詢問使用者是哪個 project）。
- CLAUDE.md 中「進行中任務」段落的辨識方式（是否需要約定固定標題格式，或用啟發式搜尋）。
- 親測交接步驟中，若專案需要編譯打包（如 DLL），建置產物要放在哪裡、如何呈報路徑給使用者。
- 與 finishing-a-development-branch 之間具體是「呼叫」還是「複製邏輯後獨立維護」，需在寫 SKILL.md 時定案（傾向於行為一致但獨立成檔，避免跨 skill 呼叫的耦合問題，待寫作階段依 superpowers 慣例決定）。
