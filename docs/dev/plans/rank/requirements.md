# rank 要件定義書

## 概要

「Atelier」（Godot 4.x + GDScript）の Phase 2 機能実装として、RankSystem（ランク進行）のうち**通常ランク進行**部分を実装する。庭（garden）・調合（alchemy）・ギルド納品（guild）は既に`logic/`・`state/`・`resources/`・`GameState`統合まで設計/実装が完了しており、本planでは「納品で得た貢献度がランクノルマを削り、制限ターン到達時に昇格試験へ進める状態（`PROMOTION_ELIGIBLE`）または同一ランクでの再挑戦（`DEMOTION`）が確定する」までの一連の判定・状態管理を実装する。

本要件は `docs/design/atelier-alchemy-core/core-systems.md`「RankSystem（ランク進行・昇格試験）詳細設計」（L273-338）・`docs/design/atelier-alchemy-core/data-schema.md`（`rank_state` L83-85 / RankMaster節 L190-212）・`docs/spec/atelier-alchemy-core/requirements.md` §2「勝敗条件」/§4「ギルドランク（審査基準）」に既に定義された契約をEARS形式に翻訳したものである。矛盾がある場合は既存設計文書を正とする。

### スコープ境界（ユーザーヒアリングで確定済み）

**含む**:
- `features/rank/logic/rank_quota_resolver.gd`（`RankQuotaResolver`: `apply_contribution`・`is_rank_cleared`・`reset_for_retry`）
- `features/rank/logic/turn_limit_resolver.gd`（`TurnLimitResolver`: `is_turn_limit_reached`・`resolve_rank_outcome`）
- `features/rank/logic/rank_outcome.gd`（`RankOutcome` enum。配置根拠はCON-003参照）
- `features/rank/resources/rank_master.gd`（`RankMaster`のResource型定義。7フィールド全て）
- `features/rank/state/rank_state.gd`（`RankState`: `quota: float`, `elapsed_turn: int`）
- `shared/constants/game_balance.gd` へのゲームオーバー閾値（降格許容回数）定数の追加
- `autoload/game_state.gd` 統合: `_accumulated_contribution`（暫定）→ 実際のノルマ消費への置き換え、`_traits_unlocked`（暫定）→ 現在ランクの`RankMaster`由来への置き換え、`_demotion_count`管理とゲームオーバー判定、ランク結果評価用クエリメソッドの新設

**含まない**（別task・別planの対象）:
- `PromotionExamResolver`・`ExamState`・`ExamOutcome`（昇格試験本体）: 別plan「promotion-exam」
- 昇格成功時の実際のランク遷移（`_current_rank_id`を次ランクへ進める処理）・`demotion_count`の0リセットの呼び出し: 別plan「promotion-exam」（試験クリアでのみ発生するため）
- `res://data/ranks/*.tres`の実データ（G〜Sの8ランク分）作成: 別plan（コンテンツ作成・バランス調整フェーズ）
- `GameState.advance_turn()`相当のターン進行メソッド新設、およびターン進行と連動したランク結果の自動判定配線: 別plan（ターンサイクル全体の設計が必要なため）
- `features/rank/ui/`（ゲームオーバー画面・昇格演出等）の実装

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: plan.md（未作成、後続フェーズで生成）
- **既存設計資産**: [`core-systems.md`](../../../design/atelier-alchemy-core/core-systems.md) RankSystem節 / [`data-schema.md`](../../../design/atelier-alchemy-core/data-schema.md) `rank_state`・RankMaster節 / [`spec/requirements.md`](../../../spec/atelier-alchemy-core/requirements.md) §2「勝敗条件」
- **先行plan**: [`guild/requirements.md`](../guild/requirements.md)（`DeliveryResult.final_contribution`・`_accumulated_contribution`の生成側契約） / [`alchemy/requirements.md`](../alchemy/requirements.md)（`_traits_unlocked`の消費側契約） / [`garden/requirements.md`](../garden/requirements.md)

## 用語集

