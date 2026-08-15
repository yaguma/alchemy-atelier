# guild 要件定義書

## 概要

「Atelier」（Godot 4.x + GDScript）の Phase 2 機能実装として、ギルド納品（GuildSystem）を実装する。庭（garden）・調合（alchemy）は既に`logic/`・`state/`・`resources/`・`GameState`統合まで完了しており、調合完了時に生成され`GameState._pending_products`へ積まれた`ProductInstance`を、プレイヤー操作なしで自動的にギルドへ納品・決算する一連の処理を本planで実装する。

本要件は `docs/design/atelier-alchemy-core/core-systems.md`「GuildSystem（ギルド納品）詳細設計」（L185-219）・`docs/design/atelier-alchemy-core/data-schema.md`（DailyOrderMaster節 L170-189）・`docs/spec/atelier-alchemy-core/requirements.md` §3「ギルド納品」/§4「日替わり指定調合物」/§5 に既に定義された契約をEARS形式に翻訳したものである。矛盾がある場合は既存設計文書を正とする。

### スコープ境界（ユーザーヒアリングで確定済み）

**含む**:
- `features/guild/logic/delivery_resolver.gd`（`DeliveryResolver`: `matches_order`・`resolve`）
- `features/guild/logic/delivery_result.gd`（`DeliveryResult`データ型。配置根拠はCON-003参照）
- `features/guild/resources/daily_order_master.gd`（`DailyOrderMaster`のResource型定義）
- `shared/constants/game_balance.gd` への指定合致ボーナス倍率定数の追加
- `autoload/game_state.gd` への納品処理メソッド（`_pending_products`を消費し`DeliveryResolver.resolve`を呼び出す）の新設
- `reward`の`_gold`即時加算、および`contribution`の暫定累積フィールドへの積算

**含まない**（別task・別planの対象）:
- RankSystem本体（ランクノルマ管理・降格判定・昇格試験の実装）: rank plan
- `res://data/daily_orders/*.tres`の実データ作成、および毎ターン終了時の指定調合物の再抽選ロジック: 別plan（日次/ターンサイクル全体の設計が別途必要なため）
- `features/guild/ui/`（納品結果表示等）の実装
- 昇格試験からの`daily_order = null`呼び出しパス自体の実装（RankSystem側の責務。本planは`matches_order`が`null`を受けて`false`を返す契約の実装・テストのみ）

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: plan.md（未作成、後続フェーズで生成）
- **既存設計資産**: [`core-systems.md`](../../../design/atelier-alchemy-core/core-systems.md) GuildSystem節 / [`data-schema.md`](../../../design/atelier-alchemy-core/data-schema.md) DailyOrderMaster節
- **先行plan**: [`alchemy/requirements.md`](../alchemy/requirements.md)（`ProductInstance`・`pending_products`の生成側契約） / [`garden/requirements.md`](../garden/requirements.md)

## 用語集

| 用語 | 定義 |
|-----|------|
| ギルド納品（Guild Delivery） | 調合完了時にプレイヤー操作なしで自動実行される決算処理。`features/guild/` |
| `DeliveryResolver` | 納品判定・最終価値算出を担うDomain層の静的クラス（副作用なし）。`matches_order`・`resolve`の2つのpublic `static func`を持つ |
| `DeliveryResult` | 納品1件の決算結果。`final_contribution: float, final_reward: float, order_matched: bool` |
| 日替わり指定調合物（DailyOrderMaster） | 「本日はこの品目 or この特性を持つ調合物を求む」というギルド側の指定。`id, condition_type, target_recipe_id, target_trait, match_bonus_multiplier` |
| `condition_type` | 指定条件の種別。`"item"`（品目指定）または`"trait"`（特性傾向指定） |
| 指定合致ボーナス | 完成品が本日の指定に合致した場合に`final_contribution`/`final_reward`の双方へ掛かる倍率。`GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER`（1.3倍、CON-006） |
| 未納品キュー（`_pending_products`） | alchemy planが新設した`GameState`内の`Array[ProductInstance]`。調合成功時に`product.clone()`が追加される。本planが唯一の消費側となる |
| 貢献度（contribution） | ランクノルマを削る値。`ProductInstance.contribution`は指定合致ボーナス適用前の値であり、本planの`DeliveryResolver.resolve`が合致ボーナスを掛けて`final_contribution`にする |
| 報酬（reward） | ゴールド獲得量。`contribution`と同様に`resolve`が合致ボーナスを掛けて`final_reward`にする |
| 累積貢献度（`_accumulated_contribution`） | RankSystem未実装のため`GameState`内に暫定的に置く貢献度の蓄積先（CON-004）。後続のrank planが正式なランクノルマ管理へ置き換える |
| `GameState` | Application層Autoload。納品処理メソッドを持ち、唯一の状態変更者・仲介者 |
| `ProductInstance` | 調合実行の成果（alchemy planで`shared/entities/`に作成済み）。`recipe_id, quality_score, activated_traits, contribution, reward`・`clone()` |
| `Result` | `shared/entities/result.gd`。`success: bool, value: Variant, error_code: StringName`と`Result.ok()`/`Result.fail()` |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: システムは`DeliveryResolver`を`features/guild/logic/delivery_resolver.gd`配下に、副作用を持たない`static func`（`Node`非継承）の集合として実装しなければならない 🔵 *[core-systems.md L192-199 クラス図`<<static>>` / .claude/rules/architecture.md「Functional Coreに置くもの」]*
  - 関連: US-008, AC-013
