# workshop 要件定義書

## 概要

「Atelier」（Godot 4.x + GDScript）の Phase 2 機能実装として、`WorkshopSystem`（工房強化・ショップ）のDomain層基盤と`GameState`統合を実装する。ゴールドで恒久投資（投入枠+1／庭拡張／レシピ解禁、ランク間限定・任意購入）と消耗投資（触媒常備／種の指名買い、ターン中いつでも購入可）を行う購入判定・購入適用ロジックを対象とする。`atelier/features/workshop/`（現状 `logic/`/`resources/`/`state/`/`ui/` すべて空スタブ）に実装する。既存の`rank`→`rank-up`の2段階プラン（Domain基盤plan → GameState統合plan）と同様、本planはDomain層基盤とGameState統合を一体で扱う。

本要件は`docs/design/atelier-alchemy-core/core-systems.md`「WorkshopSystem（工房強化・ショップ）詳細設計」節（L222-270）・`docs/design/atelier-alchemy-core/data-schema.md`「UpgradeMaster」節（L218-240）・`docs/spec/atelier-alchemy-core/requirements.md` §3「工房強化・ショップ」・§4「ショップ／工房強化」（L85-88, L170-175）・ユーザーヒアリング結果に既に定義された契約をEARS形式に翻訳したものである。矛盾がある場合は既存設計文書とヒアリング結果を正とするが、両者が食い違う箇所（触媒のquality_score算出方法）は本文書中に明記し、ヒアリング結果を優先する。

### スコープ境界（ユーザーヒアリングで確定済み）

**含む**:
- `features/workshop/logic/purchase_validator.gd`（`PurchaseValidator`: `can_purchase`・`is_permanent_upgrade`）
- `features/workshop/resources/upgrade_master.gd`（`UpgradeMaster`: id/name/is_permanent/price/effect_type/effect_value/max_purchase_count）
- `autoload/game_state.gd`統合: `GameState.apply_upgrade(upgrade: UpgradeMaster) -> Result`（ゴールド減算・effect_type別の状態反映・購入可否の実行直前再検証）、`GameState.close_workshop()`
- `res://data/upgrades/`配下への5件のUpgradeMaster `.tres`新規作成
- レシピ解禁対象として`res://data/recipes/`への第2の`RecipeMaster` `.tres`新規作成
- 触媒常備対象として`res://data/materials/`への専用`MaterialMaster`（`material_catalyst`）`.tres`新規作成（ユーザーヒアリングで確定。data-schema.md記載の`shop_purchasable=true`/`shop_base_quality=3`パターンに従う。CON-008参照）
- `MasterDataLoader`への`&"upgrades"`カテゴリ対応追加
- `GameBalance`への本plan向け定数（価格・`max_purchase_count`・`effect_value`等）新規追加
- `GameState.get_state()`への`can_purchase_permanent`・購入済み回数クエリの追加（本plan外UI実装向けの先行公開。ユーザーヒアリングで確定）

**含まない（本plan外）**:
- `features/workshop/ui/workshop_screen.gd`/`.tscn`（`WorkshopScreen`）等UI一式
- `_current_phase`への`&"workshop"`追加およびフェーズ遷移テーブルの本格導入
- 価格・`max_purchase_count`等の最終バランス調整（後日`balance-tuning-cycle`スキルで再調整する前提）
- セーブ/ロード機能（現行スコープ外、`CLAUDE.md`参照）

## 関連文書

