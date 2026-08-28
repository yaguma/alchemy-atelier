extends GdUnitTestSuite

const MainSceneScene = preload("res://scenes/main.tscn")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const GARDEN_SCRIPT_PATH := "res://features/garden/ui/garden_screen.gd"
const ALCHEMY_SCRIPT_PATH := "res://features/alchemy/ui/alchemy_screen.gd"

const SCREEN_NODE_NAMES := ["GardenScreen", "AlchemyScreen", "WorkshopScreen", "ResultScreen"]

var _phase_changes: Array[Array] = []


func before_test() -> void:
	GameState.reset_for_test()
	_phase_changes = []


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


func _garden_tab(main: MainScene) -> Button:
	return main.find_child("GardenTabButton", true, false) as Button


func _alchemy_tab(main: MainScene) -> Button:
	return main.find_child("AlchemyTabButton", true, false) as Button


## 4画面のうちvisible == trueのノード名を列挙する（test_main_scene_visibility.gd踏襲）
func _visible_screen_names(main: MainScene) -> Array[String]:
	var names: Array[String] = []
	for node_name in SCREEN_NODE_NAMES:
		var screen := main.find_child(node_name, true, false) as Control
		if screen != null and screen.visible:
			names.append(node_name)
	return names


## GameStateのsignalに指定オブジェクトのCallableが接続されているかを判定する
func _has_connection_to(target_signal: Signal, target: Object) -> bool:
	for connection in target_signal.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == target:
			return true
	return false


func _record_phase_changes() -> void:
	GameState.phase_changed.connect(_on_phase_changed_for_record)


func _on_phase_changed_for_record(previous: StringName, next: StringName) -> void:
	_phase_changes.append([previous, next])


func after_test() -> void:
	if GameState.phase_changed.is_connected(_on_phase_changed_for_record):
		GameState.phase_changed.disconnect(_on_phase_changed_for_record)


# 正常系


func test_調合タブ押下でalchemyへ遷移しAlchemyScreenのみ可視になる() -> void:
	var main := _make_main()
	_record_phase_changes()

	_alchemy_tab(main).pressed.emit()

	assert_array(_phase_changes).contains_exactly([[&"garden", &"alchemy"]])
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")
	assert_array(_visible_screen_names(main)).contains_exactly(["AlchemyScreen"])


func test_庭タブ押下でgardenへ戻りGardenScreenのみ可視になる() -> void:
	var main := _make_main()
	GameState.set_phase(&"alchemy")
	_record_phase_changes()

	_garden_tab(main).pressed.emit()

	assert_array(_phase_changes).contains_exactly([[&"alchemy", &"garden"]])
	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_array(_visible_screen_names(main)).contains_exactly(["GardenScreen"])


func test_選択中のタブのみbutton_pressedで強調表示される() -> void:
	var main := _make_main()

	assert_bool(_garden_tab(main).button_pressed).is_true()
	assert_bool(_alchemy_tab(main).button_pressed).is_false()

	GameState.set_phase(&"alchemy")

	assert_bool(_garden_tab(main).button_pressed).is_false()
	assert_bool(_alchemy_tab(main).button_pressed).is_true()


func test_タブバー対象外のフェーズでは両タブとも非選択表示になる() -> void:
	var main := _make_main()

	GameState.set_phase(&"workshop")

	assert_bool(_garden_tab(main).button_pressed).is_false()
	assert_bool(_alchemy_tab(main).button_pressed).is_false()


func test_タブはtoggle_modeが有効である() -> void:
	var main := _make_main()

	assert_bool(_garden_tab(main).toggle_mode).is_true()
	assert_bool(_alchemy_tab(main).toggle_mode).is_true()


# 回帰確認（本タスクは庭/調合画面自体を改修しない）


