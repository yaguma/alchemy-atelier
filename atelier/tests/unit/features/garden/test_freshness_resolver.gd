extends GdUnitTestSuite


func _make_material(quality: int, elapsed: int = 0) -> MaterialInstance:
	var material := MaterialInstance.new("mat_0001", &"material_herb", quality, [&"holy"])
	material.freshness_elapsed_turns = elapsed
	return material


# 正常系


# 🔵 PR #72レビュー指摘対応。在庫一覧の「腐敗まで」表記の判定に使う
func test_品質2以上の素材は次の劣化で腐敗しない() -> void:
	assert_bool(FreshnessResolver.rots_at_next_decay(_make_material(2))).is_false()


# 境界値
func test_品質1の素材は次の劣化で腐敗する() -> void:
	assert_bool(FreshnessResolver.rots_at_next_decay(_make_material(1))).is_true()


# 🔵 rots_at_next_decayとage_materialの判定が一致することを固定する（UI表示と実処理の乖離防止）
func test_rots_at_next_decayが真の素材はage_materialの劣化タイミングで腐敗する() -> void:
	var material := _make_material(1, 1)

	var aged := FreshnessResolver.age_material(material, 2)

	assert_bool(FreshnessResolver.rots_at_next_decay(material)).is_true()
	assert_bool(aged.is_rotten).is_true()


func test_age_materialで鮮度経過ターンが1加算された新しいインスタンスが返る() -> void:
	var material := _make_material(3, 0)

	var aged := FreshnessResolver.age_material(material, 2)

	assert_int(aged.freshness_elapsed_turns).is_equal(1)
	assert_int(material.freshness_elapsed_turns).is_equal(0)


func test_劣化間隔の倍数に達すると品質が1段下がる() -> void:
	var material := _make_material(3, 1)

	var aged := FreshnessResolver.age_material(material, 2)

	assert_int(aged.quality_score).is_equal(2)
	assert_bool(aged.is_rotten).is_false()


func test_劣化間隔の倍数でなければ品質は変わらない() -> void:
	var material := _make_material(3, 0)

	var aged := FreshnessResolver.age_material(material, 2)

	assert_int(aged.quality_score).is_equal(3)


func test_age_materialはinstance_idとmaterial_idとtrait_tagsを引き継ぐ() -> void:
	var material := _make_material(3, 0)

	var aged := FreshnessResolver.age_material(material, 2)

	assert_str(aged.instance_id).is_equal("mat_0001")
	assert_str(String(aged.material_id)).is_equal("material_herb")
	assert_array(aged.trait_tags).contains_exactly([&"holy"])


func test_劣化間隔2の品質C素材は2ターンでD_4ターンで腐敗する() -> void:
	var material := _make_material(2, 0)

	for i in range(2):
		material = FreshnessResolver.age_material(material, 2)
	assert_int(material.quality_score).is_equal(1)
	assert_bool(material.is_rotten).is_false()

	for i in range(2):
		material = FreshnessResolver.age_material(material, 2)
	assert_bool(material.is_rotten).is_true()


func test_turns_until_next_decayは次の劣化までの残りターンを返す() -> void:
	var material := _make_material(3, 1)

	assert_int(FreshnessResolver.turns_until_next_decay(material, 3)).is_equal(2)


# 異常系


func test_劣化間隔0の素材は経過ターンだけ進み品質は変わらない() -> void:
	var material := _make_material(3, 9)

	var aged := FreshnessResolver.age_material(material, 0)

	assert_int(aged.freshness_elapsed_turns).is_equal(10)
	assert_int(aged.quality_score).is_equal(3)
	assert_bool(aged.is_rotten).is_false()


func test_劣化間隔が負の素材も劣化しない() -> void:
	var material := _make_material(1, 0)

	var aged := FreshnessResolver.age_material(material, -1)

	assert_int(aged.quality_score).is_equal(1)
	assert_bool(aged.is_rotten).is_false()


func test_劣化しない素材のturns_until_next_decayはマイナス1を返す() -> void:
	var material := _make_material(3, 0)

	assert_int(FreshnessResolver.turns_until_next_decay(material, 0)).is_equal(-1)


# 境界値


func test_品質Dの素材が劣化タイミングを迎えると品質は下がらず腐敗する() -> void:
	var material := _make_material(1, 1)

	var aged := FreshnessResolver.age_material(material, 2)

	assert_int(aged.quality_score).is_equal(1)
	assert_bool(aged.is_rotten).is_true()


func test_劣化間隔1なら毎ターン品質が下がる() -> void:
	var material := _make_material(5, 0)

	var aged := FreshnessResolver.age_material(material, 1)

	assert_int(aged.quality_score).is_equal(4)


func test_劣化直後のturns_until_next_decayは劣化間隔と等しい() -> void:
	var material := _make_material(3, 2)

	assert_int(FreshnessResolver.turns_until_next_decay(material, 2)).is_equal(2)


func test_decay_interval_ofは素材マスターの劣化間隔を返す() -> void:
	var master := MaterialMaster.new()
	master.id = &"material_herb"
	master.decay_interval_turns = 3

	var interval := FreshnessResolver.decay_interval_of(
		_make_material(3), {&"material_herb": master}
	)

	assert_int(interval).is_equal(3)


func test_decay_interval_ofはマスター未登録なら0を返す() -> void:
	var interval := FreshnessResolver.decay_interval_of(_make_material(3), {})

	assert_int(interval).is_equal(0)
