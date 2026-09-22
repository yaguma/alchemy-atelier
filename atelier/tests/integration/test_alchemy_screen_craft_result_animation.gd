extends GdUnitTestSuite

## ui-polish Plan タスク008: 調合実行成功直後、完成品の生成演出（UiEffects.play_pop_in()）が
## OverlayLayerへ一時的に表示されることを検証する（ui-design/screens/alchemy.md L84前半）。
## 演出はギルド納品画面表示処理（_deliver_and_display）を呼ぶ前に発火し、演出完了を待たずに
## 後続処理へ進む方針を採用する（タスク006の素材投入演出と同方針。testing.mdの
## 「実装詳細ではなく振る舞いをテスト」に従い、OverlayLayerの子ノード数変化で間接的に検証する）。

const RECIPE_ID := &"recipe_test"
const RANK_ID := &"rank_test"
const SLOT_COUNT := 1


func before_test() -> void:
	GameState.reset_for_test()
	GameState._set_recipe_masters_for_test({RECIPE_ID: _make_recipe(RECIPE_ID, "テストレシピ")})
	GameState._set_unlocked_recipe_ids_for_test([RECIPE_ID] as Array[StringName])
	GameState._set_alchemy_slot_count_for_test(SLOT_COUNT)
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.traits_unlocked = false
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)


func _make_recipe(id: StringName, recipe_name: String) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = recipe_name
	recipe.base_contribution = 10.0
	recipe.base_reward = 5.0
	return recipe


func _inject_material(instance_id: String, quality: int) -> void:
	var no_tags: Array[StringName] = []
	GameState._inject_material_for_test(
		MaterialInstance.new(instance_id, &"material_herb", quality, no_tags)
	)


func _make_screen() -> AlchemyScreen:
	var runner := scene_runner("res://features/alchemy/ui/alchemy_screen.tscn")
	return runner.scene() as AlchemyScreen


func _find_overlay_layer(screen: AlchemyScreen) -> Control:
	return screen.find_child("OverlayLayer", true, false) as Control


func _find_button(screen: AlchemyScreen, node_name: String) -> Button:
	return screen.find_child(node_name, true, false) as Button


func _select_recipe(screen: AlchemyScreen) -> void:
	var option_button := screen.find_child("RecipeOptionButton", true, false) as OptionButton
	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == RECIPE_ID:
			option_button.select(index)
			option_button.item_selected.emit(index)
			return
	fail("解禁済みレシピ %s がドロップダウンに存在しません" % RECIPE_ID)


func _place_material(screen: AlchemyScreen, instance_id: String) -> void:
	var row := screen.find_child("MaterialEntry_%s" % instance_id, true, false) as MaterialEntryRow
	(row.find_child("PlaceButton", true, false) as Button).pressed.emit()


# 正常系


func test_調合実行成功直後にOverlayLayerの子ノード数が一時的に1増える() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_select_recipe(screen)
	_place_material(screen, "mat_1")
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	_find_button(screen, "ExecuteButton").pressed.emit()

	assert_int(overlay.get_child_count()).is_equal(before_count + 1)


func test_演出完了後にOverlayLayerの子ノード数が元に戻る() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_select_recipe(screen)
	_place_material(screen, "mat_1")
	# 🔵 投入時の素材スライド演出（タスク006・UiEffects.fly_ghost()）がまだOverlayLayerに
	# 残っている状態でbefore_countを取ると、後段の待機中にそのghostだけ自壊して数が食い違うため、
	# 先に収束させてから完成品演出のベースラインを取る
	await get_tree().create_timer(UiTheme.ANIM_DURATION_FLY_GHOST + 0.2).timeout
	await get_tree().process_frame
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	_find_button(screen, "ExecuteButton").pressed.emit()
	await (
		get_tree()
		. create_timer(
			UiTheme.ANIM_DURATION_POP_IN + AlchemyScreen.CRAFT_RESULT_POP_HOLD_DURATION + 0.2
		)
		. timeout
	)
	await get_tree().process_frame  # queue_free()は次フレームまで反映されないため1フレーム待つ

	assert_int(overlay.get_child_count()).is_equal(before_count)


func test_演出発火後も演出完了を待たずギルド納品画面表示処理まで完了している() -> void:
	# 🔵 in_exam=falseのためこのテスト自体はGuildDeliveryScreen表示にならないが、
	# _refresh()による状態更新（投入枠リセット）が演出と同一フレームで即座に反映されることを確認する
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_select_recipe(screen)
	_place_material(screen, "mat_1")

	_find_button(screen, "ExecuteButton").pressed.emit()

	var container := screen.find_child("SlotsContainer", true, false) as Container
	var slot_view := container.get_child(0) as AlchemySlotView
	assert_int(slot_view.get_status()).is_equal(AlchemySlotView.Status.EMPTY)


# 異常系（調合実行失敗）


func test_調合実行失敗時は演出が発生しない() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	_place_material(screen, "mat_1")
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	# レシピ未選択のまま直接呼ぶ（ボタンは無効化されているため）
	GameState.execute_alchemy(&"recipe_unknown", ["mat_1"] as Array[String])

	assert_int(overlay.get_child_count()).is_equal(before_count)
