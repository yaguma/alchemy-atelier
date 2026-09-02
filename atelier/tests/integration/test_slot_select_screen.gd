extends GdUnitTestSuite

const SaveSlotTestHelpers = preload("res://tests/mocks/save_slot_test_helpers.gd")


func before_test() -> void:
	GameState.reset_for_test()
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()


func after_test() -> void:
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()


# 正常系（表示）


func test_全スロット未使用なら3つとも新規開始表示になる() -> void:
	var screen := _make_screen()

	for slot in range(SaveService.SLOT_COUNT):
		assert_str(screen.get_slot_info_text(slot)).is_equal(SlotSelectScreen.LABEL_NEW_GAME)


func test_保存済みスロットのみつづきから表示になり保存値が反映される() -> void:
	GameState._set_gold_for_test(1234)
	assert_bool(SaveService.save_to_slot(1).success).is_true()
	var summary := SaveService.get_slot_summary(1)

	var screen := _make_screen()

	var info := screen.get_slot_info_text(1)
	assert_str(info).contains("つづきから")
	assert_str(info).contains("1234")
	assert_str(info).contains(summary.current_rank_id)
	assert_str(info).contains(str(summary.current_turn))
	assert_str(screen.get_slot_info_text(0)).is_equal(SlotSelectScreen.LABEL_NEW_GAME)
	assert_str(screen.get_slot_info_text(2)).is_equal(SlotSelectScreen.LABEL_NEW_GAME)


func test_破損スロットは壊れている旨の表示になる() -> void:
	assert_bool(SaveService.save_to_slot(2).success).is_true()
	SaveSlotTestHelpers.corrupt_slot_file(self, 2)

	var screen := _make_screen()

	assert_str(screen.get_slot_info_text(2)).is_equal(SlotSelectScreen.LABEL_CORRUPTED)


# 正常系（選択）


func test_新規スロットのボタン押下でactive_slotが更新されmainシーン遷移が要求される() -> void:
	var screen := _make_screen()

	screen.get_slot_button(2).pressed.emit()

	assert_int(SaveService.active_slot).is_equal(2)
	assert_bool(screen.has_requested_transition()).is_true()


func test_保存済みスロットのボタン押下でpending_restoreへ復元対象が保持される() -> void:
	GameState._set_gold_for_test(777)
	assert_bool(SaveService.save_to_slot(0).success).is_true()
	GameState._set_gold_for_test(0)

	var screen := _make_screen()
	screen.get_slot_button(0).pressed.emit()

	assert_int(SaveService.active_slot).is_equal(0)
	assert_int(int(SaveService._pending_restore["gold"])).is_equal(777)
	assert_bool(screen.has_requested_transition()).is_true()


# 異常系


func test_破損スロットのボタン押下でシグナルが発行され遷移は要求されない() -> void:
	assert_bool(SaveService.save_to_slot(1).success).is_true()
	SaveSlotTestHelpers.corrupt_slot_file(self, 1)

	var screen := _make_screen()
	monitor_signals(screen, false)

	screen.get_slot_button(1).pressed.emit()

	await assert_signal(screen).is_emitted(
		"slot_selection_failed", [1, SaveService.ERROR_SAVE_DATA_CORRUPTED]
	)
	assert_bool(screen.has_requested_transition()).is_false()
	assert_str(screen.get_slot_info_text(1)).is_equal(SlotSelectScreen.LABEL_CORRUPTED)


# ヘルパー


func _make_screen() -> SlotSelectScreen:
	var runner := scene_runner("res://features/save_load/ui/slot_select_screen.tscn")
	var screen := runner.scene() as SlotSelectScreen
	# 実際のシーン差し替えはGdUnit4のテストランナー自身のcurrent_sceneを巻き込むため抑止する
	screen.scene_transition_enabled = false
	return screen
