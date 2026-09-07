extends GdUnitTestSuite


func _make_upgrade(effect_type: StringName, effect_value: Variant) -> UpgradeMaster:
	var upgrade := UpgradeMaster.new()
	upgrade.effect_type = effect_type
	upgrade.effect_value = effect_value
	return upgrade


# 正常系
func test_alchemy_slot_increaseは投入枠の増加数を含む説明文を返す() -> void:
	var upgrade := _make_upgrade(&"alchemy_slot_increase", 1)

	assert_str(UpgradeEffectDescriber.describe(upgrade)).is_equal("調合の投入枠が1増えます")


# 正常系
func test_garden_slot_increaseは仕込み枠の増加数を含む説明文を返す() -> void:
	var upgrade := _make_upgrade(&"garden_slot_increase", 2)

	assert_str(UpgradeEffectDescriber.describe(upgrade)).is_equal("庭の仕込み枠が2増えます")


# 正常系
func test_catalyst_stockは固定の説明文を返す() -> void:
	var upgrade := _make_upgrade(&"catalyst_stock", null)

	assert_str(UpgradeEffectDescriber.describe(upgrade)).is_equal("触媒素材を1個獲得します")


# 境界値
func test_catalyst_stockはeffect_valueの値によらず固定の説明文を返す() -> void:
	var upgrade := _make_upgrade(&"catalyst_stock", 99)

	assert_str(UpgradeEffectDescriber.describe(upgrade)).is_equal("触媒素材を1個獲得します")


# 正常系
func test_recipe_unlockは汎用の説明文を返す() -> void:
	var upgrade := _make_upgrade(&"recipe_unlock", &"recipe_mana_tonic")

	assert_str(UpgradeEffectDescriber.describe(upgrade)).is_equal("新しいレシピが解放されます")


# 正常系
func test_seed_name_purchaseは汎用の説明文を返す() -> void:
	var upgrade := _make_upgrade(&"seed_name_purchase", &"seed_ore")

	assert_str(UpgradeEffectDescriber.describe(upgrade)).is_equal("新しい種を購入できるようになります")


# 異常系
func test_未知のeffect_typeは空文字列を返す() -> void:
	var upgrade := _make_upgrade(&"unknown_type", 1)

	assert_str(UpgradeEffectDescriber.describe(upgrade)).is_equal("")


# 境界値
func test_effect_typeが空なら空文字列を返す() -> void:
	var upgrade := _make_upgrade(&"", null)

	assert_str(UpgradeEffectDescriber.describe(upgrade)).is_equal("")


# 境界値
func test_alchemy_slot_increaseでeffect_valueが0なら0増加の説明文を返す() -> void:
	var upgrade := _make_upgrade(&"alchemy_slot_increase", 0)

	assert_str(UpgradeEffectDescriber.describe(upgrade)).is_equal("調合の投入枠が0増えます")
