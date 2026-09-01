extends GdUnitTestSuite

## G→F→Eの2段階連続昇格と工房強化購入までを、main.tscnのシーングラフ越しのUI操作だけで
## 通しで検証するロングランプレイスルー結合シナリオ。
##
## 末尾の通しシナリオ1本が2段階昇格の全体を担い、その手前の各テストは
## G→F昇格・工房強化購入・購入失敗といった局面ごとの回帰カバレッジとして併存する。
## 既存のtest_main_scene_happy_path.gd（通常ターン1周）とtest_main_scene_exam_flow.gd（試験1回）が
## それぞれ単発の局面をカバーするのに対し、本スイートは複数ランクを跨いだ状態の引き継ぎを扱う。

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SCREEN_NODE_NAMES := ["GardenScreen", "AlchemyScreen", "WorkshopScreen", "ResultScreen"]

const RANK_G_ID: StringName = &"rank_g"  # 🔵 GameBalance.RANK_ORDER[0]
const RANK_F_ID: StringName = &"rank_f"  # 🔵 GameBalance.RANK_ORDER[1]
const RANK_E_ID: StringName = &"rank_e"  # 🔵 GameBalance.RANK_ORDER[2]

const RECIPE_ID: StringName = &"recipe_full_loop_test"
const MATERIAL_ID: StringName = &"material_herb"
const MATERIAL_INSTANCE_ID := "mat_full_loop_1"
const MATERIAL_QUALITY := 3

const SEED_HERB_ID: StringName = &"seed_herb"  # 🔵 data/materials/seed_herb.tres（実マスターデータ）

## 🔵 data/upgrades/upgrade_alchemy_slot.tres（実マスターデータ、is_permanent=true / price=2000 /
## effect_type=alchemy_slot_increase / max_purchase_count=1）
const UPGRADE_ALCHEMY_SLOT_ID: StringName = &"upgrade_alchemy_slot"

## 🟡 upgrade_alchemy_slot（2000G）を確実に購入できるだけの十分な所持ゴールド。
## 工房画面は表示時点のゴールドで購入ボタンの活性/非活性を決めるため、試験開始より前に注入する
const WORKSHOP_TEST_GOLD := 5000

## 🔵 試験中の調合1回分の素材。通常ターン分（MATERIAL_INSTANCE_ID）は調合で消費されるため、
## 試験ノルマを消し切るにはもう1個必要になる
const EXAM_MATERIAL_INSTANCE_ID := "mat_full_loop_exam_1"

## 🟡 F→Eの2周目で使う素材。G→Fで使った2個は調合で消費済みのため、
## 同じインスタンスIDは在庫一覧に残っておらず2周目には別インスタンスが必要になる
const MATERIAL_INSTANCE_ID_2ND := "mat_full_loop_2"
const EXAM_MATERIAL_INSTANCE_ID_2ND := "mat_full_loop_exam_2"

# 🟡 少ない操作回数で確実に昇格まで到達させるためのテスト専用の低ノルマ値
# （test_main_scene_exam_flow.gdと同値）。試験ノルマも同じ計算で4.0になる。
const RANK_QUOTA_MAX := 4.0
const RANK_LIMIT_TURN := 2
const EXAM_TURN_LIMIT := 2
const EXAM_DIFFICULTY_COEFFICIENT := 1.0

# ランクノルマ(4.0)・試験ノルマ(4.0)のいずれも1回の納品で確実に消し切れる十分大きな値
const PRODUCT_CONTRIBUTION := 20.0
const PRODUCT_REWARD := 5.0
const RECIPE_BASE_CONTRIBUTION := 20.0
const RECIPE_BASE_REWARD := 5.0

# 昇格が確定した回数と結果を記録する観測用バッファ（CONTINUEは結果未確定のため除外する）
var _exam_outcomes: Array[int] = []


func before_test() -> void:
	GameState.reset_for_test()
	_exam_outcomes = []


func after_test() -> void:
	# GameStateはAutoloadでテストより寿命が長いため明示的に解除する
	if GameState.exam_outcome_confirmed.is_connected(_on_exam_outcome_confirmed):
		GameState.exam_outcome_confirmed.disconnect(_on_exam_outcome_confirmed)


# --- フィクスチャ ---


