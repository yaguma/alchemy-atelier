extends GdUnitTestSuite

## ui-polish Plan タスク003: material_harvested受信時、収穫元スロットから種在庫リストへ
## 素材アイコンが飛ぶ演出（UiEffects.fly_ghost()）を検証する。_refresh()が_slot_views[slot_index]を
## 破棄する「前」にsourceノードを退避していることを、演出中も通常のリフレッシュ結果が両立することで
## 間接的に担保する（testing.mdの「実装詳細ではなく振る舞いをテスト」に従う）。


func before_test() -> void:
	GameState.reset_for_test()


func _make_seed_master(seed_id: StringName) -> SeedMaster:
	var master := SeedMaster.new()
	master.id = seed_id
	master.name = "薬草の種"
	master.produces_material_id = &"material_herb"
	master.maturity_turns = 3
	master.death_grace_turns = 2
	master.base_quality = 2
	master.trait_pool = [&"trait_fresh"]
	return master


func _make_screen() -> GardenScreen:
	var runner := scene_runner("res://features/garden/ui/garden_screen.tscn")
	return runner.scene() as GardenScreen


func _find_slot_view(screen: GardenScreen, slot_index: int) -> PlantSlotView:
	var container := screen.find_child("SlotsContainer", true, false) as Container
	return container.get_child(slot_index) as PlantSlotView


func _find_overlay_layer(screen: GardenScreen) -> Control:
	return screen.find_child("OverlayLayer", true, false) as Control


# 正常系


func test_収穫時にOverlayLayerの子ノード数が一時的に1増える() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._inject_plant_for_test(PlantState.new(0, &"seed_herb", 3, true))
	var screen := _make_screen()
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	_find_slot_view(screen, 0).harvest_pressed.emit(0)

	assert_int(overlay.get_child_count()).is_equal(before_count + 1)


func test_演出完了後にOverlayLayerの子ノード数が元に戻る() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._inject_plant_for_test(PlantState.new(0, &"seed_herb", 3, true))
	var screen := _make_screen()
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	_find_slot_view(screen, 0).harvest_pressed.emit(0)
	await get_tree().create_timer(UiTheme.ANIM_DURATION_FLY_GHOST + 0.2).timeout
	await get_tree().process_frame  # queue_free()は次フレームまで反映されないため1フレーム待つ

	assert_int(overlay.get_child_count()).is_equal(before_count)


func test_演出完了後に通常のリフレッシュ結果が反映されている() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._inject_plant_for_test(PlantState.new(0, &"seed_herb", 3, true))
	var screen := _make_screen()

	_find_slot_view(screen, 0).harvest_pressed.emit(0)

	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(PlantSlotView.Status.EMPTY)
	assert_str(screen.get_toast_text()).is_not_empty()


# 境界値


func test_不正なslot_indexでも演出処理でクラッシュしない() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	var screen := _make_screen()
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	var material := MaterialInstance.new(
		"test_material", &"material_herb", 3, [] as Array[StringName]
	)
	screen._on_material_harvested(material, 999)

	assert_int(overlay.get_child_count()).is_equal(before_count)
