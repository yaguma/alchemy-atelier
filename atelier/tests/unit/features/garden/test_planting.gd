extends GdUnitTestSuite

# 正常系


func test_空きスロットがある場合can_plantがtrueを返す() -> void:
	var garden := GardenState.new()
	garden.plants = [PlantState.new(0, &"seed_herb")]

	var result := Planting.can_plant(garden, 4)

	assert_bool(result).is_true()


func test_plant成功時に新規PlantStateがResultのvalueに格納される() -> void:
	var garden := GardenState.new()
	var master := SeedMaster.new()

	var result := Planting.plant(garden, &"seed_herb", master, 4)

	assert_bool(result.success).is_true()
	var planted: PlantState = result.value
	assert_that(planted.seed_id).is_equal(&"seed_herb")
	assert_int(planted.grown_turns).is_equal(0)
	assert_bool(planted.is_matured).is_false()


func test_歯抜けスロットがある場合空いている最小のslot_indexが採番される() -> void:
	var garden := GardenState.new()
	garden.plants = [PlantState.new(1, &"seed_flower")]
	var master := SeedMaster.new()

	var result := Planting.plant(garden, &"seed_herb", master, 4)

	var planted: PlantState = result.value
	assert_int(planted.slot_index).is_equal(0)


# 異常系


func test_スロット満杯の場合can_plantがfalseを返す() -> void:
	var garden := GardenState.new()
	garden.plants = [PlantState.new(0, &"seed_herb"), PlantState.new(1, &"seed_flower")]

	var result := Planting.can_plant(garden, 2)

	assert_bool(result).is_false()


func test_スロット満杯でplantを呼ぶとslot_fullエラーを返しgarden_stateを変更しない() -> void:
	var garden := GardenState.new()
	garden.plants = [PlantState.new(0, &"seed_herb"), PlantState.new(1, &"seed_flower")]
	var master := SeedMaster.new()

	var result := Planting.plant(garden, &"seed_new", master, 2)

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"slot_full")
	assert_int(garden.plants.size()).is_equal(2)


# 境界値


func test_残り1スロットの場合can_plantがtrueでスロットを埋めた後はfalseになる() -> void:
	var garden := GardenState.new()
	garden.plants = [PlantState.new(0, &"seed_herb")]

	var before := Planting.can_plant(garden, 2)

	garden.plants = [PlantState.new(0, &"seed_herb"), PlantState.new(1, &"seed_flower")]
	var after := Planting.can_plant(garden, 2)

	assert_bool(before).is_true()
	assert_bool(after).is_false()
