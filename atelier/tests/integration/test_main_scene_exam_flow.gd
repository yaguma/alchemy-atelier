extends GdUnitTestSuite

## MainSceneの「ランク判定確定 → 昇格試験開始 → 試験合否確定 → 分岐（workshop/garden/result）」を
## 実機シーングラフ越しにUI操作だけで通す結合シナリオ（シナリオ3・4／FR-108〜FR-113, FR-201, FR-202）。
##
## 既存のtest_main_scene_exam_and_result_routing.gdがシグナルを直接emitして遷移だけを検証するのに対し、
## 本スイートはタブボタン・ターン終了ボタン・調合実行ボタン・ターンを進めるボタンの押下のみで
## GameState側のcommit_rank_outcome()/commit_exam_outcome()を発火させ、
## FR-113（exam_outcome_confirmed → game_cleared/game_over の同一フレーム内連続発行と最終画面の上書き）が
## 本物の呼び出し経路で成立することを保証する。

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

const RECIPE_ID := &"recipe_exam_flow_test"
const MATERIAL_INSTANCE_ID := "mat_exam_1"
const MATERIAL_ID := &"material_herb"
const MATERIAL_QUALITY := 3

const NON_FINAL_RANK_ID := &"rank_g"  # GameBalance.RANK_ORDER先頭（次ランクが必ず存在する）
const NEXT_RANK_ID := &"rank_f"
const FINAL_RANK_ID := &"rank_s"  # GameBalance.RANK_ORDER末尾（RankProgression.is_true_final_rankが真）

# 🟡 少ない操作回数で確実にSUCCESS/FAILUREへ到達させるためのテスト専用の低ノルマ値。
# 試験ノルマ = quota_max * exam_difficulty_coefficient * exam_turn_limit / limit_turn = 4.0
const RANK_QUOTA_MAX := 4.0
const RANK_LIMIT_TURN := 2
const EXAM_TURN_LIMIT := 2
const EXAM_DIFFICULTY_COEFFICIENT := 1.0

# ランクノルマ(4.0)・試験ノルマ(4.0)のいずれも1回の納品で確実に消し切れる十分大きな値
const PRODUCT_CONTRIBUTION := 20.0
const PRODUCT_REWARD := 5.0
const RECIPE_BASE_CONTRIBUTION := 20.0
const RECIPE_BASE_REWARD := 5.0

# FR-113の発行順とその時点の表示フェーズを記録する観測用バッファ
var _event_order: Array[String] = []
var _phase_at_outcome_confirmed: StringName = &""
var _observed_main: MainScene = null


func before_test() -> void:
	GameState.reset_for_test()
	_event_order = []
	_phase_at_outcome_confirmed = &""
	_observed_main = null


func after_test() -> void:
	# GameStateはAutoloadでテストより寿命が長いため明示的に解除する
	if GameState.exam_outcome_confirmed.is_connected(_on_exam_outcome_confirmed):
		GameState.exam_outcome_confirmed.disconnect(_on_exam_outcome_confirmed)
	if GameState.game_cleared.is_connected(_on_game_cleared):
		GameState.game_cleared.disconnect(_on_game_cleared)
	if GameState.game_over.is_connected(_on_game_over):
		GameState.game_over.disconnect(_on_game_over)


# --- フィクスチャ ---


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


## ランクノルマを「あと1回の納品で達成でき、かつ制限ターンには既に到達済み」の状態にする。
## 🟡 elapsed_turnを進める本番コードは未実装（rank_state.gdに既知ギャップとして明記）のため、
## PROMOTION_ELIGIBLEへ到達させるにはRankStateの直接注入が必須
func _make_rank_state() -> RankState:
	var rank_state := RankState.new()
	rank_state.quota = RANK_QUOTA_MAX
	rank_state.elapsed_turn = RANK_LIMIT_TURN
	return rank_state


## 🔴 MainScene._enter_tree()がload_rank_master_data()等で実データを読み込むため、
## フィクスチャの注入は必ずシーン生成の「後」に行う（先に注入すると実データで上書きされる）
func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


