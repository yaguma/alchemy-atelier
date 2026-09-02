extends GdUnitTestSuite

const SaveSlotTestHelpers = preload("res://tests/mocks/save_slot_test_helpers.gd")


func before_test() -> void:
	GameState.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()


func after_test() -> void:
	SaveSlotTestHelpers.cleanup_slots()


# 正常系


func test_save_to_slotで保存した内容がload_from_slotで往復する() -> void:
	GameState._set_gold_for_test(1234)
	# 🔵 GodotのJSONは数値を常にfloatで復元するため、期待値側もJSON往復させて
	# 同じ型表現に正規化してから比較する（int(100) != float(100.0)扱いのDictionary比較を避ける）。
	var expected: Dictionary = JSON.parse_string(
		JSON.stringify(GameStateSaveDelegate.collect_save_data(GameState))
	)

	var save_result := SaveService.save_to_slot(0)
	assert_bool(save_result.success).is_true()

	var load_result := SaveService.load_from_slot(0)
	assert_bool(load_result.success).is_true()

	var loaded: Dictionary = load_result.value
	loaded.erase("saved_at_unix")
	assert_dict(loaded).is_equal(expected)


func test_save_to_slotがsaved_at_unixを自動付与する() -> void:
	assert_bool(SaveService.save_to_slot(0).success).is_true()

	var load_result := SaveService.load_from_slot(0)
	var loaded: Dictionary = load_result.value

	assert_int(int(loaded["saved_at_unix"])).is_greater(0)


func test_get_slot_summaryが未保存スロットで空を返す() -> void:
	var summary := SaveService.get_slot_summary(0)

	assert_bool(summary.is_empty).is_true()
	assert_bool(summary.is_corrupted).is_false()
	assert_int(summary.slot_index).is_equal(0)


func test_get_slot_summaryが保存済みスロットの値を返す() -> void:
	GameState._set_gold_for_test(555)
	assert_bool(SaveService.save_to_slot(1).success).is_true()
	var expected := GameStateSaveDelegate.collect_save_data(GameState)

	var summary := SaveService.get_slot_summary(1)

	assert_bool(summary.is_empty).is_false()
	assert_bool(summary.is_corrupted).is_false()
	assert_int(summary.gold).is_equal(555)
	assert_str(summary.current_rank_id).is_equal(expected["current_rank_id"])
	assert_int(summary.current_turn).is_equal(expected["current_turn"])
	assert_int(summary.saved_at_unix).is_greater(0)


func test_スロットごとに独立したファイルへ保存される() -> void:
	GameState._set_gold_for_test(100)
	assert_bool(SaveService.save_to_slot(0).success).is_true()

	GameState._set_gold_for_test(200)
	assert_bool(SaveService.save_to_slot(2).success).is_true()

	assert_int(SaveService.get_slot_summary(0).gold).is_equal(100)
	assert_int(SaveService.get_slot_summary(2).gold).is_equal(200)
	assert_bool(SaveService.get_slot_summary(1).is_empty).is_true()


# 異常系・境界値


func test_未保存スロットのload_from_slotは失敗する() -> void:
	var result := SaveService.load_from_slot(0)

	assert_bool(result.success).is_false()


func test_破損したファイルのload_from_slotは失敗する() -> void:
	GameState._set_gold_for_test(1234)
	assert_bool(SaveService.save_to_slot(0).success).is_true()
	SaveSlotTestHelpers.corrupt_slot_file(self, 0)

	var result := SaveService.load_from_slot(0)

	assert_bool(result.success).is_false()


func test_get_slot_summaryが破損スロットでis_corruptedを返す() -> void:
	GameState._set_gold_for_test(1234)
	assert_bool(SaveService.save_to_slot(0).success).is_true()
	SaveSlotTestHelpers.corrupt_slot_file(self, 0)

	var summary := SaveService.get_slot_summary(0)

	assert_bool(summary.is_empty).is_false()
	assert_bool(summary.is_corrupted).is_true()


func test_範囲外スロットのsave_to_slotは失敗する() -> void:
	assert_bool(SaveService.save_to_slot(-1).success).is_false()
	assert_bool(SaveService.save_to_slot(SaveService.SLOT_COUNT).success).is_false()


func test_範囲外スロットのload_from_slotは失敗する() -> void:
	assert_bool(SaveService.load_from_slot(-1).success).is_false()
	assert_bool(SaveService.load_from_slot(SaveService.SLOT_COUNT).success).is_false()