| 用語 | 定義 |
|-----|------|
| ランクノルマ（quota） | 現在ランクをクリアするために削り切る必要のある残量。納品の`final_contribution`分だけ減る。0未満にはならず0でクランプする |
| `RankQuotaResolver` | ノルマ残量計算を担うDomain層の静的クラス（副作用なし）。`apply_contribution`・`is_rank_cleared`・`reset_for_retry`の3つのpublic `static func`を持つ |
| `TurnLimitResolver` | 制限ターン到達判定とランク結果確定を担うDomain層の静的クラス（副作用なし）。`is_turn_limit_reached`・`resolve_rank_outcome`の2つのpublic `static func`を持つ |
| `RankOutcome` | ランク結果の列挙型。`CONTINUE`（続行）/ `PROMOTION_ELIGIBLE`（昇格試験へ進める）/ `DEMOTION`（同一ランクへの再挑戦） |
| `RankMaster` | ランクのマスターデータ型。`id, display_name, quota_max, limit_turn, traits_unlocked, exam_turn_limit, exam_difficulty_coefficient` |
| `RankState` | ランクごとのランタイム状態。`quota: float`（ノルマ残量）, `elapsed_turn: int`（現ランクでの経過ターン数） |
| `elapsed_turn` | 現ランクでのローカルな経過ターン数。降格時に0へリセットされる。`GameState._current_turn`（ゲーム全体で単調増加するグローバルターン数）とは**別物** |
| `limit_turn` | 当該ランクの制限ターン数（`RankMaster.limit_turn`）。この値に`elapsed_turn`が到達した時点でのみランク結果を判定する |
| 降格（DEMOTION） | **ランク文字が下がることではなく、同一ランクに留まって再挑戦すること**。ゲーム全体ループは常に一方向（昇格のみ）で進行し、ランク文字が下がる遷移は存在しない |
| 降格回数（`demotion_count`） | 同一ランクでの再挑戦回数のカウンタ。規定回数到達でゲームオーバー。昇格成功時に0へリセットされる（リセットの呼び出し元は別plan） |
| 早期クリアボーナス | ノルマが制限ターンより先に0へ到達しても試験への移行は制限ターン到達まで待つ仕様。残りターンは通常プレイを継続できる意図的な優遇 |
| 特性解禁（`traits_unlocked`） | 特性システムが解禁済みか。現在ランクの`RankMaster.traits_unlocked`が権威（Gランクは`false`固定） |
| 累積貢献度（`_accumulated_contribution`） | guild planが暫定的に設けた貢献度の蓄積先フィールド。本planで実際のノルマ消費へ置き換え、フィールド自体を削除する（CON-004） |
| `GameState` | Application層Autoload。ランク状態の唯一の保持者・状態変更者・仲介者 |
| `Result` | `shared/entities/result.gd`。`success: bool, value: Variant, error_code: StringName`と`Result.ok()`/`Result.fail()` |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: システムは`RankQuotaResolver`を`features/rank/logic/rank_quota_resolver.gd`配下に、副作用を持たない`static func`（`Node`非継承）の集合として実装しなければならない 🔵 *[core-systems.md L283-288 クラス図`<<static>>` / .claude/rules/architecture.md「Functional Coreに置くもの」]*
  - 関連: US-008, AC-013
- **FR-002**: システムは`TurnLimitResolver`を`features/rank/logic/turn_limit_resolver.gd`配下に、副作用を持たない`static func`（`Node`非継承）の集合として実装しなければならない 🔵 *[core-systems.md L289-293 クラス図`<<static>>`]*
  - 関連: US-008, AC-013
- **FR-003**: システムは`RankOutcome`を`CONTINUE`・`PROMOTION_ELIGIBLE`・`DEMOTION`の3値を持つ`enum`として定義しなければならない 🔵 *[core-systems.md L305-310 クラス図`<<enumeration>>`]*
  - 関連: US-004, US-005, AC-006
