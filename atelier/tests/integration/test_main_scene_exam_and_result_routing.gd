extends GdUnitTestSuite

## MainSceneの昇格試験・終局ルーティング（FR-108〜FR-113, FR-201, FR-202, FR-403）の統合テスト。
## 中核は「commit_exam_outcome()が同一フレーム内でexam_outcome_confirmed→game_cleared/game_over
## の順に発行するケース」で、暫定遷移（workshop/garden）がresultへ正しく上書き確定すること。

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

const SCREEN_NODE_NAMES := ["GardenScreen", "AlchemyScreen", "WorkshopScreen", "ResultScreen"]


func before_test() -> void:
	GameState.reset_for_test()


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


func _screen(main: MainScene, node_name: String) -> Control:
	return main.find_child(node_name, true, false) as Control


func _visible_screen_names(main: MainScene) -> Array[String]:
	var names: Array[String] = []
	for node_name in SCREEN_NODE_NAMES:
		var screen := _screen(main, node_name)
		if screen != null and screen.visible:
			names.append(node_name)
	return names


func _current_phase() -> StringName:
	return GameState.get_state()["current_phase"]


# 正常系: 試験開始（FR-108, FR-201）


func test_exam_started受信でalchemyへ切り替わりタブが無効化される() -> void:
	var main := _make_main()

	GameState.exam_started.emit()

	assert_that(_current_phase()).is_equal(&"alchemy")
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")
	assert_bool(main.get_is_garden_tab_disabled()).is_true()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_true()


func test_庭以外から試験が開始されてもalchemyへ切り替わる() -> void:
	var main := _make_main()
	GameState.set_phase(&"workshop")

	GameState.exam_started.emit()

	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


# 正常系: 合否分岐（FR-109, FR-110）


func test_SUCCESSのみ発行された場合はworkshopへ遷移する() -> void:
	var main := _make_main()
	GameState.exam_started.emit()

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.SUCCESS)

	assert_that(_current_phase()).is_equal(&"workshop")
	assert_that(main.get_visible_phase()).is_equal(&"workshop")
	assert_bool(main.get_is_garden_tab_disabled()).is_false()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_false()


func test_FAILUREのみ発行された場合はgardenへ遷移する() -> void:
	var main := _make_main()
	GameState.exam_started.emit()

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.FAILURE)

	assert_that(_current_phase()).is_equal(&"garden")
	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_bool(main.get_is_garden_tab_disabled()).is_false()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_false()


# 正常系: 終局ルーティング（FR-111, FR-112, FR-113, FR-202）


## 【本Planの受入の中核】真の最終ランクでの試験成功。
## commit_exam_outcome()はexam_outcome_confirmed→game_clearedの順に同一フレームで発行するため、
## 暫定のworkshop遷移がresultへ上書きされて確定しなければならない。
func test_SUCCESS直後のgame_clearedでresultへ上書き確定する() -> void:
	var main := _make_main()
	GameState.exam_started.emit()
	monitor_signals(GameState, false)

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.SUCCESS)
	GameState.game_cleared.emit()

	await assert_signal(GameState).is_emitted("exam_outcome_confirmed", [ExamOutcome.Value.SUCCESS])
	await assert_signal(GameState).is_emitted("game_cleared")
	assert_that(_current_phase()).is_equal(&"result")
	assert_that(main.get_visible_phase()).is_equal(&"result")
	assert_bool(_screen(main, "WorkshopScreen").visible).is_false()
	assert_array(_visible_screen_names(main)).contains_exactly(["ResultScreen"])


## 【本Planの受入の中核】試験失敗と同時のゲームオーバー確定。
## 暫定のgarden遷移がresultへ上書きされて確定しなければならない。
func test_FAILURE直後のgame_overでresultへ上書き確定する() -> void:
	var main := _make_main()
	GameState.exam_started.emit()
	monitor_signals(GameState, false)

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.FAILURE)
	GameState.game_over.emit(3)

	await assert_signal(GameState).is_emitted("exam_outcome_confirmed", [ExamOutcome.Value.FAILURE])
	await assert_signal(GameState).is_emitted("game_over", [3])
	assert_that(_current_phase()).is_equal(&"result")
	assert_that(main.get_visible_phase()).is_equal(&"result")
	assert_bool(_screen(main, "GardenScreen").visible).is_false()
	assert_array(_visible_screen_names(main)).contains_exactly(["ResultScreen"])


func test_game_cleared単独発行でもresultへ遷移しタブが無効化される() -> void:
	var main := _make_main()

	GameState.game_cleared.emit()

	assert_that(main.get_visible_phase()).is_equal(&"result")
	assert_bool(main.get_is_garden_tab_disabled()).is_true()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_true()


func test_game_over単独発行でもresultへ遷移しタブが無効化される() -> void:
	var main := _make_main()

	GameState.game_over.emit(1)

	assert_that(main.get_visible_phase()).is_equal(&"result")
	assert_bool(main.get_is_garden_tab_disabled()).is_true()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_true()


# 境界値


## FAILURE→_set_tabs_disabled(false)→直後のgame_over→_set_tabs_disabled(true)という
## 同一フレーム内の二重更新でも、最終的にdisabled == trueで確定することを明示的に確認する。
func test_FAILURE直後のgame_overでもタブは最終的に無効化された状態で確定する() -> void:
	var main := _make_main()
	GameState.exam_started.emit()

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.FAILURE)
	GameState.game_over.emit(3)

	assert_bool(main.get_is_garden_tab_disabled()).is_true()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_true()


func test_SUCCESS直後のgame_clearedでもタブは最終的に無効化された状態で確定する() -> void:
	var main := _make_main()
	GameState.exam_started.emit()

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.SUCCESS)
	GameState.game_cleared.emit()

	assert_bool(main.get_is_garden_tab_disabled()).is_true()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_true()


func test_exam_outcome_confirmedのCONTINUEではフェーズが変化しない() -> void:
	var main := _make_main()
	GameState.exam_started.emit()

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.CONTINUE)

	assert_that(_current_phase()).is_equal(&"alchemy")
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")
	assert_bool(main.get_is_garden_tab_disabled()).is_true()


# 異常系


## FR-403は「MainSceneがresultから自動的に復帰しない」ことのみを規定しており、
## 外部からのset_phase()による強制遷移までは防がない設計とする。
## 🟡 result表示後の強制遷移を防御する必要が生じた場合は、本タスクの範囲外として別途Issue化を検討する。
func test_result表示後の外部set_phaseは本タスクではガードされない() -> void:
	var main := _make_main()
	GameState.game_cleared.emit()

	GameState.set_phase(&"garden")

	assert_that(main.get_visible_phase()).is_equal(&"garden")


## FR-403。終局後にMainScene自身の都合でresultから抜けることはない
## （終局シグナル以降、MainSceneは自発的なフェーズ変更を行わない）。
func test_終局後に試験系シグナルが再発行されてもMainSceneはresultから復帰しない() -> void:
	var main := _make_main()
	GameState.game_over.emit(3)

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.CONTINUE)

	assert_that(main.get_visible_phase()).is_equal(&"result")
