# マージ判定ゲート（merge-readiness）

作成日: 2026-11-11

## 目的

PRを「人がコードを見ずにマージしてよいか」判定できるようにする。最終的には「実装 → 検証 → マージ」をループで回したいが、
その前提として**検証が十分かどうかの判定が取れるか**をまず確かめる（本Planの範囲はここまで）。

## 調査: PR作成・レビュー用のプラグイン

| 候補 | 何をするか | マージ可否の判定 | 本プロジェクトでの使い道 |
|------|-----------|-----------------|------------------------|
| `code-review`（claude-plugins-official） | 4エージェント並列（CLAUDE.md準拠×2・バグ・git履歴）。指摘ごとに0〜100の確信度を付け、80未満を捨てる。`--comment`でPRに投稿 | **しない**（指摘を出すだけ。READMEも「人のレビューの出発点」とする） | 判定材料の1つ。Claude Code組み込みの`/code-review`で同等のことができる |
| `pr-review-toolkit`（同上） | 6エージェント（コメント精度・テスト網羅性・握りつぶし・型設計・規約・簡素化）。`pr-test-analyzer`がテストの抜けを1〜10で評価 | **しない** | テストの抜けを見るのに有用。ただしGDScript向けではなく、本プロジェクトのrulesで代替できる部分が多い |
| Claude Code Review（Team/Enterprise向けの管理サービス） | PRごとに複数エージェントでレビューし、検証ステップで誤検知を落として重大度順にインラインコメント。check runを付ける | **しない**（check runは失敗にならない。「マージの判断はチームに残る」と明記） | Teamプラン以上なら導入候補。判定材料が増えるだけで、判定は自前で要る |
| `claude-code-action@v1`（GitHub Actions） | CIで任意のプロンプト・スキル・プラグインを実行 | 自分で作れば可能 | Phase 3で、このスキルをCIから動かす土台になる |
| `ralph-loop`（同上） | Stopフックで同じプロンプトを繰り返し投入し、完了の合言葉が出るまでループ | — | Phase 4のループ実行の候補。`.claude/settings.json`では無効化済み（`false`） |

### 業界の事例（AIにマージさせている組織の共通点）

- 自動マージの対象は**「低リスク」と判定されたPRに限る**。判定は、まず決定的なルール（危険なパスに触れたら人へ回す等）、
  次にリスクスコア、最後にLLMレビューの順で重ね、どれか1つでも危険を示したら人へ回す（Meta RADAR、Vercel、Rewind等）
- 認証・課金・秘密情報・インフラに触れる変更は、エージェントの確信度にかかわらず人の承認を必須にする
- しきい値は保守的に始め、誤判定の記録を見ながら緩める
- AIレビューは業務ロジックの誤り・競合状態を見落としやすい。「AIレビューが通った」ことで人の注意が下がる点にも注意が要る

### 結論

**「マージしてよいか」を判定するプラグインは見つからなかった**。公開されているレビューツールは公式・サードパーティとも
「指摘を出す」ところまでで、判定は人に委ねる設計になっている。そこで、AIレビューの指摘を判定材料の1つとして使い、
決定的なルールと検証の証拠を合わせて判定する仕組みを、本プロジェクト用のスキルとして作った
（[`merge-readiness`スキル](../../../../.claude/skills/merge-readiness/SKILL.md)）。

## 作ったもの

| ファイル | 内容 |
|---------|------|
| `.claude/skills/merge-readiness/SKILL.md` | 判定の手順（機械判定 → AIレビュー → 要件とテストの対応 → 報告）。マージはしない |
| `.claude/skills/merge-readiness/scripts/classify_pr.py` | 差分の形とPR本文から機械的に判定する（危険領域・UI変更の描画確認・テストの削除やskip・未検証項目・差分の大きさ） |
| `.claude/skills/merge-readiness/scripts/test_classify_pr.py` | 上記の単体テスト（標準ライブラリのみ、20件） |
| `.github/pull_request_template.md` | 判定が読み取れる形のTest plan（実施/未実施をチェックボックスで分ける） |

## 試行: 直近にマージ済みのPRへ当てた結果

マージ済みのPR #94〜#101（8件）に`classify_pr.py`を当てた（CIは全件成功として扱った）。

