extends GdUnitTestSuite

## 日替わり指定依頼の「初回抽選 → 調合画面での提示 → 合致納品によるボーナス反映 →
## ターン終了での再抽選 → 表示追随」を、main.tscnのシーングラフ越しのUI操作だけで通す結合シナリオ。
##
## 抽選ロジック（DailyOrderSelector）・納品計算（DeliveryResolver）・GameState単体の
## ライフサイクルは既存テスト（test_daily_order_selector.gd / test_delivery_resolver.gd /
## test_game_state_daily_order_lifecycle.gd）がカバー済みのため、本ファイルは
## 「実データ + UI配線がそれらの結果へ到達するか」のみを扱う。

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

const SEED_HERB_ID: StringName = &"seed_herb"  # 🔵 GameBalance.INITIAL_SEED_ID
const MATERIAL_HERB_ID: StringName = &"material_herb"
const HEALING_POTION_ID: StringName = &"recipe_healing_potion"  # 🔵 GameBalance.INITIAL_RECIPE_ID
const MANA_TONIC_ID: StringName = &"recipe_mana_tonic"

const CONDITION_TYPE_ITEM := "item"
const CONDITION_TYPE_TRAIT := "trait"

## rank_gの実データはquota_max=10.0で、回復薬（base_contribution=10.0）1個の納品だけで
## ノルマを使い切り昇格試験へ入ってしまう。指定依頼の検証に試験開始を巻き込まないための余裕値
const SPACIOUS_QUOTA := 100.0

## 試験中のターン進行を1回挟んでも結果が確定しない（＝試験が継続する）だけの制限ターン数
const EXAM_TURN_LIMIT := 5

const FLOAT_TOLERANCE := 0.0001

## 再抽選が「別の依頼」を引くシードの探索上限。プールが2件なら数回で必ず見つかる
const SEED_SEARCH_LIMIT := 100

# 🔴 コードレビュー指摘対応。test_game_state_daily_order_lifecycle.gdと重複していた
# _current_pool()の実装をtests/mocks/daily_order_pool.gdへ統合した
const DailyOrderPool = preload("res://tests/mocks/daily_order_pool.gd")

var _crafted_products: Array[ProductInstance] = []
var _delivery_results: Array[DeliveryResult] = []


func before_test() -> void:
	GameState.reset_for_test()
	_crafted_products = []
	_delivery_results = []


func after_test() -> void:
	# GameStateはAutoloadでテストより寿命が長いため明示的に解除する
	if GameState.product_crafted.is_connected(_on_product_crafted_for_record):
		GameState.product_crafted.disconnect(_on_product_crafted_for_record)
	if GameState.delivered.is_connected(_on_delivered_for_record):
		GameState.delivered.disconnect(_on_delivered_for_record)


# --- 観測用レコーダ ---


## 🔵 product_crafted/deliveredは引数付きのため、assert_signal()では発行内容を取り出せない。
## test_main_scene_happy_path.gdの_record_crafted_products()と同じく専用レコーダで記録する
func _record_signals() -> void:
	GameState.product_crafted.connect(_on_product_crafted_for_record)
	GameState.delivered.connect(_on_delivered_for_record)


func _on_product_crafted_for_record(product: ProductInstance) -> void:
	_crafted_products.append(product)


func _on_delivered_for_record(results: Array) -> void:
	for result in results:
		_delivery_results.append(result as DeliveryResult)


# --- セットアップヘルパー ---


## 🔴 MainScene._enter_tree()がload_*_master_data()で実データを読み込むため、
## テスト側のフィクスチャ注入は必ずシーン生成の「後」に行う
func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


func _relax_rank_quota() -> void:
	var rank_state := RankState.new()
	rank_state.quota = SPACIOUS_QUOTA
	rank_state.elapsed_turn = 0
	GameState._set_rank_state_for_test(rank_state)


func _inject_material(instance_id: String, quality: int) -> void:
	GameState._inject_material_for_test(
		MaterialInstance.new(instance_id, MATERIAL_HERB_ID, quality, [] as Array[StringName])
	)