- **FR-002**: システムは納品1件の決算結果を`features/guild/logic/delivery_result.gd`の`DeliveryResult`（`final_contribution: float, final_reward: float, order_matched: bool`）として表現しなければならない 🔴 *[core-systems.md L200-205はクラス図のみでファイル配置は未確定。CON-003の根拠に基づく本ドキュメントでの配置決定]*
  - 関連: US-006, AC-006
- **FR-003**: システムは日替わり指定調合物のマスターデータを`features/guild/resources/daily_order_master.gd`の`DailyOrderMaster`（`id: String, condition_type: String, target_recipe_id: String, target_trait: String, match_bonus_multiplier: float`）として`Resource`継承の型で定義しなければならない 🔵 *[data-schema.md L170-189]*
  - 関連: US-001, US-002, AC-007
- **FR-004**: システムは指定合致ボーナス倍率を`shared/constants/game_balance.gd`に`DAILY_ORDER_MATCH_BONUS_MULTIPLIER := 1.3`として定義し、コード中にマジックナンバーを直書きしてはならない 🔵 *[ヒアリング結果スコープ確定事項3（requirements.md(spec) §5「仮1.2〜1.5倍」の中間値として1.3に確定）]*
  - 関連: US-001, US-002, AC-004
- **FR-005**: システムは`GameState`に納品処理メソッドを新設し、`_pending_products`を消費して`DeliveryResolver.resolve`を呼び出す唯一の経路としなければならない 🔵 *[ヒアリング結果スコープ確定事項1 / .claude/rules/state-management.md「GameStateが唯一の仲介者」]*
  - 関連: US-004, AC-008
- **FR-006**: システムは納品で得た`final_contribution`の蓄積先を`GameState`内の暫定フィールド`_accumulated_contribution: float`として保持しなければならない 🔴 *[ヒアリング結果スコープ確定事項1。RankSystem未実装のため`_traits_unlocked`（alchemy CON-007）・`_garden_slot_count`（garden CON-004）と同型の暫定フィールドパターンを踏襲した新規補完]*
  - 関連: US-005, US-011, AC-010

### イベント駆動要件（WHEN-THEN）

- **FR-101**: `matches_order(product, daily_order)`が呼び出され`daily_order.condition_type == "item"`である場合、システムは`product.recipe_id == daily_order.target_recipe_id`の真偽を返さなければならない 🔵 *[core-systems.md L212「`"item"`の場合は`product.recipe_id == daily_order.target_recipe_id`」]*
  - 関連: US-001, US-007, AC-001, AC-003
- **FR-102**: `matches_order(product, daily_order)`が呼び出され`daily_order.condition_type == "trait"`である場合、システムは`product.activated_traits.has(daily_order.target_trait)`の真偽を返さなければならない 🔵 *[core-systems.md L212「`"trait"`の場合は`product.activated_traits.has(daily_order.target_trait)`」]*
  - 関連: US-002, AC-002
- **FR-103**: `resolve(product, daily_order)`が呼び出された場合、システムは`matches_order`の結果を`DeliveryResult.order_matched`に格納し、合致時は`final_contribution = product.contribution × daily_order.match_bonus_multiplier`・`final_reward = product.reward × daily_order.match_bonus_multiplier`としなければならない 🔵 *[core-systems.md L213「指定合致ボーナスの適用はこの関数が一手に担う」]*
  - 関連: US-001, US-002, US-008, AC-004, AC-014
