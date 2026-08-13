extends GdUnitTestSuite

const TRES_PATH := "user://test_recipe_master.tres"

# 正常系


func test_exportフィールドに値を設定すると読み書きできる() -> void:
	var recipe := RecipeMaster.new()

	recipe.id = &"recipe_healing_potion"
	recipe.name = "回復薬"
	recipe.base_contribution = 10.0
	recipe.base_reward = 25.0

	assert_that(recipe.id).is_equal(&"recipe_healing_potion")
	assert_str(recipe.name).is_equal("回復薬")
	assert_float(recipe.base_contribution).is_equal(10.0)
	assert_float(recipe.base_reward).is_equal(25.0)


func test_デフォルト値が空文字列と0である() -> void:
	var recipe := RecipeMaster.new()

	assert_that(recipe.id).is_equal(&"")
	assert_str(recipe.name).is_empty()
	assert_float(recipe.base_contribution).is_equal(0.0)
	assert_float(recipe.base_reward).is_equal(0.0)


func test_Resourceを継承している() -> void:
	var recipe := RecipeMaster.new()

	assert_bool(recipe is Resource).is_true()


# エッジケース


func test_tresから読み込んだインスタンスがRecipeMaster型として扱える() -> void:
	var original := RecipeMaster.new()
	original.id = &"recipe_test"
	original.name = "テスト調合物"
	original.base_contribution = 1.5
	original.base_reward = 2.5
	assert_int(ResourceSaver.save(original, TRES_PATH)).is_equal(OK)

	var loaded: Resource = ResourceLoader.load(TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)

	assert_bool(loaded is RecipeMaster).is_true()
	var loaded_recipe: RecipeMaster = loaded
	assert_that(loaded_recipe.id).is_equal(&"recipe_test")
	assert_str(loaded_recipe.name).is_equal("テスト調合物")
	assert_float(loaded_recipe.base_contribution).is_equal(1.5)
	assert_float(loaded_recipe.base_reward).is_equal(2.5)


func test_負値や大きな値も保持できる() -> void:
	var recipe := RecipeMaster.new()

	recipe.base_contribution = -1.0
	recipe.base_reward = 999999.0

	assert_float(recipe.base_contribution).is_equal(-1.0)
	assert_float(recipe.base_reward).is_equal(999999.0)


func after_test() -> void:
	if FileAccess.file_exists(TRES_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TRES_PATH))