## 抽選プールを2件へ広げ、再抽選が実際に候補を切り替えうる状態にする
## （data/daily_orders/にcondition_type=="item"で対応するエントリが存在する2レシピを解禁する）
func _unlock_second_recipe() -> void:
	var ids: Array[StringName] = [HEALING_POTION_ID, MANA_TONIC_ID]
	GameState._set_unlocked_recipe_ids_for_test(ids)


## 試験中（in_exam）状態へ直接遷移させる。
## 🟡 exam_started発行を伴う本番経路（commit_rank_outcome -> PROMOTION_ELIGIBLE）は
## ランクマスター一式の差し替えが必要で本スイートの関心（指定依頼の扱い）を薄めるため、
## 既存のテスト専用APIで同じ観測条件（_in_exam == true）だけを作る
func _enter_exam() -> void:
	var exam_state := ExamState.new()
	exam_state.exam_quota = SPACIOUS_QUOTA
	exam_state.exam_quota_max = SPACIOUS_QUOTA
	exam_state.exam_turn_limit = EXAM_TURN_LIMIT
	GameState._set_exam_state_for_test(exam_state, true)


## 現在の解禁状況での抽選プールを、本番実装（GameStateGuildDelegate.reroll_daily_order）と
## 同じ条件でテスト側にも再現する
func _current_pool() -> Array[DailyOrderMaster]:
	return DailyOrderPool.current_pool()


## 「Gランク相当（解禁レシピ1件・特性未解禁）で、その1件を対象とする.tresが存在しない」状況を作る。
## 実データのdaily_ordersからcondition_type=="trait"のエントリだけを残すと、
## 特性未解禁のrank_gでは達成可能な依頼が0件になる。
## 🟡 マスター配列への直接代入はtest_game_state_daily_order_lifecycle.gdの既存パターンに倣う
## （本タスクのためだけにテスト専用APIを新設しない）
func _restrict_to_unachievable_orders() -> void:
	var trait_only: Array[DailyOrderMaster] = []
	for order in GameState._daily_order_masters:
		if order.condition_type == CONDITION_TYPE_TRAIT:
			trait_only.append(order)
	assert_int(trait_only.size()).is_greater(0)

	GameState._daily_order_masters = trait_only
	GameStateGuildDelegate.reroll_daily_order(GameState)


## poolから現在の依頼とは別のエントリが引かれるRngServiceのシードを探す。
## 🔴 プール内の並び順（MasterDataLoaderのロード順）に依存した固定シードを埋め込むと、
## .tresの増減で無言のうちに「変化しない再抽選」を検証してしまうため、実際に引いて確かめる
func _find_seed_selecting_other_order(
	pool: Array[DailyOrderMaster], current: DailyOrderMaster
) -> int:
	for candidate in range(1, SEED_SEARCH_LIMIT):
		RngService.set_seed(candidate)
		if DailyOrderSelector.select(pool, RngService.randf()) != current:
			return candidate
	fail("現在の指定依頼と異なる候補を引くシードが見つかりませんでした")
	return 0


# --- ノード取得ヘルパー ---


func _garden(main: MainScene) -> GardenScreen:
	return main.find_child("GardenScreen", true, false) as GardenScreen


func _alchemy(main: MainScene) -> AlchemyScreen:
	return main.find_child("AlchemyScreen", true, false) as AlchemyScreen


func _delivery_screen(main: MainScene) -> GuildDeliveryScreen:
	return _alchemy(main).find_child("GuildDeliveryScreen", true, false) as GuildDeliveryScreen


func _preview_panel(main: MainScene) -> AlchemyPreviewPanel:
	return _alchemy(main).find_child("AlchemyPreviewPanel", true, false) as AlchemyPreviewPanel


func _daily_order_label_text(main: MainScene) -> String:
	return (_alchemy(main).find_child("DailyOrderLabel", true, false) as Label).text


# --- UI操作ヘルパー ---


## 🔵 EndTurnButton/ShopButtonは庭・調合の双方に同名で存在するため、画面内ボタンを押すときは
## 必ず対象画面をrootに指定して探索範囲を絞る
func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_object(button).is_not_null()
	button.pressed.emit()


func _press_plant(main: MainScene, seed_id: StringName) -> void:
	var list := _garden(main).find_child("SeedInventoryList", true, false) as SeedInventoryList
	var row := list.find_child("SeedEntry_%s" % seed_id, true, false) as SeedEntryRow
	assert_object(row).is_not_null()
	_press(row, "PlantButton")


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