- **FR-104**: `resolve`実行時に`order_matched`が偽である場合、システムは倍率1.0を適用し`final_contribution = product.contribution`・`final_reward = product.reward`をそのまま返さなければならない 🔵 *[core-systems.md L213「`order_matched ? bonus : 1.0`」]*
  - 関連: US-003, AC-005
- **FR-105**: 納品処理メソッドが呼び出された場合、システムは`_pending_products`を先頭から順に全件消費し、各`ProductInstance`について`DeliveryResolver.resolve`を1回ずつ呼び出したうえで、処理完了時に`_pending_products`を空にしなければならない 🔴 *[ヒアリング結果スコープ確定事項1（キューを消費する契約）から導いた具体的な消費順序・全件処理の新規補完]*
  - 関連: US-004, AC-008
- **FR-106**: 各`DeliveryResult`が算出された場合、システムはその`final_reward`を`GameState._gold`へ即時加算しなければならない（`_gold`は`int`のため`roundi()`で丸める。CON-007） 🔴 *[ヒアリング結果スコープ確定事項1「rewardは納品時に即座に_goldへ加算する」。float→intの丸め規則は本ドキュメントでの新規補完]*
  - 関連: US-004, AC-009
- **FR-107**: 各`DeliveryResult`が算出された場合、システムはその`final_contribution`を`GameState._accumulated_contribution`へ加算しなければならない 🔴 *[ヒアリング結果スコープ確定事項1「contributionはGameState内の暫定フィールドに積算」]*
  - 関連: US-005, AC-010
- **FR-108**: 納品処理が完了した場合、システムは`delivered(results: Array[DeliveryResult])`シグナルを発行しなければならない 🔴 *[garden機能の`material_harvested`・alchemy機能の`product_crafted`のシグナル発行パターンを踏襲した新規補完。core-systems.mdはGuildSystemのシグナルを規定していない]*
  - 関連: US-006, AC-011
- **FR-109**: 納品処理メソッド呼び出し時に`_pending_products`が空である場合、システムは状態を一切変更せず、納品件数0を表す成功の`Result`を返さなければならない 🟡 *[「納品はプレイヤー操作なしで自動実行」（core-systems.md L217）である以上、キューが空のまま呼ばれる状況は正常系として扱うのが妥当という推測]*
  - 関連: US-009, AC-012

### 状態駆動要件（WHERE）

