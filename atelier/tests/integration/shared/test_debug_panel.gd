extends GdUnitTestSuite

## DebugPanel（ゴールド付与/ノルマ即達成/次ランクへジャンプの3ボタン）の統合テスト。
## debug-playtest-support Plan タスク002。GameStateのデバッグAPI（タスク001、
## test_game_state_debug_support.gd参照）への結線のみを検証し、判定ロジック自体の
## 正常系・異常系・境界値はGameState側のテストが担っているため本ファイルでは扱わない。

const DEBUG_PANEL_SCENE_PATH := "res://shared/debug/debug_panel.tscn"
const RANK_ID: StringName = &"rank_g"
const NEXT_RANK_ID: StringName = &"rank_f"
const RECIPE_ID: StringName = &"recipe_test"


func before_test() -> void:
	GameState.reset_for_test()


func _make_rank(rank_id: StringName, quota_max: float, limit_turn: int) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = String(rank_id)
	rank.display_name = "テストランク"
	rank.quota_max = quota_max
	rank.limit_turn = limit_turn
	rank.traits_unlocked = false
	rank.exam_turn_limit = 10
	return rank


func _make_product(recipe_id: StringName) -> ProductInstance:
	return ProductInstance.new(recipe_id, 3, [] as Array[StringName], 10.0, 5.0)


func _make_debug_panel() -> DebugPanel:
	var panel := auto_free(load(DEBUG_PANEL_SCENE_PATH).instantiate()) as DebugPanel
	add_child(panel)
	return panel


# 正常系: パネル構成


func test_パネルには3つのボタンが存在する() -> void:
	var panel := _make_debug_panel()

	var add_gold_button: Button = panel.find_child("AddGoldButton", true, false)
	var force_end_turn_button: Button = panel.find_child("ForceEndTurnButton", true, false)
	var jump_rank_button: Button = panel.find_child("JumpRankButton", true, false)

	assert_object(add_gold_button).is_not_null()
	assert_object(force_end_turn_button).is_not_null()
	assert_object(jump_rank_button).is_not_null()


func test_パネルは表示状態である() -> void:
	var panel := _make_debug_panel()

	assert_bool(panel.visible).is_true()


# 正常系: ボタン押下→GameState連携


func test_ゴールド付与ボタン押下でゴールドが増加する() -> void:
	GameState._set_gold_for_test(0)
	var panel := _make_debug_panel()

	(panel.find_child("AddGoldButton", true, false) as Button).pressed.emit()

	assert_int(GameState.get_state()["gold"]).is_equal(1000)


func test_ノルマ即達成ボタン押下で納品待ちが決算され空になる() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(RANK_ID, 100.0, 30)})
	GameState._set_current_rank_id_for_test(RANK_ID)
	GameState._inject_pending_product_for_test(_make_product(RECIPE_ID))
	var panel := _make_debug_panel()

	(panel.find_child("ForceEndTurnButton", true, false) as Button).pressed.emit()

	assert_int(GameState.get_state()["pending_products"].size()).is_equal(0)


func test_次ランクへボタン押下で現在ランクが次ランクへ変わる() -> void:
	GameState._set_rank_masters_for_test(
		{RANK_ID: _make_rank(RANK_ID, 100.0, 30), NEXT_RANK_ID: _make_rank(NEXT_RANK_ID, 200.0, 40)}
	)
	GameState._set_current_rank_id_for_test(RANK_ID)
	var rank_state := RankState.new()
	rank_state.quota = 30.0
	rank_state.elapsed_turn = 5
	GameState._set_rank_state_for_test(rank_state)
	var panel := _make_debug_panel()

	(panel.find_child("JumpRankButton", true, false) as Button).pressed.emit()

	assert_that(GameState.get_state()["current_rank_id"]).is_equal(NEXT_RANK_ID)


# 異常系・境界値


## ボタン自体はdisabled条件を持たず、押下可否の実際の判定はすべてGameState側
## （task 001のGameStateDebugDelegate.guard()等）に委譲される設計であることの確認。
## 末尾ランクで次ランクへボタンを押しても、GameState側のガードにより現在ランクは変化しない
func test_末尾ランクで次ランクへボタンを押しても現在ランクは変化しない() -> void:
	const LAST_RANK_ID: StringName = &"rank_s"
	GameState._set_rank_masters_for_test({LAST_RANK_ID: _make_rank(LAST_RANK_ID, 100.0, 30)})
	GameState._set_current_rank_id_for_test(LAST_RANK_ID)
	var panel := _make_debug_panel()

	(panel.find_child("JumpRankButton", true, false) as Button).pressed.emit()

	assert_that(GameState.get_state()["current_rank_id"]).is_equal(LAST_RANK_ID)
