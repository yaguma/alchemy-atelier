class_name GardenScreen
extends Control

## 庭画面本体。PlantSlotView・SeedInventoryList・ターン終了ボタン・ショップ導線プレースホルダーを
## 統合し、GameStateのsignalを購読して画面を更新する（FR-404, FR-406, US-001〜US-007）。
## 🔵 本タスクの完了をもって「MainSceneへの組み込みは別task」（FR-404）とするスコープ境界を厳守する。

signal shop_requested  # 🔵 FR-301（プレースホルダー導線）

const PlantSlotViewScene = preload("res://features/garden/ui/plant_slot_view.tscn")

var _slot_views: Array[PlantSlotView] = []

@onready var _slots_container: Container = %SlotsContainer
@onready var _seed_inventory_list: SeedInventoryList = %SeedInventoryList
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _shop_button: Button = %ShopButton
@onready var _toast_label: Label = %ToastLabel


func _ready() -> void:
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


## 現在表示中のトーストメッセージを返す（テスト用）。🔵
func get_toast_text() -> String:
	if _toast_label == null:
		return ""
	return _toast_label.text


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
				slot_view.setup_empty(slot_index)
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


func _on_seed_planted(_slot_index: int, _seed_id: StringName) -> void:
	_refresh()


func _on_plant_seed_failed(seed_id: StringName, error_code: StringName) -> void:
	_show_toast("種「%s」を植えられませんでした（%s）" % [seed_id, error_code])


func _on_material_harvested(material: MaterialInstance, _slot_index: int) -> void:
	_refresh()
	_show_toast("収穫しました（品質%d、特性%d件）" % [material.quality_score, material.trait_tags.size()])


func _on_harvest_failed(_slot_index: int, error_code: StringName) -> void:
	_show_toast("収穫できませんでした（%s）" % error_code)


func _on_plants_withered(slot_indices: Array) -> void:
	_refresh()
	_show_toast("スロット%sの株が枯れてしまいました" % [slot_indices])


func _on_turn_growth_advanced(_turn: int) -> void:
	_refresh()


func _show_toast(message: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = message
