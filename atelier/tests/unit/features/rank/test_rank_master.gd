extends GdUnitTestSuite

const TRES_PATH := "user://test_rank_master.tres"

# 正常系


func test_exportフィールドに値を設定すると読み書きできる() -> void:
	var rank := RankMaster.new()

	rank.id = "G"
	rank.display_name = "Gランク"
	rank.quota_max = 100.0
	rank.limit_turn = 15
	rank.traits_unlocked = false
	rank.exam_turn_limit = 1
	rank.exam_difficulty_coefficient = 1.0

	assert_str(rank.id).is_equal("G")
	assert_str(rank.display_name).is_equal("Gランク")
	assert_float(rank.quota_max).is_equal(100.0)
	assert_int(rank.limit_turn).is_equal(15)
	assert_bool(rank.traits_unlocked).is_false()
	assert_int(rank.exam_turn_limit).is_equal(1)
	assert_float(rank.exam_difficulty_coefficient).is_equal(1.0)


func test_特性解禁済みランクのフィールドも読み書きできる() -> void:
	var rank := RankMaster.new()

	rank.id = "F"
	rank.display_name = "Fランク"
	rank.traits_unlocked = true

	assert_str(rank.id).is_equal("F")
	assert_str(rank.display_name).is_equal("Fランク")
	assert_bool(rank.traits_unlocked).is_true()


func test_Resourceを継承している() -> void:
	var rank := RankMaster.new()

	assert_bool(rank is Resource).is_true()


func test_tres実データなしでフィクスチャ生成のみでインスタンス化が完結する() -> void:
	var rank := RankMaster.new()
	rank.id = "E"
	rank.display_name = "Eランク"
	rank.quota_max = 180.0
	rank.limit_turn = 14

	assert_object(rank).is_not_null()
	assert_str(rank.resource_path).is_empty()


# エッジケース


func test_デフォルト値が空文字列と0とfalseである() -> void:
	var rank := RankMaster.new()

	assert_str(rank.id).is_empty()
	assert_str(rank.display_name).is_empty()
	assert_float(rank.quota_max).is_equal(0.0)
	assert_int(rank.limit_turn).is_equal(0)
	assert_bool(rank.traits_unlocked).is_false()


func test_昇格試験フィールドのデフォルト値が0である() -> void:
	var rank := RankMaster.new()

	assert_int(rank.exam_turn_limit).is_equal(0)
	assert_float(rank.exam_difficulty_coefficient).is_equal(0.0)


func test_tresから読み込んだインスタンスがRankMaster型として扱える() -> void:
	var original := RankMaster.new()
	original.id = "S"
	original.display_name = "Sランク"
	original.quota_max = 999.5
	original.limit_turn = 8
	original.traits_unlocked = true
	original.exam_turn_limit = 2
	original.exam_difficulty_coefficient = 1.5
	assert_int(ResourceSaver.save(original, TRES_PATH)).is_equal(OK)

	var loaded: Resource = ResourceLoader.load(TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)

	assert_bool(loaded is RankMaster).is_true()
	var loaded_rank: RankMaster = loaded
	assert_str(loaded_rank.id).is_equal("S")
	assert_str(loaded_rank.display_name).is_equal("Sランク")
	assert_float(loaded_rank.quota_max).is_equal(999.5)
	assert_int(loaded_rank.limit_turn).is_equal(8)
	assert_bool(loaded_rank.traits_unlocked).is_true()
	assert_int(loaded_rank.exam_turn_limit).is_equal(2)
	assert_float(loaded_rank.exam_difficulty_coefficient).is_equal(1.5)


func after_test() -> void:
	if FileAccess.file_exists(TRES_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TRES_PATH))
