extends GdUnitTestSuite


func test_plantsに設定した値がプロパティに保持される() -> void:
	var plants: Array[PlantState] = [PlantState.new(0, &"seed_herb")]
	var garden := GardenState.new()
	garden.plants = plants

	assert_int(garden.plants.size()).is_equal(1)
	assert_that(garden.plants[0].seed_id).is_equal(&"seed_herb")


func test_cloneで生成したplants配列は元と別オブジェクトである() -> void:
	var garden := GardenState.new()
	garden.plants = [PlantState.new(0, &"seed_herb")]

	var cloned := garden.clone()
	cloned.plants.append(PlantState.new(1, &"seed_flower"))

	assert_int(cloned.plants.size()).is_equal(2)
	assert_int(garden.plants.size()).is_equal(1)


func test_cloneしたplants内の要素は別オブジェクトで独立して変更できる() -> void:
	var garden := GardenState.new()
	garden.plants = [PlantState.new(0, &"seed_herb", 2, false)]

	var cloned := garden.clone()
	cloned.plants[0].grown_turns = 99

	assert_int(cloned.plants[0].grown_turns).is_equal(99)
	assert_int(garden.plants[0].grown_turns).is_equal(2)
	assert_bool(cloned.plants[0] == garden.plants[0]).is_false()


func test_空のplantsを持つGardenStateでもcloneが正常に動作する() -> void:
	var garden := GardenState.new()
	garden.plants = []

	var cloned := garden.clone()

	assert_int(cloned.plants.size()).is_equal(0)