- **ユーザーストーリー**: [user-stories.md](user-stories.md)
- **受入基準**: [acceptance-criteria.md](acceptance-criteria.md)
- **設計・タスク**: plan.md（未作成、後続フェーズで生成）
- **既存設計資産**: [`core-systems.md`](../../../design/atelier-alchemy-core/core-systems.md) WorkshopSystem節（L222-270） / [`data-schema.md`](../../../design/atelier-alchemy-core/data-schema.md) UpgradeMaster節（L218-240） / [`requirements.md`](../../../spec/atelier-alchemy-core/requirements.md) §3・§4
- **先行plan**: [`rank-up/requirements.md`](../rank-up/requirements.md)（`GameState`の`_commit_exam_success()`成功パスの契約） / [`alchemy/requirements.md`](../alchemy/requirements.md)（`_alchemy_slot_count`・`_unlocked_recipe_ids`・`execute_alchemy()`の契約） / [`garden/requirements.md`](../garden/requirements.md)（`_garden_slot_count`・`_seed_inventory`・`_inventory`・`MaterialInstance`の契約）

## 用語集

| 用語 | 定義 |
|-----|------|
| `WorkshopSystem` | 工房強化・ショップの購入可否判定と適用を担うシステム全体の呼称（設計文書上の分類名。実装クラスは`PurchaseValidator`と`GameState.apply_upgrade()`に分かれる） |
| 恒久投資 | 投入枠+1／庭拡張／レシピ解禁。ランクをまたいで残る効果で、ランク間の工房強化画面（`_can_purchase_permanent == true`の期間）でのみ購入可能 |
| 消耗投資 | 触媒常備／種の指名買い。その場で消費される効果で、ターン中いつでも購入可能 |
| `PurchaseValidator` | 購入可否判定を担うDomain層の静的クラス（副作用なし）。`can_purchase`・`is_permanent_upgrade`の2つのpublic `static func`を持つ |
| `UpgradeMaster` | 工房強化・ショップの購入対象マスターデータ型。`id`・`name`・`is_permanent`・`price`・`effect_type`・`effect_value`・`max_purchase_count`の7フィールドを持つ |
| `effect_type` | `UpgradeMaster`が持つ効果種別。`alchemy_slot_increase`/`garden_slot_increase`/`recipe_unlock`/`catalyst_stock`/`seed_name_purchase`の5種類 |
| `effect_value` | `effect_type`に応じた効果量またはID（`Variant`）。増加量（int）または対象マスターデータのid（String/StringName） |
| `_can_purchase_permanent` | `GameState`が保持する、恒久投資の購入可否を制御する新規フラグ。デフォルト`false`。昇格試験成功時に`true`、`close_workshop()`で`false`に戻る |
| `close_workshop()` | 工房強化画面を閉じる操作に対応する新規`GameState`メソッド。`_can_purchase_permanent`を`false`へ戻す |
| `_purchased_upgrade_counts` | `GameState`が保持する、`UpgradeMaster.id`ごとの購入済み回数を記録する新規`Dictionary[StringName, int]`。`PurchaseValidator.can_purchase`の`already_purchased_count`引数の実データ源として本planで新規補完する |
| `apply_upgrade()` | `GameState.apply_upgrade(upgrade: UpgradeMaster) -> Result`。購入可否の実行直前再検証・ゴールド減算・`effect_type`別の状態反映を一手に担うApplication層メソッド |
| `MasterDataLoader` | `res://data/`配下の`.tres`をカテゴリ別にロードする既存の静的クラス（`shared/loaders/master_data_loader.gd`）。本planで`&"upgrades"`カテゴリ対応を追加する |
| `GameBalance` | ゲームバランス定数を集約する既存の静的クラス（`shared/constants/game_balance.gd`） |
| `Result` | `shared/entities/result.gd`。`success: bool, value: Variant, error_code: StringName`と`Result.ok()`/`Result.fail()` |
| `GameState` | Application層Autoload。購入状態の唯一の保持者・状態変更者・仲介者（既存planと同一原則） |

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 PRD・設計文書・ヒアリングに基づく確実な要件
- 🟡 妥当な推測による要件
- 🔴 AI推論補完による要件（要確認）

### 普遍要件（SHALL）