- **FR-004**: システムは`RankMaster`を`features/rank/resources/rank_master.gd`に`Resource`継承の型として定義し、`id: String, display_name: String, quota_max: float, limit_turn: int, traits_unlocked: bool, exam_turn_limit: int, exam_difficulty_coefficient: float`の7フィールドを全て持たせなければならない（後半2フィールドは本plan未使用だがスキーマ完全性のため定義する。CON-012） 🔵 *[data-schema.md L190-212 / ヒアリング結果「既存設計」]*
  - 関連: US-001, US-007, AC-007
- **FR-005**: システムは`RankState`を`features/rank/state/rank_state.gd`に`quota: float`・`elapsed_turn: int`を持つランタイム状態型として定義しなければならない 🔵 *[data-schema.md L83-84 / core-systems.md L288 `reset_for_retry`の戻り値型]*
  - 関連: US-003, AC-008
- **FR-006**: システムは`GameState`を現在ランク（`_current_rank_id`）・ランクマスター群（`_rank_masters`）・ランク状態（`_rank_state`）・降格回数（`_demotion_count`）の唯一の保持者とし、これらを変更する経路を`GameState`のメソッドのみに限定しなければならない 🔵 *[.claude/rules/state-management.md「GameStateが唯一の仲介者・Single Source of Truth」/ ヒアリング結果スコープ確定事項1]*
  - 関連: US-009, AC-009, AC-016
- **FR-007**: システムはゲームオーバーとなる降格回数の閾値を`shared/constants/game_balance.gd`に`MAX_DEMOTION_COUNT := 3`として定義し、コード中にマジックナンバーを直書きしてはならない 🟡 *[spec/requirements.md L54「規定回数（TBD、仮に3回）」/ L187バランス表「仮3」。仮値の採用は`GameBalance`のマジックナンバー禁止規約に従った本ドキュメントでの決定]*
  - 関連: US-006, AC-011

### イベント駆動要件（WHEN-THEN）

- **FR-101**: `apply_contribution(current_quota, contribution)`が呼び出された場合、システムは`max(0.0, current_quota - contribution)`を返さなければならない（0未満にはならず0でクランプし、超過分は切り捨てる） 🔵 *[core-systems.md L297 / spec/requirements.md L149「0未満にはならず0でクランプする。超過分は切り捨てる」]*
  - 関連: US-002, AC-001, AC-005
- **FR-102**: `is_rank_cleared(current_quota)`が呼び出された場合、システムは`current_quota <= 0.0`の真偽を返さなければならない 🔵 *[core-systems.md L298]*
  - 関連: US-002, AC-002, AC-005
- **FR-103**: `reset_for_retry(rank_master)`が呼び出された場合、システムは`quota = rank_master.quota_max`・`elapsed_turn = 0`で初期化した**新しい**`RankState`を返さなければならない（引数の`rank_master`および呼び出し元の既存`RankState`を書き換えてはならない） 🔵 *[core-systems.md L299 / data-schema.md L83-84「降格時に`quota_max`へリセット」「降格時に0へリセット」]*
  - 関連: US-005, AC-008
- **FR-104**: `is_turn_limit_reached(current_turn, limit_turn)`が呼び出された場合、システムは`current_turn >= limit_turn`の真偽を返さなければならない 🔵 *[core-systems.md L300]*
  - 関連: US-004, AC-003
- **FR-105**: `resolve_rank_outcome(quota_cleared, turn_limit_reached)`が呼び出され`turn_limit_reached`が偽である場合、システムは`quota_cleared`の値によらず常に`RankOutcome.CONTINUE`を返さなければならない（早期クリアボーナス） 🔵 *[core-systems.md L301「制限ターン到達時にのみ判定する（`turn_limit_reached`が偽なら常に`CONTINUE`）」]*
  - 関連: US-004, AC-004
- **FR-106**: `resolve_rank_outcome`が呼び出され`turn_limit_reached`が真かつ`quota_cleared`が真である場合、システムは`RankOutcome.PROMOTION_ELIGIBLE`を返さなければならない 🔵 *[core-systems.md L301「到達時、ノルマ0なら`PROMOTION_ELIGIBLE`」]*
  - 関連: US-004, AC-004
