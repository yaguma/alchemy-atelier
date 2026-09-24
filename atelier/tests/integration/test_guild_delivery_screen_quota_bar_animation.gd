extends GdUnitTestSuite

## ui-polish Plan タスク011: ギルド納品画面の貢献度反映時にランクノルマバーが滑らかに減少する
## 演出を検証する（ui-design/screens/guild-delivery.md L70）。_refresh_rank_quota(animate)の
## animate=falseは従来通り即時反映（_ready()からの初期呼び出し）、animate=trueは
## UiEffects.animate_progress_value()を使いdisplay_results()（結果表示処理）から呼ばれる。

const RANK_ID: StringName = &"rank_test"
const RANK_DISPLAY_NAME := "見習い"
const QUOTA_MAX := 100.0
const QUOTA_INITIAL := 80.0
const QUOTA_AFTER_DELIVERY := 50.0


func before_test() -> void:
	GameState.reset_for_test()
	_set_rank(QUOTA_MAX, QUOTA_INITIAL)


func _set_rank(quota_max: float, quota: float) -> void:
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.display_name = RANK_DISPLAY_NAME
	rank.quota_max = quota_max
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)
	var state := RankState.new()
	state.quota = quota
	GameState._set_rank_state_for_test(state)


func _make_screen() -> GuildDeliveryScreen:
	var runner := scene_runner("res://features/guild/ui/guild_delivery_screen.tscn")
	return runner.scene() as GuildDeliveryScreen


func _quota_bar(screen: GuildDeliveryScreen) -> ProgressBar:
	return screen.find_child("QuotaBar", true, false) as ProgressBar


func _no_products() -> Array[ProductInstance]:
	return [] as Array[ProductInstance]


func _no_results() -> Array[DeliveryResult]:
	return [] as Array[DeliveryResult]


# 正常系


func test_readyの時点では即座に目標値が反映される() -> void:
	var screen := _make_screen()

	assert_float(_quota_bar(screen).value).is_equal_approx(QUOTA_INITIAL, 0.001)


func test_display_results呼び出し直後は目標値へ即座に到達しない() -> void:
	var screen := _make_screen()
	_set_rank(QUOTA_MAX, QUOTA_AFTER_DELIVERY)

	screen.display_results(_no_products(), _no_results())

	assert_float(_quota_bar(screen).value).is_not_equal(QUOTA_AFTER_DELIVERY)


func test_display_results呼び出し後Tween完了で目標値に一致する() -> void:
	var screen := _make_screen()
	_set_rank(QUOTA_MAX, QUOTA_AFTER_DELIVERY)

	screen.display_results(_no_products(), _no_results())
	await get_tree().create_timer(UiTheme.ANIM_DURATION_QUOTA_BAR + 0.1).timeout

	assert_float(_quota_bar(screen).value).is_equal_approx(QUOTA_AFTER_DELIVERY, 0.01)


# 境界値


func test_目標値が現在値と同じ場合でもクラッシュせずTween完了後に値が維持される() -> void:
	var screen := _make_screen()
	_set_rank(QUOTA_MAX, QUOTA_INITIAL)

	screen.display_results(_no_products(), _no_results())
	await get_tree().create_timer(UiTheme.ANIM_DURATION_QUOTA_BAR + 0.1).timeout

	assert_float(_quota_bar(screen).value).is_equal_approx(QUOTA_INITIAL, 0.01)
