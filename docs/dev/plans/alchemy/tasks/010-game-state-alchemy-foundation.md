---
id: "010"
title: "GameStateに調合関連フィールド・マスターデータロード・テストAPIを追加する"
status: pending
priority: 3
dependencies: ["001", "002", "003", "004", "009"]
estimated_complexity: medium
---

# Task: GameStateに調合関連フィールド・マスターデータロード・テストAPIを追加する

## Goal

`autoload/game_state.gd`に調合関連のランタイムフィールド（レシピマスター・解禁レシピ一覧・未納品キュー・投入枠数・特性解禁フラグ）、signal宣言、`load_alchemy_master_data()`、`get_state()`/`reset_for_test()`の拡張、テスト専用APIを追加する。`execute_alchemy`本体（タスク011）の前提となる基盤のみを対象とし、`execute_alchemy`自体は実装しない。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルへの追記）

signal product_crafted(product: ProductInstance)  # 🔵 FR-112
signal execute_alchemy_failed(recipe_id: StringName, error_code: StringName)  # 🔴 garden の plant_seed_failed/harvest_failed パターン踏襲（FR-113）

# --- 調合（alchemy）関連フィールド ---
var _recipe_masters: Dictionary = {}  # 🔵 Dictionary[StringName, RecipeMaster]（_seed_masters等と同型）
var _unlocked_recipe_ids: Array[StringName] = [GameBalance.INITIAL_RECIPE_ID]  # 🔵 FR-007
var _pending_products: Array[ProductInstance] = []  # 🔴 FR-008
var _alchemy_slot_count: int = GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT  # 🔵 FR-006の暫定置き場（_garden_slot_countと同型）
var _traits_unlocked: bool = false  # 🔴 CON-007。RankMaster未実装のための暫定フィールド

## res://data/recipes/ からRecipeMasterをロードし_recipe_mastersに格納する（FR-301、MAY要件）
func load_alchemy_master_data() -> void:
	...

## テスト専用。実.tresロードを介さずRecipeMasterを直接注入する
func _set_recipe_masters_for_test(masters: Dictionary) -> void:
	...

## テスト専用。unlocked_recipe_idsを直接注入する（AC-009検証用）
func _set_unlocked_recipe_ids_for_test(ids: Array[StringName]) -> void:
	...

## テスト専用。alchemy_slot_countを直接注入する（AC-007境界値検証用）
func _set_alchemy_slot_count_for_test(count: int) -> void:
	...

## テスト専用。traits_unlockedを直接注入する（AC-011検証用）
func _set_traits_unlocked_for_test(value: bool) -> void:
	...

## テスト専用。execute_alchemy()を経由せずinventoryへ素材を直接注入する
func _inject_material_for_test(material: MaterialInstance) -> void:
	...
```

> 信号機: 🔵 `_recipe_masters`/`_unlocked_recipe_ids`/`load_alchemy_master_data`は既存`_seed_masters`/`load_garden_master_data`と同型。🔴 `_pending_products`/`_traits_unlocked`/`execute_alchemy_failed`/テスト専用API群は本plan・garden実装パターン踏襲の新規補完

## Test Strategy

- [ ] 正常系: `reset_for_test()`実行後、`_recipe_masters`が空、`_unlocked_recipe_ids`が`[GameBalance.INITIAL_RECIPE_ID]`、`_pending_products`が空、`_alchemy_slot_count`が`GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT`、`_traits_unlocked`が`false`になっている
- [ ] 正常系: `load_alchemy_master_data()`実行後、`get_state()`が返す状態から`recipe_healing_potion`（タスク008フィクスチャ）が解決できる状態になっている（`_set_recipe_masters_for_test`で注入したものと同様に扱えることを確認する形でも可）
- [ ] 正常系: `get_state()`が`pending_products`・`unlocked_recipe_ids`をキーとして含む
- [ ] エッジケース: `get_state()`の戻り値の`pending_products`（Array）に`append`しても`GameState`内部の`_pending_products`は変化しない（防御的コピー、FR-403/AC-012）
- [ ] エッジケース: `_set_recipe_masters_for_test`等のテスト専用APIで注入した内容が、以降の（本タスクで検証可能な範囲の）状態取得に反映される
- [ ] 正常系: `_inject_material_for_test(material)`実行後、`get_state().inventory`に該当`material`が含まれる

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`_seed_masters`/`load_garden_master_data()`/`get_state()`/`reset_for_test()`/`_set_masters_for_test()`/`_inject_plant_for_test()`（全メソッドが本タスクの直接のテンプレート）
- 実装のヒント: テスト専用APIは既存の`_set_masters_for_test`と同じ二重ガード（`assert(OS.is_debug_build(), ...)` + `if not OS.is_debug_build(): push_error(...); return`）を必ず踏襲する
- 注意事項: `get_state()`の`pending_products`は`ProductInstance.clone()`でディープコピーした配列を返す（`_inventory`→`cloned_inventory`と同じパターン）。`Array.map()`は型付き配列を返さないため、既存コードのコメントにある通り明示的な型付き配列構築（`for`ループ+`append`）を使う

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_alchemy_foundation.gd`
