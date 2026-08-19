extends GdUnitTestSuite

const RECIPES_DIR := "res://data/recipes/"
const MATERIALS_DIR := "res://data/materials/"
const NON_RECIPE_SOURCE_PATH := "res://data/materials/material_herb.tres"
const NON_RECIPE_TEMP_PATH := "res://data/recipes/_tmp_non_recipe.tres"


func after_test() -> void:
	# エッジケーステストが作成した一時ファイルを、テスト失敗時も含め確実に除去する
	if FileAccess.file_exists(NON_RECIPE_TEMP_PATH):
		DirAccess.remove_absolute(NON_RECIPE_TEMP_PATH)
	if FileAccess.file_exists(NON_RECIPE_TEMP_PATH + ".uid"):
		DirAccess.remove_absolute(NON_RECIPE_TEMP_PATH + ".uid")


# 正常系


func test_recipesカテゴリで実データの全件をRecipeMasterとしてロードする() -> void:
	var recipes := MasterDataLoader.load_all(&"recipes")

	assert_int(recipes.size()).is_greater(0)
	for r in recipes:
		assert_bool(r is RecipeMaster).is_true()


func test_ロードしたRecipeMasterのフィールドが実データと一致する() -> void:
	var recipes := MasterDataLoader.load_all(&"recipes")

	var healing_potion: RecipeMaster = null
	for r in recipes:
		if r is RecipeMaster and (r as RecipeMaster).id == &"recipe_healing_potion":
			healing_potion = r
			break

	assert_object(healing_potion).is_not_null()
	assert_str(healing_potion.name).is_equal("回復薬")
	assert_float(healing_potion.base_contribution).is_equal(10.0)
	assert_float(healing_potion.base_reward).is_equal(5.0)


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


# 異常系


func test_未知のカテゴリでload_allを呼ぶと空配列を返す() -> void:
	var result := MasterDataLoader.load_all(&"unknown_category")

	assert_array(result).is_empty()


# 境界値・エッジケース


func test_recipesディレクトリにRecipeMaster以外が混在してもRecipeMasterのみ返す() -> void:
	var copy_error := DirAccess.copy_absolute(NON_RECIPE_SOURCE_PATH, NON_RECIPE_TEMP_PATH)
	assert_int(copy_error).is_equal(OK)

	var recipes := MasterDataLoader.load_all(&"recipes")

	for r in recipes:
		assert_bool(r is RecipeMaster).is_true()
		assert_bool(r is MaterialMaster).is_false()


func test_materialsカテゴリの結果にRecipeMasterが混入しない() -> void:
	var materials := MasterDataLoader.load_all(&"materials")

	for m in materials:
		assert_bool(m is RecipeMaster).is_false()
