class_name AlchemyScreenSlots

## AlchemyScreenのレシピ選択・投入枠/在庫管理に関するロジックを切り出したstatic適用クラス。
## AlchemyScreen本体が300行ルールを超過したための責務分割であり、振る舞いは分割前と同一。
## PixelBackdropApplier/AlchemyScreenEffectsと同型の「状態を持たずAlchemyScreen側の
## 状態を引数で受け取るstatic適用クラス」パターンに従う。

const AlchemySlotViewScene = preload("res://features/alchemy/ui/alchemy_slot_view.tscn")


## 解禁済みレシピからドロップダウンを再構築する。選択中のレシピが解禁一覧から消えた場合は選択を解除する。🔵
## slot_stateはRefCounted（state/slot_state.gd）のため、selected_recipe_idの書き換えは
## 呼び出し元のインスタンスへそのまま反映される
static func rebuild_recipe_options(
	recipe_option_button: OptionButton,
	recipe_masters: Dictionary,
	unlocked_recipe_ids: Array,
	slot_state: SlotState,
	placeholder_text: String
) -> void:
	recipe_option_button.clear()
	# 🔵 item 0は未選択プレースホルダー。metadataを持たせず、選択不可にする
	recipe_option_button.add_item(placeholder_text)
	recipe_option_button.set_item_disabled(0, true)

	var selected_index := 0
	for recipe_id in unlocked_recipe_ids:
		var master: Variant = recipe_masters.get(recipe_id)
		if not (master is RecipeMaster):
			continue
		recipe_option_button.add_item((master as RecipeMaster).name)
		var index := recipe_option_button.item_count - 1
		recipe_option_button.set_item_metadata(index, recipe_id)
		if recipe_id == slot_state.selected_recipe_id:
			selected_index = index

	if selected_index == 0:
		slot_state.selected_recipe_id = &""
	recipe_option_button.select(selected_index)


## placed_materialsに対応するAlchemySlotViewを枠数ぶん並べ直し、生成済みの配列を返す。🔵 AC-003
## clear_requested_callbackは_on_slot_clear_requested(slot_index: int)相当のCallable
static func rebuild_slots(
	slots_container: Container,
	slot_state: SlotState,
	placed_materials: Array[MaterialInstance],
	clear_requested_callback: Callable
) -> Array[AlchemySlotView]:
	for child in slots_container.get_children():
		slots_container.remove_child(child)
		child.queue_free()

	var slot_views: Array[AlchemySlotView] = []
	for slot_index in range(slot_state.max_slots):
		var slot_view: AlchemySlotView = AlchemySlotViewScene.instantiate()
		slot_view.name = "AlchemySlot_%d" % slot_index
		slots_container.add_child(slot_view)
		slot_view.clear_requested.connect(clear_requested_callback)
		if slot_index < placed_materials.size():
			slot_view.setup(slot_index, placed_materials[slot_index])
		else:
			slot_view.setup_empty(slot_index)
		slot_views.append(slot_view)
	return slot_views


## 投入済みIDに対応するMaterialInstanceをキャッシュ済み在庫から解決する。🔵
static func placed_materials(
	placed_material_ids: Array[String], inventory: Array[MaterialInstance]
) -> Array[MaterialInstance]:
	var materials: Array[MaterialInstance] = []
	for instance_id in placed_material_ids:
		var material := find_material(inventory, instance_id)
		if material != null:
			materials.append(material)
	return materials


## 在庫から投入済みを除外した配列を返す。🔵 除外責務はMaterialInventoryListではなく本画面が持つ契約
static func available_materials(
	placed_material_ids: Array[String], inventory: Array[MaterialInstance]
) -> Array[MaterialInstance]:
	var materials: Array[MaterialInstance] = []
	for material in inventory:
		if not placed_material_ids.has(material.instance_id):
			materials.append(material)
	return materials


static func find_material(
	inventory: Array[MaterialInstance], instance_id: String
) -> MaterialInstance:
	for material in inventory:
		if material.instance_id == instance_id:
			return material
	return null


# 🔵 在庫に存在しなくなった投入済みIDを取り除いた新しい配列を返す。調合成功時のリセットもこの経路で成立する
static func drop_missing_placed_ids(
	placed_material_ids: Array[String], inventory: Array[MaterialInstance]
) -> Array[String]:
	var kept: Array[String] = []
	for instance_id in placed_material_ids:
		if find_material(inventory, instance_id) != null:
			kept.append(instance_id)
	return kept
