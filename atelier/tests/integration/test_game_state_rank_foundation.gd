extends GdUnitTestSuite

const RANK_ID: StringName = &"rank_g"
const RECIPE_ID := &"recipe_test"
const FLOAT_TOLERANCE := 0.0001


func before_test() -> void:
	GameState.reset_for_test()


func _make_rank(id: String, traits_unlocked: bool) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = id
	rank.display_name = "テストランク"
	rank.quota_max = 100.0
	rank.limit_turn = 30
	rank.traits_unlocked = traits_unlocked
	return rank


func _make_recipe(id: StringName) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = "テストレシピ"
	recipe.base_contribution = 10.0
	recipe.base_reward = 5.0
	return recipe


func _setup_alchemy(traits_unlocked: bool) -> void:
	GameState._set_recipe_masters_for_test({RECIPE_ID: _make_recipe(RECIPE_ID)})
	GameState._set_unlocked_recipe_ids_for_test([RECIPE_ID] as Array[StringName])
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(String(RANK_ID), traits_unlocked)})
	GameState._set_current_rank_id_for_test(RANK_ID)
	GameState._inject_material_for_test(
		MaterialInstance.new(
			"mat_1", &"material_herb", 3, [&"catalyst", &"heal"] as Array[StringName]
		)
	)
	GameState._inject_material_for_test(
		MaterialInstance.new("mat_2", &"material_herb", 3, [&"heal"] as Array[StringName])
	)


# 正常系


func test_reset_for_test直後はランク関連フィールドが初期値である() -> void:
	assert_that(GameState._current_rank_id).is_equal(GameBalance.INITIAL_RANK_ID)
	assert_int(GameState._rank_masters.size()).is_equal(0)
	assert_float(GameState._rank_state.quota).is_equal(0.0)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(0)
	assert_int(GameState._demotion_count).is_equal(0)


func test_get_stateがランク関連キーを含む() -> void:
	var state := GameState.get_state()

	assert_bool(state.has("current_rank_id")).is_true()
	assert_bool(state.has("demotion_count")).is_true()
	assert_bool(state.has("rank_state")).is_true()
	assert_that(state["current_rank_id"]).is_equal(GameBalance.INITIAL_RANK_ID)
	assert_int(state["demotion_count"]).is_equal(0)


func test_set_rank_masters_for_testと_set_current_rank_id_for_testで注入したRankMasterが返る() -> void:
	var rank := _make_rank("rank_g", true)
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)

	var resolved: RankMaster = GameState._get_current_rank_master_or_fallback()

	assert_object(resolved).is_same(rank)
	assert_bool(resolved.traits_unlocked).is_true()
	assert_float(resolved.quota_max).is_equal(100.0)


func test_set_rank_state_for_testで注入した値が状態に反映される() -> void:
	var rank_state := RankState.new()
	rank_state.quota = 42.5
	rank_state.elapsed_turn = 7

	GameState._set_rank_state_for_test(rank_state)

	var stored: RankState = GameState.get_state()["rank_state"]
	assert_float(stored.quota).is_equal_approx(42.5, FLOAT_TOLERANCE)
	assert_int(stored.elapsed_turn).is_equal(7)


func test_set_demotion_count_for_testで注入した値が状態に反映される() -> void:
	GameState._set_demotion_count_for_test(2)

	assert_int(GameState._demotion_count).is_equal(2)
	assert_int(GameState.get_state()["demotion_count"]).is_equal(2)


func test_特性解禁済みランクでは調合時に触媒と特性の両ボーナスが有効になる() -> void:
	_setup_alchemy(true)

	var result := GameState.execute_alchemy(RECIPE_ID, ["mat_1", "mat_2"] as Array[String])

	var product: ProductInstance = result.value
	# 触媒で品質3→4（倍率1.75）、heal×2で貢献度系ボーナス1.3が発現
	assert_int(product.quality_score).is_equal(4)
	assert_array(product.activated_traits).contains_exactly([&"heal"] as Array[StringName])
	assert_float(product.contribution).is_equal_approx(22.75, FLOAT_TOLERANCE)


