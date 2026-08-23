# rank-up-ui 要件定義書

## 概要

「Atelier」のPhase 2機能実装として、UI設計文書 [`docs/design/atelier-alchemy-core/ui-design/screens/promotion-exam.md`](../../../design/atelier-alchemy-core/ui-design/screens/promotion-exam.md) の SCR-005「昇格試験画面（PromotionExamScreen）」を実装する。

先行する`rank` Plan（通常ランク進行ドメイン、PR #20マージ済み）・`rank-up` Plan（昇格試験ドメイン層、マージ済み）は共通して「UI一式は別Plan」としてスコープ外にしてきた領域であり、`rank-ui` Plan（SCR-006結果画面）も「SCR-005昇格試験画面は本Plan外」と明記していた。本Planはこの残された領域を対象とする。

コードベース調査の結果、以下は既に実装済みであり本Planでは変更しない前提条件として扱う。

1. `atelier/features/alchemy/ui/alchemy_screen.gd`（`AlchemyScreen`）: 調合画面本体。レシピ選択・投入枠・在庫一覧・プレビュー・調合実行(`%ExecuteButton`)・終了ターン(`%EndTurnButton`)・ショップ導線・トースト表示を持ち、子として`%GuildDeliveryScreen`（`GuildDeliveryScreen`型）を直接参照する。
2. `atelier/features/guild/ui/guild_delivery_screen.gd`（`GuildDeliveryScreen`）: `_refresh_rank_quota()`が`GameState.get_state()["in_exam"]`を見て試験ノルマ(`exam_quota`/`exam_quota_max`)表示に自動的に切り替える。ランク名ラベルにも「昇格試験」サフィックスが付く。
3. `atelier/autoload/game_state_alchemy_delegate.gd`: `execute_alchemy()`が試験中(`_in_exam`)は`PromotionExamResolver.advance_turn`で試験経過ターンを自動+1する。
4. `atelier/autoload/game_state_guild_delegate.gd`: `deliver_pending_products()`が試験中は貢献度を`ExamState.exam_quota`へ加算し、`daily_order`を`null`扱いにして指定合致ボーナスを不適用にする。
5. `atelier/autoload/game_state_rank_delegate.gd`: 試験開始(`_start_exam()`、`exam_started`シグナル)、試験ターン進行専用API`advance_exam_turn()`、試験結果評価・確定(`evaluate_exam_outcome()`/`commit_exam_outcome()`、`exam_outcome_confirmed`シグナル)が実装済み。
6. `atelier/features/rank/ui/result_screen.gd`（`ResultScreen`）: `game_over`/`game_cleared`購読のみの最小画面。本Planでは変更しない。
7. `GameState.get_state()`は`in_exam`/`exam_quota`/`exam_quota_max`/`exam_elapsed_turn`/`exam_turn_limit`を既に公開している。
8. `atelier/features/workshop/ui/`は未実装（`.gitkeep`のみ）。
9. `atelier/scenes/main.tscn`へのシーン統合・画面遷移（visible切替）は全UI Planで一貫して対象外。

本Planは、新規シーン`PromotionExamScreen`を作成せず、既存`AlchemyScreen`を試験モード(`in_exam == true`)対応に拡張する方針を取る（詳細はヒアリング決定事項1参照）。

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: [plan.md](plan.md)

## 用語集

