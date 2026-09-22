extends GdUnitTestSuite

## ui-polish Plan タスク002: seed_planted受信後の対象スロットポップイン演出を検証する。
## play_sprout_animation()自体は薄いラッパー（UiEffects.play_pop_in()委譲）のため、
## 「呼ばれたか」を直接モックで検証せず、scaleがZEROから開始しANIM_DURATION_POP_IN経過後に
## ONEへ収束するという観測可能な振る舞いで検証する（testing.mdの「実装詳細ではなく振る舞いを
## テスト」に従う）。


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


func _find_seed_plant_button(screen: GardenScreen, seed_id: StringName) -> Button:
	var row := screen.find_child("SeedEntry_%s" % seed_id, true, false) as Control
	return row.find_child("PlantButton", true, false) as Button


# 正常系


func test_種植え後に対象スロットの芽がポップインで出現する() -> void:
	GameState._set_masters_for_test({&"seed_herb": _make_seed_master(&"seed_herb")}, {})
	GameState._set_seed_inventory_for_test([{"seed_id": &"seed_herb", "count": 1}])
	var screen := _make_screen()

	_find_seed_plant_button(screen, &"seed_herb").pressed.emit()

	var slot_view := _find_slot_view(screen, 0)
	assert_vector(slot_view.scale).is_equal_approx(Vector2.ZERO, Vector2(0.01, 0.01))
	await get_tree().create_timer(UiTheme.ANIM_DURATION_POP_IN + 0.1).timeout
	assert_vector(slot_view.scale).is_equal_approx(Vector2.ONE, Vector2(0.01, 0.01))


func test_play_sprout_animationは有効なTweenを返す() -> void:
	var runner := scene_runner("res://features/garden/ui/plant_slot_view.tscn")
	var slot_view := runner.scene() as PlantSlotView

	var tween := slot_view.play_sprout_animation()

	assert_object(tween).is_not_null()
	assert_bool(tween.is_valid()).is_true()


# 境界値


func test_同一フレームで連続して植付してもクラッシュせず両方ポップインする() -> void:
	(
		GameState
		. _set_masters_for_test(
			{
				&"seed_herb": _make_seed_master(&"seed_herb"),
				&"seed_flower": _make_seed_master(&"seed_flower"),
			},
			{}
		)
	)
	GameState._set_seed_inventory_for_test(
		[{"seed_id": &"seed_herb", "count": 1}, {"seed_id": &"seed_flower", "count": 1}]
	)
	var screen := _make_screen()

	GameState.plant_seed(&"seed_herb")
	GameState.plant_seed(&"seed_flower")

	assert_int(_find_slot_view(screen, 0).get_status()).is_equal(PlantSlotView.Status.GROWING)
	assert_int(_find_slot_view(screen, 1).get_status()).is_equal(PlantSlotView.Status.GROWING)
	assert_vector(_find_slot_view(screen, 1).scale).is_equal_approx(
		Vector2.ZERO, Vector2(0.01, 0.01)
	)
