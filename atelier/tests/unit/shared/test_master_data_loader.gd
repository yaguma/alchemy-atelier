extends GdUnitTestSuite

const NON_RANK_SOURCE_PATH := "res://data/materials/material_herb.tres"
const NON_RANK_TEMP_PATH := "res://data/ranks/_tmp_non_rank.tres"


func after_test() -> void:
	# 混在テストが作成した一時ファイルを、テスト失敗時も含め確実に除去する
	if FileAccess.file_exists(NON_RANK_TEMP_PATH):
		DirAccess.remove_absolute(NON_RANK_TEMP_PATH)
	if FileAccess.file_exists(NON_RANK_TEMP_PATH + ".uid"):
		DirAccess.remove_absolute(NON_RANK_TEMP_PATH + ".uid")


# 正常系


func test_materialsカテゴリで実データの全件をロードする() -> void:
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


func test_ロードしたSeedMasterのフィールドが実データと一致する() -> void:
	var materials := MasterDataLoader.load_all(&"materials")

	var seed_herb: SeedMaster = null
	for m in materials:
		if m is SeedMaster and (m as SeedMaster).id == &"seed_herb":
			seed_herb = m
			break

	assert_object(seed_herb).is_not_null()
	assert_int(seed_herb.maturity_turns).is_equal(2)
	assert_int(seed_herb.death_grace_turns).is_equal(2)
	assert_int(seed_herb.base_quality).is_equal(2)
	assert_that(seed_herb.produces_material_id).is_equal(&"material_herb")


func test_ranksカテゴリで実データの全件をRankMasterとしてロードする() -> void:
	var ranks := MasterDataLoader.load_all(&"ranks")

	assert_int(ranks.size()).is_equal(GameBalance.RANK_ORDER.size())
	for r in ranks:
		assert_object(r).is_instanceof(RankMaster)


func test_ranksカテゴリのIDがRANK_ORDERと過不足なく一致する() -> void:
	var ranks := MasterDataLoader.load_all(&"ranks")

	var loaded_ids: Array[StringName] = []
	for r in ranks:
		loaded_ids.append(StringName((r as RankMaster).id))
	loaded_ids.sort()
	var expected_ids: Array[StringName] = GameBalance.RANK_ORDER.duplicate()
	expected_ids.sort()

	assert_array(loaded_ids).is_equal(expected_ids)


func test_実データに対しvalidate_referencesがtrueを返す() -> void:
	var materials := MasterDataLoader.load_all(&"materials")

	var result := MasterDataLoader.validate_references(materials)

	assert_bool(result).is_true()


# 異常系


func test_未解決のproduces_material_idがある場合validate_referencesがfalseを返す() -> void:
	var seed := SeedMaster.new()
	seed.id = &"seed_unknown"
	seed.produces_material_id = &"material_not_exist"
	var material := MaterialMaster.new()
	material.id = &"material_herb"

	var result := MasterDataLoader.validate_references([seed, material])

	assert_bool(result).is_false()


## ranksディレクトリに他カテゴリのリソース（MaterialMaster）を一時的に置いても、
## _is_allowed_type()の型フィルタにより取り込まれないことを検証する
func test_ranksディレクトリに他カテゴリのリソースがあっても取り込まない() -> void:
	var non_rank: Resource = load(NON_RANK_SOURCE_PATH)
	assert_int(ResourceSaver.save(non_rank.duplicate(), NON_RANK_TEMP_PATH)).is_equal(OK)

	var ranks := MasterDataLoader.load_all(&"ranks")

	assert_int(ranks.size()).is_equal(GameBalance.RANK_ORDER.size())
	for r in ranks:
		assert_object(r).is_instanceof(RankMaster)


func test_未知のカテゴリでload_allを呼ぶと空配列を返す() -> void:
	var materials := MasterDataLoader.load_all(&"unknown_category")

	assert_array(materials).is_empty()


# 境界値


func test_空配列をvalidate_referencesに渡すとtrueを返す() -> void:
	var result := MasterDataLoader.validate_references([])

	assert_bool(result).is_true()
