extends GdUnitTestSuite

const RANK_ID: StringName = &"rank_g"


func before_test() -> void:
	GameState.reset_for_test()


func _make_recipe(id: StringName) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = "テストレシピ"
	recipe.base_contribution = 10.0
	recipe.base_reward = 5.0
	return recipe


func _make_rank(id: String, traits_unlocked: bool) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = id
	rank.display_name = "テストランク"
	rank.quota_max = 100.0
	rank.limit_turn = 30
	rank.traits_unlocked = traits_unlocked
	return rank


# 正常系


func test_get_stateが注入したrecipe_mastersを全件含んで返す() -> void:
	var masters := {
		&"recipe_a": _make_recipe(&"recipe_a"),
		&"recipe_b": _make_recipe(&"recipe_b"),
	}
	GameState._set_recipe_masters_for_test(masters)

	var recipe_masters: Dictionary = GameState.get_state()["recipe_masters"]

	assert_int(recipe_masters.size()).is_equal(2)
	assert_bool(recipe_masters.has(&"recipe_a")).is_true()
	assert_bool(recipe_masters.has(&"recipe_b")).is_true()
	var recipe_a: RecipeMaster = recipe_masters[&"recipe_a"]
	assert_str(recipe_a.name).is_equal("テストレシピ")


func test_get_stateが注入したalchemy_slot_countを返す() -> void:
	GameState._set_alchemy_slot_count_for_test(6)

	assert_int(GameState.get_state()["alchemy_slot_count"]).is_equal(6)


func test_reset_for_test直後のalchemy_slot_countは既定値である() -> void:
	assert_int(GameState.get_state()["alchemy_slot_count"]).is_equal(
		GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT
	)


func test_特性解禁済みランクではis_current_rank_traits_unlockedがtrueを返す() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(String(RANK_ID), true)})
	GameState._set_current_rank_id_for_test(RANK_ID)

	assert_bool(GameState.is_current_rank_traits_unlocked()).is_true()


func test_特性未解禁ランクではis_current_rank_traits_unlockedがfalseを返す() -> void:
	GameState._set_rank_masters_for_test({RANK_ID: _make_rank(String(RANK_ID), false)})
	GameState._set_current_rank_id_for_test(RANK_ID)

	assert_bool(GameState.is_current_rank_traits_unlocked()).is_false()


# 異常系


## ランクマスター未ロード時もフォールバック（traits_unlocked = false）で例外なく解決されることを確認する。
## push_error()は発生するが、これは_get_current_rank_master_or_fallback()の設計通りの挙動
func test_ランクマスター未登録でもis_current_rank_traits_unlockedがfalseを返す() -> void:
	GameState._set_current_rank_id_for_test(&"rank_unknown")

	assert_bool(GameState.is_current_rank_traits_unlocked()).is_false()


func test_get_state戻り値のrecipe_mastersへキーを追加しても内部状態は変化しない() -> void:
	GameState._set_recipe_masters_for_test({&"recipe_a": _make_recipe(&"recipe_a")})

	var recipe_masters: Dictionary = GameState.get_state()["recipe_masters"]
	recipe_masters[&"recipe_injected"] = _make_recipe(&"recipe_injected")

	var recipe_masters_after: Dictionary = GameState.get_state()["recipe_masters"]
	assert_int(recipe_masters_after.size()).is_equal(1)
	assert_bool(recipe_masters_after.has(&"recipe_injected")).is_false()


# 境界値


func test_recipe_mastersが空辞書でも空のまま返る() -> void:
	var recipe_masters: Dictionary = GameState.get_state()["recipe_masters"]

	assert_int(recipe_masters.size()).is_equal(0)


func test_alchemy_slot_countに0を注入しても0がそのまま返る() -> void:
	GameState._set_alchemy_slot_count_for_test(0)

	assert_int(GameState.get_state()["alchemy_slot_count"]).is_equal(0)
