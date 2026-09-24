extends GdUnitTestSuite

## ui-polish Plan タスク006: 素材投入時、投入元の在庫行から新スロットへ向けてゴーストが
## スライドする演出（UiEffects.fly_ghost()）を検証する。在庫行は投入直後のsetup()で
## 破棄されるため、開始位置はMaterialInventoryList.find_row_global_position()で
## 破棄前に確保していることを、演出発生と通常の状態更新の両立で間接的に担保する
## （testing.mdの「実装詳細ではなく振る舞いをテスト」に従う）。

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


func _find_slot_view(screen: AlchemyScreen, slot_index: int) -> AlchemySlotView:
	var container := screen.find_child("SlotsContainer", true, false) as Container
	return container.get_child(slot_index) as AlchemySlotView


func _place_material(screen: AlchemyScreen, instance_id: String) -> void:
	var row := screen.find_child("MaterialEntry_%s" % instance_id, true, false) as MaterialEntryRow
	(row.find_child("PlaceButton", true, false) as Button).pressed.emit()


func _inventory_list(screen: AlchemyScreen) -> MaterialInventoryList:
	return screen.find_child("MaterialInventoryList", true, false) as MaterialInventoryList


# 正常系


func test_素材投入時にOverlayLayerの子ノード数が一時的に1増える() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	_place_material(screen, "mat_1")

	assert_int(overlay.get_child_count()).is_equal(before_count + 1)


func test_演出完了後にOverlayLayerの子ノード数が元に戻る() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	_place_material(screen, "mat_1")
	await get_tree().create_timer(UiTheme.ANIM_DURATION_FLY_GHOST + 0.2).timeout
	await get_tree().process_frame  # queue_free()は次フレームまで反映されないため1フレーム待つ

	assert_int(overlay.get_child_count()).is_equal(before_count)


func test_演出中でも投入枠と在庫の状態更新は即座に反映されている() -> void:
	_inject_material("mat_1", 3)
	var screen := _make_screen()

	_place_material(screen, "mat_1")

	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(AlchemySlotView.Status.FILLED)
	assert_int(_inventory_list(screen).get_entry_count()).is_equal(0)


# 境界値


func test_投入枠が満杯の場合は演出が発生しない() -> void:
	_inject_material("mat_1", 3)
	_inject_material("mat_2", 3)
	var screen := _make_screen()
	_place_material(screen, "mat_1")  # SLOT_COUNT=1のため、これで満杯になる

	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()
	screen._on_material_place_requested("mat_2")

	assert_int(overlay.get_child_count()).is_equal(before_count)