| 用語 | 定義 |
|-----|------|
| AlchemyScreen | 既存の`Control`継承シーン（`features/alchemy/ui/alchemy_screen.gd`/`.tscn`）。本Planの主な変更対象 |
| GuildDeliveryScreen | 既存の`Control`継承シーン（`features/guild/ui/guild_delivery_screen.gd`/`.tscn`）。試験ノルマバー表示は実装済みで本Planでは変更しない |
| in_exam | `GameState.get_state()["in_exam"]`。試験モード中か否かを示すbool値。本Planの全UI分岐の判定軸 |
| ExamState / ExamOutcome | `features/rank/state/exam_state.gd` / `features/rank/logic/exam_outcome.gd`。`ExamOutcome.Value`は`CONTINUE`/`SUCCESS`/`FAILURE`の3値 |
| `exam_started` | `GameState`の既存シグナル。試験開始時（`commit_rank_outcome()`のPROMOTION_ELIGIBLE分岐経由）に発行される |
| `exam_outcome_confirmed(outcome)` | `GameState`の既存シグナル。`commit_exam_outcome()`呼び出し時に必ず発行される（`outcome`がCONTINUEの場合も含む） |
| `advance_exam_turn()` | `GameState`の既存公開API。調合を実行せず試験ターンのみ+1する。`in_exam == false`の場合`Result.fail(&"not_in_exam")`を返す |
| PromotionExamScreen | UI設計文書上の画面名（SCR-005の呼称）。本Planでは**新規シーンとしては作成しない**（非スコープ、既存`AlchemyScreen`拡張で代替） |
| txt-exam-turn | 設計文書UI要素ID。試験残りターン数の表示（本Plan新規実装対象） |
| btn-advance-turn | 設計文書UI要素ID。「ターンを進める」ボタン（本Plan新規実装対象） |
| SCR-005 | `docs/design/atelier-alchemy-core/ui-design/screens/promotion-exam.md`で定義される画面ID |
| `commit_rank_outcome()` / `commit_exam_outcome()` | `GameState`の既存公開API。ランク／試験の結果評価を実行直前に再評価し確定する。**現状プロダクションコードから呼び出す箇所が存在しない**（詳細はCON-005参照） |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: 本Planは新規`Control`継承シーン`PromotionExamScreen`を作成せず、既存`AlchemyScreen`（`features/alchemy/ui/alchemy_screen.gd`/`.tscn`）を拡張して試験モードUIを実装しなければならない 🔵 *[ヒアリング決定事項1]*
  - 関連: US-601, AC-001
- **FR-002**: `AlchemyScreen`の`_ready()`は、`GameState.exam_started`および`GameState.exam_outcome_confirmed`シグナルを購読しなければならない 🔵 *[ヒアリング決定事項2、`.claude/rules/state-management.md`「UIコンポーネントでの状態監視」]*
  - 関連: US-301, US-603, AC-009
- **FR-003**: `AlchemyScreen`の`_exit_tree()`は、`exam_started`・`exam_outcome_confirmed`への購読を`is_connected()`チェックの上`disconnect()`しなければならない 🔵 *[`.claude/rules/ui-components.md`「破棄チェックリスト」]*
  - 関連: US-301, US-603, AC-009
- **FR-004**: `AlchemyScreen`は、試験残りターン数を表示する新規`Label`（txt-exam-turn相当）を持たなければならない 🔵 *[design doc UI要素表、ヒアリング必須差分]*
  - 関連: US-101, AC-002
- **FR-005**: `AlchemyScreen`は、`GameState.advance_exam_turn()`を呼び出す新規`Button`（btn-advance-turn相当、例: `%AdvanceExamTurnButton`）を持たなければならない 🔵 *[ヒアリング決定事項6]*
  - 関連: US-201, AC-003

### イベント駆動要件（WHEN-THEN）

- **FR-101**: `in_exam == true`の状態で`GameState.product_crafted`シグナルが発行された場合、`AlchemyScreen`は`_on_product_crafted()`内で自動的に`GameState.deliver_pending_products()`を呼び出し、その結果を`%GuildDeliveryScreen.display_results()`へ渡さなければならない 🔵 *[ヒアリング決定事項5]*
  - 関連: US-001, AC-005
- **FR-102**: `%AdvanceExamTurnButton`が押下された場合、`AlchemyScreen`は`GameState.advance_exam_turn()`を呼び出し、その後画面表示（残りターン表示等）を再計算しなければならない 🔵 *[ヒアリング決定事項6、design doc OnExamTurnAdvanced]*
  - 関連: US-201, AC-003
