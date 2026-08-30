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


# 正常系（指定依頼ラベル）


func _make_item_order(target_recipe_id: String, multiplier: float = 1.5) -> DailyOrderMaster:
	var order := DailyOrderMaster.new()
	order.id = "order_item"
	order.condition_type = "item"
	order.target_recipe_id = target_recipe_id
	order.match_bonus_multiplier = multiplier
	return order


func _make_trait_order(target_trait: String, multiplier: float = 1.5) -> DailyOrderMaster:
	var order := DailyOrderMaster.new()
	order.id = "order_trait"
	order.condition_type = "trait"
	order.target_trait = target_trait
	order.match_bonus_multiplier = multiplier
	return order


func test_指定依頼がitem条件のとき対象レシピ名と倍率が表示される() -> void:
	GameState._set_current_daily_order_for_test(_make_item_order(String(RECIPE_ID), 1.5))

	var screen := _make_screen()

	assert_str(_label_text(screen, "DailyOrderLabel")).is_equal("指定依頼: テストレシピ（x1.5）")


func test_指定依頼がtrait条件のとき対象特性名と倍率が表示される() -> void:
	GameState._set_current_daily_order_for_test(_make_trait_order("芳香", 2.0))

	var screen := _make_screen()

	assert_str(_label_text(screen, "DailyOrderLabel")).is_equal("指定依頼: 特性「芳香」（x2.0）")


func test_指定依頼が無い場合はなしと明示表示される() -> void:
	var screen := _make_screen()

	assert_str(_label_text(screen, "DailyOrderLabel")).is_equal(AlchemyScreen.DAILY_ORDER_NONE_TEXT)


func test_ターン進行で指定依頼が引き直されるとラベルが追随する() -> void:
	GameState._set_current_daily_order_for_test(_make_item_order(String(RECIPE_ID), 1.5))
	var screen := _make_screen()
	assert_str(_label_text(screen, "DailyOrderLabel")).is_equal("指定依頼: テストレシピ（x1.5）")

	# マスター未ロードのため再抽選の母集団は空となり、指定依頼はnullへ引き直される
	GameState.advance_turn_growth()
	screen.refresh()

	assert_str(_label_text(screen, "DailyOrderLabel")).is_equal(AlchemyScreen.DAILY_ORDER_NONE_TEXT)


## 🔵 試験中はresolve_daily_order_for_delivery()がnullを返すため、プレビューだけでなく
## ラベル表示も「なし」に揃える（実際の納品結果と乖離した指定依頼を提示しない）
func test_試験中は指定依頼ラベルがなし表示になる() -> void:
	GameState._set_current_daily_order_for_test(_make_item_order(String(RECIPE_ID), 2.0))
	GameState._set_exam_state_for_test(ExamState.new(), true)

	var screen := _make_screen()

	assert_str(_label_text(screen, "DailyOrderLabel")).is_equal(AlchemyScreen.DAILY_ORDER_NONE_TEXT)


# 異常系（指定依頼ラベル）


func test_対象レシピのマスターが見つからない場合はレシピIDをそのまま表示する() -> void:
	GameState._set_current_daily_order_for_test(_make_item_order("recipe_unknown", 1.5))

	var screen := _make_screen()

	assert_str(_label_text(screen, "DailyOrderLabel")).is_equal("指定依頼: recipe_unknown（x1.5）")


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
	GameState.exam_started.emit()
	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.CONTINUE)

	assert_bool(GameState.product_crafted.get_connections().is_empty()).is_true()
	assert_bool(GameState.execute_alchemy_failed.get_connections().is_empty()).is_true()
	assert_bool(GameState.delivered.get_connections().is_empty()).is_true()
	assert_bool(GameState.exam_started.get_connections().is_empty()).is_true()
	assert_bool(GameState.exam_outcome_confirmed.get_connections().is_empty()).is_true()


# 試験モード（rank-up-ui Plan、AC-002〜AC-010）


func _make_exam_state(
	quota: float, quota_max: float, elapsed_turn: int, turn_limit: int
) -> ExamState:
	var state := ExamState.new()
	state.exam_quota = quota
	state.exam_quota_max = quota_max
	state.exam_elapsed_turn = elapsed_turn
	state.exam_turn_limit = turn_limit
	return state


