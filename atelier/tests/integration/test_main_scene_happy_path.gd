extends GdUnitTestSuite

## MainSceneのハッピーパス結合シナリオ（AC-018）。
## シナリオ1「庭で植付→調合タブ→調合実行→ターン終了で納品→続けるで庭復帰」と
## シナリオ2「庭/調合からの工房往復」を、main.tscnのシーングラフ越しのUI操作だけで検証する。
## GameState単体の同等フローは既存の統合テスト（test_game_state_execute_alchemy.gd等）が
## カバー済みのため、本ファイルは「UI配線がその結果へ到達するか」のみを扱う。

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SCREEN_NODE_NAMES := ["GardenScreen", "AlchemyScreen", "WorkshopScreen", "ResultScreen"]

const SEED_HERB_ID: StringName = &"seed_herb"
const SEED_HERB_DISPLAY_NAME := "薬草の種"  # 🔵 data/materials/seed_herb.tres（実マスターデータ）
const MATERIAL_HERB_ID: StringName = &"material_herb"
const HEALING_POTION_ID: StringName = &"recipe_healing_potion"  # 🔵 GameBalance.INITIAL_RECIPE_ID

## rank_gの実データはquota_max=10.0で、回復薬（base_contribution=10.0）1個を納品するだけで
## ノルマを使い切り昇格試験が始まってしまう。通常ターン1周の検証に試験を巻き込まないための余裕値。
## 🟡 試験開始側の結合シナリオはtask010（test_main_scene_exam_flow.gd）の担当範囲
const SPACIOUS_QUOTA := 100.0

var _crafted_products: Array[ProductInstance] = []


func before_test() -> void:
	GameState.reset_for_test()
	_crafted_products = []


func after_test() -> void:
	if GameState.product_crafted.is_connected(_on_product_crafted_for_record):
		GameState.product_crafted.disconnect(_on_product_crafted_for_record)


## 🔵 product_craftedは引数を1つ取るため、assert_signal(...).is_emitted("product_crafted")では
## 「引数なしでの発行」を期待した扱いになり一致しない。test_main_scene_tab_bar.gdの
## _record_phase_changes()と同じく、専用レコーダで発行内容ごと記録する
func _record_crafted_products() -> void:
	GameState.product_crafted.connect(_on_product_crafted_for_record)


func _on_product_crafted_for_record(product: ProductInstance) -> void:
	_crafted_products.append(product)


# --- セットアップヘルパー ---


func _make_main() -> MainScene:
	var runner := scene_runner(MAIN_SCENE_PATH)
	return runner.scene() as MainScene


## 実マスターデータのノルマでは1回の納品で昇格試験へ入ってしまうため、ノルマ残量だけを緩める。
## 🔵 MainSceneの_enter_tree()がload_rank_master_data()でRankStateを初期化するため、
## 必ずシーン生成後に呼ぶ
func _relax_rank_quota() -> void:
	var rank_state := RankState.new()
	rank_state.quota = SPACIOUS_QUOTA
	rank_state.elapsed_turn = 0
	GameState._set_rank_state_for_test(rank_state)


func _inject_material(instance_id: String, quality: int) -> void:
	GameState._inject_material_for_test(
		MaterialInstance.new(instance_id, MATERIAL_HERB_ID, quality, [] as Array[StringName])
	)


# --- ノード取得ヘルパー ---


func _garden(main: MainScene) -> GardenScreen:
	return main.find_child("GardenScreen", true, false) as GardenScreen


func _alchemy(main: MainScene) -> AlchemyScreen:
	return main.find_child("AlchemyScreen", true, false) as AlchemyScreen


func _workshop(main: MainScene) -> WorkshopScreen:
	return main.find_child("WorkshopScreen", true, false) as WorkshopScreen


func _rank_hud(main: MainScene) -> RankHud:
	return main.find_child("RankHud", true, false) as RankHud


func _seed_list(main: MainScene) -> SeedInventoryList:
	return _garden(main).find_child("SeedInventoryList", true, false) as SeedInventoryList


