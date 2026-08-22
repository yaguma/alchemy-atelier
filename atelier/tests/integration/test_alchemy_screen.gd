extends GdUnitTestSuite

const RECIPE_ID := &"recipe_test"
const RANK_ID := &"rank_test"
const BASE_CONTRIBUTION := 10.0
const BASE_REWARD := 5.0
const SLOT_COUNT := 2


func before_test() -> void:
	GameState.reset_for_test()
	GameState._set_recipe_masters_for_test({RECIPE_ID: _make_recipe(RECIPE_ID, "テストレシピ")})
	GameState._set_unlocked_recipe_ids_for_test([RECIPE_ID] as Array[StringName])
	GameState._set_alchemy_slot_count_for_test(SLOT_COUNT)
	_set_rank(false)


func _make_recipe(id: StringName, recipe_name: String) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = recipe_name
	recipe.base_contribution = BASE_CONTRIBUTION
	recipe.base_reward = BASE_REWARD
	return recipe


func _set_rank(traits_unlocked: bool) -> void:
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.traits_unlocked = traits_unlocked
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)


func _inject_material(instance_id: String, quality: int, tags: Array[StringName] = []) -> void:
	GameState._inject_material_for_test(
		MaterialInstance.new(instance_id, &"material_herb", quality, tags)
	)


func _make_screen() -> AlchemyScreen:
	var runner := scene_runner("res://features/alchemy/ui/alchemy_screen.tscn")
	return runner.scene() as AlchemyScreen


func _select_recipe(screen: AlchemyScreen, recipe_id: StringName) -> void:
	var option_button := screen.find_child("RecipeOptionButton", true, false) as OptionButton
	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == recipe_id:
			option_button.select(index)
			option_button.item_selected.emit(index)
			return
	fail("解禁済みレシピ %s がドロップダウンに存在しません" % recipe_id)


func _place_material(screen: AlchemyScreen, instance_id: String) -> void:
	var row := screen.find_child("MaterialEntry_%s" % instance_id, true, false) as MaterialEntryRow
	(row.find_child("PlaceButton", true, false) as Button).pressed.emit()


func _find_slot_view(screen: AlchemyScreen, slot_index: int) -> AlchemySlotView:
	var container := screen.find_child("SlotsContainer", true, false) as Container
	return container.get_child(slot_index) as AlchemySlotView


func _find_button(screen: AlchemyScreen, node_name: String) -> Button:
	return screen.find_child(node_name, true, false) as Button


func _preview_panel(screen: AlchemyScreen) -> AlchemyPreviewPanel:
	return screen.find_child("AlchemyPreviewPanel", true, false) as AlchemyPreviewPanel


func _inventory_list(screen: AlchemyScreen) -> MaterialInventoryList:
	return screen.find_child("MaterialInventoryList", true, false) as MaterialInventoryList


func _delivery_screen(screen: AlchemyScreen) -> GuildDeliveryScreen:
	return screen.find_child("GuildDeliveryScreen", true, false) as GuildDeliveryScreen


func _label_text(screen: AlchemyScreen, node_name: String) -> String:
	return (screen.find_child(node_name, true, false) as Label).text


# 🔴 コードレビュー指摘対応。"QualityLabel"はAlchemyPreviewPanelとMaterialEntryRowの双方に
# 同名で存在するため、screen全体からのfind_child()は木構造上の兄弟順に依存する脆いルックアップになる
# （たまたまAlchemyPreviewPanelがMaterialInventoryListより先に配置されているため現状は通っている）。
# プレビュー系ラベルは必ずAlchemyPreviewPanel配下に限定して探索する
func _preview_label_text(screen: AlchemyScreen, node_name: String) -> String:
	return (_preview_panel(screen).find_child(node_name, true, false) as Label).text


func _screen_source() -> String:
	var raw := FileAccess.get_file_as_string("res://features/alchemy/ui/alchemy_screen.gd")
	return raw.replace("\r\n", "\n")


func _pending_count() -> int:
	return (GameState.get_state()["pending_products"] as Array[ProductInstance]).size()


# 正常系（レシピ選択〜プレビュー）


