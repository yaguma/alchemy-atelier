class_name AlchemyScreen
extends Control

## 調合画面本体。AlchemySlotView・MaterialInventoryList・AlchemyPreviewPanel・レシピ選択・
## 調合実行/ターン終了/ショップボタンを統合し、GameStateのsignalを購読して画面を更新する
## （US-001〜US-203, US-301〜US-302, AC-004〜AC-014）。
## 🔵 本タスクの完了をもって「MainSceneへの組み込みは別task」（FR-405, CON-005）とする
## スコープ境界を厳守する。タブ切替・visible制御・シーン遷移は一切実装しない。

signal shop_requested  # 🔵 FR-110（プレースホルダー導線。GardenScreen.shop_requested踏襲）
# 🔵 FR-107, FR-402。埋め込みGuildDeliveryScreenのscreen_closedを本画面が中継することで、
# MainSceneはGuildDeliveryScreen（他Featureのui/）を直接参照せず結果確認完了を検知できる
signal delivery_confirmed
# 🔵 タスク013（ui-polish Plan）。GameState.exam_outcome_confirmedをAlchemyScreenが中継する
# 画面遷移非同期シグナル。SUCCESS/FAILURE確定時のみ発行し、画面遷移そのもの（set_phase等）は
# 一切行わない。中継する理由: GameState.exam_outcome_confirmedをMainSceneが直接購読すると、
# ノード生成順（子→親）によりAlchemyScreen側ハンドラが先に走った直後、同じ同期呼び出しの中で
# MainScene側がGameState.set_phase()を呼びAlchemyScreen自身をvisible=falseにしてしまい、
# AlchemyScreen内の結果演出が描画前に消えてしまう問題があった。delivery_confirmedと同型のパターン
signal exam_result_pending(outcome: ExamOutcome.Value)

const RECIPE_PLACEHOLDER_TEXT := "選択してください"
const ERROR_MESSAGES := {
	&"unknown_recipe_id": "レシピが見つかりませんでした",
	&"recipe_not_unlocked": "このレシピはまだ解禁されていません",
	&"material_not_owned": "投入した素材が在庫にありません",
	&"duplicate_material_in_slot": "同じ素材を重複して投入しています",
	&"slot_execution_invalid": "投入内容が調合の条件を満たしていません",
}  # 🟡 ui-design/screens/alchemy.mdが文言未確定（🟡TBD）のため、error_codeから妥当な推測で新規決定

# 🟡 指定依頼の提示文言。design docが文言未確定のため書式は新規決定。
# 空欄ではなく「なし」を明示することで、未実装/表示バグとの区別が付くようにする
const DAILY_ORDER_NONE_TEXT := "指定依頼: なし"
const DAILY_ORDER_ITEM_FORMAT := "指定依頼: %s（x%.1f）"
const DAILY_ORDER_TRAIT_FORMAT := "指定依頼: 特性「%s」（x%.1f）"

# 🔵 ui-polish Plan タスク008。完成品確定直後の一瞬の生成演出（ui-design/screens/alchemy.md
# L84前半）に使う文言・表示保持秒数。文言・保持秒数ともにdesign doc未確定のためtdd-implementer裁量で新規決定
const CRAFT_RESULT_POPUP_TEXT_FORMAT := "%s 完成！"  # 🟡
const CRAFT_RESULT_POP_HOLD_DURATION := 0.5  # 🟡

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
# 🔵 ui-polish Plan タスク007。前回のプレビューで発現していたタグ集合。_on_preview_inputs_changed()で
# 新規発現タグ（今回のみに含まれるタグ）を検出するための比較用ローカル状態
var _previous_activated_traits: Array[StringName] = []

@onready var _recipe_option_button: OptionButton = %RecipeOptionButton
@onready var _daily_order_label: Label = %DailyOrderLabel
@onready var _slots_container: Container = %SlotsContainer
@onready var _material_inventory_list: MaterialInventoryList = %MaterialInventoryList
@onready var _preview_panel: AlchemyPreviewPanel = %AlchemyPreviewPanel
@onready var _guild_delivery_screen: GuildDeliveryScreen = %GuildDeliveryScreen
@onready var _execute_button: Button = %ExecuteButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _shop_button: Button = %ShopButton
@onready var _toast_label: Label = %ToastLabel
@onready var _exam_turn_label: Label = %ExamTurnLabel
@onready var _exam_guidance_label: Label = %ExamGuidanceLabel
@onready var _advance_exam_turn_button: Button = %AdvanceExamTurnButton
@onready var _overlay_layer: Control = %OverlayLayer  # 🔵 ui-polish Plan タスク006: 素材投入演出の追加先


