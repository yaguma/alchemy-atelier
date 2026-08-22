extends GdUnitTestSuite

const RANK_ID: StringName = &"rank_g"


func before_test() -> void:
	GameState.reset_for_test()


func _make_rank(id: String) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = id
	rank.display_name = "見習い"
	rank.quota_max = 100.0
	rank.limit_turn = 30
	rank.traits_unlocked = true
	return rank


func _make_rank_state(quota: float) -> RankState:
	var state := RankState.new()
	state.quota = quota
	return state


# 正常系


func test_get_current_rank_masterが現在ランクのマスターを返す() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(String(RANK_ID))})
	GameState._set_current_rank_id_for_test(RANK_ID)

	var master := GameState.get_current_rank_master()

	assert_object(master).is_not_null()
	assert_float(master.quota_max).is_equal(100.0)
	assert_str(master.display_name).is_equal("見習い")


func test_get_current_rank_quotaが注入したノルマ残量を返す() -> void:
	GameState._set_rank_state_for_test(_make_rank_state(40.0))

	assert_float(GameState.get_current_rank_quota()).is_equal(40.0)


# 異常系


## ランクマスター未ロード時も_get_current_rank_master_or_fallback()の安全側フォールバックが
## 返り、例外を投げないことを確認する（push_error()は設計通りの挙動）
func test_ランクマスター未登録でもget_current_rank_masterがフォールバックを返す() -> void:
	GameState._set_current_rank_id_for_test(&"rank_unknown")

	var master := GameState.get_current_rank_master()

	assert_object(master).is_not_null()
	assert_float(master.quota_max).is_equal(0.0)
	assert_bool(master.traits_unlocked).is_false()
	assert_int(master.limit_turn).is_equal(0)


# 境界値


func test_reset_for_test直後のget_current_rank_quotaは0を返す() -> void:
	assert_float(GameState.get_current_rank_quota()).is_equal(0.0)