func _setup_ranks(current_rank_id: StringName) -> void:
	var masters: Dictionary = {
		NON_FINAL_RANK_ID: _make_rank(NON_FINAL_RANK_ID),
		NEXT_RANK_ID: _make_rank(NEXT_RANK_ID),
		FINAL_RANK_ID: _make_rank(FINAL_RANK_ID),
	}
	GameState._set_rank_masters_for_test(masters)
	GameState._set_current_rank_id_for_test(current_rank_id)
	GameState._set_rank_state_for_test(_make_rank_state())
	GameState._set_recipe_masters_for_test({RECIPE_ID: _make_recipe()})
	GameState._set_unlocked_recipe_ids_for_test([RECIPE_ID] as Array[StringName])
	GameState._inject_material_for_test(
		MaterialInstance.new(
			MATERIAL_INSTANCE_ID, MATERIAL_ID, MATERIAL_QUALITY, [] as Array[StringName]
		)
	)


# --- UI操作ヘルパー ---


func _alchemy_screen(main: MainScene) -> AlchemyScreen:
	return main.find_child("AlchemyScreen", true, false) as AlchemyScreen


func _result_screen(main: MainScene) -> ResultScreen:
	return main.find_child("ResultScreen", true, false) as ResultScreen


func _workshop_screen(main: MainScene) -> WorkshopScreen:
	return main.find_child("WorkshopScreen", true, false) as WorkshopScreen


## MainScene直下のタブボタンを押下する。
## 🔴 "EndTurnButton"はGardenScreenにも同名で存在するため、画面内ボタンはmain全体から探さない
func _press_tab(main: MainScene, node_name: String) -> void:
	(main.find_child(node_name, true, false) as Button).pressed.emit()


func _alchemy_button(main: MainScene, node_name: String) -> Button:
	return _alchemy_screen(main).find_child(node_name, true, false) as Button


func _press_in_alchemy(main: MainScene, node_name: String) -> void:
	_alchemy_button(main, node_name).pressed.emit()


## 調合画面へ切り替え、ランクノルマを達成する納品を経てターンを終了し、昇格試験を開始させる。
## 経路: EndTurnButton押下 -> deliver_pending_products() -> commit_rank_outcome()
##       -> PROMOTION_ELIGIBLE -> _start_exam() -> exam_started
func _start_exam_via_ui(main: MainScene) -> void:
	_press_tab(main, "AlchemyTabButton")
	GameState._inject_pending_product_for_test(_make_product())
	_press_in_alchemy(main, "EndTurnButton")


## 試験中に調合を1回実行する。試験中は調合成功で自動納品されるため、試験ノルマがここで消し切られる。
func _craft_once_in_exam(main: MainScene) -> void:
	var screen := _alchemy_screen(main)
	var option_button := screen.find_child("RecipeOptionButton", true, false) as OptionButton
	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == RECIPE_ID:
			option_button.select(index)
			option_button.item_selected.emit(index)
			break
	var row_name := "MaterialEntry_%s" % MATERIAL_INSTANCE_ID
	var row := screen.find_child(row_name, true, false) as MaterialEntryRow
	(row.find_child("PlaceButton", true, false) as Button).pressed.emit()
	_press_in_alchemy(main, "ExecuteButton")


## 試験の制限ターンを使い切るまで「ターンを進める」を押し続け、FAILUREを確定させる。
func _exhaust_exam_turns(main: MainScene) -> void:
	for _i in range(EXAM_TURN_LIMIT):
		_press_in_alchemy(main, "AdvanceExamTurnButton")


# --- FR-113観測用リスナー ---


## MainSceneの_ready()による接続より後に接続されるため、各コールバック時点の表示フェーズは
## 「MainSceneが当該シグナルへ反応し終えた直後の値」になる。
func _observe_endgame_signals(main: MainScene) -> void:
	_observed_main = main
	GameState.exam_outcome_confirmed.connect(_on_exam_outcome_confirmed)
	GameState.game_cleared.connect(_on_game_cleared)
	GameState.game_over.connect(_on_game_over)


