extends GdUnitTestSuite


func _make_order(
	id: String, condition_type: String, target_recipe_id: String = "", target_trait: String = ""
) -> DailyOrderMaster:
	var order := DailyOrderMaster.new()
	order.id = id
	order.condition_type = condition_type
	order.target_recipe_id = target_recipe_id
	order.target_trait = target_trait
	return order


# 正常系: 解禁済みレシピを対象とするitemエントリは絞り込み結果に残る
func test_解禁済みレシピのアイテム条件は絞り込み結果に含まれる() -> void:
	var orders: Array[DailyOrderMaster] = [_make_order("o1", "item", "healing_potion")]
	var unlocked: Array[StringName] = [&"healing_potion"]

	var result := DailyOrderSelector.filter_achievable(orders, unlocked, false)

	assert_int(result.size()).is_equal(1)
	assert_str(result[0].id).is_equal("o1")


# 正常系: 特性解禁済みならtraitエントリは絞り込み結果に残る
func test_特性解禁済みなら特性条件は絞り込み結果に含まれる() -> void:
	var orders: Array[DailyOrderMaster] = [_make_order("o1", "trait", "", "gold")]
	var unlocked: Array[StringName] = [] as Array[StringName]

	var result := DailyOrderSelector.filter_achievable(orders, unlocked, true)

	assert_int(result.size()).is_equal(1)
	assert_str(result[0].id).is_equal("o1")


# 正常系: 未解禁レシピを対象とするitemエントリは除外される
func test_未解禁レシピのアイテム条件は絞り込み結果から除外される() -> void:
	var orders: Array[DailyOrderMaster] = [_make_order("o1", "item", "elixir")]
	var unlocked: Array[StringName] = [&"healing_potion"]

	var result := DailyOrderSelector.filter_achievable(orders, unlocked, true)

	assert_int(result.size()).is_equal(0)


# 正常系: 特性未解禁ならtraitエントリはすべて除外される
func test_特性未解禁なら特性条件はすべて除外される() -> void:
	var orders: Array[DailyOrderMaster] = [
		_make_order("o1", "trait", "", "gold"),
		_make_order("o2", "trait", "", "holy"),
		_make_order("o3", "item", "healing_potion"),
	]
	var unlocked: Array[StringName] = [&"healing_potion"]

	var result := DailyOrderSelector.filter_achievable(orders, unlocked, false)

	assert_int(result.size()).is_equal(1)
	assert_str(result[0].id).is_equal("o3")


# 異常系: 未知のcondition_typeは除外される
func test_未知の条件種別は絞り込み結果から除外される() -> void:
	var orders: Array[DailyOrderMaster] = [_make_order("o1", "unknown", "healing_potion", "gold")]
	var unlocked: Array[StringName] = [&"healing_potion"]

	var result := DailyOrderSelector.filter_achievable(orders, unlocked, true)

	assert_int(result.size()).is_equal(0)


# 異常系: ターゲットが空文字のエントリは除外される
func test_ターゲットが空文字のエントリは絞り込み結果から除外される() -> void:
	var orders: Array[DailyOrderMaster] = [
		_make_order("o1", "item", ""),
		_make_order("o2", "trait", "", ""),
	]
	var unlocked: Array[StringName] = [&""]

	var result := DailyOrderSelector.filter_achievable(orders, unlocked, true)

	assert_int(result.size()).is_equal(0)


# 境界値: 全件が空配列なら絞り込み結果も空配列
func test_依頼一覧が空なら絞り込み結果も空になる() -> void:
	var orders: Array[DailyOrderMaster] = [] as Array[DailyOrderMaster]
	var unlocked: Array[StringName] = [&"healing_potion"]

	var result := DailyOrderSelector.filter_achievable(orders, unlocked, true)

	assert_int(result.size()).is_equal(0)


# 境界値: 解禁済みレシピが空配列ならitemエントリはすべて除外される
func test_解禁済みレシピが空ならアイテム条件はすべて除外される() -> void:
	var orders: Array[DailyOrderMaster] = [
		_make_order("o1", "item", "healing_potion"),
		_make_order("o2", "item", "elixir"),
	]
	var unlocked: Array[StringName] = [] as Array[StringName]

	var result := DailyOrderSelector.filter_achievable(orders, unlocked, true)

	assert_int(result.size()).is_equal(0)


# 異常系: 絞り込みは引数の配列を書き換えない（副作用なし）
func test_絞り込みは引数の配列を書き換えない() -> void:
	var orders: Array[DailyOrderMaster] = [
		_make_order("o1", "item", "elixir"),
		_make_order("o2", "item", "healing_potion"),
	]
	var unlocked: Array[StringName] = [&"healing_potion"]

	DailyOrderSelector.filter_achievable(orders, unlocked, true)

	assert_int(orders.size()).is_equal(2)


# 正常系: 同一の乱数値では常に同一の結果が返る（決定性）
func test_同一の乱数値では同じ依頼が選出される() -> void:
	var pool: Array[DailyOrderMaster] = [
		_make_order("o1", "item", "a"),
		_make_order("o2", "item", "b"),
		_make_order("o3", "item", "c"),
	]

	var first := DailyOrderSelector.select(pool, 0.5)
	var second := DailyOrderSelector.select(pool, 0.5)

	assert_object(second).is_same(first)


# 正常系: 異なる乱数値ではプール内の異なる要素が選出されうる
func test_異なる乱数値では異なる依頼が選出されうる() -> void:
	var pool: Array[DailyOrderMaster] = [
		_make_order("o1", "item", "a"),
		_make_order("o2", "item", "b"),
		_make_order("o3", "item", "c"),
	]

	assert_str(DailyOrderSelector.select(pool, 0.0).id).is_equal("o1")
	assert_str(DailyOrderSelector.select(pool, 0.5).id).is_equal("o2")
	assert_str(DailyOrderSelector.select(pool, 0.9).id).is_equal("o3")


# 境界値: プールが空配列ならnullを返す
func test_プールが空なら選出結果はnullになる() -> void:
	var pool: Array[DailyOrderMaster] = [] as Array[DailyOrderMaster]

	assert_object(DailyOrderSelector.select(pool, 0.0)).is_null()
	assert_object(DailyOrderSelector.select(pool, 0.9999)).is_null()


# 境界値: プールが1件のみならどの乱数値でもその1件が返る
func test_プールが1件ならどの乱数値でもその1件が返る(
	random_value: float,
	_test_parameters := [
		[0.0],
		[0.5],
		[0.9999],
	]
) -> void:
	var pool: Array[DailyOrderMaster] = [_make_order("only", "item", "a")]

	assert_str(DailyOrderSelector.select(pool, random_value).id).is_equal("only")


# 境界値: 乱数値が理論上の境界でもプール外インデックスへアクセスしない
func test_乱数値が境界でもプール範囲外にアクセスしない() -> void:
	var pool: Array[DailyOrderMaster] = [
		_make_order("o1", "item", "a"),
		_make_order("o2", "item", "b"),
	]

	assert_str(DailyOrderSelector.select(pool, 0.0).id).is_equal("o1")
	assert_str(DailyOrderSelector.select(pool, 0.9999).id).is_equal("o2")
	# 契約外の値（1.0以上・負値）が渡ってもクランプされ範囲外アクセスしない
	assert_str(DailyOrderSelector.select(pool, 1.0).id).is_equal("o2")
	assert_str(DailyOrderSelector.select(pool, -0.1).id).is_equal("o1")
