extends GdUnitTestSuite

const GuildDeliveryResultRowScene = preload(
	"res://features/guild/ui/guild_delivery_result_row.tscn"
)


func _make_row() -> GuildDeliveryResultRow:
	var row: GuildDeliveryResultRow = auto_free(GuildDeliveryResultRowScene.instantiate())
	add_child(row)
	return row


func _find_label(row: GuildDeliveryResultRow, node_name: String) -> Label:
	return row.find_child(node_name, true, false) as Label


# 正常系


func test_setupで名称と品質と特性と貢献度と報酬が表示に反映される() -> void:
	var row := _make_row()
	var traits: Array[StringName] = [&"holy"]

	row.setup("回復薬", 4, traits, true, 12.5, 30.0)

	assert_str(_find_label(row, "DeliveryNameLabel").text).is_equal("回復薬")
	assert_str(_find_label(row, "DeliveryQualityLabel").text).contains("4")
	assert_str(_find_label(row, "DeliveryTraitsLabel").text).contains("holy")
	var value_text := _find_label(row, "DeliveryValueLabel").text
	assert_str(value_text).contains("12.5")
	assert_str(value_text).contains("30.0")


func test_order_matchedがtrueのとき指定合致ラベルが表示される() -> void:
	var row := _make_row()
	var traits: Array[StringName] = [&"holy"]

	row.setup("回復薬", 4, traits, true, 12.5, 30.0)

	var order_label := _find_label(row, "DeliveryOrderMatchLabel")
	assert_bool(order_label.visible).is_true()
	assert_str(order_label.text).is_equal(GuildDeliveryResultRow.ORDER_MATCHED_TEXT)


func test_order_matchedがfalseのとき指定合致ラベルが非表示になる() -> void:
	var row := _make_row()
	var traits: Array[StringName] = [&"holy"]

	row.setup("回復薬", 4, traits, false, 12.5, 30.0)

	assert_bool(_find_label(row, "DeliveryOrderMatchLabel").visible).is_false()


func test_複数の発現特性がすべて表示される() -> void:
	var row := _make_row()
	var traits: Array[StringName] = [&"holy", &"golden"]

	row.setup("聖水", 5, traits, false, 40.0, 55.0)

	var traits_text := _find_label(row, "DeliveryTraitsLabel").text
	assert_str(traits_text).contains("holy")
	assert_str(traits_text).contains("golden")


func test_format_valueが貢献度と報酬の両方を含む() -> void:
	var text := GuildDeliveryResultRow.format_value(12.5, 30.0)

	assert_str(text).contains("12.5")
	assert_str(text).contains("30.0")
	assert_str(text).contains("貢献度")
	assert_str(text).contains("報酬")


func test_format_valueは見込み表記を含まない() -> void:
	var text := GuildDeliveryResultRow.format_value(12.5, 30.0)

	assert_str(text).not_contains("見込み")


func test_format_qualityが品質スコアを含む() -> void:
	assert_str(GuildDeliveryResultRow.format_quality(3)).contains("3")


func test_format_traitsが全タグを区切り文字で連結する() -> void:
	var traits: Array[StringName] = [&"holy", &"golden"]

	var text := GuildDeliveryResultRow.format_traits(traits)

	assert_str(text).contains("holy" + GuildDeliveryResultRow.TRAIT_SEPARATOR + "golden")


# 異常系


func test_setupを再実行すると前回の表示内容が残らない() -> void:
	var row := _make_row()
	var traits: Array[StringName] = [&"holy"]
	row.setup("回復薬", 4, traits, true, 12.5, 30.0)

	var no_traits: Array[StringName] = []
	row.setup("鉄塊", 2, no_traits, false, 1.0, 2.0)

	assert_str(_find_label(row, "DeliveryNameLabel").text).is_equal("鉄塊")
	assert_str(_find_label(row, "DeliveryTraitsLabel").text).not_contains("holy")
	assert_str(_find_label(row, "DeliveryValueLabel").text).not_contains("12.5")
	assert_bool(_find_label(row, "DeliveryOrderMatchLabel").visible).is_false()


func test_調合物名が空文字でもクラッシュせず表示される() -> void:
	var row := _make_row()
	var no_traits: Array[StringName] = []

	row.setup("", 1, no_traits, false, 0.0, 0.0)

	assert_str(_find_label(row, "DeliveryNameLabel").text).is_empty()
	assert_str(_find_label(row, "DeliveryQualityLabel").text).contains("1")


# 境界値


func test_発現特性が空配列のとき特性なし表記になる() -> void:
	var row := _make_row()
	var no_traits: Array[StringName] = []

	row.setup("回復薬", 3, no_traits, false, 5.0, 6.0)

	assert_str(GuildDeliveryResultRow.format_traits(no_traits)).contains(
		GuildDeliveryResultRow.TRAITS_NONE_TEXT
	)
	assert_str(_find_label(row, "DeliveryTraitsLabel").text).contains(
		GuildDeliveryResultRow.TRAITS_NONE_TEXT
	)


func test_品質スコアの下限と上限が表示できる() -> void:
	var row := _make_row()
	var no_traits: Array[StringName] = []

	row.setup("回復薬", GameBalance.QUALITY_SCORE_MIN, no_traits, false, 0.0, 0.0)
	assert_str(_find_label(row, "DeliveryQualityLabel").text).contains(
		str(GameBalance.QUALITY_SCORE_MIN)
	)

	row.setup("回復薬", GameBalance.QUALITY_SCORE_MAX, no_traits, false, 0.0, 0.0)
	assert_str(_find_label(row, "DeliveryQualityLabel").text).contains(
		str(GameBalance.QUALITY_SCORE_MAX)
	)


func test_貢献度と報酬が0でも表示される() -> void:
	var row := _make_row()
	var no_traits: Array[StringName] = []

	row.setup("回復薬", 1, no_traits, false, 0.0, 0.0)

	assert_str(_find_label(row, "DeliveryValueLabel").text).contains("0.0")
