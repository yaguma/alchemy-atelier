# rank-ui 要件定義書

## 概要

「Atelier」のPhase 2機能実装として、UI設計文書 `docs/design/atelier-alchemy-core/ui-design/overview.md` の SCR-006「結果画面（ゲームクリア/ゲームオーバー）」を新規実装する。

現状 `atelier/features/rank/ui/` は `.gitkeep` のみで完全未着手である。一方、ランク進行・昇格試験のドメインロジック（`RankQuotaResolver`/`TurnLimitResolver`/`RankOutcome`/`RankMaster`/`RankState`/`PromotionExamResolver`/`ExamOutcome`/`RankProgression`/`ExamState`、および`autoload/game_state.gd`＋`autoload/game_state_rank_delegate.gd`によるApplication層委譲）は先行Plan（rank・rank-up）で実装・マージ済みである。

本Planには重要な設計ギャップの解消が前提作業として含まれる。現在、「Sランク（最終ランク）で昇格試験に成功した＝ゲームクリア」を明示的に区別するsignal/APIが存在しない。`atelier/autoload/game_state_rank_delegate.gd`の`_commit_exam_success()`（157-176行目）は、`RankProgression.get_next_rank_id(current_rank_id)`が空文字列`&""`を返した場合（＝最終ランクで次ランクが存在しない＝ゲームクリア相当）に、単に`_in_exam = false`として早期returnするのみで、この分岐を区別する信号を一切発行していない。同関数には次ランクのRankMasterがマスターデータに未登録というエラー分岐（166-169行目）も存在し、そちらも同様に`current_rank_id`を変えずに早期returnするため、「current_rank_idが変化しないままSUCCESS確定」というシグナルだけでは真のゲームクリアとマスターデータ欠落エラーを区別できない。本Planでは新規シグナル`game_cleared`を追加し、この区別を可能にする。

本Planの対象はSCR-006結果画面（ゲームクリア/ゲームオーバー）**のみ**。SCR-005昇格試験画面（PromotionExamScreen）は別Planのスコープであり、本Planには含まない。

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: [plan.md](plan.md)

## 用語集

| 用語 | 定義 |
|-----|------|
| ResultScreen | 本Planで新規実装する`Control`継承の単一シーン（`features/rank/ui/result_screen.gd`/`.tscn`）。ゲームクリア/ゲームオーバーの結果種別メッセージのみを表示する |
| `game_cleared` | 本Planで`autoload/game_state.gd`に新規追加するシグナル。最終ランク（Sランク相当）での昇格試験成功時にのみ発行される |
| `game_over(demotion_count: int)` | 既存シグナル。降格の累積等によりゲームオーバー条件が成立した際に発行される（`autoload/game_state.gd` 19行目） |
| `_commit_exam_success()` | `atelier/autoload/game_state_rank_delegate.gd`内の関数。昇格試験SUCCESS確定時の内部処理を担う（157-176行目） |
| 真のゲームクリア | 現在ランクがRANK_ORDER末尾（最終ランク）であり、`RankProgression.get_next_rank_id()`が空文字列を返す状態でSUCCESS確定した場合を指す。次ランクのRankMaster欠落エラーとは区別する |
| SCR-006 | `docs/design/atelier-alchemy-core/ui-design/overview.md`で定義される画面ID。結果画面（ゲームクリア/ゲームオーバー）を指す |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: ResultScreen（`Control`継承の単一シーン）は、`GameState.game_over`および`GameState.game_cleared`シグナルを自身の`_ready()`で購読しなければならない 🔵 *[ヒアリング決定事項3、`.claude/rules/state-management.md`「UIコンポーネントでの状態監視」]*
  - 関連: US-003, AC-003
- **FR-002**: ResultScreenは、クリア表示とオーバー表示を単一の`Control`シーン内部で切り替えて表示しなければならない（別シーン・別コンポーネントに分割しない） 🔵 *[ヒアリング決定事項4]*
  - 関連: US-001, US-002, AC-001, AC-002
