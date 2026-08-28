extends GdUnitTestSuite

## MainSceneの工房往復ルーティング（FR-104, FR-105）の統合テスト。
## GardenScreen/AlchemyScreenのshop_requestedで工房へ入り、
## WorkshopScreen.screen_closedで直前フェーズへ戻ることを検証する。

const MAIN_SCENE_PATH := "res://scenes/main.tscn"


func before_test() -> void:
	GameState.reset_for_test()


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


func _garden(main: MainScene) -> GardenScreen:
	return main.find_child("GardenScreen", true, false) as GardenScreen


func _alchemy(main: MainScene) -> AlchemyScreen:
	return main.find_child("AlchemyScreen", true, false) as AlchemyScreen


func _workshop(main: MainScene) -> WorkshopScreen:
	return main.find_child("WorkshopScreen", true, false) as WorkshopScreen


func _current_phase() -> StringName:
	return GameState.get_state()["current_phase"]


# 正常系


func test_庭表示中のshop_requestedでworkshopへ切り替わる() -> void:
	var main := _make_main()

	_garden(main).shop_requested.emit()

	assert_that(_current_phase()).is_equal(&"workshop")
	assert_that(main.get_visible_phase()).is_equal(&"workshop")


func test_調合表示中のshop_requestedでworkshopへ切り替わる() -> void:
	var main := _make_main()
	GameState.set_phase(&"alchemy")

	_alchemy(main).shop_requested.emit()

	assert_that(_current_phase()).is_equal(&"workshop")
	assert_that(main.get_visible_phase()).is_equal(&"workshop")


func test_庭から入った工房を閉じるとgardenへ復帰する() -> void:
	var main := _make_main()
	_garden(main).shop_requested.emit()

	_workshop(main).screen_closed.emit()

	assert_that(_current_phase()).is_equal(&"garden")
	assert_that(main.get_visible_phase()).is_equal(&"garden")


func test_調合から入った工房を閉じるとalchemyへ復帰する() -> void:
	var main := _make_main()
	GameState.set_phase(&"alchemy")
	_alchemy(main).shop_requested.emit()

	_workshop(main).screen_closed.emit()

	assert_that(_current_phase()).is_equal(&"alchemy")
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


# 境界値


func test_workshop表示中の再shop_requestedで復帰先が上書きされない() -> void:
	var main := _make_main()
	GameState.set_phase(&"alchemy")
	_alchemy(main).shop_requested.emit()

	_garden(main).shop_requested.emit()
	_workshop(main).screen_closed.emit()

	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


func test_工房への往復を繰り返しても毎回直前フェーズへ復帰する() -> void:
	var main := _make_main()

	_garden(main).shop_requested.emit()
	_workshop(main).screen_closed.emit()
	assert_that(main.get_visible_phase()).is_equal(&"garden")

	GameState.set_phase(&"alchemy")
	_alchemy(main).shop_requested.emit()
	_workshop(main).screen_closed.emit()

	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


# 異常系


func test_直前フェーズの記録がない状態でscreen_closedを受けるとgardenへ復帰する() -> void:
	var main := _make_main()
	GameState.set_phase(&"workshop")

	_workshop(main).screen_closed.emit()

	assert_that(_current_phase()).is_equal(&"garden")
	assert_that(main.get_visible_phase()).is_equal(&"garden")
