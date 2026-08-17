# rank-up 要件定義書

## 概要

「Atelier」（Godot 4.x + GDScript）の Phase 2 機能実装として、`rank` plan（PR #20マージ済み）が明示的にスコープ外とした**昇格試験システム本体**を実装する。通常ランク進行（`RankQuotaResolver`/`TurnLimitResolver`/`GameState`のランクフィールド群）は既に実装済みであり、本planは`TurnLimitResolver.resolve_rank_outcome`が`PROMOTION_ELIGIBLE`を返した後の「昇格試験（一発勝負の特殊局面）」の判定・状態管理・結果確定（次ランクへの昇格 or 同ランク再挑戦 or ゲームクリア）を実装する。

本要件は `docs/design/atelier-alchemy-core/core-systems.md`「RankSystem（ランク進行・昇格試験）詳細設計」（L273-374、特にL294-354の`PromotionExamResolver`/`ExamState`/`ExamOutcome`/昇格試験の詳細設計節）・`docs/design/atelier-alchemy-core/data-schema.md`（`exam_state` L63-69・L92-94、RankMaster節 L190-213）・ユーザーヒアリング結果に既に定義された契約をEARS形式に翻訳したものである。矛盾がある場合は既存設計文書とヒアリング結果を正とする。

### スコープ境界（ユーザーヒアリングで確定済み）

**含む**:
- `features/rank/logic/promotion_exam_resolver.gd`（`PromotionExamResolver`: `start_exam`・`advance_turn`・`resolve_outcome`）
- `features/rank/logic/exam_outcome.gd`（`ExamOutcome` enum、`RankOutcome`と同じ配置根拠）
- `features/rank/state/exam_state.gd`（`ExamState`: `exam_quota`・`exam_quota_max`・`exam_elapsed_turn`・`exam_turn_limit`）
- `shared/constants/game_balance.gd`への`RANK_ORDER: Array[StringName]`定数追加
- `autoload/game_state.gd`統合: `exam_state`関連フィールド追加、試験開始・試験中のターン進行・試験結果評価/確定、成功時の実ランク遷移、失敗時の再挑戦リセット、ゲームクリア判定

**含まない（本plan外）**:
- `features/rank/ui/`・`PromotionExamScene`等のUI一式、アニメーション/演出、エラーメッセージ文言
- `res://data/ranks/*.tres`実データ作成（G〜Sの8ランク分。別plan、コンテンツ作成）
- `atelier/autoload/game_state.gd`の500行超過リファクタリング（rank plan踏襲で今回も受容し、別Issueとして起票する）
- `exam_turn_limit`・`exam_difficulty_coefficient`の具体的なバランス数値確定（引き続き🟡TBD）
- `GameState.advance_turn()`相当の**通常ターンループ**進行メソッド新設（rank planが既にスコープ外とした事項。本plan内の試験専用ターン進行はこれとは独立した自己完結的な仕組みとして実装する）

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: plan.md（未作成、後続フェーズで生成）
- **既存設計資産**: [`core-systems.md`](../../../design/atelier-alchemy-core/core-systems.md) RankSystem節（L273-374） / [`data-schema.md`](../../../design/atelier-alchemy-core/data-schema.md) `exam_state`節（L63-69, L92-94）・RankMaster節（L190-213）
- **先行plan**: [`rank/requirements.md`](../rank/requirements.md)（`RankQuotaResolver`・`TurnLimitResolver`・`RankOutcome`・`RankMaster`・`RankState`・`GameState`ランク統合の生成側契約） / [`guild/requirements.md`](../guild/requirements.md)（`DeliveryResolver.resolve`・`matches_order`の契約） / [`alchemy/requirements.md`](../alchemy/requirements.md)（`execute_alchemy`の契約）

## 用語集

