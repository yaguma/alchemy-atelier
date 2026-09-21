extends GdUnitTestSuite

## DebugPanelがMainSceneに常時最前面の子として組み込まれ、庭・調合・工房・結果いずれの
## フェーズ表示中でも操作可能であることを検証する。debug-playtest-support Plan タスク003。
## DebugPanel自体のボタン結線（GameStateデバッグAPI呼び出し）の正常系・異常系・境界値は
## test_debug_panel.gd（task 002）が担っているため、本ファイルではMainSceneへの組み込みと
## 描画順、他画面表示との共存、およびRankHudとの連携のみを扱う。

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const RANK_ID: StringName = &"rank_g"
const NEXT_RANK_ID: StringName = &"rank_f"
const CURRENT_RANK_NAME := "現在ランク"
const NEXT_RANK_NAME := "次のランク"


func before_test() -> void:
	GameState.reset_for_test()


func _make_rank(
	rank_id: StringName, display_name: String, quota_max: float, limit_turn: int
) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = String(rank_id)
	rank.display_name = display_name
	rank.quota_max = quota_max
	rank.limit_turn = limit_turn
	rank.traits_unlocked = false
	rank.exam_turn_limit = 10
	return rank


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


func _find_debug_panel(main: MainScene) -> DebugPanel:
	return main.find_child("DebugPanel", true, false) as DebugPanel


func _find_button(panel: DebugPanel, button_name: String) -> Button:
	return panel.find_child(button_name, true, false) as Button


# 正常系


func test_MainScene直下にDebugPanelが存在する() -> void:
	var main := _make_main()

	var panel := _find_debug_panel(main)

	assert_object(panel).is_not_null()
	assert_object(panel.get_parent()).is_equal(main)


func test_DebugPanelは表示状態である() -> void:
	var main := _make_main()

	assert_bool(_find_debug_panel(main).visible).is_true()


func test_DebugPanelはSettingsOverlayLayerより後ろの子として描画順で最前面にある() -> void:
	var main := _make_main()

	var panel := _find_debug_panel(main)
	var settings_overlay_layer := main.find_child("SettingsOverlayLayer", true, false)

	assert_int(panel.get_index()).is_greater(settings_overlay_layer.get_index())


func test_庭調合工房結果いずれのフェーズ表示中もDebugPanelは表示され続ける() -> void:
	var main := _make_main()

	for phase in [&"garden", &"alchemy", &"workshop", &"result"]:
		GameState.set_phase(phase)

		assert_bool(_find_debug_panel(main).visible).is_true()


func test_調合フェーズ表示中にゴールド付与ボタンで所持ゴールドが増加する() -> void:
	var main := _make_main()
	GameState.set_phase(&"alchemy")
	GameState._set_gold_for_test(0)
	var panel := _find_debug_panel(main)

	_find_button(panel, "AddGoldButton").pressed.emit()

	assert_int(GameState.get_state()["gold"]).is_equal(1000)


# 異常系・境界値


## debug_jump_to_next_rank()はstate._current_rank_id等を直接書き換えるだけでシグナルを
## 発行しないため、MainScene側でRankHud.refresh()への結線を担う必要があることの確認
## （新規シグナルは追加しない。既存のButton.pressedとRankHud公開APIのみで結線する）。
## 🔴 MainScene._enter_tree()がload_rank_master_data()等で実データを読み込むため、
## フィクスチャの注入は必ずシーン生成の「後」に行う（先に注入すると実データで上書きされる。
## test_main_scene_exam_flow.gd _make_main()のコメント参照）
func test_次ランクへボタン押下後にRankHudのランク名表示が更新される() -> void:
	var main := _make_main()
	var masters: Dictionary = {
		RANK_ID: _make_rank(RANK_ID, CURRENT_RANK_NAME, 100.0, 30),
		NEXT_RANK_ID: _make_rank(NEXT_RANK_ID, NEXT_RANK_NAME, 200.0, 40),
	}
	GameState._set_rank_masters_for_test(masters)
	GameState._set_current_rank_id_for_test(RANK_ID)
	var rank_state := RankState.new()
	rank_state.quota = 30.0
	rank_state.elapsed_turn = 5
	GameState._set_rank_state_for_test(rank_state)
	var panel := _find_debug_panel(main)
	var rank_hud := main.find_child("RankHud", true, false) as RankHud

	_find_button(panel, "JumpRankButton").pressed.emit()

	assert_str(rank_hud.get_rank_name_text()).is_equal(NEXT_RANK_NAME)
