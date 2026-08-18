---
id: "009"
title: "GameState.apply_upgrade()にeffect_type別の状態反映5種を実装する"
status: pending
priority: 2
dependencies: ["008"]
estimated_complexity: high
---

# Task: GameState.apply_upgrade()にeffect_type別の状態反映5種を実装する

## Goal

タスク008で`pass`のみだった`_apply_upgrade_effect(upgrade)`に、`effect_type`別の状態反映ロジック5種（`alchemy_slot_increase` / `garden_slot_increase` / `recipe_unlock` / `catalyst_stock` / `seed_name_purchase`）を実装する（FR-105, FR-106, FR-107, FR-108, FR-109）。

## Interfaces

```gdscript
# atelier/autoload/game_state.gd の _apply_upgrade_effect() を置き換え

## 🔵 FR-105〜FR-109。upgrade.effect_typeに応じてGameStateの各状態を更新する。
## 呼び出し元のapply_upgrade()が既に検証済み（購入可能）であることを前提とし、
## ここでは検証を行わない（Domain層システム同士を直接参照しないCON-003に従い、
## 反映先はすべてGameState自身のフィールドに限定する）
func _apply_upgrade_effect(upgrade: UpgradeMaster) -> void:
	match upgrade.effect_type:
		&"alchemy_slot_increase":  # FR-105
			_alchemy_slot_count += (upgrade.effect_value as int)
		&"garden_slot_increase":  # FR-106
			_garden_slot_count += (upgrade.effect_value as int)
		&"recipe_unlock":  # FR-107
			_unlocked_recipe_ids.append(upgrade.effect_value as StringName)
		&"catalyst_stock":  # FR-108, CON-010
			var material := MaterialInstance.new(
				"mat_%04d" % _material_instance_seq,
				GameBalance.CATALYST_MATERIAL_ID,
				GameBalance.CATALYST_BASE_QUALITY_SCORE,
				[&"catalyst"]
			)
			_material_instance_seq += 1
			_inventory.append(material)
		&"seed_name_purchase":  # FR-109
			var seed_id := upgrade.effect_value as StringName
			var index := _find_seed_inventory_index(seed_id)
			if index == -1:
				_seed_inventory.append({"seed_id": seed_id, "count": 1})
			else:
				_seed_inventory[index]["count"] = (
					(_seed_inventory[index]["count"] as int) + 1
				)
		_:
			push_error("未知のeffect_typeです: %s" % upgrade.effect_type)  # 🟡 防御的分岐
```

`_material_instance_seq`は既存`harvest()`（`game_state.gd` L217-218）と同一のカウンタを共有する（🔵 Plan設計フェーズで確認済み。別カウンタにすると`harvest()`由来と`apply_upgrade()`由来の`instance_id`が衝突しうるため、共有が必然）。

## Test Strategy

`docs/dev/plans/workshop/acceptance-criteria.md` AC-008, AC-009, AC-010, AC-011, AC-012準拠。`_can_purchase_permanent = true`にした上で恒久投資を、フラグ不問で消耗投資を購入するテストとして構成する。

- [ ] **正常系**: `effect_type = &"alchemy_slot_increase"`, `effect_value = 1`のUpgradeMaster購入後、`_alchemy_slot_count`が購入前+1になる
- [ ] **境界値**: `max_purchase_count = 1`の`alchemy_slot_increase`は、2回目の購入要求が拒否され`_alchemy_slot_count`がそれ以上増加しない（タスク008の検証ロジックとの結合確認）
- [ ] **正常系**: `effect_type = &"garden_slot_increase"`, `effect_value = 1`のUpgradeMaster購入後、`_garden_slot_count`が購入前+1になる
- [ ] **正常系**: `effect_type = &"recipe_unlock"`, `effect_value = &"recipe_mana_tonic"`のUpgradeMaster購入後、`_unlocked_recipe_ids`に対象IDが追加される
- [ ] **正常系**: 上記購入後、`execute_alchemy(&"recipe_mana_tonic", ...)`で`&"recipe_not_unlocked"`エラーが発生しなくなる（既存`AlchemySystem`ロジックとの結合確認）
- [ ] **正常系**: `effect_type = &"catalyst_stock"`のUpgradeMaster購入後、`_inventory`のサイズが1増え、追加された`MaterialInstance`の`material_id`が`GameBalance.CATALYST_MATERIAL_ID`、`trait_tags`に`&"catalyst"`が含まれる
- [ ] **正常系**: 追加された`MaterialInstance.quality_score`が`GameBalance.CATALYST_BASE_QUALITY_SCORE`と一致する
- [ ] **境界値**: `catalyst_stock`を連続2回購入すると`_inventory`に触媒素材が2件独立して追加される（参照共有していないこと。`instance_id`が重複しないことも確認）
- [ ] **正常系**: `effect_type = &"seed_name_purchase"`, `effect_value`が既存`_seed_inventory`の`seed_id`（例: `GameBalance.INITIAL_SEED_ID`）の場合、該当エントリの`count`が+1される
- [ ] **正常系**: `effect_value`が`_seed_inventory`に存在しない`seed_id`（例: `&"seed_ore"`、初期状態で未所持）の場合、`{seed_id: effect_value, count: 1}`の新規エントリが追加される

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`harvest()`（L216-224、`MaterialInstance`生成と`_material_instance_seq`インクリメントの既存パターン）、`_find_seed_inventory_index()`（L185-189、再利用対象）、`atelier/shared/entities/material_instance.gd`（コンストラクタ引数順: `instance_id, material_id, quality_score, trait_tags`）
- 実装のヒント: `MaterialInstance.new()`の第2引数`material_id`にはタスク002で追加した`GameBalance.CATALYST_MATERIAL_ID`（`&"material_catalyst"`）を渡す。第3引数`quality_score`には既存`GameBalance.CATALYST_BASE_QUALITY_SCORE`（既存L41、本タスクで初めて実消費）を渡す
- 注意事項: `_apply_upgrade_effect()`はタスク008で作成済みの空実装を置き換えるのみで、`apply_upgrade()`本体（検証・ゴールド減算・シグナル発行）は変更しない。`recipe_unlock`のテストで使う`&"recipe_mana_tonic"`はタスク004で作成済みの第2レシピ、`seed_name_purchase`のテストで使う`&"seed_ore"`は既存マスターデータ

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_apply_upgrade_effects.gd`