func _delivery_screen(main: MainScene) -> GuildDeliveryScreen:
	return _alchemy(main).find_child("GuildDeliveryScreen", true, false) as GuildDeliveryScreen


## 4画面のうちvisible == trueのノード名を列挙する（test_main_scene_tab_bar.gd踏襲）
func _visible_screen_names(main: MainScene) -> Array[String]:
	var names: Array[String] = []
	for node_name in SCREEN_NODE_NAMES:
		var screen := main.find_child(node_name, true, false) as Control
		if screen != null and screen.visible:
			names.append(node_name)
	return names


# --- UI操作ヘルパー ---


## rootの配下からnode_nameのButtonを探して押下をシミュレートする。
## 🔵 EndTurnButton/ShopButtonは庭・調合の双方に同名で存在するため、必ず対象画面を
## rootに指定して探索範囲を絞る
func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_object(button).is_not_null()
	button.pressed.emit()


func _press_plant(main: MainScene, seed_id: StringName) -> void:
	var row := _seed_list(main).find_child("SeedEntry_%s" % seed_id, true, false) as SeedEntryRow
	assert_object(row).is_not_null()
	_press(row, "PlantButton")


func _seed_entry_name(main: MainScene, seed_id: StringName) -> String:
	var row := _seed_list(main).find_child("SeedEntry_%s" % seed_id, true, false) as SeedEntryRow
	return (row.find_child("NameLabel", true, false) as Label).text


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


func _press_delivery_continue(main: MainScene) -> void:
	_press(_delivery_screen(main), "ContinueButton")


# --- 状態取得ヘルパー ---


func _gold() -> int:
	return GameState.get_state()["gold"]


func _pending_products() -> Array:
	return GameState.get_state()["pending_products"]


func _inventory() -> Array:
	return GameState.get_state()["inventory"]


## 4画面とMainScene自身のインスタンスIDを控える。change_scene_to_file()による画面の
## 破棄・再生成が起きていないことの代替観測点（NFR-001）
func _screen_instance_ids(main: MainScene) -> Array[int]:
	var ids: Array[int] = [main.get_instance_id()]
	for node_name in SCREEN_NODE_NAMES:
		ids.append(main.find_child(node_name, true, false).get_instance_id())
	return ids


# 正常系（シナリオ1: 通常ターン1周）


func test_通常ターンを1周して庭に復帰する() -> void:
	_inject_material("mat_1", 4)
	var main := _make_main()
	_relax_rank_quota()
	var instance_ids_before := _screen_instance_ids(main)

	# 起動直後は庭のみ可視で、種一覧が実マスターデータの表示名を持つ
	assert_array(_visible_screen_names(main)).contains_exactly(["GardenScreen"])
	assert_int(_seed_list(main).get_entry_count()).is_equal(1)
	assert_str(_seed_entry_name(main, SEED_HERB_ID)).is_equal(SEED_HERB_DISPLAY_NAME)

	# 庭で植付 → garden_stateへ反映される
	_press_plant(main, SEED_HERB_ID)
	var garden_state: GardenState = GameState.get_state()["garden_state"]
	assert_int(garden_state.plants.size()).is_equal(1)
	assert_that(garden_state.plants[0].seed_id).is_equal(SEED_HERB_ID)

	# 調合タブ押下 → 調合画面のみ可視
	_press(main, "AlchemyTabButton")
	assert_array(_visible_screen_names(main)).contains_exactly(["AlchemyScreen"])

	# レシピ選択・素材投入・調合実行 → product_crafted発行・在庫消費
	var alchemy := _alchemy(main)
	_record_crafted_products()
	_select_recipe(alchemy, HEALING_POTION_ID)
	_place_material(alchemy, "mat_1")
	_press(alchemy, "ExecuteButton")

	assert_int(_crafted_products.size()).is_equal(1)
	assert_int(_crafted_products[0].quality_score).is_equal(4)
	assert_array(_inventory()).is_empty()
	assert_int(_pending_products().size()).is_equal(1)

	# ターン終了 → 納品結果が表示され、RankHudのゴールドが報酬分だけ増える
	var gold_before := _gold()
	_press(alchemy, "EndTurnButton")

	assert_bool(_delivery_screen(main).visible).is_true()
	assert_int(_delivery_screen(main).get_item_count()).is_equal(1)
	assert_int(_pending_products().size()).is_equal(0)
	assert_int(_gold()).is_greater(gold_before)
	assert_str(_rank_hud(main).get_gold_text()).contains(str(_gold()))

	# 続ける → 結果を畳んで庭フェーズへ復帰する
	_press_delivery_continue(main)

	assert_bool(_delivery_screen(main).visible).is_false()
	assert_that(GameState.get_state()["current_phase"]).is_equal(&"garden")
	assert_array(_visible_screen_names(main)).contains_exactly(["GardenScreen"])

	# シナリオ全体を通じてシーン遷移が発生していない（NFR-001）
	assert_array(_screen_instance_ids(main)).contains_exactly(instance_ids_before)