func test_レシピ選択と素材投入で投入枠が埋まりプレビューが更新される() -> void:
	_inject_material("mat_1", 4)
	var screen := _make_screen()

	_select_recipe(screen, RECIPE_ID)
	_place_material(screen, "mat_1")

	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(AlchemySlotView.Status.FILLED)
	assert_int(_find_slot_view(screen, 1).get_status()).is_equal(AlchemySlotView.Status.EMPTY)
	# 品質4 → 倍率1.75、特性なし → 貢献度10*1.75=17.5 / 報酬5*1.75=8.75
	assert_str(_preview_label_text(screen, "QualityLabel")).is_equal("品質: 4")
	assert_str(_preview_label_text(screen, "ValueLabel")).is_equal("見込み貢献度: 17.5 / 見込み報酬: 8.8")


func test_投入済み素材は在庫一覧から除外される() -> void:
	_inject_material("mat_1", 3)
	_inject_material("mat_2", 3)
	var screen := _make_screen()

	_place_material(screen, "mat_1")

	assert_int(_inventory_list(screen).get_entry_count()).is_equal(1)
	assert_object(screen.find_child("MaterialEntry_mat_1", true, false)).is_null()


func test_レシピ未選択または0投入ではプレビューが空表示になる() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()

	# レシピ未選択かつ0投入（初期状態）
	assert_str(_preview_label_text(screen, "QualityLabel")).is_equal("品質: -")

	# レシピ未選択で投入だけした場合も計算しない
	_place_material(screen, "mat_1")
	assert_str(_preview_label_text(screen, "QualityLabel")).is_equal("品質: -")


func test_指定依頼に合致するとプレビューにボーナス適用後の値が表示される() -> void:
	var order := DailyOrderMaster.new()
	order.id = "order_test"
	order.condition_type = "item"
	order.target_recipe_id = String(RECIPE_ID)
	order.match_bonus_multiplier = 2.0
	GameState._set_current_daily_order_for_test(order)
	_inject_material("mat_1", 4)
	var screen := _make_screen()

	_select_recipe(screen, RECIPE_ID)
	_place_material(screen, "mat_1")

	assert_bool(_preview_panel(screen).is_order_matched()).is_true()
	# 貢献度17.5 / 報酬8.75 に指定合致ボーナス2.0倍
	assert_str(_preview_label_text(screen, "ValueLabel")).is_equal("見込み貢献度: 35.0 / 見込み報酬: 17.5")


## 🔴 コードレビュー指摘対応（PR#30）の回帰テスト。GameStateGuildDelegate.deliver_pending_products()は
## 試験中(in_exam)に指定依頼をnullへ切り替えボーナスを不適用にするが、以前のAlchemyScreenは
## この分岐を無視して常に指定合致ボーナスを見込んだプレビューを表示していた（実際の納品結果と乖離するバグ）
func test_試験中は指定依頼に合致していてもプレビューにボーナスが適用されない() -> void:
	var order := DailyOrderMaster.new()
	order.id = "order_test"
	order.condition_type = "item"
	order.target_recipe_id = String(RECIPE_ID)
	order.match_bonus_multiplier = 2.0
	GameState._set_current_daily_order_for_test(order)
	GameState._set_exam_state_for_test(ExamState.new(), true)
	_inject_material("mat_1", 4)
	var screen := _make_screen()

	_select_recipe(screen, RECIPE_ID)
	_place_material(screen, "mat_1")

	assert_bool(_preview_panel(screen).is_order_matched()).is_false()
	# ボーナス不適用のため貢献度17.5 / 報酬8.75のまま（指定合致時の35.0/17.5にならない）
	assert_str(_preview_label_text(screen, "ValueLabel")).is_equal("見込み貢献度: 17.5 / 見込み報酬: 8.8")


# 正常系（投入取り消し）


func test_投入枠のクリアで素材が在庫へ戻る() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_select_recipe(screen, RECIPE_ID)
	_place_material(screen, "mat_1")

	_find_slot_view(screen, 0).clear_requested.emit(0)

	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(AlchemySlotView.Status.EMPTY)
	assert_int(_inventory_list(screen).get_entry_count()).is_equal(1)
	assert_str(_preview_label_text(screen, "QualityLabel")).is_equal("品質: -")