## 調合画面でレシピ選択→素材投入までを行う（ライブプレビューが確定した状態で止める）。
## 🔴 ExecuteButtonまで押すと投入素材が在庫から消えて_refresh()が投入枠を空に戻すため、
## プレビューの検証は必ず本ヘルパーの直後（実行前）に行うこと
func _place_for_craft(main: MainScene, recipe_id: StringName, instance_id: String) -> void:
	var alchemy := _alchemy(main)
	_select_recipe(alchemy, recipe_id)
	_place_material(alchemy, instance_id)


# --- 期待値ヘルパー ---


## AlchemyScreen._update_daily_order_label()が組み立てるべき文言を、
## GameStateの実データ側から独立に再構成する
func _expected_label_text(order: DailyOrderMaster) -> String:
	if order == null:
		return AlchemyScreen.DAILY_ORDER_NONE_TEXT
	if order.condition_type == CONDITION_TYPE_TRAIT:
		return (
			AlchemyScreen.DAILY_ORDER_TRAIT_FORMAT
			% [order.target_trait, order.match_bonus_multiplier]
		)
	return (
		AlchemyScreen.DAILY_ORDER_ITEM_FORMAT
		% [_recipe_display_name(order.target_recipe_id), order.match_bonus_multiplier]
	)


func _recipe_display_name(recipe_id: String) -> String:
	var masters: Dictionary = GameState.get_state()["recipe_masters"]
	var master: Variant = masters.get(StringName(recipe_id))
	if master is RecipeMaster:
		return (master as RecipeMaster).name
	return recipe_id


# 正常系: 初回抽選と提示


func test_ゲーム開始直後から指定依頼が機能し画面に表示される() -> void:
	var main := _make_main()

	# 初回抽選が済んでおり、納品判定に渡せる指定依頼が解決できる
	var order := GameState.resolve_daily_order_for_delivery()
	assert_object(order).is_not_null()
	# Gランクは特性未解禁のため、達成可能なのは解禁済みレシピを対象とするitem依頼のみ
	assert_str(order.condition_type).is_equal(CONDITION_TYPE_ITEM)
	assert_str(order.target_recipe_id).is_equal(String(HEALING_POTION_ID))

	_press(main, "AlchemyTabButton")

	# 空欄ではなく、指定依頼の内容（対象レシピの表示名と倍率）が読み取れる
	var label_text := _daily_order_label_text(main)
	assert_str(label_text).is_not_equal("")
	assert_str(label_text).is_not_equal(AlchemyScreen.DAILY_ORDER_NONE_TEXT)
	assert_str(label_text).is_equal(_expected_label_text(order))
	assert_str(label_text).contains(_recipe_display_name(order.target_recipe_id))


# 正常系: 合致納品でのボーナス反映


func test_指定依頼に合致する調合物を納品するとボーナスが反映される() -> void:
	_inject_material("mat_1", 4)
	var main := _make_main()
	_relax_rank_quota()
	_record_signals()

	var order := GameState.resolve_daily_order_for_delivery()
	assert_str(order.target_recipe_id).is_equal(String(HEALING_POTION_ID))
	var multiplier := order.match_bonus_multiplier

	_press(main, "AlchemyTabButton")
	_place_for_craft(main, HEALING_POTION_ID, "mat_1")

	# 調合を実行する前のライブプレビューの時点で指定合致が提示される
	assert_bool(_preview_panel(main).is_order_matched()).is_true()

	_press(_alchemy(main), "ExecuteButton")
	var gold_before: int = GameState.get_state()["gold"]
	_press(_alchemy(main), "EndTurnButton")

	assert_int(_crafted_products.size()).is_equal(1)
	assert_int(_delivery_results.size()).is_equal(1)

	# DeliveryResolverの契約どおり、貢献度・報酬の双方が倍率ぶんだけ増えている
	var product := _crafted_products[0]
	var result := _delivery_results[0]
	assert_bool(result.order_matched).is_true()
	assert_float(result.final_contribution).is_equal_approx(
		product.contribution * multiplier, FLOAT_TOLERANCE
	)
	assert_float(result.final_reward).is_equal_approx(product.reward * multiplier, FLOAT_TOLERANCE)
	assert_int(GameState.get_state()["gold"] - gold_before).is_equal(roundi(result.final_reward))
	# 納品結果画面にもボーナス適用後の1件が表示される
	assert_bool(_delivery_screen(main).visible).is_true()
	assert_int(_delivery_screen(main).get_item_count()).is_equal(1)


