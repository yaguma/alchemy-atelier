extends GdUnitTestSuite


func _make_rank_master(quota_max: float = 100.0, limit_turn: int = 30) -> RankMaster:
	var rank_master := RankMaster.new()
	rank_master.id = "G"
	rank_master.display_name = "Gランク"
	rank_master.quota_max = quota_max
	rank_master.limit_turn = limit_turn
	return rank_master


# 正常系: AC-001 貢献度分だけノルマ残量が減算される
func test_貢献度を適用するとノルマ残量が減算される() -> void:
	assert_float(RankQuotaResolver.apply_contribution(100.0, 30.0)).is_equal_approx(70.0, 0.0001)


# 境界値: AC-001 残量を超える貢献度でも0未満にならず超過分は切り捨てられる
func test_残量を超える貢献度でもノルマ残量は0にクランプされる() -> void:
	assert_float(RankQuotaResolver.apply_contribution(10.0, 30.0)).is_equal_approx(0.0, 0.0001)


# 境界値: AC-001 既に0の状態から減算しても0のまま維持される
func test_ノルマ残量が0の状態から減算しても0のまま維持される() -> void:
	assert_float(RankQuotaResolver.apply_contribution(0.0, 10.0)).is_equal_approx(0.0, 0.0001)


# 境界値: AC-001 貢献度0なら残量は変化しない
func test_貢献度が0ならノルマ残量は変化しない() -> void:
	assert_float(RankQuotaResolver.apply_contribution(100.0, 0.0)).is_equal_approx(100.0, 0.0001)


# 境界値: AC-001 残量とちょうど同値の貢献度で0になる
func test_残量と同値の貢献度を適用するとノルマ残量が0になる() -> void:
	assert_float(RankQuotaResolver.apply_contribution(30.0, 30.0)).is_equal_approx(0.0, 0.0001)


# 正常系: AC-002 残量0はクリア判定される
func test_ノルマ残量が0ならクリア済みと判定される() -> void:
	assert_bool(RankQuotaResolver.is_rank_cleared(0.0)).is_true()


# 正常系: AC-002 残量が僅かでも残っていれば未クリア
func test_ノルマ残量が残っていれば未クリアと判定される() -> void:
	assert_bool(RankQuotaResolver.is_rank_cleared(0.1)).is_false()


# 境界値: AC-002 防御的に負値が渡されてもクリア扱いとする
func test_ノルマ残量が負値でもクリア済みと判定される() -> void:
	assert_bool(RankQuotaResolver.is_rank_cleared(-1.0)).is_true()


# 正常系: AC-008 再挑戦リセットでquota_maxとelapsed_turn=0の新規RankStateが返る
func test_再挑戦リセットでノルマ残量と経過ターンが初期化される() -> void:
	var rank_master := _make_rank_master(100.0)

	var reset_state := RankQuotaResolver.reset_for_retry(rank_master)

	assert_float(reset_state.quota).is_equal_approx(100.0, 0.0001)
	assert_int(reset_state.elapsed_turn).is_equal(0)


# 異常系: FR-401 引数のRankMasterはin-placeで書き換えられない
func test_再挑戦リセットは引数のランクマスターを書き換えない() -> void:
	var rank_master := _make_rank_master(100.0, 30)

	RankQuotaResolver.reset_for_retry(rank_master)

	assert_float(rank_master.quota_max).is_equal_approx(100.0, 0.0001)
	assert_int(rank_master.limit_turn).is_equal(30)


# 異常系: NFR-101 nullを渡してもクラッシュせず既定のRankStateを返す
func test_ランクマスターがnullでもクラッシュせず既定値のRankStateを返す() -> void:
	var reset_state := RankQuotaResolver.reset_for_retry(null)

	assert_object(reset_state).is_not_null()
	assert_float(reset_state.quota).is_equal_approx(0.0, 0.0001)
	assert_int(reset_state.elapsed_turn).is_equal(0)


# 異常系: AC-008 呼び出しごとに独立した新規インスタンスを返す
func test_再挑戦リセットは呼び出しごとに独立したインスタンスを返す() -> void:
	var rank_master := _make_rank_master(100.0)

	var first := RankQuotaResolver.reset_for_retry(rank_master)
	var second := RankQuotaResolver.reset_for_retry(rank_master)
	first.quota = 0.0

	assert_bool(first == second).is_false()
	assert_float(second.quota).is_equal_approx(100.0, 0.0001)


# 異常系: AC-013 純粋関数として同一引数では常に同じ結果を返す
func test_同一引数で複数回呼び出しても同じ結果を返す() -> void:
	var rank_master := _make_rank_master(100.0)

	assert_float(RankQuotaResolver.apply_contribution(100.0, 30.0)).is_equal_approx(
		RankQuotaResolver.apply_contribution(100.0, 30.0), 0.0001
	)
	assert_bool(RankQuotaResolver.is_rank_cleared(0.0)).is_equal(
		RankQuotaResolver.is_rank_cleared(0.0)
	)
	assert_float(RankQuotaResolver.reset_for_retry(rank_master).quota).is_equal_approx(
		RankQuotaResolver.reset_for_retry(rank_master).quota, 0.0001
	)
