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


## FR-007。get_state()の戻り値がupgrade_mastersキーを持つ
func test_get_stateがupgrade_mastersキーを含む() -> void:
	var state := GameState.get_state()

	assert_bool(state.has("upgrade_masters")).is_true()


## FR-007。reset_for_test()直後はupgrade_mastersが空
func test_reset_for_test直後はget_stateのupgrade_mastersが空である() -> void:
	var state := GameState.get_state()

	assert_int((state["upgrade_masters"] as Dictionary).size()).is_equal(0)


## FR-007, FR-011。load_workshop_master_data()呼び出し後、実データ由来のUpgradeMasterが5件反映される
func test_load_workshop_master_data後にget_stateのupgrade_mastersに実データ5件が反映される() -> void:
	GameState.load_workshop_master_data()

	var upgrade_masters: Dictionary = GameState.get_state()["upgrade_masters"]

	assert_int(upgrade_masters.size()).is_equal(5)
	assert_bool(upgrade_masters.has(&"upgrade_alchemy_slot")).is_true()
	var upgrade: UpgradeMaster = upgrade_masters[&"upgrade_alchemy_slot"]
	assert_object(upgrade).is_instanceof(UpgradeMaster)


## FR-008。get_state()の戻り値がpurchased_upgrade_countsキーを持つ
func test_get_stateがpurchased_upgrade_countsキーを含む() -> void:
	var state := GameState.get_state()

	assert_bool(state.has("purchased_upgrade_counts")).is_true()


## FR-008。_set_purchased_upgrade_counts_for_test()で注入した値がget_state()に反映される
func test_purchased_upgrade_counts注入後にget_stateへ反映される() -> void:
	GameState._set_purchased_upgrade_counts_for_test({&"upgrade_alchemy_slot": 2})

	var purchased_upgrade_counts: Dictionary = GameState.get_state()["purchased_upgrade_counts"]

	assert_int(purchased_upgrade_counts[&"upgrade_alchemy_slot"]).is_equal(2)


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


## FR-007。get_state()戻り値のupgrade_mastersへキー追加/削除しても内部状態は汚染されない
func test_get_state戻り値のupgrade_mastersへキーを追加削除しても内部状態は変化しない() -> void:
	GameState.load_workshop_master_data()

	var upgrade_masters: Dictionary = GameState.get_state()["upgrade_masters"]
	upgrade_masters[&"upgrade_injected"] = null
	upgrade_masters.erase(&"upgrade_alchemy_slot")

	var upgrade_masters_after: Dictionary = GameState.get_state()["upgrade_masters"]
	assert_int(upgrade_masters_after.size()).is_equal(5)
	assert_bool(upgrade_masters_after.has(&"upgrade_injected")).is_false()
	assert_bool(upgrade_masters_after.has(&"upgrade_alchemy_slot")).is_true()


## FR-008。get_state()戻り値のpurchased_upgrade_countsの値を書き換えても内部状態は汚染されない
func test_get_state戻り値のpurchased_upgrade_countsの値を書き換えても内部状態は変化しない() -> void:
	GameState._set_purchased_upgrade_counts_for_test({&"upgrade_alchemy_slot": 1})

	var purchased_upgrade_counts: Dictionary = GameState.get_state()["purchased_upgrade_counts"]
	purchased_upgrade_counts[&"upgrade_alchemy_slot"] = 999

	var purchased_upgrade_counts_after: Dictionary = (
		GameState.get_state()["purchased_upgrade_counts"]
	)
	assert_int(purchased_upgrade_counts_after[&"upgrade_alchemy_slot"]).is_equal(1)


func test_reset_for_testで工房強化関連フィールドが初期状態に戻る() -> void:
	GameState._set_can_purchase_permanent_for_test(true)
	GameState._set_purchased_upgrade_counts_for_test({&"upgrade_alchemy_slot": 3})

	GameState.reset_for_test()

	assert_bool(GameState._can_purchase_permanent).is_false()
	assert_int(GameState._purchased_upgrade_counts.size()).is_equal(0)
	assert_int(GameState._upgrade_masters.size()).is_equal(0)
