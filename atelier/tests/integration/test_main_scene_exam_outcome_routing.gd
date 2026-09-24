extends GdUnitTestSuite

## MainSceneとExamOutcomeOverlayの結線（ui-polish Plan タスク014）を検証する統合テスト。
## AlchemyScreen.exam_result_pending受信でオーバーレイが表示されるだけで画面遷移は行われず、
## acknowledged受信後に初めてSUCCESS→workshop/FAILURE→gardenへ遷移することを保証する。
## GameState.exam_outcome_confirmedの直接emitでAlchemyScreen（既にGameState.exam_outcome_confirmedを
## 購読済み）経由のexam_result_pending中継を発火させる点はtest_main_scene_exam_and_result_routing.gd
## と同型（本ファイルはExamOutcomeOverlay自体の表示・入力ブロックの観点に絞る）。

const MAIN_SCENE_PATH := "res://scenes/main.tscn"


func before_test() -> void:
	GameState.reset_for_test()


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


func _overlay(main: MainScene) -> ExamOutcomeOverlay:
	return main.find_child("ExamOutcomeOverlay", true, false) as ExamOutcomeOverlay


func _confirm_button(main: MainScene) -> Button:
	return _overlay(main).find_child("ConfirmButton", true, false) as Button


func _garden_tab(main: MainScene) -> Button:
	return main.find_child("GardenTabButton", true, false) as Button


# 正常系


func test_SUCCESS確定でオーバーレイが表示され遷移はまだ行われない() -> void:
	var main := _make_main()
	GameState.exam_started.emit()

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.SUCCESS)

	assert_bool(_overlay(main).visible).is_true()
	var label := _overlay(main).find_child("MessageLabel", true, false) as Label
	assert_str(label.text).is_equal(ExamOutcomeOverlay.SUCCESS_MESSAGE_TEXT)
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


func test_FAILURE確定でオーバーレイが表示され遷移はまだ行われない() -> void:
	var main := _make_main()
	GameState.exam_started.emit()

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.FAILURE)

	assert_bool(_overlay(main).visible).is_true()
	var label := _overlay(main).find_child("MessageLabel", true, false) as Label
	assert_str(label.text).is_equal(ExamOutcomeOverlay.FAILURE_MESSAGE_TEXT)
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


func test_SUCCESS確認後にworkshopへ遷移しオーバーレイが閉じる() -> void:
	var main := _make_main()
	GameState.exam_started.emit()
	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.SUCCESS)

	_confirm_button(main).pressed.emit()

	assert_that(main.get_visible_phase()).is_equal(&"workshop")
	assert_bool(_overlay(main).visible).is_false()
	assert_bool(main.get_is_garden_tab_disabled()).is_false()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_false()


func test_FAILURE確認後にgardenへ遷移しオーバーレイが閉じる() -> void:
	var main := _make_main()
	GameState.exam_started.emit()
	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.FAILURE)

	_confirm_button(main).pressed.emit()

	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_bool(_overlay(main).visible).is_false()
	assert_bool(main.get_is_garden_tab_disabled()).is_false()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_false()


# エッジケース


## エッジケース: オーバーレイ表示中は庭⇔調合タブの切替を受け付けない方針を固定する。
## タブはexam_started時点から無効化されており、SUCCESS/FAILURE確定後もacknowledgedを
## 受けるまで_set_tabs_disabled(false)が呼ばれないため、タブ押下は常にガードで弾かれる
## （_on_garden_tab_pressed()等のButton.disabledチェック。disabledはコード経由の
## pressed発行自体は止めないため、押下操作が空振りすることまで確認する）。
func test_オーバーレイ表示中はタブ押下で調合画面から離脱できない() -> void:
	var main := _make_main()
	GameState.exam_started.emit()
	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.SUCCESS)

	_garden_tab(main).pressed.emit()

	assert_that(main.get_visible_phase()).is_equal(&"alchemy")
	assert_bool(_overlay(main).visible).is_true()


# 異常系


## AlchemyScreenはCONTINUEでexam_result_pending自体を発行しないため、MainScene経由では
## 到達しないが、ExamOutcomeOverlay.show_outcome()自身に想定外の値を直接渡しても
## 表示状態が変化しない防御的分岐を、MainSceneが保持する実インスタンス越しに確認する
func test_オーバーレイへ直接CONTINUEを渡しても表示状態が変化しない() -> void:
	var main := _make_main()

	_overlay(main).show_outcome(ExamOutcome.Value.CONTINUE)

	assert_bool(_overlay(main).visible).is_false()
