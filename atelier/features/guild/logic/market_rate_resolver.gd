# 🔵 需要相場（レシピごとの納品価値の倍率）を扱う純粋関数群（core-systems.md「v7.1追加システム」、FR-712）。
# 副作用・乱数・GameState参照を持たない。相場はrecipe_id(StringName) -> float のDictionaryで表し、
# 更新系は引数を書き換えず新しいDictionaryを返す。
class_name MarketRateResolver


## 🔵 未登録のレシピは既定値（等倍）を返す（FR-712-001）
static func get_rate(market_rates: Dictionary, recipe_id: StringName) -> float:
	return float(market_rates.get(recipe_id, GameBalance.MARKET_RATE_DEFAULT))


## 🔵 納品後の相場を返す。納品したレシピの倍率を下落幅だけ下げ、下限でクランプする（FR-712-003）
static func after_delivery(market_rates: Dictionary, recipe_id: StringName) -> Dictionary:
	var updated := market_rates.duplicate()
	updated[recipe_id] = maxf(
		GameBalance.MARKET_RATE_MIN,
		get_rate(market_rates, recipe_id) - GameBalance.MARKET_DROP_STEP
	)
	return updated


## 🔵 ターン終了時の相場を返す。そのターンに納品されなかった登録済みレシピの倍率を回復幅だけ上げ、
## 上限でクランプする（FR-712-004）。
## 🟡 一度も納品していないレシピは未登録のまま等倍に留める（登録済みのみを回復対象とする）
static func recover_at_turn_end(
	market_rates: Dictionary, delivered_recipe_ids: Array[StringName]
) -> Dictionary:
	var updated := market_rates.duplicate()
	for recipe_id in market_rates:
		if delivered_recipe_ids.has(recipe_id):
			continue
		updated[recipe_id] = minf(
			GameBalance.MARKET_RATE_MAX,
			float(market_rates[recipe_id]) + GameBalance.MARKET_RECOVER_STEP
		)
	return updated
