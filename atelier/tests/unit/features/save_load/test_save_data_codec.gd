extends GdUnitTestSuite


# 正常系
func test_同じ内容のDictionaryからは同じチェックサムが返る() -> void:
	var data := {"gold": 100, "turn": 3}

	var first := SaveDataCodec.calculate_checksum(data)
	var second := SaveDataCodec.calculate_checksum(data)

	assert_str(first).is_equal(second)


# 正常系
func test_チェックサムは64桁の16進文字列を返す() -> void:
	var checksum := SaveDataCodec.calculate_checksum({"gold": 100})

	assert_int(checksum.length()).is_equal(64)
	assert_bool(checksum.is_valid_hex_number()).is_true()


# 異常系
func test_内容が異なるDictionaryでは異なるチェックサムが返る() -> void:
	var original := SaveDataCodec.calculate_checksum({"gold": 100, "turn": 3})
	var modified := SaveDataCodec.calculate_checksum({"gold": 101, "turn": 3})

	assert_str(original).is_not_equal(modified)


# 境界値
func test_空のDictionaryでもチェックサムを計算できる() -> void:
	var checksum := SaveDataCodec.calculate_checksum({})

	assert_int(checksum.length()).is_equal(64)


# 正常系
func test_dataとchecksumを持つDictionaryにラップする() -> void:
	var data := {"gold": 100}

	var wrapped := SaveDataCodec.wrap_with_checksum(data)

	assert_dict(wrapped).contains_key_value("data", data)
	assert_dict(wrapped).contains_key_value("checksum", SaveDataCodec.calculate_checksum(data))


# 境界値
func test_空のDictionaryもラップできる() -> void:
	var wrapped := SaveDataCodec.wrap_with_checksum({})

	assert_dict(wrapped).contains_key_value("data", {})
	assert_dict(wrapped).contains_key_value("checksum", SaveDataCodec.calculate_checksum({}))


# 異常系
func test_ラップ後のチェックサムは元データの改変を検出できる() -> void:
	var wrapped := SaveDataCodec.wrap_with_checksum({"gold": 100})

	var tampered_checksum := SaveDataCodec.calculate_checksum({"gold": 999})

	assert_str(wrapped["checksum"]).is_not_equal(tampered_checksum)


# 正常系
func test_正当なラップ済みデータからdataをそのまま取り出せる() -> void:
	var data := _make_valid_save_data()
	var wrapped := SaveDataCodec.wrap_with_checksum(data)

	var result := SaveDataCodec.validate_and_unwrap(wrapped)

	assert_dict(result).is_equal(data)


# 異常系
func test_Dictionary以外を渡すと空Dictionaryが返る(
	raw: Variant,
	_test_parameters := [
		[[]],
		["not a dictionary"],
		[null],
		[42],
	]
) -> void:
	assert_dict(SaveDataCodec.validate_and_unwrap(raw)).is_empty()


# 異常系
func test_dataキーが存在しない場合は空Dictionaryが返る() -> void:
	var wrapped := {"checksum": SaveDataCodec.calculate_checksum(_make_valid_save_data())}

	assert_dict(SaveDataCodec.validate_and_unwrap(wrapped)).is_empty()


# 異常系
func test_dataキーがDictionaryでない場合は空Dictionaryが返る() -> void:
	var wrapped := {"data": [], "checksum": SaveDataCodec.calculate_checksum({})}

	assert_dict(SaveDataCodec.validate_and_unwrap(wrapped)).is_empty()


# 異常系
func test_checksumが1文字改変されている場合は空Dictionaryが返る() -> void:
	var wrapped := SaveDataCodec.wrap_with_checksum(_make_valid_save_data())
	var original_checksum: String = wrapped["checksum"]
	var head := "0" if original_checksum.substr(0, 1) != "0" else "1"
	wrapped["checksum"] = head + original_checksum.substr(1)

	assert_dict(SaveDataCodec.validate_and_unwrap(wrapped)).is_empty()


# 異常系
func test_checksumがStringでない場合は空Dictionaryが返る() -> void:
	var wrapped := {"data": _make_valid_save_data(), "checksum": 12345}

	assert_dict(SaveDataCodec.validate_and_unwrap(wrapped)).is_empty()


# 異常系
func test_必須キーが欠落している場合は空Dictionaryが返る() -> void:
	var data := _make_valid_save_data()
	data.erase("gold")
	var wrapped := SaveDataCodec.wrap_with_checksum(data)

	assert_dict(SaveDataCodec.validate_and_unwrap(wrapped)).is_empty()


# 異常系
func test_必須キーの型が不一致の場合は空Dictionaryが返る() -> void:
	var data := _make_valid_save_data()
	data["gold"] = "100"
	var wrapped := SaveDataCodec.wrap_with_checksum(data)

	assert_dict(SaveDataCodec.validate_and_unwrap(wrapped)).is_empty()


# 境界値
func test_JSONパース由来のfloat数値でも正当と判定される() -> void:
	var data := _make_valid_save_data()
	data["gold"] = 100.0
	data["current_turn"] = 3.0
	data["saved_at_unix"] = 1756771200.0
	var wrapped := SaveDataCodec.wrap_with_checksum(data)

	var result := SaveDataCodec.validate_and_unwrap(wrapped)

	assert_dict(result).is_equal(data)


## 全必須キーを満たす最小限のセーブデータを生成する（テスト用フィクスチャ）。
func _make_valid_save_data() -> Dictionary:
	return {
		"current_phase": "garden",
		"gold": 100,
		"current_turn": 3,
		"garden_state": {},
		"seed_inventory": [],
		"inventory": [],
		"material_instance_seq": 0,
		"garden_slot_count": 4,
		"unlocked_recipe_ids": [],
		"pending_products": [],
		"alchemy_slot_count": 4,
		"current_daily_order_id": "",
		"current_rank_id": "G",
		"demotion_count": 0,
		"rank_state": {},
		"rank_state_initialized": true,
		"last_rank_outcome": 0,
		"in_exam": false,
		"exam_state": {},
		"last_exam_outcome": 0,
		"has_cleared_game": false,
		"can_purchase_permanent": false,
		"purchased_upgrade_counts": {},
		"saved_at_unix": 1756771200,
	}
