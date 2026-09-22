extends GdUnitTestSuite


func _make_control() -> Control:
	var control: Control = auto_free(Control.new())
	add_child(control)
	return control


func _make_progress_bar() -> ProgressBar:
	var bar: ProgressBar = auto_free(ProgressBar.new())
	add_child(bar)
	return bar


# 正常系


func test_play_pop_inで有効なTweenが返りscaleがONEへ収束する() -> void:
	var target := _make_control()

	var tween := UiEffects.play_pop_in(target, 0.05, Tween.EASE_OUT)

	assert_object(tween).is_not_null()
	assert_bool(tween.is_valid()).is_true()
	assert_vector(target.scale).is_equal_approx(Vector2.ZERO, Vector2(0.01, 0.01))
	await tween.finished
	assert_vector(target.scale).is_equal_approx(Vector2.ONE, Vector2(0.01, 0.01))


func test_fly_ghostでoverlay_layerの子ノード数が1増える() -> void:
	var overlay := _make_control()
	var source := _make_control()
	source.global_position = Vector2(10, 10)
	var before_count := overlay.get_child_count()

	UiEffects.fly_ghost(overlay, source, Vector2(100, 100), 0.05)

	assert_int(overlay.get_child_count()).is_equal(before_count + 1)


func test_fly_ghost完了後にoverlay_layerの子ノード数が呼び出し前に戻る() -> void:
	var overlay := _make_control()
	var source := _make_control()
	source.global_position = Vector2(0, 0)
	var before_count := overlay.get_child_count()

	var tween := UiEffects.fly_ghost(overlay, source, Vector2(50, 50), 0.05)
	await tween.finished
	# queue_free()は次フレームまで反映されないため、1フレーム待つ
	await get_tree().process_frame

	assert_int(overlay.get_child_count()).is_equal(before_count)


func test_play_wither_fadeでmodulateのアルファが0へ向けて変化する() -> void:
	var target := _make_control()

	var tween := UiEffects.play_wither_fade(target, 0.05)

	assert_float(target.modulate.a).is_equal_approx(1.0, 0.001)
	await tween.finished


func test_animate_progress_valueで即座には目標値にならずTween完了後に一致する() -> void:
	var bar := _make_progress_bar()
	bar.max_value = 100
	bar.value = 0

	var tween := UiEffects.animate_progress_value(bar, 80.0, 0.05)

	assert_float(bar.value).is_not_equal(80.0)
	await tween.finished
	assert_float(bar.value).is_equal_approx(80.0, 0.01)


func test_play_highlight_pulseでTween完了後にself_modulateが元の色へ戻る() -> void:
	var target := _make_control()
	var original_color := target.self_modulate

	var tween := UiEffects.play_highlight_pulse(target, Color.RED, 0.05)

	await tween.finished

	assert_bool(target.self_modulate == original_color).is_true()


# 異常系・境界値


func test_duration0以下でもクラッシュせず即完了する(duration: float, _test_parameters := [[0.0], [-1.0]]) -> void:
	var target := _make_control()

	var tween := UiEffects.play_pop_in(target, duration, Tween.EASE_OUT)

	await tween.finished

	assert_vector(target.scale).is_equal_approx(Vector2.ONE, Vector2(0.01, 0.01))
