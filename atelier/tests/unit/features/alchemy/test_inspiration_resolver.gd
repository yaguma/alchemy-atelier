extends GdUnitTestSuite

## 🔵 Issue #67（FR-714）。熟練ひらめきの確率・候補選び・内容の決定を検証する。

const SOURCE := &"recipe_healing_potion"


func _make_master(
	id: StringName,
	required: Array[StringName],
	result: StringName,
	min_rank_id: StringName = &"rank_e",
	source: StringName = SOURCE
) -> InspirationMaster:
	var master := InspirationMaster.new()
	master.id = id
	master.source_recipe_id = source
	master.required_traits = required
	master.result_recipe_id = result
	master.min_rank_id = min_rank_id
	return master


func _no_unlocked() -> Array[StringName]:
	return []


# 正常系（確率）


func test_初回の確率は初回確率になる() -> void:
	assert_float(InspirationResolver.chance_for(1)).is_equal_approx(
		GameBalance.INSPIRATION_BASE_CHANCE, 0.0001
	)


func test_1回ごとに上昇幅ずつ確率が上がる() -> void:
	assert_float(InspirationResolver.chance_for(3)).is_equal_approx(
		GameBalance.INSPIRATION_BASE_CHANCE + GameBalance.INSPIRATION_CHANCE_STEP * 2, 0.0001
	)


func test_天井回数に達すると確率は1になる() -> void:
	assert_float(InspirationResolver.chance_for(GameBalance.INSPIRATION_CEILING_COUNT)).is_equal(
		1.0
	)


func test_乱数値が確率未満ならひらめく() -> void:
	assert_bool(InspirationResolver.should_inspire(1, 0.05)).is_true()


func test_乱数値が確率以上ならひらめかない() -> void:
	assert_bool(InspirationResolver.should_inspire(1, 0.5)).is_false()


# 正常系（候補と内容）


func test_元レシピと投入特性が一致する候補を返す() -> void:
	var holy := _make_master(&"insp_holy", [&"holy"] as Array[StringName], &"recipe_holy_water")
	var heal := _make_master(&"insp_heal", [&"heal"] as Array[StringName], &"recipe_high")
	var input: Array[StringName] = [&"holy"]

	var candidates := InspirationResolver.find_candidates(
		[holy, heal] as Array[InspirationMaster], SOURCE, input, &"rank_e", _no_unlocked()
	)

	assert_int(candidates.size()).is_equal(1)
	assert_that(candidates[0].id).is_equal(&"insp_holy")


func test_必要特性の多いより具体的な候補が優先される() -> void:
	var gold := _make_master(&"insp_gold", [&"gold"] as Array[StringName], &"recipe_gold_dust")
	var both := _make_master(
		&"insp_both", [&"holy", &"gold"] as Array[StringName], &"recipe_blessed"
	)
	var input: Array[StringName] = [&"holy", &"gold"]
	var candidates := InspirationResolver.find_candidates(
		[gold, both] as Array[InspirationMaster], SOURCE, input, &"rank_e", _no_unlocked()
	)

	var picked := InspirationResolver.pick(candidates, 0.0)

	assert_that(picked.id).is_equal(&"insp_both")


func test_同じ具体度の候補は乱数で選ばれる() -> void:
	var a := _make_master(&"insp_a", [&"holy"] as Array[StringName], &"recipe_a")
	var b := _make_master(&"insp_b", [&"holy"] as Array[StringName], &"recipe_b")
	var candidates: Array[InspirationMaster] = [a, b]

	assert_that(InspirationResolver.pick(candidates, 0.1).id).is_equal(&"insp_a")
	assert_that(InspirationResolver.pick(candidates, 0.9).id).is_equal(&"insp_b")


# 異常系


func test_熟練度0以下の確率は0になる() -> void:
	assert_float(InspirationResolver.chance_for(0)).is_equal(0.0)


func test_解禁済みのレシピは候補から外れる() -> void:
	var holy := _make_master(&"insp_holy", [&"holy"] as Array[StringName], &"recipe_holy_water")
	var input: Array[StringName] = [&"holy"]
	var unlocked: Array[StringName] = [&"recipe_holy_water"]

	var candidates := InspirationResolver.find_candidates(
		[holy] as Array[InspirationMaster], SOURCE, input, &"rank_e", unlocked
	)

	assert_array(candidates).is_empty()


func test_解禁ランクに届かない候補は外れる() -> void:
	var holy := _make_master(
		&"insp_holy", [&"holy"] as Array[StringName], &"recipe_holy_water", &"rank_c"
	)
	var input: Array[StringName] = [&"holy"]

	var candidates := InspirationResolver.find_candidates(
		[holy] as Array[InspirationMaster], SOURCE, input, &"rank_e", _no_unlocked()
	)

	assert_array(candidates).is_empty()


