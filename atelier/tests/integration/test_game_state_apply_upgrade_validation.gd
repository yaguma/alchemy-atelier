extends GdUnitTestSuite

## GameState.apply_upgrade()の共通検証パイプライン（null検証・恒久フラグ検証・
## PurchaseValidator.can_purchase実行直前再評価・PurchaseValidator.is_valid_effect実行直前再評価・
## ゴールド減算・購入回数カウント更新・gold_changedシグナル発行）を検証する
## （FR-101〜104, FR-112〜114, FR-401〜402）。本テストのeffect_type別の状態反映結果自体は
## test_game_state_apply_upgrade_effects.gdの担当のため、ここではeffect_valueを要求しない
## catalyst_stockを既知の有効なeffect_typeとして使い、共通検証パイプラインのみを対象にする


func before_test() -> void:
	GameState.reset_for_test()


func _make_upgrade(
	is_permanent: bool = false, price: int = 100, max_purchase_count: int = 1
) -> UpgradeMaster:
	var upgrade := UpgradeMaster.new()
	upgrade.id = &"upgrade_test_dummy"
	upgrade.is_permanent = is_permanent
	upgrade.price = price
	upgrade.max_purchase_count = max_purchase_count
	upgrade.effect_type = &"catalyst_stock"
	return upgrade


# 正常系


func test_ゴールドが十分で消耗投資なら購入が成立する() -> void:
	GameState._set_gold_for_test(200)
	var upgrade := _make_upgrade(false, 100)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_true()
	assert_object(result.value).is_equal(upgrade)


func test_消耗投資はcan_purchase_permanentの値に関わらず購入できる() -> void:
	GameState._set_gold_for_test(200)
	GameState._set_can_purchase_permanent_for_test(false)
	var upgrade := _make_upgrade(false, 100)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_true()


func test_購入成立時にgoldがprice分減算される() -> void:
	GameState._set_gold_for_test(200)
	var upgrade := _make_upgrade(false, 100)

	GameState.apply_upgrade(upgrade)

	assert_int(GameState.get_state()["gold"]).is_equal(100)


func test_購入成立時にgold_changedシグナルが正しい引数で発行される() -> void:
	monitor_signals(GameState, false)
	GameState._set_gold_for_test(200)
	var upgrade := _make_upgrade(false, 100)

	GameState.apply_upgrade(upgrade)

	await assert_signal(GameState).is_emitted(GameState.gold_changed, 200, 100, -100)


func test_購入成立時にpurchased_upgrade_countsが1増える() -> void:
	GameState._set_gold_for_test(200)
	var upgrade := _make_upgrade(false, 100)

	GameState.apply_upgrade(upgrade)

	assert_int(GameState._purchased_upgrade_counts[upgrade.id]).is_equal(1)


# 異常系


func test_ゴールド不足なら購入が拒否されgoldが変化しない() -> void:
	var upgrade := _make_upgrade(false, 100)
	GameState._set_gold_for_test(upgrade.price - 1)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_false()
	assert_int(GameState.get_state()["gold"]).is_equal(upgrade.price - 1)


func test_恒久投資でcan_purchase_permanentがfalseなら購入が拒否されgoldが変化しない() -> void:
	GameState._set_gold_for_test(200)
	GameState._set_can_purchase_permanent_for_test(false)
	var upgrade := _make_upgrade(true, 100)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_false()
	assert_int(GameState.get_state()["gold"]).is_equal(200)


func test_購入が拒否された場合はgold_changedシグナルが発行されない() -> void:
	var emit_count := 0
	var handler := func(_previous: int, _new_amount: int, _delta: int) -> void: emit_count += 1
	GameState.gold_changed.connect(handler)
	var upgrade := _make_upgrade(false, 100)
	GameState._set_gold_for_test(upgrade.price - 1)

	GameState.apply_upgrade(upgrade)

	GameState.gold_changed.disconnect(handler)
	assert_int(emit_count).is_equal(0)


func test_未知のeffect_typeなら購入が拒否されgoldとcountsが変化しない() -> void:
	GameState._set_gold_for_test(200)
	var upgrade := _make_upgrade(false, 100)
	upgrade.effect_type = &"unknown_effect"

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_false()
	assert_str(result.error_code).is_equal(&"invalid_effect")
	assert_int(GameState.get_state()["gold"]).is_equal(200)
	assert_int(GameState._purchased_upgrade_counts.size()).is_equal(0)


func test_effect_valueの型が不一致なら購入が拒否されgoldが変化しない() -> void:
	GameState._set_gold_for_test(200)
	var upgrade := _make_upgrade(false, 100)
	upgrade.effect_type = &"alchemy_slot_increase"
	upgrade.effect_value = &"not_an_int"  # 本来int必須のところにStringNameを誤設定

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_false()
	assert_str(result.error_code).is_equal(&"invalid_effect")
	assert_int(GameState.get_state()["gold"]).is_equal(200)


func test_apply_upgradeにnullを渡すとクラッシュせず失敗Resultが返り状態が変化しない() -> void:
	GameState._set_gold_for_test(200)

	var result := GameState.apply_upgrade(null)

	assert_bool(result.success).is_false()
	assert_str(result.error_code).is_equal(&"invalid_upgrade")
	assert_int(GameState.get_state()["gold"]).is_equal(200)
	assert_int(GameState._purchased_upgrade_counts.size()).is_equal(0)


# 境界値


func test_ゴールドと価格が同額なら購入が成立する() -> void:
	var upgrade := _make_upgrade(false, 100)
	GameState._set_gold_for_test(upgrade.price)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_true()
	assert_int(GameState.get_state()["gold"]).is_equal(0)


func test_購入回数が上限到達直前の2回目呼び出しは購入が拒否されカウントが増えない() -> void:
	# already_purchased_count == max_purchase_count - 1（上限到達直前）の状態から開始する。
	# 1回目の呼び出しはcount(1) < max(2)のため成立しcountがmaxに到達する。
	# 2回目の呼び出しはcount(2) == max(2)のため拒否され、countはそれ以上増えない
	var upgrade := _make_upgrade(false, 100, 2)
	GameState._set_gold_for_test(1000)
	GameState._set_purchased_upgrade_counts_for_test({upgrade.id: 1})

	var first_result := GameState.apply_upgrade(upgrade)
	assert_bool(first_result.success).is_true()
	assert_int(GameState._purchased_upgrade_counts[upgrade.id]).is_equal(2)

	var second_result := GameState.apply_upgrade(upgrade)

	assert_bool(second_result.success).is_false()
	assert_int(GameState._purchased_upgrade_counts[upgrade.id]).is_equal(2)


# 異常系（アトミック性・総合）


func test_ゴールド不足かつ購入回数上限到達でもgoldとcountsが呼び出し前と完全に一致する() -> void:
	var upgrade := _make_upgrade(false, 100, 1)
	GameState._set_gold_for_test(upgrade.price - 1)
	GameState._set_purchased_upgrade_counts_for_test({upgrade.id: 1})

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_false()
	assert_int(GameState.get_state()["gold"]).is_equal(upgrade.price - 1)
	assert_int(GameState._purchased_upgrade_counts[upgrade.id]).is_equal(1)


func test_恒久フラグfalseで購入拒否時にcountsも変化しない() -> void:
	var upgrade := _make_upgrade(true, 100, 1)
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(false)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_false()
	assert_int(GameState._purchased_upgrade_counts.size()).is_equal(0)
