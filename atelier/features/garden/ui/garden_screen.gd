class_name GardenScreen
extends Control

## 庭画面本体。PlantSlotView・SeedInventoryList・ターン終了ボタン・ショップ導線プレースホルダーを
## 統合し、GameStateのsignalを購読して画面を更新する（FR-404, FR-406, US-001〜US-007）。
## 🔵 本タスクの完了をもって「MainSceneへの組み込みは別task」（FR-404）とするスコープ境界を厳守する。

signal shop_requested  # 🔵 FR-301（プレースホルダー導線）

const PlantSlotViewScene = preload("res://features/garden/ui/plant_slot_view.tscn")
const ERROR_MESSAGES := {
	&"slot_full": "庭スロットに空きがありません",  # 🔵 garden.md L70の文言をそのまま採用
}  # 🔵 alchemy_screen.gdのERROR_MESSAGESと同型

var _slot_views: Array[PlantSlotView] = []

@onready var _slots_container: Container = %SlotsContainer
@onready var _seed_inventory_list: SeedInventoryList = %SeedInventoryList
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _shop_button: Button = %ShopButton
@onready var _toast_label: Label = %ToastLabel
@onready var _overlay_layer: Control = %OverlayLayer  # 🔵 ui-polish Plan タスク003: 収穫演出の追加先


func _ready() -> void:
	_apply_theme()
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_seed_inventory_list.seed_plant_requested.connect(_on_seed_plant_requested)

	# 🔵 GameStateはAutoloadのため_exit_tree()での明示的disconnect()が必須（ui-components.md）
	GameState.seed_planted.connect(_on_seed_planted)
	GameState.plant_seed_failed.connect(_on_plant_seed_failed)
	GameState.material_harvested.connect(_on_material_harvested)
	GameState.harvest_failed.connect(_on_harvest_failed)
	GameState.plants_withered.connect(_on_plants_withered)
	GameState.turn_growth_advanced.connect(_on_turn_growth_advanced)

	_refresh()


func _exit_tree() -> void:
	if GameState.seed_planted.is_connected(_on_seed_planted):
		GameState.seed_planted.disconnect(_on_seed_planted)
	if GameState.plant_seed_failed.is_connected(_on_plant_seed_failed):
		GameState.plant_seed_failed.disconnect(_on_plant_seed_failed)
	if GameState.material_harvested.is_connected(_on_material_harvested):
		GameState.material_harvested.disconnect(_on_material_harvested)
	if GameState.harvest_failed.is_connected(_on_harvest_failed):
		GameState.harvest_failed.disconnect(_on_harvest_failed)
	if GameState.plants_withered.is_connected(_on_plants_withered):
		GameState.plants_withered.disconnect(_on_plants_withered)
	if GameState.turn_growth_advanced.is_connected(_on_turn_growth_advanced):
		GameState.turn_growth_advanced.disconnect(_on_turn_growth_advanced)


## 🔴 コードレビュー指摘対応: EndTurnButtonは当初PRIMARY（確定操作）だったが、
## alchemy_screen.gd（同じくEndTurnButton、同じ「ターンを終了する」操作）はdesign-guide.mdの
## ボタン表「日終了・破棄→デンジャー」に明示的に対応するためDANGERを採用しており、
## 同一アクションで画面ごとにバリアントが割れていた。design-guide.mdの表に従いDANGERへ揃える。
## ShopButton=補助的な導線でSECONDARYとした（タスクファイルの暫定割り当てに従う）
func _apply_theme() -> void:
	ButtonStyleApplier.apply_button_style(_end_turn_button, UiTheme.ButtonVariant.DANGER)
	ButtonStyleApplier.apply_button_style(_shop_button, UiTheme.ButtonVariant.SECONDARY)
	UiTheme.apply_pixel_font(_end_turn_button)
	UiTheme.apply_pixel_font(_shop_button)
	UiTheme.apply_pixel_font(_toast_label)


## 現在表示中のトーストメッセージを返す（テスト用）。🔵
func get_toast_text() -> String:
	if _toast_label == null:
		return ""
	return _toast_label.text


## error_codeに対応するトースト文言を返す。未知のコードもそのまま提示して沈黙させない。
## 🔵 alchemy_screen.gdのerror_message()と同型
static func error_message(error_code: StringName) -> String:
	if ERROR_MESSAGES.has(error_code):
		return ERROR_MESSAGES[error_code]
	return "植え付けに失敗しました（%s）" % error_code


## GameStateの最新値で表示を再構築する公開API。🔴 コードレビュー指摘対応。MainSceneは
## 4画面を常駐させvisible切替のみで表示するため、本画面が購読していない変化（工房での
## 種購入等）を可視化のたびに反映するには、MainSceneから明示的にrefresh()を呼ぶ経路が要る。
## _refresh()はモジュール内限定（先頭_）のため、外部公開用の薄いラッパーとして用意する
func refresh() -> void:
	_refresh()