## 🔴 CONTINUEは「試験がまだ続いている＝結果未確定」を表し、FR-113の
## 「exam_outcome_confirmed → game_cleared/game_over」の順序関係に一切関与しない。
## 「ターンを進める」を押すたびにCONTINUEが発行されて記録が押下回数に依存してしまうため、
## 終局判定の観測対象は結果が確定したSUCCESS/FAILUREのみに絞る
func _on_exam_outcome_confirmed(outcome: ExamOutcome.Value) -> void:
	if outcome == ExamOutcome.Value.CONTINUE:
		return
	_event_order.append("exam_outcome_confirmed")
	_phase_at_outcome_confirmed = _observed_main.get_visible_phase()


func _on_game_cleared() -> void:
	_event_order.append("game_cleared")


func _on_game_over(_demotion_count: int) -> void:
	_event_order.append("game_over")


# 正常系: 試験開始（FR-108, FR-201）


func test_通常ターンの終了でランク判定が確定し試験が開始される() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	monitor_signals(GameState, false)

	_start_exam_via_ui(main)

	await assert_signal(GameState).is_emitted("exam_started")
	assert_bool(GameState.get_state()["in_exam"]).is_true()
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")
	assert_bool(main.get_is_garden_tab_disabled()).is_true()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_true()


## FR-201。試験中はタブが無効化されるため、庭タブ押下では調合画面から離脱できない。
func test_試験中は庭タブを押しても調合画面から離脱できない() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	_start_exam_via_ui(main)

	_press_tab(main, "GardenTabButton")

	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


## 試験開始時に試験モードUIへ切り替わっていること（AdvanceExamTurnButtonが操作可能になること）を
## 確認する。以降のテストが「ターンを進める」経由で結果を確定させる前提そのものの検証。
func test_試験開始で調合画面が試験モードUIへ切り替わる() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	_start_exam_via_ui(main)

	assert_bool(_alchemy_button(main, "AdvanceExamTurnButton").visible).is_true()
	assert_bool(_alchemy_button(main, "EndTurnButton").visible).is_false()


# 正常系: 合格分岐（FR-109, FR-110, FR-201解除）


func test_試験に合格すると工房強化画面が自動表示される_非最終ランク() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	_start_exam_via_ui(main)
	_craft_once_in_exam(main)
	monitor_signals(GameState, false)

	_press_in_alchemy(main, "AdvanceExamTurnButton")

	await assert_signal(GameState).is_emitted("exam_outcome_confirmed", [ExamOutcome.Value.SUCCESS])
	assert_that(main.get_visible_phase()).is_equal(&"workshop")
	assert_that(GameState.get_state()["current_rank_id"]).is_equal(NEXT_RANK_ID)
	assert_bool(GameState.get_state()["can_purchase_permanent"]).is_true()
	assert_bool(GameState.get_state()["in_exam"]).is_false()
	# FR-201解除。合格後はタブ操作が再び可能になる
	assert_bool(main.get_is_garden_tab_disabled()).is_false()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_false()


## 🔴 現状の仕様ギャップを明示する特性テスト。WorkshopScreenは_ready()と購入/閉じる操作でしか
## _refresh()しないため、試験合格でcan_purchase_permanentがtrueになっても、
## MainSceneがvisibleを切り替えただけでは恒久投資タブが自動で活性化・自動選択されない。
## GameState側のフラグは正しく立っている（上のテストで検証済み）ため表示層のみの問題。
func test_試験合格直後は工房の恒久投資タブがまだ自動選択されない() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	_start_exam_via_ui(main)
	_craft_once_in_exam(main)

	_press_in_alchemy(main, "AdvanceExamTurnButton")

	assert_that(_workshop_screen(main).get_active_tab()).is_equal(WorkshopScreen.TAB_CONSUMABLE)


## FR-105 / AC-004異常系。試験合格による工房遷移はMainScene._on_exam_outcome_confirmed()が
## set_phase()を直接呼ぶ経路であり、_on_shop_requested()を通らないため復帰先は更新されない。
## したがって閉じたときの戻り先は「工房を開く直前の調合画面」ではなく既定値の庭になる。
## 🟡 試験直前の画面へ戻したい場合は復帰先の更新箇所を増やす必要があるが、本タスクは
## テストのみを追加するスコープのため現行仕様をそのまま固定する。
func test_試験合格後の工房を閉じると既定の復帰先である庭へ戻る() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	_start_exam_via_ui(main)
	_craft_once_in_exam(main)
	_press_in_alchemy(main, "AdvanceExamTurnButton")

	(_workshop_screen(main).find_child("CloseButton", true, false) as Button).pressed.emit()

	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_bool(GameState.get_state()["can_purchase_permanent"]).is_false()


