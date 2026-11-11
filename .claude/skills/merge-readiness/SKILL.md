---
name: merge-readiness
description: |
  PRを「人がコードを見ずにマージしてよいか」判定するスキル。差分の形（危険領域・UI変更・テストの増減・大きさ）、
  PR本文の検証の証拠（Test planのチェック状況・描画確認の有無）、CIの結果、AIレビューの指摘、
  Issueの要件とテストの対応を突き合わせ、AUTO_MERGE_OK / HUMAN_REVIEW_REQUIRED / BLOCKED の3段階で判定し、
  その根拠と「人が見るべき箇所」を出す。マージ自体はしない（判定だけ）。
  使用タイミング:
  (1) 「マージしていいか判定して」「マージ判定」「レビューなしでマージできる？」と言われた時
  (2) 「/merge-readiness」コマンドが実行された時
  (3) PR作成後、/code-review を終えてマージ前の最終確認をする時
  引数: [PR番号]（省略時: 現在のブランチのPR）
  オプション: --comment（判定結果をPRコメントに投稿）
---

# Merge Readiness

PRを「人がコードを見ずにマージしてよいか」判定する。**マージはしない**。判定と根拠を出すところまでがこのスキルの仕事。

公開されているレビュー用プラグイン（`code-review`・`pr-review-toolkit`・Claude Code Review等）は、どれも
「指摘を出す」ところまでで「マージしてよいか」は判定しない（判定は人に委ねる設計）。そのため本プロジェクトでは、
AIレビューの指摘を**判定材料の1つ**として使い、それ以外の判定材料（危険領域・検証の証拠・要件との対応）と合わせて
このスキルが判定する。調査の経緯は[`docs/dev/plans/merge-readiness-gate/`](../../../docs/dev/plans/merge-readiness-gate/)を参照。

## 判定の3段階

| 判定 | 意味 | 次の行動 |
|------|------|---------|
| `AUTO_MERGE_OK` | 機械的に見ても、AIレビューで見ても、人がコードを見る理由がない | マージしてよい（現段階では人がマージボタンを押す） |
| `HUMAN_REVIEW_REQUIRED` | 人の判断か、まだ揃っていない検証がある | 「人が見るべき箇所」だけを人が見る、または足りない検証を足して再判定 |
| `BLOCKED` | マージしてはいけない | 指摘を直して再判定 |

判定は「最も重い指摘」で決まる（1つでも`BLOCKED`があれば`BLOCKED`）。

## 実行フロー

```
Step 1: 対象PRの情報を集める（本文・CI・Issue）
Step 2: 機械判定（classify_pr.py）
Step 3: AIレビュー（/code-review）
Step 4: 要件とテストの対応表を作る
Step 5: 判定をまとめて報告（--comment時はPRに投稿）
```

## Step 1: 情報を集める

1. PR番号を決める（引数、なければ現在のブランチのPR）
2. PR本文・head SHA・CIの結果（check runs）を取る。GitHub MCPが使える環境では`pull_request_read`
   （`method: "get"` と `"get_check_runs"`）、ローカルでは`gh pr view N --json body,headRefOid`と`gh pr checks N`
3. CIの結果を `pass` / `fail` / `pending` に丸める（`CI`ジョブが`success`なら`pass`。1つでも`failure`なら`fail`。
   実行中・未実行なら`pending`）
4. PR本文の`Closes #N`からIssueを読む（Step 4で使う）
5. PR本文を一時ファイル（スクラッチパッド）に保存し、`git fetch origin main <head branch>`する

## Step 2: 機械判定

```bash
python3 .claude/skills/merge-readiness/scripts/classify_pr.py --base origin/main --head <headのSHA> --body <本文ファイル> --ci <pass|fail|pending>
```

JSONで`verdict`と`findings`（`rule`・`message`）が返る。終了コードは 0=AUTO / 1=HUMAN / 2=BLOCKED / 3=実行エラー。
見ているルールは以下（詳細と根拠は`scripts/classify_pr.py`の定数を参照）。

| rule | 判定 | 内容 |
|------|------|------|
| `ci` | BLOCKED / HUMAN | CIが失敗 / 未確定 |
| `test-deleted` | BLOCKED | テストファイルの削除 |
| `test-skip` | BLOCKED | `do_skip`の追加 |
| `test-func-removed` | HUMAN | `test_`関数の純減 |
| `print` | HUMAN | 本番コードへの`print()`追加 |
| `sensitive` | HUMAN | 危険領域（CI・設定・セーブ・アドオン・バランス数値・マスターデータ・この判定の仕組み自体） |
| `no-test` | HUMAN | コード変更にテスト変更が伴わない |
| `no-visual-evidence` | HUMAN | UI・シーン・アセット変更なのに、描画E2Eかgodot-visual-checkの実施がPR本文にない |
| `unverified` | HUMAN | Test planに未チェック項目がある |
| `no-body` / `no-test-plan` | HUMAN | 何を検証したか書かれていない |
| `too-large` | HUMAN | 差分400行超（`.uid`・ロック・ドキュメント除く） |