| 用語 | 定義 |
|-----|------|
| 昇格試験（Exam） | `RankOutcome.PROMOTION_ELIGIBLE`確定後に発生する、庭なし・専用ノルマ・超短期ターンの一発勝負局面。通常の`AlchemySystem`/`GuildSystem`をそのまま再利用する |
| `PromotionExamResolver` | 昇格試験の状態遷移を担うDomain層の静的クラス（副作用なし）。`start_exam`・`advance_turn`・`resolve_outcome`の3つのpublic `static func`を持つ |
| `ExamState` | 昇格試験中のランタイム状態。`exam_quota: float`（試験ノルマ残量）, `exam_quota_max: float`（試験ノルマ上限）, `exam_elapsed_turn: int`（試験内経過ターン）, `exam_turn_limit: int`（試験制限ターン） |
| `ExamOutcome` | 昇格試験結果の列挙型。`CONTINUE`（続行）/ `SUCCESS`（昇格成功）/ `FAILURE`（試験失敗＝同ランク再挑戦） |
| `in_exam` | `GameState`が保持する、現在昇格試験中かどうかを表すフラグ。試験終了（成功/失敗）時に`false`へ戻る |
| `RANK_ORDER` | `GameBalance`が保持する、ランクIDの昇格順配列（`rank_g`→`rank_f`→…→`rank_s`）。次ランク判定の唯一の情報源 |
| 次ランクなし（ゲームクリア） | `RANK_ORDER`上で現在ランクが末尾（Sランク相当）のため次ランクIDが存在しない状態。試験成功時はランク遷移ではなくゲームクリア確定として扱う |
| 試験ノルマ（`exam_quota`） | 通常の`rank_state.quota`とは別管理される、試験専用のノルマ残量。減算ロジック自体は`RankQuotaResolver.apply_contribution`を流用する |
| 指定合致ボーナス不適用 | 試験中は`DeliveryResolver.resolve`に`daily_order = null`を渡すため、日替わり指定調合物の合致ボーナスが常に不適用になる仕様。報酬・貢献度自体は通常通り計算される |
| `demotion_count` | 同一ランクでの再挑戦回数のカウンタ（rank planで導入済み）。試験失敗で+1、試験成功で0にリセットされる。`GameBalance.MAX_DEMOTION_COUNT`到達でゲームオーバー |
| `GameState` | Application層Autoload。試験状態の唯一の保持者・状態変更者・仲介者（rank planと同一原則） |
| `Result` | `shared/entities/result.gd`。`success: bool, value: Variant, error_code: StringName`と`Result.ok()`/`Result.fail()` |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: システムは`PromotionExamResolver`を`features/rank/logic/promotion_exam_resolver.gd`配下に、副作用を持たない`static func`（`Node`非継承）の集合として実装しなければならない 🔵 *[core-systems.md L294-299 クラス図`<<static>>`]*
  - 関連: US-104, AC-020
- **FR-002**: `PromotionExamResolver.start_exam(rank_master: RankMaster) -> ExamState`は、`exam_quota = exam_quota_max = (rank_master.quota_max / rank_master.limit_turn) * rank_master.exam_turn_limit * rank_master.exam_difficulty_coefficient`、`exam_elapsed_turn = 0`、`exam_turn_limit = rank_master.exam_turn_limit`で初期化した新規`ExamState`を返さなければならない 🔵 *[core-systems.md L334]*
  - 関連: US-001, AC-001
- **FR-003**: `PromotionExamResolver.advance_turn(exam_state: ExamState) -> ExamState`は、引数を破壊的に変更せず、`exam_elapsed_turn`を+1した**新規**`ExamState`を返さなければならない 🔵 *[core-systems.md L335、`RankQuotaResolver.reset_for_retry`と同じ不変更新パターン]*
  - 関連: US-101, US-102, AC-002
- **FR-004**: `PromotionExamResolver.resolve_outcome(exam_state: ExamState) -> ExamOutcome.Value`は、`exam_quota <= 0`なら`SUCCESS`、`exam_elapsed_turn >= exam_turn_limit`かつ`exam_quota > 0`なら`FAILURE`、それ以外は`CONTINUE`を返さなければならない 🔵 *[core-systems.md L336]*
  - 関連: US-201, US-203, AC-003
- **FR-005**: システムは`ExamOutcome`を`CONTINUE`・`SUCCESS`・`FAILURE`の3値を持つ`enum`として`features/rank/logic/exam_outcome.gd`に定義しなければならない（`RankOutcome`が`PromotionExamResolver`と`GameState`の双方から参照されるため`state/`ではなく`logic/`に配置された既存の配置根拠を踏襲する） 🟡 *[core-systems.md L306-311 / rank/requirements.md CON-003の配置根拠]*
  - 関連: US-201, US-203, AC-003
