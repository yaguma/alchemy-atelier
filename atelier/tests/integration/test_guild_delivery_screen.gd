extends GdUnitTestSuite

const RECIPE_A: StringName = &"recipe_a"
const RECIPE_B: StringName = &"recipe_b"
const RECIPE_UNKNOWN: StringName = &"recipe_unknown"
const RANK_ID: StringName = &"rank_test"
const RANK_DISPLAY_NAME := "見習い"
const QUOTA_MAX := 100.0
const QUOTA_REMAINING := 40.0


func before_test() -> void:
	GameState.reset_for_test()
	var masters := {
		RECIPE_A: _make_recipe(RECIPE_A, "回復薬"),
		RECIPE_B: _make_recipe(RECIPE_B, "聖水"),
	}
	GameState._set_recipe_masters_for_test(masters)
	_set_rank(QUOTA_MAX, QUOTA_REMAINING)


func _make_recipe(id: StringName, recipe_name: String) -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = id
	recipe.name = recipe_name
	return recipe


func _set_rank(quota_max: float, quota: float) -> void:
	var rank := RankMaster.new()
	rank.id = String(RANK_ID)
	rank.display_name = RANK_DISPLAY_NAME
	rank.quota_max = quota_max
	GameState._set_rank_masters_for_test({RANK_ID: rank})
	GameState._set_current_rank_id_for_test(RANK_ID)
	var state := RankState.new()
	state.quota = quota
	GameState._set_rank_state_for_test(state)


func _make_product(
	recipe_id: StringName, quality: int, traits: Array[StringName] = []
) -> ProductInstance:
	return ProductInstance.new(recipe_id, quality, traits, 0.0, 0.0)


func _make_result(contribution: float, reward: float, matched: bool = false) -> DeliveryResult:
	return DeliveryResult.new(contribution, reward, matched)


func _make_screen() -> GuildDeliveryScreen:
	var runner := scene_runner("res://features/guild/ui/guild_delivery_screen.tscn")
	return runner.scene() as GuildDeliveryScreen


func _find_row(screen: GuildDeliveryScreen, index: int) -> GuildDeliveryResultRow:
	return screen.find_child("DeliveryEntry_%d" % index, true, false) as GuildDeliveryResultRow


func _row_label_text(row: GuildDeliveryResultRow, node_name: String) -> String:
	return (row.find_child(node_name, true, false) as Label).text


func _quota_bar(screen: GuildDeliveryScreen) -> ProgressBar:
	return screen.find_child("QuotaBar", true, false) as ProgressBar


func _label_text(screen: GuildDeliveryScreen, node_name: String) -> String:
	return (screen.find_child(node_name, true, false) as Label).text


# 正常系


func test_単一件の納品結果がリストに反映される() -> void:
	var screen := _make_screen()
	var traits: Array[StringName] = [&"holy"]
	var products: Array[ProductInstance] = [_make_product(RECIPE_A, 4, traits)]
	var results: Array[DeliveryResult] = [_make_result(12.5, 30.0, true)]

	screen.display_results(products, results)

	assert_int(screen.get_item_count()).is_equal(1)
	var row := _find_row(screen, 0)
	assert_object(row).is_not_null()
	assert_str(_row_label_text(row, "DeliveryNameLabel")).is_equal("回復薬")
	assert_str(_row_label_text(row, "DeliveryQualityLabel")).contains("4")
	assert_str(_row_label_text(row, "DeliveryTraitsLabel")).contains("holy")
	var value_text := _row_label_text(row, "DeliveryValueLabel")
	assert_str(value_text).contains("12.5")
	assert_str(value_text).contains("30.0")


