extends GdUnitTestSuite

const UPGRADES_DIR := "res://data/upgrades/"
const MATERIALS_DIR := "res://data/materials/"
const NON_UPGRADE_SOURCE_PATH := "res://data/materials/material_herb.tres"
const NON_UPGRADE_TEMP_PATH := "res://data/upgrades/_tmp_non_upgrade.tres"


func after_test() -> void:
	# エッジケーステストが作成した一時ファイルを、テスト失敗時も含め確実に除去する
	if FileAccess.file_exists(NON_UPGRADE_TEMP_PATH):
		DirAccess.remove_absolute(NON_UPGRADE_TEMP_PATH)
	if FileAccess.file_exists(NON_UPGRADE_TEMP_PATH + ".uid"):
		DirAccess.remove_absolute(NON_UPGRADE_TEMP_PATH + ".uid")


# 正常系


func test_upgradesカテゴリで実データの全件をUpgradeMasterとしてロードする() -> void:
	var upgrades := MasterDataLoader.load_all(&"upgrades")

	assert_int(upgrades.size()).is_equal(5)
	for u in upgrades:
		assert_bool(u is UpgradeMaster).is_true()


func test_ロードしたUpgradeMasterのフィールドが実データと一致する() -> void:
	var upgrades := MasterDataLoader.load_all(&"upgrades")

	var by_id: Dictionary = {}
	for u in upgrades:
		by_id[(u as UpgradeMaster).id] = u

	# .tresのリテラル値はGameBalance.WORKSHOP_*定数と同じ値を直接記述する意図的な重複
	# （.tresからGDScript定数を参照する仕組みがGodotにないため）。ここでGameBalance定数と
	# 突き合わせることで、片方だけ値を変更した場合のドリフトを検知する（コードレビュー指摘対応）
	var alchemy_slot: UpgradeMaster = by_id.get(&"upgrade_alchemy_slot")
	assert_object(alchemy_slot).is_not_null()
	assert_str(alchemy_slot.name).is_equal("投入枠+1")
	assert_bool(alchemy_slot.is_permanent).is_true()
	assert_int(alchemy_slot.price).is_equal(GameBalance.WORKSHOP_ALCHEMY_SLOT_PRICE)
	assert_that(alchemy_slot.effect_type).is_equal(&"alchemy_slot_increase")
	assert_int(alchemy_slot.effect_value).is_equal(GameBalance.WORKSHOP_ALCHEMY_SLOT_EFFECT_VALUE)
	assert_int(alchemy_slot.max_purchase_count).is_equal(
		GameBalance.WORKSHOP_ALCHEMY_SLOT_MAX_PURCHASE_COUNT
	)

	var garden_slot: UpgradeMaster = by_id.get(&"upgrade_garden_slot")
	assert_object(garden_slot).is_not_null()
	assert_str(garden_slot.name).is_equal("庭拡張")
	assert_bool(garden_slot.is_permanent).is_true()
	assert_int(garden_slot.price).is_equal(GameBalance.WORKSHOP_GARDEN_SLOT_PRICE)
	assert_that(garden_slot.effect_type).is_equal(&"garden_slot_increase")
	assert_int(garden_slot.effect_value).is_equal(GameBalance.WORKSHOP_GARDEN_SLOT_EFFECT_VALUE)
	assert_int(garden_slot.max_purchase_count).is_equal(
		GameBalance.WORKSHOP_GARDEN_SLOT_MAX_PURCHASE_COUNT
	)

	var recipe_unlock: UpgradeMaster = by_id.get(&"upgrade_recipe_unlock_mana_tonic")
	assert_object(recipe_unlock).is_not_null()
	assert_str(recipe_unlock.name).is_equal("レシピ解禁：魔力秘薬")
	assert_bool(recipe_unlock.is_permanent).is_true()
	assert_int(recipe_unlock.price).is_equal(GameBalance.WORKSHOP_RECIPE_UNLOCK_PRICE)
	assert_that(recipe_unlock.effect_type).is_equal(&"recipe_unlock")
	assert_that(recipe_unlock.effect_value).is_equal(GameBalance.SECOND_RECIPE_ID)
	assert_int(recipe_unlock.max_purchase_count).is_equal(
		GameBalance.WORKSHOP_RECIPE_UNLOCK_MAX_PURCHASE_COUNT
	)

	var catalyst: UpgradeMaster = by_id.get(&"upgrade_catalyst")
	assert_object(catalyst).is_not_null()
	assert_str(catalyst.name).is_equal("触媒常備")
	assert_bool(catalyst.is_permanent).is_false()
	assert_int(catalyst.price).is_equal(GameBalance.WORKSHOP_CATALYST_STOCK_PRICE)
	assert_that(catalyst.effect_type).is_equal(&"catalyst_stock")
	assert_int(catalyst.max_purchase_count).is_equal(
		GameBalance.WORKSHOP_CATALYST_STOCK_MAX_PURCHASE_COUNT
	)

	var seed_name_purchase: UpgradeMaster = by_id.get(&"upgrade_seed_name_purchase_ore")
	assert_object(seed_name_purchase).is_not_null()
	assert_str(seed_name_purchase.name).is_equal("種の指名買い：鉱石の種")
	assert_bool(seed_name_purchase.is_permanent).is_false()
	assert_int(seed_name_purchase.price).is_equal(GameBalance.WORKSHOP_SEED_NAME_PURCHASE_PRICE)
	assert_that(seed_name_purchase.effect_type).is_equal(&"seed_name_purchase")
	assert_that(seed_name_purchase.effect_value).is_equal(&"seed_ore")
	assert_int(seed_name_purchase.max_purchase_count).is_equal(
		GameBalance.WORKSHOP_SEED_NAME_PURCHASE_MAX_PURCHASE_COUNT
	)


func test_materialsカテゴリのロードが既存どおり動作する() -> void:
	var materials := MasterDataLoader.load_all(&"materials")

	var seed_count := 0
	var material_count := 0
	for m in materials:
		if m is SeedMaster:
			seed_count += 1
		elif m is MaterialMaster:
			material_count += 1

	assert_int(seed_count).is_equal(2)
	assert_int(material_count).is_equal(3)
	assert_int(materials.size()).is_equal(seed_count + material_count)
	assert_bool(MasterDataLoader.validate_references(materials)).is_true()


func test_recipesカテゴリのロードが既存どおり動作する() -> void:
	var recipes := MasterDataLoader.load_all(&"recipes")

	assert_int(recipes.size()).is_equal(2)
	for r in recipes:
		assert_bool(r is RecipeMaster).is_true()


# 異常系


func test_upgradesディレクトリにUpgradeMaster以外が混在してもUpgradeMasterのみ返す() -> void:
	var copy_error := DirAccess.copy_absolute(NON_UPGRADE_SOURCE_PATH, NON_UPGRADE_TEMP_PATH)
	assert_int(copy_error).is_equal(OK)

	var upgrades := MasterDataLoader.load_all(&"upgrades")

	assert_int(upgrades.size()).is_equal(5)
	for u in upgrades:
		assert_bool(u is UpgradeMaster).is_true()
		assert_bool(u is MaterialMaster).is_false()


func test_materialsカテゴリの結果にUpgradeMasterが混入しない() -> void:
	var materials := MasterDataLoader.load_all(&"materials")

	for m in materials:
		assert_bool(m is UpgradeMaster).is_false()
