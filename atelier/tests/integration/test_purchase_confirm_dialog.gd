extends GdUnitTestSuite

const SCENE_PATH := "res://features/workshop/ui/purchase_confirm_dialog.tscn"


func _make_upgrade(
	id: StringName, name: String, price: int, effect_type: StringName, effect_value: Variant
) -> UpgradeMaster:
	var upgrade := UpgradeMaster.new()
	upgrade.id = id
	upgrade.name = name
	upgrade.price = price
	upgrade.effect_type = effect_type
	upgrade.effect_value = effect_value
	return upgrade


func _make_default_upgrade() -> UpgradeMaster:
	return _make_upgrade(&"alchemy_slot_1", "調合台の拡張", 500, &"alchemy_slot_increase", 1)


func _make_runner() -> GdUnitSceneRunner:
	return scene_runner(SCENE_PATH)


func _make_dialog() -> PurchaseConfirmDialog:
	return _make_runner().scene() as PurchaseConfirmDialog


func _find_confirm_button(dialog: PurchaseConfirmDialog) -> Button:
	return dialog.find_child("ConfirmButton", true, false) as Button


func _find_cancel_button(dialog: PurchaseConfirmDialog) -> Button:
	return dialog.find_child("CancelButton", true, false) as Button


## confirmedシグナルの発行を同期的に観測する。ハンドラがqueue_free()まで行うため、
## awaitを挟むmonitor_signals/assert_signalでは解放済みノードへアクセスしうる
func _watch_confirmed(dialog: PurchaseConfirmDialog) -> Array[StringName]:
	var received: Array[StringName] = []
	dialog.confirmed.connect(func(upgrade_id: StringName) -> void: received.append(upgrade_id))
	return received


func _watch_cancelled(dialog: PurchaseConfirmDialog) -> Array[bool]:
	var received: Array[bool] = []
	dialog.cancelled.connect(func() -> void: received.append(true))
	return received


# 正常系（表示内容）


func test_setup後にアイテム名が表示される() -> void:
	var dialog := _make_dialog()
	var upgrade := _make_default_upgrade()

	dialog.setup(upgrade)

	assert_str(dialog.get_name_text()).is_equal("調合台の拡張")


func test_setup後に価格がG付きで表示される() -> void:
	var dialog := _make_dialog()
	var upgrade := _make_default_upgrade()

	dialog.setup(upgrade)

	assert_str(dialog.get_price_text()).is_equal("500 G")


func test_setup後に効果説明がUpgradeEffectDescriberの結果と一致する() -> void:
	var dialog := _make_dialog()
	var upgrade := _make_default_upgrade()

	dialog.setup(upgrade)

	assert_str(dialog.get_effect_text()).is_equal(UpgradeEffectDescriber.describe(upgrade))
	assert_str(dialog.get_effect_text()).is_equal("調合の投入枠が1増えます")


# 正常系（確認・キャンセル）


func test_購入するボタン押下でconfirmedがupgrade_id付きで発行される() -> void:
	var dialog := _make_dialog()
	dialog.setup(_make_default_upgrade())
	var confirmed_events := _watch_confirmed(dialog)

	_find_confirm_button(dialog).pressed.emit()

	assert_array(confirmed_events).contains_exactly([&"alchemy_slot_1"])


func test_購入するボタン押下でダイアログ自身が解放予約される() -> void:
	var dialog := _make_dialog()
	dialog.setup(_make_default_upgrade())

	_find_confirm_button(dialog).pressed.emit()

	assert_bool(dialog.is_queued_for_deletion()).is_true()


func test_キャンセルボタン押下でcancelledが発行され解放予約される() -> void:
	var dialog := _make_dialog()
	dialog.setup(_make_default_upgrade())
	var cancelled_events := _watch_cancelled(dialog)
	var confirmed_events := _watch_confirmed(dialog)

	_find_cancel_button(dialog).pressed.emit()

	assert_array(cancelled_events).has_size(1)
	assert_array(confirmed_events).is_empty()
	assert_bool(dialog.is_queued_for_deletion()).is_true()


func test_シグナル未接続でキャンセルしても副作用なく解放される() -> void:
	var gold_before: int = GameState.get_state()["gold"]
	var dialog := _make_dialog()
	dialog.setup(_make_default_upgrade())

	_find_cancel_button(dialog).pressed.emit()

	assert_int(GameState.get_state()["gold"]).is_equal(gold_before)
	assert_bool(dialog.is_queued_for_deletion()).is_true()


