extends GdUnitTestSuite

const SCENE_PATH := "res://shared/ui/rank_hud.tscn"
const RANK_ID: StringName = &"rank_test"
const RANK_DISPLAY_NAME := "見習い"
const QUOTA_MAX := 100.0
const QUOTA_REMAINING := 40.0
const LIMIT_TURN := 10

# 🔵 FR-114。RankHudが購読するGameState signalの網羅一覧（購読解除検証で使う）
const HUD_SIGNAL_NAMES: Array[String] = [
	"gold_changed",
	"turn_growth_advanced",
	"rank_outcome_confirmed",
	"delivered",
	"exam_started",
	"exam_outcome_confirmed",
]


var _settings_requested_count := 0
var _phase_changed_count := 0


func before_test() -> void:
	GameState.reset_for_test()
	_set_rank(QUOTA_MAX, QUOTA_REMAINING, LIMIT_TURN, 0)
	_settings_requested_count = 0
	_phase_changed_count = 0


func after_test() -> void:
	if GameState.phase_changed.is_connected(_on_phase_changed_for_test):
		GameState.phase_changed.disconnect(_on_phase_changed_for_test)


func _on_settings_requested_for_test() -> void:
	_settings_requested_count += 1


func _on_phase_changed_for_test(_previous: StringName, _next: StringName) -> void:
	_phase_changed_count += 1


func _set_rank(quota_max: float, quota: float, limit_turn: int, elapsed_turn: int) -> void:
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.display_name = RANK_DISPLAY_NAME
	rank.quota_max = quota_max
	rank.limit_turn = limit_turn
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)
	var rank_state := RankState.new()
	rank_state.quota = quota
	rank_state.elapsed_turn = elapsed_turn
	GameState._set_rank_state_for_test(rank_state)


func _make_hud() -> RankHud:
	var runner := scene_runner(SCENE_PATH)
	return runner.scene() as RankHud


func _connection_counts() -> Dictionary:
	var counts := {}
	for signal_name in HUD_SIGNAL_NAMES:
		counts[signal_name] = GameState.get_signal_connection_list(signal_name).size()
	return counts


# 正常系


func test_readyの時点でランク名がマスターの表示名になる() -> void:
	var hud := _make_hud()

	assert_str(hud.get_rank_name_text()).is_equal(RANK_DISPLAY_NAME)


func test_readyの時点でゴールドと残ターンが初期値を反映する() -> void:
	GameState._set_gold_for_test(120)
	var hud := _make_hud()

	assert_str(hud.get_gold_text()).contains("120")
	assert_str(hud.get_turn_remaining_text()).contains("10")


func test_gold_changed受信でゴールド表示が更新される() -> void:
	var hud := _make_hud()

	GameState._set_gold_for_test(350)
	GameState.gold_changed.emit(0, 350, 350)

	assert_str(hud.get_gold_text()).contains("350")


func test_turn_growth_advanced受信で残ターン表示が更新される() -> void:
	var hud := _make_hud()

	_set_rank(QUOTA_MAX, QUOTA_REMAINING, LIMIT_TURN, 3)
	GameState.turn_growth_advanced.emit(3)

	assert_str(hud.get_turn_remaining_text()).contains("7")


func test_delivered受信でノルマ比率が更新される() -> void:
	var hud := _make_hud()

	_set_rank(QUOTA_MAX, 10.0, LIMIT_TURN, 0)
	GameState.delivered.emit([] as Array[DeliveryResult])

	assert_float(hud.get_quota_ratio()).is_equal_approx(0.1, 0.001)


func test_ノルマ比率が残量と上限の比になる() -> void:
	var hud := _make_hud()

	assert_float(hud.get_quota_ratio()).is_equal_approx(QUOTA_REMAINING / QUOTA_MAX, 0.001)


func test_昇格試験中は試験ノルマと試験残ターンを表示する() -> void:
	var exam_state := ExamState.new()
	exam_state.exam_quota = 15.0
	exam_state.exam_quota_max = 60.0
	exam_state.exam_elapsed_turn = 1
	exam_state.exam_turn_limit = 5
	GameState._set_exam_state_for_test(exam_state, true)
	var hud := _make_hud()

	assert_str(hud.get_rank_name_text()).is_equal(
		RANK_DISPLAY_NAME + RankHud.EXAM_RANK_LABEL_SUFFIX
	)
	assert_float(hud.get_quota_ratio()).is_equal_approx(0.25, 0.001)
	assert_str(hud.get_turn_remaining_text()).contains("4")


