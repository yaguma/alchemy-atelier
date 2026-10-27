extends GdUnitTestSuite

## 🔵 Issue #68（FR-715）。予告された試験ルールで昇格試験が行われ、進捗で合否が決まり、
## 合格報酬が解禁されることを検証する。

const RANK_ID: StringName = &"rank_e"
const NEXT_RANK_ID: StringName = &"rank_d"
const RECIPE_ID := &"recipe_a"
const REWARD_RECIPE_ID := &"recipe_reward"
const DELIVER_RULE_ID := &"exam_deliver"
const SLOT_RULE_ID := &"exam_slot"
const INTERMEDIATE_RULE_ID := &"exam_intermediate"


func before_test() -> void:
	GameState.reset_for_test()
	var recipes := {
		RECIPE_ID: _make_recipe(RECIPE_ID), REWARD_RECIPE_ID: _make_recipe(REWARD_RECIPE_ID)
	}
	GameState._set_recipe_masters_for_test(recipes)
	GameState._set_unlocked_recipe_ids_for_test([RECIPE_ID] as Array[StringName])
	GameState._set_alchemy_slot_count_for_test(4)
	var intermediate_rule := _make_rule(INTERMEDIATE_RULE_ID, ExamRuleMaster.RULE_USE_INTERMEDIATE)
	var rules := {
		DELIVER_RULE_ID: _make_rule(DELIVER_RULE_ID, ExamRuleMaster.RULE_DELIVER_ITEMS),
		SLOT_RULE_ID: _make_rule(SLOT_RULE_ID, ExamRuleMaster.RULE_QUALITY_WITH_SLOT_LIMIT),
		INTERMEDIATE_RULE_ID: intermediate_rule,
	}
	GameState._set_exam_rule_masters_for_test(rules)
	var pool: Array[StringName] = [DELIVER_RULE_ID]
	GameState._set_rank_masters_for_test(
		{RANK_ID: _make_rank(RANK_ID, pool), NEXT_RANK_ID: _make_rank(NEXT_RANK_ID, pool)}
	)
	GameState._set_current_rank_id_for_test(RANK_ID)


func after_test() -> void:
	GameState.reset_for_test()


func _make_recipe(id: StringName) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = String(id)
	recipe.base_contribution = 10.0
	recipe.base_reward = 5.0
	return recipe


func _make_rule(id: StringName, rule_type: StringName) -> ExamRuleMaster:
	var rule := ExamRuleMaster.new()
	rule.id = id
	rule.rule_type = rule_type
	rule.display_text = "試験: %s" % id
	rule.turn_limit = 2
	rule.target_count = 2
	rule.slot_limit = 2
	rule.min_quality = 1
	rule.reward_recipe_ids = [REWARD_RECIPE_ID] as Array[StringName]
	return rule


func _make_rank(id: StringName, pool: Array[StringName]) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = String(id)
	rank.quota_max = 100.0
	rank.limit_turn = 10
	rank.traits_unlocked = true
	rank.exam_turn_limit = 1
	rank.exam_difficulty_coefficient = 1.0
	rank.exam_rule_pool = pool
	return rank


## 制限ターン到達・ノルマ0の状態で、指定ルールを予告済みにして試験を始める
func _start_exam_with(rule_id: StringName) -> void:
	var rank_state := RankState.new()
	rank_state.quota = 0.0
	rank_state.elapsed_turn = 10
	rank_state.announced_exam_rule_id = rule_id
	GameState._set_rank_state_for_test(rank_state)
	GameState.commit_rank_outcome()


func _craft_and_deliver(quality: int = 3) -> void:
	var id := "mat_q%d_%d" % [quality, (GameState.get_state()["inventory"] as Array).size()]
	var no_traits: Array[StringName] = []
	GameState._inject_material_for_test(
		MaterialInstance.new(id, &"material_herb", quality, no_traits)
	)
	GameState.execute_alchemy(RECIPE_ID, [id])
	GameState.deliver_pending_products()


# 正常系


func test_予告された試験ルールで試験が始まり制限ターンはルールの値になる() -> void:
	_start_exam_with(DELIVER_RULE_ID)

	var state := GameState.get_state()
	assert_bool(state["in_exam"]).is_true()
	assert_int(state["exam_turn_limit"]).is_equal(2)
	assert_that(state["exam_rule_id"]).is_equal(DELIVER_RULE_ID)


func test_指定数を納品すると合格し合格報酬のレシピが解禁される() -> void:
	_start_exam_with(DELIVER_RULE_ID)
	_craft_and_deliver()
	assert_int(GameState.evaluate_exam_outcome()).is_equal(ExamOutcome.Value.CONTINUE)

	_craft_and_deliver()
	GameState.commit_exam_outcome()

	assert_that(GameState.get_state()["current_rank_id"]).is_equal(NEXT_RANK_ID)
	assert_array(GameState.get_state()["unlocked_recipe_ids"]).contains([REWARD_RECIPE_ID])