- **FR-107**: `resolve_rank_outcome`が呼び出され`turn_limit_reached`が真かつ`quota_cleared`が偽である場合、システムは`RankOutcome.DEMOTION`を返さなければならない 🔵 *[core-systems.md L301「0でなければ`DEMOTION`」]*
  - 関連: US-005, AC-004
- **FR-108**: 納品処理（`GameState.deliver_pending_products()`）で各`DeliveryResult`が算出された場合、システムは`RankQuotaResolver.apply_contribution(_rank_state.quota, result.final_contribution)`の結果で`_rank_state.quota`を更新しなければならない 🔵 *[ヒアリング結果「既存コード資産」（guild CON-004の暫定実装を本planで置き換える確定事項）]*
  - 関連: US-002, US-010, AC-009
- **FR-109**: ランク結果を問い合わせるクエリメソッドが呼び出された場合、システムは`is_rank_cleared`と`is_turn_limit_reached`の結果を`resolve_rank_outcome`へ渡して得た`RankOutcome`を返さなければならない 🔴 *[ヒアリング結果スコープ確定事項3「`GameState`にランク結果を問い合わせるクエリメソッドを用意するに留める」。メソッド名・シグネチャの具体形はCON-009として本ドキュメントで新規決定]*
  - 関連: US-009, AC-010
- **FR-110**: ランク結果の確定処理が呼び出され結果が`RankOutcome.DEMOTION`である場合、システムは`_demotion_count`を1加算し、`RankQuotaResolver.reset_for_retry(現在ランクのRankMaster)`の戻り値で`_rank_state`を差し替えなければならない 🔵 *[spec/requirements.md L271「同一ランクでの連続再挑戦回数のカウンタ」/ core-systems.md L299「降格して同一ランクに再挑戦する際に呼ぶ」/ ヒアリング結果「降格の定義と`demotion_count`の扱い」]*
  - 関連: US-005, US-006, AC-011
- **FR-111**: `_demotion_count`が`GameBalance.MAX_DEMOTION_COUNT`に到達した場合、システムはゲームオーバーが確定した状態を保持し、その旨を問い合わせ可能にしなければならない 🔵 *[spec/requirements.md L54「同一ランクで規定回数連続して降格した場合、ゲームオーバー」/ ヒアリング結果「この判定・カウンタ管理は本plan内で実装する」]*
  - 関連: US-006, AC-011
- **FR-112**: ランク結果が確定した場合、システムは確定した`RankOutcome`を伴うシグナルを発行しなければならない 🔴 *[garden機能の`material_harvested`・alchemy機能の`product_crafted`・guild機能の`delivered`のシグナル発行パターンを踏襲した新規補完。core-systems.mdはRankSystemのシグナルを規定していない]*
  - 関連: US-011, AC-012
- **FR-113**: 降格の確定によりゲームオーバーが成立した場合、システムはゲームオーバーを通知するシグナルを発行しなければならない 🔴 *[FR-112と同じシグナル発行パターンからの新規補完。ゲームオーバー画面（別plan）への橋渡しとして必要という推測]*
  - 関連: US-006, US-011, AC-011, AC-012
- **FR-114**: `_rank_masters`に`_current_rank_id`に対応する`RankMaster`が存在しない状態でランク由来の値（`traits_unlocked`・`quota_max`・`limit_turn`）が要求された場合、システムはクラッシュせず`push_error()`で内部不整合を報告したうえで安全な既定値を返さなければならない（CON-008） 🔴 *[garden `harvest()`の`master_data_missing`パターン（`SeedMaster`欠落時の専用エラーコード扱い）を踏襲した新規補完。既定値の具体的な選択はCON-008で決定]*
  - 関連: US-007, AC-014

### 状態駆動要件（WHERE）

