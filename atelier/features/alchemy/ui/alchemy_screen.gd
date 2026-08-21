class_name AlchemyScreen
extends Control

## 調合画面本体。AlchemySlotView・MaterialInventoryList・AlchemyPreviewPanel・レシピ選択・
## 調合実行/ターン終了/ショップボタンを統合し、GameStateのsignalを購読して画面を更新する
## （US-001〜US-203, US-301〜US-302, AC-004〜AC-014）。
## 🔵 本タスクの完了をもって「MainSceneへの組み込みは別task」（FR-405, CON-005）とする
## スコープ境界を厳守する。タブ切替・visible制御・シーン遷移は一切実装しない。

signal shop_requested  # 🔵 FR-110（プレースホルダー導線。GardenScreen.shop_requested踏襲）

const AlchemySlotViewScene = preload("res://features/alchemy/ui/alchemy_slot_view.tscn")
const RECIPE_PLACEHOLDER_TEXT := "選択してください"
const ERROR_MESSAGES := {
	&"unknown_recipe_id": "レシピが見つかりませんでした",
	&"recipe_not_unlocked": "このレシピはまだ解禁されていません",
	&"material_not_owned": "投入した素材が在庫にありません",
	&"duplicate_material_in_slot": "同じ素材を重複して投入しています",
	&"slot_execution_invalid": "投入内容が調合の条件を満たしていません",
}  # 🟡 ui-design/screens/alchemy.mdが文言未確定（🟡TBD）のため、error_codeから妥当な推測で新規決定

# 🔵 投入順=スロット表示順の唯一のソース・オブ・トゥルース。
# 「投入済み」はドメイン層にもGameStateにも存在しないUIローカルな一時状態のため本画面が保持する
var _placed_material_ids: Array[String] = []
var _slot_state: SlotState = SlotState.new()
var _recipe_masters: Dictionary = {}  # 🔵 StringName -> RecipeMaster。get_state()から都度キャッシュ
var _inventory: Array[MaterialInstance] = []  # 🔵 get_state()から都度キャッシュ
# 🔴 コードレビュー指摘対応。_recompute_preview()のたびにGameState.get_state()を再度フル呼び出し
# していた（_inventory/_recipe_masters同様に_refresh()時点でキャッシュすべきコスト）のを解消する。
# GameState.resolve_daily_order_for_delivery()経由で取得するため、試験中(_in_exam)は
# 自動的にnullとなり、実際の納品処理と同じ指定依頼の扱いになる（プレビューと実結果の乖離防止）
var _daily_order_for_preview: DailyOrderMaster = null
var _slot_views: Array[AlchemySlotView] = []

@onready var _recipe_option_button: OptionButton = %RecipeOptionButton
@onready var _slots_container: Container = %SlotsContainer
@onready var _material_inventory_list: MaterialInventoryList = %MaterialInventoryList
@onready var _preview_panel: AlchemyPreviewPanel = %AlchemyPreviewPanel
@onready var _execute_button: Button = %ExecuteButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _shop_button: Button = %ShopButton
@onready var _toast_label: Label = %ToastLabel