## 🔵 MainScene._enter_tree()がload_rank_master_data()等で実データを読み込むため、
## フィクスチャの注入は必ずシーン生成の「後」に行う（先に注入すると実データで上書きされる）
func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


func _make_rank(rank_id: StringName) -> RankMaster:
	var rank := RankMaster.new()
	rank.id = String(rank_id)
	rank.display_name = "テストランク"
	rank.quota_max = RANK_QUOTA_MAX
	rank.limit_turn = RANK_LIMIT_TURN
	rank.traits_unlocked = false
	rank.exam_turn_limit = EXAM_TURN_LIMIT
	rank.exam_difficulty_coefficient = EXAM_DIFFICULTY_COEFFICIENT
	return rank


## G→F→Eの3ランク分のRankMasterを一括登録する。昇格先のマスターが欠けていると
## 昇格処理が成立しないため、シナリオで到達しうる全ランクを最初にまとめて差し替える。
func _setup_rank_masters() -> void:
	(
		GameState
		. _set_rank_masters_for_test(
			{
				RANK_G_ID: _make_rank(RANK_G_ID),
				RANK_F_ID: _make_rank(RANK_F_ID),
				RANK_E_ID: _make_rank(RANK_E_ID),
			}
		)
	)


## ランクノルマを「あと1回の納品で達成でき、かつ制限ターンには既に到達済み」の状態にする。
## 🟡 elapsed_turnを進める本番コードは未実装（rank_state.gdに既知ギャップとして明記）のため、
## PROMOTION_ELIGIBLEへ到達させるにはRankStateの直接注入が必須。
## 昇格するたびに次ランク用の状態を作り直す必要があるため、ランクを跨ぐたびに呼び直す。
func _enter_rank(rank_id: StringName) -> void:
	var rank_state := RankState.new()
	rank_state.quota = RANK_QUOTA_MAX
	rank_state.elapsed_turn = RANK_LIMIT_TURN
	GameState._set_current_rank_id_for_test(rank_id)
	GameState._set_rank_state_for_test(rank_state)


func _make_recipe() -> RecipeMaster:
	var recipe := RecipeMaster.new()
	recipe.id = RECIPE_ID
	recipe.name = "テストレシピ"
	recipe.base_contribution = RECIPE_BASE_CONTRIBUTION
	recipe.base_reward = RECIPE_BASE_REWARD
	return recipe


func _make_product() -> ProductInstance:
	return ProductInstance.new(
		RECIPE_ID, MATERIAL_QUALITY, [] as Array[StringName], PRODUCT_CONTRIBUTION, PRODUCT_REWARD
	)


func _inject_material(instance_id: String) -> void:
	GameState._inject_material_for_test(
		MaterialInstance.new(instance_id, MATERIAL_ID, MATERIAL_QUALITY, [] as Array[StringName])
	)


## テスト専用レシピを解禁済みにし、それを1回調合できる素材を1個投入する。
func _setup_recipe_and_material() -> void:
	GameState._set_recipe_masters_for_test({RECIPE_ID: _make_recipe()})
	GameState._set_unlocked_recipe_ids_for_test([RECIPE_ID] as Array[StringName])
	_inject_material(MATERIAL_INSTANCE_ID)


# --- UI操作ヘルパー ---


## rootの配下からnode_nameのButtonを探して押下をシミュレートする。
## 🔵 EndTurnButton/ShopButtonは庭・調合の双方に同名で存在するため、必ず対象画面を
## rootに指定して探索範囲を絞る
func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_object(button).is_not_null()
	button.pressed.emit()


func _garden(main: MainScene) -> GardenScreen:
	return main.find_child("GardenScreen", true, false) as GardenScreen


func _alchemy(main: MainScene) -> AlchemyScreen:
	return main.find_child("AlchemyScreen", true, false) as AlchemyScreen


func _workshop(main: MainScene) -> WorkshopScreen:
	return main.find_child("WorkshopScreen", true, false) as WorkshopScreen


