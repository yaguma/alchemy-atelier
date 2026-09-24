extends GdUnitTestSuite

## ui-polish Plan タスク004: GameState.plants_withered受信時、対象スロットの複製をOverlayLayerへ
## 乗せてグレー化フェードアウトさせる演出（UiEffects.play_wither_fade()）を検証する。
## 既存のトースト表示（枯死通知）は変更せず引き続き行われることをあわせて確認する。


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
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._inject_plant_for_test(PlantState.new(0, &"seed_herb", 3, true))
	GameState._inject_plant_for_test(PlantState.new(2, &"seed_herb", 3, true))
	var runner := scene_runner("res://features/garden/ui/garden_screen.tscn")
	return runner.scene() as GardenScreen


func _find_overlay_layer(screen: GardenScreen) -> Control:
	return screen.find_child("OverlayLayer", true, false) as Control


# 正常系


func test_枯死時にOverlayLayerの子ノード数が対象スロット数だけ一時的に増える() -> void:
	var screen := _make_screen()
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	screen._on_plants_withered([0, 2])

	assert_int(overlay.get_child_count()).is_equal(before_count + 2)


func test_枯死時に既存のトースト表示が引き続き行われる() -> void:
	var screen := _make_screen()

	screen._on_plants_withered([0, 2])

	assert_str(screen.get_toast_text()).is_not_empty()


func test_演出完了後にOverlayLayerの子ノード数が元に戻る() -> void:
	var screen := _make_screen()
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	screen._on_plants_withered([0, 2])
	await get_tree().create_timer(UiTheme.ANIM_DURATION_WITHER_FADE + 0.2).timeout
	await get_tree().process_frame  # queue_free()は次フレームまで反映されないため1フレーム待つ

	assert_int(overlay.get_child_count()).is_equal(before_count)


func test_演出中にturn_growth_advancedのrefreshが発火してもクラッシュしない() -> void:
	var screen := _make_screen()

	screen._on_plants_withered([0, 2])
	screen._on_turn_growth_advanced(1)
	await get_tree().create_timer(UiTheme.ANIM_DURATION_WITHER_FADE + 0.2).timeout
	await get_tree().process_frame

	assert_str(screen.get_toast_text()).is_not_empty()


# 境界値


func test_slot_indicesが空配列の場合は演出が発生しない() -> void:
	var screen := _make_screen()
	var overlay := _find_overlay_layer(screen)
	var before_count := overlay.get_child_count()

	screen._on_plants_withered([])

	assert_int(overlay.get_child_count()).is_equal(before_count)