func test_先頭枠のクリアで後続の投入がスロット順に詰められる() -> void:
	_inject_material("mat_1", 3)
	_inject_material("mat_2", 5)
	var screen := _make_screen()
	_place_material(screen, "mat_1")
	_place_material(screen, "mat_2")

	_find_slot_view(screen, 0).clear_requested.emit(0)

	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(AlchemySlotView.Status.FILLED)
	assert_int(_find_slot_view(screen, 1).get_status()).is_equal(AlchemySlotView.Status.EMPTY)
	assert_str(_label_text(screen, "MaterialLabel")).contains("Q5")


# 正常系（調合実行成功）


func test_調合実行成功で投入枠がリセットされ在庫が更新されトーストが出る() -> void:
	_inject_material("mat_1", 3)
	_inject_material("mat_2", 3)
	var screen := _make_screen()
	_select_recipe(screen, RECIPE_ID)
	_place_material(screen, "mat_1")

	_find_button(screen, "ExecuteButton").pressed.emit()

	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(AlchemySlotView.Status.EMPTY)
	assert_int(_inventory_list(screen).get_entry_count()).is_equal(1)
	assert_str(screen.get_toast_text()).is_not_empty()
	assert_int(_pending_count()).is_equal(1)


# 異常系（調合実行失敗）


func test_調合実行失敗時はトーストのみ表示され投入枠と在庫が変化しない() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_place_material(screen, "mat_1")

	# レシピ未選択のまま直接呼ぶ（ボタンは無効化されているため）
	GameState.execute_alchemy(&"recipe_unknown", ["mat_1"] as Array[String])

	assert_str(screen.get_toast_text()).is_equal(AlchemyScreen.error_message(&"unknown_recipe_id"))
	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(AlchemySlotView.Status.FILLED)
	assert_int(_inventory_list(screen).get_entry_count()).is_equal(0)


func test_未知のerror_codeでもトーストにコードが提示される() -> void:
	assert_str(AlchemyScreen.error_message(&"unexpected_code")).contains("unexpected_code")


# 境界値（ボタン活性制御）


func test_調合実行ボタンはレシピ選択済みかつ1件以上投入でのみ活性化する() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	var execute_button := _find_button(screen, "ExecuteButton")

	assert_bool(execute_button.disabled).is_true()  # レシピ未選択・0投入

	_select_recipe(screen, RECIPE_ID)
	assert_bool(execute_button.disabled).is_true()  # レシピのみ選択（0投入）

	_place_material(screen, "mat_1")
	assert_bool(execute_button.disabled).is_false()  # 選択済み・1件投入

	_find_slot_view(screen, 0).clear_requested.emit(0)
	assert_bool(execute_button.disabled).is_true()  # 投入を取り消して0件に戻る


func test_レシピ未選択のまま投入しても調合実行ボタンは無効のまま() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()

	_place_material(screen, "mat_1")

	assert_bool(_find_button(screen, "ExecuteButton").disabled).is_true()


# 境界値（投入枠上限）


func test_投入枠が埋まっている状態では追加投入されない() -> void:
	_inject_material("mat_1", 3)
	_inject_material("mat_2", 3)
	_inject_material("mat_3", 3)
	var screen := _make_screen()
	_place_material(screen, "mat_1")
	_place_material(screen, "mat_2")

	_place_material(screen, "mat_3")

	# SLOT_COUNT=2のため3件目は配置されず、在庫にmat_3が残る
	var container := screen.find_child("SlotsContainer", true, false) as Container
	assert_int(container.get_child_count()).is_equal(SLOT_COUNT)
	assert_int(_inventory_list(screen).get_entry_count()).is_equal(1)
	assert_object(screen.find_child("MaterialEntry_mat_3", true, false)).is_not_null()


# 正常系（ターン終了）


func test_ターン終了ボタンで納品結果がギルド納品画面へ表示される() -> void:
	_inject_material("mat_1", 3)
	_inject_material("mat_2", 4)
	var screen := _make_screen()
	_select_recipe(screen, RECIPE_ID)
	_place_material(screen, "mat_1")
	_find_button(screen, "ExecuteButton").pressed.emit()
	_place_material(screen, "mat_2")
	_find_button(screen, "ExecuteButton").pressed.emit()
	assert_int(_pending_count()).is_equal(2)

	_find_button(screen, "EndTurnButton").pressed.emit()

	assert_int(_pending_count()).is_equal(0)
	assert_int(_delivery_screen(screen).get_item_count()).is_equal(2)
	# 品質3 → 倍率1.5、品質4 → 倍率1.75。貢献度10*(1.5+1.75)=32.5 / 報酬5*(1.5+1.75)=16.25
	assert_float(_delivery_screen(screen).get_total_contribution()).is_equal_approx(32.5, 0.01)
	assert_float(_delivery_screen(screen).get_total_reward()).is_equal_approx(16.25, 0.01)
	# 納品トーストのプレースホルダー実装は撤去済みのため、直前の調合トーストのまま変化しない
	assert_str(screen.get_toast_text()).contains("調合しました")


