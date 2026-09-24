extends GdUnitTestSuite

## ui-polish Plan タスク015: 昇格試験中の試験ノルマ減少演出がタスク011で実装済みの
## GuildDeliveryScreen._refresh_rank_quota(animate)・RankHud._refresh_quota(animate)を
## そのまま流用できることを確認する回帰テスト（promotion-exam.md L87）。
## 🔵 コードレビュー確認済み: 両メソッドはin_exam分岐でexam_quota/exam_quota_maxを参照する
## だけで、UiEffects.animate_progress_value()を使うアニメーション自体は通常時と共通の
## 単一実装であり、試験専用の別実装（重複コード）は存在しない。

const RANK_ID: StringName = &"rank_test"
const RANK_DISPLAY_NAME := "見習い"
const EXAM_QUOTA_MAX := 30.0
const EXAM_QUOTA_INITIAL := 20.0
const EXAM_QUOTA_AFTER_DELIVERY := 5.0
const EXAM_TURN_LIMIT := 3


func before_test() -> void:
	GameState.reset_for_test()
	_set_exam(EXAM_QUOTA_MAX, EXAM_QUOTA_INITIAL)


func _set_exam(quota_max: float, quota: float) -> void:
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.display_name = RANK_DISPLAY_NAME
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)

	var exam_state := ExamState.new()
	exam_state.exam_quota_max = quota_max
	exam_state.exam_quota = quota
	exam_state.exam_turn_limit = EXAM_TURN_LIMIT
	GameState._set_exam_state_for_test(exam_state, true)


func _make_guild_delivery_screen() -> GuildDeliveryScreen:
	var runner := scene_runner("res://features/guild/ui/guild_delivery_screen.tscn")
	return runner.scene() as GuildDeliveryScreen


func _make_rank_hud() -> RankHud:
	var runner := scene_runner("res://shared/ui/rank_hud.tscn")
	return runner.scene() as RankHud


func _quota_bar(node: Control) -> ProgressBar:
	return node.find_child("QuotaBar", true, false) as ProgressBar


func _no_products() -> Array[ProductInstance]:
	return [] as Array[ProductInstance]


func _no_results() -> Array[DeliveryResult]:
	return [] as Array[DeliveryResult]


# 正常系


func test_試験中のdisplay_results呼び出し直後は試験ノルマの目標値へ即座に到達しない() -> void:
	var screen := _make_guild_delivery_screen()
	_set_exam(EXAM_QUOTA_MAX, EXAM_QUOTA_AFTER_DELIVERY)

	screen.display_results(_no_products(), _no_results())

	assert_float(_quota_bar(screen).value).is_not_equal(EXAM_QUOTA_AFTER_DELIVERY)


func test_試験中のdisplay_results呼び出し後Tween完了で試験ノルマの目標値に一致する() -> void:
	var screen := _make_guild_delivery_screen()
	_set_exam(EXAM_QUOTA_MAX, EXAM_QUOTA_AFTER_DELIVERY)

	screen.display_results(_no_products(), _no_results())
	await get_tree().create_timer(UiTheme.ANIM_DURATION_QUOTA_BAR + 0.1).timeout

	assert_float(_quota_bar(screen).value).is_equal_approx(EXAM_QUOTA_AFTER_DELIVERY, 0.01)


func test_試験中のRankHudもdelivered受信直後は試験ノルマの目標値へ即座に到達しない() -> void:
	var hud := _make_rank_hud()
	_set_exam(EXAM_QUOTA_MAX, EXAM_QUOTA_AFTER_DELIVERY)

	GameState.delivered.emit(_no_results())

	assert_float(_quota_bar(hud).value).is_not_equal(EXAM_QUOTA_AFTER_DELIVERY)


func test_試験中のRankHudもdelivered受信後Tween完了で試験ノルマの目標値に一致する() -> void:
	var hud := _make_rank_hud()
	_set_exam(EXAM_QUOTA_MAX, EXAM_QUOTA_AFTER_DELIVERY)

	GameState.delivered.emit(_no_results())
	await get_tree().create_timer(UiTheme.ANIM_DURATION_QUOTA_BAR + 0.1).timeout

	assert_float(_quota_bar(hud).value).is_equal_approx(EXAM_QUOTA_AFTER_DELIVERY, 0.01)


# 境界値


func test_試験開始直後の初期表示はノルマ変化がないためアニメーションなしで即時反映される() -> void:
	var screen := _make_guild_delivery_screen()

	assert_float(_quota_bar(screen).value).is_equal_approx(EXAM_QUOTA_INITIAL, 0.001)


func test_試験中でも目標値が現在値と同じ場合はTween完了後も値が維持される() -> void:
	var screen := _make_guild_delivery_screen()
	_set_exam(EXAM_QUOTA_MAX, EXAM_QUOTA_INITIAL)

	screen.display_results(_no_products(), _no_results())
	await get_tree().create_timer(UiTheme.ANIM_DURATION_QUOTA_BAR + 0.1).timeout

	assert_float(_quota_bar(screen).value).is_equal_approx(EXAM_QUOTA_INITIAL, 0.01)
