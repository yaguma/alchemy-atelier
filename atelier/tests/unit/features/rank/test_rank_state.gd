extends GdUnitTestSuite


func test_newしたRankStateのデフォルト値はquotaが0でelapsed_turnが0である() -> void:
	var rank_state := RankState.new()

	assert_float(rank_state.quota).is_equal(0.0)
	assert_int(rank_state.elapsed_turn).is_equal(0)


func test_設定した値がcloneで複製したインスタンスにも引き継がれる() -> void:
	var rank_state := RankState.new()
	rank_state.quota = 120.5
	rank_state.elapsed_turn = 7

	var cloned := rank_state.clone()

	assert_float(cloned.quota).is_equal(120.5)
	assert_int(cloned.elapsed_turn).is_equal(7)


func test_cloneで複製したインスタンスを変更しても元のインスタンスは影響を受けない() -> void:
	var rank_state := RankState.new()
	rank_state.quota = 100.0
	rank_state.elapsed_turn = 3

	var cloned := rank_state.clone()
	cloned.quota = 0.0
	cloned.elapsed_turn = 99

	assert_float(rank_state.quota).is_equal(100.0)
	assert_int(rank_state.elapsed_turn).is_equal(3)
	assert_bool(cloned == rank_state).is_false()