# 正常系: 調合後の再抽選を挟んでも調合時点のボーナスで確定する（PR#42コードレビュー指摘の回帰テスト）


## 🔴 コードレビュー指摘対応。Garden側のEndTurn（advance_turn_growth、FR-102）はAlchemy側の
## 納品タイミングと無関係に指定依頼を再抽選しうる。調合済みだが未納品の調合物が、納品前に挟まれた
## 庭のターン終了で指定依頼が別物へすり替わっても、調合時点でライブプレビューに表示していた
## ボーナスのまま決算されることを検証する（納品時点の新しい指定依頼が誤って適用されない）
func test_調合後に庭でターン終了し指定依頼が再抽選されても納品ボーナスは調合時点のもので確定する() -> void:
	_inject_material("mat_1", 4)
	var main := _make_main()
	_relax_rank_quota()
	_unlock_second_recipe()
	_record_signals()

	var order_at_craft := GameState.resolve_daily_order_for_delivery()
	assert_str(order_at_craft.target_recipe_id).is_equal(String(HEALING_POTION_ID))
	var multiplier := order_at_craft.match_bonus_multiplier

	_press(main, "AlchemyTabButton")
	_place_for_craft(main, HEALING_POTION_ID, "mat_1")
	assert_bool(_preview_panel(main).is_order_matched()).is_true()
	_press(_alchemy(main), "ExecuteButton")

	# 納品前に庭のターン終了を挟み、指定依頼を別のものへ確実に再抽選させる
	var pool := _current_pool()
	var rng_seed := _find_seed_selecting_other_order(pool, order_at_craft)
	RngService.set_seed(rng_seed)
	_press(main, "GardenTabButton")
	_press(_garden(main), "EndTurnButton")
	assert_object(GameState._current_daily_order).is_not_same(order_at_craft)

	_press(main, "AlchemyTabButton")
	var gold_before: int = GameState.get_state()["gold"]
	_press(_alchemy(main), "EndTurnButton")

	assert_int(_delivery_results.size()).is_equal(1)
	var product := _crafted_products[0]
	var result := _delivery_results[0]
	# 納品時点の指定依頼は既に別物へ切り替わっているが、報酬は調合時点のボーナスのまま決算される
	assert_bool(result.order_matched).is_true()
	assert_float(result.final_contribution).is_equal_approx(
		product.contribution * multiplier, FLOAT_TOLERANCE
	)
	assert_float(result.final_reward).is_equal_approx(product.reward * multiplier, FLOAT_TOLERANCE)
	assert_int(GameState.get_state()["gold"] - gold_before).is_equal(roundi(result.final_reward))


# 正常系: ターン終了での再抽選と表示追随


func test_ターン終了で指定依頼が再抽選され表示が更新される() -> void:
	var main := _make_main()
	_unlock_second_recipe()

	_press(main, "AlchemyTabButton")
	var label_before := _daily_order_label_text(main)
	var order_before := GameState._current_daily_order
	assert_object(order_before).is_not_null()

	var pool := _current_pool()
	assert_int(pool.size()).is_greater(1)

	# 同一シードから払い出される乱数値で期待値を先に算出し、同じシードを再設定してから
	# 「ターンを終了する」を押すことで、再抽選結果を決定的に照合する
	var rng_seed := _find_seed_selecting_other_order(pool, order_before)
	RngService.set_seed(rng_seed)
	var expected := DailyOrderSelector.select(pool, RngService.randf())

	_press(main, "GardenTabButton")
	RngService.set_seed(rng_seed)
	_press(_garden(main), "EndTurnButton")

	assert_object(GameState._current_daily_order).is_same(expected)
	assert_object(GameState._current_daily_order).is_not_same(order_before)

	_press(main, "AlchemyTabButton")

	var label_after := _daily_order_label_text(main)
	assert_str(label_after).is_equal(_expected_label_text(expected))
	assert_str(label_after).is_not_equal(label_before)


