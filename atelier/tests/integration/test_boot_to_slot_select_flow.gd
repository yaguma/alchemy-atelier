extends GdUnitTestSuite

## スロット選択→ゲーム再開/新規開始のエンドツーエンド結線を検証する。
## MainScene._enter_tree()末尾でのSaveService.apply_pending_restore()呼び出しが対象。
## SaveService単体の保存/復元挙動はtest_save_service_pending_restore.gdが、
## スロット選択画面のUI挙動はtest_slot_select_screen.gdが、
## BootSceneの遷移先はtest_boot_scene.gdがカバー済みのため、
## 本ファイルは「シーン起動を跨いで値が繋がるか」のみを扱う。

const SaveSlotTestHelpers = preload("res://tests/mocks/save_slot_test_helpers.gd")

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

## 🟡 実データ上「item条件・target_recipe_id=recipe_mana_tonic」の依頼。初期解禁レシピは
## recipe_healing_potionのみのためMainScene起動時の抽選（reroll_daily_order）では絶対に
## 選ばれない。よって復元後にこのIDが残っていれば「抽選結果を復元が上書きした」と断定できる
const RESTORE_ONLY_DAILY_ORDER_ID := "daily_order_mana_tonic"

const SAVED_GOLD := 500


func before_test() -> void:
	GameState.reset_for_test()
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()


func after_test() -> void:
	SaveService.reset_for_test()
	SaveSlotTestHelpers.cleanup_slots()
	GameState.reset_for_test()


# 正常系: E2Eラウンドトリップ


func test_スロット未選択でmainを起動すると初期状態のまま開始する() -> void:
	_make_main()

	var state := GameState.get_state()
	assert_int(state["gold"]).is_equal(0)
	assert_str(String(state["current_phase"])).is_equal("garden")
	assert_int(SaveService.active_slot).is_equal(-1)


func test_保存済みスロット選択後にmainを起動すると保存時のゴールドが復元される() -> void:
	_save_current_progress_to_slot(0)
	GameState.reset_for_test()
	assert_bool(SaveService.select_slot_and_restore(0).success).is_true()

	_make_main()

	assert_int(GameState.get_state()["gold"]).is_equal(SAVED_GOLD)


func test_復元された指定依頼が起動時の抽選結果より優先される() -> void:
	_load_all_master_data()
	var order := DailyOrderMaster.new()
	order.id = RESTORE_ONLY_DAILY_ORDER_ID
	GameState._set_current_daily_order_for_test(order)
	assert_bool(SaveService.save_to_slot(1).success).is_true()
	GameState.reset_for_test()
	assert_bool(SaveService.select_slot_and_restore(1).success).is_true()

	_make_main()

	var resolved := GameState.resolve_daily_order_for_delivery()
	assert_object(resolved).is_not_null()
	assert_str(resolved.id).is_equal(RESTORE_ONLY_DAILY_ORDER_ID)


# 異常系・境界値


func test_新規スロット選択後にmainを起動しても初期状態のまま開始する() -> void:
	assert_bool(SaveService.select_slot_and_restore(2).success).is_true()

	_make_main()

	var state := GameState.get_state()
	assert_int(state["gold"]).is_equal(0)
	assert_str(String(state["current_phase"])).is_equal("garden")
	assert_bool(SaveService._pending_restore.is_empty()).is_true()


func test_apply_pending_restoreはmain起動後に保留を持ち越さない() -> void:
	_save_current_progress_to_slot(0)
	GameState.reset_for_test()
	assert_bool(SaveService.select_slot_and_restore(0).success).is_true()

	_make_main()

	assert_bool(SaveService._pending_restore.is_empty()).is_true()


# ヘルパー


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


## MainScene._enter_tree()と同じ順序でマスターデータをロードする。
## プレイ途中の現実的なスナップショットを保存するために使う
func _load_all_master_data() -> void:
	GameState.load_garden_master_data()
	GameState.load_alchemy_master_data()
	GameState.load_workshop_master_data()
	GameState.load_rank_master_data()
	GameState.load_daily_order_master_data()


func _save_current_progress_to_slot(slot: int) -> void:
	_load_all_master_data()
	GameState._set_gold_for_test(SAVED_GOLD)
	assert_bool(SaveService.save_to_slot(slot).success).is_true()
