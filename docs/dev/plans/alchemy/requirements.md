# alchemy 要件定義書

## 概要

「Atelier」（Godot 4.x + GDScript）の Phase 2 機能実装として、調合（AlchemySystem、★ゲームの核心）を実装する。庭（garden）機能は既に`logic/`・`state/`・`resources/`・`GameState`統合まで完了しており、庭で仕込んだ素材（`MaterialInstance`）を調合台（投入枠）へ投入し、品質を盛るか特性を宿すかのトレードオフをしながら調合物（`ProductInstance`）を生み出す一連の処理を、本plan（調合実行まで）で実装する。

本要件は `docs/design/atelier-alchemy-core/core-systems.md`「AlchemySystem詳細設計」（L98-181）・`docs/design/atelier-alchemy-core/data-schema.md`（RecipeMaster節）・`docs/design/atelier-alchemy-core/dataflow.md`（調合のデータフロー、L60-104）・`docs/spec/atelier-alchemy-core/requirements.md` §3/§4/§5 に既に定義された契約をEARS形式に翻訳したものである。矛盾がある場合は既存設計文書を正とする。

### スコープ境界（ユーザーヒアリングで確定済み）

**含む**:
- `features/alchemy/logic/`（`QualityCalculator`, `TraitActivation`, `ProductValueCalculator`）
- `features/alchemy/state/`（`SlotState`）
- `features/alchemy/resources/`（`RecipeMaster`）
- `shared/entities/product_instance.gd`（`ProductInstance`、複数Feature共有のため。配置根拠はCON-003参照）
- `autoload/game_state.gd` への統合メソッド（`execute_alchemy`、および付随する`load_alchemy_master_data`相当）
- `GameState`内の未納品キュー`pending_products: Array[ProductInstance]`の新設

**含まない**（別task・別planの対象）:
- ギルド納品（`DeliveryResolver.matches_order`/`resolve`）・日替わり指定調合物との合致判定・ランクノルマ減算・指定合致ボーナスの適用（GuildSystem、guild plan）
- 昇格試験での調合流用（RankSystem、rank plan）
- `features/alchemy/ui/`（`AlchemyScreen`等）の実装
- ショップでの触媒購入・レシピ解禁購入処理（WorkshopSystem、workshop plan）

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: plan.md（未作成、後続フェーズで生成）
- **既存設計資産**: [`core-systems.md`](../../../design/atelier-alchemy-core/core-systems.md) AlchemySystem節 / [`data-schema.md`](../../../design/atelier-alchemy-core/data-schema.md) / [`dataflow.md`](../../../design/atelier-alchemy-core/dataflow.md) 調合のデータフロー

## 用語集