- **FR-006**: システムは`ExamState`を`features/rank/state/exam_state.gd`に`RefCounted`継承のランタイム状態型として定義し、`exam_quota: float`・`exam_quota_max: float`・`exam_elapsed_turn: int`・`exam_turn_limit: int`の4フィールドと、独立コピーを返す`clone()`メソッドを持たせなければならない 🔵 *[core-systems.md L300-305クラス図 / data-schema.md L63-69 / `RankState.clone()`と同じ防御的コピーパターン]*
  - 関連: US-001, AC-004
- **FR-007**: システムは`GameBalance.RANK_ORDER`を`Array[StringName]`定数として`shared/constants/game_balance.gd`に追加し、`[&"rank_g", &"rank_f", &"rank_e", &"rank_d", &"rank_c", &"rank_b", &"rank_a", &"rank_s"]`の順序（昇格順、既存`GameBalance.INITIAL_RANK_ID = &"rank_g"`と整合する命名規則）で定義しなければならない 🔵 *[ヒアリング結果 新規決定方針1]*
  - 関連: US-201, US-202, AC-005
- **FR-008**: システムは`GameState`を、試験中フラグ（`in_exam`相当）と試験状態（`_exam_state`相当）の唯一の保持者とし、これらを変更する経路を`GameState`のメソッドのみに限定しなければならない 🔵 *[.claude/rules/state-management.md「GameStateが唯一の仲介者」/ ヒアリング結果スコープ確定事項「含む」]*
  - 関連: US-001, AC-017
- **FR-009**: `GameState.get_state()`は、試験状態のビュー（`in_exam`・`exam_quota`・`exam_quota_max`・`exam_elapsed_turn`・`exam_turn_limit`の5フィールド）を、`ExamState`の内部正本を直接公開せず防御的コピー（`clone()`または値のコピー）した上で含めなければならない 🔵 *[data-schema.md L63-69 exam_state辞書構造 / .claude/rules/state-management.md「`get_state()`戻り値の防御的コピー必須」]*
  - 関連: US-003, AC-018
- **FR-010**: システムは、現在ランクIDから次ランクIDを決定するロジックを `features/rank/logic/rank_progression.gd` に `RankProgression.get_next_rank_id(current_rank_id: StringName) -> StringName` として実装しなければならない（`GameBalance.RANK_ORDER`上のindex+1参照。次ランクが存在しない場合は空文字列 `""` を返す）。`GameState`（Imperative Shell）は結果を受け取るのみとし、配列探索自体をインラインで持ってはならない 🔵 *[ユーザーヒアリングで確定。既存の`rank_outcome.gd`（8行）・`turn_limit_resolver.gd`（21行）と同型の単一責務・小規模logicファイルパターンを踏襲する新規ファイルとして配置する]*
  - 関連: US-002, AC-012, AC-013

### イベント駆動要件（WHEN-THEN）

- **FR-101**: `GameState.commit_rank_outcome()`が`RankOutcome.Value.PROMOTION_ELIGIBLE`を確定した場合、システムは`in_exam`を`true`に設定し、`PromotionExamResolver.start_exam`で現在ランクの`RankMaster`から生成した`ExamState`を格納しなければならない 🔵 *[core-systems.md L344「発生条件」]*
  - 関連: US-001, AC-006
- **FR-102**: `in_exam`が`true`の間に`GameState.execute_alchemy()`が呼び出された場合、システムは通常の調合処理に加えて、`PromotionExamResolver.advance_turn`相当の処理で`exam_elapsed_turn`を+1しなければならない 🔵 *[ヒアリング結果 新規決定方針6 / core-systems.md L350]*
  - 関連: US-101, AC-007
- **FR-103**: `in_exam`が`true`の間に、調合を実行せずターンのみ進める専用メソッド（例: `advance_exam_turn()`）が呼び出された場合、システムは`PromotionExamResolver.advance_turn`を呼び出して`exam_elapsed_turn`を+1しなければならない 🔵 *[ヒアリング結果 新規決定方針6「デッドロック回避手段」/ core-systems.md L335, L350]*
  - 関連: US-102, AC-008
