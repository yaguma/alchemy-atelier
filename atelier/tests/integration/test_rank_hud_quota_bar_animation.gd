extends GdUnitTestSuite

## ui-polish Plan タスク011: RankHud（常時表示の共通UI）のランクノルマバーも
## GuildDeliveryScreenと同じ演出を共有する（delivered受信時に滑らかに減少）。
## refresh(animate)のanimate=falseは従来通り即時反映（_ready()・他signal受信時）、
## animate=trueはUiEffects.animate_progress_value()を使いdelivered受信時のみ適用される。

const RANK_ID: StringName = &"rank_test"
const RANK_DISPLAY_NAME := "見習い"
const QUOTA_MAX := 100.0
const QUOTA_INITIAL := 80.0
const QUOTA_AFTER_DELIVERY := 50.0
const LIMIT_TURN := 10


func before_test() -> void:
	GameState.reset_for_test()
	_set_rank(QUOTA_MAX, QUOTA_INITIAL)


func _set_rank(quota_max: float, quota: float) -> void:
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.display_name = RANK_DISPLAY_NAME
	rank.quota_max = quota_max
	rank.limit_turn = LIMIT_TURN
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)
	var state := RankState.new()
	state.quota = quota
	GameState._set_rank_state_for_test(state)


func _make_hud() -> RankHud:
	var runner := scene_runner("res://shared/ui/rank_hud.tscn")
	return runner.scene() as RankHud


func _quota_bar(hud: RankHud) -> ProgressBar:
	return hud.find_child("QuotaBar", true, false) as ProgressBar


# 正常系


func test_readyの時点では即座に目標比率が反映される() -> void:
	var hud := _make_hud()

	assert_float(hud.get_quota_ratio()).is_equal_approx(QUOTA_INITIAL / QUOTA_MAX, 0.001)


func test_delivered受信直後は目標値へ即座に到達しない() -> void:
	var hud := _make_hud()
	_set_rank(QUOTA_MAX, QUOTA_AFTER_DELIVERY)

	GameState.delivered.emit([] as Array[DeliveryResult])

	assert_float(_quota_bar(hud).value).is_not_equal(QUOTA_AFTER_DELIVERY)


func test_delivered受信後Tween完了で目標値に一致する() -> void:
	var hud := _make_hud()
	_set_rank(QUOTA_MAX, QUOTA_AFTER_DELIVERY)

	GameState.delivered.emit([] as Array[DeliveryResult])
	await get_tree().create_timer(UiTheme.ANIM_DURATION_QUOTA_BAR + 0.1).timeout

	assert_float(_quota_bar(hud).value).is_equal_approx(QUOTA_AFTER_DELIVERY, 0.01)


func test_gold_changed受信では即座に目標値へ反映される() -> void:
	var hud := _make_hud()
	_set_rank(QUOTA_MAX, QUOTA_AFTER_DELIVERY)

	GameState._set_gold_for_test(500)
	GameState.gold_changed.emit(0, 500, 500)

	assert_float(_quota_bar(hud).value).is_equal_approx(QUOTA_AFTER_DELIVERY, 0.001)


# 境界値


func test_目標値が現在値と同じ場合でもクラッシュせずTween完了後に値が維持される() -> void:
	var hud := _make_hud()
	_set_rank(QUOTA_MAX, QUOTA_INITIAL)

	GameState.delivered.emit([] as Array[DeliveryResult])
	await get_tree().create_timer(UiTheme.ANIM_DURATION_QUOTA_BAR + 0.1).timeout

	assert_float(_quota_bar(hud).value).is_equal_approx(QUOTA_INITIAL, 0.01)