## GameState.get_state()を再取得し、スロット一覧・種一覧を再構築する。🔵
func _refresh() -> void:
	if _slots_container == null:
		return

	var state := GameState.get_state()
	var garden_state: GardenState = state["garden_state"]
	var seed_masters: Dictionary = state["seed_masters"]
	var slot_count: int = state["garden_slot_count"]

	var plants_by_slot: Dictionary = {}
	for plant in garden_state.plants:
		plants_by_slot[plant.slot_index] = plant

	for child in _slots_container.get_children():
		_slots_container.remove_child(child)
		child.queue_free()
	_slot_views.clear()

	for slot_index in range(slot_count):
		var slot_view: PlantSlotView = PlantSlotViewScene.instantiate()
		_slots_container.add_child(slot_view)
		slot_view.harvest_pressed.connect(_on_harvest_pressed)
		var plant: Variant = plants_by_slot.get(slot_index)
		if plant is PlantState:
			var master: Variant = seed_masters.get((plant as PlantState).seed_id)
			if master is SeedMaster:
				slot_view.setup(plant as PlantState, master as SeedMaster)
			else:
				# 🔴 コードレビュー指摘対応。株は存在するがSeedMasterが解決できない状態を
				# 空き扱いにすると植付可能に見えてしまうため、専用のデータ異常表示にする
				slot_view.setup_data_error(slot_index)
		else:
			slot_view.setup_empty(slot_index)
		_slot_views.append(slot_view)

	_seed_inventory_list.setup(state["seed_inventory"], seed_masters)


func _on_seed_plant_requested(seed_id: StringName) -> void:
	GameState.plant_seed(seed_id)


func _on_harvest_pressed(slot_index: int) -> void:
	GameState.harvest(slot_index)


func _on_end_turn_pressed() -> void:
	GameState.advance_turn_growth()


func _on_shop_pressed() -> void:
	shop_requested.emit()


## 🔵 ui-polish Plan タスク002。_refresh()は_slot_viewsを再構築するため、ポップインは
## 再構築後の新しいノードに対して呼ぶ（Implementation Notesの順序注意に従う）
func _on_seed_planted(slot_index: int, _seed_id: StringName) -> void:
	_refresh()
	if slot_index >= 0 and slot_index < _slot_views.size():
		_slot_views[slot_index].play_sprout_animation()


func _on_plant_seed_failed(_seed_id: StringName, error_code: StringName) -> void:
	_show_toast(error_message(error_code))


## 🔵 ui-polish Plan タスク003。_refresh()が_slot_views[slot_index]をqueue_free()する「前」に
## 収穫元スロットのノード参照を退避し、_refresh()後にUiEffects.fly_ghost()のsourceとして使う
## （queue_free()は当該フレーム末尾まで実ノードを解放しないため、_refresh()を挟んでも参照は安全）
func _on_material_harvested(material: MaterialInstance, slot_index: int) -> void:
	var source_slot_view: PlantSlotView = null
	if slot_index >= 0 and slot_index < _slot_views.size():
		source_slot_view = _slot_views[slot_index]

	_refresh()

	if source_slot_view != null:
		UiEffects.fly_ghost(
			_overlay_layer,
			source_slot_view,
			_seed_inventory_list.global_position,
			UiTheme.ANIM_DURATION_FLY_GHOST
		)
	_show_toast("収穫しました（品質%d、特性%d件）" % [material.quality_score, material.trait_tags.size()])


func _on_harvest_failed(_slot_index: int, error_code: StringName) -> void:
	_show_toast("収穫できませんでした（%s）" % error_code)


## 🔴 コードレビュー指摘対応。advance_turn_growth()はplants_withered直後に必ずturn_growth_advancedを
## 発行するため、表示の再構築は_on_turn_growth_advanced()側の_refresh()一回に任せ、ここでは
## トースト表示のみ行う（1回のターン終了操作でGardenScreen全体を二重に再構築しないため）。
## 🔵 ui-polish Plan タスク004: 対象スロットの複製を_overlay_layerへ乗せグレー化フェードアウトさせる。
## 複製は_slots_container外（_overlay_layer配下）で独立して自壊するため、直後にturn_growth_advanced経由
## で_refresh()が_slot_views本体を破棄してもクラッシュしない
func _on_plants_withered(slot_indices: Array) -> void:
	for slot_index: Variant in slot_indices:
		if slot_index is int and slot_index >= 0 and slot_index < _slot_views.size():
			var source_slot_view: PlantSlotView = _slot_views[slot_index]
			var ghost := source_slot_view.duplicate() as Control
			_overlay_layer.add_child(ghost)
			ghost.global_position = source_slot_view.global_position
			UiEffects.play_wither_fade(ghost, UiTheme.ANIM_DURATION_WITHER_FADE)
	_show_toast("スロット%sの株が枯れてしまいました" % [slot_indices])


func _on_turn_growth_advanced(_turn: int) -> void:
	_refresh()


func _show_toast(message: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = message