func test_特性未解禁ランクでは同じ素材構成でも両ボーナスが無効になる() -> void:
	_setup_alchemy(false)

	var result := GameState.execute_alchemy(RECIPE_ID, ["mat_1", "mat_2"] as Array[String])

	var product: ProductInstance = result.value
	assert_int(product.quality_score).is_equal(3)
	assert_array(product.activated_traits).is_empty()
	assert_float(product.contribution).is_equal_approx(15.0, FLOAT_TOLERANCE)


# 異常系


func test_rank_mastersが空でもフォールバックRankMasterが返りクラッシュしない() -> void:
	var resolved: RankMaster = GameState._get_current_rank_master_or_fallback()

	assert_object(resolved).is_not_null()
	assert_bool(resolved.traits_unlocked).is_false()
	assert_float(resolved.quota_max).is_equal(0.0)
	assert_int(resolved.limit_turn).is_equal(0)


func test_現在ランクIDに対応するマスターが無い場合もフォールバックが返る() -> void:
	GameState._set_rank_masters_for_test({&"rank_f": _make_rank("rank_f", true)})
	GameState._set_current_rank_id_for_test(&"rank_s")

	var resolved: RankMaster = GameState._get_current_rank_master_or_fallback()

	assert_bool(resolved.traits_unlocked).is_false()


func test_マスター未注入のまま調合しても特性は無効のまま成功する() -> void:
	GameState._set_recipe_masters_for_test({RECIPE_ID: _make_recipe(RECIPE_ID)})
	GameState._set_unlocked_recipe_ids_for_test([RECIPE_ID] as Array[StringName])
	GameState._inject_material_for_test(
		MaterialInstance.new(
			"mat_1", &"material_herb", 3, [&"catalyst", &"heal"] as Array[StringName]
		)
	)
	GameState._inject_material_for_test(
		MaterialInstance.new("mat_2", &"material_herb", 3, [&"heal"] as Array[StringName])
	)

	var result := GameState.execute_alchemy(RECIPE_ID, ["mat_1", "mat_2"] as Array[String])

	assert_bool(result.success).is_true()
	assert_int((result.value as ProductInstance).quality_score).is_equal(3)


## CON-005: 暫定フィールド_traits_unlockedのテスト専用APIはランク注入経由へ一本化され削除済み
func test_set_traits_unlocked_for_testが削除されている() -> void:
	assert_bool(GameState.has_method("_set_traits_unlocked_for_test")).is_false()


# 境界値・エッジケース


## FR-410: get_state()のrank_stateを変更してもGameState内部の正本は汚染されない
func test_get_stateのrank_stateを変更しても内部状態は汚染されない() -> void:
	var injected := RankState.new()
	injected.quota = 10.0
	injected.elapsed_turn = 1
	GameState._set_rank_state_for_test(injected)

	var returned: RankState = GameState.get_state()["rank_state"]
	returned.quota = 999.0
	returned.elapsed_turn = 99

	var again: RankState = GameState.get_state()["rank_state"]
	assert_float(again.quota).is_equal_approx(10.0, FLOAT_TOLERANCE)
	assert_int(again.elapsed_turn).is_equal(1)


## _set_rank_state_for_test()は内部でclone()するため、注入後に引数を変更しても汚染されない
func test_set_rank_state_for_test注入後に引数を変更しても内部状態は汚染されない() -> void:
	var injected := RankState.new()
	injected.quota = 10.0
	GameState._set_rank_state_for_test(injected)

	injected.quota = 999.0

	assert_float(GameState._rank_state.quota).is_equal_approx(10.0, FLOAT_TOLERANCE)


func test_reset_for_testでランク関連フィールドが初期状態に戻る() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank("rank_g", true)})
	GameState._set_current_rank_id_for_test(&"rank_a")
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT)
	var rank_state := RankState.new()
	rank_state.quota = 50.0
	rank_state.elapsed_turn = 5
	GameState._set_rank_state_for_test(rank_state)

	GameState.reset_for_test()

	assert_that(GameState._current_rank_id).is_equal(GameBalance.INITIAL_RANK_ID)
	assert_int(GameState._rank_masters.size()).is_equal(0)
	assert_float(GameState._rank_state.quota).is_equal(0.0)
	assert_int(GameState._rank_state.elapsed_turn).is_equal(0)
	assert_int(GameState._demotion_count).is_equal(0)