func _set_exam(
	quota: float, quota_max: float, elapsed_turn: int, turn_limit: int, in_exam: bool = true
) -> void:
	GameState._set_exam_state_for_test(
		_make_exam_state(quota, quota_max, elapsed_turn, turn_limit), in_exam
	)


func test_ready後に試験シグナルが購読済みである() -> void:
	var _screen := _make_screen()

	assert_int(GameState.exam_started.get_connections().size()).is_equal(1)
	assert_int(GameState.exam_outcome_confirmed.get_connections().size()).is_equal(1)


func test_破棄後に試験シグナルの購読が解除される() -> void:
	var screen := _make_screen()
	screen.get_parent().remove_child(screen)
	screen.free()

	assert_bool(GameState.exam_started.get_connections().is_empty()).is_true()
	assert_bool(GameState.exam_outcome_confirmed.get_connections().is_empty()).is_true()


func test_画面生成直後は試験用ノードが非表示である() -> void:
	var screen := _make_screen()

	assert_bool(screen.find_child("ExamTurnLabel", true, false).visible).is_false()
	assert_bool(screen.find_child("ExamGuidanceLabel", true, false).visible).is_false()
	assert_bool(screen.find_child("AdvanceExamTurnButton", true, false).visible).is_false()


func test_試験中は残りターンが表示されEndTurnButtonが非表示になる() -> void:
	_set_exam(3.0, 10.0, 2, 5)
	var screen := _make_screen()

	assert_str(_label_text(screen, "ExamTurnLabel")).is_equal("残り3ターン")
	assert_bool(screen.find_child("ExamTurnLabel", true, false).visible).is_true()
	assert_bool(_find_button(screen, "AdvanceExamTurnButton").visible).is_true()
	assert_bool(_find_button(screen, "EndTurnButton").visible).is_false()


func test_試験中でなければ既存のEndTurnButtonが表示されたままになる() -> void:
	var screen := _make_screen()

	assert_bool(_find_button(screen, "AdvanceExamTurnButton").visible).is_false()
	assert_bool(_find_button(screen, "EndTurnButton").visible).is_true()


func test_残りターンが上限に到達した場合は0ターン表示のままクランプされる() -> void:
	_set_exam(3.0, 10.0, 5, 5)
	var screen := _make_screen()

	assert_str(_label_text(screen, "ExamTurnLabel")).is_equal("残り0ターン")


func test_経過ターンが上限を超えていても0ターン表示のままクランプされる() -> void:
	_set_exam(3.0, 10.0, 5, 3)
	var screen := _make_screen()

	assert_str(_label_text(screen, "ExamTurnLabel")).is_equal("残り0ターン")


func test_ターンを進めるボタン押下で試験経過ターンが1増え表示が更新される() -> void:
	_set_exam(3.0, 10.0, 2, 5)
	var screen := _make_screen()

	_find_button(screen, "AdvanceExamTurnButton").pressed.emit()

	assert_int(GameState.get_state()["exam_elapsed_turn"]).is_equal(3)
	assert_str(_label_text(screen, "ExamTurnLabel")).is_equal("残り2ターン")


func test_ターンを進めるボタンは在庫が空でも常に有効である() -> void:
	_set_exam(3.0, 10.0, 2, 5)
	var screen := _make_screen()

	assert_bool(_find_button(screen, "AdvanceExamTurnButton").disabled).is_false()


func test_試験開始シグナルでトーストが表示され画面が更新される() -> void:
	var screen := _make_screen()

	GameState.exam_started.emit()

	assert_str(screen.get_toast_text()).is_equal("昇格試験が始まりました！")


func test_試験合格確定でトーストが表示される() -> void:
	_setup_exam_success_rank()
	_set_exam(0.0, 50.0, 5, 20)
	var screen := _make_screen()

	GameState.commit_exam_outcome()

	assert_str(screen.get_toast_text()).is_equal("昇格試験に合格しました！")


func test_試験不合格確定でトーストが表示される() -> void:
	_setup_exam_success_rank()
	_set_exam(10.0, 50.0, 20, 20)
	var screen := _make_screen()

	GameState.commit_exam_outcome()

	assert_str(screen.get_toast_text()).is_equal("昇格試験に失敗しました…")


