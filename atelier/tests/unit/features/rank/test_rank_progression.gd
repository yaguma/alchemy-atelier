extends GdUnitTestSuite


# 正常系: FR-010 先頭ランクから次ランクへ遷移する
func test_先頭ランクから次のランクIDを取得できる() -> void:
	assert_str(String(RankProgression.get_next_rank_id(&"rank_g"))).is_equal("rank_f")


# 正常系: FR-010 中間ランクから次ランクへ遷移する
func test_中間ランクから次のランクIDを取得できる() -> void:
	assert_str(String(RankProgression.get_next_rank_id(&"rank_d"))).is_equal("rank_c")


# 正常系: FR-010 末尾直前のランクから最終ランクへ遷移する
func test_末尾直前のランクから最終ランクIDを取得できる() -> void:
	assert_str(String(RankProgression.get_next_rank_id(&"rank_a"))).is_equal("rank_s")


# 境界値: FR-404 末尾ランクには次ランクがなく空文字列を返す（ゲームクリア判定の根拠）
func test_末尾ランクでは次ランクがなく空のIDを返す() -> void:
	assert_str(String(RankProgression.get_next_rank_id(&"rank_s"))).is_equal("")


# 異常系: NFR-101 RANK_ORDERに存在しないランクIDでもクラッシュせず空のIDを返す
func test_未知のランクIDでもクラッシュせず空のIDを返す() -> void:
	assert_str(String(RankProgression.get_next_rank_id(&"unknown"))).is_equal("")


# 異常系: NFR-101 空のランクIDでもクラッシュせず空のIDを返す
func test_空のランクIDでもクラッシュせず空のIDを返す() -> void:
	assert_str(String(RankProgression.get_next_rank_id(&""))).is_equal("")


# 異常系: 戻り値の型がStringNameであることを保証する
func test_戻り値がStringName型である() -> void:
	assert_int(typeof(RankProgression.get_next_rank_id(&"rank_g"))).is_equal(TYPE_STRING_NAME)
	assert_int(typeof(RankProgression.get_next_rank_id(&"rank_s"))).is_equal(TYPE_STRING_NAME)


# 正常系: FR-010 RANK_ORDER全体を辿ると末尾まで一巡できる
func test_先頭から辿るとRANK_ORDERの全ランクを順に走査できる() -> void:
	var visited: Array[StringName] = [GameBalance.INITIAL_RANK_ID]
	var current: StringName = GameBalance.INITIAL_RANK_ID

	while true:
		var next := RankProgression.get_next_rank_id(current)
		if next == &"":
			break
		visited.append(next)
		current = next

	assert_int(visited.size()).is_equal(GameBalance.RANK_ORDER.size())
	assert_str(String(visited[-1])).is_equal(String(GameBalance.RANK_ORDER[-1]))


# 異常系: AC-013 純粋関数として同一引数では常に同じ結果を返す
func test_同一引数で複数回呼び出しても同じ結果を返す() -> void:
	assert_str(String(RankProgression.get_next_rank_id(&"rank_g"))).is_equal(
		String(RankProgression.get_next_rank_id(&"rank_g"))
	)
	assert_str(String(RankProgression.get_next_rank_id(&"rank_s"))).is_equal(
		String(RankProgression.get_next_rank_id(&"rank_s"))
	)
