extends GdUnitTestSuite


func _make_upgrade(is_permanent: bool) -> UpgradeMaster:
	var upgrade := UpgradeMaster.new()
	upgrade.is_permanent = is_permanent
	return upgrade


# 正常系
func test_ゴールドが価格を上回っていれば購入可能() -> void:
	assert_bool(PurchaseValidator.can_purchase(1000, 500, 0, 1)).is_true()


# 異常系
func test_ゴールド不足なら購入不可() -> void:
	assert_bool(PurchaseValidator.can_purchase(499, 500, 0, 1)).is_false()


# 境界値
func test_ゴールドと価格が等しいとき購入可能() -> void:
	assert_bool(PurchaseValidator.can_purchase(500, 500, 0, 1)).is_true()


# 境界値
func test_ゴールドが価格より1不足すると購入不可() -> void:
	assert_bool(PurchaseValidator.can_purchase(499, 500, 0, 1)).is_false()


# 境界値
func test_購入済み回数が上限直前なら購入可能() -> void:
	assert_bool(PurchaseValidator.can_purchase(500, 500, 2, 3)).is_true()


# 境界値
func test_購入済み回数が上限に到達済みなら購入不可() -> void:
	assert_bool(PurchaseValidator.can_purchase(500, 500, 3, 3)).is_false()


# 境界値
func test_購入上限が実質無制限なら購入済み回数が多くても購入可能() -> void:
	assert_bool(PurchaseValidator.can_purchase(500, 500, 500, 999)).is_true()


# 正常系
func test_恒久強化ならtrueを返す() -> void:
	var upgrade := _make_upgrade(true)

	assert_bool(PurchaseValidator.is_permanent_upgrade(upgrade)).is_true()


# 異常系
func test_恒久強化でなければfalseを返す() -> void:
	var upgrade := _make_upgrade(false)

	assert_bool(PurchaseValidator.is_permanent_upgrade(upgrade)).is_false()


func _make_upgrade_with_effect(effect_type: StringName, effect_value: Variant) -> UpgradeMaster:
	var upgrade := UpgradeMaster.new()
	upgrade.effect_type = effect_type
	upgrade.effect_value = effect_value
	return upgrade


# 正常系
func test_alchemy_slot_increaseでeffect_valueがintなら有効() -> void:
	var upgrade := _make_upgrade_with_effect(&"alchemy_slot_increase", 1)

	assert_bool(PurchaseValidator.is_valid_effect(upgrade)).is_true()


# 正常系
func test_garden_slot_increaseでeffect_valueがintなら有効() -> void:
	var upgrade := _make_upgrade_with_effect(&"garden_slot_increase", 1)

	assert_bool(PurchaseValidator.is_valid_effect(upgrade)).is_true()


# 正常系
func test_recipe_unlockでeffect_valueがStringNameなら有効() -> void:
	var upgrade := _make_upgrade_with_effect(&"recipe_unlock", &"recipe_mana_tonic")

	assert_bool(PurchaseValidator.is_valid_effect(upgrade)).is_true()


# 正常系
func test_seed_name_purchaseでeffect_valueがStringNameなら有効() -> void:
	var upgrade := _make_upgrade_with_effect(&"seed_name_purchase", &"seed_ore")

	assert_bool(PurchaseValidator.is_valid_effect(upgrade)).is_true()


# 正常系
func test_catalyst_stockはeffect_valueを問わず有効() -> void:
	var upgrade := _make_upgrade_with_effect(&"catalyst_stock", null)

	assert_bool(PurchaseValidator.is_valid_effect(upgrade)).is_true()


# 異常系
func test_未知のeffect_typeは無効() -> void:
	var upgrade := _make_upgrade_with_effect(&"unknown_effect", 1)

	assert_bool(PurchaseValidator.is_valid_effect(upgrade)).is_false()


# 異常系
func test_alchemy_slot_increaseでeffect_valueがStringNameなら無効() -> void:
	var upgrade := _make_upgrade_with_effect(&"alchemy_slot_increase", &"not_an_int")

	assert_bool(PurchaseValidator.is_valid_effect(upgrade)).is_false()


# 異常系
func test_recipe_unlockでeffect_valueがintなら無効() -> void:
	var upgrade := _make_upgrade_with_effect(&"recipe_unlock", 1)

	assert_bool(PurchaseValidator.is_valid_effect(upgrade)).is_false()


# 境界値
func test_alchemy_slot_increaseでeffect_valueがnullなら無効() -> void:
	var upgrade := _make_upgrade_with_effect(&"alchemy_slot_increase", null)

	assert_bool(PurchaseValidator.is_valid_effect(upgrade)).is_false()
