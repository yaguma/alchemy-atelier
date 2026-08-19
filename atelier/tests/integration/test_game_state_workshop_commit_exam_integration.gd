extends GdUnitTestSuite

## GameState.close_workshop()/get_purchased_count()/load_workshop_master_data()と、
## 昇格試験成功パス（_commit_exam_success()冒頭の1行追加）の接続を検証する（FR-005, FR-011, FR-015, FR-018, FR-110）。

const LAST_RANK_ID: StringName = &"rank_s"
const NON_DUP_UPGRADE_TEMP_PATH := "res://data/upgrades/_tmp_dup_upgrade.tres"


func before_test() -> void:
	GameState.reset_for_test()


func after_test() -> void:
	# 重複IDテストが作成した一時フィクスチャを、テスト失敗時も含め確実に除去する
	if FileAccess.file_exists(NON_DUP_UPGRADE_TEMP_PATH):
		DirAccess.remove_absolute(NON_DUP_UPGRADE_TEMP_PATH)
	if FileAccess.file_exists(NON_DUP_UPGRADE_TEMP_PATH + ".uid"):
		DirAccess.remove_absolute(NON_DUP_UPGRADE_TEMP_PATH + ".uid")


func _make_upgrade(
	is_permanent: bool = true, price: int = 100, max_purchase_count: int = 1
) -> UpgradeMaster:
	var upgrade := UpgradeMaster.new()
	upgrade.id = &"upgrade_test_dummy"
	upgrade.is_permanent = is_permanent
	upgrade.price = price
	upgrade.max_purchase_count = max_purchase_count
	upgrade.effect_type = &"catalyst_stock"
	return upgrade


func _make_rank(rank_id: StringName, quota_max: float, limit_turn: int) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = String(rank_id)
	rank.display_name = "テストランク"
	rank.quota_max = quota_max
	rank.limit_turn = limit_turn
	rank.traits_unlocked = false
	return rank


func _set_rank_state(quota: float, elapsed_turn: int) -> void:
	var state := RankState.new()
	state.quota = quota
	state.elapsed_turn = elapsed_turn
	GameState._set_rank_state_for_test(state)


func _set_exam_state(
	quota: float, quota_max: float, elapsed_turn: int, turn_limit: int, in_exam: bool = true
) -> void:
	var state := ExamState.new()
	state.exam_quota = quota
	state.exam_quota_max = quota_max
	state.exam_elapsed_turn = elapsed_turn
	state.exam_turn_limit = turn_limit
	GameState._set_exam_state_for_test(state, in_exam)


## RANK_ORDER末尾（次ランクなし）でSUCCESS確定させる。_commit_exam_success()の3分岐のうち
## 最も設定が単純な分岐だが、新規追加行は分岐前（関数冒頭）にあるため他の分岐にも一律適用される
func _setup_success_at_last_rank() -> void:
	GameState._set_rank_masters_for_test({LAST_RANK_ID: _make_rank(LAST_RANK_ID, 100.0, 30)})
	GameState._set_current_rank_id_for_test(LAST_RANK_ID)
	_set_rank_state(100.0, 0)
	_set_exam_state(0.0, 50.0, 5, 20)


# 正常系: close_workshop


func test_close_workshopでcan_purchase_permanentがfalseになる() -> void:
	GameState._set_can_purchase_permanent_for_test(true)

	GameState.close_workshop()

	assert_bool(GameState._can_purchase_permanent).is_false()


func test_close_workshopはfalseの状態から呼んでも冪等にfalseのままである() -> void:
	GameState._set_can_purchase_permanent_for_test(false)

	GameState.close_workshop()

	assert_bool(GameState._can_purchase_permanent).is_false()


# 正常系: get_purchased_count


func test_get_purchased_countは未購入のupgrade_idに対して0を返す() -> void:
	assert_int(GameState.get_purchased_count(&"upgrade_never_purchased")).is_equal(0)


func test_get_purchased_countはapply_upgradeで1回購入済みのupgrade_idに対して1を返す() -> void:
	GameState._set_can_purchase_permanent_for_test(true)
	GameState._set_gold_for_test(200)
	var upgrade := _make_upgrade(true, 100)

	var result := GameState.apply_upgrade(upgrade)

	assert_bool(result.success).is_true()
	assert_int(GameState.get_purchased_count(upgrade.id)).is_equal(1)


# 正常系: 昇格試験成功パスとの接続（FR-110）


func test_昇格試験成功確定直後にcan_purchase_permanentがtrueになる() -> void:
	_setup_success_at_last_rank()

	var result := GameState.commit_exam_outcome()

	assert_int(result.value).is_equal(ExamOutcome.Value.SUCCESS)
	assert_bool(GameState._can_purchase_permanent).is_true()


func test_昇格試験成功確定後にclose_workshopを呼ぶとfalseに戻る() -> void:
	_setup_success_at_last_rank()
	GameState.commit_exam_outcome()

	GameState.close_workshop()

	assert_bool(GameState._can_purchase_permanent).is_false()


# 異常系: 昇格試験失敗パスは無変更であることの回帰確認


func test_昇格試験失敗確定ではcan_purchase_permanentがtrueにならない() -> void:
	_set_rank_state(20.0, 30)
	_set_exam_state(10.0, 100.0, 20, 20)

	var result := GameState.commit_exam_outcome()

	assert_int(result.value).is_equal(ExamOutcome.Value.FAILURE)
	assert_bool(GameState._can_purchase_permanent).is_false()


# 正常系: load_workshop_master_data


func test_load_workshop_master_dataで実データの5件がupgrade_mastersに登録される() -> void:
	GameState.load_workshop_master_data()

	assert_int(GameState._upgrade_masters.size()).is_equal(5)
	assert_bool(GameState._upgrade_masters.has(&"upgrade_alchemy_slot")).is_true()
	assert_bool(GameState._upgrade_masters.has(&"upgrade_garden_slot")).is_true()
	assert_bool(GameState._upgrade_masters.has(&"upgrade_recipe_unlock_mana_tonic")).is_true()
	assert_bool(GameState._upgrade_masters.has(&"upgrade_catalyst")).is_true()
	assert_bool(GameState._upgrade_masters.has(&"upgrade_seed_name_purchase_ore")).is_true()


# 異常系: load_workshop_master_dataのID重複検知（既存load_alchemy_master_data()と同型の回帰確認）


func test_upgrade_idが重複するtresが存在する場合upgrade_mastersが更新されない() -> void:
	var copy_error := DirAccess.copy_absolute(
		"res://data/upgrades/upgrade_catalyst.tres", NON_DUP_UPGRADE_TEMP_PATH
	)
	assert_int(copy_error).is_equal(OK)

	GameState.load_workshop_master_data()

	assert_int(GameState._upgrade_masters.size()).is_equal(0)
