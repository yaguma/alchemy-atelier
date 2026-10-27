extends GdUnitTestSuite

## 🔵 Issue #64（FR-711）。ターン終了・試験ターン進行で在庫の素材が劣化・腐敗することを検証する。


func before_test() -> void:
	GameState.reset_for_test()


func after_test() -> void:
	GameState.reset_for_test()


func _make_material_master(id: StringName, decay_interval: int) -> MaterialMaster:
	var master := MaterialMaster.new()
	master.id = id
	master.decay_interval_turns = decay_interval
	return master


func _set_material_masters(masters: Array[MaterialMaster]) -> void:
	var dict: Dictionary = {}
	for master in masters:
		dict[master.id] = master
	GameState._set_masters_for_test({}, dict)


func _inject(instance_id: String, material_id: StringName, quality: int) -> void:
	var empty_tags: Array[StringName] = []
	GameState._inject_material_for_test(
		MaterialInstance.new(instance_id, material_id, quality, empty_tags)
	)


func _inventory() -> Array:
	return GameState.get_state()["inventory"]


# 正常系


func test_ターン終了で在庫素材の鮮度経過ターンが進む() -> void:
	_set_material_masters([_make_material_master(&"material_herb", 3)])
	_inject("mat_0001", &"material_herb", 3)

	GameState.advance_turn_growth()

	var material: MaterialInstance = _inventory()[0]
	assert_int(material.freshness_elapsed_turns).is_equal(1)
	assert_int(material.quality_score).is_equal(3)


func test_劣化間隔に達したターン終了で品質が下がる() -> void:
	_set_material_masters([_make_material_master(&"material_herb", 2)])
	_inject("mat_0001", &"material_herb", 3)

	GameState.advance_turn_growth()
	GameState.advance_turn_growth()

	var material: MaterialInstance = _inventory()[0]
	assert_int(material.quality_score).is_equal(2)


func test_腐敗した素材は在庫から取り除かれmaterials_rottedが発行される() -> void:
	_set_material_masters([_make_material_master(&"material_herb", 1)])
	_inject("mat_0001", &"material_herb", 1)
	_inject("mat_0002", &"material_herb", 3)
	monitor_signals(GameState, false)

	GameState.advance_turn_growth()

	var inventory := _inventory()
	assert_int(inventory.size()).is_equal(1)
	assert_str((inventory[0] as MaterialInstance).instance_id).is_equal("mat_0002")
	await assert_signal(GameState).is_emitted("materials_rotted", [["mat_0001"]])


func test_昇格試験のターン進行でも素材が劣化する() -> void:
	_set_material_masters([_make_material_master(&"material_herb", 1)])
	_inject("mat_0001", &"material_herb", 3)
	var exam_state := ExamState.new()
	exam_state.exam_turn_limit = 2
	GameState._set_exam_state_for_test(exam_state, true)

	GameState.advance_exam_turn()

	var material: MaterialInstance = _inventory()[0]
	assert_int(material.quality_score).is_equal(2)


func test_get_stateの在庫と素材マスターから残りターンを算出できる() -> void:
	_set_material_masters([_make_material_master(&"material_herb", 3)])
	_inject("mat_0001", &"material_herb", 3)
	GameState.advance_turn_growth()
	var state := GameState.get_state()

	var turns := AlchemyScreenSlots.turns_until_decay_by_id(
		state["inventory"], state["material_masters"]
	)

	assert_int(int(turns["mat_0001"])).is_equal(2)


# 異常系


func test_劣化しない素材は何ターン経過しても品質が変わらない() -> void:
	_set_material_masters([_make_material_master(&"material_ore", 0)])
	_inject("mat_0001", &"material_ore", 2)

	for i in range(10):
		GameState.advance_turn_growth()

	var material: MaterialInstance = _inventory()[0]
	assert_int(material.quality_score).is_equal(2)
	assert_int(material.freshness_elapsed_turns).is_equal(10)


func test_マスター未登録の素材は劣化しない扱いになる() -> void:
	_set_material_masters([])
	_inject("mat_0001", &"material_unknown", 1)

	GameState.advance_turn_growth()

	var inventory := _inventory()
	assert_int(inventory.size()).is_equal(1)
	assert_int((inventory[0] as MaterialInstance).quality_score).is_equal(1)
	assert_bool((inventory[0] as MaterialInstance).is_rotten).is_false()


func test_腐敗がなければmaterials_rottedは発行されない() -> void:
	_set_material_masters([_make_material_master(&"material_herb", 5)])
	_inject("mat_0001", &"material_herb", 3)
	monitor_signals(GameState, false)

	GameState.advance_turn_growth()

	await assert_signal(GameState).wait_until(50).is_not_emitted("materials_rotted")


func test_試験中でなければadvance_exam_turnは素材を劣化させない() -> void:
	_set_material_masters([_make_material_master(&"material_herb", 1)])
	_inject("mat_0001", &"material_herb", 3)

	GameState.advance_exam_turn()

	var material: MaterialInstance = _inventory()[0]
	assert_int(material.quality_score).is_equal(3)


# セーブ/ロード（FR-717）


func test_鮮度経過ターンはセーブして復元しても保持される() -> void:
	_set_material_masters([_make_material_master(&"material_herb", 5)])
	_inject("mat_0001", &"material_herb", 3)
	GameState.advance_turn_growth()
	GameState.advance_turn_growth()
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, data)

	var material: MaterialInstance = _inventory()[0]
	assert_int(material.freshness_elapsed_turns).is_equal(2)


func test_鮮度のない旧形式のセーブデータは鮮度0として復元される() -> void:
	_inject("mat_0001", &"material_herb", 3)
	var data := GameStateSaveDelegate.collect_save_data(GameState)
	for entry: Dictionary in data["inventory"]:
		entry.erase("freshness_elapsed_turns")

	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, data)

	var material: MaterialInstance = _inventory()[0]
	assert_int(material.freshness_elapsed_turns).is_equal(0)
