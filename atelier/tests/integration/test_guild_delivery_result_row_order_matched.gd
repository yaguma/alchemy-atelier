extends GdUnitTestSuite

## ui-polish Plan タスク012: ギルド納品画面で指定合致した結果行に対する強調演出（キラキラ）を
## 検証する（ui-design/screens/guild-delivery.md L71）。GPUParticles2Dではなく
## UiEffects.play_highlight_pulse()（self_modulateのパルス）で代替する（ユーザー決定事項）。
## タスク010のポップイン演出と時系列が重ならないよう、ポップイン完了後にハイライトを開始する契約。

const RECIPE_A: StringName = &"recipe_a"
const RECIPE_B: StringName = &"recipe_b"


func before_test() -> void:
	GameState.reset_for_test()
	var masters := {
		RECIPE_A: _make_recipe(RECIPE_A, "回復薬"),
		RECIPE_B: _make_recipe(RECIPE_B, "聖水"),
	}
	GameState._set_recipe_masters_for_test(masters)
	var rank := RankMaster.new()
	rank.id = "rank_test"
	rank.display_name = "見習い"
	rank.quota_max = 100.0
	GameState._set_rank_masters_for_test({&"rank_test": rank})
	GameState._set_current_rank_id_for_test(&"rank_test")


func _make_recipe(id: StringName, recipe_name: String) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = recipe_name
	return recipe


func _make_product(recipe_id: StringName, quality: int) -> ProductInstance:
	var no_tags: Array[StringName] = []
	return ProductInstance.new(recipe_id, quality, no_tags, 0.0, 0.0)


func _make_result(contribution: float, reward: float, order_matched: bool) -> DeliveryResult:
	return DeliveryResult.new(contribution, reward, order_matched)


func _make_screen() -> GuildDeliveryScreen:
	var runner := scene_runner("res://features/guild/ui/guild_delivery_screen.tscn")
	return runner.scene() as GuildDeliveryScreen


func _find_row(screen: GuildDeliveryScreen, index: int) -> GuildDeliveryResultRow:
	return screen.find_child("DeliveryEntry_%d" % index, true, false) as GuildDeliveryResultRow


func _after_pop_in_duration() -> float:
	return UiTheme.ANIM_DURATION_FADE_SCREEN + UiTheme.ANIM_DURATION_POP_IN + 0.05


func _highlight_mid_duration() -> float:
	return _after_pop_in_duration() + (UiTheme.ANIM_DURATION_HIGHLIGHT_PULSE / 2.0)


func _highlight_end_duration() -> float:
	return _after_pop_in_duration() + UiTheme.ANIM_DURATION_HIGHLIGHT_PULSE + 0.1


# 正常系


func test_指定合致した結果行はポップイン完了後にハイライト演出が発火する() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [_make_product(RECIPE_A, 3)]
	var results: Array[DeliveryResult] = [_make_result(10.0, 5.0, true)]
	screen.display_results(products, results)
	screen.visible = false
	var row := _find_row(screen, 0)
	var original_color := row.self_modulate

	screen.show_with_animation()
	await get_tree().create_timer(_highlight_mid_duration()).timeout

	assert_bool(row.self_modulate == original_color).is_false()

	await get_tree().create_timer(_highlight_end_duration() - _highlight_mid_duration()).timeout
	assert_bool(row.self_modulate == original_color).is_true()


func test_複数の指定合致行がそれぞれ独立してハイライト演出する() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [
		_make_product(RECIPE_A, 3),
		_make_product(RECIPE_B, 4),
	]
	var results: Array[DeliveryResult] = [
		_make_result(10.0, 5.0, true),
		_make_result(20.0, 6.0, true),
	]
	screen.display_results(products, results)
	screen.visible = false
	var row_a := _find_row(screen, 0)
	var row_b := _find_row(screen, 1)
	var original_color_a := row_a.self_modulate
	var original_color_b := row_b.self_modulate

	screen.show_with_animation()
	await get_tree().create_timer(_highlight_mid_duration()).timeout

	assert_bool(row_a.self_modulate == original_color_a).is_false()
	assert_bool(row_b.self_modulate == original_color_b).is_false()


# 異常系


func test_指定合致していない結果行はハイライト演出が発火しない() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [_make_product(RECIPE_A, 3)]
	var results: Array[DeliveryResult] = [_make_result(10.0, 5.0, false)]
	screen.display_results(products, results)
	screen.visible = false
	var row := _find_row(screen, 0)
	var original_color := row.self_modulate

	screen.show_with_animation()
	await get_tree().create_timer(_highlight_end_duration()).timeout

	assert_bool(row.self_modulate == original_color).is_true()


func test_指定合致行のハイライト演出はGPUParticles2Dを使用しない() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [_make_product(RECIPE_A, 3)]
	var results: Array[DeliveryResult] = [_make_result(10.0, 5.0, true)]
	screen.display_results(products, results)
	screen.visible = false
	var row := _find_row(screen, 0)

	screen.show_with_animation()
	await get_tree().create_timer(_highlight_mid_duration()).timeout

	for child in row.get_children():
		assert_bool(child is GPUParticles2D).is_false()


# 境界値


func test_指定合致行が0件でもクラッシュせずポップインだけが完了する() -> void:
	var screen := _make_screen()
	screen.display_results([] as Array[ProductInstance], [] as Array[DeliveryResult])
	screen.visible = false

	screen.show_with_animation()
	await get_tree().create_timer(_highlight_end_duration()).timeout

	assert_float(screen.modulate.a).is_equal_approx(1.0, 0.01)
