extends GdUnitTestSuite


func test_コンストラクタに渡した値がプロパティに設定される() -> void:
	var activated_traits: Array[StringName] = [&"holy"]

	var instance := ProductInstance.new(&"recipe_potion", 3, activated_traits, 12.5, 30.0)

	assert_that(instance.recipe_id).is_equal(&"recipe_potion")
	assert_int(instance.quality_score).is_equal(3)
	assert_that(instance.activated_traits).is_equal(activated_traits)
	assert_float(instance.contribution).is_equal(12.5)
	assert_float(instance.reward).is_equal(30.0)


func test_cloneで生成したインスタンスは値が等しいが別オブジェクトである() -> void:
	var activated_traits: Array[StringName] = [&"holy"]
	var original := ProductInstance.new(&"recipe_potion", 3, activated_traits, 12.5, 30.0)

	var cloned := original.clone()

	assert_bool(cloned == original).is_false()
	assert_that(cloned.recipe_id).is_equal(original.recipe_id)
	assert_int(cloned.quality_score).is_equal(original.quality_score)
	assert_that(cloned.activated_traits).is_equal(original.activated_traits)
	assert_float(cloned.contribution).is_equal(original.contribution)
	assert_float(cloned.reward).is_equal(original.reward)


func test_cloneしたactivated_traitsを変更しても元のインスタンスは変化しない() -> void:
	var activated_traits: Array[StringName] = [&"holy"]
	var original := ProductInstance.new(&"recipe_potion", 3, activated_traits, 12.5, 30.0)

	var cloned := original.clone()
	cloned.activated_traits.append(&"catalyst")

	assert_int(cloned.activated_traits.size()).is_equal(2)
	assert_int(original.activated_traits.size()).is_equal(1)


func test_空のactivated_traitsでもインスタンス生成とcloneができる() -> void:
	var empty_traits: Array[StringName] = []

	var instance := ProductInstance.new(&"recipe_potion", 1, empty_traits, 0.0, 0.0)
	var cloned := instance.clone()

	assert_int(instance.activated_traits.size()).is_equal(0)
	assert_int(cloned.activated_traits.size()).is_equal(0)


func test_コンストラクタに渡した配列を後から変更してもインスタンスは影響を受けない() -> void:
	var activated_traits: Array[StringName] = [&"holy"]
	var instance := ProductInstance.new(&"recipe_potion", 3, activated_traits, 12.5, 30.0)

	activated_traits.append(&"catalyst")

	assert_int(instance.activated_traits.size()).is_equal(1)


## 🔴 コードレビュー指摘対応（PR#42）。指定依頼の納品時ボーナスすり替わりバグの修正で追加した2フィールド
func test_daily_order_snapshotの既定値はnullでhas_daily_order_snapshotはfalse() -> void:
	var instance := ProductInstance.new(&"recipe_potion", 3, [] as Array[StringName], 12.5, 30.0)

	assert_object(instance.daily_order_snapshot).is_null()
	assert_bool(instance.has_daily_order_snapshot).is_false()


func test_cloneでhas_daily_order_snapshotとdaily_order_snapshotが複製される() -> void:
	var original := ProductInstance.new(&"recipe_potion", 3, [] as Array[StringName], 12.5, 30.0)
	var order := DailyOrderMaster.new()
	order.id = "order_test"
	order.match_bonus_multiplier = 1.3
	original.has_daily_order_snapshot = true
	original.daily_order_snapshot = order

	var cloned := original.clone()

	assert_bool(cloned.has_daily_order_snapshot).is_true()
	assert_object(cloned.daily_order_snapshot).is_not_null()
	assert_str(cloned.daily_order_snapshot.id).is_equal("order_test")
	# 参照ではなく複製された別オブジェクトであること（daily_order_master.gdのclone()契約と同様）
	assert_bool(cloned.daily_order_snapshot == order).is_false()


func test_daily_order_snapshotがnullのままcloneしてもnullを維持する() -> void:
	var original := ProductInstance.new(&"recipe_potion", 3, [] as Array[StringName], 12.5, 30.0)
	original.has_daily_order_snapshot = true

	var cloned := original.clone()

	assert_bool(cloned.has_daily_order_snapshot).is_true()
	assert_object(cloned.daily_order_snapshot).is_null()
