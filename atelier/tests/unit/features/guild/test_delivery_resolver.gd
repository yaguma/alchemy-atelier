extends GdUnitTestSuite


func _make_product(
	recipe_id: StringName,
	activated_traits: Array[StringName] = [] as Array[StringName],
	contribution: float = 10.0,
	reward: float = 5.0
) -> ProductInstance:
	return ProductInstance.new(recipe_id, 3, activated_traits, contribution, reward)


func _make_order(
	condition_type: String,
	target_recipe_id: String = "",
	target_trait: String = "",
	match_bonus_multiplier: float = 1.3
) -> DailyOrderMaster:
	var order := DailyOrderMaster.new()
	order.id = "order_test"
	order.condition_type = condition_type
	order.target_recipe_id = target_recipe_id
	order.target_trait = target_trait
	order.match_bonus_multiplier = match_bonus_multiplier
	return order


# 正常系: AC-001 condition_type="item"でレシピIDが一致する
func test_アイテム条件でレシピIDが一致すれば合致と判定される() -> void:
	var product := _make_product(&"healing_potion")
	var order := _make_order("item", "healing_potion")

	assert_bool(DeliveryResolver.matches_order(product, order)).is_true()


# 正常系: AC-001 condition_type="item"でレシピIDが一致しない
func test_アイテム条件でレシピIDが一致しなければ非合致と判定される() -> void:
	var product := _make_product(&"healing_potion")
	var order := _make_order("item", "elixir")

	assert_bool(DeliveryResolver.matches_order(product, order)).is_false()


# 正常系: AC-002 condition_type="trait"で対象特性を含む
func test_特性条件で対象特性を含めば合致と判定される() -> void:
	var traits: Array[StringName] = [&"holy", &"gold"]
	var product := _make_product(&"healing_potion", traits)
	var order := _make_order("trait", "", "gold")

	assert_bool(DeliveryResolver.matches_order(product, order)).is_true()


# 正常系: AC-002 condition_type="trait"で発現特性が空
func test_特性条件で発現特性が空なら非合致と判定される() -> void:
	var product := _make_product(&"healing_potion")
	var order := _make_order("trait", "", "gold")

	assert_bool(DeliveryResolver.matches_order(product, order)).is_false()


# 異常系: target_recipe_id未設定（既定値""）のitem条件は、recipe_idが空の調合物とも
# 誤って合致しないことを保証する（コードレビュー指摘: 不正なマスターデータ/フィクスチャ対策）
func test_アイテム条件でtarget_recipe_idが空なら非合致と判定される() -> void:
	var product := _make_product(&"")
	var order := _make_order("item", "")

	assert_bool(DeliveryResolver.matches_order(product, order)).is_false()


# 異常系: target_trait未設定（既定値""）のtrait条件は、活性特性が空の調合物とも
# 誤って合致しないことを保証する
func test_特性条件でtarget_traitが空なら非合致と判定される() -> void:
	var product := _make_product(&"healing_potion", [&""] as Array[StringName])
	var order := _make_order("trait", "", "")

	assert_bool(DeliveryResolver.matches_order(product, order)).is_false()


# 異常系: AC-003 daily_order=nullでも判定がクラッシュしない
func test_指定依頼がnullなら非合致と判定される() -> void:
	var product := _make_product(&"healing_potion")

	assert_bool(DeliveryResolver.matches_order(product, null)).is_false()


# 異常系: AC-003 daily_order=null時のresolveは倍率1.0のまま
func test_指定依頼がnullなら倍率を掛けずに解決される() -> void:
	var product := _make_product(&"healing_potion", [] as Array[StringName], 10.0, 5.0)

	var result := DeliveryResolver.resolve(product, null)

	assert_bool(result.order_matched).is_false()
	assert_float(result.final_contribution).is_equal_approx(10.0, 0.0001)
	assert_float(result.final_reward).is_equal_approx(5.0, 0.0001)


