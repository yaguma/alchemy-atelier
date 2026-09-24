class_name AlchemyScreenEffects

## AlchemyScreenの演出系メソッド群（ui-polish Plan タスク006, 007, 008）を切り出した
## static適用クラス。AlchemyScreen本体が500行ルールを超過したための責務分割であり、
## 振る舞いは分割前と同一（docs/dev/plans/ui-polish/reports/verify-2026-09-23.md参照）。
## PixelBackdropApplier/ButtonStyleApplierと同型の「状態を持たずAlchemyScreen側の
## 状態を引数で受け取るstatic適用クラス」パターンに従う。


## 投入元の在庫行位置から新スロットへ向けてゴーストをスライドさせる。🔵 ui-polish Plan タスク006。
## 演出は見た目のみで、直前の状態更新（投入枠反映・在庫除外）を一切ブロックしない
## （呼び出し元で状態更新を終えてから本関数を呼ぶ契約）。
## 🟡 在庫行は既にsetup()で破棄済みのため、複製元には代わりに新スロット自身の見た目
## （slot_views[slot_index]）を使う。start_positionはfly_ghost()にfrom_global_positionとして
## そのまま渡すため、本関数側で複製やglobal_position差し替えを行う必要はない
## （fly_ghost()自体がtarget_slotを複製し、指定位置から目的地まで飛ばす）
static func play_material_slide_in(
	overlay_layer: Control,
	slot_views: Array[AlchemySlotView],
	placed_material_ids: Array[String],
	material_instance_id: String,
	start_position: Vector2
) -> void:
	var slot_index := placed_material_ids.find(material_instance_id)
	if slot_index < 0 or slot_index >= slot_views.size():
		return

	var target_slot := slot_views[slot_index]
	UiEffects.fly_ghost(
		overlay_layer,
		target_slot,
		start_position,
		target_slot.global_position,
		UiTheme.ANIM_DURATION_FLY_GHOST
	)


## 完成品確定直後、一瞬の生成演出（UiEffects.play_pop_in()）をoverlay_layerへ表示する。
## 🔵 ui-polish Plan タスク008。完成品専用の表示UIが既存に無いため、Implementation Notes記載の
## 裁量に基づき最小限のPanelContainer+Labelを動的生成する。ポップイン完了後もhold_duration秒だけ
## 表示を保持してから自壊する
static func play_craft_result_pop(
	overlay_layer: Control, popup_text: String, hold_duration: float
) -> void:
	if overlay_layer == null:
		return

	var popup := build_craft_result_popup(popup_text)
	overlay_layer.add_child(popup)
	# 🔴 global_position はControlの左上座標のため、中央点をそのまま代入すると自身のサイズの
	# 半分だけ右下にズレる。get_combined_minimum_size()はコンテナのsort（次フレームまで遅延）を
	# 待たずに子要素から同期的にサイズを算出できるため、add_child()直後でも正しい値が取れる
	var popup_size := popup.get_combined_minimum_size()
	popup.global_position = overlay_layer.get_global_rect().get_center() - popup_size / 2.0

	var tween := UiEffects.play_pop_in(
		popup, UiTheme.ANIM_DURATION_POP_IN, UiTheme.ANIM_EASE_DEFAULT
	)
	tween.tween_interval(hold_duration)
	tween.tween_callback(popup.queue_free)


static func build_craft_result_popup(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	UiTheme.apply_panel_style(panel)
	var label := Label.new()
	label.text = text
	UiTheme.apply_pixel_font(label)
	panel.add_child(label)
	return panel


## 前回発現していたタグ集合(previous_activated_traits)には無く、今回新規に発現したタグを持つ
## 投入済みスロットにのみAlchemySlotView.play_trait_highlight()を発火する。🔵 タスク007
## 新規発現の判定（Set差分）はUI表示都合の比較であり、「何が発現したか」自体の判定は
## activated_traits（TraitActivation.resolve_traits()の戻り値）をそのまま使う。
## 呼び出し元は戻り値を使わず、次回比較用にactivated_traitsをそのまま保持し直す契約
static func play_newly_activated_trait_highlights(
	slot_views: Array[AlchemySlotView],
	materials: Array[MaterialInstance],
	activated_traits: Array[StringName],
	previous_activated_traits: Array[StringName]
) -> void:
	var newly_activated: Array[StringName] = []
	for trait_tag in activated_traits:
		if not previous_activated_traits.has(trait_tag):
			newly_activated.append(trait_tag)

	if newly_activated.is_empty():
		return

	for slot_index in range(materials.size()):
		if slot_index >= slot_views.size():
			continue
		if _material_has_any_trait(materials[slot_index], newly_activated):
			slot_views[slot_index].play_trait_highlight()


static func _material_has_any_trait(
	material: MaterialInstance, trait_tags: Array[StringName]
) -> bool:
	for trait_tag in trait_tags:
		if material.trait_tags.has(trait_tag):
			return true
	return false
