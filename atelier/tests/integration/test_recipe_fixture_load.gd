extends GdUnitTestSuite

const HEALING_POTION_PATH := "res://data/recipes/recipe_healing_potion.tres"


# 正常系


func test_recipe_healing_potionがRecipeMaster型としてロードされる() -> void:
	var resource: Resource = load(HEALING_POTION_PATH)

	assert_object(resource).is_not_null()
	assert_bool(resource is RecipeMaster).is_true()


func test_recipe_healing_potionのプロパティが仕様どおりの値である() -> void:
	var recipe: RecipeMaster = load(HEALING_POTION_PATH)

	assert_that(recipe.id).is_equal(&"recipe_healing_potion")
	assert_str(recipe.name).is_equal("回復薬")
	assert_float(recipe.base_contribution).is_equal(10.0)
	assert_float(recipe.base_reward).is_equal(5.0)


# 異常系・境界値


func test_recipesディレクトリに存在しないレシピidは解決できない() -> void:
	assert_bool(ResourceLoader.exists(HEALING_POTION_PATH)).is_true()
	assert_bool(ResourceLoader.exists("res://data/recipes/recipe_not_exist.tres")).is_false()


func test_既存のmaterialsマスターデータロードが引き続き成功する() -> void:
	var materials := MasterDataLoader.load_all(&"materials")

	assert_int(materials.size()).is_greater(0)
	assert_bool(MasterDataLoader.validate_references(materials)).is_true()