- **FR-104**: `in_exam`が`false`の間に上記の試験専用ターン進行メソッド（FR-103）が呼び出された場合、システムは状態を一切変更せず失敗を表す`Result`を返さなければならない 🟡 *[既存`execute_alchemy_failed`等の検証パターンからの類推。試験外での誤呼び出しに対する安全策]*
  - 関連: US-102, AC-008
- **FR-105**: `in_exam`が`true`の間に`GameState.deliver_pending_products()`が呼び出された場合、システムは`_current_daily_order`の値に関わらず`DeliveryResolver.resolve`へ`daily_order = null`を渡し、得られた`final_contribution`を`RankQuotaResolver.apply_contribution`で`exam_quota`（`rank_state.quota`ではない）に適用しなければならない 🔵 *[core-systems.md L347, L349「試験ノルマへの反映」]*
  - 関連: US-103, AC-009
- **FR-106**: `in_exam`が`true`の間の`deliver_pending_products()`呼び出しでも、システムは`final_reward`を通常の（非試験時と同じ）ロジックで`gold`へ加算しなければならない 🔵 *[core-systems.md L348「報酬（ゴールド）は通常どおり獲得する」]*
  - 関連: US-103, AC-010
- **FR-107**: `GameState.evaluate_exam_outcome()`が呼び出された場合、システムは`PromotionExamResolver.resolve_outcome(_exam_state)`の結果を、状態を一切変更せずに返さなければならない（`evaluate_rank_outcome()`と同じ問い合わせ専用パターン） 🔵 *[core-systems.md L296-299 / rank/requirements.md `evaluate_rank_outcome()`の既存パターン踏襲]*
  - 関連: US-201, US-203, AC-011
- **FR-108**: `GameState.commit_exam_outcome()`が呼び出され、実行直前に再評価した`evaluate_exam_outcome()`が`SUCCESS`かつ`FR-010`の次ランク決定ロジックが有効な次ランクIDを返した場合、システムは `_current_rank_id`を次ランクへ更新し、`_demotion_count`を0にリセットし、次ランクの`RankMaster.quota_max`で`_rank_state`を新規初期化し、`_rank_state_initialized`を`true`に設定した上で、`in_exam`を`false`に戻さなければならない 🔵 *[ヒアリング結果で本plan内対応と確定。既存`_rank_state_initialized`フラグ（`game_state.gd` L55, L385-391）は現状`game_state_test_support.gd`経由でしか`true`にならず本番コード経路が皆無だったが、本FRが唯一の本番セット経路となる。なお初回（Gランク）の`_rank_state_initialized`初期化タイミングはゲーム開始フロー側の別課題であり本plan外]*
  - 関連: US-201, AC-012
- **FR-109**: `GameState.commit_exam_outcome()`が呼び出され、`evaluate_exam_outcome()`が`SUCCESS`だが`FR-010`の次ランク決定ロジックが次ランクなし（`RANK_ORDER`末尾）と判定した場合、システムはランク遷移・`_rank_state`初期化を行わず、ゲームクリアとして扱い`in_exam`を`false`に戻さなければならない 🔵 *[ヒアリング結果 新規決定方針2, 7「次ランクが存在しない場合はゲームクリアと判定する」]*
  - 関連: US-202, AC-013
- **FR-110**: `GameState.commit_exam_outcome()`が呼び出され、実行直前に再評価した`evaluate_exam_outcome()`が`FAILURE`を返した場合、システムは`RankQuotaResolver.reset_for_retry(現在ランクのRankMaster)`で`_rank_state`をリセットし、`_demotion_count`を+1し、`in_exam`を`false`に戻さなければならない 🔵 *[ヒアリング結果 新規決定方針8 / core-systems.md L353]*
  - 関連: US-203, AC-014
- **FR-111**: `FR-110`の`_demotion_count`加算の結果`is_game_over()`（`_demotion_count >= GameBalance.MAX_DEMOTION_COUNT`）が真になった場合、システムは既存の`game_over(demotion_count: int)`シグナルを発行しなければならない（rank planの`commit_rank_outcome()`のゲームオーバー確定ロジックと同じ経路を再利用する） 🔵 *[ヒアリング結果 新規決定方針8「既存のcommit_rank_outcomeのゲームオーバー確定ロジックと整合させる」]*
  - 関連: US-204, AC-015
