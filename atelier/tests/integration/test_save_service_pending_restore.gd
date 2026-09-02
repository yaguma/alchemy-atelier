extends GdUnitTestSuite

const SaveSlotTestHelpers = preload("res://tests/mocks/save_slot_test_helpers.gd")


func before_test() -> void:
	GameState.reset_for_test()
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()


func after_test() -> void:
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()


# 正常系


func test_空スロットのselect_slot_and_restoreは成功しactive_slotを記憶する() -> void:
	var result := SaveService.select_slot_and_restore(0)

	assert_bool(result.success).is_true()
	assert_int(SaveService.active_slot).is_equal(0)
	assert_bool(SaveService._pending_restore.is_empty()).is_true()


func test_保存済みスロットのselect_slot_and_restoreがpending_restoreへ保持する() -> void:
	GameState._set_gold_for_test(777)
	assert_bool(SaveService.save_to_slot(1).success).is_true()
	GameState._set_gold_for_test(0)

	var result := SaveService.select_slot_and_restore(1)

	assert_bool(result.success).is_true()
	assert_int(SaveService.active_slot).is_equal(1)
	assert_int(int(SaveService._pending_restore["gold"])).is_equal(777)
	# この時点ではGameStateへ書き込まない（マスターデータ未ロードの可能性があるため）
	assert_int(int(GameState.get_state()["gold"])).is_equal(0)


func test_apply_pending_restoreがGameStateへ適用しpendingをクリアする() -> void:
	GameState._set_gold_for_test(555)
	assert_bool(SaveService.save_to_slot(0).success).is_true()
	GameState._set_gold_for_test(0)
	assert_bool(SaveService.select_slot_and_restore(0).success).is_true()

	SaveService.apply_pending_restore()

	assert_int(int(GameState.get_state()["gold"])).is_equal(555)
	assert_bool(SaveService._pending_restore.is_empty()).is_true()


func test_pending_restoreが空ならapply_pending_restoreはGameStateを変更しない() -> void:
	GameState._set_gold_for_test(42)
	assert_bool(SaveService.select_slot_and_restore(0).success).is_true()

	SaveService.apply_pending_restore()

	assert_int(int(GameState.get_state()["gold"])).is_equal(42)


func test_active_slot設定後のautosaveがスロットを更新する() -> void:
	assert_bool(SaveService.select_slot_and_restore(2).success).is_true()
	GameState._set_gold_for_test(320)

	SaveService.autosave()

	assert_int(SaveService.get_slot_summary(2).gold).is_equal(320)


# 異常系・境界値


func test_破損スロットのselect_slot_and_restoreは失敗しpendingを空のままにする() -> void:
	GameState._set_gold_for_test(1234)
	assert_bool(SaveService.save_to_slot(2).success).is_true()
	SaveSlotTestHelpers.corrupt_slot_file(self, 2)

	var result := SaveService.select_slot_and_restore(2)

	assert_bool(result.success).is_false()
	assert_str(String(result.error_code)).is_equal("save_data_corrupted")
	assert_bool(SaveService._pending_restore.is_empty()).is_true()


func test_active_slot未選択のautosaveはファイルを作らない() -> void:
	SaveService.autosave()

	for slot in range(SaveService.SLOT_COUNT):
		assert_bool(FileAccess.file_exists(SaveService._slot_path(slot))).is_false()


func test_範囲外スロットのselect_slot_and_restoreは失敗する() -> void:
	assert_bool(SaveService.select_slot_and_restore(-1).success).is_false()
	assert_bool(SaveService.select_slot_and_restore(SaveService.SLOT_COUNT).success).is_false()
	assert_int(SaveService.active_slot).is_equal(-1)