# 正常系（シナリオ2: 工房往復）


func test_調合からの工房往復で調合画面に復帰する() -> void:
	var main := _make_main()
	var instance_ids_before := _screen_instance_ids(main)
	_press(main, "AlchemyTabButton")

	_press(_alchemy(main), "ShopButton")

	assert_that(GameState.get_state()["current_phase"]).is_equal(&"workshop")
	assert_array(_visible_screen_names(main)).contains_exactly(["WorkshopScreen"])

	_press(_workshop(main), "CloseButton")

	assert_that(GameState.get_state()["current_phase"]).is_equal(&"alchemy")
	assert_array(_visible_screen_names(main)).contains_exactly(["AlchemyScreen"])
	assert_array(_screen_instance_ids(main)).contains_exactly(instance_ids_before)


func test_庭からの工房往復で庭画面に復帰する() -> void:
	var main := _make_main()

	_press(_garden(main), "ShopButton")

	assert_array(_visible_screen_names(main)).contains_exactly(["WorkshopScreen"])

	_press(_workshop(main), "CloseButton")

	assert_that(GameState.get_state()["current_phase"]).is_equal(&"garden")
	assert_array(_visible_screen_names(main)).contains_exactly(["GardenScreen"])


# 境界値


func test_納品対象が0件のターン終了でも続けるで庭へ復帰する() -> void:
	var main := _make_main()
	_relax_rank_quota()
	_press(main, "AlchemyTabButton")

	_press(_alchemy(main), "EndTurnButton")

	assert_int(_delivery_screen(main).get_item_count()).is_equal(0)
	assert_bool(_delivery_screen(main).visible).is_true()

	_press_delivery_continue(main)

	assert_array(_visible_screen_names(main)).contains_exactly(["GardenScreen"])


func test_工房往復を挟んでも通常ターンの納品フローが継続できる() -> void:
	_inject_material("mat_1", 3)
	var main := _make_main()
	_relax_rank_quota()
	_press(main, "AlchemyTabButton")

	# 調合前に工房へ寄り道して戻る
	_press(_alchemy(main), "ShopButton")
	_press(_workshop(main), "CloseButton")
	assert_array(_visible_screen_names(main)).contains_exactly(["AlchemyScreen"])

	var alchemy := _alchemy(main)
	_select_recipe(alchemy, HEALING_POTION_ID)
	_place_material(alchemy, "mat_1")
	_press(alchemy, "ExecuteButton")
	_press(alchemy, "EndTurnButton")

	assert_int(_delivery_screen(main).get_item_count()).is_equal(1)
	assert_int(_gold()).is_greater(0)


# 異常系


func test_納品結果が未表示でも続けるの強制発行で庭へ遷移するのみでクラッシュしない() -> void:
	var main := _make_main()
	_press(main, "AlchemyTabButton")

	# 一度も納品していない（GuildDeliveryScreenがvisible == false）状態で「続ける」を強制発行する
	assert_bool(_delivery_screen(main).visible).is_false()
	_press_delivery_continue(main)

	assert_that(GameState.get_state()["current_phase"]).is_equal(&"garden")
	assert_array(_visible_screen_names(main)).contains_exactly(["GardenScreen"])