func test_試験継続中はトーストが変化しない() -> void:
	var screen := _make_screen()
	screen._show_toast("直前のトースト")

	GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.CONTINUE)

	assert_str(screen.get_toast_text()).is_equal("直前のトースト")


func test_on_exam_outcome_confirmedにExamOutcomeValueの型注釈がある() -> void:
	var source := _screen_source()

	(
		assert_bool(
			source.contains("func _on_exam_outcome_confirmed(outcome: ExamOutcome.Value) -> void:")
		)
		. is_true()
	)


func test_試験中の調合成功で自動納品されギルド納品画面へ反映される() -> void:
	_set_exam(10.0, 10.0, 0, 5)
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_select_recipe(screen, RECIPE_ID)
	_place_material(screen, "mat_1")

	_find_button(screen, "ExecuteButton").pressed.emit()

	assert_int(_delivery_screen(screen).get_item_count()).is_equal(1)
	assert_int(_pending_count()).is_equal(0)
	assert_float(_delivery_screen(screen).get_total_contribution()).is_greater(0.0)
	assert_float(_delivery_screen(screen).get_total_reward()).is_greater(0.0)


func test_試験中でなければ調合成功しても自動納品されない() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_select_recipe(screen, RECIPE_ID)
	_place_material(screen, "mat_1")

	_find_button(screen, "ExecuteButton").pressed.emit()

	assert_int(_delivery_screen(screen).get_item_count()).is_equal(0)
	assert_int(_pending_count()).is_equal(1)


func test_試験中に連続して調合すると毎回自動納品され表示が更新される() -> void:
	_set_exam(10.0, 10.0, 0, 5)
	_inject_material("mat_1", 3)
	_inject_material("mat_2", 4)
	var screen := _make_screen()
	_select_recipe(screen, RECIPE_ID)

	_place_material(screen, "mat_1")
	_find_button(screen, "ExecuteButton").pressed.emit()
	assert_int(_delivery_screen(screen).get_item_count()).is_equal(1)

	_place_material(screen, "mat_2")
	_find_button(screen, "ExecuteButton").pressed.emit()

	assert_int(_delivery_screen(screen).get_item_count()).is_equal(1)
	assert_int(_pending_count()).is_equal(0)


func test_試験中に在庫が空だと案内メッセージが表示される() -> void:
	_set_exam(3.0, 10.0, 0, 5)
	var screen := _make_screen()

	assert_bool(screen.find_child("ExamGuidanceLabel", true, false).visible).is_true()


func test_試験中に解禁レシピが空だと案内メッセージが表示される() -> void:
	_set_exam(3.0, 10.0, 0, 5)
	_inject_material("mat_1", 3)
	GameState._set_unlocked_recipe_ids_for_test([] as Array[StringName])
	var screen := _make_screen()

	assert_bool(screen.find_child("ExamGuidanceLabel", true, false).visible).is_true()


## 🔴 コードレビュー指摘対応の回帰テスト。unlocked_recipe_idsが非空でも、対応するRecipeMasterが
## _recipe_mastersに存在しなければドロップダウンが実質空になり「解禁レシピ0」と同じデッドロックになる
func test_試験中に解禁レシピはあるがマスターデータ未ロードだと案内メッセージが表示される() -> void:
	_set_exam(3.0, 10.0, 0, 5)
	_inject_material("mat_1", 3)
	GameState._set_unlocked_recipe_ids_for_test([&"recipe_missing"] as Array[StringName])
	var screen := _make_screen()

	assert_bool(screen.find_child("ExamGuidanceLabel", true, false).visible).is_true()


func test_試験中でも在庫と解禁レシピがあれば案内メッセージは表示されない() -> void:
	_set_exam(3.0, 10.0, 0, 5)
	_inject_material("mat_1", 3)
	var screen := _make_screen()

	assert_bool(screen.find_child("ExamGuidanceLabel", true, false).visible).is_false()


func test_試験中でなければ在庫が空でも案内メッセージは表示されない() -> void:
	var screen := _make_screen()

	assert_bool(screen.find_child("ExamGuidanceLabel", true, false).visible).is_false()


func test_案内メッセージ表示中もターンを進めるボタンは有効なまま() -> void:
	_set_exam(3.0, 10.0, 0, 5)
	var screen := _make_screen()

	assert_bool(_find_button(screen, "AdvanceExamTurnButton").disabled).is_false()
	assert_bool(_find_button(screen, "ExecuteButton").disabled).is_true()


