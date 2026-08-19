extends GdUnitTestSuite

## GameState._apply_upgrade_effect()のeffect_type別状態反映5種を検証する（FR-105〜FR-109）。
## apply_upgrade()本体（共通検証・ゴールド減算・シグナル発行）はタスク008で検証済みのため、
## 本テストでは購入可能な条件を整えた上でeffect_type別の状態変化のみを確認する


func before_test() -> void:
	GameState.reset_for_test()


func _make_upgrade(
	effect_type: StringName,
	effect_value: Variant,
	is_permanent: bool = false,
	price: int = 0,
	max_purchase_count: int = 999
) -> UpgradeMaster:
	var upgrade := UpgradeMaster.new()
	upgrade.id = StringName("upgrade_test_%s" % effect_type)
	upgrade.is_permanent = is_permanent
	upgrade.price = price
	upgrade.max_purchase_count = max_purchase_count
	upgrade.effect_type = effect_type
	upgrade.effect_value = effect_value
	return upgrade


# --- alchemy_slot_increase ---


func test_alchemy_slot_increase購入後にalchemy_slot_countが加算される() -> void:
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(true)
	var before_count: int = GameState._alchemy_slot_count
	var upgrade := _make_upgrade(&"alchemy_slot_increase", 1, true, 100, 1)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_true()
	assert_int(GameState._alchemy_slot_count).is_equal(before_count + 1)


func test_alchemy_slot_increaseは上限到達後の2回目購入で増加しない() -> void:
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(true)
	var before_count: int = GameState._alchemy_slot_count
	var upgrade := _make_upgrade(&"alchemy_slot_increase", 1, true, 100, 1)

	GameState.apply_upgrade(upgrade)
	var second_result := GameState.apply_upgrade(upgrade)

	assert_bool(second_result.success).is_false()
	assert_int(GameState._alchemy_slot_count).is_equal(before_count + 1)


# --- garden_slot_increase ---


func test_garden_slot_increase購入後にgarden_slot_countが加算される() -> void:
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(true)
	var before_count: int = GameState._garden_slot_count
	var upgrade := _make_upgrade(&"garden_slot_increase", 1, true, 100, 3)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_true()
	assert_int(GameState._garden_slot_count).is_equal(before_count + 1)


# --- recipe_unlock ---


func test_recipe_unlock購入後にunlocked_recipe_idsへ対象IDが追加される() -> void:
	GameState._set_gold_for_test(1000)
	var upgrade := _make_upgrade(&"recipe_unlock", &"recipe_mana_tonic", false, 100, 1)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_true()
	assert_array(GameState.get_state()["unlocked_recipe_ids"]).contains([&"recipe_mana_tonic"])


func test_recipe_unlock購入後にexecute_alchemyで未解禁エラーが発生しなくなる() -> void:
	var recipe := RecipeMaster.new()
	recipe.id = &"recipe_mana_tonic"
	recipe.name = "テストレシピ"
	recipe.base_contribution = 10.0
	recipe.base_reward = 5.0
	GameState._set_recipe_masters_for_test({&"recipe_mana_tonic": recipe})
	GameState._set_gold_for_test(1000)

	var before_result := GameState.execute_alchemy(&"recipe_mana_tonic", [])
	assert_str(before_result.error_code).is_equal(&"recipe_not_unlocked")

	var upgrade := _make_upgrade(&"recipe_unlock", &"recipe_mana_tonic", false, 100, 1)
	GameState.apply_upgrade(upgrade)

	var after_result := GameState.execute_alchemy(&"recipe_mana_tonic", [])
	assert_str(after_result.error_code).is_not_equal(&"recipe_not_unlocked")


# --- catalyst_stock ---


func test_catalyst_stock購入後にinventoryサイズが1増え触媒素材が追加される() -> void:
	GameState._set_gold_for_test(1000)
	var upgrade := _make_upgrade(&"catalyst_stock", null, false, 100, 999)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_true()
	var inventory: Array = GameState.get_state()["inventory"]
	assert_int(inventory.size()).is_equal(1)
	var material: MaterialInstance = inventory[0]
	assert_that(material.material_id).is_equal(GameBalance.CATALYST_MATERIAL_ID)
	assert_array(material.trait_tags).contains([&"catalyst"])


func test_catalyst_stock購入で追加される素材のquality_scoreが定数と一致する() -> void:
	GameState._set_gold_for_test(1000)
	var upgrade := _make_upgrade(&"catalyst_stock", null, false, 100, 999)

	GameState.apply_upgrade(upgrade)

	var inventory: Array = GameState.get_state()["inventory"]
	var material: MaterialInstance = inventory[0]
	assert_int(material.quality_score).is_equal(GameBalance.CATALYST_BASE_QUALITY_SCORE)


func test_catalyst_stockを連続2回購入すると独立した2件がinventoryに追加される() -> void:
	GameState._set_gold_for_test(1000)
	var upgrade := _make_upgrade(&"catalyst_stock", null, false, 100, 999)

	GameState.apply_upgrade(upgrade)
	GameState.apply_upgrade(upgrade)

	# 参照共有していないことは内部フィールドを直接参照して確認する（get_state()はclone()を
	# 経由するため、常に別インスタンスになり参照共有の有無を検証できないため）
	var inventory: Array[MaterialInstance] = GameState._inventory
	assert_int(inventory.size()).is_equal(2)
	var first: MaterialInstance = inventory[0]
	var second: MaterialInstance = inventory[1]
	assert_str(first.instance_id).is_not_equal(second.instance_id)
	assert_bool(first == second).is_false()


# --- seed_name_purchase ---


func test_seed_name_purchaseで既存seed_idの場合countが1増える() -> void:
	GameState._set_gold_for_test(1000)
	var upgrade := _make_upgrade(&"seed_name_purchase", GameBalance.INITIAL_SEED_ID, false, 50, 999)
	var before_count: int = GameState._find_seed_inventory_index(GameBalance.INITIAL_SEED_ID)
	var before_entry: Dictionary = GameState.get_state()["seed_inventory"][before_count]
	var before_seed_count: int = before_entry["count"]

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_true()
	var seed_inventory: Array = GameState.get_state()["seed_inventory"]
	var index := GameState._find_seed_inventory_index(GameBalance.INITIAL_SEED_ID)
	assert_int(seed_inventory[index]["count"]).is_equal(before_seed_count + 1)


func test_seed_name_purchaseで未所持seed_idの場合新規エントリが追加される() -> void:
	GameState._set_gold_for_test(1000)
	var upgrade := _make_upgrade(&"seed_name_purchase", &"seed_ore", false, 50, 999)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_true()
	var seed_inventory: Array = GameState.get_state()["seed_inventory"]
	var index := GameState._find_seed_inventory_index(&"seed_ore")
	assert_int(index).is_greater_equal(0)
	assert_int(seed_inventory[index]["count"]).is_equal(1)