- **FR-001**: `PurchaseValidator.can_purchase(gold: int, price: int, already_purchased_count: int, max_purchase_count: int) -> bool`は、`gold >= price and already_purchased_count < max_purchase_count`を返さなければならない 🔵 *[core-systems.md L252]*
  - 関連: US-201, US-202, AC-001
- **FR-002**: `PurchaseValidator.is_permanent_upgrade(upgrade: UpgradeMaster) -> bool`は`upgrade.is_permanent`を返さなければならない 🔵 *[core-systems.md L253, data-schema.md L236]*
  - 関連: US-004, AC-002
- **FR-003**: システムは`PurchaseValidator`を`features/workshop/logic/purchase_validator.gd`配下に、副作用を持たない`static func`（`Node`非継承）の集合として実装しなければならない 🔵 *[core-systems.md L230-236 クラス図`<<static>>`, architecture.md Functional Core原則]*
  - 関連: US-201, AC-001, AC-002
- **FR-004**: システムは`UpgradeMaster`を`features/workshop/resources/upgrade_master.gd`に`Resource`継承のマスターデータ型として、`id: StringName`・`name: String`・`is_permanent: bool`・`price: int`・`effect_type: StringName`・`effect_value: Variant`・`max_purchase_count: int`の7フィールドを持たせて定義しなければならない 🔵 *[data-schema.md L218-240]*
  - 関連: US-301, AC-015
- **FR-005**: システムは`MasterDataLoader`に`&"upgrades"`カテゴリの読み込み対応を追加し、`res://data/upgrades/`配下の`.tres`を`UpgradeMaster`型として読み込まなければならない（既存`&"recipes"`カテゴリの実装パターンを踏襲する） 🔵 *[ヒアリング結果 実装範囲2、既存master_data_loader.gd `_resolve_dir_path`/`_is_allowed_type`パターン]*
  - 関連: US-301, AC-015
- **FR-006**: システムは`res://data/upgrades/`に5件の`UpgradeMaster` `.tres`（投入枠+1／庭拡張／レシピ解禁／触媒常備／種の指名買い）を新規作成しなければならない 🔵 *[ヒアリング結果 実装範囲2]*
  - 関連: US-301, AC-015
- **FR-007**: システムはレシピ解禁対象として、`res://data/recipes/`に既存`recipe_healing_potion`以外の第2の`RecipeMaster` `.tres`を新規作成しなければならない（数値は`GameBalance`等の既存パターンに倣った仮値でよい） 🔵 *[ヒアリング結果 実装範囲2「レシピ解禁の対象レシピ問題」]*
  - 関連: US-302, AC-016
- **FR-008**: システムは`GameBalance`に本plan向けの価格・`max_purchase_count`・`effect_value`相当の定数を新規追加しなければならない。価格序列は「投入枠+1 ≫ 庭拡張≒レシピ解禁 ＞ 触媒 ＞ 種の指名買い」に従う 🟡 *[ヒアリング結果 実装範囲4、requirements.md §4「ショップ／工房強化」]*
  - 関連: US-001, US-002, US-003, US-101, US-102
- **FR-009**: システムは`GameState._can_purchase_permanent: bool`（デフォルト`false`）フィールドを新規追加しなければならない 🔵 *[ヒアリング結果 実装範囲3]*
  - 関連: US-004, AC-004
- **FR-010**: システムは`GameState._purchased_upgrade_counts: Dictionary[StringName, int]`（キー=`UpgradeMaster.id`、値=購入回数、デフォルト空`Dictionary`）を新規追加し、`PurchaseValidator.can_purchase`の`already_purchased_count`引数の実データ源としなければならない 🔵 *[ユーザー確認済み。既存`_seed_inventory`の`{seed_id, count}`と同型パターンとして採用を決定]*
  - 関連: US-202, AC-013