func test_複数件の合計貢献度と合計報酬が総和になる() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [
		_make_product(RECIPE_A, 3),
		_make_product(RECIPE_B, 4),
		_make_product(RECIPE_A, 5),
	]
	var results: Array[DeliveryResult] = [
		_make_result(10.0, 5.0),
		_make_result(20.5, 7.5),
		_make_result(30.0, 12.0),
	]

	screen.display_results(products, results)

	assert_int(screen.get_item_count()).is_equal(3)
	assert_float(screen.get_total_contribution()).is_equal_approx(60.5, 0.001)
	assert_float(screen.get_total_reward()).is_equal_approx(24.5, 0.001)
	var total_text := _label_text(screen, "TotalLabel")
	assert_str(total_text).contains("60.5")
	assert_str(total_text).contains("24.5")


func test_指定合致の有無が項目ごとに表示に反映される() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [
		_make_product(RECIPE_A, 3),
		_make_product(RECIPE_B, 3),
	]
	var results: Array[DeliveryResult] = [
		_make_result(10.0, 5.0, true),
		_make_result(10.0, 5.0, false),
	]

	screen.display_results(products, results)

	var matched_label := (
		_find_row(screen, 0).find_child("DeliveryOrderMatchLabel", true, false) as Label
	)
	var unmatched_label := (
		_find_row(screen, 1).find_child("DeliveryOrderMatchLabel", true, false) as Label
	)
	assert_bool(matched_label.visible).is_true()
	assert_str(matched_label.text).is_equal(GuildDeliveryResultRow.ORDER_MATCHED_TEXT)
	assert_bool(unmatched_label.visible).is_false()


func test_productsとresultsがindexで対応して表示される() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [
		_make_product(RECIPE_A, 2),
		_make_product(RECIPE_B, 5),
	]
	var results: Array[DeliveryResult] = [
		_make_result(11.0, 3.0),
		_make_result(22.0, 6.0),
	]

	screen.display_results(products, results)

	var first := _find_row(screen, 0)
	var second := _find_row(screen, 1)
	assert_str(_row_label_text(first, "DeliveryNameLabel")).is_equal("回復薬")
	assert_str(_row_label_text(first, "DeliveryQualityLabel")).contains("2")
	assert_str(_row_label_text(first, "DeliveryValueLabel")).contains("11.0")
	assert_str(_row_label_text(second, "DeliveryNameLabel")).is_equal("聖水")
	assert_str(_row_label_text(second, "DeliveryQualityLabel")).contains("5")
	assert_str(_row_label_text(second, "DeliveryValueLabel")).contains("22.0")


func test_0件を渡すと件数と合計値がリセットされる() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [
		_make_product(RECIPE_A, 3),
		_make_product(RECIPE_B, 3),
	]
	var results: Array[DeliveryResult] = [
		_make_result(10.0, 5.0),
		_make_result(20.0, 6.0),
	]
	screen.display_results(products, results)

	screen.display_results([] as Array[ProductInstance], [] as Array[DeliveryResult])

	assert_int(screen.get_item_count()).is_equal(0)
	assert_float(screen.get_total_contribution()).is_equal(0.0)
	assert_float(screen.get_total_reward()).is_equal(0.0)
	assert_object(_find_row(screen, 0)).is_null()


func test_ランクノルマバーが現在ランクの残量と上限を反映する() -> void:
	var screen := _make_screen()

	screen.display_results([] as Array[ProductInstance], [] as Array[DeliveryResult])

	var bar := _quota_bar(screen)
	assert_float(bar.max_value).is_equal(QUOTA_MAX)
	assert_float(bar.value).is_equal(QUOTA_REMAINING)
	assert_str(_label_text(screen, "RankNameLabel")).is_equal(RANK_DISPLAY_NAME)


func test_readyの時点でランクノルマバーが初期化される() -> void:
	var screen := _make_screen()

	assert_float(_quota_bar(screen).value).is_equal(QUOTA_REMAINING)
	assert_str(_label_text(screen, "RankNameLabel")).is_equal(RANK_DISPLAY_NAME)


