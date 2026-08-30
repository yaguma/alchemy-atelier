extends GdUnitTestSuite

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

# 🔴 抽選プールを2件以上にして「再抽選が実際に候補を切り替えうる」状態を作るためのレシピID。
# data/daily_orders/にcondition_type=="item"で対応するエントリが存在する2件を使う
const SECOND_RECIPE_ID: StringName = &"recipe_mana_tonic"

# 🔴 コードレビュー指摘対応。test_main_scene_daily_order_flow.gdと重複していた
# _current_pool()の実装をtests/mocks/daily_order_pool.gdへ統合した
const DailyOrderPool = preload("res://tests/mocks/daily_order_pool.gd")


func before_test() -> void:
	GameState.reset_for_test()
	# 指定依頼の絞り込みはis_current_rank_traits_unlocked()を経由するため、
	# ランクマスター未ロード時のフォールバック警告を避けて実プレイと同じ条件に揃える
	GameState.load_rank_master_data()


## 現在の解禁状況での抽選プールを、本番実装と同じ条件でテスト側にも再現する
func _current_pool() -> Array[DailyOrderMaster]:
	return DailyOrderPool.current_pool()


func _unlock_second_recipe() -> void:
	var ids: Array[StringName] = [GameBalance.INITIAL_RECIPE_ID, SECOND_RECIPE_ID]
	GameState._set_unlocked_recipe_ids_for_test(ids)


# 正常系


func test_load_daily_order_master_dataでマスターがロードされる() -> void:
	GameState.load_daily_order_master_data()

	assert_int(GameState._daily_order_masters.size()).is_greater(0)


func test_load_daily_order_master_data後にcurrent_daily_orderが設定される() -> void:
	GameState.load_daily_order_master_data()

	assert_object(GameState.get_state()["current_daily_order"]).is_not_null()


func test_load_daily_order_master_data後に納品用の指定依頼が解決できる() -> void:
	GameState.load_daily_order_master_data()

	assert_object(GameState.resolve_daily_order_for_delivery()).is_not_null()


func test_advance_turn_growthで指定依頼が再抽選される() -> void:
	GameState.load_daily_order_master_data()
	_unlock_second_recipe()
	var pool := _current_pool()
	assert_int(pool.size()).is_greater(1)

	# 同一シードから払い出される乱数値で期待値を先に算出し、
	# 同じシードを再設定してから再抽選を走らせることで決定的に照合する
	RngService.set_seed(12345)
	var expected := DailyOrderSelector.select(pool, RngService.randf())

	RngService.set_seed(12345)
	GameState.advance_turn_growth()

	assert_object(GameState._current_daily_order).is_same(expected)


# 異常系


func test_マスターデータが0件でも再抽選がクラッシュせずnullになる() -> void:
	# data/daily_orders/を空にはできないため、ロード結果が0件だった場合と同じ状態を直接作る
	GameState._daily_order_masters = []

	GameStateGuildDelegate.reroll_daily_order(GameState)

	assert_object(GameState._current_daily_order).is_null()


func test_絞り込み後のプールが空になると再抽選でnullに更新される() -> void:
	GameState.load_daily_order_master_data()
	assert_object(GameState._current_daily_order).is_not_null()

	# 解禁レシピを空にすると、traits未解禁（rank_g）と合わせて達成可能な依頼が無くなる
	var empty_ids: Array[StringName] = []
	GameState._set_unlocked_recipe_ids_for_test(empty_ids)

	GameState.advance_turn_growth()

	assert_object(GameState._current_daily_order).is_null()


# 境界値


func test_load_daily_order_master_dataを2回呼んでもクラッシュしない() -> void:
	GameState.load_daily_order_master_data()

	GameState.load_daily_order_master_data()

	assert_int(GameState._daily_order_masters.size()).is_greater(0)
	assert_object(GameState._current_daily_order).is_not_null()


func test_試験中はターン進行後も納品用の指定依頼がnullのままである() -> void:
	GameState.load_daily_order_master_data()
	GameState._set_exam_state_for_test(ExamState.new(), true)

	GameState.advance_turn_growth()

	assert_object(GameState._current_daily_order).is_not_null()
	assert_object(GameState.resolve_daily_order_for_delivery()).is_null()


func test_advance_exam_turnでは指定依頼を再抽選しない() -> void:
	GameState.load_daily_order_master_data()
	_unlock_second_recipe()
	GameState._set_exam_state_for_test(ExamState.new(), true)
	var before := GameState._current_daily_order

	GameState.advance_exam_turn()

	assert_object(GameState._current_daily_order).is_same(before)


func test_MainSceneの生成で指定依頼マスターがロードされる() -> void:
	var runner := scene_runner(MAIN_SCENE_PATH)
	assert_object(runner.scene()).is_not_null()

	assert_int(GameState._daily_order_masters.size()).is_greater(0)
	assert_object(GameState._current_daily_order).is_not_null()
