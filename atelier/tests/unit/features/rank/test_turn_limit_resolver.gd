extends GdUnitTestSuite


# 正常系（AC-003）
func test_現在ターンが制限ターンと等しい場合は到達とみなす() -> void:
	assert_bool(TurnLimitResolver.is_turn_limit_reached(15, 15)).is_true()


# 正常系（AC-003）
func test_現在ターンが制限ターン未満の場合は未到達となる() -> void:
	assert_bool(TurnLimitResolver.is_turn_limit_reached(14, 15)).is_false()


# 正常系（AC-003）
func test_現在ターンが制限ターンを超過した場合は到達とみなす() -> void:
	assert_bool(TurnLimitResolver.is_turn_limit_reached(20, 15)).is_true()


# 正常系（AC-004）
func test_制限ターン到達かつノルマクリア済みなら昇格試験挑戦可となる() -> void:
	var outcome := TurnLimitResolver.resolve_rank_outcome(true, true)

	assert_int(outcome).is_equal(RankOutcome.Value.PROMOTION_ELIGIBLE)


# 正常系（AC-004）
func test_制限ターン到達かつノルマ未達なら降格となる() -> void:
	var outcome := TurnLimitResolver.resolve_rank_outcome(false, true)

	assert_int(outcome).is_equal(RankOutcome.Value.DEMOTION)


# 境界値（AC-004, FR-411）
func test_ノルマクリア済みでも制限ターン未到達なら継続となる() -> void:
	var outcome := TurnLimitResolver.resolve_rank_outcome(true, false)

	assert_int(outcome).is_equal(RankOutcome.Value.CONTINUE)


# 境界値（AC-004）
func test_ノルマ未達かつ制限ターン未到達なら継続となる() -> void:
	var outcome := TurnLimitResolver.resolve_rank_outcome(false, false)

	assert_int(outcome).is_equal(RankOutcome.Value.CONTINUE)


# 異常系（AC-013）
func test_同一引数での複数回呼び出しが常に同じ結果を返す() -> void:
	for _i in range(3):
		assert_bool(TurnLimitResolver.is_turn_limit_reached(15, 15)).is_true()
		assert_int(TurnLimitResolver.resolve_rank_outcome(true, true)).is_equal(
			RankOutcome.Value.PROMOTION_ELIGIBLE
		)
		assert_int(TurnLimitResolver.resolve_rank_outcome(false, true)).is_equal(
			RankOutcome.Value.DEMOTION
		)
		assert_int(TurnLimitResolver.resolve_rank_outcome(true, false)).is_equal(
			RankOutcome.Value.CONTINUE
		)
