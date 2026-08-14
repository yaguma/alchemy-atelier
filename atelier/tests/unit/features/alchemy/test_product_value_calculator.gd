extends GdUnitTestSuite

const PRODUCT_VALUE_CALCULATOR_PATH := "res://features/alchemy/logic/product_value_calculator.gd"


func _arg_names(method_name: String) -> Array[String]:
	var script: GDScript = load(PRODUCT_VALUE_CALCULATOR_PATH)
	for method in script.get_script_method_list():
		if method["name"] != method_name:
			continue
		var names: Array[String] = []
		for arg in method["args"]:
			names.append(arg["name"])
		return names
	return []


# 正常系
func test_貢献度は基礎値と品質倍率と特性ボーナスの積である() -> void:
	assert_float(ProductValueCalculator.calculate_contribution(10.0, 1.5, 1.3)).is_equal_approx(
		19.5, 0.0001
	)


# 正常系
func test_報酬は基礎値と品質倍率と特性ボーナスの積である() -> void:
	assert_float(ProductValueCalculator.calculate_reward(5.0, 1.5, 1.0)).is_equal_approx(
		7.5, 0.0001
	)


# 境界値
func test_基礎値がゼロなら貢献度も報酬もゼロになる() -> void:
	assert_float(ProductValueCalculator.calculate_contribution(0.0, 2.0, 1.3)).is_equal_approx(
		0.0, 0.0001
	)
	assert_float(ProductValueCalculator.calculate_reward(0.0, 2.0, 1.3)).is_equal_approx(
		0.0, 0.0001
	)


# 異常系: FR-406 二重乗算バグ再発防止（match_bonus_multiplier相当の引数を受け取らない）
func test_貢献度と報酬の算出関数は引数を3つしか受け取らない() -> void:
	var contribution_args := _arg_names("calculate_contribution")
	var reward_args := _arg_names("calculate_reward")

	assert_array(contribution_args).is_equal(["base_contribution", "quality_mult", "trait_bonus"])
	assert_array(reward_args).is_equal(["base_reward", "quality_mult", "trait_bonus"])


# 正常系
func test_貢献度系特性ボーナスは乗算合成される() -> void:
	var activated: Array[StringName] = [&"holy", &"purify"]
	var expected: float = (
		float(GameBalance.TRAIT_CONTRIBUTION_BONUS[&"holy"])
		* float(GameBalance.TRAIT_CONTRIBUTION_BONUS[&"purify"])
	)

	assert_float(ProductValueCalculator.resolve_contribution_bonus(activated)).is_equal_approx(
		expected, 0.0001
	)


# 正常系
func test_報酬系特性ボーナスは乗算合成される() -> void:
	var activated: Array[StringName] = [&"gold", &"glamour"]
	var expected: float = (
		float(GameBalance.TRAIT_REWARD_BONUS[&"gold"])
		* float(GameBalance.TRAIT_REWARD_BONUS[&"glamour"])
	)

	assert_float(ProductValueCalculator.resolve_reward_bonus(activated)).is_equal_approx(
		expected, 0.0001
	)


# 正常系: 系統をまたいで乗算しない（真のトレードオフの前提）
func test_貢献度系ボーナス算出は報酬系タグを無視する() -> void:
	var activated: Array[StringName] = [&"gold"]

	assert_float(ProductValueCalculator.resolve_contribution_bonus(activated)).is_equal_approx(
		1.0, 0.0001
	)


# 正常系: 系統をまたいで乗算しない
func test_報酬系ボーナス算出は貢献度系タグを無視する() -> void:
	var activated: Array[StringName] = [&"holy"]

	assert_float(ProductValueCalculator.resolve_reward_bonus(activated)).is_equal_approx(
		1.0, 0.0001
	)


# 正常系: 混在時はそれぞれ自系統のタグのみを合成する
func test_混在した特性タグから系統ごとのボーナスを分離して合成する() -> void:
	var activated: Array[StringName] = [&"holy", &"gold", &"purify"]
	var expected_contribution: float = (
		float(GameBalance.TRAIT_CONTRIBUTION_BONUS[&"holy"])
		* float(GameBalance.TRAIT_CONTRIBUTION_BONUS[&"purify"])
	)

	assert_float(ProductValueCalculator.resolve_contribution_bonus(activated)).is_equal_approx(
		expected_contribution, 0.0001
	)
	assert_float(ProductValueCalculator.resolve_reward_bonus(activated)).is_equal_approx(
		float(GameBalance.TRAIT_REWARD_BONUS[&"gold"]), 0.0001
	)


# 異常系
func test_発現特性が空なら各系統のボーナスは1倍である() -> void:
	var activated: Array[StringName] = []

	assert_float(ProductValueCalculator.resolve_contribution_bonus(activated)).is_equal_approx(
		1.0, 0.0001
	)
	assert_float(ProductValueCalculator.resolve_reward_bonus(activated)).is_equal_approx(
		1.0, 0.0001
	)


# 異常系
func test_未登録の特性タグは無視され1倍のままである() -> void:
	var activated: Array[StringName] = [&"unknown_trait"]

	assert_float(ProductValueCalculator.resolve_contribution_bonus(activated)).is_equal_approx(
		1.0, 0.0001
	)
	assert_float(ProductValueCalculator.resolve_reward_bonus(activated)).is_equal_approx(
		1.0, 0.0001
	)


# 境界値: 貢献度系タグ全種を渡すと全倍率の積になる
func test_貢献度系タグ全種を渡すと全倍率の積になる() -> void:
	var activated: Array[StringName] = []
	var expected := 1.0
	for tag: StringName in GameBalance.TRAIT_CONTRIBUTION_BONUS:
		activated.append(tag)
		expected *= float(GameBalance.TRAIT_CONTRIBUTION_BONUS[tag])

	assert_float(ProductValueCalculator.resolve_contribution_bonus(activated)).is_equal_approx(
		expected, 0.0001
	)


# 境界値: 報酬系タグ全種を渡すと全倍率の積になる
func test_報酬系タグ全種を渡すと全倍率の積になる() -> void:
	var activated: Array[StringName] = []
	var expected := 1.0
	for tag: StringName in GameBalance.TRAIT_REWARD_BONUS:
		activated.append(tag)
		expected *= float(GameBalance.TRAIT_REWARD_BONUS[tag])

	assert_float(ProductValueCalculator.resolve_reward_bonus(activated)).is_equal_approx(
		expected, 0.0001
	)
