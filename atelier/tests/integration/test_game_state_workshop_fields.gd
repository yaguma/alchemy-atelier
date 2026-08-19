extends GdUnitTestSuite


func before_test() -> void:
	GameState.reset_for_test()


# 正常系


func test_reset_for_test直後は工房強化関連フィールドが初期値である() -> void:
	assert_bool(GameState._can_purchase_permanent).is_false()
	assert_int(GameState._purchased_upgrade_counts.size()).is_equal(0)
	assert_int(GameState._upgrade_masters.size()).is_equal(0)


func test_get_stateがcan_purchase_permanentキーを含む() -> void:
	var state := GameState.get_state()

	assert_bool(state.has("can_purchase_permanent")).is_true()
	assert_bool(state["can_purchase_permanent"]).is_false()


func test_set_can_purchase_permanent_for_testで注入した値が状態に反映される() -> void:
	GameState._set_can_purchase_permanent_for_test(true)

	assert_bool(GameState._can_purchase_permanent).is_true()
	assert_bool(GameState.get_state()["can_purchase_permanent"]).is_true()


func test_set_purchased_upgrade_counts_for_testで注入した値が状態に反映される() -> void:
	var counts: Dictionary = {&"upgrade_alchemy_slot": 2, &"upgrade_garden_slot": 1}

	GameState._set_purchased_upgrade_counts_for_test(counts)

	assert_int(GameState._purchased_upgrade_counts[&"upgrade_alchemy_slot"]).is_equal(2)
	assert_int(GameState._purchased_upgrade_counts[&"upgrade_garden_slot"]).is_equal(1)


# 異常系


## テスト専用APIガード: デバッグビルド外からの実行は禁止される（既存パターン踏襲の確認）。
## CIはデバッグビルドで実行されるため、この呼び出し自体は成功する前提で
## GameStateTestSupport.guard()が例外を投げずfalseを返す実装であることを間接的に確認する
func test_set_can_purchase_permanent_for_testはデバッグビルドで正常に動作する() -> void:
	assert_bool(OS.is_debug_build()).is_true()

	GameState._set_can_purchase_permanent_for_test(true)

	assert_bool(GameState._can_purchase_permanent).is_true()


func test_set_purchased_upgrade_counts_for_testはデバッグビルドで正常に動作する() -> void:
	assert_bool(OS.is_debug_build()).is_true()

	GameState._set_purchased_upgrade_counts_for_test({&"upgrade_alchemy_slot": 1})

	assert_int(GameState._purchased_upgrade_counts[&"upgrade_alchemy_slot"]).is_equal(1)


# 境界値・エッジケース


## FR-013相当: set_purchased_upgrade_counts_for_test()は内部でduplicate()するため、
## 注入後に呼び出し元のDictionaryを変更しても内部状態は汚染されない
func test_set_purchased_upgrade_counts_for_test注入後に引数を変更しても内部状態は汚染されない() -> void:
	var counts: Dictionary = {&"upgrade_alchemy_slot": 1}

	GameState._set_purchased_upgrade_counts_for_test(counts)
	counts[&"upgrade_alchemy_slot"] = 999

	assert_int(GameState._purchased_upgrade_counts[&"upgrade_alchemy_slot"]).is_equal(1)


## FR-410相当: get_state()の戻り値を変更してもGameState内部の正本は汚染されない
func test_get_stateの戻り値を変更しても内部状態は汚染されない() -> void:
	GameState._set_can_purchase_permanent_for_test(true)

	var returned := GameState.get_state()
	returned["can_purchase_permanent"] = false

	var again := GameState.get_state()
	assert_bool(again["can_purchase_permanent"]).is_true()


func test_reset_for_testで工房強化関連フィールドが初期状態に戻る() -> void:
	GameState._set_can_purchase_permanent_for_test(true)
	GameState._set_purchased_upgrade_counts_for_test({&"upgrade_alchemy_slot": 3})

	GameState.reset_for_test()

	assert_bool(GameState._can_purchase_permanent).is_false()
	assert_int(GameState._purchased_upgrade_counts.size()).is_equal(0)
	assert_int(GameState._upgrade_masters.size()).is_equal(0)