func _ready() -> void:
	_apply_theme()
	_recipe_option_button.item_selected.connect(_on_recipe_selected)
	_execute_button.pressed.connect(_on_execute_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_material_inventory_list.material_place_requested.connect(_on_material_place_requested)
	_advance_exam_turn_button.pressed.connect(_on_advance_exam_turn_pressed)
	_guild_delivery_screen.screen_closed.connect(_on_delivery_screen_closed)

	# 🔵 GameStateはAutoloadのため_exit_tree()での明示的disconnect()が必須（ui-components.md）
	GameState.product_crafted.connect(_on_product_crafted)
	GameState.execute_alchemy_failed.connect(_on_execute_alchemy_failed)
	GameState.exam_started.connect(_on_exam_started)
	GameState.exam_outcome_confirmed.connect(_on_exam_outcome_confirmed)

	_refresh()


func _exit_tree() -> void:
	if GameState.product_crafted.is_connected(_on_product_crafted):
		GameState.product_crafted.disconnect(_on_product_crafted)
	if GameState.execute_alchemy_failed.is_connected(_on_execute_alchemy_failed):
		GameState.execute_alchemy_failed.disconnect(_on_execute_alchemy_failed)
	if GameState.exam_started.is_connected(_on_exam_started):
		GameState.exam_started.disconnect(_on_exam_started)
	if GameState.exam_outcome_confirmed.is_connected(_on_exam_outcome_confirmed):
		GameState.exam_outcome_confirmed.disconnect(_on_exam_outcome_confirmed)
	# 🟡 子ノードへの接続はGodotが自動切断するが、_ready()の接続と対にして可読性を揃える
	if _guild_delivery_screen.screen_closed.is_connected(_on_delivery_screen_closed):
		_guild_delivery_screen.screen_closed.disconnect(_on_delivery_screen_closed)


## ドット絵アセット（AlchemyBackdropPixel・9-sliceカードパネル）に合わせ、既存ボタンへ
## ButtonStyleApplier、テキスト要素へDotGothic16フォント（UiTheme.FONT_PIXEL_JP）を適用する。
## 🔵 実行=PRIMARY（確定操作）は本タスクのInterfacesで暫定決定済み。
## 🔵 EndTurnButton（ターンを終了する）はdesign-guide.mdのボタン表「日終了・破棄→デンジャー」に
## 明示的に対応するためDANGERを採用する。
## 🟡 AdvanceExamTurnButtonはEndTurnButtonと排他表示（試験中のみ表示）でターン消費という
## 同じ意味論を持つため、同じDANGERに揃える。
## 🟡 ShopButtonは他画面への導線（確定・危険操作のいずれでもない）のためSECONDARYとする
func _apply_theme() -> void:
	for label: Label in [_daily_order_label, _toast_label, _exam_turn_label, _exam_guidance_label]:
		UiTheme.apply_pixel_font(label)
	UiTheme.apply_pixel_font(_recipe_option_button)

	UiTheme.apply_pixel_font(_execute_button)
	ButtonStyleApplier.apply_button_style(_execute_button, UiTheme.ButtonVariant.PRIMARY)

	UiTheme.apply_pixel_font(_end_turn_button)
	ButtonStyleApplier.apply_button_style(_end_turn_button, UiTheme.ButtonVariant.DANGER)

	UiTheme.apply_pixel_font(_advance_exam_turn_button)
	ButtonStyleApplier.apply_button_style(_advance_exam_turn_button, UiTheme.ButtonVariant.DANGER)

	UiTheme.apply_pixel_font(_shop_button)
	ButtonStyleApplier.apply_button_style(_shop_button, UiTheme.ButtonVariant.SECONDARY)


## 現在表示中のトーストメッセージを返す（テスト用）。🔵 GardenScreen.get_toast_text()踏襲
func get_toast_text() -> String:
	if _toast_label == null:
		return ""
	return _toast_label.text


## GameStateの最新値で表示を再構築する公開API。🔴 コードレビュー指摘対応。庭で収穫した素材が
## 調合タブへ切り替えた時点の在庫一覧に反映されない不具合の修正としてMainSceneから呼ばれる
## （GardenScreen.refresh()と同型のラッパー）
func refresh() -> void:
	_refresh()


## error_codeに対応するトースト文言を返す。未知のコードもそのまま提示して沈黙させない。🔵 AC-009
static func error_message(error_code: StringName) -> String:
	if ERROR_MESSAGES.has(error_code):
		return ERROR_MESSAGES[error_code]
	return "調合に失敗しました（%s）" % error_code


## GameState.get_state()を再取得し、レシピ一覧・スロット一覧・在庫一覧・プレビューを再構築する。🔵
## 🔴 コードレビュー指摘対応。取得済みのstateを呼び出し元へ返すことで、_on_product_crafted()等が
## 自動納品判定のためにGameState.get_state()を再度呼ばずに済むようにする（NFR-001）
func _refresh() -> Dictionary:
	if _slots_container == null:
		return {}

	var state := GameState.get_state()
	_recipe_masters = state["recipe_masters"]
	_inventory = state["inventory"]
	_slot_state.max_slots = state["alchemy_slot_count"]
	# 🔴 コードレビュー指摘対応。_recompute_preview()側でGameState.get_state()を再度呼ばずに済むよう
	# ここでキャッシュする。GameState側のロジックと同一の式（試験中はnull）を経由する
	_daily_order_for_preview = GameState.resolve_daily_order_for_delivery()
	_update_daily_order_label()

	# 🔵 在庫から消えた素材（調合実行で消費された等）が投入枠に残らないよう先に整合を取る
	_drop_missing_placed_ids()

	_rebuild_recipe_options(state["unlocked_recipe_ids"])
	_rebuild_slots()
	_material_inventory_list.setup(_available_materials())
	_on_preview_inputs_changed()
	_refresh_exam_ui(state)
	return state


## in_exam状態に応じて試験用UI（残りターン表示・ターンを進めるボタン・案内メッセージ）を更新する。
## 🔴 実装判断。_refresh()が既に取得済みのstateを再利用し、追加のGameState.get_state()呼び出しは
## 行わない（NFR-001）。具体的な判定・表示ロジックはAlchemyScreenExamへ委譲する
func _refresh_exam_ui(state: Dictionary) -> void:
	AlchemyScreenExam.refresh_exam_ui(
		state,
		_recipe_masters,
		_exam_turn_label,
		_advance_exam_turn_button,
		_end_turn_button,
		_exam_guidance_label
	)


## 指定依頼ラベルの更新。ロジック本体はAlchemyScreenPreviewへ委譲する。🔵
func _update_daily_order_label() -> void:
	AlchemyScreenPreview.update_daily_order_label(
		_daily_order_label,
		_daily_order_for_preview,
		_recipe_masters,
		DAILY_ORDER_NONE_TEXT,
		DAILY_ORDER_ITEM_FORMAT,
		DAILY_ORDER_TRAIT_FORMAT
	)


## recipe_idに対応するRecipeMasterの表示名を返す。ロジック本体はAlchemyScreenPreviewへ委譲する。🔴
func _resolve_recipe_display_name(recipe_id: String) -> String:
	return AlchemyScreenPreview.resolve_recipe_display_name(_recipe_masters, recipe_id)


## ローカルキャッシュのみでプレビュー再計算とボタン活性状態を更新する。
## 🟡 投入操作のたびにGameState.get_state()（inventory/pending_productsのディープコピーを伴う）を
## 呼ぶとコストが嵩むため、素材の解決はキャッシュ済みの_inventoryから行う
func _on_preview_inputs_changed() -> void:
	var materials := _placed_materials()
	_slot_state.materials = materials
	var activated_traits := _recompute_preview(materials)
	AlchemyScreenEffects.play_newly_activated_trait_highlights(
		_slot_views, materials, activated_traits, _previous_activated_traits
	)
	_previous_activated_traits = activated_traits
	if _execute_button != null:
		_execute_button.disabled = not _slot_state.can_execute()  # 🔵 AC-010


## プレビュー再計算。ロジック本体はAlchemyScreenPreviewへ委譲する。🔵 AC-007
func _recompute_preview(materials: Array[MaterialInstance]) -> Array[StringName]:
	return AlchemyScreenPreview.recompute_preview(
		_preview_panel,
		_recipe_masters,
		_slot_state.selected_recipe_id,
		_daily_order_for_preview,
		materials
	)


## 解禁済みレシピからドロップダウンを再構築する。ロジック本体はAlchemyScreenSlotsへ委譲する。🔵
func _rebuild_recipe_options(unlocked_recipe_ids: Array) -> void:
	AlchemyScreenSlots.rebuild_recipe_options(
		_recipe_option_button,
		_recipe_masters,
		unlocked_recipe_ids,
		_slot_state,
		RECIPE_PLACEHOLDER_TEXT
	)


## _placed_material_idsに対応するAlchemySlotViewを枠数ぶん並べ直す。ロジック本体はAlchemyScreenSlotsへ委譲する。🔵 AC-003
func _rebuild_slots() -> void:
	_slot_views = AlchemyScreenSlots.rebuild_slots(
		_slots_container, _slot_state, _placed_materials(), _on_slot_clear_requested
	)


## 投入済みIDに対応するMaterialInstanceをキャッシュ済み在庫から解決する。ロジック本体はAlchemyScreenSlotsへ委譲する。🔵
func _placed_materials() -> Array[MaterialInstance]:
	return AlchemyScreenSlots.placed_materials(_placed_material_ids, _inventory)


## 在庫から投入済みを除外した配列を返す。ロジック本体はAlchemyScreenSlotsへ委譲する。🔵
func _available_materials() -> Array[MaterialInstance]:
	return AlchemyScreenSlots.available_materials(_placed_material_ids, _inventory)


func _find_material(instance_id: String) -> MaterialInstance:
	return AlchemyScreenSlots.find_material(_inventory, instance_id)


# 🔵 在庫に存在しなくなった投入済みIDを取り除く。調合成功時のリセットもこの経路で成立する
func _drop_missing_placed_ids() -> void:
	_placed_material_ids = AlchemyScreenSlots.drop_missing_placed_ids(
		_placed_material_ids, _inventory
	)


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

	# 🔵 ui-polish Plan タスク006。在庫行は直後のsetup()で破棄されるため、破棄される前に開始位置を確保する
	var start_position := _material_inventory_list.find_row_global_position(material_instance_id)

	_placed_material_ids.append(material_instance_id)
	_rebuild_slots()
	_material_inventory_list.setup(_available_materials())
	_on_preview_inputs_changed()

	AlchemyScreenEffects.play_material_slide_in(
		_overlay_layer, _slot_views, _placed_material_ids, material_instance_id, start_position
	)


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


# 🔵 FR-101, CON-003。deliver_pending_products()はキューを空にしてしまうため、
# GuildDeliveryScreenへ渡す表示用のProductInstance列を必ず実行前にスナップショットとして確保し、
# products[i]とresults[i]が同一調合物を指す対応関係を呼び出し元として保証する
# 🔵 FR-115。納品でノルマを消費し切った後にランク結果を確定させる（順序が逆だと同ターンの
# 貢献度が判定に反映されない）。試験中はEndTurnButton自体がvisible=falseのため誤発火しない
func _on_end_turn_pressed() -> void:
	var snapshot: Array[ProductInstance] = GameState.get_state()["pending_products"]
	_deliver_and_display(snapshot)
	GameState.commit_rank_outcome()


## 🔴 コードレビュー指摘対応。_on_end_turn_pressed()と_on_product_crafted()（試験中自動納品）で
## 重複していた「deliver_pending_products() -> display_results()」呼び出し契約を1箇所に集約する
func _deliver_and_display(products: Array[ProductInstance]) -> void:
	var result := GameState.deliver_pending_products()
	_guild_delivery_screen.display_results(products, result.value as Array[DeliveryResult])
	# 🔵 タスク010。visible=trueの直書きをフェードイン+結果行ポップ演出付きの表示へ置換する
	_guild_delivery_screen.show_with_animation()


func _on_shop_pressed() -> void:
	shop_requested.emit()


# 🔵 FR-107, FR-203。結果画面を畳んでからdelivery_confirmedへ中継する。
# GameStateへの副作用はGuildDeliveryScreen側と同様に持たない
func _on_delivery_screen_closed() -> void:
	_guild_delivery_screen.visible = false
	delivery_confirmed.emit()


# 🔵 FR-102。design doc OnExamTurnAdvanced。in_exam=falseの場合ボタン自体がvisible=falseで
# 押下不能なため、GameState.advance_exam_turn()のResult.fail(&"not_in_exam")ハンドリングは不要 🟡
# 🔵 FR-116。ターン消費後に試験結果を確定させる（制限ターン到達の判定に当ターンを含めるため）。
# 試験中のランク判定はcommit_exam_outcome()が担うので、ここでcommit_rank_outcome()は呼ばない
func _on_advance_exam_turn_pressed() -> void:
	GameState.advance_exam_turn()
	GameState.commit_exam_outcome()
	_refresh()


func _on_product_crafted(product: ProductInstance) -> void:
	# 🔵 AC-008。投入素材は在庫から消費済みのため、_refresh()で投入枠が空にリセットされる
	# 🔴 コードレビュー指摘対応。_refresh()が返すstateを再利用し、下のin_exam判定のために
	# GameState.get_state()を再度呼ばない（NFR-001）
	var state := _refresh()
	_show_toast("調合しました（品質%d、発現特性%d件）" % [product.quality_score, product.activated_traits.size()])

	# 🔵 ui-polish Plan タスク008。ギルド納品画面表示処理（_deliver_and_display）を呼ぶ前に、
	# 完成品の生成演出をOverlayLayerへ発火する。演出は見た目のみで状態遷移をブロックしないため、
	# 完了を待たずに後続処理（自動納品判定）へ進む（タスク006の素材投入演出と同方針）
	AlchemyScreenEffects.play_craft_result_pop(
		_overlay_layer,
		CRAFT_RESULT_POPUP_TEXT_FORMAT % _resolve_recipe_display_name(String(product.recipe_id)),
		CRAFT_RESULT_POP_HOLD_DURATION
	)

	# 🔵 FR-101。in_exam中のみ自動納品する。_on_end_turn_pressed()と同じ_deliver_and_display()を使う
	if state.is_empty():
		return
	if state["in_exam"]:
		var snapshot: Array[ProductInstance] = state["pending_products"]
		_deliver_and_display(snapshot)


func _on_execute_alchemy_failed(_recipe_id: StringName, error_code: StringName) -> void:
	# 🔵 AC-009。失敗時はGameState側で状態が一切変更されないため、投入枠・在庫の再構築を行わない
	_show_toast(error_message(error_code))


func _show_toast(message: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = message


# 🟡 FR-103。design doc OnExamStarted
func _on_exam_started() -> void:
	_refresh()
	_show_toast(AlchemyScreenExam.EXAM_MESSAGES[&"exam_started"])


# 🟡 FR-104, FR-105。design doc OnExamResolved
# 🔵 タスク013。SUCCESS/FAILURE確定時はexam_result_pendingを発行してMainSceneへ画面遷移を委譲する。
# 本画面自身はGameState.set_phase()等の画面遷移処理を一切行わない（画面遷移はMainSceneの責務）。
# CONTINUEは「試験がまだ続いている」ことを表すため画面遷移が絡まず、従来通りトーストのみで完結する
func _on_exam_outcome_confirmed(outcome: ExamOutcome.Value) -> void:
	_refresh()
	match outcome:
		ExamOutcome.Value.SUCCESS:
			_show_toast(AlchemyScreenExam.EXAM_MESSAGES[&"exam_success"])
			exam_result_pending.emit(outcome)
		ExamOutcome.Value.FAILURE:
			_show_toast(AlchemyScreenExam.EXAM_MESSAGES[&"exam_failure"])
			exam_result_pending.emit(outcome)
		_:
			pass  # 🔵 FR-105。CONTINUEの場合はトーストを表示せず、exam_result_pendingも発行しない