# 納品結果画面の表示制御とdelivery_confirmed中継（main-scene-integration Plan、FR-107/FR-203/FR-402）


func _delivery_continue_button(screen: AlchemyScreen) -> Button:
	return _delivery_screen(screen).find_child("ContinueButton", true, false) as Button


func test_画面生成直後はギルド納品画面が非表示である() -> void:
	var screen := _make_screen()

	assert_bool(_delivery_screen(screen).visible).is_false()


func test_ターン終了で納品結果を表示するとギルド納品画面が表示される() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_select_recipe(screen, RECIPE_ID)
	_place_material(screen, "mat_1")
	_find_button(screen, "ExecuteButton").pressed.emit()

	_find_button(screen, "EndTurnButton").pressed.emit()

	assert_bool(_delivery_screen(screen).visible).is_true()


func test_続けるボタン押下でギルド納品画面が再び非表示になる() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_find_button(screen, "EndTurnButton").pressed.emit()
	assert_bool(_delivery_screen(screen).visible).is_true()

	_delivery_continue_button(screen).pressed.emit()

	assert_bool(_delivery_screen(screen).visible).is_false()


func test_続けるボタン押下でdelivery_confirmedが中継発行される() -> void:
	var screen := _make_screen()
	monitor_signals(screen)
	_find_button(screen, "EndTurnButton").pressed.emit()

	_delivery_continue_button(screen).pressed.emit()

	await assert_signal(screen).is_emitted("delivery_confirmed")


func test_試験中の自動納品でもギルド納品画面が表示される() -> void:
	_set_exam(10.0, 10.0, 0, 5)
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_select_recipe(screen, RECIPE_ID)
	_place_material(screen, "mat_1")

	_find_button(screen, "ExecuteButton").pressed.emit()

	assert_bool(_delivery_screen(screen).visible).is_true()


func test_納品対象が0件でも表示制御がクラッシュせず表示と非表示を往復する() -> void:
	var screen := _make_screen()

	_find_button(screen, "EndTurnButton").pressed.emit()

	assert_int(_delivery_screen(screen).get_item_count()).is_equal(0)
	assert_bool(_delivery_screen(screen).visible).is_true()

	_delivery_continue_button(screen).pressed.emit()

	assert_bool(_delivery_screen(screen).visible).is_false()


func test_破棄後にscreen_closedの購読が解除される() -> void:
	var screen := _make_screen()
	var delivery := _delivery_screen(screen)
	assert_int(delivery.screen_closed.get_connections().size()).is_equal(1)

	screen.get_parent().remove_child(screen)
	screen.free()

	assert_bool(is_instance_valid(delivery)).is_false()


# ターン確定の配線（main-scene-integration Plan、FR-115/FR-116）


## commit_rank_outcome()のPROMOTION_ELIGIBLE/DEMOTION分岐を実際に成立させるためのランク設定。
## _set_rank()と違い_set_rank_state_for_test()まで行うため_rank_state_initializedがtrueになり、
## evaluate_rank_outcome()がCONTINUE固定のガードを抜けて実判定を行うようになる
func _setup_rank_outcome(quota: float, elapsed_turn: int, limit_turn: int) -> void:
	var rank := RankMaster.new()
	rank.id = "rank_g"
	rank.display_name = "テストG"
	rank.quota_max = 100.0
	rank.limit_turn = limit_turn
	rank.exam_turn_limit = 10
	rank.exam_difficulty_coefficient = 0.5
	rank.traits_unlocked = false
	var next_rank := RankMaster.new()
	next_rank.id = "rank_f"
	next_rank.display_name = "テストF"
	next_rank.quota_max = 200.0
	next_rank.limit_turn = 40
	next_rank.exam_turn_limit = 10
	next_rank.exam_difficulty_coefficient = 0.5
	next_rank.traits_unlocked = false
	GameState._set_rank_masters_for_test({&"rank_g": rank, &"rank_f": next_rank})
	GameState._set_current_rank_id_for_test(&"rank_g")
	var rank_state := RankState.new()
	rank_state.quota = quota
	rank_state.elapsed_turn = elapsed_turn
	GameState._set_rank_state_for_test(rank_state)


