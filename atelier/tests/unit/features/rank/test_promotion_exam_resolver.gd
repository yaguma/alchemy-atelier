extends GdUnitTestSuite


func _make_rank_master(
	quota_max: float = 100.0,
	limit_turn: int = 10,
	exam_turn_limit: int = 3,
	exam_difficulty_coefficient: float = 1.5
) -> RankMaster:
	var rank_master := RankMaster.new()
	rank_master.id = "G"
	rank_master.display_name = "Gランク"
	rank_master.quota_max = quota_max
	rank_master.limit_turn = limit_turn
	rank_master.exam_turn_limit = exam_turn_limit
	rank_master.exam_difficulty_coefficient = exam_difficulty_coefficient
	return rank_master


func _make_exam_state(
	exam_quota: float = 45.0,
	exam_quota_max: float = 45.0,
	exam_elapsed_turn: int = 0,
	exam_turn_limit: int = 3
) -> ExamState:
	var exam_state := ExamState.new()
	exam_state.exam_quota = exam_quota
	exam_state.exam_quota_max = exam_quota_max
	exam_state.exam_elapsed_turn = exam_elapsed_turn
	exam_state.exam_turn_limit = exam_turn_limit
	return exam_state


# --- start_exam ---


# 正常系: FR-002 試験ノルマ上限が難度係数と試験ターン比率から算出される
func test_試験開始時に試験ノルマ上限が算出される() -> void:
	var rank_master := _make_rank_master(100.0, 10, 3, 1.5)

	var exam_state := PromotionExamResolver.start_exam(rank_master)

	assert_float(exam_state.exam_quota_max).is_equal_approx(45.0, 0.0001)
	assert_float(exam_state.exam_quota).is_equal_approx(45.0, 0.0001)


# 正常系: FR-002 経過ターンは0、制限ターンはマスターの値で初期化される
func test_試験開始時に経過ターンと制限ターンが初期化される() -> void:
	var rank_master := _make_rank_master(100.0, 10, 3, 1.5)

	var exam_state := PromotionExamResolver.start_exam(rank_master)

	assert_int(exam_state.exam_elapsed_turn).is_equal(0)
	assert_int(exam_state.exam_turn_limit).is_equal(3)


# 異常系: NFR-101 nullを渡してもクラッシュせずゼロ値のExamStateを返す
func test_ランクマスターがnullでもクラッシュせずゼロ値のExamStateを返す() -> void:
	var exam_state := PromotionExamResolver.start_exam(null)

	assert_object(exam_state).is_not_null()
	assert_float(exam_state.exam_quota).is_equal_approx(0.0, 0.0001)
	assert_float(exam_state.exam_quota_max).is_equal_approx(0.0, 0.0001)
	assert_int(exam_state.exam_elapsed_turn).is_equal(0)
	assert_int(exam_state.exam_turn_limit).is_equal(0)


# 異常系: NFR-101 limit_turn=0でもゼロ除算せずゼロ値のExamStateを返す
func test_制限ターンが0でもゼロ除算せずゼロ値のExamStateを返す() -> void:
	var rank_master := _make_rank_master(100.0, 0, 3, 1.5)

	var exam_state := PromotionExamResolver.start_exam(rank_master)

	assert_float(exam_state.exam_quota).is_equal_approx(0.0, 0.0001)
	assert_float(exam_state.exam_quota_max).is_equal_approx(0.0, 0.0001)
	assert_int(exam_state.exam_turn_limit).is_equal(0)


# 異常系: NFR-101 limit_turnが負値でもゼロ値のExamStateを返す
func test_制限ターンが負値でもゼロ値のExamStateを返す() -> void:
	var rank_master := _make_rank_master(100.0, -1, 3, 1.5)

	var exam_state := PromotionExamResolver.start_exam(rank_master)

	assert_float(exam_state.exam_quota_max).is_equal_approx(0.0, 0.0001)
	assert_int(exam_state.exam_turn_limit).is_equal(0)


