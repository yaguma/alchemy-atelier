extends GdUnitTestSuite

const SaveSlotTestHelpers = preload("res://tests/mocks/save_slot_test_helpers.gd")

const TEST_SLOT := 0


func before_test() -> void:
	GameState.reset_for_test()
	# 🔵 Autoloadのため各テストで明示的に未選択へ戻す（他テストからの汚染防止）
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()


func after_test() -> void:
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()


# 正常系


func test_active_slot選択済みならset_phaseでスロットファイルが更新される() -> void:
	SaveService.active_slot = TEST_SLOT
	GameState._set_gold_for_test(777)

	GameState.set_phase(&"alchemy")

	var result := SaveService.load_from_slot(TEST_SLOT)
	assert_bool(result.success).is_true()
	var loaded: Dictionary = result.value
	assert_int(int(loaded["gold"])).is_equal(777)
	assert_str(String(loaded["current_phase"])).is_equal("alchemy")


func test_異なるフェーズへ連続遷移すると都度最新状態で上書きされる() -> void:
	SaveService.active_slot = TEST_SLOT

	GameState._set_gold_for_test(111)
	GameState.set_phase(&"alchemy")

	GameState._set_gold_for_test(222)
	GameState.set_phase(&"workshop")

	var result := SaveService.load_from_slot(TEST_SLOT)
	assert_bool(result.success).is_true()
	var loaded: Dictionary = result.value
	assert_int(int(loaded["gold"])).is_equal(222)
	assert_str(String(loaded["current_phase"])).is_equal("workshop")


# 異常系・境界値


func test_active_slot未選択ならset_phaseを繰り返してもファイルが作られない() -> void:
	GameState.set_phase(&"alchemy")
	GameState.set_phase(&"workshop")
	GameState.set_phase(&"garden")

	for slot in range(SaveService.SLOT_COUNT):
		assert_bool(FileAccess.file_exists(SaveService._slot_path(slot))).is_false()


func test_同一フェーズへのset_phaseでは書き込みが発生しない() -> void:
	SaveService.active_slot = TEST_SLOT

	# 初期フェーズは&"garden"のため、同じ値を渡すと previous == next となる
	GameState.set_phase(&"garden")

	assert_bool(FileAccess.file_exists(SaveService._slot_path(TEST_SLOT))).is_false()