func test_納品対象が0件のターン終了でギルド納品画面が0件へリセットされる() -> void:
	GameState._inject_pending_product_for_test(
		ProductInstance.new(RECIPE_ID, 3, [] as Array[StringName], 10.0, 5.0)
	)
	var screen := _make_screen()
	_find_button(screen, "EndTurnButton").pressed.emit()
	assert_int(_delivery_screen(screen).get_item_count()).is_equal(1)

	# pending_productsが空のまま再度ターン終了しても例外なく0件表示へ戻る
	_find_button(screen, "EndTurnButton").pressed.emit()

	assert_int(_delivery_screen(screen).get_item_count()).is_equal(0)
	assert_float(_delivery_screen(screen).get_total_contribution()).is_equal_approx(0.0, 0.01)
	assert_float(_delivery_screen(screen).get_total_reward()).is_equal_approx(0.0, 0.01)


# 正常系（ショップ導線）


func test_ショップボタン押下でshop_requestedが発行され状態が変化しない() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	monitor_signals(screen)
	var before_state := GameState.get_state()

	_find_button(screen, "ShopButton").pressed.emit()

	await assert_signal(screen).is_emitted("shop_requested")
	var after_state := GameState.get_state()
	assert_int((after_state["inventory"] as Array[MaterialInstance]).size()).is_equal(
		(before_state["inventory"] as Array[MaterialInstance]).size()
	)
	assert_int(after_state["gold"]).is_equal(before_state["gold"])
	assert_int(after_state["current_turn"]).is_equal(before_state["current_turn"])


# 保守性確認（禁止要件）


func test_AlchemyScreenのソースが禁止された実装を含まない() -> void:
	var source := _screen_source()

	assert_bool(source.contains("_get_drag_data")).is_false()
	assert_bool(source.contains("_drop_data")).is_false()
	assert_bool(source.contains("change_scene_to_file")).is_false()
	assert_bool(source.contains("main.tscn")).is_false()


## 納品結果表示はGuildDeliveryScreenへ委譲したため、deliveredシグナル購読と
## 納品トーストのプレースホルダー実装が残っていないことを確認する
func test_AlchemyScreenが納品トーストのプレースホルダー実装を持たない() -> void:
	var source := _screen_source()

	assert_bool(source.contains("_on_delivered")).is_false()
	assert_bool(source.contains("件を納品しました")).is_false()


func test_調合実行ハンドラがdeliver_pending_productsを呼ばない() -> void:
	# gdformatが書き戻す改行コードに依存しないようLFへ正規化してから走査する
	var source := _screen_source()
	var handler_start := source.find("func _on_execute_pressed")
	# 関数本体は次の空行までで終わる（後続関数の説明コメントを巻き込まないため）
	var handler_end := source.find("\n\n", handler_start)
	var handler_body := source.substr(handler_start, handler_end - handler_start)

	assert_bool(handler_body.contains("deliver_pending_products")).is_false()
	assert_bool(handler_body.contains("execute_alchemy")).is_true()


# signal購読解除確認


func test_破棄後にGameStateのシグナルを発行しても例外が発生しない() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	screen.get_parent().remove_child(screen)
	screen.free()

	GameState.product_crafted.emit(
		ProductInstance.new(RECIPE_ID, 3, [] as Array[StringName], 10.0, 5.0)
	)
	GameState.execute_alchemy_failed.emit(RECIPE_ID, &"slot_execution_invalid")
	GameState.delivered.emit([] as Array[DeliveryResult])

	assert_bool(GameState.product_crafted.get_connections().is_empty()).is_true()
	assert_bool(GameState.execute_alchemy_failed.get_connections().is_empty()).is_true()
	assert_bool(GameState.delivered.get_connections().is_empty()).is_true()