func test_ターン終了でランク結果が確定しrank_outcome_confirmedが発行される() -> void:
	_setup_rank_outcome(100.0, 0, 30)
	var screen := _make_screen()
	monitor_signals(GameState, false)

	_find_button(screen, "EndTurnButton").pressed.emit()

	await assert_signal(GameState).is_emitted(
		"rank_outcome_confirmed", [RankOutcome.Value.CONTINUE]
	)


func test_ランクノルマ達成状態のターン終了で昇格試験が開始される() -> void:
	_setup_rank_outcome(0.0, 30, 30)
	var screen := _make_screen()
	monitor_signals(GameState, false)

	_find_button(screen, "EndTurnButton").pressed.emit()

	await assert_signal(GameState).is_emitted("exam_started")
	assert_bool(GameState.get_state()["in_exam"]).is_true()


func test_試験ターンを進めると試験結果が確定しexam_outcome_confirmedが発行される() -> void:
	_setup_exam_success_rank()
	_set_exam(10.0, 50.0, 0, 20)
	var screen := _make_screen()
	monitor_signals(GameState, false)

	_find_button(screen, "AdvanceExamTurnButton").pressed.emit()

	await assert_signal(GameState).is_emitted(
		"exam_outcome_confirmed", [ExamOutcome.Value.CONTINUE]
	)
	assert_bool(GameState.get_state()["in_exam"]).is_true()


func test_試験ノルマ達成状態でターンを進めると合格が確定する() -> void:
	_setup_exam_success_rank()
	_set_exam(0.0, 50.0, 0, 20)
	var screen := _make_screen()
	monitor_signals(GameState, false)

	_find_button(screen, "AdvanceExamTurnButton").pressed.emit()

	await assert_signal(GameState).is_emitted("exam_outcome_confirmed", [ExamOutcome.Value.SUCCESS])
	assert_bool(GameState.get_state()["in_exam"]).is_false()


## 異常系。試験中はEndTurnButtonがvisible=falseで押下不能なため、commit_rank_outcome()が
## 試験中に誤発火してランク判定と試験判定が二重に走ることはない（既存のvisible制御による防止を確認する）
func test_試験中はターン終了ボタンが押下不能でランク結果確定が誤発火しない() -> void:
	_setup_rank_outcome(0.0, 30, 30)
	_set_exam(10.0, 50.0, 0, 20)
	var screen := _make_screen()

	assert_bool(_find_button(screen, "EndTurnButton").visible).is_false()
	assert_bool(_find_button(screen, "AdvanceExamTurnButton").visible).is_true()


## 境界値。降格回数がMAX_DEMOTION_COUNTの直前（-1）でDEMOTIONが確定すると、
## rank_outcome_confirmedに続けてgame_overまで発行される
func test_降格でゲームオーバー閾値に到達するとターン終了後にgame_overも発行される() -> void:
	_setup_rank_outcome(100.0, 30, 30)
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 1)
	var screen := _make_screen()
	monitor_signals(GameState, false)

	_find_button(screen, "EndTurnButton").pressed.emit()

	await assert_signal(GameState).is_emitted(
		"rank_outcome_confirmed", [RankOutcome.Value.DEMOTION]
	)
	await assert_signal(GameState).is_emitted("game_over", [GameBalance.MAX_DEMOTION_COUNT])
	assert_bool(GameState.is_game_over()).is_true()


## commit_exam_outcome()のSUCCESS分岐がGameBalance.RANK_ORDER上の次ランク解決に依存するため、
## RANK_ORDER実在の2ランク（rank_g→rank_f）をマスター登録する（test_game_state_exam_outcome.gdと同型）。
## これにより「未知の現在ランクID」push_errorを避けつつSUCCESS/FAILUREともに検証できる
func _setup_exam_success_rank() -> void:
	var current := RankMaster.new()
	current.id = "rank_g"
	current.display_name = "テストG"
	current.quota_max = 100.0
	current.limit_turn = 30
	current.traits_unlocked = false
	var next_rank := RankMaster.new()
	next_rank.id = "rank_f"
	next_rank.display_name = "テストF"
	next_rank.quota_max = 200.0
	next_rank.limit_turn = 40
	next_rank.traits_unlocked = false
	GameState._set_rank_masters_for_test({&"rank_g": current, &"rank_f": next_rank})
	GameState._set_current_rank_id_for_test(&"rank_g")