- **FR-016**: システムは`res://data/materials/`に専用`MaterialMaster` `.tres`（`id: &"material_catalyst"`, `shop_purchasable: true`, `shop_base_quality: 3`）を新規作成しなければならない 🔵 *[ユーザー確認済み。data-schema.md L131-137のMaterialMaster例に沿った専用IDを採用]*
  - 関連: US-101, AC-011
- **FR-017**: システムは`GameState.get_state()`に`can_purchase_permanent: bool`フィールドを含めなければならない 🔵 *[ユーザー確認済み。本plan外のUI実装が読み取れる状態にしておく]*
  - 関連: -
- **FR-018**: システムは指定`upgrade.id`の購入済み回数を取得するクエリメソッド`GameState.get_purchased_count(upgrade_id: StringName) -> int`を提供しなければならない 🔵 *[ユーザー確認済み]*
  - 関連: -
- **FR-011**: システムは`GameState._upgrade_masters: Dictionary`（キー=`StringName` id、値=`UpgradeMaster`）フィールドと、`MasterDataLoader.load_all(&"upgrades")`からロードする`load_workshop_master_data()`メソッドを新規追加しなければならない（既存`load_alchemy_master_data()`と同型パターン） 🟡 *[既存load_garden_master_data()/load_alchemy_master_data()パターンからの推定]*
  - 関連: US-301, AC-015
- **FR-012**: システムは`_can_purchase_permanent`に対し、`GameStateTestSupport`経由のテスト専用API`_set_can_purchase_permanent_for_test()`を提供しなければならない 🔵 *[state-management.mdテスト専用APIパターン, ヒアリング結果「既存コードベースの前提」]*
  - 関連: US-201, AC-017
- **FR-013**: システムは`_purchased_upgrade_counts`に対し、`GameStateTestSupport`経由のテスト専用API`_set_purchased_upgrade_counts_for_test()`を提供しなければならない 🔵 *[FR-010と同型。ユーザー確認済み]*
  - 関連: US-202, AC-013, AC-017
- **FR-014**: `reset_for_test()`は`_can_purchase_permanent`を`false`へ、`_purchased_upgrade_counts`を空`Dictionary`へ、`_upgrade_masters`を空`Dictionary`へそれぞれ初期化しなければならない 🔵 *[既存reset_for_test()パターン踏襲。ユーザー確認済み]*
  - 関連: AC-017
- **FR-015**: システムは`GameState.close_workshop() -> void`メソッドを新規追加しなければならない 🔵 *[ヒアリング結果 実装範囲3]*
  - 関連: US-004, AC-005

### イベント駆動要件（WHEN-THEN）

- **FR-101**: `GameState.apply_upgrade(upgrade)`が呼び出された場合、システムは`PurchaseValidator.can_purchase`を最新の`_gold`・`_purchased_upgrade_counts`の値で再評価してから状態を変更しなければならない 🔵 *[core-systems.md L255, architecture.md「検証責務のレイヤー配置原則」, ヒアリング結果 実装範囲3]*
  - 関連: US-201, AC-003, AC-014
- **FR-102**: `PurchaseValidator.can_purchase`の再評価が`false`を返した場合、`GameState.apply_upgrade()`はいかなる状態（`_gold`・`_inventory`・`_alchemy_slot_count`・`_garden_slot_count`・`_unlocked_recipe_ids`・`_seed_inventory`・`_purchased_upgrade_counts`）も変更せず`Result.fail()`を返さなければならない 🔵 *[core-systems.md L255, execute_alchemy()の失敗時無変更パターン踏襲]*
  - 関連: US-201, AC-003, AC-013, AC-014
- **FR-103**: `upgrade.is_permanent == true`かつ`_can_purchase_permanent == false`の場合、`GameState.apply_upgrade()`は購入を拒否し`Result.fail()`を返さなければならない 🔵 *[ヒアリング結果 実装範囲3]*
  - 関連: US-004, AC-004