## 庭の種一覧から指定の種を1つ植え付ける。種マスターはフィクスチャで差し替えていないため
## 実マスターデータの行（SeedEntry_<seed_id>）をそのまま押す。
## 🔴 PlantButtonはdisabled状態でもコード経由のpressed発行を抑止しないため、押下自体が
## 成立しても植え付けが実際に成功したとは限らない。garden_state.plantsの株数が
## 押下前後で1件増えていることまで確認し、slot_full等での静かな失敗を検出できるようにする
func _plant_seed(main: MainScene, seed_id: StringName) -> void:
	var row := _garden(main).find_child("SeedEntry_%s" % seed_id, true, false) as SeedEntryRow
	assert_object(row).is_not_null()
	var plants_before: int = (GameState.get_state()["garden_state"] as GardenState).plants.size()
	_press(row, "PlantButton")
	var plants_after: int = (GameState.get_state()["garden_state"] as GardenState).plants.size()
	assert_int(plants_after).is_equal(plants_before + 1)


## 🔵 test_main_scene_happy_path.gdの同名ヘルパー踏襲。OptionButtonはselect()だけでは
## item_selectedが発行されないため、明示的にemitして画面側の選択処理を走らせる
func _select_recipe(alchemy: AlchemyScreen, recipe_id: StringName) -> void:
	var option_button := alchemy.find_child("RecipeOptionButton", true, false) as OptionButton
	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == recipe_id:
			option_button.select(index)
			option_button.item_selected.emit(index)
			return
	fail("解禁済みレシピ %s がドロップダウンに存在しません" % recipe_id)


func _place_material(alchemy: AlchemyScreen, instance_id: String) -> void:
	var row := alchemy.find_child("MaterialEntry_%s" % instance_id, true, false) as MaterialEntryRow
	assert_object(row).is_not_null()
	_press(row, "PlaceButton")


## 調合画面へ切り替え、レシピ選択・素材投入・調合実行・ターン終了を1サイクル行う。
## 🔵 ターン終了で納品決算とランク判定が走るため、ノルマを消し切っていればそのまま試験が始まる
## （GuildDeliveryScreenの「続ける」は押さない。押すと庭へ戻り試験開始と競合するため）
func _run_one_alchemy_turn(main: MainScene, material_instance_id: String) -> void:
	_press(main, "AlchemyTabButton")
	var alchemy := _alchemy(main)
	_select_recipe(alchemy, RECIPE_ID)
	_place_material(alchemy, material_instance_id)
	_press(alchemy, "ExecuteButton")
	_press(alchemy, "EndTurnButton")


## 試験中に調合を1回実行する。試験中は調合成功で自動納品されるため、試験ノルマがここで消し切られる。
## 🔵 test_main_scene_exam_flow.gdの同名関数を踏襲。素材IDのみ、昇格を跨いで使い回せるよう引数化した
func _craft_once_in_exam(
	main: MainScene, material_instance_id: String = EXAM_MATERIAL_INSTANCE_ID
) -> void:
	var alchemy := _alchemy(main)
	_select_recipe(alchemy, RECIPE_ID)
	_place_material(alchemy, material_instance_id)
	_press(alchemy, "ExecuteButton")


## 工房のアイテム一覧から指定の強化を1つ購入する。
## 🔵 行のノード名はupgrade_item_list.gd L61の "UpgradeItem_%s" % upgrade.id 準拠。
## 🔵 Button.disabledはコード経由のpressed発行を抑止しないため、押下自体は常に成立し、
## 実際の可否はGameState.apply_upgrade()側の再検証に委ねられる（ゴールド不足ケースの検証点）
func _purchase_upgrade(main: MainScene, upgrade_id: StringName) -> void:
	var row := (
		_workshop(main).find_child("UpgradeItem_%s" % upgrade_id, true, false) as UpgradeItemRow
	)
	assert_object(row).is_not_null()
	_press(row, "PurchaseButton")


## 実マスターデータ側の購入価格を引く。テスト内に価格をハードコードすると
## .tresのバランス調整でテストが無関係に落ちるため、常に読み込み済みマスターから取得する。
func _upgrade_price(upgrade_id: StringName) -> int:
	var upgrade_masters: Dictionary = GameState.get_state()["upgrade_masters"]
	var upgrade: Variant = upgrade_masters.get(upgrade_id)
	assert_bool(upgrade is UpgradeMaster).is_true()
	return (upgrade as UpgradeMaster).price