> 🔴 `classify_pr.py`は**差分の形とPR本文しか見ない**。コードの正しさは見ない。
> PR本文の「修正前に失敗することを確認済み」は自己申告であり、このスクリプトは真偽を確かめられない
> （機械的に確かめる仕組みは未整備。`docs/dev/plans/merge-readiness-gate/plan.md` Phase 2参照）。

## Step 3: AIレビュー

`/code-review`（Claude Code組み込み）を`high`でPRに対して実行する（`/code-review high <PR番号>`）。
指摘を次のように判定へ写す。

| AIレビューの指摘 | 判定 |
|------------------|------|
| 実行時エラー・データ破損・ゲームロジックの誤り（[`code-review.md`](../../rules/code-review.md)のCritical相当） | BLOCKED |
| それ以外の正しさの指摘（PLAUSIBLE含む） | HUMAN（指摘箇所を「人が見るべき箇所」に入れる） |
| 指摘なし | 判定に影響しない |

> 🔴 指摘なしは「問題がない」ことの証明ではない（どのレビューツールも公式にそう明記している）。
> AIレビューは**HUMAN/BLOCKEDに倒す方向にだけ**使い、AUTOに倒す根拠には使わない。

## Step 4: 要件とテストの対応表

IssueやPlan（`docs/dev/plans/*/acceptance-criteria.md`）にある要件・受入基準を1行ずつ並べ、
それぞれを確かめている証拠を対応づける。

| 要件 | 証拠 | 種類 |
|------|------|------|
| 終了ボタンが画面内に収まる | `test_title_screen.gd::test_全ボタンが画面内に収まる` | 自動テスト（CI） |
| 見た目が崩れていない | なし（godot-visual-check未実施） | — |

証拠の種類は強い順に「自動テスト（CIで実行）」＞「描画E2E（ローカル実行、PR本文に結果あり）」＞
「手動確認（PR本文に記載）」。**証拠のない要件が1つでもあれば HUMAN**。
テストを読み、テスト名だけでなく、本当にその要件をassertしているかを確かめる
（例: 「重ならない」という名前で、矩形を比べずに`visible`だけ見ているテストは証拠にしない）。

## Step 5: 報告

```markdown
## 🚦 Merge Readiness: HUMAN_REVIEW_REQUIRED

**PR**: #N <タイトル>（head: <SHA先頭7桁>）
**CI**: pass

### 判定の根拠
| 判定 | 出どころ | 内容 |
|------|---------|------|
| HUMAN | classify_pr: no-visual-evidence | UI変更だが描画確認がない |
| HUMAN | AIレビュー | `foo.gd:42` でnullを返す経路がある（PLAUSIBLE） |

### 要件と証拠
（Step 4の表）

### 人が見るべき箇所（これだけ見ればよい）
- [ ] `atelier/features/.../foo.gd:42` — AIレビューの指摘
- [ ] 画面の見た目 — `/godot-visual-check alchemy` を実行するか、目で確認する

### AUTO_MERGE_OK にするには
- 描画E2E（`uv run --project tests/e2e_mcp atelier-e2e`）を実行し、結果をTest planにチェック済みで書く
```

「人が見るべき箇所」は、人がコード全体を読まずに済むよう、ファイル:行と確認内容を具体的に書く。
`--comment`指定時はこのレポートをPRコメントとして投稿する（末尾にこのスキルによる自動判定である旨を書く）。

## やらないこと

- マージ・承認（approve）はしない。判定だけ出す
- 判定を甘くするためにPR本文のチェックを付け替えない。未実施の検証は未実施のまま報告する
- 実施していない検証を実施済みと書かない（[`godot-debug-tools.md`](../../rules/godot-debug-tools.md)「禁止事項」）

## 判定ルールを変えるとき

`scripts/classify_pr.py`の定数を変え、`scripts/test_classify_pr.py`にケースを足して
`python3 -m unittest discover -s .claude/skills/merge-readiness/scripts`で確かめる。
このディレクトリ自体が危険領域（`sensitive`）に入っているため、判定ルールの変更PRは必ず人の確認になる。

## 音声通知

VOICEVOXが使える場合のみ: 開始「マージ判定を開始するのだ」／完了「判定は{判定}なのだ」（speaker=3, speedScale=1.3）