- **FR-201**: 現在ランクの`RankMaster.traits_unlocked`が偽である状態にある間、システムは調合の品質計算・特性発現判定へ渡す特性解禁フラグを偽としなければならない（`GameState._traits_unlocked`の暫定フィールドではなく現在ランクの`RankMaster`が権威） 🔵 *[data-schema.md L210「traits_unlocked: 特性システムが解禁済みか（Gランクは`false`固定）」/ ヒアリング結果「既存コード資産」（alchemy CON-007の暫定フィールドを本planで置き換える確定事項）]*
  - 関連: US-007, AC-014
- **FR-202**: ゲームオーバーが確定している状態にある間、システムは`_demotion_count`をさらに加算してはならず、ランク結果確定処理の再呼び出しに対して状態を変化させてはならない 🟡 *[「明確な詰み状態を持つ」（spec/requirements.md L55）以上、確定後の再入力で状態が進み続けるのは不正であるという妥当な推測。冪等性の担保]*
  - 関連: US-006, AC-011

### 任意要件（MAY）

- **FR-301**: システムは`GameState`にランク関連の状態を直接注入するテスト専用API（`_set_rank_masters_for_test()`・`_set_rank_state_for_test()`・`_set_demotion_count_for_test()`等）を提供してもよい 🟡 *[garden `_set_masters_for_test()`・alchemy `_set_recipe_masters_for_test()`パターン踏襲。`res://data/ranks/`の実データが本plan外（FR-405）であるため注入手段が必要という推測]*
  - 関連: US-012, AC-015
- **FR-302**: システムは後続plan（promotion-exam）が昇格成功時に呼び出すための`_demotion_count`リセットAPIを提供してもよい 🟡 *[data-schema.md L79「昇格成功時に0へリセット」。呼び出し元が本plan内に存在しない（ヒアリング結果）ため、APIの先出し提供は任意と判断]*
  - 関連: US-012, AC-016

### 禁止要件（MUST NOT）

- **FR-401**: `features/rank/logic/`配下の関数は副作用（状態変更・I/O・乱数の自己生成）を持ってはならない。特に`reset_for_retry`は引数や既存`RankState`をin-placeで書き換えてはならない 🔵 *[.claude/rules/architecture.md「Functional Coreに置くもの」/ tdd-implementation.md]*
  - 関連: AC-008, AC-013
- **FR-402**: `RankQuotaResolver`・`TurnLimitResolver`は乱数に依存しない設計であり、`logic/`配下で乱数を自己生成してはならない（ノルマ計算・制限ターン判定の計算式に乱数要素はない） 🔵 *[core-systems.md L295-301のメソッド表に乱数引数の記載がない]*
  - 関連: AC-013
- **FR-403**: 本plan内の実装は`PromotionExamResolver`・`ExamState`・`ExamOutcome`および昇格試験フロー自体を実装してはならない（promotion-exam planの対象） 🔵 *[ヒアリング結果スコープ確定事項1 / 「スコープに含まない事項」]*
  - 関連: US-013, AC-017
- **FR-404**: 本plan内の実装は昇格成功時のランク遷移（`_current_rank_id`を次ランクへ進める処理）を実装してはならない（試験クリアでのみ発生するため promotion-exam planの対象） 🔵 *[ヒアリング結果「スコープに含まない事項」]*
  - 関連: US-013, AC-017
- **FR-405**: 本plan内の実装は`res://data/ranks/*.tres`の実データ（G〜Sの8ランク分）を作成してはならない（コンテンツ作成planの対象） 🔵 *[ヒアリング結果スコープ確定事項2]*
  - 関連: US-013, AC-017, CON-006
- **FR-406**: 本plan内の実装は`GameState.advance_turn()`相当のターン進行メソッドを新設してはならず、ターン進行をトリガーとしたランク結果の自動判定を配線してはならない（ターンサイクル設計planの対象） 🔵 *[ヒアリング結果スコープ確定事項3]*
  - 関連: US-013, AC-017