| 用語 | 定義 |
|-----|------|
| 調合（Alchemy） | 投入枠に素材を組み合わせて調合物を作る主戦場機能。`features/alchemy/` |
| 投入枠（SlotState） | 調合台に素材を投入する枠。`materials: Array[MaterialInstance], max_slots: int, selected_recipe_id: StringName`を保持。上限は`player.permanent_upgrades.alchemy_slot_count` |
| レシピ（RecipeMaster） | 調合物の設計図となるマスターデータ。`id, name, base_contribution, base_reward`。実行前に解禁済みから1つ選ぶ（事前選択方式） |
| 事前選択方式 | 調合実行前に解禁済みレシピを1つ選択し、その基礎値を価値計算に用いる方式（確定仕様） |
| 品質スコア（quality_score） | 投入素材の品質平均を四捨五入した1〜5の整数値。触媒があれば+1（上限5クランプ） |
| 品質倍率（quality_multiplier） | 品質スコア（1〜5）に対する単調非減少の乗数。`GameBalance.QUALITY_MULTIPLIER_TABLE`で定義 |
| 特性発現（TraitActivation） | 同一特性タグを2個以上投入すると発現するルール。1個のみ不発、3個目以降は据え置き |
| 貢献度系特性 | 聖(`holy`)・浄(`purify`)・癒(`heal`)。発現すると貢献度にのみボーナス（乗算合成） |
| 報酬系特性 | 金(`gold`)・華(`glamour`)・稀(`rare`)。発現すると報酬にのみボーナス（乗算合成） |
| 触媒（catalyst） | 補助系特性。`trait_tags.has(&"catalyst")`。投入1個で成果物の最終品質+1段（上限5クランプ）。発現閾値2個ルールの対象外 |
| `traits_unlocked` | 現在ランクで特性システムが解禁済みか。Gランクは`false`固定（特性封印）。本plan内は`RankMaster`未実装のため`GameState`内の暫定フィールドで保持（CON-007） |
| 調合物（ProductInstance） | 調合実行の成果。`recipe_id, quality_score, activated_traits, contribution, reward` |
| 貢献度（contribution） | `基礎貢献度 × 品質倍率 × 貢献度系特性ボーナス`（指定合致ボーナスは含まない。GuildSystem側の責務） |
| 報酬（reward） | `基礎報酬 × 品質倍率 × 報酬系特性ボーナス`（指定合致ボーナスは含まない） |
| 未納品キュー（pending_products） | 調合成功で生成された`ProductInstance`を溜める`GameState`内配列。後続のguild planが消費する想定のインターフェース |
| `GameState` | Application層Autoload。調合関連の統合メソッド（`execute_alchemy`）を持つ |
| `MaterialInstance` | 収穫・購入で得られる素材のランタイムインスタンス（garden planで作成済み、`shared/entities/`） |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: システムは投入枠のランタイム状態を`features/alchemy/state/slot_state.gd`の`SlotState`（`materials: Array[MaterialInstance], max_slots: int, selected_recipe_id: StringName`）として管理しなければならない 🔵 *[architecture.md L220「state/slot_state.gd」/ core-systems.md L123-128]*
  - 関連: US-005, US-007, AC-007, AC-008
- **FR-002**: システムはレシピのマスターデータを`features/alchemy/resources/recipe_master.gd`の`RecipeMaster`（`id: String, name: String, base_contribution: float, base_reward: float`）として`res://data/recipes/*.tres`に定義しなければならない 🔵 *[data-schema.md L150-166]*
  - 関連: US-005, AC-009, AC-014
- **FR-003**: システムは調合完了時に生成される調合物を`shared/entities/product_instance.gd`の`ProductInstance`（`recipe_id: StringName, quality_score: int, activated_traits: Array[StringName], contribution: float, reward: float`）として表現しなければならない 🔴 *[core-systems.md L129-135はクラス図のみでファイル配置は未確定（ヒアリング結果「要検討」）。CON-003の根拠に基づく本ドキュメントでの配置決定]*
  - 関連: US-008, AC-010
- **FR-004**: システムは`QualityCalculator`, `TraitActivation`, `ProductValueCalculator`を`features/alchemy/logic/`配下に副作用を持たない`static func`として実装しなければならない 🔵 *[architecture.md「Domain層」/ core-systems.md L108-122]*
  - 関連: US-001, US-002, US-003, US-004, AC-001〜AC-004, AC-013
- **FR-005**: システムは調合関連の数値を`shared/constants/game_balance.gd`の`GameBalance`に以下の具体値で定数として定義し、コード中にマジックナンバーを直書きしてはならない 🔴 *[requirements.md(spec) §5「数値設計（仮置き）」の仮範囲をヒアリング結果の方針に従い本plan内で具体値へ確定。数値自体はバランス調整サイクルで後日上書き前提]*
  - `ALCHEMY_SLOT_COUNT_DEFAULT := 4`
  - `QUALITY_MULTIPLIER_TABLE := {1: 1.0, 2: 1.25, 3: 1.5, 4: 1.75, 5: 2.0}`（品質1〜5への単調非減少の乗数）
  - `TRAIT_ACTIVATION_THRESHOLD := 2`（特性発現に必要な同一タグ出現数）
  - `CATALYST_BASE_QUALITY_SCORE := 3`（触媒素材の購入時基準品質、B相当）
  - `TRAIT_CONTRIBUTION_BONUS := {&"holy": 1.3, &"purify": 1.3, &"heal": 1.3}`
  - `TRAIT_REWARD_BONUS := {&"gold": 1.3, &"glamour": 1.3, &"rare": 1.3}`
  - `INITIAL_RECIPE_ID: StringName = &"recipe_healing_potion"`
  - 関連: US-001〜US-004, AC-001〜AC-004, AC-014