# 境界値: FR-002 難度係数0なら試験ノルマ上限も0になる
func test_難度係数が0なら試験ノルマ上限が0になる() -> void:
	var rank_master := _make_rank_master(100.0, 10, 3, 0.0)

	var exam_state := PromotionExamResolver.start_exam(rank_master)

	assert_float(exam_state.exam_quota_max).is_equal_approx(0.0, 0.0001)
	assert_float(exam_state.exam_quota).is_equal_approx(0.0, 0.0001)
	assert_int(exam_state.exam_turn_limit).is_equal(3)


# 異常系: NFR-101 exam_turn_limit=0（未設定マスターデータ）でもゼロ値のExamStateを返す
# exam_turn_limit=0だとquota_maxが0になり、resolve_outcome()が0ターン目で即SUCCESSを
# 返してしまう（未達成のまま昇格試験に合格する）ため、start_exam()側でガードする。
func test_試験制限ターンが0でもゼロ値のExamStateを返す() -> void:
	var rank_master := _make_rank_master(100.0, 10, 0, 1.5)

	var exam_state := PromotionExamResolver.start_exam(rank_master)

	assert_float(exam_state.exam_quota_max).is_equal_approx(0.0, 0.0001)
	assert_float(exam_state.exam_quota).is_equal_approx(0.0, 0.0001)
	assert_int(exam_state.exam_turn_limit).is_equal(0)


# 異常系: NFR-101 exam_turn_limitが負値でもゼロ値のExamStateを返す
func test_試験制限ターンが負値でもゼロ値のExamStateを返す() -> void:
	var rank_master := _make_rank_master(100.0, 10, -1, 1.5)

	var exam_state := PromotionExamResolver.start_exam(rank_master)

	assert_float(exam_state.exam_quota_max).is_equal_approx(0.0, 0.0001)
	assert_int(exam_state.exam_turn_limit).is_equal(0)


# 異常系: FR-401 引数のRankMasterはin-placeで書き換えられない
func test_試験開始は引数のランクマスターを書き換えない() -> void:
	var rank_master := _make_rank_master(100.0, 10, 3, 1.5)

	PromotionExamResolver.start_exam(rank_master)

	assert_float(rank_master.quota_max).is_equal_approx(100.0, 0.0001)
	assert_int(rank_master.limit_turn).is_equal(10)
	assert_int(rank_master.exam_turn_limit).is_equal(3)
	assert_float(rank_master.exam_difficulty_coefficient).is_equal_approx(1.5, 0.0001)


# 異常系: AC-013 呼び出しごとに独立した新規インスタンスを返す
func test_試験開始は呼び出しごとに独立したインスタンスを返す() -> void:
	var rank_master := _make_rank_master(100.0, 10, 3, 1.5)

	var first := PromotionExamResolver.start_exam(rank_master)
	var second := PromotionExamResolver.start_exam(rank_master)
	first.exam_quota = 0.0

	assert_bool(first == second).is_false()
	assert_float(second.exam_quota).is_equal_approx(45.0, 0.0001)


# --- advance_turn ---


# 正常系: FR-003 経過ターンが1加算された新規ExamStateが返る
func test_ターン進行で経過ターンが1加算される() -> void:
	var exam_state := _make_exam_state(45.0, 45.0, 0, 3)

	var advanced := PromotionExamResolver.advance_turn(exam_state)

	assert_int(advanced.exam_elapsed_turn).is_equal(1)


# 正常系: FR-403 経過ターン以外のフィールドは引き継がれる
func test_ターン進行で経過ターン以外のフィールドが引き継がれる() -> void:
	var exam_state := _make_exam_state(20.0, 45.0, 1, 3)

	var advanced := PromotionExamResolver.advance_turn(exam_state)

	assert_float(advanced.exam_quota).is_equal_approx(20.0, 0.0001)
	assert_float(advanced.exam_quota_max).is_equal_approx(45.0, 0.0001)
	assert_int(advanced.exam_turn_limit).is_equal(3)


# 異常系: FR-401 引数のExamStateはin-placeで書き換えられない
func test_ターン進行は引数のExamStateを書き換えない() -> void:
	var exam_state := _make_exam_state(45.0, 45.0, 0, 3)

	PromotionExamResolver.advance_turn(exam_state)

	assert_int(exam_state.exam_elapsed_turn).is_equal(0)


