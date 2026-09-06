extends GdUnitTestSuite

## GameState.reset_for_new_game()（本番コードパスから呼べる新規ゲーム用リセットAPI）と
## 既存reset_for_test()の非デグレを検証する。GameStateResetDelegate導入で初期化本体を
## 共有した後も、両者の外部から見た振る舞い（ガードの有無・リセット結果）が変わらないことを確認する。


func after_test() -> void:
	GameState.reset_for_test()


func test_reset_for_new_gameは所持ゴールドと現在ランクを初期値へ戻す() -> void:
	GameState._set_gold_for_test(9999)
	GameState._set_current_rank_id_for_test(&"S")

	GameState.reset_for_new_game()

	var state := GameState.get_state()
	assert_int(int(state["gold"])).is_equal(0)
	assert_str(String(state["current_rank_id"])).is_equal(String(GameBalance.INITIAL_RANK_ID))


func test_reset_for_new_gameは現在フェーズを庭へ戻す() -> void:
	GameState.set_phase(&"alchemy")

	GameState.reset_for_new_game()

	assert_str(String(GameState.get_state()["current_phase"])).is_equal("garden")


## 🔵 デバッグビルド判定に依存せず、本番コードパス相当でも呼び出せることの確認
## （reset_for_test()と異なりGameStateTestSupport.guard()を経由しない）
func test_reset_for_new_gameはOS_is_debug_buildに関わらず状態を変更する() -> void:
	GameState._set_gold_for_test(500)

	GameState.reset_for_new_game()

	assert_int(int(GameState.get_state()["gold"])).is_equal(0)
