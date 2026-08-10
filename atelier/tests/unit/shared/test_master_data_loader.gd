extends GdUnitTestSuite

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
	assert_int(material_count).is_equal(2)


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


func test_未知のカテゴリでload_allを呼ぶと空配列を返す() -> void:
	var materials := MasterDataLoader.load_all(&"unknown_category")

	assert_array(materials).is_empty()


# 境界値


func test_空配列をvalidate_referencesに渡すとtrueを返す() -> void:
	var result := MasterDataLoader.validate_references([])

	assert_bool(result).is_true()