# 境界値: FR-003 制限ターン直前から+1して上限ちょうどに到達する
func test_制限ターン直前から進行すると上限ちょうどに到達する() -> void:
	var exam_state := _make_exam_state(45.0, 45.0, 2, 3)

	var advanced := PromotionExamResolver.advance_turn(exam_state)

	assert_int(advanced.exam_elapsed_turn).is_equal(3)


# 不変性: FR-401 戻り値と引数は非同一参照である
func test_ターン進行の戻り値は引数と別インスタンスである() -> void:
	var exam_state := _make_exam_state(45.0, 45.0, 0, 3)

	var advanced := PromotionExamResolver.advance_turn(exam_state)

	assert_bool(advanced == exam_state).is_false()


# --- resolve_outcome ---


# 正常系: FR-004 ノルマ残・ターン残ならCONTINUE
func test_ノルマ未達成かつ制限ターン未到達ならCONTINUEを返す() -> void:
	var exam_state := _make_exam_state(50.0, 50.0, 1, 3)

	var outcome := PromotionExamResolver.resolve_outcome(exam_state)

	assert_int(outcome).is_equal(ExamOutcome.Value.CONTINUE)


# 境界値: FR-004 ノルマ残量ちょうど0でSUCCESS
func test_ノルマ残量が0ちょうどならSUCCESSを返す() -> void:
	var exam_state := _make_exam_state(0.0, 45.0, 1, 3)

	var outcome := PromotionExamResolver.resolve_outcome(exam_state)

	assert_int(outcome).is_equal(ExamOutcome.Value.SUCCESS)


# 境界値: FR-004 制限ターン到達かつノルマ達成済みならSUCCESSが優先される
func test_制限ターン到達でもノルマ達成済みならSUCCESSが優先される() -> void:
	var exam_state := _make_exam_state(0.0, 45.0, 3, 3)

	var outcome := PromotionExamResolver.resolve_outcome(exam_state)

	assert_int(outcome).is_equal(ExamOutcome.Value.SUCCESS)


# 境界値: FR-004 制限ターン到達かつノルマ未達成ならFAILURE
func test_制限ターン到達かつノルマ未達成ならFAILUREを返す() -> void:
	var exam_state := _make_exam_state(10.0, 45.0, 3, 3)

	var outcome := PromotionExamResolver.resolve_outcome(exam_state)

	assert_int(outcome).is_equal(ExamOutcome.Value.FAILURE)


# 境界値: FR-004 制限ターンを超過してもノルマ未達成ならFAILURE
func test_制限ターンを超過しノルマ未達成ならFAILUREを返す() -> void:
	var exam_state := _make_exam_state(10.0, 45.0, 4, 3)

	var outcome := PromotionExamResolver.resolve_outcome(exam_state)

	assert_int(outcome).is_equal(ExamOutcome.Value.FAILURE)


# 境界値: FR-004 制限ターン直前でノルマ未達成ならCONTINUE
func test_制限ターン直前でノルマ未達成ならCONTINUEを返す() -> void:
	var exam_state := _make_exam_state(10.0, 45.0, 2, 3)

	var outcome := PromotionExamResolver.resolve_outcome(exam_state)

	assert_int(outcome).is_equal(ExamOutcome.Value.CONTINUE)


# 異常系: FR-004 ノルマ残量が負値でもSUCCESS扱いになる
func test_ノルマ残量が負値でもSUCCESSを返す() -> void:
	var exam_state := _make_exam_state(-5.0, 45.0, 1, 3)

	var outcome := PromotionExamResolver.resolve_outcome(exam_state)

	assert_int(outcome).is_equal(ExamOutcome.Value.SUCCESS)


# 異常系: FR-401 判定は引数のExamStateを書き換えない
func test_結果判定は引数のExamStateを書き換えない() -> void:
	var exam_state := _make_exam_state(10.0, 45.0, 2, 3)

	PromotionExamResolver.resolve_outcome(exam_state)

	assert_float(exam_state.exam_quota).is_equal_approx(10.0, 0.0001)
	assert_int(exam_state.exam_elapsed_turn).is_equal(2)