func test_garden_screenのsignal宣言がshop_requestedのみである() -> void:
	var source := FileAccess.get_file_as_string(GARDEN_SCRIPT_PATH)

	assert_str(source).is_not_empty()
	assert_int(source.count("\nsignal ")).is_equal(1)
	assert_bool(source.contains("signal shop_requested")).is_true()


## task006でdelivery_confirmed（GuildDeliveryScreen.screen_closedの中継）が追加されたため、
## AlchemyScreenが公開するsignalはshop_requestedとdelivery_confirmedの2本に限られる
func test_alchemy_screenのsignal宣言がshop_requestedとdelivery_confirmedのみである() -> void:
	var source := FileAccess.get_file_as_string(ALCHEMY_SCRIPT_PATH)

	assert_str(source).is_not_empty()
	assert_int(source.count("\nsignal ")).is_equal(2)
	assert_bool(source.contains("signal shop_requested")).is_true()
	assert_bool(source.contains("signal delivery_confirmed")).is_true()


# 試験中のタブ制御（FR-201, FR-202）


func test_exam_started受信後に両タブがdisabledになる() -> void:
	var main := _make_main()

	GameState.exam_started.emit()

	assert_bool(main.get_is_garden_tab_disabled()).is_true()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_true()


func test_exam_outcome_confirmedのSUCCESSでdisabledが解除される() -> void:
	var main := _make_main()
	GameState.exam_started.emit()

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.SUCCESS)

	assert_bool(main.get_is_garden_tab_disabled()).is_false()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_false()


func test_exam_outcome_confirmedのFAILUREでdisabledが解除される() -> void:
	var main := _make_main()
	GameState.exam_started.emit()

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.FAILURE)

	assert_bool(main.get_is_garden_tab_disabled()).is_false()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_false()


# 境界値


func test_exam_outcome_confirmedのCONTINUEではdisabledが維持される() -> void:
	var main := _make_main()
	GameState.exam_started.emit()

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.CONTINUE)

	assert_bool(main.get_is_garden_tab_disabled()).is_true()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_true()


func test_現在表示中のタブを再度押下しても表示状態が壊れない() -> void:
	var main := _make_main()
	_record_phase_changes()

	_garden_tab(main).pressed.emit()
	_garden_tab(main).pressed.emit()

	assert_array(_phase_changes).contains_exactly([[&"garden", &"garden"], [&"garden", &"garden"]])
	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_array(_visible_screen_names(main)).contains_exactly(["GardenScreen"])
	assert_bool(_garden_tab(main).button_pressed).is_true()


# 異常系


func test_試験中に庭タブのpressedを強制発行してもフェーズが変化しない() -> void:
	var main := _make_main()
	GameState.set_phase(&"alchemy")
	GameState.exam_started.emit()
	_record_phase_changes()

	_garden_tab(main).pressed.emit()

	assert_array(_phase_changes).is_empty()
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


## task008でexam_startedがalchemyへの遷移を伴うようになった（FR-108）ため、
## 試験開始時点の表示フェーズはgardenではなくalchemyになる。
## 本テストの主眼である「タブ押下がフェーズを変えないこと」は_phase_changesの空判定が担う
func test_試験中に調合タブのpressedを強制発行してもフェーズが変化しない() -> void:
	var main := _make_main()
	GameState.exam_started.emit()
	_record_phase_changes()

	_alchemy_tab(main).pressed.emit()

	assert_array(_phase_changes).is_empty()
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


func test_exit_tree後に試験系シグナルの購読が解除される() -> void:
	var main: MainScene = MainSceneScene.instantiate()
	add_child(main)

	assert_bool(_has_connection_to(GameState.exam_started, main)).is_true()
	assert_bool(_has_connection_to(GameState.exam_outcome_confirmed, main)).is_true()

	remove_child(main)

	assert_bool(_has_connection_to(GameState.exam_started, main)).is_false()
	assert_bool(_has_connection_to(GameState.exam_outcome_confirmed, main)).is_false()
	main.free()