- **FR-103**: `GameState.exam_started`が発行された場合、`AlchemyScreen`は画面表示を再計算し（試験モード表示へ切替）、開始を知らせるトーストメッセージを表示しなければならない 🟡 *[design doc OnExamStarted、文言は新規決定]*
  - 関連: US-301, AC-006
- **FR-104**: `GameState.exam_outcome_confirmed(outcome)`が発行され`outcome`が`SUCCESS`または`FAILURE`の場合、`AlchemyScreen`は画面表示を再計算し（`in_exam`が`false`に戻るため通常モード表示へ復帰）、結果を示すトーストメッセージを表示しなければならない 🟡 *[design doc OnExamResolved、演出はテキストのみ＝ヒアリング決定事項3]*
  - 関連: US-302, AC-007
- **FR-105**: `GameState.exam_outcome_confirmed(outcome)`が発行され`outcome`が`CONTINUE`の場合、`AlchemyScreen`は画面表示のみ再計算し、結果トーストメッセージは表示してはならない 🟡 *[commit_exam_outcome()は常にexam_outcome_confirmedを発行する仕様（`game_state_rank_delegate.gd`）への防御的対応、新規決定]*
  - 関連: US-303, AC-008
- **FR-106**: 試験残りターン数は`max(exam_turn_limit - exam_elapsed_turn, 0)`で算出し、「残り{n}ターン」の書式で表示しなければならない 🟡 *[design doc txt-exam-turn、書式・クランプは新規決定]*
  - 関連: US-101, AC-002

### 状態駆動要件（WHERE）

- **FR-201**: `in_exam == true`である間、`AlchemyScreen`は残りターン表示ラベルと`%AdvanceExamTurnButton`を`visible = true`にしなければならない 🔵 *[ヒアリング決定事項6]*
  - 関連: US-101, US-201, AC-002, AC-003
- **FR-202**: `in_exam == false`である間、`AlchemyScreen`は残りターン表示ラベルと`%AdvanceExamTurnButton`を`visible = false`にしなければならない 🔵 *[ヒアリング決定事項6、非試験中は常設しない]*
  - 関連: US-101, US-201, AC-002, AC-003
- **FR-203**: `in_exam == true`である間、`AlchemyScreen`は`%EndTurnButton`を`visible = false`にしなければならない 🔵 *[ヒアリング決定事項5]*
  - 関連: US-002, AC-004
- **FR-204**: `in_exam == false`である間、`AlchemyScreen`は`%EndTurnButton`を`visible = true`にし、既存の手動納品挙動（`_on_end_turn_pressed()`）を変更してはならない 🔵 *[ヒアリング決定事項5「非試験中の挙動は変更しない」]*
  - 関連: US-002, AC-004
- **FR-205**: `in_exam == true`かつ（`state["inventory"]`が空、または`state["unlocked_recipe_ids"]`が空）である間、`AlchemyScreen`は案内メッセージを表示しなければならない 🟡 *[design doc「エラー状態」、文言・表示条件は新規決定]*
  - 関連: US-401, AC-010
- **FR-206**: FR-205の条件を満たさない間、案内メッセージは非表示でなければならない 🟡 *[FR-205と対の状態遷移、新規決定]*
  - 関連: US-401, AC-010

### 任意要件（MAY）

- **FR-301**: `AlchemyScreen`は、試験開始・結果確定・案内メッセージの文言を、既存`ERROR_MESSAGES`辞書と同様のパターンの新規定数辞書として定義してもよい 🟡 *[既存`AlchemyScreen.ERROR_MESSAGES`パターン踏襲]*
  - 関連: US-301, US-302, US-401, AC-006, AC-007, AC-010
- **FR-302**: `AlchemyScreen`は、テスト容易性のため残りターン数算出ロジックを`static func`として公開してもよい（既存`error_message()`静的関数パターン踏襲） 🟡 *[既存`AlchemyScreen.error_message()`パターン踏襲]*
  - 関連: US-102, AC-002

