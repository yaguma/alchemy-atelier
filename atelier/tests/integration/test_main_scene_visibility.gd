extends GdUnitTestSuite

const MainSceneScene = preload("res://scenes/main.tscn")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scenes/main.gd"

const SCREEN_NODE_NAMES := ["GardenScreen", "AlchemyScreen", "WorkshopScreen", "ResultScreen"]


func before_test() -> void:
	GameState.reset_for_test()


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


## 4画面のうちvisible == trueのノード名を列挙する。排他性（ちょうど1つ）の検証に使う
func _visible_screen_names(main: MainScene) -> Array[String]:
	var names: Array[String] = []
	for node_name in SCREEN_NODE_NAMES:
		var screen := main.find_child(node_name, true, false) as Control
		if screen != null and screen.visible:
			names.append(node_name)
	return names


## GameStateのsignalに指定オブジェクトのCallableが接続されているかを判定する。
## 購読側のハンドラはprivateでテストから参照できないため、接続先オブジェクトで照合する
## （test_result_screen.gdの同名ヘルパー踏襲）
func _has_connection_to(target_signal: Signal, target: Object) -> bool:
	for connection in target_signal.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == target:
			return true
	return false


# 正常系


func test_ロード直後はgardenフェーズでGardenScreenのみ可視である() -> void:
	var main := _make_main()

	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_array(_visible_screen_names(main)).contains_exactly(["GardenScreen"])


func test_ready時に4機能のマスターデータがロードされる() -> void:
	_make_main()

	var state := GameState.get_state()

	assert_int((state["seed_masters"] as Dictionary).size()).is_greater(0)
	assert_int((state["recipe_masters"] as Dictionary).size()).is_greater(0)
	assert_int((state["upgrade_masters"] as Dictionary).size()).is_greater(0)
	assert_int(GameState._rank_masters.size()).is_greater(0)


## Godotは_ready()を子→親の順に呼ぶため、MainSceneの_ready()でロードしたのでは
## 4画面の初期描画に間に合わない。マスターデータ由来の表示（ランク名・ノルマバー）が
## フォールバック値のままになっていないことで、ロードが子より先に完了したことを検証する
func test_マスターデータのロードが子画面の初期描画より先に完了する() -> void:
	var main := _make_main()

	var rank_name_label := main.find_child("RankNameLabel", true, false) as Label
	var quota_bar := main.find_child("QuotaBar", true, false) as Range

	assert_object(rank_name_label).is_not_null()
	assert_str(rank_name_label.text).is_not_empty()
	assert_float(quota_bar.max_value).is_greater(0.0)


func test_set_phaseでalchemyへ切り替えるとAlchemyScreenのみ可視になる() -> void:
	var main := _make_main()

	GameState.set_phase(&"alchemy")

	assert_that(main.get_visible_phase()).is_equal(&"alchemy")
	assert_array(_visible_screen_names(main)).contains_exactly(["AlchemyScreen"])


func test_workshopとresultへの切替もそれぞれ対応画面のみ可視になる() -> void:
	var main := _make_main()

	GameState.set_phase(&"workshop")
	assert_array(_visible_screen_names(main)).contains_exactly(["WorkshopScreen"])

	GameState.set_phase(&"result")
	assert_array(_visible_screen_names(main)).contains_exactly(["ResultScreen"])


# 境界値


func test_連続してフェーズを切り替えても常にちょうど1画面のみ可視である() -> void:
	var main := _make_main()

	for phase in [&"alchemy", &"workshop", &"result", &"garden"]:
		GameState.set_phase(phase)

		assert_array(_visible_screen_names(main)).has_size(1)
		assert_that(main.get_visible_phase()).is_equal(phase)


func test_同じフェーズへ連続で切り替えても排他性が崩れない() -> void:
	var main := _make_main()

	GameState.set_phase(&"alchemy")
	GameState.set_phase(&"alchemy")

	assert_array(_visible_screen_names(main)).contains_exactly(["AlchemyScreen"])


# 異常系


func test_未知のフェーズ値では4画面いずれも可視にならない() -> void:
	var main := _make_main()

	GameState.set_phase(&"unknown")

	assert_array(_visible_screen_names(main)).is_empty()
	assert_that(main.get_visible_phase()).is_equal(&"")


func test_未知フェーズの後に既知フェーズへ戻すと復帰する() -> void:
	var main := _make_main()

	GameState.set_phase(&"unknown")
	GameState.set_phase(&"garden")

	assert_array(_visible_screen_names(main)).contains_exactly(["GardenScreen"])


func test_exit_tree後にphase_changedの購読が解除される() -> void:
	var main: MainScene = MainSceneScene.instantiate()
	add_child(main)

	assert_bool(_has_connection_to(GameState.phase_changed, main)).is_true()

	remove_child(main)

	assert_bool(_has_connection_to(GameState.phase_changed, main)).is_false()
	main.free()


## NFR-002: 本ゲームはターン制のため毎フレーム処理を持たない
func test_main_gdに_processが定義されていない() -> void:
	var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)

	assert_str(source).is_not_empty()
	assert_bool(source.contains("func _process")).is_false()