func _ready() -> void:
	_recipe_option_button.item_selected.connect(_on_recipe_selected)
	_execute_button.pressed.connect(_on_execute_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_material_inventory_list.material_place_requested.connect(_on_material_place_requested)

	# 🔵 GameStateはAutoloadのため_exit_tree()での明示的disconnect()が必須（ui-components.md）
	GameState.product_crafted.connect(_on_product_crafted)
	GameState.execute_alchemy_failed.connect(_on_execute_alchemy_failed)
	GameState.delivered.connect(_on_delivered)

	_refresh()


func _exit_tree() -> void:
	if GameState.product_crafted.is_connected(_on_product_crafted):
		GameState.product_crafted.disconnect(_on_product_crafted)
	if GameState.execute_alchemy_failed.is_connected(_on_execute_alchemy_failed):
		GameState.execute_alchemy_failed.disconnect(_on_execute_alchemy_failed)
	if GameState.delivered.is_connected(_on_delivered):
		GameState.delivered.disconnect(_on_delivered)


## 現在表示中のトーストメッセージを返す（テスト用）。🔵 GardenScreen.get_toast_text()踏襲
func get_toast_text() -> String:
	if _toast_label == null:
		return ""
	return _toast_label.text


## error_codeに対応するトースト文言を返す。未知のコードもそのまま提示して沈黙させない。🔵 AC-009
static func error_message(error_code: StringName) -> String:
	if ERROR_MESSAGES.has(error_code):
		return ERROR_MESSAGES[error_code]
	return "調合に失敗しました（%s）" % error_code


## GameState.get_state()を再取得し、レシピ一覧・スロット一覧・在庫一覧・プレビューを再構築する。🔵
func _refresh() -> void:
	if _slots_container == null:
		return

	var state := GameState.get_state()
	_recipe_masters = state["recipe_masters"]
	_inventory = state["inventory"]
	_slot_state.max_slots = state["alchemy_slot_count"]
	# 🔴 コードレビュー指摘対応。_recompute_preview()側でGameState.get_state()を再度呼ばずに済むよう
	# ここでキャッシュする。GameState側のロジックと同一の式（試験中はnull）を経由する
	_daily_order_for_preview = GameState.resolve_daily_order_for_delivery()

	# 🔵 在庫から消えた素材（調合実行で消費された等）が投入枠に残らないよう先に整合を取る
	_drop_missing_placed_ids()

	_rebuild_recipe_options(state["unlocked_recipe_ids"])
	_rebuild_slots()
	_material_inventory_list.setup(_available_materials())
	_on_preview_inputs_changed()


## ローカルキャッシュのみでプレビュー再計算とボタン活性状態を更新する。
## 🟡 投入操作のたびにGameState.get_state()（inventory/pending_productsのディープコピーを伴う）を
## 呼ぶとコストが嵩むため、素材の解決はキャッシュ済みの_inventoryから行う
func _on_preview_inputs_changed() -> void:
	var materials := _placed_materials()
	_slot_state.materials = materials
	_recompute_preview(materials)
	if _execute_button != null:
		_execute_button.disabled = not _slot_state.can_execute()  # 🔵 AC-010


## ProductProvisionalResolver（QualityCalculator -> TraitActivation -> ProductValueCalculator の
## 3段階パイプライン） -> DeliveryResolver を同期呼び出しし、AlchemyPreviewPanelへ結果を渡す。🔵 AC-007
## 🔴 コードレビュー指摘対応。GameStateAlchemyDelegate.execute_alchemy()と同一の
## ProductProvisionalResolverを経由することで両者の計算結果が乖離しないようにし、
## 指定依頼の判定にも_refresh()でキャッシュ済みの_daily_order_for_preview（試験中はnull）を使う
## ことで、実際の納品処理（GameStateGuildDelegate.deliver_pending_products）と同じ扱いにする
func _recompute_preview(materials: Array[MaterialInstance]) -> void:
	if _preview_panel == null:
		return
	var recipe: Variant = _recipe_masters.get(_slot_state.selected_recipe_id)
	if materials.is_empty() or not (recipe is RecipeMaster):
		_preview_panel.show_empty()  # 🔵 AC-007異常系。レシピ未選択・0投入では計算自体を行わない
		return

	var traits_unlocked := GameState.is_current_rank_traits_unlocked()
	var provisional := ProductProvisionalResolver.resolve(
		materials, recipe as RecipeMaster, traits_unlocked
	)
	var result := DeliveryResolver.resolve(provisional, _daily_order_for_preview)

	_preview_panel.show_preview(
		provisional.quality_score,
		provisional.activated_traits,
		result.final_contribution,
		result.final_reward,
		result.order_matched
	)


## 解禁済みレシピからドロップダウンを再構築する。選択中のレシピが解禁一覧から消えた場合は選択を解除する。🔵
func _rebuild_recipe_options(unlocked_recipe_ids: Array) -> void:
	_recipe_option_button.clear()
	# 🔵 item 0は未選択プレースホルダー。metadataを持たせず、選択不可にする
	_recipe_option_button.add_item(RECIPE_PLACEHOLDER_TEXT)
	_recipe_option_button.set_item_disabled(0, true)

	var selected_index := 0
	for recipe_id in unlocked_recipe_ids:
		var master: Variant = _recipe_masters.get(recipe_id)
		if not (master is RecipeMaster):
			continue
		_recipe_option_button.add_item((master as RecipeMaster).name)
		var index := _recipe_option_button.item_count - 1
		_recipe_option_button.set_item_metadata(index, recipe_id)
		if recipe_id == _slot_state.selected_recipe_id:
			selected_index = index

	if selected_index == 0:
		_slot_state.selected_recipe_id = &""
	_recipe_option_button.select(selected_index)


## _placed_material_idsに対応するAlchemySlotViewを枠数ぶん並べ直す。🔵 AC-003
func _rebuild_slots() -> void:
	for child in _slots_container.get_children():
		_slots_container.remove_child(child)
		child.queue_free()
	_slot_views.clear()

	var placed := _placed_materials()
	for slot_index in range(_slot_state.max_slots):
		var slot_view: AlchemySlotView = AlchemySlotViewScene.instantiate()
		slot_view.name = "AlchemySlot_%d" % slot_index
		_slots_container.add_child(slot_view)
		slot_view.clear_requested.connect(_on_slot_clear_requested)
		if slot_index < placed.size():
			slot_view.setup(slot_index, placed[slot_index])
		else:
			slot_view.setup_empty(slot_index)
		_slot_views.append(slot_view)


## 投入済みIDに対応するMaterialInstanceをキャッシュ済み在庫から解決する。🔵
func _placed_materials() -> Array[MaterialInstance]:
	var materials: Array[MaterialInstance] = []
	for instance_id in _placed_material_ids:
		var material := _find_material(instance_id)
		if material != null:
			materials.append(material)
	return materials


## 在庫から投入済みを除外した配列を返す。🔵 除外責務はMaterialInventoryListではなく本画面が持つ契約
func _available_materials() -> Array[MaterialInstance]:
	var materials: Array[MaterialInstance] = []
	for material in _inventory:
		if not _placed_material_ids.has(material.instance_id):
			materials.append(material)
	return materials


func _find_material(instance_id: String) -> MaterialInstance:
	for material in _inventory:
		if material.instance_id == instance_id:
			return material
	return null


# 🔵 在庫に存在しなくなった投入済みIDを取り除く。調合成功時のリセットもこの経路で成立する
func _drop_missing_placed_ids() -> void:
	var kept: Array[String] = []
	for instance_id in _placed_material_ids:
		if _find_material(instance_id) != null:
			kept.append(instance_id)
	_placed_material_ids = kept


func _on_recipe_selected(index: int) -> void:
	# 🔵 item 0はプレースホルダーのため選択として扱わない
	if index <= 0:
		return
	var metadata: Variant = _recipe_option_button.get_item_metadata(index)
	if not (metadata is StringName):
		return
	_slot_state.selected_recipe_id = metadata
	_on_preview_inputs_changed()


func _on_material_place_requested(material_instance_id: String) -> void:
	# 🔵 FR-203（投入枠上限）と二重投入の防御。どちらも無効操作のため何もしない
	if _placed_material_ids.size() >= _slot_state.max_slots:
		return
	if _placed_material_ids.has(material_instance_id):
		return
	if _find_material(material_instance_id) == null:
		return

	_placed_material_ids.append(material_instance_id)
	_rebuild_slots()
	_material_inventory_list.setup(_available_materials())
	_on_preview_inputs_changed()


func _on_slot_clear_requested(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _placed_material_ids.size():
		return
	_placed_material_ids.remove_at(slot_index)  # 🔵 AC-005。投入順を詰めてスロット表示順と一致させる
	_rebuild_slots()
	_material_inventory_list.setup(_available_materials())
	_on_preview_inputs_changed()


# 🔵 GardenScreen._on_seed_plant_requested()と同一パターン。戻り値のResultは使わず、
# 結果はproduct_crafted/execute_alchemy_failedシグナル経由でのみ処理する
func _on_execute_pressed() -> void:
	GameState.execute_alchemy(_slot_state.selected_recipe_id, _placed_material_ids.duplicate())


# 🔵 FR-108のプレースホルダー実装。deliver_pending_products()以外は呼ばない
func _on_end_turn_pressed() -> void:
	GameState.deliver_pending_products()


func _on_shop_pressed() -> void:
	shop_requested.emit()


func _on_product_crafted(product: ProductInstance) -> void:
	# 🔵 AC-008。投入素材は在庫から消費済みのため、_refresh()で投入枠が空にリセットされる
	_refresh()
	_show_toast("調合しました（品質%d、発現特性%d件）" % [product.quality_score, product.activated_traits.size()])


func _on_execute_alchemy_failed(_recipe_id: StringName, error_code: StringName) -> void:
	# 🔵 AC-009。失敗時はGameState側で状態が一切変更されないため、投入枠・在庫の再構築を行わない
	_show_toast(error_message(error_code))


func _on_delivered(results: Array[DeliveryResult]) -> void:
	_refresh()
	_show_toast("%d件を納品しました" % results.size())


func _show_toast(message: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = message
