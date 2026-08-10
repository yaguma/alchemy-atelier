extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


func test_初期状態のcurrent_phaseはgardenである() -> void:
	assert_that(GameState.get_state()["current_phase"]).is_equal(&"garden")


func test_get_stateは初期値としてgold_0とcurrent_turn_1を含む() -> void:
	var state := GameState.get_state()
	assert_int(state["gold"]).is_equal(0)
	assert_int(state["current_turn"]).is_equal(1)


func test_set_phaseでphase_changedシグナルが発行される() -> void:
	# GameStateはAutoload（テスト終了後も生存し続ける必要がある）のため、
	# monitor_signals()のデフォルト挙動（テスト終了時の自動解放）を明示的に無効化する
	monitor_signals(GameState, false)
	GameState.set_phase(&"alchemy")
	await assert_signal(GameState).is_emitted(GameState.phase_changed, &"garden", &"alchemy")


func test_reset_for_test実行後にgoldが初期値0へ戻る() -> void:
	GameState.set_phase(&"alchemy")
	GameState.reset_for_test()
	assert_int(GameState.get_state()["gold"]).is_equal(0)


func test_get_state戻り値のDictionaryを書き換えても内部状態は変化しない() -> void:
	var state := GameState.get_state()
	state["current_phase"] = &"dummy"
	assert_that(GameState.get_state()["current_phase"]).is_not_equal(&"dummy")