- **FR-104**: FR-101〜FR-103の検証を通過した場合、`GameState.apply_upgrade()`は`upgrade.price`を`_gold`から減算し、`gold_changed(previous_amount, new_amount, delta)`シグナルを発行しなければならない 🔵 *[既存`gold_changed`パターン踏襲（`deliver_pending_products()`と同様、状態変更後・シグナル発行前に確定させる）]*
  - 関連: US-001, US-101, AC-007
- **FR-105**: `upgrade.effect_type == &"alchemy_slot_increase"`の場合、`GameState.apply_upgrade()`は`_alchemy_slot_count`を`effect_value`（int）分だけ加算しなければならない 🔵 *[core-systems.md L263]*
  - 関連: US-001, AC-008
- **FR-106**: `upgrade.effect_type == &"garden_slot_increase"`の場合、`GameState.apply_upgrade()`は`_garden_slot_count`を`effect_value`（int）分だけ加算しなければならない 🔵 *[core-systems.md L264]*
  - 関連: US-002, AC-009
- **FR-107**: `upgrade.effect_type == &"recipe_unlock"`の場合、`GameState.apply_upgrade()`は`effect_value`（対象`RecipeMaster.id`、String/StringName）を`_unlocked_recipe_ids`へ`append`しなければならない 🔵 *[core-systems.md L265]*
  - 関連: US-003, AC-010
- **FR-108**: `upgrade.effect_type == &"catalyst_stock"`の場合、`GameState.apply_upgrade()`は`material_id = &"material_catalyst"`（FR-016）・`trait_tags = [&"catalyst"]`・`quality_score = GameBalance.CATALYST_BASE_QUALITY_SCORE`を持つ新規`MaterialInstance`を生成し`_inventory`へ追加しなければならない 🔵 *[ヒアリング結果「既存コードベースの前提」。CON-010に記載の通りcore-systems.md記載（`MaterialMaster.shop_base_quality`使用）とは異なるが、ヒアリングでの明示決定を優先する]*
  - 関連: US-101, AC-011
- **FR-109**: `upgrade.effect_type == &"seed_name_purchase"`の場合、`GameState.apply_upgrade()`は`effect_value`（対象`SeedMaster.id`）に対応する`_seed_inventory`エントリの`count`を+1し、存在しなければ`count: 1`で新規追加しなければならない（既存`_find_seed_inventory_index()`ヘルパーを再利用する） 🔵 *[core-systems.md L267, ヒアリング結果「既存コードベースの前提」]*
  - 関連: US-102, AC-012
- **FR-110**: 昇格試験が成功した場合（既存`_commit_exam_success()`の成功パス内）、システムは`_can_purchase_permanent`を`true`へ設定しなければならない 🔵 *[ヒアリング結果 実装範囲3]*
  - 関連: US-004, AC-005
- **FR-111**: `close_workshop()`が呼び出された場合、システムは`_can_purchase_permanent`を`false`へ戻さなければならない 🔵 *[ヒアリング結果 実装範囲3]*
  - 関連: US-004, AC-005
- **FR-112**: `apply_upgrade(upgrade)`に`null`が渡された場合、システムはいかなる状態も変更せず`Result.fail(&"invalid_upgrade")`を返さなければならない 🟡 *[ヒアリングに明示なし。execute_alchemy()の`_validate_alchemy_request`型の防御的検証パターン・既存エラーコード命名規則からの妥当な推測]*
  - 関連: AC-018
- **FR-113**: `apply_upgrade()`が成功した場合、システムは`_purchased_upgrade_counts[upgrade.id]`を+1しなければならない（キーが未登録の場合は0から開始して+1する） 🔵 *[FR-010と同型。ユーザー確認済み]*
  - 関連: US-202, AC-013
- **FR-114**: `apply_upgrade()`の検証・状態反映がすべて成功した場合、システムは`Result.ok(upgrade)`を返さなければならない 🟡 *[既存execute_alchemy()のResult.ok(product)パターンから推定]*
  - 関連: US-001, AC-007