## 種の植え付けと通常ターン1周を行い、ノルマ消化で昇格試験が始まるところまで進める。
## 🔵 呼び出し元で事前にmonitor_signals(GameState, false)を済ませておくこと（await前提）
## 🔵 素材IDは昇格を跨いで別インスタンスへ切り替えられるよう引数化した（2周目は在庫が空のため）
func _run_turn_until_exam_started(
	main: MainScene, material_instance_id: String = MATERIAL_INSTANCE_ID
) -> void:
	_plant_seed(main, SEED_HERB_ID)
	_run_one_alchemy_turn(main, material_instance_id)
	await assert_signal(GameState).is_emitted("exam_started")


## 試験中の調合1回と試験ターン送りを行い、合格が確定するところまで進める。
func _pass_exam(main: MainScene, material_instance_id: String = EXAM_MATERIAL_INSTANCE_ID) -> void:
	_craft_once_in_exam(main, material_instance_id)
	_press(_alchemy(main), "AdvanceExamTurnButton")
	await assert_signal(GameState).is_emitted("exam_outcome_confirmed", [ExamOutcome.Value.SUCCESS])


# --- 昇格回数の観測用リスナー ---


## 🔵 test_main_scene_exam_flow.gdの_observe_endgame_signals()踏襲。MainSceneの_ready()より後に
## 接続されるため、MainSceneが当該シグナルへ反応し終えた後に呼ばれる
func _record_exam_outcomes() -> void:
	GameState.exam_outcome_confirmed.connect(_on_exam_outcome_confirmed)


## 🔵 CONTINUEは「試験がまだ続いている＝結果未確定」を表し、押下回数に比例して発行されるため、
## 昇格回数の観測対象は結果が確定したSUCCESS/FAILUREのみに絞る
func _on_exam_outcome_confirmed(outcome: ExamOutcome.Value) -> void:
	if outcome == ExamOutcome.Value.CONTINUE:
		return
	_exam_outcomes.append(outcome)


## 4画面とMainScene自身のインスタンスIDを控える。change_scene_to_file()による画面の
## 破棄・再生成が起きていないことの代替観測点（NFR-001）
func _screen_instance_ids(main: MainScene) -> Array[int]:
	var ids: Array[int] = [main.get_instance_id()]
	for node_name in SCREEN_NODE_NAMES:
		ids.append(main.find_child(node_name, true, false).get_instance_id())
	return ids


# 正常系: フィクスチャの土台検証


func test_フィクスチャ注入後にGランクから開始できる() -> void:
	var main := _make_main()

	_setup_rank_masters()
	_enter_rank(RANK_G_ID)
	_setup_recipe_and_material()

	assert_that(GameState.get_state()["current_rank_id"]).is_equal(RANK_G_ID)
	assert_that(main.get_visible_phase()).is_equal(&"garden")
	var rank_state: RankState = GameState.get_state()["rank_state"]
	assert_float(rank_state.quota).is_equal(RANK_QUOTA_MAX)
	assert_int(GameState.get_state()["inventory"].size()).is_equal(1)


func test_MainSceneと4画面のインスタンスIDを観測できる() -> void:
	var main := _make_main()

	var ids := _screen_instance_ids(main)

	assert_int(ids.size()).is_equal(SCREEN_NODE_NAMES.size() + 1)
	# 🔴 同じ呼び出しの結果同士を比較する自己比較は、find_child()が誤ったノードに
	# マッチしていても常にパスしてしまうため検証力がない（PR#44レビュー指摘対応）。
	# 各IDが有効値（0より大きい）かつ互いに重複していないことを直接検証する。
	var seen_ids: Dictionary = {}
	for id in ids:
		assert_int(id).is_greater(0)
		assert_bool(seen_ids.has(id)).is_false()
		seen_ids[id] = true


# 正常系: G→Fの前半シナリオ（通常ターン→ランク判定→試験→合格→工房）


