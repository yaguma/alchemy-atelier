extends GdUnitTestSuite

## 🔵 Issue #70。v7.1新要素（鮮度・需要相場・熟練ひらめき）のパラメータが、balance-design.md
## 「v7.1の調整方針」の不変条件を満たしていることを検証する。値を調整した際に方針から外れたら落ちる。

const SIMULATED_TURNS := 24  # Sランクの制限ターン数と同程度の期間で平均を見る


## 毎ターン1件ずつ、recipe_ids を順番に巡回して納品したときの平均相場倍率
func _average_market_rate(recipe_ids: Array[StringName]) -> float:
	var rates := {}
	var total := 0.0
	for turn in range(SIMULATED_TURNS):
		var recipe_id := recipe_ids[turn % recipe_ids.size()]
		total += MarketRateResolver.get_rate(rates, recipe_id)
		rates = MarketRateResolver.after_delivery(rates, recipe_id)
		var delivered: Array[StringName] = [recipe_id]
		rates = MarketRateResolver.recover_at_turn_end(rates, delivered)
	return total / SIMULATED_TURNS


## 熟練度1回目から天井までのひらめき確率から、ひらめくまでの期待調合回数を求める
func _expected_crafts_to_inspire() -> float:
	var expected := 0.0
	var not_yet := 1.0
	for count in range(1, GameBalance.INSPIRATION_CEILING_COUNT + 1):
		var chance := InspirationResolver.chance_for(count)
		expected += count * not_yet * chance
		not_yet *= 1.0 - chance
	return expected


# 需要相場（FR-712）


func test_天井回数ぶん同じ品を連続納品しても相場は0_6から0_7に収まる() -> void:
	var rates := {}
	for i in range(GameBalance.INSPIRATION_CEILING_COUNT - 1):
		rates = MarketRateResolver.after_delivery(rates, &"recipe_a")

	var rate_at_ceiling := MarketRateResolver.get_rate(rates, &"recipe_a")

	assert_float(rate_at_ceiling).is_between(0.6 - 0.0001, 0.7 + 0.0001)


func test_同じ品だけを納め続けると相場は大きく下がる() -> void:
	var only_one: Array[StringName] = [&"recipe_a"]

	assert_float(_average_market_rate(only_one)).is_less(0.8)


func test_2品を交互に納めれば相場の罰はほぼ受けない() -> void:
	# 序盤は納品用レシピが2種程度しかないため、2品の交互納品が損にならない水準にする
	var two: Array[StringName] = [&"recipe_a", &"recipe_b"]

	assert_float(_average_market_rate(two)).is_greater_equal(0.95)


func test_3品以上を回すと休ませた品の価値が上がる() -> void:
	var three: Array[StringName] = [&"recipe_a", &"recipe_b", &"recipe_c"]

	assert_float(_average_market_rate(three)).is_greater(1.0)


func test_相場の下限は罰に感じさせない水準である() -> void:
	assert_float(GameBalance.MARKET_RATE_MIN).is_greater_equal(0.5)
	assert_float(GameBalance.MARKET_RATE_MAX).is_greater(GameBalance.MARKET_RATE_DEFAULT)


# 熟練ひらめき（FR-714）


func test_ひらめき確率は熟練度とともに単調に上がり天井で確定する() -> void:
	var previous := 0.0
	for count in range(1, GameBalance.INSPIRATION_CEILING_COUNT + 1):
		var chance := InspirationResolver.chance_for(count)
		assert_float(chance).is_greater_equal(previous)
		previous = chance
	assert_float(previous).is_equal(1.0)


func test_ひらめくまでの期待調合回数は1ランクで1から2回ひらめける範囲にある() -> void:
	# 1ランクで同じレシピを6〜12回程度調合する想定（制限ターン8〜24）。期待回数が3前後なら1〜2回ひらめく
	var expected := _expected_crafts_to_inspire()

	assert_float(expected).is_between(2.5, 4.0)


# 鮮度（FR-711）


func test_成熟直後に収穫した素材は劣化間隔の2倍のターンは腐らない() -> void:
	# balance-design.md「鮮度の圧の強さ」。品質qの素材は劣化間隔ごとに1段下がり、
	# 品質Dでもう一度劣化タイミングを迎えると腐るため、腐るまでのターン数は q × 劣化間隔
	var materials := MasterDataLoader.load_all(&"materials")
	var masters_by_id: Dictionary = {}
	for master in materials:
		if master is MaterialMaster:
			masters_by_id[(master as MaterialMaster).id] = master

	for master in materials:
		if not (master is SeedMaster):
			continue
		var seed: SeedMaster = master
		var produced: MaterialMaster = masters_by_id[seed.produces_material_id]
		var interval := produced.decay_interval_turns
		if interval <= 0:
			continue
		assert_int(seed.base_quality * interval).is_greater_equal(interval * 2)


func test_鉱石と中間素材と触媒は劣化しない() -> void:
	for master in MasterDataLoader.load_all(&"materials"):
		if not (master is MaterialMaster):
			continue
		var material_master: MaterialMaster = master
		var never_decays := (
			material_master.is_intermediate
			or material_master.shop_purchasable
			or material_master.id == &"material_ore"
		)
		if never_decays:
			assert_int(material_master.decay_interval_turns).is_equal(0)