- **FR-115**: `MasterDataLoader.load_all(&"upgrades")`が呼び出された場合、システムは`res://data/upgrades/`配下の`.tres`を`UpgradeMaster`の`Array`として返さなければならない 🔵 *[既存load_all()の&"recipes"実装パターン踏襲]*
  - 関連: US-301, AC-015

### 状態駆動要件（WHERE）

- **FR-201**: `_can_purchase_permanent`が`false`である間、システムは恒久投資（`is_permanent == true`）のいかなる購入要求も拒否しなければならない 🔵 *[ヒアリング結果 実装範囲3]*
  - 関連: US-004, AC-004
- **FR-202**: `_can_purchase_permanent`が`true`である間、システムは恒久投資の購入要求を`PurchaseValidator.can_purchase`の判定に従って許可しなければならない 🔵 *[ヒアリング結果 実装範囲3]*
  - 関連: US-001, US-002, US-003, AC-004
- **FR-203**: `upgrade.is_permanent`が`false`（消耗投資）である間、システムは`_can_purchase_permanent`の値に関わらず購入要求を`PurchaseValidator.can_purchase`の判定に従って許可しなければならない 🔵 *[ヒアリング結果 実装範囲3「消耗投資はフラグに関わらず常時購入可能」]*
  - 関連: US-101, US-102, AC-006

### 任意要件（MAY）

該当なし。当初FR-301/FR-302として提案していた`get_state().can_purchase_permanent`公開・購入回数クエリメソッドは、ユーザーヒアリングで「含める」と確定したため、普遍要件FR-017・FR-018へ格上げ済み。

### 禁止要件（MUST NOT）

- **FR-401**: `GameState.apply_upgrade()`は、検証（FR-101〜FR-103）に失敗した場合、いかなる内部状態（`_gold`・`_inventory`・`_alchemy_slot_count`・`_garden_slot_count`・`_unlocked_recipe_ids`・`_seed_inventory`・`_purchased_upgrade_counts`）も変更してはならない 🔵 *[FR-102と対をなす禁止要件、execute_alchemy()のアトミック性パターン踏襲]*
  - 関連: AC-003, AC-013, AC-014
- **FR-402**: `GameState.apply_upgrade()`は、UI層が示した購入可否判定結果を信頼して状態を変更してはならない。状態変更の実行直前に必ず`PurchaseValidator.can_purchase`を再評価しなければならない 🔵 *[architecture.md「検証責務のレイヤー配置原則」, ヒアリング結果 実装範囲3]*
  - 関連: AC-003, AC-014
- **FR-403**: `PurchaseValidator`は`GameState`等Application層・UI層を参照してはならない（Functional Core原則） 🔵 *[architecture.mdレイヤー間依存ルール]*
  - 関連: AC-001, AC-002
- **FR-404**: `MasterDataLoader.load_all(&"upgrades")`は、`res://data/upgrades/`配下に他カテゴリのリソースが混在していても`UpgradeMaster`以外を結果に含めてはならない 🔵 *[既存`_is_allowed_type`パターン踏襲]*
  - 関連: AC-015

## 非機能要件

### パフォーマンス

- **NFR-001**: `apply_upgrade()`の検証・状態反映は、`_seed_inventory`の線形探索（通常数件〜数十件程度）を含めてもフレーム内で同期完結し、体感遅延を生じさせてはならない 🟡 *[既存execute_alchemy()/harvest()と同水準の計算量を前提とした推定]*

### セキュリティ（データ整合性）