- **FR-407**: 本plan内の実装は`features/rank/ui/`（ゲームオーバー画面・昇格演出等）を実装してはならない（別task・別planの対象） 🔵 *[ヒアリング結果「スコープに含まない事項」]*
  - 関連: US-013, AC-017
- **FR-408**: 本plan完了後、`GameState._accumulated_contribution`フィールドおよびそこへの加算処理を残してはならない（実際のノルマ消費へ完全に置き換えたうえで削除する） 🔵 *[ヒアリング結果「既存コード資産」「`_accumulated_contribution`フィールド自体は本plan完了後は不要になるため削除する」]*
  - 関連: US-010, AC-009, CON-004
- **FR-409**: 他Feature（`features/alchemy/`・`features/guild/`等）および将来のUIは`features/rank/state/rank_state.gd`を直接参照してはならない（`RankState`は`GameState`からのみ参照可） 🔵 *[.claude/rules/architecture.md「公開APIパターン」/ ヒアリング結果アーキテクチャ制約（alchemyの`SlotState`と同型パターン）]*
  - 関連: AC-016
- **FR-410**: `GameState.get_state()`はランク関連フィールドについて、呼び出し元が内部状態を直接改変できる参照をそのまま返してはならない（`RankState`は`clone()`等によるディープコピー必須） 🔵 *[.claude/rules/state-management.md「get_state()戻り値の防御的コピー必須」/ alchemy FR-403・guild FR-408（既存規約の維持）]*
  - 関連: US-009, AC-016
- **FR-411**: `resolve_rank_outcome`は`turn_limit_reached`が偽のときに`PROMOTION_ELIGIBLE`または`DEMOTION`を返してはならない（早期クリアボーナスの構造的保証。ノルマ0到達で即座に試験へ移行するバグの再発防止） 🔵 *[core-systems.md L301「ランクノルマが制限ターンより先に0になっても試験への移行は制限ターン到達まで待つ」/ spec/requirements.md L46]*
  - 関連: US-004, AC-004

## 非機能要件

### パフォーマンス

- **NFR-001**: ランクノルマ更新・ランク結果判定は`_process()`を用いず、呼び出し時の同期処理のみで完結しなければならない 🟡 *[.claude/rules/performance.md「`_process()`に書くべきでない処理」]*

### セキュリティ

- **NFR-101**: `RankQuotaResolver`・`TurnLimitResolver`および`GameState`のランク関連メソッドは、`rank_master = null`・`_rank_masters`に該当IDなし・負の`contribution`・`limit_turn = 0`のいずれを受け取ってもクラッシュしてはならない 🔵 *[.claude/rules/security.md「すべての外部入力を検証」/ FR-114のフォールバック契約]*

### ユーザビリティ

- **NFR-201**: ランク結果確定シグナル・ゲームオーバーシグナルは、将来のUI実装が「昇格試験へ進める」「あと何回で詰みか」を表示できる情報（`RankOutcome`・現在の`_demotion_count`）を伴わなければならない 🟡 *[ui-design/overview.md 画面一覧にランク進行表示が存在することを踏まえた推測。具体的なUI要件は本plan外（FR-407）]*

### 保守性・アーキテクチャ整合性

- **NFR-301**: `features/rank/`配下の実装は`logic/`・`resources/`・`state/`のディレクトリ構成に従わなければならない（`ui/`は本plan対象外） 🔵 *[.claude/rules/architecture.md]*
- **NFR-302**: 他Featureから本機能を参照する場合は`features/rank/logic/*.gd`および`features/rank/resources/*.gd`のみを参照可能とし、`state/`・`ui/`への直接参照を行ってはならない 🔵 *[.claude/rules/architecture.md「公開APIパターン」/ FR-409]*
- **NFR-303**: `_accumulated_contribution`・`_traits_unlocked`の置き換えは既存の guild plan / alchemy plan のテストを破壊してはならない。破壊する場合は当該テストを本planで更新し、更新理由をコミットメッセージに記載しなければならない 🟡 *[CON-004・CON-005が破壊的変更であることから導かれる、既存テスト資産保護のための妥当な運用要件]*