# 正常系: ゲームクリア（FR-111, FR-113, FR-202）


## 【本Planの受入の中核】真の最終ランクでの試験合格。
## commit_exam_outcome()がexam_outcome_confirmed → game_clearedの順で同一フレーム内に発行し、
## 暫定のworkshop遷移がresultへ上書き確定することをUI操作経由で保証する。
func test_最終ランクの試験に合格するとゲームクリア画面が表示される() -> void:
	var main := _make_main()
	_setup_ranks(FINAL_RANK_ID)
	_start_exam_via_ui(main)
	_craft_once_in_exam(main)
	_observe_endgame_signals(main)
	monitor_signals(GameState, false)

	_press_in_alchemy(main, "AdvanceExamTurnButton")

	await assert_signal(GameState).is_emitted("exam_outcome_confirmed", [ExamOutcome.Value.SUCCESS])
	await assert_signal(GameState).is_emitted("game_cleared")
	assert_array(_event_order).contains_exactly(["exam_outcome_confirmed", "game_cleared"])
	# SUCCESS受信直後は暫定でworkshopが表示され、直後のgame_clearedがresultへ上書きする
	assert_that(_phase_at_outcome_confirmed).is_equal(&"workshop")
	assert_that(main.get_visible_phase()).is_equal(&"result")
	assert_int(_result_screen(main).get_result_kind()).is_equal(ResultScreen.ResultKind.CLEAR)
	assert_bool(_workshop_screen(main).visible).is_false()
	assert_bool(main.get_is_garden_tab_disabled()).is_true()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_true()
	assert_bool(GameState.is_game_cleared()).is_true()
	# FR-404。最終ランクでは昇格せずcurrent_rank_idが不変のまま終局する
	assert_that(GameState.get_state()["current_rank_id"]).is_equal(FINAL_RANK_ID)


# 正常系: 不合格分岐（FR-110）


func test_試験に不合格でも庭画面から再挑戦できる() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	_start_exam_via_ui(main)
	monitor_signals(GameState, false)

	_exhaust_exam_turns(main)

	await assert_signal(GameState).is_emitted("exam_outcome_confirmed", [ExamOutcome.Value.FAILURE])
	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_int(GameState.get_state()["demotion_count"]).is_equal(1)
	assert_bool(GameState.get_state()["in_exam"]).is_false()
	assert_bool(GameState.is_game_over()).is_false()
	# FR-201解除。再挑戦のためタブ操作が復帰していること
	assert_bool(main.get_is_garden_tab_disabled()).is_false()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_false()

	_press_tab(main, "AlchemyTabButton")

	assert_that(main.get_visible_phase()).is_equal(&"alchemy")


# 正常系: ゲームオーバー（FR-112, FR-113, FR-202）


## 【本Planの受入の中核】試験不合格と同時のゲームオーバー確定。
## exam_outcome_confirmed → game_overの順で同一フレーム内に発行され、
## 暫定のgarden遷移がresultへ上書き確定することをUI操作経由で保証する。
func test_規定回数連続降格するとゲームオーバー画面が表示される() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 1)
	_start_exam_via_ui(main)
	_observe_endgame_signals(main)
	monitor_signals(GameState, false)

	_exhaust_exam_turns(main)

	await assert_signal(GameState).is_emitted("exam_outcome_confirmed", [ExamOutcome.Value.FAILURE])
	await assert_signal(GameState).is_emitted("game_over", [GameBalance.MAX_DEMOTION_COUNT])
	assert_array(_event_order).contains_exactly(["exam_outcome_confirmed", "game_over"])
	# FAILURE受信直後は暫定でgardenが表示され、直後のgame_overがresultへ上書きする
	assert_that(_phase_at_outcome_confirmed).is_equal(&"garden")
	assert_that(main.get_visible_phase()).is_equal(&"result")
	assert_int(_result_screen(main).get_result_kind()).is_equal(ResultScreen.ResultKind.OVER)
	assert_bool(main.get_is_garden_tab_disabled()).is_true()
	assert_bool(main.get_is_alchemy_tab_disabled()).is_true()
	assert_bool(GameState.is_game_over()).is_true()