# 正常系: AC-004 合致時は指定合致ボーナスが貢献度と報酬の双方に適用される
func test_合致時は指定合致ボーナスが貢献度と報酬に適用される() -> void:
	var product := _make_product(&"healing_potion", [] as Array[StringName], 10.0, 5.0)
	var order := _make_order("item", "healing_potion", "", 1.3)

	var result := DeliveryResolver.resolve(product, order)

	assert_bool(result.order_matched).is_true()
	assert_float(result.final_contribution).is_equal_approx(13.0, 0.0001)
	assert_float(result.final_reward).is_equal_approx(6.5, 0.0001)


# 境界値: AC-004/CON-006 倍率はGameBalance定数ではなくインスタンス値を使う
func test_倍率はマスターデータのインスタンス値が使われる() -> void:
	var product := _make_product(&"healing_potion", [] as Array[StringName], 10.0, 5.0)
	var order := _make_order("item", "healing_potion", "", 1.5)

	var result := DeliveryResolver.resolve(product, order)

	assert_float(result.final_contribution).is_equal_approx(15.0, 0.0001)
	assert_float(result.final_reward).is_equal_approx(7.5, 0.0001)


# 正常系: AC-005 非合致時は元の値のまま変化しない
func test_非合致時は貢献度と報酬が元の値のまま維持される() -> void:
	var product := _make_product(&"healing_potion", [] as Array[StringName], 10.0, 5.0)
	var order := _make_order("item", "elixir", "", 1.3)

	var result := DeliveryResolver.resolve(product, order)

	assert_bool(result.order_matched).is_false()
	assert_float(result.final_contribution).is_equal_approx(10.0, 0.0001)
	assert_float(result.final_reward).is_equal_approx(5.0, 0.0001)


# 境界値: AC-004 貢献度と報酬がゼロでも乗算結果はゼロのまま破綻しない
func test_貢献度と報酬がゼロなら合致してもゼロのままである() -> void:
	var product := _make_product(&"healing_potion", [] as Array[StringName], 0.0, 0.0)
	var order := _make_order("item", "healing_potion", "", 1.3)

	var result := DeliveryResolver.resolve(product, order)

	assert_bool(result.order_matched).is_true()
	assert_float(result.final_contribution).is_equal_approx(0.0, 0.0001)
	assert_float(result.final_reward).is_equal_approx(0.0, 0.0001)


# 異常系: AC-007/NFR-101 未知のcondition_typeでもクラッシュせず非合致を返す
func test_未知の条件種別なら非合致と判定される() -> void:
	var traits: Array[StringName] = [&"gold"]
	var product := _make_product(&"healing_potion", traits)
	var order := _make_order("unknown", "healing_potion", "gold", 1.3)

	assert_bool(DeliveryResolver.matches_order(product, order)).is_false()

	var result := DeliveryResolver.resolve(product, order)

	assert_bool(result.order_matched).is_false()
	assert_float(result.final_contribution).is_equal_approx(10.0, 0.0001)
	assert_float(result.final_reward).is_equal_approx(5.0, 0.0001)


# 異常系: AC-013 純粋関数として同一引数では常に同じ結果を返す
func test_同一引数で複数回呼び出しても同じ結果を返す() -> void:
	var product := _make_product(&"healing_potion", [] as Array[StringName], 10.0, 5.0)
	var order := _make_order("item", "healing_potion", "", 1.3)

	var first := DeliveryResolver.resolve(product, order)
	var second := DeliveryResolver.resolve(product, order)

	assert_bool(DeliveryResolver.matches_order(product, order)).is_equal(
		DeliveryResolver.matches_order(product, order)
	)
	assert_float(second.final_contribution).is_equal_approx(first.final_contribution, 0.0001)
	assert_float(second.final_reward).is_equal_approx(first.final_reward, 0.0001)
	assert_bool(second.order_matched).is_equal(first.order_matched)


# 異常系: AC-013 resolveは引数のProductInstanceを書き換えない（副作用なし）
func test_解決処理は引数の調合物インスタンスを書き換えない() -> void:
	var product := _make_product(&"healing_potion", [] as Array[StringName], 10.0, 5.0)
	var order := _make_order("item", "healing_potion", "", 1.3)

	DeliveryResolver.resolve(product, order)

	assert_float(product.contribution).is_equal_approx(10.0, 0.0001)
	assert_float(product.reward).is_equal_approx(5.0, 0.0001)