- **NFR-101**: `GameState.apply_upgrade()`は、UI層の事前判定結果を信頼せず、実行直前に必ず`PurchaseValidator.can_purchase`を再評価しなければならない（FR-402と同一の原則をNFRとしても明記） 🔵 *[architecture.md「検証責務のレイヤー配置原則」]*
- **NFR-102**: `GameState.get_state()`は、新規追加する内部`Dictionary`/`Array`フィールド（`_purchased_upgrade_counts`等）についても既存の防御的コピー原則（`duplicate(true)`）を適用し、呼び出し元に内部データの直接参照を渡してはならない 🔵 *[state-management.md「get_state()戻り値の防御的コピー必須」]*

### ユーザビリティ・保守性

- **NFR-201**: `PurchaseValidator`・`UpgradeMaster`はFeature-Based Architecture・Functional Core原則に従い実装し、他Featureの`state/`・`ui/`を直接参照してはならない 🔵 *[architecture.md]*
- **NFR-202**: `game_state.gd`が500行ルール（`.claude/rules/coding-style.md`）に抵触する場合、既存の`GameStateTestSupport`委譲パターンを踏襲してテスト専用APIを分離しなければならない 🟡 *[rank-up planの前例踏襲]*

## 制約

- **CON-001**: `PurchaseValidator`は`features/workshop/logic/`に副作用のない`static func`として実装しなければならない（Functional Core原則） 🔵 *[architecture.md]*
- **CON-002**: `UpgradeMaster`は`features/workshop/resources/`に`Resource`継承のマスターデータ型として実装しなければならない 🔵 *[architecture.md]*
- **CON-003**: `apply_upgrade()`は`GameState`（Application層）にのみ実装し、Domain層システム同士（workshopの`logic/`とalchemy/gardenの`logic/`等）を直接参照させてはならない。状態反映先（`_alchemy_slot_count`等）へのアクセスはすべて`GameState`内で完結させる 🔵 *[architecture.mdレイヤー間依存ルール]*
- **CON-004**: `WorkshopScreen`等UI層（`features/workshop/ui/`）の実装は本planのスコープ外とする 🔵 *[ヒアリング結果]*
- **CON-005**: `_current_phase`への`&"workshop"`追加およびフェーズ遷移テーブルの本格導入は本planのスコープ外とする 🔵 *[ヒアリング結果]*
- **CON-006**: 価格・`max_purchase_count`等の数値（FR-008）は仮値（🟡TBD）であり、後日`balance-tuning-cycle`スキルによる再調整を前提とする 🟡 *[ヒアリング結果 除外事項]*
- **CON-007**: セーブ/ロード機能は現行スコープ外のため、本planでの永続化対応は行わない 🔵 *[CLAUDE.md]*
- **CON-008**: `catalyst_stock`購入で生成する`MaterialInstance`の`material_id`は、専用`MaterialMaster`（`material_catalyst`、FR-016で新規作成）の`id`を使用する（ユーザー確認済み。既存`material_herb`等の流用は行わない） 🔵 *[ユーザーヒアリングで確定]*
- **CON-009**: 恒久投資の購入回数トラッキング（`PurchaseValidator.can_purchase`の`already_purchased_count`引数の実データ源）は`GameState._purchased_upgrade_counts`（`Dictionary[StringName, int]`、既存`_seed_inventory`と同型パターン）として新規追加する（ユーザー確認済み） 🔵 *[FR-010/FR-013と対応]*
- **CON-010**: 既存`GameBalance.CATALYST_BASE_QUALITY_SCORE`を`catalyst_stock`購入時の`quality_score`として使用する方針（FR-108）は、`core-systems.md`の記載（`MaterialMaster.shop_base_quality`使用）と異なるが、ユーザーヒアリングでの明示決定（「本plan内では未消費でWorkshopSystem側で参照する前方定義」というコメント付きで既に用意されていたフィールドを実消費する）を優先する 🔵 *[ヒアリング結果 実装範囲4、design文書との差異は本文書中に明記済み]*

## 信頼性レベルサマリー

- 🔵 青信号: 48件
- 🟡 黄信号: 7件
- 🔴 赤信号: 0件（ユーザーヒアリングで全て解消済み）