# 境界値


## 連続降格回数が閾値の1つ手前で不合格になった場合はgame_overが発行されず、
## 再挑戦のためgardenへ戻ることを確認する（ゲームオーバー境界の直前側）。
func test_降格回数が閾値の1つ手前なら不合格でもゲームオーバーにならない() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 2)
	_start_exam_via_ui(main)
	_observe_endgame_signals(main)

	_exhaust_exam_turns(main)

	assert_array(_event_order).contains_exactly(["exam_outcome_confirmed"])  # game_overは発行されない
	assert_that(main.get_visible_phase()).is_equal(&"garden")
	assert_int(GameState.get_state()["demotion_count"]).is_equal(GameBalance.MAX_DEMOTION_COUNT - 1)
	assert_bool(GameState.is_game_over()).is_false()
	assert_int(_result_screen(main).get_result_kind()).is_equal(ResultScreen.ResultKind.NONE)


## 制限ターンの最終ターンに到達する手前（1回だけ「ターンを進める」）では結果が確定せず、
## 試験画面に留まったままであることを確認する（制限ターン到達境界の直前側）。
func test_試験の制限ターン到達前は結果が確定せず調合画面に留まる() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	_start_exam_via_ui(main)
	_observe_endgame_signals(main)

	_press_in_alchemy(main, "AdvanceExamTurnButton")

	# CONTINUEのみが発行され、SUCCESS/FAILUREはまだ確定していない
	assert_bool(_event_order.is_empty()).is_true()
	assert_bool(GameState.get_state()["in_exam"]).is_true()
	assert_that(main.get_visible_phase()).is_equal(&"alchemy")
	assert_bool(main.get_is_garden_tab_disabled()).is_true()


# 異常系: 終局確定後の再操作（FR-113冪等ガード, FR-403）


## ゲームクリア確定後に試験UIを再操作しても、commit_exam_outcome()のis_game_cleared()ガードにより
## 状態もフェーズも変化しない（game_clearedも再発行されない）。
func test_ゲームクリア確定後に試験UIを再操作しても画面が変化しない() -> void:
	var main := _make_main()
	_setup_ranks(FINAL_RANK_ID)
	_start_exam_via_ui(main)
	_craft_once_in_exam(main)
	_press_in_alchemy(main, "AdvanceExamTurnButton")
	_observe_endgame_signals(main)

	_press_in_alchemy(main, "AdvanceExamTurnButton")
	_press_in_alchemy(main, "EndTurnButton")

	assert_bool(_event_order.is_empty()).is_true()
	assert_that(main.get_visible_phase()).is_equal(&"result")
	assert_int(_result_screen(main).get_result_kind()).is_equal(ResultScreen.ResultKind.CLEAR)


## ゲームオーバー確定後に試験UIを再操作しても、commit_exam_outcome()のis_game_over()ガードにより
## 状態もフェーズも変化しない（game_overも再発行されない）。
func test_ゲームオーバー確定後に試験UIを再操作しても画面が変化しない() -> void:
	var main := _make_main()
	_setup_ranks(NON_FINAL_RANK_ID)
	GameState._set_demotion_count_for_test(GameBalance.MAX_DEMOTION_COUNT - 1)
	_start_exam_via_ui(main)
	_exhaust_exam_turns(main)
	_observe_endgame_signals(main)

	_press_in_alchemy(main, "AdvanceExamTurnButton")
	_press_in_alchemy(main, "EndTurnButton")

	assert_bool(_event_order.is_empty()).is_true()
	assert_that(main.get_visible_phase()).is_equal(&"result")
	assert_int(_result_screen(main).get_result_kind()).is_equal(ResultScreen.ResultKind.OVER)
	assert_int(GameState.get_state()["demotion_count"]).is_equal(GameBalance.MAX_DEMOTION_COUNT)