- **FR-112**: `GameState.commit_exam_outcome()`が呼び出され、実行直前に再評価した`evaluate_exam_outcome()`が`CONTINUE`を返した場合、システムは状態を一切変更せず、結果が`CONTINUE`であることを表す`Result`を返さなければならない 🟡 *[`commit_rank_outcome()`の実行直前再評価パターンからの類推]*
  - 関連: US-205, AC-016
- **FR-113**: `is_game_over()`が既に真の状態で`GameState.commit_exam_outcome()`が呼び出された場合、システムは状態を再変更せず、直近の確定結果を冪等に返さなければならない（`commit_rank_outcome()`の`_last_rank_outcome`と同じ冪等性パターン） 🟡 *[rank/game_state.gd L413-415の既存`commit_rank_outcome()`冪等性ロジックからの類推]*
  - 関連: US-205, AC-016

### 状態駆動要件（WHERE）

- **FR-201**: `in_exam`が`true`の間、システムは`GameState.commit_rank_outcome()`が新たに`PROMOTION_ELIGIBLE`を確定させても、既存の`_exam_state`を上書き再初期化してはならず（二重開始防止）、既存の試験を継続しなければならない 🟡 *[ヒアリング結果には明示なし。二重開始による状態破壊を防ぐための安全策として本ドキュメントで補完]*
  - 関連: US-002, AC-017

### 任意要件（MAY）

- **FR-301**: システムは`commit_exam_outcome()`が`SUCCESS`/`FAILURE`を確定した際に、`exam_outcome_confirmed(outcome: ExamOutcome.Value)`シグナルを発行してもよい（既存の`rank_outcome_confirmed`シグナルと対称なパターン） 🟡 *[rank/game_state.gd L15, L424の既存`rank_outcome_confirmed`パターンからの類推。将来のUI実装（本plan外）が購読する想定]*
  - 関連: US-205, AC-016
- **FR-302**: システムは`FR-101`で試験へ突入した際に、`exam_started`相当のシグナルを発行してもよい 🟡 *[phase_changed等、既存の状態遷移通知パターンからの類推]*
  - 関連: US-001, AC-006

### 禁止要件（MUST NOT）

- **FR-401**: システムは、`in_exam`が`true`の間の納品において、`_current_daily_order`が非nullであっても指定合致ボーナスを適用してはならない 🔵 *[core-systems.md L347「日替わり指定調合物ボーナスは適用しない」]*
  - 関連: US-103, AC-009
- **FR-402**: `PromotionExamResolver`の各`static func`は、内部で乱数を生成したり、`GameState`・`RngService`を直接参照したりしてはならない 🔵 *[.claude/rules/architecture.md「Functional Core内での副作用禁止」/ 乱数は引数で受け取る規約]*
  - 関連: US-104, AC-020
- **FR-403**: `PromotionExamResolver.advance_turn`および`ExamState.clone()`は、引数として渡された`ExamState`インスタンスをin-placeで変更してはならない 🔵 *[core-systems.md L335 / `RankState.clone()`・`RankQuotaResolver.reset_for_retry`と同じ不変更新パターン]*
  - 関連: US-104, AC-020
- **FR-404**: `GameState.commit_exam_outcome()`は、`GameBalance.RANK_ORDER`の末尾を超えて`_current_rank_id`を進めてはならない（範囲外アクセスを起こしてはならない）。ゲームクリアは通常の昇格処理と明確に区別して扱わなければならない 🔵 *[ヒアリング結果 新規決定方針2「明示フラグは追加しない」→index範囲外判定に一本化]*
  - 関連: US-202, AC-013

## 非機能要件

### パフォーマンス

- **NFR-001**: `PromotionExamResolver`の各`static func`は定数時間相当の軽量な純粋関数のみで構成され、`_process()`等の毎フレーム処理を必要としてはならない 🟡 *[.claude/rules/performance.md「_process()内での重い処理」禁止からの類推]*

### 信頼性・データ整合性