- **FR-006**: システムは調合投入枠数の実行時権威を`player.permanent_upgrades.alchemy_slot_count`とし、`GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT`は当該フィールドのゲーム開始時初期値としてのみ使用しなければならない 🔵 *[data-schema.md L19, L80]*
  - 関連: US-007, AC-007, AC-008
- **FR-007**: システムは解禁済みレシピID一覧を`unlocked_recipe_ids: Array[StringName]`として管理し、初期状態で最低1件（`GameBalance.INITIAL_RECIPE_ID`が指す`recipe_healing_potion`）を保証しなければならない 🔵 *[data-schema.md L82 / requirements.md(spec) L130]*
  - 関連: US-005, AC-009, AC-014
- **FR-008**: システムは調合成功時に生成された`ProductInstance`を`GameState`の未納品キュー`pending_products: Array[ProductInstance]`に追加しなければならない 🔴 *[ヒアリング結果スコープ確定事項3。ギルド納品が別plan未実装であるための橋渡しインターフェースとして新規補完]*
  - 関連: US-008, US-011, AC-010

### イベント駆動要件（WHEN-THEN）

- **FR-101**: 呼び出し元が調合実行操作を行った場合、システムは`GameState.execute_alchemy(recipe_id: StringName, material_instance_ids: Array[String]) -> Result`を実行しなければならない 🔵 *[dataflow.md L78「execute_alchemy(selected_recipe_id, slot_materials)」/ ui-design/screens/alchemy.md L90]*
  - 関連: US-005, US-006, US-007, AC-005〜AC-010
- **FR-102**: `execute_alchemy`が呼び出された場合、システムはDomain層計算に進む前に (1) `recipe_id`が既知のレシピマスターに実在するか (2) `recipe_id`が`unlocked_recipe_ids`に含まれるか (3) 渡された全`material_instance_ids`が`inventory`に実在するか (4) 投入枠内で`material_instance_ids`が重複していないか、の順で検証し、いずれかを満たさない場合は計算に進まず失敗の`Result`を返さなければならない 🔴 *[(3)(4)はcore-systems.md L162-169「投入検証」で確定済み🔵。(1)(2)のレシピ検証はgarden機能`plant_seed`の`seed_masters`存在確認パターンを踏襲した本ドキュメントでの新規補完]*
  - 関連: US-005, US-006, AC-005, AC-006, AC-009
- **FR-103**: 検証を通過した場合、システムは投入素材配列・`max_slots`（現在の`alchemy_slot_count`）・`selected_recipe_id`から`SlotState`を構築し`SlotState.can_execute()`を実行直前に再評価しなければならない。偽の場合は失敗の`Result`を返さなければならない 🔵 *[core-systems.md L150「can_execute」/ architecture.md「実行直前に必ずDomain層の判定関数を再評価する」]*
  - 関連: US-007, AC-007, AC-008
- **FR-104**: `execute_alchemy`実行時、システムは現在の`traits_unlocked`フラグを`QualityCalculator.calculate_quality`・`TraitActivation.resolve_traits`の両方に同一の値で渡さなければならない 🔵 *[core-systems.md L146, L149 / dataflow.md L104]*
  - 関連: US-012, AC-011
- **FR-105**: 投入素材の品質スコアが算出される場合、システムは投入素材の`quality_score`の平均を四捨五入した値を基礎品質スコアとしなければならない 🔵 *[core-systems.md L146]*
  - 関連: US-001, AC-001
