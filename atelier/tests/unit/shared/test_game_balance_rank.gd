extends GdUnitTestSuite


func test_ゲームオーバー閾値となる降格回数上限が3である() -> void:
	assert_int(GameBalance.MAX_DEMOTION_COUNT).is_equal(3)


func test_降格回数上限がint型である() -> void:
	assert_int(typeof(GameBalance.MAX_DEMOTION_COUNT)).is_equal(TYPE_INT)


func test_初期ランクIDがrank_gである() -> void:
	assert_str(String(GameBalance.INITIAL_RANK_ID)).is_equal("rank_g")


func test_初期ランクIDがStringName型である() -> void:
	assert_int(typeof(GameBalance.INITIAL_RANK_ID)).is_equal(TYPE_STRING_NAME)