### テスト容易性

- **NFR-401**: `features/rank/logic/`配下の全public `static func`（`apply_contribution`・`is_rank_cleared`・`reset_for_retry`・`is_turn_limit_reached`・`resolve_rank_outcome`の5つ）は、正常系・異常系・境界値のテストをGdUnit4で最低1本ずつ持たなければならない 🔵 *[.claude/rules/testing.md「カバレッジ目標」]*
- **NFR-402**: テストファイルは`tests/unit/features/rank/`または`tests/integration/`に配置しなければならない（`features/rank/`配下への配置は禁止） 🔵 *[.claude/rules/architecture.md「テストファイル配置」]*

## 制約

- **CON-001**: 実装言語はGDScript、対象エンジンはGodot 4.x（現行4.7）とする 🔵 *[CLAUDE.md / docs/dev/context.md]*
- **CON-002**: テストフレームワークはGdUnit4（v6.2.1）を使用し、`tests/unit/features/rank/`・`tests/integration/`に配置する 🔵 *[.claude/rules/testing.md / docs/dev/context.md]*
- **CON-003**: `RankOutcome` enumは`features/rank/logic/rank_outcome.gd`に単独の`class_name`付きスクリプトとして配置する。理由: `TurnLimitResolver`の戻り値型として`logic/`内から参照され、かつ`GameState`（Application層）と後続の promotion-exam plan からも参照されるため、`state/`（`GameState`専用、FR-409）に置くと他Featureから参照できなくなるため 🔴 *[core-systems.md L305-310のクラス図では配置未確定。guild CON-003（`DeliveryResult`を`logic/`へ配置した判断）と同型の検討を本ドキュメントで実施した結果の新規決定]*
- **CON-004**: **【破壊的変更】** guild planが実装した`GameState.deliver_pending_products()`内の「`final_contribution`を`_accumulated_contribution`へ単純加算する」挙動（guild FR-107 / guild CON-004）を、本planで`RankQuotaResolver.apply_contribution`による`_rank_state.quota`更新（FR-108）へ置き換える。`_accumulated_contribution`フィールドは削除する（FR-408）。guild planの受入基準 AC-010（累積貢献度の検証）は本planで`_rank_state.quota`ベースへ書き換える必要がある 🔵 *[ヒアリング結果「既存コード資産」。guild CON-004が「後続のrank planが正式なランクノルマ管理へ置き換える前提」と明記済み]*
- **CON-005**: **【破壊的変更】** alchemy planが設けた暫定フィールド`GameState._traits_unlocked`（alchemy CON-007）を、現在ランクの`RankMaster.traits_unlocked`由来の値へ置き換える（FR-201）。既存のテスト専用API`_set_traits_unlocked_for_test()`は、`_set_rank_masters_for_test()`によるランク注入経由の指定へ移行するか、後方互換のために残すかを実装時に判断する（残す場合は「ランク由来の値を一時的に上書きするテスト専用手段」である旨をコメントで明記する） 🟡 *[ヒアリング結果「既存コード資産」で置き換えは確定。既存テストAPIの去就は明示されていないため、本ドキュメントで実装時判断に委ねる方針を採る]*
- **CON-006**: `res://data/ranks/`は空であり本planでも実データを作成しない（FR-405）ため、GdUnit4テストは`RankMaster`をコード上でインスタンス化したテストフィクスチャを使用する 🔵 *[ヒアリング結果スコープ確定事項2 / guild CON-005・alchemy CON-005と同一事情]*
- **CON-007**: ゲームオーバー閾値は`GameBalance.MAX_DEMOTION_COUNT := 3`（仮値）とする。`spec/requirements.md` L187が🟡TBD（仮2〜3、仮3）としているため、バランス調整フェーズ（別plan）で変更されうる暫定値である 🟡 *[spec/requirements.md L54・L187。「仮3」の採用は既存文書の推奨値をそのまま用いた妥当な判断]*
- **CON-008**: `_rank_masters`に`_current_rank_id`が存在しない場合のフォールバックは、`traits_unlocked`は`false`（安全側＝特性封印）、`quota_max`は`0.0`、`limit_turn`は`0`を返し、いずれの場合も`push_error()`で内部不整合を報告する。`false`を安全側と判断する根拠は、Gランク（初期状態）が`traits_unlocked = false`固定であり、誤って特性を解禁するより封印したままの方がゲーム進行上の破綻が小さいため 🔴 *[FR-114のフォールバック具体値は既存設計文書に記載がなく、本ドキュメントでの新規決定]*
- **CON-009**: ランク結果評価APIは、副作用のない問い合わせ（`evaluate_rank_outcome() -> RankOutcome`）と、結果を状態へ確定反映する処理（`commit_rank_outcome() -> Result`。DEMOTION時に`_demotion_count`加算・`reset_for_retry`適用・シグナル発行を行う）の**2メソッドに分離**する。分離の理由は、UIが結果を先読み表示する用途（副作用なし）と、実際に降格を確定させる用途（副作用あり）が異なるライフサイクルを持ち、`.claude/rules/architecture.md`「検証責務のレイヤー配置原則」が「Presentationは先出しフィードバックのみ、Applicationが実行直前にDomain層を再評価する」を求めるため 🔴 *[ヒアリング結果スコープ確定事項3「クエリメソッドを用意するに留める」からメソッド名・分割方針の具体形を本ドキュメントで新規決定]*
- **CON-010**: **【前提依存】** 本plan着手時点（2026-08-16）でリポジトリの`atelier/features/guild/`は空であり、guild planの`DeliveryResolver`・`DeliveryResult`・`GameState.deliver_pending_products()`は**未実装**である。本planのFR-108（納品時のノルマ消費）およびCON-004（`_accumulated_contribution`の置き換え）は guild plan の実装完了を前提とするため、guild planの実装マージ後に着手すること 🔴 *[本ドキュメント作成時に`atelier/features/`および`atelier/autoload/game_state.gd`を実地調査して判明した事実。ヒアリング結果は guild plan を実装済みとして記述していたため、この差異は要確認]*
- **CON-011**: `RankState`は`RefCounted`継承とし、`GameState.get_state()`の防御的コピー（FR-410）のために`clone()`メソッドを持たせる。理由: `GardenState`・`SlotState`（既存の`state/`型）が同一パターンを採用済みであり、`Resource`継承にすると`.tres`保存対象と誤認されるため 🟡 *[既存の`atelier/features/garden/state/garden_state.gd`・`atelier/features/alchemy/state/slot_state.gd`の実装パターンからの妥当な踏襲]*
- **CON-012**: `RankMaster`の`exam_turn_limit`・`exam_difficulty_coefficient`は本planでは一切参照しない（promotion-exam planの対象）が、マスターデータのスキーマ完全性のため型定義には含める。本planのテストではこれら2フィールドの値を検証しない 🔵 *[ヒアリング結果「既存設計」の`RankMaster`定義に明記された確定事項]*

## 信頼性レベルサマリー

- 🔵 青信号: 38件
  - FR 28件: FR-001〜FR-006 / FR-101〜FR-108, FR-110, FR-111 / FR-201 / FR-401〜FR-411
  - NFR 5件: NFR-101, NFR-301, NFR-302, NFR-401, NFR-402
  - CON 5件: CON-001, CON-002, CON-004, CON-006, CON-012
- 🟡 黄信号: 10件
  - FR 4件: FR-007, FR-202, FR-301, FR-302
  - NFR 3件: NFR-001, NFR-201, NFR-303
  - CON 3件: CON-005, CON-007, CON-011
- 🔴 赤信号: 8件（要確認）
  - FR 4件: FR-109, FR-112, FR-113, FR-114
  - CON 4件: CON-003, CON-008, CON-009, CON-010
- 合計: 56件（FR 36件 + NFR 8件 + CON 12件）
