extends GdUnitTestSuite


func test_品質倍率テーブルが品質3で1_5を返す() -> void:
	assert_float(GameBalance.QUALITY_MULTIPLIER_TABLE[3]).is_equal(1.5)


func test_投入枠数の初期値が4である() -> void:
	assert_int(GameBalance.ALCHEMY_SLOT_COUNT_DEFAULT).is_equal(4)


func test_特性発現閾値が2である() -> void:
	assert_int(GameBalance.TRAIT_ACTIVATION_THRESHOLD).is_equal(2)


func test_触媒基準品質が3である() -> void:
	assert_int(GameBalance.CATALYST_BASE_QUALITY_SCORE).is_equal(3)


func test_貢献度向け特性ボーナスがholyで1_3を返す() -> void:
	assert_float(GameBalance.TRAIT_CONTRIBUTION_BONUS[&"holy"]).is_equal(1.3)


func test_報酬向け特性ボーナスがgoldで1_3を返す() -> void:
	assert_float(GameBalance.TRAIT_REWARD_BONUS[&"gold"]).is_equal(1.3)


func test_初期解禁レシピidが設定されている() -> void:
	assert_that(GameBalance.INITIAL_RECIPE_ID).is_equal(&"recipe_healing_potion")


func test_品質倍率テーブルが品質1から5までのキーを持つ() -> void:
	for quality in range(GameBalance.QUALITY_SCORE_MIN, GameBalance.QUALITY_SCORE_MAX + 1):
		assert_bool(GameBalance.QUALITY_MULTIPLIER_TABLE.has(quality)).is_true()
	assert_int(GameBalance.QUALITY_MULTIPLIER_TABLE.size()).is_equal(5)


func test_品質倍率テーブルが単調非減少である() -> void:
	for quality in range(GameBalance.QUALITY_SCORE_MIN, GameBalance.QUALITY_SCORE_MAX):
		var current: float = GameBalance.QUALITY_MULTIPLIER_TABLE[quality]
		var next: float = GameBalance.QUALITY_MULTIPLIER_TABLE[quality + 1]
		assert_bool(current <= next).is_true()


func test_貢献度向けと報酬向けの特性キーが重複しない() -> void:
	for trait_id: StringName in GameBalance.TRAIT_CONTRIBUTION_BONUS:
		assert_bool(GameBalance.TRAIT_REWARD_BONUS.has(trait_id)).is_false()


func test_既存の庭関連定数が変更されていない() -> void:
	assert_int(GameBalance.GARDEN_SLOT_COUNT).is_equal(5)
	assert_int(GameBalance.DEATH_GRACE_TURNS_DEFAULT).is_equal(2)
	assert_float(GameBalance.QUALITY_UP_CHANCE).is_equal(0.3)
	assert_int(GameBalance.QUALITY_SCORE_MIN).is_equal(1)
	assert_int(GameBalance.QUALITY_SCORE_MAX).is_equal(5)
	assert_int(GameBalance.WITHER_WARNING_REMAINING_TURNS).is_equal(1)
	assert_that(GameBalance.INITIAL_SEED_ID).is_equal(&"seed_herb")
	assert_int(GameBalance.INITIAL_SEED_COUNT).is_equal(2)
