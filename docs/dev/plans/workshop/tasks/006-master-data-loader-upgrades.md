---
id: "006"
title: "MasterDataLoaderにupgradesカテゴリを追加し5件のUpgradeMasterを新規作成する"
status: pending
priority: 2
dependencies: ["001", "002", "004"]
estimated_complexity: medium
---

# Task: MasterDataLoaderにupgradesカテゴリを追加し5件のUpgradeMasterを新規作成する

## Goal

`MasterDataLoader`に`&"upgrades"`カテゴリの読み込み対応を追加し（FR-005, FR-115, FR-404）、`res://data/upgrades/`に5件の`UpgradeMaster` `.tres`（投入枠+1／庭拡張／レシピ解禁／触媒常備／種の指名買い）を新規作成する（FR-006）。

## Interfaces

```gdscript
# atelier/shared/loaders/master_data_loader.gd への変更差分

const UPGRADES_DIR := "res://data/upgrades/"  # 🔵 FR-005。追加定数

static func _resolve_dir_path(category: StringName) -> String:
	match category:
		&"materials":
			return MATERIALS_DIR
		&"recipes":
			return RECIPES_DIR
		&"upgrades":  # 🔵 FR-005。追加分岐
			return UPGRADES_DIR
		_:
			return ""

static func _is_allowed_type(category: StringName, resource: Resource) -> bool:
	match category:
		&"materials":
			return resource is SeedMaster or resource is MaterialMaster
		&"recipes":
			return resource is RecipeMaster
		&"upgrades":  # 🔵 FR-005, FR-404
			return resource is UpgradeMaster
		_:
			return false
```

`load_all()`本体・`validate_references()`は無変更（`&"upgrades"`は`SeedMaster.produces_material_id`のクロス参照検証対象外、Plan設計フェーズで確認済み）。

5件の`.tres`（`GameBalance`定数はタスク002で追加済みの値を使用）:

```
# atelier/data/upgrades/upgrade_alchemy_slot.tres
id = &"upgrade_alchemy_slot", name = "投入枠+1", is_permanent = true
price = GameBalance.WORKSHOP_ALCHEMY_SLOT_PRICE相当の値(2000)
effect_type = &"alchemy_slot_increase", effect_value = 1
max_purchase_count = 1

# atelier/data/upgrades/upgrade_garden_slot.tres
id = &"upgrade_garden_slot", name = "庭拡張", is_permanent = true
price = 800, effect_type = &"garden_slot_increase", effect_value = 1
max_purchase_count = 3

# atelier/data/upgrades/upgrade_recipe_unlock_mana_tonic.tres
id = &"upgrade_recipe_unlock_mana_tonic", name = "レシピ解禁：魔力秘薬", is_permanent = true
price = 800, effect_type = &"recipe_unlock", effect_value = &"recipe_mana_tonic"（タスク004のid）
max_purchase_count = 1

# atelier/data/upgrades/upgrade_catalyst.tres
id = &"upgrade_catalyst", name = "触媒常備", is_permanent = false
price = 150, effect_type = &"catalyst_stock", effect_value = null（未使用）
max_purchase_count = 999

# atelier/data/upgrades/upgrade_seed_name_purchase_ore.tres
id = &"upgrade_seed_name_purchase_ore", name = "種の指名買い：鉱石の種", is_permanent = false
price = 50, effect_type = &"seed_name_purchase", effect_value = &"seed_ore"（既存SeedMaster）
max_purchase_count = 999
```

🟡 `.tres`のリテラル値（price等）は`GameBalance`定数と同じ値を直接記述する（`.tres`から`GameBalance`定数を参照する仕組みはGodotにないため、値の重複自体は意図的。値のズレが生じないよう、実装時はタスク002の定数値をそのままコピーすること）。`effect_value = &"seed_ore"`は`INITIAL_SEED_ID`（`seed_herb`）と異なる種を対象にすることで、AC-012の「未所持`seed_id`が新規エントリとして追加される」パスをデフォルト状態でそのまま検証できる（Plan設計フェーズで確認済み）。

## Test Strategy

`docs/dev/plans/workshop/acceptance-criteria.md` AC-015準拠。

- [ ] `MasterDataLoader.load_all(&"upgrades")`が5件の`UpgradeMaster`を返す
- [ ] 各要素の`id`・`name`・`is_permanent`・`price`・`effect_type`・`effect_value`・`max_purchase_count`が`.tres`の内容と一致する
- [ ] **異常系**: `res://data/upgrades/`に`UpgradeMaster`以外の`.tres`が混在していても`load_all(&"upgrades")`の結果に含まれない（既存`_is_allowed_type`パターンの踏襲確認。テストフィクスチャとして別カテゴリの`.tres`を一時的に混在させて検証するか、既存`&"recipes"`の同種テストと同じ手法を踏襲する）
- [ ] `load_all(&"materials")`・`load_all(&"recipes")`の既存挙動が本変更によって破壊されていない（回帰確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/loaders/master_data_loader.gd`全体（`&"recipes"`カテゴリの実装パターンをそのまま横展開する）、`atelier/tests/integration/test_master_data_loader_recipes.gd`（同種カテゴリのテストの書き方の参照元）
- 実装のヒント: `_resolve_dir_path()`・`_is_allowed_type()`のmatch文にそれぞれ1分岐追加するだけ。`load_all()`本体は変更不要
- 注意事項: `UpgradeMaster`（タスク001）が先に定義されている必要がある。`GameBalance`定数（タスク002）・第2レシピ`.tres`（タスク004）の値をそのまま`.tres`に転記するため、それらのタスク完了後に着手する

## Files

- 変更: `atelier/shared/loaders/master_data_loader.gd`
- 新規: `atelier/data/upgrades/upgrade_alchemy_slot.tres`, `atelier/data/upgrades/upgrade_garden_slot.tres`, `atelier/data/upgrades/upgrade_recipe_unlock_mana_tonic.tres`, `atelier/data/upgrades/upgrade_catalyst.tres`, `atelier/data/upgrades/upgrade_seed_name_purchase_ore.tres`
- テスト: `atelier/tests/integration/test_master_data_loader_upgrades.gd`
