extends GdUnitTestSuite

const TRES_PATH := "user://test_daily_order_master.tres"

# 正常系


func test_exportフィールドに値を設定すると読み書きできる() -> void:
	var order := DailyOrderMaster.new()

	order.id = "daily_order_healing_potion"
	order.condition_type = "item"
	order.target_recipe_id = "recipe_healing_potion"
	order.target_trait = ""
	order.match_bonus_multiplier = 1.5

	assert_str(order.id).is_equal("daily_order_healing_potion")
	assert_str(order.condition_type).is_equal("item")
	assert_str(order.target_recipe_id).is_equal("recipe_healing_potion")
	assert_str(order.target_trait).is_empty()
	assert_float(order.match_bonus_multiplier).is_equal(1.5)


func test_特性条件の指定でもフィールドを読み書きできる() -> void:
	var order := DailyOrderMaster.new()

	order.id = "daily_order_trait_fire"
	order.condition_type = "trait"
	order.target_trait = "trait_fire"

	assert_str(order.condition_type).is_equal("trait")
	assert_str(order.target_trait).is_equal("trait_fire")
	assert_str(order.target_recipe_id).is_empty()


func test_Resourceを継承している() -> void:
	var order := DailyOrderMaster.new()

	assert_bool(order is Resource).is_true()


func test_cloneで全フィールドを保持した独立インスタンスが得られる() -> void:
	var original := DailyOrderMaster.new()
	original.id = "order_original"
	original.condition_type = "item"
	original.target_recipe_id = "recipe_original"
	original.target_trait = "trait_original"
	original.match_bonus_multiplier = 2.0

	var copy := original.clone()

	assert_str(copy.id).is_equal("order_original")
	assert_str(copy.condition_type).is_equal("item")
	assert_str(copy.target_recipe_id).is_equal("recipe_original")
	assert_str(copy.target_trait).is_equal("trait_original")
	assert_float(copy.match_bonus_multiplier).is_equal(2.0)


func test_clone後に複製側を変更しても元のインスタンスは汚染されない() -> void:
	var original := DailyOrderMaster.new()
	original.match_bonus_multiplier = 1.3

	var copy := original.clone()
	copy.match_bonus_multiplier = 9.9

	assert_float(original.match_bonus_multiplier).is_equal(1.3)


func test_tres実データなしでフィクスチャ生成のみでインスタンス化が完結する() -> void:
	var order := DailyOrderMaster.new()
	order.id = "fixture_only"
	order.condition_type = "item"
	order.target_recipe_id = "recipe_test"
	order.match_bonus_multiplier = 1.3

	assert_object(order).is_not_null()
	assert_str(order.resource_path).is_empty()


# エッジケース


func test_デフォルト値が空文字列と既定倍率である() -> void:
	var order := DailyOrderMaster.new()

	assert_str(order.id).is_empty()
	assert_str(order.condition_type).is_empty()
	assert_str(order.target_recipe_id).is_empty()
	assert_str(order.target_trait).is_empty()
	assert_float(order.match_bonus_multiplier).is_equal(1.3)


func test_condition_typeの既定値はitemでもtraitでもない() -> void:
	var order := DailyOrderMaster.new()

	assert_str(order.condition_type).is_not_equal("item")
	assert_str(order.condition_type).is_not_equal("trait")


func test_tresから読み込んだインスタンスがDailyOrderMaster型として扱える() -> void:
	var original := DailyOrderMaster.new()
	original.id = "daily_order_test"
	original.condition_type = "trait"
	original.target_recipe_id = "recipe_test"
	original.target_trait = "trait_test"
	original.match_bonus_multiplier = 2.0
	assert_int(ResourceSaver.save(original, TRES_PATH)).is_equal(OK)

	var loaded: Resource = ResourceLoader.load(TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)

	assert_bool(loaded is DailyOrderMaster).is_true()
	var loaded_order: DailyOrderMaster = loaded
	assert_str(loaded_order.id).is_equal("daily_order_test")
	assert_str(loaded_order.condition_type).is_equal("trait")
	assert_str(loaded_order.target_recipe_id).is_equal("recipe_test")
	assert_str(loaded_order.target_trait).is_equal("trait_test")
	assert_float(loaded_order.match_bonus_multiplier).is_equal(2.0)


func after_test() -> void:
	if FileAccess.file_exists(TRES_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TRES_PATH))