| PR | 判定 | 理由 |
|----|------|------|
| #94 調合画面の投入枠の潰れ | HUMAN | UI変更なのに描画確認なし（MCP接続タイムアウトで未実施） |
| #95 タイトル画面の終了ボタンのはみ出し | HUMAN | 同上 |
| #96 タブバーの背景 | HUMAN | 同上 |
| #97 DebugPanelの配置 | HUMAN | 同上 |
| #98 自シーンpreloadの循環参照 | HUMAN | `.tscn`変更あり・エディタ起動時の確認が未実施 |
| #99 エクスポートからテストを除外 | HUMAN | 危険領域（`export_presets.cfg`）・exe起動確認が未実施 |
| #100 godot-ai MCPの起動方法 | HUMAN | 危険領域（`.mcp.json`）・再起動後の接続確認が未実施 |
| #101 描画E2Eの追加 | HUMAN | 差分913行・レビュアー環境での実行確認が未実施 |

**判定は取れる**。8件すべてが「人の確認が必要」になり、理由もPR本文に書かれた未実施項目と一致した
（各PRの作成者が自分で「未実施」と書いていた項目を、判定が拾えている）。

一方で、**今の検証のやり方では、自動でマージしてよいPRが1件も出ない**ことも分かった。最大の原因は描画の確認で、
クラウドセッションではgodot-ai MCPが使えない（Godotエディタが無い）ため、UIを触るPRは必ず描画確認が抜ける。
レビュー用のプラグインを足しても、この穴は埋まらない。

## 判定でまだ見られないこと（既知の限界）

- **「修正前のコードで失敗することを確認済み」は自己申告**で、真偽を機械的に確かめていない（Phase 2で対応）
- 判定ルールの誤り（本当は危ないのにAUTOになる）の検出は、まだ実績で確かめていない。
  AUTOになったPRが後で不具合を出したら、その形をルールとテストに足す
- ブランチ保護（必須チェック・承認の要否）の設定状況は、このセッションからは確認していない

## ロードマップ

1. **Phase 1（本Plan）**: 判定が取れるかを確かめる — 完了。判定は取れるが、今は全件HUMANになる
2. **Phase 2: 検証の穴を埋める**
   - 「テストが修正前に失敗するか」をCIで確かめるジョブを足す（PRで追加・変更されたテストを、mainのコードに対して実行し、
     失敗することを確認する。新機能でクラスが無く読み込みに失敗する場合も「失敗」とみなす）
   - UI変更の描画確認を、クラウドセッションでも取れるようにする。案: CIのXvfb上でGodotを非headlessで起動し、
     描画E2Eと同じ矩形チェックをGDScriptで行う（MCP不要）。現状の描画E2EはGodotエディタ＋MCP前提でローカル専用
3. **Phase 3: 判定をCIに載せる**: `claude-code-action@v1`でPRごとにこのスキルを実行し、判定をPRコメントとcheck runで残す
4. **Phase 4: ループ化**: AUTO_MERGE_OKのPRだけ自動マージ（`enable_pr_auto_merge`）し、HUMANは人へ通知する。
   最初は「AUTO判定でも人がマージボタンを押す」運用で、判定と人の判断のずれを記録してからしきい値を緩める

## 参考

- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official)（`code-review`・`pr-review-toolkit`・`ralph-loop`のREADME）
- [Claude Code GitHub Actions](https://code.claude.com/docs/en/github-actions.md)
- [Claude Code Review](https://code.claude.com/docs/en/code-review.md)
- [Rewind: How we let AI approve pull requests (safely)](https://rewind.com/blog/ai-approve-pull-requests-safely/)
- [Vercel: 58% of PRs in our largest monorepo merge without human review](https://vercel.com/blog/58-percent-of-prs-in-our-largest-monorepo-merge-without-human-review)
- [Automating Low-Risk Code Review at Meta: RADAR](https://www.themoonlight.io/en/review/automating-low-risk-code-review-at-meta-radar-risk-calibration-and-review-efficiency)
- [Augment Code: AI agents pull request approval guardrails](https://www.augmentcode.com/guides/ai-agents-pull-request-approval-guardrails)
