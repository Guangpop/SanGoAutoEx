---
description: 残りコンテキストが少ないときに、作業引き継ぎを作成してファイルに保存します（Serena不要）。
argument-hint: [作業タイトル]
allowed-tools: Read(*), Write(*), Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(date:+%Y%m%d-%H%M), Bash(mkdir -p docs/handoffs:*), Bash(tail:*), Bash(jq:*)
hook: check-context
---

## トランスクリプトからのコンテキスト情報
フックから渡されるトランスクリプトパスを使用して、現在のコンテキスト使用状況を確認します。
これは `check-context` フックによって自動的に処理されます。

## 自動取得（変更可）
- Now(時刻): !`date +%Y-%m-%d" "%H:%M`
- TS(タイムスタンプ): !`date +%Y%m%d-%H%M`
- Branch: !`git branch --show-current || echo "(no-git)"`
- Changed files: !`git diff --name-only HEAD || echo "-"`

## あなたがやること
**目的**：会話のコンパクト前に、引き継ぎ要約を**短く**作って保存する。

1) 下の**固定セクション**で、2,000文字以内の要約を作成（箇条書き中心）：
   - Goal / Scope（やること・やらないこと）
   - Key decisions（採用・却下と理由を一行ずつ）
   - Done / Pending（完了・未完）
   - Next actions（順序つき 3–7個、各≤140字）
   - Affected files（必要なら path:line）
   - Affected symbols（例: Class#method(sig)／不明なら省略可）
   - Repro / Commands（再現・実行コマンド）
   - Risks / Unknowns（不確定要素と検証案）
   - Links（PR/Issue/Docs）

2) リポジトリ直下の `CURRENT_WORK.md` に**追記**する。見出しは以下：

[Handoff] “$ARGUMENTS” — {{Now}} (branch: {{Branch}})

- ファイルが無ければタイトル `# CURRENT_WORK` を付けて新規作成。
- 直近の履歴が上に来るように追記。

3) 同じ内容を `docs/handoffs/` に**スナップショット保存**する：
- パス：`docs/handoffs/handoff-{{TS}}-{{Branch}}.md`
- ディレクトリが無ければ作成してから書き込む。

4) 最新ポインタ更新：
- `docs/handoffs/_latest.txt` に**上で作ったファイル名**を上書き保存。

### 注意
- 大きなコード貼り付けは禁止。代わりにファイル・行番号で示す。
- 具体的な編集対象（ファイル/クラス/メソッド名）を優先して書く。