- **FR-201**: `daily_order`が`null`である状態にある間、システムは`matches_order`が必ず`false`を返し、`resolve`が指定合致ボーナスを適用しない（倍率1.0）ようにしなければならない 🔵 *[core-systems.md L212「`daily_order`が`null`の場合は必ず`false`を返す（2026-08-05修正、PRレビューCritical#9対応）」]*
  - 関連: US-007, AC-003

### 任意要件（MAY）

- **FR-301**: システムは`GameState`に本日の指定調合物を注入するテスト専用API（`_set_current_daily_order_for_test()`等）を提供してもよい 🟡 *[alchemy機能の`_set_traits_unlocked_for_test()`・garden機能の`_set_masters_for_test()`パターン踏襲。再抽選ロジックが本plan外（CON-010）であるため注入手段が必要という推測]*
  - 関連: US-007, AC-008

### 禁止要件（MUST NOT）

- **FR-401**: `features/guild/logic/`配下の関数は副作用（状態変更・I/O・乱数の自己生成）を持ってはならない 🔵 *[.claude/rules/architecture.md「Functional Coreに置くもの」/ tdd-implementation.md]*
  - 関連: AC-013
- **FR-402**: `DeliveryResolver`は乱数に依存しない設計であり、`logic/`配下で乱数を自己生成してはならない（納品判定・価値算出の計算式に乱数要素はない） 🔵 *[core-systems.md L208-214のメソッド表に乱数引数の記載がない]*
  - 関連: AC-013
- **FR-403**: 指定合致ボーナス（`match_bonus_multiplier`）は`DeliveryResolver.resolve`のみが適用しなければならず、`ProductValueCalculator.calculate_contribution`/`calculate_reward`側で適用してはならない（二重乗算バグの再発防止） 🔵 *[core-systems.md L213「ProductValueCalculator側では合致ボーナスを掛けない（2026-08-05修正、PRレビューCritical#4対応）」/ alchemy FR-406]*
  - 関連: US-008, AC-014
- **FR-404**: 本plan内の実装はRankSystem本体（ランクノルマの減算・上限管理・降格判定・昇格試験）を実装してはならない（rank planの対象） 🔵 *[ヒアリング結果「スコープに含まない事項」]*
  - 関連: AC-016, CON-004
- **FR-405**: 本plan内の実装は`res://data/daily_orders/*.tres`の実データ作成、および毎ターン終了時の指定調合物の再抽選ロジックを実装してはならない（別planの対象） 🔵 *[ヒアリング結果スコープ確定事項2]*
  - 関連: AC-016, CON-005, CON-010
- **FR-406**: 本plan内の実装は`features/guild/ui/`（納品結果表示等）を実装してはならない（別task・別planの対象） 🔵 *[ヒアリング結果「スコープに含まない事項」]*
  - 関連: AC-016
- **FR-407**: 本plan内の実装は昇格試験から`daily_order = null`で`DeliveryResolver`を呼び出すパス自体を実装してはならない（RankSystem側の責務。本planは`null`受領時の契約のみ実装・テストする） 🔵 *[ヒアリング結果「スコープに含まない事項」]*
  - 関連: AC-003, AC-016
- **FR-408**: `GameState.get_state()`は`pending_products`を含む戻り値について、呼び出し元が内部状態を直接改変できる参照をそのまま返してはならない（`duplicate(true)`または`clone()`によるディープコピー必須） 🔵 *[.claude/rules/state-management.md「get_state()戻り値の防御的コピー必須」/ alchemy FR-403（既存規約の維持）]*
  - 関連: US-010, AC-015

## 非機能要件

### パフォーマンス

- **NFR-001**: 納品処理は`_process()`を用いず、呼び出し時の同期処理のみで完結しなければならない 🟡 *[.claude/rules/performance.md「`_process()`に書くべきでない処理」]*

### セキュリティ

- **NFR-101**: `DeliveryResolver`および納品処理メソッドは、`daily_order = null`・空の`_pending_products`・`condition_type`が`"item"`/`"trait"`以外の未知値、のいずれを受け取ってもクラッシュしてはならない 🔵 *[core-systems.md L212のnullガード契約 / .claude/rules/security.md「すべての外部入力を検証」]*

### ユーザビリティ

- **NFR-201**: `delivered`シグナルは納品1件ごとの`DeliveryResult`（`order_matched`を含む）を保持した配列を渡し、将来のUI実装が「指定に合致したか」を件別に表示できるようにしなければならない 🟡 *[ui-design/overview.md 画面一覧に納品結果表示が存在することを踏まえた推測。具体的なUI要件は本plan外]*

### 保守性・アーキテクチャ整合性

- **NFR-301**: `features/guild/`配下の実装は`logic/`・`resources/`のディレクトリ構成に従わなければならない（`ui/`は本plan対象外、`state/`は本planでは作成しない） 🔵 *[.claude/rules/architecture.md]*
- **NFR-302**: 他Featureから本機能を参照する場合は`features/guild/logic/*.gd`および`features/guild/resources/*.gd`のみを参照可能とし、`state/`・`ui/`への直接参照を行ってはならない 🔵 *[.claude/rules/architecture.md「公開APIパターン」]*

### テスト容易性

- **NFR-401**: `features/guild/logic/`配下の全public `static func`（`matches_order`・`resolve`）は、正常系・異常系・境界値のテストをGdUnit4で最低1本ずつ持たなければならない 🔵 *[.claude/rules/testing.md「カバレッジ目標」]*
- **NFR-402**: テストファイルは`tests/unit/features/guild/`または`tests/integration/`に配置しなければならない（`features/guild/`配下への配置は禁止） 🔵 *[.claude/rules/architecture.md「テストファイル配置」]*

## 制約

- **CON-001**: 実装言語はGDScript、対象エンジンはGodot 4.x（現行4.7）とする 🔵 *[CLAUDE.md / docs/dev/context.md]*
- **CON-002**: テストフレームワークはGdUnit4（v6.2.1）を使用し、`tests/unit/features/guild/`・`tests/integration/`に配置する 🔵 *[.claude/rules/testing.md / docs/dev/context.md]*
- **CON-003**: `DeliveryResult`は`features/guild/logic/delivery_result.gd`に配置する。理由: `core-systems.md`のクラス図では配置未確定であり、参照元が`DeliveryResolver`（同一Featureの`logic/`）と`GameState`（Application層。Domain層を参照可）に限られるため`shared/entities/`へ昇格する必要がなく、かつ`state/`に置くと他Feature（rank plan）から参照できなくなるため 🔴 *[alchemy CON-003（`ProductInstance`を`shared/entities/`へ配置した判断）と同型の検討を本ドキュメントで実施した結果の新規決定]*
- **CON-004**: RankSystemが別plan未実装のため、`final_contribution`の蓄積先は`GameState._accumulated_contribution: float`（初期値`0.0`）とする。後続のrank planが正式なランクノルマ管理（`quota_remaining`の減算等）へ置き換える前提であり、コード上に暫定である旨をコメントで明記する 🔵 *[ヒアリング結果スコープ確定事項1。alchemy CON-007の`_traits_unlocked`・garden CON-004の`_garden_slot_count`と同型のパターンが採用済み]*
- **CON-005**: `res://data/daily_orders/`は空であり本planでも実データを作成しないため、GdUnit4テストは`DailyOrderMaster`をコード上でインスタンス化したテストフィクスチャを使用する 🔵 *[ヒアリング結果スコープ確定事項2 / alchemy CON-005と同一事情]*
- **CON-006**: `match_bonus_multiplier`の既定値は1.3とし、`GameBalance.DAILY_ORDER_MATCH_BONUS_MULTIPLIER := 1.3`として定義する。`DailyOrderMaster`インスタンスが個別の`match_bonus_multiplier`を持つ場合はインスタンス側の値を優先し、`GameBalance`定数は実データ作成時（別plan）の既定値としてのみ使用する 🔵 *[ヒアリング結果スコープ確定事項3 / alchemy FR-006の「実行時権威はインスタンス側、定数は初期値」パターンを踏襲]*
- **CON-007**: `final_reward`（`float`）から`GameState._gold`（`int`）への加算は`roundi()`による四捨五入で行う。`floori()`（切り捨て）を採用しないのは、品質倍率・特性倍率・合致倍率の連鎖乗算で生じる端数がプレイヤーに不利側へ一貫して偏るのを避けるため 🔴 *[float→intの変換規則は既存設計文書に記載がなく、本ドキュメントでの新規決定。alchemy planの`QualityCalculator`が平均値に`roundi()`相当の四捨五入を用いている点と方針を揃えた]*
- **CON-008**: `matches_order`/`resolve`の`daily_order`引数は`null`許容が契約（FR-201）であるため、型注釈は`DailyOrderMaster`とし（GDScriptのオブジェクト型注釈は`null`を許容する）、関数冒頭で`if daily_order == null`のガードを置く 🟡 *[GDScriptの型システム上、`Resource`継承型の引数は`null`を代入可能であるという言語仕様に基づく妥当な実装方針]*
- **CON-009**: 納品処理メソッドのシグネチャは`deliver_pending_products() -> Result`（成功時`Result.ok(results: Array[DeliveryResult])`）の単一アトミック呼び出しとする。1件ずつ納品する逐次API（`deliver_one()`等）は提供しない 🔴 *[core-systems.md L217「納品自体はプレイヤー操作なしで自動実行される」からメソッド名・戻り値の具体形を本ドキュメントで新規決定。alchemy CON-009の「単一アトミック呼び出し」方針を踏襲]*
- **CON-010**: 本日の指定調合物の再抽選ロジックが本plan外（FR-405）であるため、`GameState`は`_current_daily_order: DailyOrderMaster = null`を暫定フィールドとして保持し、既定値`null`（指定なし＝全納品が非合致）で動作する。再抽選の実装は別planが本フィールドの更新経路を追加する 🔴 *[ヒアリング結果スコープ確定事項2から導いた、納品処理が`daily_order`をどこから得るかについての本ドキュメントでの新規決定]*

## 信頼性レベルサマリー

- 🔵 青信号: 27件（FR 17件 + NFR 5件 + CON 5件）
- 🟡 黄信号: 5件（FR 2件: FR-109, FR-301 / NFR 2件: NFR-001, NFR-201 / CON 1件: CON-008）
- 🔴 赤信号: 10件（FR 6件: FR-002, FR-006, FR-105, FR-106, FR-107, FR-108 / CON 4件: CON-003, CON-007, CON-009, CON-010）
- 合計: 42件（FR 25件 + NFR 7件 + CON 10件）