func test_Escapeキーでキャンセルボタンと同じ結果になる() -> void:
	var runner := _make_runner()
	var dialog := runner.scene() as PurchaseConfirmDialog
	dialog.setup(_make_default_upgrade())
	var cancelled_events := _watch_cancelled(dialog)

	runner.simulate_action_pressed("ui_cancel")

	assert_array(cancelled_events).has_size(1)
	assert_bool(dialog.is_queued_for_deletion()).is_true()


# 正常系（open_singleton）


func test_open_singletonは現在参照がなければ新規生成しparentへ追加する() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)

	var dialog := PurchaseConfirmDialog.open_singleton(
		null,
		parent,
		_make_default_upgrade(),
		func(_id: StringName) -> void: pass,
		func() -> void: pass
	)

	assert_object(dialog).is_not_null()
	assert_bool(parent.get_children().has(dialog)).is_true()
	assert_str(dialog.get_name_text()).is_equal("調合台の拡張")


func test_open_singletonが生成したダイアログのシグナルでコールバックが呼ばれる() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)
	var confirmed_ids: Array[StringName] = []
	var dialog := PurchaseConfirmDialog.open_singleton(
		null,
		parent,
		_make_default_upgrade(),
		func(upgrade_id: StringName) -> void: confirmed_ids.append(upgrade_id),
		func() -> void: pass
	)

	_find_confirm_button(dialog).pressed.emit()

	assert_array(confirmed_ids).contains_exactly([&"alchemy_slot_1"])


func test_open_singletonが生成したダイアログのキャンセルでコールバックが呼ばれる() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)
	var cancelled_events: Array[bool] = []
	var dialog := PurchaseConfirmDialog.open_singleton(
		null,
		parent,
		_make_default_upgrade(),
		func(_id: StringName) -> void: pass,
		func() -> void: cancelled_events.append(true)
	)

	_find_cancel_button(dialog).pressed.emit()

	assert_array(cancelled_events).has_size(1)


# 異常系・境界値


func test_open_singletonは既存インスタンスがあれば新規生成しない() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)
	var existing := PurchaseConfirmDialog.open_singleton(
		null,
		parent,
		_make_default_upgrade(),
		func(_id: StringName) -> void: pass,
		func() -> void: pass
	)
	var other := _make_upgrade(&"garden_slot_1", "庭の拡張", 300, &"garden_slot_increase", 2)

	var result := PurchaseConfirmDialog.open_singleton(
		existing, parent, other, func(_id: StringName) -> void: pass, func() -> void: pass
	)

	assert_object(result).is_same(existing)
	assert_int(parent.get_children().size()).is_equal(1)
	assert_str(existing.get_name_text()).is_equal("調合台の拡張")


func test_購入操作を連続で行ってもconfirmedは1度しか発行されない() -> void:
	var dialog := _make_dialog()
	dialog.setup(_make_default_upgrade())
	var confirmed_events := _watch_confirmed(dialog)
	var confirm_button := _find_confirm_button(dialog)

	confirm_button.pressed.emit()
	confirm_button.pressed.emit()

	assert_array(confirmed_events).has_size(1)


func test_購入確定後にキャンセルが届いてもcancelledは発行されない() -> void:
	var dialog := _make_dialog()
	dialog.setup(_make_default_upgrade())
	var cancelled_events := _watch_cancelled(dialog)

	_find_confirm_button(dialog).pressed.emit()
	_find_cancel_button(dialog).pressed.emit()

	assert_array(cancelled_events).is_empty()


func test_未知のeffect_typeでは効果説明が空表示になる() -> void:
	var dialog := _make_dialog()
	var upgrade := _make_upgrade(&"unknown_1", "謎の強化", 100, &"unknown_effect", 1)

	dialog.setup(upgrade)

	assert_str(dialog.get_effect_text()).is_equal("")


func test_価格0のアイテムでも価格表示が崩れない() -> void:
	var dialog := _make_dialog()
	var upgrade := _make_upgrade(&"free_1", "無料強化", 0, &"catalyst_stock", 1)

	dialog.setup(upgrade)

	assert_str(dialog.get_price_text()).is_equal("0 G")
	assert_str(dialog.get_effect_text()).is_equal("触媒素材を1個獲得します")