# 異常系: 達成可能な指定依頼が存在しない構成


func test_達成可能な指定依頼が無いランクでも通しプレイが完走する() -> void:
	_inject_material("mat_1", 3)
	var main := _make_main()
	_relax_rank_quota()
	_restrict_to_unachievable_orders()
	_record_signals()

	assert_object(GameState.resolve_daily_order_for_delivery()).is_null()

	# 庭: 植付 → ターン終了（再抽選が走ってもnullのまま更新される）
	_press_plant(main, SEED_HERB_ID)
	_press(_garden(main), "EndTurnButton")
	assert_object(GameState._current_daily_order).is_null()

	# 調合: 「指定依頼: なし」を提示したまま調合できる
	_press(main, "AlchemyTabButton")
	assert_str(_daily_order_label_text(main)).is_equal(AlchemyScreen.DAILY_ORDER_NONE_TEXT)

	_place_for_craft(main, HEALING_POTION_ID, "mat_1")
	assert_bool(_preview_panel(main).is_order_matched()).is_false()

	# 納品: 倍率が一切掛からない素の貢献度・報酬で決算される
	_press(_alchemy(main), "ExecuteButton")
	_press(_alchemy(main), "EndTurnButton")

	assert_int(_delivery_results.size()).is_equal(1)
	var product := _crafted_products[0]
	var result := _delivery_results[0]
	assert_bool(result.order_matched).is_false()
	assert_float(result.final_contribution).is_equal_approx(product.contribution, FLOAT_TOLERANCE)
	assert_float(result.final_reward).is_equal_approx(product.reward, FLOAT_TOLERANCE)

	# 続ける → 庭へ復帰し、一巡が例外なく完走する
	_press(_delivery_screen(main), "ContinueButton")
	assert_that(GameState.get_state()["current_phase"]).is_equal(&"garden")


# 異常系: 昇格試験中のボーナス非適用（既存契約の非退行）


func test_試験中は調合プレビューと納品結果の双方でボーナスが適用されない() -> void:
	_inject_material("mat_1", 4)
	var main := _make_main()
	_record_signals()

	# 試験開始前は合致対象（回復薬）の指定依頼が出ている
	assert_str(GameState._current_daily_order.target_recipe_id).is_equal(String(HEALING_POTION_ID))

	_enter_exam()
	_press(main, "AlchemyTabButton")

	# 表示・プレビュー・納品結果のいずれも「指定依頼なし」と同じ扱いになる
	assert_str(_daily_order_label_text(main)).is_equal(AlchemyScreen.DAILY_ORDER_NONE_TEXT)

	_place_for_craft(main, HEALING_POTION_ID, "mat_1")
	# 合致対象のレシピを選んでいても、試験中のプレビューは指定合致にならない
	assert_bool(_preview_panel(main).is_order_matched()).is_false()

	# 🔵 試験中は調合成功で自動納品されるため、ExecuteButtonの押下だけで決算まで到達する
	_press(_alchemy(main), "ExecuteButton")

	assert_int(_delivery_results.size()).is_equal(1)
	var product := _crafted_products[0]
	var result := _delivery_results[0]
	assert_bool(result.order_matched).is_false()
	assert_float(result.final_contribution).is_equal_approx(product.contribution, FLOAT_TOLERANCE)
	assert_float(result.final_reward).is_equal_approx(product.reward, FLOAT_TOLERANCE)
	# 指定依頼自体は保持されたままで、試験終了後に復帰できる
	assert_object(GameState._current_daily_order).is_not_null()


# 境界値: 試験中のターン進行では再抽選しない


func test_試験中にターンを進めても指定依頼が変化しない() -> void:
	var main := _make_main()
	_unlock_second_recipe()
	_enter_exam()
	var order_before := GameState._current_daily_order
	assert_object(order_before).is_not_null()

	_press(main, "AlchemyTabButton")
	_press(_alchemy(main), "AdvanceExamTurnButton")

	assert_object(GameState._current_daily_order).is_same(order_before)
	assert_str(_daily_order_label_text(main)).is_equal(AlchemyScreen.DAILY_ORDER_NONE_TEXT)