func test_続けるボタン押下でscreen_closedが発行される() -> void:
	var screen := _make_screen()
	monitor_signals(screen, false)

	(screen.find_child("ContinueButton", true, false) as Button).pressed.emit()

	await assert_signal(screen).is_emitted("screen_closed")


# 異常系


func test_未登録のrecipe_idはフォールバック文言で表示される() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [_make_product(RECIPE_UNKNOWN, 3)]
	var results: Array[DeliveryResult] = [_make_result(10.0, 5.0)]

	screen.display_results(products, results)

	assert_int(screen.get_item_count()).is_equal(1)
	assert_str(_row_label_text(_find_row(screen, 0), "DeliveryNameLabel")).is_equal(
		GuildDeliveryScreen.UNKNOWN_RECIPE_NAME
	)


func test_ランクマスター未ロードでもノルマバーが空表示になる() -> void:
	GameState._set_rank_masters_for_test({})
	GameState._set_current_rank_id_for_test(&"rank_missing")
	var screen := _make_screen()

	screen.display_results([] as Array[ProductInstance], [] as Array[DeliveryResult])

	var bar := _quota_bar(screen)
	assert_float(bar.value).is_equal(0.0)
	assert_float(bar.ratio).is_equal(0.0)
	assert_bool(bar.max_value > 0.0).is_true()


# 境界値


func test_発現特性が0件のときプレースホルダーが表示される() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [_make_product(RECIPE_A, 3)]
	var results: Array[DeliveryResult] = [_make_result(10.0, 5.0)]

	screen.display_results(products, results)

	assert_str(_row_label_text(_find_row(screen, 0), "DeliveryTraitsLabel")).contains(
		GuildDeliveryResultRow.TRAITS_NONE_TEXT
	)


func test_resultsがproductsより短い場合は短い方に合わせる() -> void:
	var screen := _make_screen()
	var products: Array[ProductInstance] = [
		_make_product(RECIPE_A, 3),
		_make_product(RECIPE_B, 3),
	]
	var results: Array[DeliveryResult] = [_make_result(10.0, 5.0)]

	screen.display_results(products, results)

	assert_int(screen.get_item_count()).is_equal(1)
	assert_float(screen.get_total_contribution()).is_equal(10.0)


func test_ノルマ残量が上限を超えていてもバーが上限でクランプされる() -> void:
	_set_rank(50.0, 80.0)
	var screen := _make_screen()

	assert_float(_quota_bar(screen).value).is_equal(50.0)


# 🔴 コードレビュー指摘対応。昇格試験中はGameStateGuildDelegate.deliver_pending_products()が
# 貢献度をExamState.exam_quotaへ加算するため、ノルマバーも試験ノルマを参照する必要がある
func test_昇格試験中はノルマバーが試験ノルマを反映する() -> void:
	var exam_state := ExamState.new()
	exam_state.exam_quota = 15.0
	exam_state.exam_quota_max = 60.0
	GameState._set_exam_state_for_test(exam_state, true)
	var screen := _make_screen()

	screen.display_results([] as Array[ProductInstance], [] as Array[DeliveryResult])

	var bar := _quota_bar(screen)
	assert_float(bar.max_value).is_equal(60.0)
	assert_float(bar.value).is_equal(15.0)
	assert_str(_label_text(screen, "RankNameLabel")).is_equal(
		RANK_DISPLAY_NAME + GuildDeliveryScreen.EXAM_RANK_LABEL_SUFFIX
	)


func test_昇格試験中の通常ランクノルマ変化はノルマバーへ反映されない() -> void:
	var exam_state := ExamState.new()
	exam_state.exam_quota = 15.0
	exam_state.exam_quota_max = 60.0
	GameState._set_exam_state_for_test(exam_state, true)
	var screen := _make_screen()

	_set_rank(QUOTA_MAX, 90.0)
	screen.display_results([] as Array[ProductInstance], [] as Array[DeliveryResult])

	assert_float(_quota_bar(screen).value).is_equal(15.0)
