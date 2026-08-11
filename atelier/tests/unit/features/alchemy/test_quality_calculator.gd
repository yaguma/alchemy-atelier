extends GdUnitTestSuite


func _make_material(quality_score: int, trait_tags: Array[StringName] = []) -> MaterialInstance:
	return MaterialInstance.new("mat_test", &"material_herb", quality_score, trait_tags)


func _make_materials(quality_scores: Array[int]) -> Array[MaterialInstance]:
	var materials: Array[MaterialInstance] = []
	for score in quality_scores:
		materials.append(_make_material(score))
	return materials


# 正常系
func test_割り切れる平均品質をそのまま返す() -> void:
	var materials := _make_materials([3, 3])

	assert_int(QualityCalculator.calculate_quality(materials, false)).is_equal(3)


# 正常系
func test_平均が5割の端数なら切り上げる() -> void:
	var materials := _make_materials([3, 4])

	assert_int(QualityCalculator.calculate_quality(materials, false)).is_equal(4)


# 境界値
func test_平均2点5は3に丸められる() -> void:
	var materials := _make_materials([2, 3])

	assert_int(QualityCalculator.calculate_quality(materials, false)).is_equal(3)


# 境界値
func test_平均2点33は2に丸められる() -> void:
	var materials := _make_materials([2, 2, 3])

	assert_int(QualityCalculator.calculate_quality(materials, false)).is_equal(2)


# 正常系
func test_特性解放済みで触媒素材を含むと品質が1加算される() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(3, [&"catalyst"]),
		_make_material(3),
	]

	assert_int(QualityCalculator.calculate_quality(materials, true)).is_equal(4)


# 境界値
func test_四捨五入後が上限のとき触媒があっても上限のままである() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(5, [&"catalyst"]),
		_make_material(5),
	]

	assert_int(QualityCalculator.calculate_quality(materials, true)).is_equal(
		GameBalance.QUALITY_SCORE_MAX
	)


# 異常系
func test_特性未解放なら触媒素材を含んでもボーナスが適用されない() -> void:
	var materials: Array[MaterialInstance] = [
		_make_material(3, [&"catalyst"]),
		_make_material(3),
	]

	assert_int(QualityCalculator.calculate_quality(materials, false)).is_equal(3)


# 異常系
func test_素材が空配列なら品質下限を返す() -> void:
	var materials: Array[MaterialInstance] = []

	assert_int(QualityCalculator.calculate_quality(materials, true)).is_equal(
		GameBalance.QUALITY_SCORE_MIN
	)


# 正常系
func test_品質スコアに対応する倍率を返す() -> void:
	assert_float(QualityCalculator.quality_multiplier(3)).is_equal(
		GameBalance.QUALITY_MULTIPLIER_TABLE[3]
	)


# 境界値
func test_品質下限と上限の倍率を返す() -> void:
	assert_float(QualityCalculator.quality_multiplier(GameBalance.QUALITY_SCORE_MIN)).is_equal(
		GameBalance.QUALITY_MULTIPLIER_TABLE[GameBalance.QUALITY_SCORE_MIN]
	)
	assert_float(QualityCalculator.quality_multiplier(GameBalance.QUALITY_SCORE_MAX)).is_equal(
		GameBalance.QUALITY_MULTIPLIER_TABLE[GameBalance.QUALITY_SCORE_MAX]
	)


# 異常系
func test_範囲外の品質スコアは下限上限の倍率にクランプされる() -> void:
	assert_float(QualityCalculator.quality_multiplier(0)).is_equal(
		GameBalance.QUALITY_MULTIPLIER_TABLE[GameBalance.QUALITY_SCORE_MIN]
	)
	assert_float(QualityCalculator.quality_multiplier(99)).is_equal(
		GameBalance.QUALITY_MULTIPLIER_TABLE[GameBalance.QUALITY_SCORE_MAX]
	)
