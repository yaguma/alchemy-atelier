extends GdUnitTestSuite


func test_同一seedで5回のrandfが完全一致する() -> void:
	RngService.set_seed(12345)
	var seq1: Array[float] = []
	for i in range(5):
		seq1.append(RngService.randf())

	RngService.set_seed(12345)
	var seq2: Array[float] = []
	for i in range(5):
		seq2.append(RngService.randf())

	assert_array(seq1).is_equal(seq2)


func test_異なるseedでは乱数列が一致しない() -> void:
	RngService.set_seed(12345)
	var seq1: Array[float] = []
	for i in range(5):
		seq1.append(RngService.randf())

	RngService.set_seed(54321)
	var seq2: Array[float] = []
	for i in range(5):
		seq2.append(RngService.randf())

	assert_array(seq1).is_not_equal(seq2)


func test_seed_0でも例外を投げず動作する() -> void:
	RngService.set_seed(0)
	var value := RngService.randf()
	assert_float(value).is_between(0.0, 1.0)


func test_randf_rangeは指定範囲内の値を返す() -> void:
	RngService.set_seed(1)
	for i in range(20):
		var value := RngService.randf_range(2.0, 5.0)
		assert_float(value).is_between(2.0, 5.0)
