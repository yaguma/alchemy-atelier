extends GdUnitTestSuite

## 🔵 Issue #65（FR-712-006）。相場倍率の表示文字列を検証する。


func test_下落なら倍率と下向き矢印を含む() -> void:
	var text := MarketRateText.format(0.8)

	assert_str(text).contains("0.80")
	assert_str(text).contains(MarketRateText.DOWN_MARK)


func test_上昇なら上向き矢印を含む() -> void:
	assert_str(MarketRateText.format(1.1)).contains(MarketRateText.UP_MARK)


func test_等倍なら空文字を返す() -> void:
	assert_str(MarketRateText.format(GameBalance.MARKET_RATE_DEFAULT)).is_empty()


func test_浮動小数の誤差で等倍に近い値も空文字として扱う() -> void:
	assert_str(MarketRateText.format(0.9 + 0.1)).is_empty()