## 【本Planの前半の中核】Gランクから通常ターン1周でノルマを消し切り、そのまま昇格試験へ入って
## 1回の調合で合格し、Fランクへ昇格して工房強化画面が自動表示されるまでをUI操作のみで通す。
func test_G昇格試験に合格しworkshop画面へ自動遷移する() -> void:
	var main := _make_main()
	_setup_rank_masters()
	_enter_rank(RANK_G_ID)
	_setup_recipe_and_material()
	# 🔵 exam_started時のAlchemyScreen._refresh()で在庫一覧へ載せる必要があるため、
	# 試験用素材は試験が始まるターン終了より前に投入しておく（注入自体はシグナルを発行しない）
	_inject_material(EXAM_MATERIAL_INSTANCE_ID)
	monitor_signals(GameState, false)

	await _run_turn_until_exam_started(main)

	# 納品が成立して納品待ちが捌け、ノルマ消化により昇格試験が始まっている
	assert_int(GameState.get_state()["pending_products"].size()).is_equal(0)
	assert_bool(GameState.get_state()["in_exam"]).is_true()

	await _pass_exam(main)

	assert_that(main.get_visible_phase()).is_equal(&"workshop")
	assert_that(GameState.get_state()["current_rank_id"]).is_equal(RANK_F_ID)
	# 後続タスクの工房強化購入シナリオの前提（FR-012）
	assert_bool(GameState.get_state()["can_purchase_permanent"]).is_true()


# 正常系: 工房強化の購入（G昇格直後の恒久投資枠）


## Gランク昇格直後に強制表示される工房で恒久強化「投入枠+1」をUI操作のみで購入し、
## ゴールド減算と調合投入枠の増加が実際にGameStateへ反映されること、閉じたあと通常の
## ゲーム画面へ復帰できることを通しで確認する。
##
## 🔴 復帰先は調合ではなく庭になる。MainScene._phase_before_workshopはshop_requested経由の
## 工房入場でしか更新されず（main.gd _on_shop_requested()）、試験合格時は
## _on_exam_outcome_confirmed()がset_phase(PHASE_WORKSHOP)を直接呼ぶため初期値の庭が残るため
## （main.gd _on_workshop_closed()のコメント「shop_requestedを経ずに工房へ入った場合は
## 初期値である庭へ戻る（AC-004異常系）」に一致）。昇格直後に新ランク用の仕込みへ戻る導線として
## 妥当と判断し、現状の挙動をそのまま固定する
func test_G昇格後の工房で恒久強化を購入すると反映され庭へ復帰する() -> void:
	var main := _make_main()
	_setup_rank_masters()
	_enter_rank(RANK_G_ID)
	_setup_recipe_and_material()
	_inject_material(EXAM_MATERIAL_INSTANCE_ID)
	GameState._set_gold_for_test(WORKSHOP_TEST_GOLD)
	monitor_signals(GameState, false)

	await _run_turn_until_exam_started(main)
	await _pass_exam(main)
	assert_that(main.get_visible_phase()).is_equal(&"workshop")

	var price := _upgrade_price(UPGRADE_ALCHEMY_SLOT_ID)
	var gold_before: int = GameState.get_state()["gold"]
	var slot_count_before: int = GameState._alchemy_slot_count

	_purchase_upgrade(main, UPGRADE_ALCHEMY_SLOT_ID)

	assert_int(GameState.get_state()["gold"]).is_equal(gold_before - price)
	assert_int(GameState._alchemy_slot_count).is_equal(slot_count_before + 1)
	assert_int(GameState.get_purchased_count(UPGRADE_ALCHEMY_SLOT_ID)).is_equal(1)

	_press(_workshop(main), "CloseButton")

	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_bool(GameState.get_state()["can_purchase_permanent"]).is_false()


# エッジケース: 工房強化の購入失敗


## 工房画面のボタン押下はDomain層の再検証を素通りしない。所持ゴールドを価格未満へ落とした状態で
## 購入ボタンを押しても、ゴールドも投入枠も一切変化しないことを保証する
## （🔵 Button.disabledはコード経由のpressed発行を止めないため、この経路は実際に到達しうる）。
func test_ゴールド不足の状態で恒久強化を購入しても状態が変化しない() -> void:
	var main := _make_main()
	_setup_rank_masters()
	_enter_rank(RANK_G_ID)
	_setup_recipe_and_material()
	_inject_material(EXAM_MATERIAL_INSTANCE_ID)
	GameState._set_gold_for_test(WORKSHOP_TEST_GOLD)
	monitor_signals(GameState, false)

	await _run_turn_until_exam_started(main)
	await _pass_exam(main)

	var price := _upgrade_price(UPGRADE_ALCHEMY_SLOT_ID)
	GameState._set_gold_for_test(price - 1)
	var slot_count_before: int = GameState._alchemy_slot_count

	_purchase_upgrade(main, UPGRADE_ALCHEMY_SLOT_ID)

	assert_int(GameState.get_state()["gold"]).is_equal(price - 1)
	assert_int(GameState._alchemy_slot_count).is_equal(slot_count_before)
	assert_int(GameState.get_purchased_count(UPGRADE_ALCHEMY_SLOT_ID)).is_equal(0)