- **FR-003**: ResultScreenは、表示内容として結果種別を示すメッセージのみを表示しなければならない 🔵 *[ヒアリング決定事項5]*
  - 関連: US-005, AC-008
- **FR-004**: GameStateは、既存の`game_over(demotion_count: int)`と対称的な新規シグナル`game_cleared`を提供しなければならない 🔵 *[ヒアリング決定事項2]*
  - 関連: US-001, AC-001

### イベント駆動要件（WHEN-THEN）

- **FR-101**: `game_state_rank_delegate.gd`の`_commit_exam_success()`内で`RankProgression.get_next_rank_id(current_rank_id)`が空文字列`&""`を返した場合（最終ランクでの昇格試験成功＝真のゲームクリア）、GameStateは`game_cleared`シグナルを発行しなければならない 🔵 *[ヒアリング決定事項2、`game_state_rank_delegate.gd` 159-163行目]*
  - 関連: US-001, AC-001
- **FR-102**: `GameState.game_cleared`シグナルが発行された場合、ResultScreenは内部表示をクリア表示に切り替えなければならない 🔵 *[ヒアリング決定事項3]*
  - 関連: US-001, AC-001
- **FR-103**: `GameState.game_over`シグナルが発行された場合、ResultScreenは内部表示をオーバー表示に切り替えなければならない 🔵 *[ヒアリング決定事項3、既存`game_over`シグナル]*
  - 関連: US-002, AC-002
- **FR-104**: ResultScreenノードがシーンツリーから除去される場合（`_exit_tree()`）、ResultScreenは`game_over`・`game_cleared`両シグナルへの接続を`is_connected()`チェックの上`disconnect()`しなければならない 🔵 *[`.claude/rules/state-management.md`「signal（EventBus相当）」、`.claude/rules/ui-components.md`「破棄チェックリスト」]*
  - 関連: US-003, AC-003

### 状態駆動要件（WHERE）

- **FR-201**: 次ランクのRankMasterが`_rank_masters`に未登録というエラー状態にある間、`_commit_exam_success()`は`game_cleared`を発行してはならず、既存の`push_error`（`_warn_missing_next_rank_master()`）による警告のみを維持しなければならない 🔵 *[ヒアリング決定事項2、`game_state_rank_delegate.gd` 165-169行目]*
  - 関連: US-004, AC-004

### 任意要件（MAY）

- **FR-301**: ResultScreenは、GdUnit4テストでの検証を容易にするため、現在の表示状態を取得するテスト用ゲッター（`alchemy_screen.gd`のテスト用ゲッターパターン踏襲）を提供してもよい 🟡 *[`features/alchemy/ui/alchemy_screen.gd`の既存パターン]*
  - 関連: US-003, AC-003
- **FR-302**: `game_cleared`シグナルは、将来の拡張余地を残すため引数を持たせてもよい（引数なし／ありは実装Task側の判断に委ねる） 🟡 *[ヒアリング決定事項2、実装Task側判断に委任と明記]*
  - 関連: US-001, AC-001

### 禁止要件（MUST NOT）

- **FR-401**: ResultScreenは、クリア表示とオーバー表示を同時に表示してはならない 🔵 *[ヒアリング決定事項4、単一Control内切替の帰結]*
  - 関連: US-001, US-002, AC-005
- **FR-402**: ResultScreenは、閉じる／次へ進むボタン等のインタラクティブ要素を実装してはならない 🔵 *[ヒアリング決定事項6]*
  - 関連: US-006, AC-006
- **FR-403**: 本Planは、ResultScreenを`atelier/scenes/main.tscn`へ統合してはならない（`current_phase`に応じた`visible`切り替えの組み込みも含め、本Plan外＝Won't Have） 🔵 *[ヒアリング決定事項7]*
  - 関連: US-007, AC-007