func test_別の元レシピの候補は外れる() -> void:
	var other := _make_master(
		&"insp_other", [&"holy"] as Array[StringName], &"recipe_x", &"rank_e", &"recipe_mana_tonic"
	)
	var input: Array[StringName] = [&"holy"]

	var candidates := InspirationResolver.find_candidates(
		[other] as Array[InspirationMaster], SOURCE, input, &"rank_e", _no_unlocked()
	)

	assert_array(candidates).is_empty()


func test_必要特性が投入されていなければ外れる() -> void:
	var both := _make_master(
		&"insp_both", [&"holy", &"gold"] as Array[StringName], &"recipe_blessed"
	)
	var input: Array[StringName] = [&"holy"]

	var candidates := InspirationResolver.find_candidates(
		[both] as Array[InspirationMaster], SOURCE, input, &"rank_e", _no_unlocked()
	)

	assert_array(candidates).is_empty()


func test_候補がなければpickはnullを返す() -> void:
	var empty: Array[InspirationMaster] = []

	assert_object(InspirationResolver.pick(empty, 0.5)).is_null()


func test_RANK_ORDERにない現在ランクでは候補が出ない() -> void:
	var holy := _make_master(&"insp_holy", [&"holy"] as Array[StringName], &"recipe_holy_water")
	var input: Array[StringName] = [&"holy"]

	var candidates := InspirationResolver.find_candidates(
		[holy] as Array[InspirationMaster], SOURCE, input, &"rank_unknown", _no_unlocked()
	)

	assert_array(candidates).is_empty()


# 境界値


func test_天井の直前回数でも確率は1未満である() -> void:
	var before_ceiling := GameBalance.INSPIRATION_CEILING_COUNT - 1

	assert_float(InspirationResolver.chance_for(before_ceiling)).is_less(1.0)


func test_天井を超えた回数でも確率は1のまま() -> void:
	var over_ceiling := GameBalance.INSPIRATION_CEILING_COUNT + 3

	assert_float(InspirationResolver.chance_for(over_ceiling)).is_equal(1.0)


func test_乱数値1未満なら天井では必ずひらめく() -> void:
	var ceiling := GameBalance.INSPIRATION_CEILING_COUNT

	assert_bool(InspirationResolver.should_inspire(ceiling, 0.9999)).is_true()


func test_input_traitsは投入素材の特性の和集合で触媒を除く() -> void:
	var materials: Array[MaterialInstance] = [
		MaterialInstance.new("m1", &"material_herb", 3, [&"holy"] as Array[StringName]),
		MaterialInstance.new("m2", &"material_herb", 3, [&"holy", &"holy"] as Array[StringName]),
		MaterialInstance.new("m3", &"material_catalyst", 3, [&"catalyst"] as Array[StringName]),
	]

	assert_array(InspirationResolver.input_traits(materials)).contains_exactly(
		[&"holy"] as Array[StringName]
	)


# inspirable_source_recipe_ids（PR #75レビュー指摘対応）


func test_ひらめく余地のある元レシピを重複なく返す() -> void:
	var holy := _make_master(&"insp_holy", [&"holy"] as Array[StringName], &"recipe_holy_water")
	var heal := _make_master(&"insp_heal", [&"heal"] as Array[StringName], &"recipe_high")
	var gold := _make_master(
		&"insp_gold", [&"gold"] as Array[StringName], &"recipe_gold_dust", &"rank_e", &"recipe_mana"
	)

	var source_ids := InspirationResolver.inspirable_source_recipe_ids(
		[holy, heal, gold] as Array[InspirationMaster], &"rank_e", _no_unlocked()
	)

	assert_array(source_ids).contains_exactly([SOURCE, &"recipe_mana"] as Array[StringName])


func test_結果がすべて解禁済みの元レシピは含まれない() -> void:
	var holy := _make_master(&"insp_holy", [&"holy"] as Array[StringName], &"recipe_holy_water")
	var unlocked: Array[StringName] = [&"recipe_holy_water"]

	var source_ids := InspirationResolver.inspirable_source_recipe_ids(
		[holy] as Array[InspirationMaster], &"rank_e", unlocked
	)

	assert_array(source_ids).is_empty()


func test_解禁ランクに届かない対応表しかない元レシピは含まれない() -> void:
	var holy := _make_master(
		&"insp_holy", [&"holy"] as Array[StringName], &"recipe_holy_water", &"rank_c"
	)

	var source_ids := InspirationResolver.inspirable_source_recipe_ids(
		[holy] as Array[InspirationMaster], &"rank_e", _no_unlocked()
	)

	assert_array(source_ids).is_empty()


func test_一部の結果だけ解禁済みなら元レシピは含まれる() -> void:
	var holy := _make_master(&"insp_holy", [&"holy"] as Array[StringName], &"recipe_holy_water")
	var heal := _make_master(&"insp_heal", [&"heal"] as Array[StringName], &"recipe_high")
	var unlocked: Array[StringName] = [&"recipe_holy_water"]

	var source_ids := InspirationResolver.inspirable_source_recipe_ids(
		[holy, heal] as Array[InspirationMaster], &"rank_e", unlocked
	)

	assert_array(source_ids).contains_exactly([SOURCE] as Array[StringName])
