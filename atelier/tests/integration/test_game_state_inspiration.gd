extends GdUnitTestSuite

## 🔵 Issue #67（FR-714）。調合のたびに熟練度が貯まり、投入した特性の方向にレシピがひらめくことを検証する。
## 乱数に依存しないよう、確率1になる天井（INSPIRATION_CEILING_COUNT回目の調合）で結果を確認する。

const SOURCE_RECIPE_ID := &"recipe_healing_potion"
const HOLY_RESULT_ID := &"recipe_holy_water"
const HEAL_RESULT_ID := &"recipe_high_healing_potion"
const RANK_ID := &"rank_e"

var _material_seq := 0


func before_test() -> void:
	GameState.reset_for_test()
	var recipes := {
		SOURCE_RECIPE_ID: _make_recipe(SOURCE_RECIPE_ID),
		HOLY_RESULT_ID: _make_recipe(HOLY_RESULT_ID),
		HEAL_RESULT_ID: _make_recipe(HEAL_RESULT_ID),
	}
	GameState._set_recipe_masters_for_test(recipes)
	GameState._set_unlocked_recipe_ids_for_test([SOURCE_RECIPE_ID] as Array[StringName])
	GameState._set_alchemy_slot_count_for_test(4)
	var holy_traits: Array[StringName] = [&"holy"]
	var heal_traits: Array[StringName] = [&"heal"]
	var inspirations: Array[InspirationMaster] = [
		_make_inspiration(&"insp_holy", holy_traits, HOLY_RESULT_ID),
		_make_inspiration(&"insp_heal", heal_traits, HEAL_RESULT_ID),
	]
	GameState._set_inspiration_for_test(inspirations)
	_set_rank(true)


func after_test() -> void:
	GameState.reset_for_test()


func _make_recipe(id: StringName) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = String(id)
	recipe.base_contribution = 10.0
	recipe.base_reward = 5.0
	return recipe


func _make_inspiration(
	id: StringName, required: Array[StringName], result: StringName
) -> InspirationMaster:
	var master := InspirationMaster.new()
	master.id = id
	master.source_recipe_id = SOURCE_RECIPE_ID
	master.required_traits = required
	master.result_recipe_id = result
	master.min_rank_id = RANK_ID
	return master


func _set_rank(inspiration_unlocked: bool) -> void:
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.traits_unlocked = true
	rank.inspiration_unlocked = inspiration_unlocked
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)


func _craft_with(trait_tag: StringName) -> void:
	_material_seq += 1
	var id := "mat_test_%d" % _material_seq
	var tags: Array[StringName] = []
	if trait_tag != &"":
		tags.append(trait_tag)
	GameState._inject_material_for_test(MaterialInstance.new(id, &"material_herb", 3, tags))
	GameState.execute_alchemy(SOURCE_RECIPE_ID, [id])


func _mastery(recipe_id: StringName) -> int:
	return int((GameState.get_state()["recipe_mastery"] as Dictionary).get(recipe_id, 0))


func _unlocked() -> Array:
	return GameState.get_state()["unlocked_recipe_ids"]


func _set_mastery_before_ceiling() -> void:
	GameState._set_inspiration_for_test(
		GameState._inspiration_masters,
		{SOURCE_RECIPE_ID: GameBalance.INSPIRATION_CEILING_COUNT - 1}
	)


# 正常系


func test_調合するたびに熟練度が1上がる() -> void:
	# 無特性の投入では候補が出ないため、確率判定に当選しても熟練度はリセットされない
	_craft_with(&"")
	_craft_with(&"")

	assert_int(_mastery(SOURCE_RECIPE_ID)).is_equal(2)


func test_天井回数の調合で投入した特性の方向のレシピを必ずひらめく() -> void:
	_set_mastery_before_ceiling()

	_craft_with(&"heal")

	assert_array(_unlocked()).contains([HEAL_RESULT_ID])
	assert_array(_unlocked()).not_contains([HOLY_RESULT_ID])


func test_ひらめくと熟練度が0に戻りrecipe_inspiredが発行される() -> void:
	_set_mastery_before_ceiling()
	monitor_signals(GameState, false)

	_craft_with(&"holy")

	assert_int(_mastery(SOURCE_RECIPE_ID)).is_equal(0)
	await assert_signal(GameState).is_emitted(
		"recipe_inspired", [HOLY_RESULT_ID, SOURCE_RECIPE_ID, [&"holy"] as Array[StringName]]
	)


func test_ひらめいたレシピはこのランでひらめいたレシピとして記録される() -> void:
	_set_mastery_before_ceiling()

	_craft_with(&"holy")

	assert_array(GameState.get_state()["inspired_recipe_ids"]).contains_exactly([HOLY_RESULT_ID])


# 異常系


func test_ひらめき未解禁のランクでは熟練度が貯まらない() -> void:
	_set_rank(false)

	_craft_with(&"holy")

	assert_int(_mastery(SOURCE_RECIPE_ID)).is_equal(0)


func test_候補がない場合はひらめかず熟練度もリセットされない() -> void:
	_set_mastery_before_ceiling()

	_craft_with(&"gold")

	assert_int(_mastery(SOURCE_RECIPE_ID)).is_equal(GameBalance.INSPIRATION_CEILING_COUNT)
	assert_array(_unlocked()).contains_exactly([SOURCE_RECIPE_ID])


func test_調合に失敗した場合は熟練度が変わらない() -> void:
	GameState.execute_alchemy(SOURCE_RECIPE_ID, ["mat_missing"])

	assert_int(_mastery(SOURCE_RECIPE_ID)).is_equal(0)


func test_新規ゲーム開始で熟練度とひらめいたレシピが消える() -> void:
	_set_mastery_before_ceiling()
	_craft_with(&"holy")

	GameState.reset_for_new_game()

	assert_dict(GameState.get_state()["recipe_mastery"]).is_empty()
	assert_array(GameState.get_state()["inspired_recipe_ids"]).is_empty()
	assert_array(_unlocked()).not_contains([HOLY_RESULT_ID])


# セーブ/ロード（FR-717）


func test_熟練度とひらめいたレシピはセーブして復元しても保持される() -> void:
	_set_mastery_before_ceiling()
	_craft_with(&"holy")
	_craft_with(&"")
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_int(_mastery(SOURCE_RECIPE_ID)).is_equal(1)
	assert_array(GameState.get_state()["inspired_recipe_ids"]).contains_exactly([HOLY_RESULT_ID])


func test_熟練度のない旧形式のセーブデータは空として復元される() -> void:
	var data := GameStateSaveDelegate.collect_save_data(GameState)
	data.erase("recipe_mastery")
	data.erase("inspired_recipe_ids")

	GameStateSaveDelegate.restore_save_data(GameState, data)

	assert_dict(GameState.get_state()["recipe_mastery"]).is_empty()
	assert_array(GameState.get_state()["inspired_recipe_ids"]).is_empty()
