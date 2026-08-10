extends GdUnitTestSuite


func test_okに値を渡すとsuccessがtrueでvalueに格納される() -> void:
	var result := Result.ok(42)
	assert_bool(result.success).is_true()
	assert_that(result.value).is_equal(42)


func test_ok引数省略でvalueがnullになる() -> void:
	var result := Result.ok()
	assert_bool(result.success).is_true()
	assert_that(result.value).is_null()


func test_failでsuccessがfalseかつerror_codeが設定される() -> void:
	var result := Result.fail(&"slot_full")
	assert_bool(result.success).is_false()
	assert_that(result.error_code).is_equal(&"slot_full")


func test_failのvalueはnullのままである() -> void:
	var result := Result.fail(&"slot_full")
	assert_that(result.value).is_null()
