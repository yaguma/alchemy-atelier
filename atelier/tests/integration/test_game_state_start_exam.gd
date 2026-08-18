extends GdUnitTestSuite

const RANK_ID: StringName = &"rank_g"
const FLOAT_TOLERANCE := 0.0001

var _confirmed_outcomes: Array = []
var _exam_started_count: int = 0


func before_test() -> void:
	GameState.reset_for_test()
	_confirmed_outcomes = []
	_exam_started_count = 0
	GameState.rank_outcome_confirmed.connect(_on_rank_outcome_confirmed)
	GameState.exam_started.connect(_on_exam_started)


func after_test() -> void:
	# GameStateはAutoloadで購読側テストより寿命が長いため明示的に解除する
	if GameState.rank_outcome_confirmed.is_connected(_on_rank_outcome_confirmed):
		GameState.rank_outcome_confirmed.disconnect(_on_rank_outcome_confirmed)
	if GameState.exam_started.is_connected(_on_exam_started):
		GameState.exam_started.disconnect(_on_exam_started)


func _on_rank_outcome_confirmed(outcome: RankOutcome.Value) -> void:
	_confirmed_outcomes.append(outcome)


func _on_exam_started() -> void:
	_exam_started_count += 1


## 有効な試験パラメータを持つRankMasterを生成する（quota_max/limit_turnはランク本体用、
## exam_turn_limit/exam_difficulty_coefficientは昇格試験用）
func _make_valid_rank(
	quota_max: float, limit_turn: int, exam_turn_limit: int, exam_difficulty_coefficient: float
) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.display_name = "テストランク"
	rank.quota_max = quota_max
	rank.limit_turn = limit_turn
	rank.traits_unlocked = false
	rank.exam_turn_limit = exam_turn_limit
	rank.exam_difficulty_coefficient = exam_difficulty_coefficient
	return rank


func _setup_valid_rank() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_valid_rank(100.0, 30, 5, 0.5)})
	GameState._set_current_rank_id_for_test(RANK_ID)


func _set_rank_state(quota: float, elapsed_turn: int) -> void:
	var state := RankState.new()
	state.quota = quota
	state.elapsed_turn = elapsed_turn
	GameState._set_rank_state_for_test(state)


# 正常系


func test_PROMOTION_ELIGIBLE確定後にin_examがtrueになる() -> void:
	_setup_valid_rank()
	_set_rank_state(0.0, 30)

	var result := GameState.commit_rank_outcome()

	assert_int(result.value).is_equal(RankOutcome.Value.PROMOTION_ELIGIBLE)
	assert_bool(GameState.get_state().in_exam).is_true()


func test_試験開始後のexam_quota_maxがPromotionExamResolverの計算式と一致する() -> void:
	_setup_valid_rank()
	_set_rank_state(0.0, 30)
	var expected := (
		PromotionExamResolver.start_exam(GameState._rank_masters[RANK_ID]).exam_quota_max
	)

	GameState.commit_rank_outcome()

	assert_float(GameState.get_state().exam_quota_max).is_equal_approx(expected, FLOAT_TOLERANCE)


func test_試験開始時にexam_startedシグナルが発行される() -> void:
	# AutoloadのGameStateがテスト終了時に自動解放されないよう第2引数falseを明示する
	monitor_signals(GameState, false)
	_setup_valid_rank()
	_set_rank_state(0.0, 30)

	GameState.commit_rank_outcome()

	await assert_signal(GameState).is_emitted("exam_started")


# 異常系


## NFR-101: RankMaster不正（limit_turn<=0）時は試験開始不可のフォールバックが働く。
## limit_turn=0の場合、TurnLimitResolver.is_turn_limit_reached(elapsed_turn=0, 0)がtrueになるため
## evaluate_rank_outcome()自体はPROMOTION_ELIGIBLEを返す一方、_start_exam()は
## limit_turn<=0を検出して試験を開始しない（push_error()を記録するのみ）
func test_RankMasterのlimit_turnが不正な場合は試験を開始せずin_examがfalseのまま() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_valid_rank(0.0, 0, 5, 0.5)})
	GameState._set_current_rank_id_for_test(RANK_ID)
	_set_rank_state(0.0, 0)

	var result := GameState.commit_rank_outcome()

	assert_int(result.value).is_equal(RankOutcome.Value.PROMOTION_ELIGIBLE)
	assert_bool(GameState.get_state().in_exam).is_false()
	assert_int(_exam_started_count).is_equal(0)


# 二重開始防止（FR-201）


func test_試験中に再度PROMOTION_ELIGIBLEが確定しても既存の試験状態が上書きされない() -> void:
	_setup_valid_rank()
	var in_progress_exam := ExamState.new()
	in_progress_exam.exam_quota = 3.0
	in_progress_exam.exam_quota_max = 10.0
	in_progress_exam.exam_elapsed_turn = 2
	in_progress_exam.exam_turn_limit = 5
	GameState._set_exam_state_for_test(in_progress_exam)
	_set_rank_state(0.0, 30)

	GameState.commit_rank_outcome()

	assert_int(GameState._exam_state.exam_elapsed_turn).is_equal(2)
	assert_float(GameState._exam_state.exam_quota).is_equal_approx(3.0, FLOAT_TOLERANCE)
	assert_float(GameState._exam_state.exam_quota_max).is_equal_approx(10.0, FLOAT_TOLERANCE)
	assert_int(GameState._exam_state.exam_turn_limit).is_equal(5)
	assert_int(_exam_started_count).is_equal(0)


# 既存動作の非破壊確認


func test_DEMOTION確定時の既存挙動は変化しない() -> void:
	_setup_valid_rank()
	_set_rank_state(20.0, 30)

	var result := GameState.commit_rank_outcome()

	assert_int(result.value).is_equal(RankOutcome.Value.DEMOTION)
	assert_int(GameState._demotion_count).is_equal(1)
	assert_bool(GameState.get_state().in_exam).is_false()
	assert_int(_confirmed_outcomes.size()).is_equal(1)
	assert_int(_confirmed_outcomes[0]).is_equal(RankOutcome.Value.DEMOTION)
	assert_int(_exam_started_count).is_equal(0)


func test_CONTINUE確定時の既存挙動は変化しない() -> void:
	_setup_valid_rank()
	_set_rank_state(20.0, 10)

	var result := GameState.commit_rank_outcome()

	assert_int(result.value).is_equal(RankOutcome.Value.CONTINUE)
	assert_int(GameState._demotion_count).is_equal(0)
	assert_bool(GameState.get_state().in_exam).is_false()
	assert_int(_confirmed_outcomes.size()).is_equal(1)
	assert_int(_confirmed_outcomes[0]).is_equal(RankOutcome.Value.CONTINUE)
	assert_int(_exam_started_count).is_equal(0)