# エッジケース: 複数ランクの跨ぎ


## 昇格を跨いだシナリオでは_enter_rank()を複数回呼ぶため、2回目以降も
## 例外にならずランク状態が新しいランクの初期値へ作り直されることを保証する。
func test_ランクを跨いで再度入場してもランク状態がリセットされる() -> void:
	_make_main()
	_setup_rank_masters()
	_enter_rank(RANK_G_ID)
	GameState._set_rank_state_for_test(RankState.new())  # ノルマを消化し切った状態を模す

	_enter_rank(RANK_F_ID)

	assert_that(GameState.get_state()["current_rank_id"]).is_equal(RANK_F_ID)
	var rank_state: RankState = GameState.get_state()["rank_state"]
	assert_float(rank_state.quota).is_equal(RANK_QUOTA_MAX)
	assert_int(rank_state.elapsed_turn).is_equal(RANK_LIMIT_TURN)


# 正常系: 通し全体（G→F→Eの2段階連続昇格）


## 【本Planの中核】G→F昇格、恒久強化の購入、F→E昇格までを1本のシナリオとして通しで実行し、
## ランクを跨いでも状態が正しく引き継がれること、およびその間MainSceneと4画面が一度も
## 破棄・再生成されないこと（NFR-001）を保証する。
##
## 🔵 F→Eでは_enter_rank(RANK_F_ID)で低ノルマを再注入する。昇格時に本番コードが
## RankQuotaResolver.reset_for_retry()でquota=quota_max / elapsed_turn=0へ初期化する
## （game_state_rank_delegate.gd L231）ため、制限ターン到達済みの状態は毎回作り直す必要がある。
## 注入は本番の初期化を上書きするだけで二重初期化にはならない
func test_G昇格から工房強化購入を経てF昇格まで実機シーングラフのみで通しで到達する() -> void:
	var main := _make_main()
	_setup_rank_masters()
	_enter_rank(RANK_G_ID)
	_setup_recipe_and_material()
	_inject_material(EXAM_MATERIAL_INSTANCE_ID)
	GameState._set_gold_for_test(WORKSHOP_TEST_GOLD)
	var instance_ids_before := _screen_instance_ids(main)
	_record_exam_outcomes()
	monitor_signals(GameState, false)

	# 1段目: G→F（通常ターン1周でノルマ消化 → 試験 → 合格 → 工房が自動表示）
	await _run_turn_until_exam_started(main)
	await _pass_exam(main)
	assert_that(GameState.get_state()["current_rank_id"]).is_equal(RANK_F_ID)
	assert_that(main.get_visible_phase()).is_equal(&"workshop")

	# 恒久強化を購入して工房を閉じる（🔵 復帰先は調合ではなく庭。タスク003で確認済みの現行仕様）
	_purchase_upgrade(main, UPGRADE_ALCHEMY_SLOT_ID)
	_press(_workshop(main), "CloseButton")
	assert_that(main.get_visible_phase()).is_equal(&"garden")

	# 2段目: F→E（庭からもう一度同じ手順を繰り返す。素材は2周目用を新たに投入する）
	_enter_rank(RANK_F_ID)
	_inject_material(MATERIAL_INSTANCE_ID_2ND)
	_inject_material(EXAM_MATERIAL_INSTANCE_ID_2ND)

	await _run_turn_until_exam_started(main, MATERIAL_INSTANCE_ID_2ND)
	await _pass_exam(main, EXAM_MATERIAL_INSTANCE_ID_2ND)

	assert_that(GameState.get_state()["current_rank_id"]).is_equal(RANK_E_ID)
	assert_that(main.get_visible_phase()).is_equal(&"workshop")
	# 2回の昇格がいずれも合格として確定している（CONTINUE等の中間発行は記録対象外）
	assert_array(_exam_outcomes).contains_exactly(
		[ExamOutcome.Value.SUCCESS, ExamOutcome.Value.SUCCESS]
	)
	# NFR-001。全操作を通じてMainSceneと4画面が一度も作り直されていない
	assert_array(_screen_instance_ids(main)).contains_exactly(instance_ids_before)
