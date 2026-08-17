extends GdUnitTestSuite


func test_ゲームオーバー閾値となる降格回数上限が3である() -> void:
	assert_int(GameBalance.MAX_DEMOTION_COUNT).is_equal(3)


func test_降格回数上限がint型である() -> void:
	assert_int(typeof(GameBalance.MAX_DEMOTION_COUNT)).is_equal(TYPE_INT)


func test_初期ランクIDがrank_gである() -> void:
	assert_str(String(GameBalance.INITIAL_RANK_ID)).is_equal("rank_g")


func test_初期ランクIDがStringName型である() -> void:
	assert_int(typeof(GameBalance.INITIAL_RANK_ID)).is_equal(TYPE_STRING_NAME)


func test_ランク順序の先頭がrank_gである() -> void:
	assert_str(String(GameBalance.RANK_ORDER[0])).is_equal("rank_g")


func test_ランク順序の末尾がrank_sである() -> void:
	assert_str(String(GameBalance.RANK_ORDER[7])).is_equal("rank_s")


func test_ランク順序の要素数が8である() -> void:
	assert_int(GameBalance.RANK_ORDER.size()).is_equal(8)


func test_ランク順序に重複したランクIDが存在しない() -> void:
	var unique: Array[StringName] = []
	for rank_id in GameBalance.RANK_ORDER:
		if not unique.has(rank_id):
			unique.append(rank_id)
	assert_int(unique.size()).is_equal(GameBalance.RANK_ORDER.size())


func test_ランク順序の先頭が初期ランクIDと一致する() -> void:
	assert_str(String(GameBalance.RANK_ORDER[0])).is_equal(String(GameBalance.INITIAL_RANK_ID))


func test_ランク順序の全要素がStringName型である() -> void:
	for rank_id in GameBalance.RANK_ORDER:
		assert_int(typeof(rank_id)).is_equal(TYPE_STRING_NAME)
