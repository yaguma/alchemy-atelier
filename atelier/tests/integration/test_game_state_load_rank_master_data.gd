extends GdUnitTestSuite

const FLOAT_TOLERANCE := 0.0001


func before_test() -> void:
	GameState.reset_for_test()


## 実データ（res://data/ranks/）側の仮値変更に追従できるよう、期待値はテスト内で
## ハードコードせずマスターデータから引く
func _initial_rank_quota_max() -> float:
	for r in MasterDataLoader.load_all(&"ranks"):
		if (r as RankMaster).id == String(GameBalance.INITIAL_RANK_ID):
			return (r as RankMaster).quota_max
	return -1.0


# 正常系


func test_load_rank_master_data後にRANK_ORDERの全ランクが解決できる() -> void:
	GameState.load_rank_master_data()

	assert_int(GameState._rank_masters.size()).is_equal(GameBalance.RANK_ORDER.size())
	for rank_id in GameBalance.RANK_ORDER:
		assert_object(GameState._rank_masters.get(rank_id)).is_not_null()


func test_load_rank_master_data後にcurrent_rank_idのRankMasterが解決できる() -> void:
	GameState.load_rank_master_data()

	var current_rank_id: StringName = GameState.get_state()["current_rank_id"]

	assert_that(current_rank_id).is_equal(GameBalance.INITIAL_RANK_ID)
	assert_object(GameState._rank_masters.get(current_rank_id)).is_not_null()


func test_初回ロードでRankStateが初期ランクのquota_maxで初期化される() -> void:
	GameState.load_rank_master_data()

	assert_bool(GameState._rank_state_initialized).is_true()
	assert_float(GameState._rank_state.quota).is_equal_approx(
		_initial_rank_quota_max(), FLOAT_TOLERANCE
	)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(0)


# 境界値


func test_2回連続で呼んでもRankStateが上書き初期化されない() -> void:
	GameState.load_rank_master_data()
	var progressed := RankState.new()
	progressed.quota = 1.0
	progressed.elapsed_turn = 5
	GameState._set_rank_state_for_test(progressed)

	GameState.load_rank_master_data()

	assert_float(GameState._rank_state.quota).is_equal_approx(1.0, FLOAT_TOLERANCE)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(5)


# 異常系


## data/ranks/が空の場合と同じ防御パス（初期ランクのRankMasterが引けない）を、
## ファイルシステムを壊さず再現するため未知のランクIDを現在ランクに設定して検証する
func test_現在ランクのRankMasterが無くてもクラッシュせず初期化をスキップする() -> void:
	GameState._set_current_rank_id_for_test(&"rank_unknown")

	GameState.load_rank_master_data()

	assert_bool(GameState._rank_state_initialized).is_false()
	assert_float(GameState._rank_state.quota).is_equal_approx(0.0, FLOAT_TOLERANCE)