func test_readyの時点で歯車ボタンが存在し押下可能である() -> void:
	var hud := _make_hud()

	var button: Button = hud.get_settings_button()
	assert_object(button).is_not_null()
	assert_bool(button.disabled).is_false()


func test_歯車ボタン押下でsettings_requestedが発行される() -> void:
	var hud := _make_hud()
	hud.settings_requested.connect(_on_settings_requested_for_test)

	hud.get_settings_button().pressed.emit()

	assert_int(_settings_requested_count).is_equal(1)


func test_昇格試験中でも歯車ボタンが押下可能である() -> void:
	var exam_state := ExamState.new()
	exam_state.exam_quota = 15.0
	exam_state.exam_quota_max = 60.0
	exam_state.exam_elapsed_turn = 1
	exam_state.exam_turn_limit = 5
	GameState._set_exam_state_for_test(exam_state, true)
	var hud := _make_hud()
	hud.settings_requested.connect(_on_settings_requested_for_test)

	assert_bool(hud.get_settings_button().disabled).is_false()
	hud.get_settings_button().pressed.emit()

	assert_int(_settings_requested_count).is_equal(1)


# 🔵 RankHudの自己完結方針（状態変更・フェーズ遷移を行わない）の維持確認。
# set_phase()はphase_changedをemitするため、その発行回数0で呼び出しなしを検証する
func test_歯車ボタン押下でフェーズ遷移が発生しない() -> void:
	var hud := _make_hud()
	GameState.phase_changed.connect(_on_phase_changed_for_test)
	var phase_before: StringName = GameState.get_state()["current_phase"]

	hud.get_settings_button().pressed.emit()

	assert_int(_phase_changed_count).is_equal(0)
	assert_str(String(GameState.get_state()["current_phase"])).is_equal(String(phase_before))


# 異常系


func test_歯車ボタン追加後もexit_treeで破棄でき購読側が発火しない() -> void:
	var hud: RankHud = (load(SCENE_PATH) as PackedScene).instantiate()
	add_child(hud)
	await await_idle_frame()
	hud.settings_requested.connect(_on_settings_requested_for_test)

	remove_child(hud)
	hud.free()

	assert_int(_settings_requested_count).is_equal(0)


func test_ランクマスター未登録でもフォールバック表示になる() -> void:
	GameState._set_rank_masters_for_test({})
	GameState._set_current_rank_id_for_test(&"rank_missing")
	var hud := _make_hud()

	assert_str(hud.get_rank_name_text()).is_equal(RankHud.UNKNOWN_RANK_NAME)
	assert_float(hud.get_quota_ratio()).is_equal(0.0)
	assert_str(hud.get_turn_remaining_text()).contains("0")


func test_exit_tree後に購読していた6シグナルが解除される() -> void:
	var baseline := _connection_counts()
	var hud: RankHud = (load(SCENE_PATH) as PackedScene).instantiate()
	add_child(hud)
	await await_idle_frame()

	var connected := _connection_counts()
	remove_child(hud)
	hud.free()

	var released := _connection_counts()
	for signal_name in HUD_SIGNAL_NAMES:
		assert_int(connected[signal_name]).is_equal(int(baseline[signal_name]) + 1)
		assert_int(released[signal_name]).is_equal(baseline[signal_name])


# 境界値


func test_ノルマ上限が0でも比率が0除算せず0になる() -> void:
	_set_rank(0.0, 0.0, LIMIT_TURN, 0)
	var hud := _make_hud()

	assert_float(hud.get_quota_ratio()).is_equal(0.0)


func test_ノルマ残量が上限を超えても比率が1を超えない() -> void:
	_set_rank(50.0, 80.0, LIMIT_TURN, 0)
	var hud := _make_hud()

	assert_float(hud.get_quota_ratio()).is_equal(1.0)


func test_経過ターンが制限ターンを超えても残ターンが負にならない() -> void:
	_set_rank(QUOTA_MAX, QUOTA_REMAINING, 3, 8)
	var hud := _make_hud()

	assert_str(hud.get_turn_remaining_text()).contains("0")
	assert_str(hud.get_turn_remaining_text()).not_contains("-")
