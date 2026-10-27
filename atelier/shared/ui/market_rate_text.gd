class_name MarketRateText

## 🔵 Issue #65（FR-712-006）。需要相場の倍率を画面表示用の文字列にする。
## 調合画面（レシピ選択）とギルド納品画面（結果行）の両方で同じ表記を使うため、
## 他Featureのui/を参照せずに済むようshared/ui/に置く。

const TEXT_FORMAT := "相場x%.2f%s"  # 🟡 ui-design未確定の暫定表記
const UP_MARK := "↑"
const DOWN_MARK := "↓"


## 等倍なら空文字を返す（相場が動いた品だけを目立たせる）
static func format(market_multiplier: float) -> String:
	if is_equal_approx(market_multiplier, GameBalance.MARKET_RATE_DEFAULT):
		return ""
	var mark := UP_MARK if market_multiplier > GameBalance.MARKET_RATE_DEFAULT else DOWN_MARK
	return TEXT_FORMAT % [market_multiplier, mark]