- **NFR-101**: `RankMaster`が`_rank_masters`に存在しない・`RANK_ORDER`に現在ランクIDが含まれない等のマスターデータ不整合が発生した場合、システムはクラッシュせず`push_error()`でログを記録した上で安全側（試験開始不可・ランク遷移なし等）にフォールバックしなければならない 🔵 *[既存`RankQuotaResolver.reset_for_retry`のnullガード（L24-26）・`GameState._get_current_rank_master_or_fallback()`（L369-380）と同じ既存パターンの踏襲]*

### 保守性

- **NFR-201**: `atelier/autoload/game_state.gd`は本plan実装後も[`.claude/rules/coding-style.md`](../../../../.claude/rules/coding-style.md)の300行目安・500行上限ルールを超過し続けることを許容するが、新規追加するテスト専用API（`_set_xxx_for_test`等）は既存の`GameStateTestSupport`への1行委譲パターンを踏襲し、本体側の行数増加を抑制しなければならない 🟡 *[game_state.gd L437-438の既存コメント「500行ルール対応」パターンの継続]*
- **NFR-202**: `PromotionExamResolver`・`ExamState`・`ExamOutcome`はいずれもFunctional Core（副作用なし）として実装し、[`.claude/rules/testing.md`](../../../../.claude/rules/testing.md)のカバレッジ基準（全public `static func`に正常系・異常系・境界値のテストを最低1本ずつ）を満たせる設計としなければならない 🔵 *[testing.md「カバレッジ目標」]*

## 制約

- **CON-001**: 本planは`rank` plan（PR #20マージ済み）の成果物（`RankQuotaResolver`・`TurnLimitResolver`・`RankOutcome`・`RankMaster`・`RankState`・`GameState`のランク統合フィールド群）に依存する前提とする 🔵 *[ヒアリング結果「前提」]*
- **CON-002**: `features/rank/ui/`・`PromotionExamScene`等のUI一式、アニメーション・演出、エラーメッセージ文言は本plan外とする 🔵 *[ヒアリング結果「含まない」]*
- **CON-003**: `res://data/ranks/*.tres`実データ（G〜Sの8ランク分）作成は本plan外とする。テストは`_set_rank_masters_for_test`等の既存テスト専用APIによるフィクスチャ注入で代替する 🔵 *[ヒアリング結果「含まない」]*
- **CON-004**: `exam_turn_limit`・`exam_difficulty_coefficient`の具体的なバランス数値は`balance-design.md`の🟡TBD項目のまま引き続き追跡し、本plan内で断定的に確定させない。既存の`RankMaster.exam_turn_limit`/`exam_difficulty_coefficient`フィールドをそのまま使用する 🔵 *[ヒアリング結果 新規決定方針3]*
- **CON-005**: `atelier/autoload/game_state.gd`（現535行）の500行超過リファクタリングは本plan外とし、別Issueとして起票する 🔵 *[ヒアリング結果「含まない」]*
- **CON-006**: 試験中（`in_exam = true`）の`GardenScreen`への遷移禁止はUI層の責務とし、`GameState`層（`plant_seed()`/`harvest()`）には本plan内で追加の実行時ガードを設けない 🔵 *[data-schema.md L92「真の間GardenScreenへの遷移をUI側で禁止する」]*
- **CON-007**: ランクIDの命名規則は`rank_g`〜`rank_s`（snake_case）を採用する。`data-schema.md`のRankMasterサンプルにある`"id": "G"`表記とは異なるが、既存実装済みの`GameBalance.INITIAL_RANK_ID = &"rank_g"`と整合させることを優先する 🔵 *[ヒアリング結果 新規決定方針1 / atelier/shared/constants/game_balance.gd L64]*
- **CON-008**: 新規テスト専用API（`_set_exam_state_for_test`等）は、既存の`GameStateTestSupport`委譲パターン（`_set_xxx_for_test` → `GameStateTestSupport.xxx(self, ...)` → `guard()`による`OS.is_debug_build()`二重ガード）を踏襲する 🟡 *[game_state.gd L437-438 / game_state_test_support.gd既存実装パターン]*

## 信頼性レベルサマリー

- 🔵 青信号: 29件
- 🟡 黄信号: 12件
- 🔴 赤信号: 0件（ユーザーヒアリングで解消済み）