- **FR-404**: ResultScreenは、到達ランク・降格回数・所持ゴールド等の統計情報を表示してはならない 🔵 *[ヒアリング決定事項5]*
  - 関連: US-005, AC-008
- **FR-405**: `game_state_rank_delegate.gd`は、次ランクのRankMaster欠落エラー分岐（166-169行目）から`game_cleared`シグナルを発行してはならない 🔵 *[ヒアリング決定事項2]*
  - 関連: US-004, AC-004

## 非機能要件

### パフォーマンス

- **NFR-001**: ResultScreenの表示切り替えは`_process()`を使わずシグナル駆動（イベント駆動）で行い、毎フレームの不要な処理を発生させてはならない 🟡 *[`.claude/rules/performance.md`「禁止事項」、本ゲームはターン制で常時アニメーションが少ない前提]*

### セキュリティ

- **NFR-101**: ResultScreenは外部入力を受け付けない表示専用画面だが、`GameState`から受け取るシグナル引数の型は明示的に注釈しなければならない 🔵 *[`.claude/rules/code-standards.md`型安全性、`.claude/rules/coding-style.md`「静的型付け」]*

### ユーザビリティ

- **NFR-201**: ResultScreenが表示する日本語メッセージは、プロジェクト共通のCJK対応フォント設定（`UiTheme`経由）を使用しなければならない 🟡 *[`.claude/rules/godot-best-practices.md`「日本語テキスト描画の注意」]*

### 保守性

- **NFR-301**: `game_cleared`・`game_over`ともに、命名規則（snake_case）・型注釈の原則に従わなければならない 🔵 *[`.claude/rules/coding-style.md`「命名規則」]*

## 制約

- **CON-001**: `game_cleared`シグナル追加は`autoload/game_state.gd`（Application層）への変更だが、guild-ui Planが`GameState`へ薄いラッパー（`get_current_rank_master()`／`get_current_rank_quota()`）を追加した前例と同型の、UI実装に必要な最小限のApplication層拡張として本Planのスコープに含める 🔵 *[ヒアリング決定事項2]*
- **CON-002**: `atelier/autoload/game_state.gd`は既に500行超過の既知課題（rank-up Plan検証レポートで言及済み、別Issue化検討中）であり、本Planでのシグナル追加（1行程度の増分）は許容し、大規模リファクタリングは本Planの対象外とする 🔵 *[ヒアリング記載事項]*
- **CON-003**: SCR-005昇格試験画面（PromotionExamScreen）は別Planのスコープであり、本Planには含まない 🔵 *[ヒアリング決定事項1]*
- **CON-004**: ResultScreenを`MainScene`へ組み込み`current_phase`に応じた`visible`切り替えを行う作業は本Plan外（Won't Have）。本PlanはResultScreenコンポーネント自体の実装とGdUnit4テストのみを対象とする 🔵 *[ヒアリング決定事項7、guild-ui・alchemy-ui Planの前例]*
- **CON-005**: `features/rank/ui/`は他Featureの`state/`・`ui/`を直接参照してはならない 🔵 *[`.claude/rules/architecture.md`「公開APIパターン」]*
- **CON-006**: テストは`tests/unit/features/rank/`（新規シグナル発行ロジックが`logic/`層に及ぶ場合）・`tests/integration/`（`GameState`シグナル発行・ResultScreenのシグナル購読動作確認）配下に配置する 🔵 *[ヒアリング記載事項]*
- **CON-007**: タイトル画面・セーブロード機能は設計スコープ外（`CLAUDE.md`参照）のため、ResultScreenはゲームの実質的終端画面として、閉じる／次へ進む導線を持たない 🔵 *[ヒアリング決定事項6]*

## 信頼性レベルサマリー

- 🔵 青信号: 23件
- 🟡 黄信号: 4件
- 🔴 赤信号: 0件（要確認なし）