- **FR-106**: `traits_unlocked`が真かつ投入素材中に`trait_tags.has(&"catalyst")`を満たす素材が1つ以上ある場合、システムは四捨五入後の品質スコアに+1し、上限5でクランプしなければならない 🔵 *[core-systems.md L146「2026-08-05修正、PRレビューCritical#6対応」]*
  - 関連: US-002, AC-002
- **FR-107**: `traits_unlocked`が真の場合、システムは投入素材中で同一特性タグの出現数が`GameBalance.TRAIT_ACTIVATION_THRESHOLD`（2個）以上のものだけを発現済みとして`activated_traits`に含めなければならない（1個のみは不発、3個目以降は据え置き） 🔵 *[core-systems.md L149]*
  - 関連: US-003, AC-003
- **FR-108**: 発現した特性が貢献度系（`holy`/`purify`/`heal`）を含む場合、システムはそれぞれの個別倍率（`GameBalance.TRAIT_CONTRIBUTION_BONUS`）を乗算合成した値を貢献度計算にのみ適用しなければならない 🔵 *[core-systems.md L171-177「特性ボーナスの算出」]*
  - 関連: US-004, AC-004
- **FR-109**: 発現した特性が報酬系（`gold`/`glamour`/`rare`）を含む場合、システムはそれぞれの個別倍率（`GameBalance.TRAIT_REWARD_BONUS`）を乗算合成した値を報酬計算にのみ適用しなければならない 🔵 *[core-systems.md L171-177]*
  - 関連: US-004, AC-004
- **FR-110**: 品質・特性発現が確定した場合、システムは`ProductValueCalculator.calculate_contribution(recipe.base_contribution, quality_mult, contribution_bonus)`と`calculate_reward(recipe.base_reward, quality_mult, reward_bonus)`を呼び出し、その結果で`ProductInstance`を生成しなければならない 🔵 *[core-systems.md L151-152]*
  - 関連: US-005, AC-010
- **FR-111**: `ProductInstance`生成時、システムはこの時点の`recipe_id`をそのまま`ProductInstance.recipe_id`にコピーしなければならない 🔵 *[core-systems.md L160「2026-08-10追加、実装レディネス監査#2対応」]*
  - 関連: US-005, AC-010
- **FR-112**: 調合が成功した場合、システムは投入された全`MaterialInstance`を`inventory`から除去し、生成された`ProductInstance`を`pending_products`に追加し、`product_crafted(product: ProductInstance)`シグナルを発行しなければならない 🔴 *[ヒアリング結果スコープ確定事項3。garden機能の`plant_seed`/`harvest`統合パターン踏襲の新規補完]*
  - 関連: US-008, AC-010
- **FR-113**: 検証または実行のいずれかの段階で失敗した場合、システムは`inventory`・`pending_products`を変更してはならず、`execute_alchemy_failed(recipe_id: StringName, error_code: StringName)`シグナルを発行しなければならない 🔴 *[garden機能の`plant_seed_failed`/`harvest_failed`パターン踏襲の新規補完]*
  - 関連: US-006, US-007, US-010, AC-005〜AC-009, AC-015

### 状態駆動要件（WHERE）

- **FR-201**: `traits_unlocked`が偽の状態にある間、システムは`TraitActivation.resolve_traits`が常に空配列を返すようにしなければならない 🔵 *[core-systems.md L149「Gランクの特性封印」]*
  - 関連: US-003, US-012, AC-003, AC-011
- **FR-202**: `traits_unlocked`が偽の状態にある間、システムは`QualityCalculator.calculate_quality`が触媒タグの有無に関わらず品質ボーナスを適用しないようにしなければならない 🔵 *[core-systems.md L146「2026-08-10追加、実装レディネス監査#4対応」]*
  - 関連: US-002, US-012, AC-002, AC-011

### 任意要件（MAY）

- **FR-301**: システムは`GameState`に`load_alchemy_master_data()`のようなAPIを提供し、`res://data/recipes/`から`RecipeMaster`をロードしてもよい 🟡 *[garden機能の`load_garden_master_data()`パターン踏襲]*
  - 関連: US-005, AC-014

### 禁止要件（MUST NOT）

- **FR-401**: `features/alchemy/logic/`配下の関数は副作用（状態変更・I/O・乱数の自己生成）を持ってはならない 🔵 *[architecture.md「Functional Coreに置くもの」/ tdd-implementation.md]*
  - 関連: AC-013
- **FR-402**: `QualityCalculator`・`TraitActivation`・`ProductValueCalculator`は乱数に依存しない設計であり、`logic/`配下で乱数を自己生成してはならない（本システムの計算式に乱数要素はない） 🔵 *[core-systems.md L108-122のメソッド表に乱数引数の記載がない]*
  - 関連: AC-013
- **FR-403**: `GameState.get_state()`は`pending_products`・`inventory`を含む戻り値について、呼び出し元が内部状態を直接改変できる参照をそのまま返してはならない（`duplicate(true)`または`clone()`によるディープコピー必須） 🔵 *[state-management.md「get_state()戻り値の防御的コピー必須」]*
  - 関連: AC-012
- **FR-404**: 本plan内の実装はギルド納品判定（`DeliveryResolver.matches_order`/`resolve`）・ランクノルマ反映・指定合致ボーナスの適用を行ってはならない（GuildSystem/RankSystem側が別plan未実装のため） 🔵 *[ヒアリング結果スコープ確定事項1]*
  - 関連: CON-004
- **FR-405**: 本plan内の実装は`features/alchemy/ui/`（`AlchemyScreen`等）を実装してはならない（別task・別planの対象） 🔵 *[ヒアリング結果スコープ確定事項2]*
  - 関連: CON-009
- **FR-406**: `ProductValueCalculator.calculate_contribution`・`calculate_reward`は指定合致ボーナス（`match_bonus_multiplier`）を引数に取ってはならない（二重乗算バグの再発防止のためGuildSystem.DeliveryResolver側に一本化する） 🔵 *[core-systems.md L154「2026-08-05修正、PRレビューCritical#4対応」]*
  - 関連: US-004, AC-004

## 非機能要件

### パフォーマンス

- **NFR-001**: `GameState.execute_alchemy`の処理は`_process()`を用いず、呼び出し時の同期処理のみで完結しなければならない 🟡 *[performance.md「`_process()`に書くべきでない処理」]*

### セキュリティ

- **NFR-101**: `execute_alchemy`が受け取る`recipe_id`/`material_instance_ids`は、実在するマスターID・現在の`inventory`に存在する`instance_id`のみを正当な入力として扱い、不正な値には失敗の`Result`を返しクラッシュしてはならない 🔵 *[security.md「入力検証」の一般原則 / FR-102]*

### ユーザビリティ

- **NFR-201**: 調合実行の各失敗ケースは、将来のUI実装がトースト表示等に転用できるよう、原因ごとに異なる`error_code`（`unknown_recipe_id`, `recipe_not_unlocked`, `material_not_owned`, `duplicate_material_in_slot`, `slot_execution_invalid`）を返さなければならない 🟡 *[garden機能のerror_code設計パターン踏襲]*

### 保守性・アーキテクチャ整合性

- **NFR-301**: `features/alchemy/`配下の実装は`logic/`・`state/`・`resources/`のディレクトリ構成に従わなければならない（`ui/`は本plan対象外） 🔵 *[.claude/rules/architecture.md]*
- **NFR-302**: 他Featureから調合機能を参照する場合は`features/alchemy/logic/*.gd`および`features/alchemy/resources/*.gd`のみを参照可能とし、`state/`への直接参照を行ってはならない。`ProductInstance`は複数Featureが参照するため`shared/entities/`に配置し、この制約の対象外とする 🔵 *[.claude/rules/architecture.md「公開APIパターン」/ CON-003]*

### テスト容易性

- **NFR-401**: `features/alchemy/logic/`配下の全public `static func`は、正常系・異常系・境界値のテストをGdUnit4で最低1本ずつ持たなければならない 🔵 *[.claude/rules/testing.md「カバレッジ目標」]*
- **NFR-402**: テストファイルは`tests/unit/features/alchemy/`または`tests/integration/`に配置しなければならない（`features/alchemy/`配下への配置は禁止） 🔵 *[.claude/rules/architecture.md「テストファイル配置」]*

## 制約

- **CON-001**: 実装言語はGDScript、対象エンジンはGodot 4.xとする 🔵 *[CLAUDE.md]*
- **CON-002**: テストフレームワークはGdUnit4を使用し、`tests/unit/features/alchemy/`・`tests/integration/`に配置する 🔵 *[.claude/rules/testing.md]*
- **CON-003**: `ProductInstance`は`features/alchemy/state/`ではなく`shared/entities/product_instance.gd`に配置する。理由: `core-systems.md`のクラス図では配置未確定（「要検討」とヒアリングで明示）だが、後続のguild planで`DeliveryResolver.resolve(product: ProductInstance, ...)`が型として直接参照する必要があり、architecture.mdの「他Featureのstate/を直接参照しない」制約を満たすには`state/`に置けない 🔴 *[ヒアリング結果「要検討」を本ドキュメントで解決。`MaterialInstance`の`shared/entities/`配置（garden CON-003）と同型の判断]*
- **CON-004**: 本plan完了時点で`autoload/game_state.gd`は`execute_alchemy`を追加するが、ギルド納品（`DeliveryResolver`呼び出し・`daily_order`合致判定・ランクノルマ反映）は行わない。`pending_products`は後続のguild planがそのまま消費できるインターフェース契約とする 🔵 *[ヒアリング結果スコープ確定事項1・3]*
- **CON-005**: `shared/loaders/master_data_loader.gd`は現状スタブであるため、本plan内のGdUnit4テストは`RecipeMaster`のテスト用フィクスチャ（`tests/mocks/`等）を個別に用意しなければならない 🟡 *[garden plan CON-005と同一事情]*
- **CON-006**: 調合関連のバランス数値（品質倍率テーブル・特性ボーナス倍率6種・触媒基準品質・投入枠初期値）はFR-005記載の具体値をそのまま`GameBalance`定数として採用し、コード上に🟡TBD/🔴新規補完である旨をコメントで明記する 🔵 *[ヒアリング結果「バランス数値の扱い」]*
- **CON-007**: `traits_unlocked`の本来の実行時権威は`RankMaster.traits_unlocked`だが、RankSystemが別plan未実装のため、`GameState`は内部フィールド`_traits_unlocked: bool`で暫定的に保持する。デフォルト値は`false`（ゲーム開始時のGランクを想定した仮決め）とし、`_set_traits_unlocked_for_test()`のようなテスト専用APIで上書き可能にする 🔴 *[data-schema.md L198のGランク`traits_unlocked: false`例に基づく本ドキュメントでの新規補完。garden plan CON-004の`_garden_slot_count`パターンと同型]*
- **CON-008**: `RecipeMaster`の初期解禁レシピフィクスチャは`data-schema.md` L152-158のJSON例（`id: "recipe_healing_potion", name: "回復薬", base_contribution: 10.0, base_reward: 5.0`）をそのまま採用し、`GameBalance.INITIAL_RECIPE_ID`の指す先とする 🔵 *[data-schema.md L152-158の既存サンプル値を流用]*
- **CON-009**: `execute_alchemy`のシグネチャは`(recipe_id: StringName, material_instance_ids: Array[String]) -> Result`の単一アトミック呼び出しとする。`SlotState`への逐次的な素材追加・削除（`insert_material`/`remove_material`等、UIのライブプレビュー用途）は本plan外とする 🔴 *[dataflow.md L78の`execute_alchemy(selected_recipe_id, slot_materials)`シグネチャは確定だが、UIが逐次構築する`SlotState`のプレビューAPIまでは本plan（UI対象外）のスコープに含めないという設計判断]*
- **CON-010**: 特性タグの`StringName`は以下で命名する: 聖=`&"holy"`・金=`&"gold"`はdata-schema.mdの既存サンプルに準拠、浄=`&"purify"`・癒=`&"heal"`・華=`&"glamour"`・稀=`&"rare"`は既存文書に例がなく本ドキュメントで新規命名する 🔴 *[data-schema.md L112, L177の`holy`/`gold`サンプルを踏襲。残り4タグの命名は本ドキュメントでの新規補完のため要確認]*

## 信頼性レベルサマリー

- 🔵 青信号: 33件（FR 23件 + NFR 5件 + CON 5件）
- 🟡 黄信号: 4件（FR 1件: FR-301 / NFR 2件: NFR-001, NFR-201 / CON 1件: CON-005）
- 🔴 赤信号: 10件（FR 6件: FR-003, FR-005, FR-008, FR-102, FR-112, FR-113 / CON 4件: CON-003, CON-007, CON-009, CON-010）
- 合計: 47件（FR 30件 + NFR 7件 + CON 10件）
