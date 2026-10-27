extends GdUnitTestSuite

## 🔵 Issue #65（FR-712）。需要相場の倍率計算を検証する。

const RECIPE_A := &"recipe_a"
const RECIPE_B := &"recipe_b"

# 正常系


func test_未登録のレシピの相場倍率は既定値を返す() -> void:
	assert_float(MarketRateResolver.get_rate({}, RECIPE_A)).is_equal(
		GameBalance.MARKET_RATE_DEFAULT
	)


func test_登録済みのレシピは保持している相場倍率を返す() -> void:
	assert_float(MarketRateResolver.get_rate({RECIPE_A: 0.8}, RECIPE_A)).is_equal_approx(
		0.8, 0.0001
	)


func test_納品後はそのレシピの相場倍率が下落幅だけ下がる() -> void:
	var rates := MarketRateResolver.after_delivery({}, RECIPE_A)

	assert_float(MarketRateResolver.get_rate(rates, RECIPE_A)).is_equal_approx(
		GameBalance.MARKET_RATE_DEFAULT - GameBalance.MARKET_DROP_STEP, 0.0001
	)


# 🔵 PR #73レビュー指摘対応。納品待ちの調合物を順に納品した後の見込み相場
func test_納品待ちの同じレシピの数だけ見込み相場が下がる() -> void:
	var pending: Array[StringName] = [RECIPE_A, RECIPE_B, RECIPE_A]

	var projected := MarketRateResolver.project_after_deliveries({}, pending)

	assert_float(MarketRateResolver.get_rate(projected, RECIPE_A)).is_equal_approx(
		GameBalance.MARKET_RATE_DEFAULT - GameBalance.MARKET_DROP_STEP * 2, 0.0001
	)
	assert_float(MarketRateResolver.get_rate(projected, RECIPE_B)).is_equal_approx(
		GameBalance.MARKET_RATE_DEFAULT - GameBalance.MARKET_DROP_STEP, 0.0001
	)


# 境界値
func test_納品待ちが空なら見込み相場は現在の相場と同じ() -> void:
	var pending: Array[StringName] = []

	var projected := MarketRateResolver.project_after_deliveries({RECIPE_A: 0.8}, pending)

	assert_float(MarketRateResolver.get_rate(projected, RECIPE_A)).is_equal_approx(0.8, 0.0001)


# 異常系
func test_project_after_deliveriesは引数の辞書を書き換えない() -> void:
	var original := {RECIPE_A: 1.0}
	var pending: Array[StringName] = [RECIPE_A]

	MarketRateResolver.project_after_deliveries(original, pending)

	assert_float(original[RECIPE_A]).is_equal_approx(1.0, 0.0001)


func test_納品後も他のレシピの相場倍率は変わらない() -> void:
	var rates := MarketRateResolver.after_delivery({RECIPE_B: 0.9}, RECIPE_A)

	assert_float(MarketRateResolver.get_rate(rates, RECIPE_B)).is_equal_approx(0.9, 0.0001)


func test_after_deliveryは引数の辞書を書き換えない() -> void:
	var original := {RECIPE_A: 1.0}

	MarketRateResolver.after_delivery(original, RECIPE_A)

	assert_float(float(original[RECIPE_A])).is_equal(1.0)


func test_ターン終了時に納品されなかったレシピの相場倍率が回復する() -> void:
	var delivered: Array[StringName] = []

	var rates := MarketRateResolver.recover_at_turn_end({RECIPE_A: 0.8}, delivered)

	assert_float(MarketRateResolver.get_rate(rates, RECIPE_A)).is_equal_approx(
		0.8 + GameBalance.MARKET_RECOVER_STEP, 0.0001
	)


func test_ターン終了時にそのターン納品したレシピは回復しない() -> void:
	var delivered: Array[StringName] = [RECIPE_A]

	var rates := MarketRateResolver.recover_at_turn_end({RECIPE_A: 0.8, RECIPE_B: 0.8}, delivered)

	assert_float(MarketRateResolver.get_rate(rates, RECIPE_A)).is_equal_approx(0.8, 0.0001)
	assert_float(MarketRateResolver.get_rate(rates, RECIPE_B)).is_equal_approx(
		0.8 + GameBalance.MARKET_RECOVER_STEP, 0.0001
	)


func test_recover_at_turn_endは引数の辞書を書き換えない() -> void:
	var original := {RECIPE_A: 0.8}
	var delivered: Array[StringName] = []

	MarketRateResolver.recover_at_turn_end(original, delivered)

	assert_float(float(original[RECIPE_A])).is_equal_approx(0.8, 0.0001)


# 異常系


func test_空の相場でターン終了しても空のまま() -> void:
	var delivered: Array[StringName] = [RECIPE_A]

	var rates := MarketRateResolver.recover_at_turn_end({}, delivered)

	assert_dict(rates).is_empty()


# 境界値


func test_相場倍率は下限より下がらない() -> void:
	var rates := {RECIPE_A: GameBalance.MARKET_RATE_MIN}

	rates = MarketRateResolver.after_delivery(rates, RECIPE_A)

	assert_float(MarketRateResolver.get_rate(rates, RECIPE_A)).is_equal_approx(
		GameBalance.MARKET_RATE_MIN, 0.0001
	)


func test_相場倍率は上限より上がらない() -> void:
	var delivered: Array[StringName] = []

	var rates := MarketRateResolver.recover_at_turn_end(
		{RECIPE_A: GameBalance.MARKET_RATE_MAX}, delivered
	)

	assert_float(MarketRateResolver.get_rate(rates, RECIPE_A)).is_equal_approx(
		GameBalance.MARKET_RATE_MAX, 0.0001
	)


func test_休ませ続けると相場倍率は既定値を超えて上限まで上がる() -> void:
	var delivered: Array[StringName] = []
	var rates := {RECIPE_A: GameBalance.MARKET_RATE_DEFAULT}

	for i in range(100):
		rates = MarketRateResolver.recover_at_turn_end(rates, delivered)

	assert_float(MarketRateResolver.get_rate(rates, RECIPE_A)).is_equal_approx(
		GameBalance.MARKET_RATE_MAX, 0.0001
	)


func test_天井回数ぶん連続納品すると下限付近まで下がる() -> void:
	var rates := {}

	for i in range(5):
		rates = MarketRateResolver.after_delivery(rates, RECIPE_A)

	assert_float(MarketRateResolver.get_rate(rates, RECIPE_A)).is_equal_approx(
		GameBalance.MARKET_RATE_MIN, 0.0001
	)