### 禁止要件（MUST NOT）

- **FR-401**: 本Planは新規`Control`継承シーン`PromotionExamScreen`（`.gd`/`.tscn`）を作成してはならない 🔵 *[ヒアリング決定事項1、非スコープ]*
  - 関連: US-501, AC-011
- **FR-402**: 本Planは`features/workshop/ui/`を実装してはならない 🔵 *[非スコープ]*
  - 関連: US-502, AC-011
- **FR-403**: 本Planは`atelier/scenes/main.tscn`への統合・画面遷移・`visible`切替を実装してはならない 🔵 *[非スコープ、ヒアリング決定事項2]*
  - 関連: US-502, AC-011
- **FR-404**: 本Planは試験開始時の緊張感演出・ノルマ減少演出・成功/失敗確定時の専用演出を実装してはならない 🔵 *[ヒアリング決定事項3]*
  - 関連: US-503, AC-011
- **FR-405**: 本Planは到達ランク・降格回数・所持ゴールド等の統計情報表示を実装してはならない 🔵 *[非スコープ]*
  - 関連: US-504, AC-011
- **FR-406**: `%AdvanceExamTurnButton`は、`in_exam == false`の間、`visible = true`にしてはならない（常設しない） 🔵 *[ヒアリング決定事項6]*
  - 関連: US-201, AC-003
- **FR-407**: `AlchemyScreen`は、`in_exam == true`の間、`%EndTurnButton`経由の手動納品操作（`_on_end_turn_pressed()`の追加呼び出し）をユーザーに提供してはならない（非表示化により操作不能にする） 🟡 *[ヒアリング決定事項5の帰結]*
  - 関連: US-002, AC-004
- **FR-408**: 本Planは`%GuildDeliveryScreen`（`GuildDeliveryScreen._refresh_rank_quota()`）の試験モード表示切替ロジックを変更してはならない（既存実装で充足済み） 🔵 *[前提条件2、変更不要]*
  - 関連: US-602, AC-011

## 非機能要件

### パフォーマンス

- **NFR-001**: `AlchemyScreen`の試験モードUI更新（表示切替・ラベル再計算）は`_process()`を使わずシグナル駆動で行い、毎フレームの不要な処理を発生させてはならない 🟡 *[`.claude/rules/performance.md`「禁止事項」、既存`AlchemyScreen`が`_process()`を持たない実装方針を踏襲]*

### セキュリティ

- **NFR-101**: `AlchemyScreen`が新規に購読するシグナルハンドラ（`exam_started`/`exam_outcome_confirmed`）の引数は、明示的な型注釈（`outcome: ExamOutcome.Value`等）を付与しなければならない 🔵 *[`.claude/rules/code-standards.md`型安全性、`.claude/rules/coding-style.md`「静的型付け」]*

### ユーザビリティ

- **NFR-201**: `AlchemyScreen`が新規に表示する日本語メッセージ（残りターン表示・トースト・案内メッセージ）は、プロジェクト共通のCJK対応フォント設定（`UiTheme`経由）を使用しなければならない 🟡 *[`.claude/rules/godot-best-practices.md`「日本語テキスト描画の注意」]*

### 保守性

- **NFR-301**: 実装後の`AlchemyScreen`（現状290行程度）が300行を超える場合、`.claude/rules/coding-style.md`「1ファイルの上限」に従い、ヘルパー関数の抽出等の分割を検討しなければならない。ただし500行のハード上限（`.claude/plugins/.../fullspec-templates.md`の一般制約とは別に、コーディング規約上の上限）を明らかに超過する見込みがない限り、本Plan内での即時ファイル分割は必須要件としない 🟡 *[ヒアリング技術的制約、`.claude/rules/coding-style.md`]*

## 制約

