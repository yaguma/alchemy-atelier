extends GdUnitTestSuite

# 正常系


func test_advance_growthでgrown_turnsが加算された新しいPlantStateが返る() -> void:
	var plant_state := PlantState.new(0, &"seed_herb", 2, false)

	var result := Harvest.advance_growth(plant_state, 1)

	assert_int(result.grown_turns).is_equal(3)
	assert_int(plant_state.grown_turns).is_equal(2)


func test_advance_growthはslot_indexとseed_idとis_maturedを引き継ぐ() -> void:
	var plant_state := PlantState.new(2, &"seed_flower", 0, true)

	var result := Harvest.advance_growth(plant_state, 1)

	assert_int(result.slot_index).is_equal(2)
	assert_that(result.seed_id).is_equal(&"seed_flower")
	assert_bool(result.is_matured).is_true()


func test_grown_turnsがmaturity_turnsと一致するときis_maturedがtrueを返す() -> void:
	var plant_state := PlantState.new(0, &"seed_herb", 3, false)
	var master := SeedMaster.new()
	master.maturity_turns = 3

	var result := Harvest.is_matured(plant_state, master)

	assert_bool(result).is_true()


# 異常系


func test_grown_turnsがmaturity_turns未満のときis_maturedがfalseを返す() -> void:
	var plant_state := PlantState.new(0, &"seed_herb", 2, false)
	var master := SeedMaster.new()
	master.maturity_turns = 3

	var result := Harvest.is_matured(plant_state, master)

	assert_bool(result).is_false()


func test_未成熟のPlantStateはis_deadが常にfalseを返す() -> void:
	var plant_state := PlantState.new(0, &"seed_herb", 0, false)
	var master := SeedMaster.new()
	master.maturity_turns = 3
	master.death_grace_turns = 2

	var result := Harvest.is_dead(plant_state, master)

	assert_bool(result).is_false()


# 境界値


func test_成熟直後で待機0ターンはis_deadがfalseを返す() -> void:
	var master := SeedMaster.new()
	master.maturity_turns = 3
	master.death_grace_turns = 2
	var plant_state := PlantState.new(0, &"seed_herb", 3, true)

	var result := Harvest.is_dead(plant_state, master)

	assert_bool(result).is_false()


func test_待機ターン数がdeath_grace_turnsちょうどのときis_deadがfalseを返す() -> void:
	var master := SeedMaster.new()
	master.maturity_turns = 3
	master.death_grace_turns = 2
	var plant_state := PlantState.new(0, &"seed_herb", 5, true)

	var result := Harvest.is_dead(plant_state, master)

	assert_bool(result).is_false()


func test_待機ターン数がdeath_grace_turnsを1超えたときis_deadがtrueを返す() -> void:
	var master := SeedMaster.new()
	master.maturity_turns = 3
	master.death_grace_turns = 2
	var plant_state := PlantState.new(0, &"seed_herb", 6, true)

	var result := Harvest.is_dead(plant_state, master)

	assert_bool(result).is_true()
