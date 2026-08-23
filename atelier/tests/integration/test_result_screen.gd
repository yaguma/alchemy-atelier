extends GdUnitTestSuite

const ResultScreenScene = preload("res://features/rank/ui/result_screen.tscn")


func before_test() -> void:
	GameState.reset_for_test()


func _make_screen() -> ResultScreen:
	var runner := scene_runner("res://features/rank/ui/result_screen.tscn")
	return runner.scene() as ResultScreen


func _message_text(screen: ResultScreen) -> String:
	return (screen.find_child("ResultMessageLabel", true, false) as Label).text


## GameStateのsignalに指定オブジェクトのCallableが接続されているかを判定する。
## 購読側のハンドラはprivateでテストから参照できないため、接続先オブジェクトで照合する。
func _has_connection_to(target_signal: Signal, target: Object) -> bool:
	for connection in target_signal.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == target:
			return true
	return false


# 正常系


func test_game_cleared発行でクリア表示に切り替わる() -> void:
	var screen := _make_screen()

	GameState.game_cleared.emit()

	assert_int(screen.get_result_kind()).is_equal(ResultScreen.ResultKind.CLEAR)
	assert_str(_message_text(screen)).is_equal(ResultScreen.CLEAR_MESSAGE_TEXT)


func test_game_over発行でゲームオーバー表示に切り替わる() -> void:
	var screen := _make_screen()

	GameState.game_over.emit(2)

	assert_int(screen.get_result_kind()).is_equal(ResultScreen.ResultKind.OVER)
	assert_str(_message_text(screen)).is_equal(ResultScreen.OVER_MESSAGE_TEXT)


# 異常系


func test_シグナル未発行では結果種別が未確定で文言が空になる() -> void:
	var screen := _make_screen()

	assert_int(screen.get_result_kind()).is_equal(ResultScreen.ResultKind.NONE)
	assert_str(_message_text(screen)).is_equal(ResultScreen.INITIAL_MESSAGE_TEXT)


func test_ready後に両シグナルへ接続されている() -> void:
	var screen := _make_screen()

	assert_bool(_has_connection_to(GameState.game_over, screen)).is_true()
	assert_bool(_has_connection_to(GameState.game_cleared, screen)).is_true()


func test_ツリーから除去すると両シグナルの購読が解除される() -> void:
	var screen: ResultScreen = auto_free(ResultScreenScene.instantiate())
	add_child(screen)
	assert_bool(_has_connection_to(GameState.game_over, screen)).is_true()

	remove_child(screen)

	assert_bool(_has_connection_to(GameState.game_over, screen)).is_false()
	assert_bool(_has_connection_to(GameState.game_cleared, screen)).is_false()


# 境界値


func test_クリア後にゲームオーバーが来ると後着が優先される() -> void:
	var screen := _make_screen()

	GameState.game_cleared.emit()
	GameState.game_over.emit(1)

	assert_int(screen.get_result_kind()).is_equal(ResultScreen.ResultKind.OVER)
	assert_str(_message_text(screen)).is_equal(ResultScreen.OVER_MESSAGE_TEXT)


func test_ゲームオーバー後にクリアが来ると後着が優先される() -> void:
	var screen := _make_screen()

	GameState.game_over.emit(1)
	GameState.game_cleared.emit()

	assert_int(screen.get_result_kind()).is_equal(ResultScreen.ResultKind.CLEAR)
	assert_str(_message_text(screen)).is_equal(ResultScreen.CLEAR_MESSAGE_TEXT)


func test_降格回数0でもゲームオーバー文言は変わらない() -> void:
	var screen := _make_screen()

	GameState.game_over.emit(0)

	assert_int(screen.get_result_kind()).is_equal(ResultScreen.ResultKind.OVER)
	assert_str(_message_text(screen)).is_equal(ResultScreen.OVER_MESSAGE_TEXT)
