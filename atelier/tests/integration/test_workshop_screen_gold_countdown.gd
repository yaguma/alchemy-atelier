extends GdUnitTestSuite

## ui-polish Plan タスク016: 購入成功時のゴールドカウントダウン演出のテスト


func before_test() -> void:
	GameState.reset_for_test()


func _make_screen() -> WorkshopScreen:
	var runner := scene_runner("res://features/workshop/ui/workshop_screen.tscn")
	return runner.scene() as WorkshopScreen


func _find_gold_label(screen: WorkshopScreen) -> Label:
	return screen.find_child("GoldLabel", true, false) as Label


func _find_consumable_list(screen: WorkshopScreen) -> UpgradeItemList:
	return screen.find_child("ConsumableList", true, false) as UpgradeItemList


# 正常系


func test_購入成功直後はゴールド表示が即座に購入後の値にならない() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(100)
	var screen := _make_screen()

	_find_consumable_list(screen).purchase_requested.emit(&"upgrade_seed_name_purchase_ore")

	assert_str(_find_gold_label(screen).text).is_not_equal("50 G")


func test_購入成功後カウントダウン完了時にゴールド表示が購入後の値になる() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(100)
	var screen := _make_screen()

	_find_consumable_list(screen).purchase_requested.emit(&"upgrade_seed_name_purchase_ore")
	await get_tree().create_timer(UiTheme.ANIM_DURATION_GOLD_COUNTDOWN + 0.1).timeout

	assert_str(_find_gold_label(screen).text).is_equal("50 G")


func test_連続で呼び出すと前回のカウントダウンTweenがkillされる() -> void:
	# 🔴 コードレビュー指摘対応。連打購入等で短時間に_animate_gold_countdown()が連続呼び出しされると、
	# 前回のTweenが生存したまま新しいTweenが同じ_gold_labelを奪い合い表示がちらつく/逆戻りする
	# 競合があった。UiEffects.kill_active_tween()連携により前回Tweenがkillされることを検証する
	var screen := _make_screen()

	var first_tween: Tween = screen._animate_gold_countdown(
		100, 50, UiTheme.ANIM_DURATION_GOLD_COUNTDOWN
	)
	var second_tween: Tween = screen._animate_gold_countdown(
		50, 20, UiTheme.ANIM_DURATION_GOLD_COUNTDOWN
	)

	assert_bool(first_tween.is_valid()).is_false()
	await second_tween.finished
	assert_str(_find_gold_label(screen).text).is_equal("20 G")


func test_カウントダウン中の中間値はfromとtoの範囲内に収まる() -> void:
	var screen := _make_screen()
	var observed_values: Array[int] = []

	var tween: Tween = screen._animate_gold_countdown(100, 50, UiTheme.ANIM_DURATION_GOLD_COUNTDOWN)
	tween.custom_step(UiTheme.ANIM_DURATION_GOLD_COUNTDOWN / 2.0)
	var text := _find_gold_label(screen).text
	var value := int(text.replace(" G", ""))
	observed_values.append(value)

	for v in observed_values:
		assert_int(v).is_between(50, 100)


# 異常系


func test_購入失敗時はカウントダウンが発生せずゴールド表示が変化しない() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(10)
	var screen := _make_screen()

	_find_consumable_list(screen).purchase_requested.emit(&"upgrade_seed_name_purchase_ore")
	await get_tree().create_timer(UiTheme.ANIM_DURATION_GOLD_COUNTDOWN + 0.1).timeout

	assert_str(_find_gold_label(screen).text).is_equal("10 G")


# 境界値


func test_fromとtoが同じ値でもクラッシュせず即座に一致した値になる() -> void:
	var screen := _make_screen()
	_find_gold_label(screen).text = "0 G"

	var tween: Tween = screen._animate_gold_countdown(
		100, 100, UiTheme.ANIM_DURATION_GOLD_COUNTDOWN
	)
	await tween.finished

	assert_str(_find_gold_label(screen).text).is_equal("100 G")
