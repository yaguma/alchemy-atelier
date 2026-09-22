extends GdUnitTestSuite

## ExamOutcomeOverlay（features/rank/ui/exam_outcome_overlay.gd）単体の表示切り替えを検証する
## 統合テスト（ui-polish Plan タスク014）。MainSceneとの結線・実遷移の検証は
## test_main_scene_exam_outcome_routing.gdへ分離する。

const OverlayScene = preload("res://features/rank/ui/exam_outcome_overlay.tscn")


func _make_overlay() -> ExamOutcomeOverlay:
	var overlay: ExamOutcomeOverlay = OverlayScene.instantiate()
	add_child(overlay)
	auto_free(overlay)
	return overlay


func _confirm_button(overlay: ExamOutcomeOverlay) -> Button:
	return overlay.find_child("ConfirmButton", true, false) as Button


func _message_label(overlay: ExamOutcomeOverlay) -> Label:
	return overlay.find_child("MessageLabel", true, false) as Label


func _wash(overlay: ExamOutcomeOverlay) -> ColorRect:
	return overlay.find_child("WashColorRect", true, false) as ColorRect


# 正常系


func test_SUCCESSでオーバーレイが表示され合格の文言が設定される() -> void:
	var overlay := _make_overlay()

	overlay.show_outcome(ExamOutcome.Value.SUCCESS)

	assert_bool(overlay.visible).is_true()
	assert_str(_message_label(overlay).text).is_equal(ExamOutcomeOverlay.SUCCESS_MESSAGE_TEXT)


func test_FAILUREでオーバーレイが表示され不合格の文言が設定される() -> void:
	var overlay := _make_overlay()

	overlay.show_outcome(ExamOutcome.Value.FAILURE)

	assert_bool(overlay.visible).is_true()
	assert_str(_message_label(overlay).text).is_equal(ExamOutcomeOverlay.FAILURE_MESSAGE_TEXT)


func test_SUCCESSとFAILUREでウォッシュ色が異なる() -> void:
	var overlay := _make_overlay()

	overlay.show_outcome(ExamOutcome.Value.SUCCESS)
	var success_color: Color = _wash(overlay).color

	overlay.show_outcome(ExamOutcome.Value.FAILURE)
	var failure_color: Color = _wash(overlay).color

	assert_bool(success_color == failure_color).is_false()


func test_確認ボタン押下でacknowledgedが発行され非表示に戻る() -> void:
	var overlay := _make_overlay()
	overlay.show_outcome(ExamOutcome.Value.SUCCESS)
	monitor_signals(overlay, false)  # 🔵 _make_overlay()側で既にauto_free()済みのため二重解放を避ける

	_confirm_button(overlay).pressed.emit()

	await assert_signal(overlay).is_emitted("acknowledged")
	assert_bool(overlay.visible).is_false()


# 異常系・境界値


## AlchemyScreen側はCONTINUEでexam_result_pending自体を発行しないため通常到達しないが、
## show_outcome()自身の防御的分岐として、想定外の値では表示状態を変化させないことを保証する
func test_CONTINUEを渡すと表示状態が変化しない() -> void:
	var overlay := _make_overlay()

	overlay.show_outcome(ExamOutcome.Value.CONTINUE)

	assert_bool(overlay.visible).is_false()
	assert_str(_message_label(overlay).text).is_equal("")


## 確認済み（非表示）の状態でCONTINUEが渡っても、直前に確定していた文言が上書きされずに残る
func test_確認後にCONTINUEを渡しても直前の表示内容が保持される() -> void:
	var overlay := _make_overlay()
	overlay.show_outcome(ExamOutcome.Value.SUCCESS)
	_confirm_button(overlay).pressed.emit()

	overlay.show_outcome(ExamOutcome.Value.CONTINUE)

	assert_bool(overlay.visible).is_false()
	assert_str(_message_label(overlay).text).is_equal(ExamOutcomeOverlay.SUCCESS_MESSAGE_TEXT)
