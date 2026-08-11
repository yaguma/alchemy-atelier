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


# resolve_withering / harvest 用ヘルパー


func _make_master(p_id: StringName, p_base_quality: int = 1) -> SeedMaster:
	var master := SeedMaster.new()
	master.id = p_id
	master.produces_material_id = &"mat_%s" % p_id
	master.maturity_turns = 3
	master.death_grace_turns = 2
	master.base_quality = p_base_quality
	master.trait_pool = [&"trait_fresh"]
	return master


func _make_garden(plants: Array[PlantState]) -> GardenState:
	var garden_state := GardenState.new()
	garden_state.plants = plants
	return garden_state


# resolve_withering 正常系


func test_resolve_witheringは枯死株のみを除去し生存株を残す() -> void:
	var masters := {&"seed_herb": _make_master(&"seed_herb")}
	var alive := PlantState.new(0, &"seed_herb", 4, true)
	var dead := PlantState.new(1, &"seed_herb", 6, true)
	var garden_state := _make_garden([alive, dead])

	var result := Harvest.resolve_withering(garden_state, masters)

	assert_int(result.plants.size()).is_equal(1)
	assert_int(result.plants[0].slot_index).is_equal(0)
	assert_int(garden_state.plants.size()).is_equal(2)


func test_resolve_witheringは枯死株がなければplantsを変化させない() -> void:
	var masters := {&"seed_herb": _make_master(&"seed_herb")}
	var garden_state := _make_garden(
		[PlantState.new(0, &"seed_herb", 1, false), PlantState.new(1, &"seed_herb", 5, true)]
	)

	var result := Harvest.resolve_withering(garden_state, masters)

	assert_int(result.plants.size()).is_equal(2)


# resolve_withering 異常系・境界値


func test_resolve_witheringはplantsが空でも空配列を返す() -> void:
	var masters := {&"seed_herb": _make_master(&"seed_herb")}
	var garden_state := _make_garden([])

	var result := Harvest.resolve_withering(garden_state, masters)

	assert_int(result.plants.size()).is_equal(0)


func test_resolve_witheringはmastersに存在しないseed_idの株を除去しない() -> void:
	var masters := {}
	var garden_state := _make_garden([PlantState.new(0, &"seed_unknown", 99, true)])

	var result := Harvest.resolve_withering(garden_state, masters)

	assert_int(result.plants.size()).is_equal(1)


# harvest 正常系


func test_harvestは待機0ターンならbase_qualityの素材を返す() -> void:
	var master := _make_master(&"seed_herb", 3)
	var plant_state := PlantState.new(0, &"seed_herb", 3, true)

	var result := Harvest.harvest(plant_state, master, 0.0, 0.0)

	assert_bool(result.success).is_true()
	var material: MaterialInstance = result.value
	assert_int(material.quality_score).is_equal(3)


func test_harvestは待機1ターン以上かつ抽選成功で品質が1上昇する() -> void:
	var master := _make_master(&"seed_herb", 3)
	var plant_state := PlantState.new(0, &"seed_herb", 4, true)

	var result := Harvest.harvest(plant_state, master, GameBalance.QUALITY_UP_CHANCE - 0.01, 0.0)

	var material: MaterialInstance = result.value
	assert_int(material.quality_score).is_equal(4)


func test_harvestはproduces_material_idと抽選された特性を素材に設定する() -> void:
	var master := _make_master(&"seed_herb", 2)
	master.trait_pool = [&"trait_fresh", &"trait_rich"]
	var plant_state := PlantState.new(0, &"seed_herb", 3, true)

	var result := Harvest.harvest(plant_state, master, 1.0, 0.9)

	var material: MaterialInstance = result.value
	assert_that(material.material_id).is_equal(&"mat_seed_herb")
	assert_int(material.trait_tags.size()).is_equal(1)
	assert_that(material.trait_tags[0]).is_equal(&"trait_rich")


# harvest 異常系


func test_harvestは待機1ターン以上でも抽選失敗なら品質が上昇しない() -> void:
	var master := _make_master(&"seed_herb", 3)
	var plant_state := PlantState.new(0, &"seed_herb", 5, true)

	var result := Harvest.harvest(plant_state, master, GameBalance.QUALITY_UP_CHANCE, 0.0)

	var material: MaterialInstance = result.value
	assert_int(material.quality_score).is_equal(3)


func test_harvestは枯死株に対して失敗しMaterialInstanceを生成しない() -> void:
	var master := _make_master(&"seed_herb", 3)
	var plant_state := PlantState.new(0, &"seed_herb", 6, true)

	var result := Harvest.harvest(plant_state, master, 0.0, 0.0)

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"withered")
	assert_object(result.value).is_null()


func test_harvestは未成熟株に対してnot_maturedで失敗する() -> void:
	var master := _make_master(&"seed_herb", 3)
	var plant_state := PlantState.new(0, &"seed_herb", 1, false)

	var result := Harvest.harvest(plant_state, master, 0.0, 0.0)

	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"not_matured")


# harvest 境界値


func test_harvestは品質上昇してもQUALITY_SCORE_MAXを超えない() -> void:
	var master := _make_master(&"seed_herb", GameBalance.QUALITY_SCORE_MAX)
	var plant_state := PlantState.new(0, &"seed_herb", 4, true)

	var result := Harvest.harvest(plant_state, master, 0.0, 0.0)

	var material: MaterialInstance = result.value
	assert_int(material.quality_score).is_equal(GameBalance.QUALITY_SCORE_MAX)