func test_試験中の納品で進捗が記録される() -> void:
	_start_exam_with(DELIVER_RULE_ID)

	_craft_and_deliver()

	var progress: Dictionary = GameState.get_state()["exam_progress"]
	assert_int(ExamRuleResolver.delivered_count(progress)).is_equal(1)


func test_昇格すると次のランクの試験ルールが予告される() -> void:
	_start_exam_with(DELIVER_RULE_ID)
	_craft_and_deliver()
	_craft_and_deliver()

	GameState.commit_exam_outcome()

	var rank_state: RankState = GameState.get_state()["rank_state"]
	assert_that(rank_state.announced_exam_rule_id).is_equal(DELIVER_RULE_ID)


func test_get_stateに予告された試験ルールが含まれる() -> void:
	var rank_state := RankState.new()
	rank_state.quota = 100.0
	rank_state.announced_exam_rule_id = DELIVER_RULE_ID
	GameState._set_rank_state_for_test(rank_state)

	var announced: ExamRuleMaster = GameState.get_state()["announced_exam_rule"]

	assert_that(announced.id).is_equal(DELIVER_RULE_ID)
	assert_str(announced.display_text).is_equal("試験: exam_deliver")


func test_投入枠制限ルールの試験中は投入枠の上限が下がる() -> void:
	_start_exam_with(SLOT_RULE_ID)
	var no_traits: Array[StringName] = []
	for id in ["m1", "m2", "m3"]:
		GameState._inject_material_for_test(
			MaterialInstance.new(id, &"material_herb", 3, no_traits)
		)

	var result := GameState.execute_alchemy(RECIPE_ID, ["m1", "m2", "m3"])

	assert_int(GameState.get_state()["effective_alchemy_slot_count"]).is_equal(2)
	assert_bool(result.success).is_false()


func test_中間素材を投入した調合物は中間素材使用として記録される() -> void:
	var holy_water := MaterialMaster.new()
	holy_water.id = &"material_holy_water"
	holy_water.is_intermediate = true
	GameState._set_masters_for_test({}, {&"material_holy_water": holy_water})
	var no_traits: Array[StringName] = []
	GameState._inject_material_for_test(
		MaterialInstance.new("hw", &"material_holy_water", 3, no_traits)
	)

	var result := GameState.execute_alchemy(RECIPE_ID, ["hw"])

	assert_bool((result.value as ProductInstance).used_intermediate).is_true()


# 異常系


func test_予告がなければ従来の試験ノルマ方式で試験が行われる() -> void:
	_start_exam_with(&"")

	var state := GameState.get_state()
	assert_int(state["exam_turn_limit"]).is_equal(1)
	assert_that(state["exam_rule_id"]).is_equal(&"")
	assert_object(state["announced_exam_rule"]).is_null()


func test_存在しない試験ルールが予告されていても従来の試験ノルマ方式で試験が行われる() -> void:
	_start_exam_with(&"exam_missing")

	assert_int(GameState.get_state()["exam_turn_limit"]).is_equal(1)


func test_制限ターンまでに指定数を納品できなければ不合格で再挑戦時に予告し直される() -> void:
	_start_exam_with(DELIVER_RULE_ID)
	GameState.advance_exam_turn()
	GameState.advance_exam_turn()

	GameState.commit_exam_outcome()

	var state := GameState.get_state()
	assert_that(state["current_rank_id"]).is_equal(RANK_ID)
	assert_bool(state["in_exam"]).is_false()
	var rank_state: RankState = state["rank_state"]
	assert_that(rank_state.announced_exam_rule_id).is_equal(DELIVER_RULE_ID)
	assert_array(state["unlocked_recipe_ids"]).not_contains([REWARD_RECIPE_ID])


func test_試験外の納品は進捗に記録されない() -> void:
	_craft_and_deliver()

	assert_dict(GameState.get_state()["exam_progress"]).is_empty()


# セーブ/ロード（FR-717）


func test_予告と試験の進捗はセーブして復元しても保持される() -> void:
	_start_exam_with(DELIVER_RULE_ID)
	_craft_and_deliver()
	var data := GameStateSaveDelegate.collect_save_data(GameState)

	GameState.reset_for_test()
	GameStateSaveDelegate.restore_save_data(GameState, data)

	var state := GameState.get_state()
	assert_that(state["exam_rule_id"]).is_equal(DELIVER_RULE_ID)
	assert_int(ExamRuleResolver.delivered_count(state["exam_progress"])).is_equal(1)


func test_試験ルールのない旧形式のセーブデータは予告なしとして復元される() -> void:
	var data := GameStateSaveDelegate.collect_save_data(GameState)
	(data["rank_state"] as Dictionary).erase("announced_exam_rule_id")
	(data["exam_state"] as Dictionary).erase("exam_rule_id")
	(data["exam_state"] as Dictionary).erase("progress")

	GameStateSaveDelegate.restore_save_data(GameState, data)

	var state := GameState.get_state()
	assert_that((state["rank_state"] as RankState).announced_exam_rule_id).is_equal(&"")
	assert_dict(state["exam_progress"]).is_empty()