- **CON-001**: 既存の`AlchemyScreen`→`GuildDeliveryScreen`参照という先例（`features/alchemy/ui`から`features/guild/ui`を直接参照する既存の統合済み構造）をそのまま踏襲し、本Planでも変更しない。これは`.claude/rules/architecture.md`「公開APIパターン」の「他Featureの`ui/`を直接参照しない」原則からの逸脱だが、既存コードベースの実運用上の先例であり、本Planが新たにこの逸脱を拡大するものではない 🟡 *[ヒアリング技術的制約、要件文書上に明記する指示あり]*
- **CON-002**: 実装後の`AlchemyScreen`の行数増分見積りは概ね70〜90行（既存290行→推定360〜380行）であり、`.claude/rules/coding-style.md`の「300行超で分割検討」ルールに抵触する可能性がある。500行のハード上限には達しない見込みのため、分割の要否は実装Task側の判断に委ねる（NFR-301参照） 🟡 *[ヒアリング技術的制約]*
- **CON-003**: 本Planは、UI設計文書（`promotion-exam.md`）がTBDのまま残していたエラー案内メッセージ・残りターン表示フォーマット等の文言を、本requirements.mdフェーズで新規に確定する 🔵 *[ヒアリング決定事項4]*
- **CON-004**: テストはGdUnit4の`scene_runner()`パターンを用い、既存`tests/integration/test_alchemy_screen.gd`への追加、または`tests/integration/`配下の新規ファイルとして配置する。`tests/unit/`への配置は本Planでは想定しない（`AlchemyScreen`拡張はUI層のみで新規`logic/`純粋関数を追加しないため） 🔵 *[`.claude/rules/testing.md`、既存`test_alchemy_screen.gd`パターン]*
- **CON-005**: コードベース調査の結果、`GameState.commit_rank_outcome()`・`GameState.commit_exam_outcome()`は`GameState`の公開APIとして存在するが、**プロダクションコードパス（`AlchemyScreen`を含むいずれの`ui/`・`autoload/*_delegate.gd`）から実際に呼び出す箇所が一切存在しない**（呼び出しは`tests/integration/`配下のテストコードのみ）。そのため現行実装のままでは、実際のゲームプレイ中に`exam_started`・`exam_outcome_confirmed`シグナルが発行されるトリガーが存在せず、本Planが実装する`AlchemyScreen`のシグナル購読処理（FR-002〜FR-005, FR-101〜FR-105）は、統合テストにおいて`GameState.commit_rank_outcome()`/`commit_exam_outcome()`を直接呼び出す形（既存`test_game_state_exam_outcome.gd`と同型）でのみ検証可能であり、実プレイでは発火しない。**ユーザー確認済み（2026-08-24ヒアリング）**: 本Planはこの配線ギャップ（「誰が・いつ`commit_rank_outcome()`/`commit_exam_outcome()`を呼ぶか」というゲームループ全体のオーケストレーション）の解消を対象に含めない。`rank`/`rank-up`/`rank-ui`各Planと同様、`MainScene`統合・ゲームループ配線トリガーの実装は別Plan/別Taskの対象とし、本Planの成果物はUI層（`AlchemyScreen`拡張）とそれをsignal直接呼び出しで検証するGdUnit4統合テストに限定する 🔵 *[コードベース調査による発見をユーザーに提示し、スコープ外とすることを確認済み]*
- **CON-006**: `features/rank/ui/result_screen.gd`/`.tscn`（SCR-006結果画面）は本Planの変更対象外とする 🔵 *[前提条件6]*
- **CON-007**: Godotの`Control.visible = false`は入力処理（`gui_input`等）も同時に停止するため、`%EndTurnButton`非表示時（FR-203）に追加のクリックガード実装（`disabled`プロパティの併用等）は必須要件としない 🟡 *[Godot標準の`Control`挙動に基づく推測]*

## 信頼性レベルサマリー

- 🔵 青信号: 23件
- 🟡 黄信号: 15件
- 🔴 赤信号: 0件（CON-005はユーザー確認済みのため🔵へ更新）
