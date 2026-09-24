extends GdUnitTestSuite

## ui-polish Plan タスク007: 調合画面で投入内容の変化により新規に特性が発現した瞬間、
## 該当スロット（AlchemySlotView）をハイライト演出（UiEffects.play_highlight_pulse()）で
## 光らせるフィードバックを検証する（ui-design/screens/alchemy.md L83）。
## 判定ロジック自体（何が発現したか）はTraitActivation.resolve_traits()
## （ProductProvisionalResolver経由）の戻り値をそのまま使う。本テストは
## 「前回との差分検出→対象スロットへの演出適用」というUI層の配線のみを検証する。

const RECIPE_ID := &"recipe_test"
const RANK_ID := &"rank_test"
const SLOT_COUNT := 4
const TAG_A := &"holy"
const TAG_B := &"fire"


func before_test() -> void:
	GameState.reset_for_test()
	GameState._set_recipe_masters_for_test({RECIPE_ID: _make_recipe(RECIPE_ID, "テストレシピ")})
	GameState._set_unlocked_recipe_ids_for_test([RECIPE_ID] as Array[StringName])
	GameState._set_alchemy_slot_count_for_test(SLOT_COUNT)
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	# 🔵 traits_unlocked=falseだとTraitActivation.resolve_traits()が常に空配列を返し検証できない
	rank.traits_unlocked = true
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)


func _make_recipe(id: StringName, recipe_name: String) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = recipe_name
	recipe.base_contribution = 10.0
	recipe.base_reward = 5.0
	return recipe


func _inject_material(instance_id: String, tags: Array[StringName]) -> void:
	GameState._inject_material_for_test(
		MaterialInstance.new(instance_id, &"material_herb", 3, tags)
	)


func _make_screen() -> AlchemyScreen:
	var runner := scene_runner("res://features/alchemy/ui/alchemy_screen.tscn")
	return runner.scene() as AlchemyScreen


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


func _find_slot_view(screen: AlchemyScreen, slot_index: int) -> AlchemySlotView:
	var container := screen.find_child("SlotsContainer", true, false) as Container
	return container.get_child(slot_index) as AlchemySlotView


func _slot_panel(screen: AlchemyScreen, slot_index: int) -> PanelContainer:
	return (
		_find_slot_view(screen, slot_index).find_child("SlotPanel", true, false) as PanelContainer
	)


func _filled_color() -> Color:
	return AlchemySlotView.status_color(AlchemySlotView.Status.FILLED)


# 正常系


func test_2個目の素材投入で特性タグが新規発現した場合該当スロットがハイライトされる() -> void:
	_inject_material("mat_1", [TAG_A])
	_inject_material("mat_2", [TAG_A])
	var screen := _make_screen()
	_select_recipe(screen)

	_place_material(screen, "mat_1")  # 出現数1 < 閾値2のため未発現
	assert_bool(_slot_panel(screen, 0).self_modulate == _filled_color()).is_true()

	_place_material(screen, "mat_2")  # 出現数2 >= 閾値2で新規発現
	await get_tree().create_timer(0.15).timeout

	assert_bool(_slot_panel(screen, 1).self_modulate == _filled_color()).is_false()


# 異常系（既発現タグ・取り消し）


func test_既に発現済みのタグは再度投入しても演出が発火しない() -> void:
	_inject_material("mat_1", [TAG_A])
	_inject_material("mat_2", [TAG_A])
	_inject_material("mat_3", [TAG_A])
	var screen := _make_screen()
	_select_recipe(screen)
	_place_material(screen, "mat_1")
	_place_material(screen, "mat_2")  # ここでTAG_Aが新規発現

	_place_material(screen, "mat_3")  # TAG_Aは既に発現済みのため新規発現なし
	await get_tree().create_timer(0.15).timeout

	assert_bool(_slot_panel(screen, 2).self_modulate == _filled_color()).is_true()


func test_取り消して発現条件を満たさなくなった場合は演出が発生しない() -> void:
	_inject_material("mat_1", [TAG_A])
	_inject_material("mat_2", [TAG_A])
	var screen := _make_screen()
	_select_recipe(screen)
	_place_material(screen, "mat_1")
	_place_material(screen, "mat_2")  # TAG_A新規発現
	# 既存の演出（slot0・slot1）を収束させ、後続チェックへ影響を残さない
	await get_tree().create_timer(UiTheme.ANIM_DURATION_HIGHLIGHT_PULSE + 0.2).timeout

	_find_slot_view(screen, 0).clear_requested.emit(0)  # mat_1を取り消す。出現数1 < 閾値2に戻る
	await get_tree().create_timer(0.15).timeout

	assert_bool(_slot_panel(screen, 0).self_modulate == _filled_color()).is_true()


# 境界値（複数タグ同時新規発現）


func test_複数タグが同時に新規発現した場合対象スロットすべてに演出が適用される() -> void:
	_inject_material("mat_1", [TAG_A])
	_inject_material("mat_2", [TAG_B])
	_inject_material("mat_3", [TAG_A, TAG_B])
	var screen := _make_screen()
	_select_recipe(screen)
	_place_material(screen, "mat_1")  # TAG_A出現数1
	_place_material(screen, "mat_2")  # TAG_B出現数1、まだ未発現

	_place_material(screen, "mat_3")  # TAG_A, TAG_Bともに出現数2で同時新規発現
	await get_tree().create_timer(0.15).timeout

	assert_bool(_slot_panel(screen, 0).self_modulate == _filled_color()).is_false()  # mat_1 (TAG_A)
	assert_bool(_slot_panel(screen, 1).self_modulate == _filled_color()).is_false()  # mat_2 (TAG_B)
	assert_bool(_slot_panel(screen, 2).self_modulate == _filled_color()).is_false()  # mat_3 (両方)
