extends GdUnitTestSuite

const PERMANENT_UPGRADE_ID: StringName = &"upgrade_recipe_unlock_mana_tonic"
const CONSUMABLE_UPGRADE_ID: StringName = &"upgrade_seed_name_purchase_ore"


func before_test() -> void:
	GameState.reset_for_test()


func _make_screen() -> WorkshopScreen:
	var runner := scene_runner("res://features/workshop/ui/workshop_screen.tscn")
	return runner.scene() as WorkshopScreen


func _find_dialog(screen: WorkshopScreen) -> PurchaseConfirmDialog:
	return screen.find_child("PurchaseConfirmDialog", true, false) as PurchaseConfirmDialog


func _find_overlay_layer(screen: WorkshopScreen) -> Control:
	return screen.find_child("OverlayLayer", true, false) as Control


func _press_confirm(dialog: PurchaseConfirmDialog) -> void:
	(dialog.find_child("ConfirmButton", true, false) as Button).pressed.emit()


func _press_cancel(dialog: PurchaseConfirmDialog) -> void:
	(dialog.find_child("CancelButton", true, false) as Button).pressed.emit()


# 正常系（消耗投資は即時購入のまま）


func test_消耗投資アイテムの購入要求はダイアログを経由せず即時購入される() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(100)
	var screen := _make_screen()

	screen._on_purchase_requested(CONSUMABLE_UPGRADE_ID)

	assert_bool(screen.is_confirm_dialog_open()).is_false()
	assert_int(GameState.get_state()["gold"]).is_equal(50)
	assert_str(screen.get_toast_text()).contains("種の指名買い：鉱石の種")


# 正常系（恒久投資はダイアログを挟む）


func test_恒久投資アイテムの購入要求では即時購入されず確認ダイアログが開く() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(true)
	var screen := _make_screen()

	screen._on_purchase_requested(PERMANENT_UPGRADE_ID)

	assert_bool(screen.is_confirm_dialog_open()).is_true()
	assert_int(GameState.get_state()["gold"]).is_equal(1000)
	assert_int(GameState.get_purchased_count(PERMANENT_UPGRADE_ID)).is_equal(0)
	assert_str(screen.get_toast_text()).is_equal("")


func test_確認ダイアログには対象アイテムの名称と価格が表示される() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(true)
	var screen := _make_screen()

	screen._on_purchase_requested(PERMANENT_UPGRADE_ID)

	var dialog := _find_dialog(screen)
	assert_str(dialog.get_name_text()).is_equal("レシピ解禁：魔力秘薬")
	assert_str(dialog.get_price_text()).is_equal("800 G")


func test_確認ダイアログで購入するを押すと購入が実行されダイアログが閉じる() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(true)
	var screen := _make_screen()
	screen._on_purchase_requested(PERMANENT_UPGRADE_ID)

	_press_confirm(_find_dialog(screen))

	assert_bool(screen.is_confirm_dialog_open()).is_false()
	assert_int(GameState.get_state()["gold"]).is_equal(200)
	assert_int(GameState.get_purchased_count(PERMANENT_UPGRADE_ID)).is_equal(1)
	assert_str(screen.get_toast_text()).contains("レシピ解禁：魔力秘薬")


func test_確認ダイアログでキャンセルを押すと状態が変化せずダイアログが閉じる() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(true)
	var screen := _make_screen()
	screen._on_purchase_requested(PERMANENT_UPGRADE_ID)

	_press_cancel(_find_dialog(screen))

	assert_bool(screen.is_confirm_dialog_open()).is_false()
	assert_int(GameState.get_state()["gold"]).is_equal(1000)
	assert_int(GameState.get_purchased_count(PERMANENT_UPGRADE_ID)).is_equal(0)
	assert_str(screen.get_toast_text()).is_equal("")


# 異常系（回帰確認）


func test_恒久投資タブが非活性の場合はダイアログを開かず失敗トーストが表示される() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	var screen := _make_screen()

	screen._on_purchase_requested(PERMANENT_UPGRADE_ID)

	assert_bool(screen.is_confirm_dialog_open()).is_false()
	assert_int(GameState.get_state()["gold"]).is_equal(1000)
	assert_int(GameState.get_purchased_count(PERMANENT_UPGRADE_ID)).is_equal(0)
	assert_str(screen.get_toast_text()).contains("購入できませんでした")


func test_マスター未登録のupgrade_idで購入要求してもダイアログが開かない() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(true)
	var screen := _make_screen()

	screen._on_purchase_requested(&"upgrade_nonexistent")

	assert_bool(screen.is_confirm_dialog_open()).is_false()
	assert_int(GameState.get_state()["gold"]).is_equal(1000)


# 境界値（多重起動）


func test_確認ダイアログ表示中に同じアイテムを再要求してもダイアログは多重生成されない() -> void:
	GameState.load_workshop_master_data()
	GameState._set_gold_for_test(1000)
	GameState._set_can_purchase_permanent_for_test(true)
	var screen := _make_screen()

	screen._on_purchase_requested(PERMANENT_UPGRADE_ID)
	screen._on_purchase_requested(PERMANENT_UPGRADE_ID)

	assert_int(_find_overlay_layer(screen).get_child_count()).is_equal(1)
	assert_bool(screen.is_confirm_dialog_open()).is_true()
