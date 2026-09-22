class_name GuildDeliveryScreen
extends Control

## ギルド納品結果画面。納品1件ごとの結果リスト・合計貢献度/合計報酬・ランクノルマ簡易バーを表示し、
## 「続ける」ボタンで導線シグナルを発行する（US-001〜US-401, AC-001〜AC-008）。
## 🔵 表示更新の唯一の経路はdisplay_results()。納品判定（DeliveryResolver）も納品実行
## （GameState.deliver_pending_products）も本画面の責務外で、算出済みの値を受け取って表示するのみ。
## 🔵 MainSceneへの組み込み・タブ切替・シーン遷移は別task（FR-401, FR-403）。

signal screen_closed  # 🟡 FR-102。シグナル名は要件文書でも「例」表記であり確定名ではない

const RESULT_ROW_SCENE_PATH := "res://features/guild/ui/guild_delivery_result_row.tscn"
const GuildDeliveryResultRowScene = preload(RESULT_ROW_SCENE_PATH)
const UNKNOWN_RECIPE_NAME := "不明な調合物"  # 🔴 AC-001異常系フォールバック文言、暫定
const ENTRY_SEPARATION := 8
const EXAM_RANK_LABEL_SUFFIX := "昇格試験"  # 🟡 promotion-exam.md「{ランク名}昇格試験」表記踏襲
# 🔴 ノルマ上限が0（ランクマスター未ロード時のフォールバック）のままProgressBar.max_valueへ
# 代入するとratioが0除算でNaNになるため、空表示用のダミー上限へ置き換える（AC-004異常系）
const EMPTY_QUOTA_MAX := 1.0
# 🟡 ui-polish Plan タスク010。各結果行のポップ演出を「順次」開始させる間隔。
# design doc（guild-delivery.md L69）は時間・イージングともに🟡TBDのため新規決定
const RESULT_ROW_POP_STAGGER := 0.08

var _item_count: int = 0
var _total_contribution: float = 0.0
var _total_reward: float = 0.0

@onready var _content_panel: PanelContainer = %ContentPanel
@onready var _entry_container: VBoxContainer = %EntryContainer
@onready var _total_label: Label = %TotalLabel
@onready var _rank_name_label: Label = %RankNameLabel
@onready var _quota_bar: ProgressBar = %QuotaBar
@onready var _continue_button: Button = %ContinueButton


## 🟡 pixel-art-remaining-screens Plan タスク007: ドット絵背景・カードパネル・ボタン・
## DotGothic16フォントを統合する。ContinueButton=結果確認を締めくくる確定操作としてPRIMARYを採用
## （rank/ui/result_screen.gdと同型のパターン）。
## 🔴 コードレビュー指摘対応: apply_pixel_font(self)はGodotのadd_theme_font_overrideが
## 子孫へ伝播しないため実質no-opだった（ルート自身はテキストを持たない）。garden_screen.gd等の
## 既存実装と同じく、テキストを持つ各ノードへ個別に適用する
func _ready() -> void:
	UiTheme.apply_panel_style(_content_panel)
	_entry_container.add_theme_constant_override("separation", ENTRY_SEPARATION)
	_continue_button.pressed.connect(_on_continue_pressed)
	ButtonStyleApplier.apply_button_style(_continue_button, UiTheme.ButtonVariant.PRIMARY)
	UiTheme.apply_pixel_font(_rank_name_label)
	UiTheme.apply_pixel_font(_total_label)
	UiTheme.apply_pixel_font(_continue_button)
	_refresh_rank_quota()
	_apply_totals()


## 唯一の公開表示更新経路（FR-008）。products[i]とresults[i]は同一調合物対応が
## 呼び出し元（AlchemyScreen）で保証済み（FR-101, CON-003）という前提でindexをそのまま使う。
## 納品対象が空だった場合もdisplay_results([], [])が呼ばれ0件へリセットされる（FR-006, AC-008）
func display_results(products: Array[ProductInstance], results: Array[DeliveryResult]) -> void:
	_rebuild_list(products, results)
	_apply_totals()
	_refresh_rank_quota(true)


## 画面表示時のフェードイン+完成品ポップ演出（ui-design/screens/guild-delivery.md L69）。
## visible=trueにした上でmodulate.aを0→1へフェードし、既に構築済みの各結果行へ
## UiEffects.play_pop_in()を順次適用する。呼び出し元（AlchemyScreen._deliver_and_display()）は
## display_results()で行を構築済みにしてから本関数を呼ぶ契約とする
func show_with_animation() -> void:
	visible = true
	UiEffects.play_fade_in(self, UiTheme.ANIM_DURATION_FADE_SCREEN, UiTheme.ANIM_EASE_DEFAULT)
	_play_result_row_pop_ins()


## 現在表示している納品結果の件数を返す（テスト用）。🔵 FR-007
func get_item_count() -> int:
	return _item_count


## 現在表示している合計貢献度を返す（テスト用）。🔵 FR-007
func get_total_contribution() -> float:
	return _total_contribution


## 現在表示している合計報酬を返す（テスト用）。🔵 FR-007
func get_total_reward() -> float:
	return _total_reward


## 合計貢献度・合計報酬の表示文字列を組み立てる。
## 🟡 AlchemyPreviewPanel.format_value踏襲。確定値のため「見込み」は付けない
static func format_totals(total_contribution: float, total_reward: float) -> String:
	return "合計貢献度: %.1f / 合計報酬: %.1f" % [total_contribution, total_reward]


# 🔵 MaterialInventoryList._rebuild()と同型。既存行を全破棄してから再構築することで、
# 0件のdisplay_results()呼び出しがそのままリストのクリアとして成立する（AC-008）
func _rebuild_list(products: Array[ProductInstance], results: Array[DeliveryResult]) -> void:
	if _entry_container == null:
		return

	for child in _entry_container.get_children():
		_entry_container.remove_child(child)
		child.queue_free()

	_item_count = 0
	_total_contribution = 0.0
	_total_reward = 0.0

	# 🔵 CON-004。recipe_id -> 表示名の解決に必要なマスターは本メソッド内で1回だけ取得する
	var recipe_masters: Dictionary = GameState.get_state()["recipe_masters"]
	# 🟡 両配列の要素数は呼び出し元の契約上一致する（FR-101）が、片方が短い場合でも
	# 存在しないindexを参照してクラッシュしないよう短い方に合わせる
	var count := mini(products.size(), results.size())
	for index in range(count):
		var product := products[index]
		var result := results[index]
		if product == null or result == null:
			continue
		_add_entry_row(index, product, result, recipe_masters)
		_item_count += 1
		_total_contribution += result.final_contribution
		_total_reward += result.final_reward


# 🔵 GuildDeliveryResultRowの@onready変数はadd_child()によるシーンツリー追加後の_ready()で
# 解決されるため、setup()は必ずadd_child()の後に呼ぶ（MaterialInventoryListと同一契約）。
# 行名はProductInstanceが一意ID相当のフィールドを持たないためindexベースにする
func _add_entry_row(
	index: int, product: ProductInstance, result: DeliveryResult, recipe_masters: Dictionary
) -> void:
	var row: GuildDeliveryResultRow = GuildDeliveryResultRowScene.instantiate()
	row.name = "DeliveryEntry_%d" % index
	_entry_container.add_child(row)
	row.setup(
		_resolve_recipe_name(recipe_masters, product.recipe_id),
		product.quality_score,
		product.activated_traits,
		result.order_matched,
		result.final_contribution,
		result.final_reward
	)


# 🔴 AC-001異常系。マスター未登録のrecipe_idでも表示を止めず、フォールバック文言で描画する
func _resolve_recipe_name(recipe_masters: Dictionary, recipe_id: StringName) -> String:
	var master: Variant = recipe_masters.get(recipe_id)
	if not (master is RecipeMaster):
		return UNKNOWN_RECIPE_NAME
	return (master as RecipeMaster).name


# 🟡 各結果行のポップ演出をRESULT_ROW_POP_STAGGER間隔でずらして開始する。
# 行が0件の場合はTweenerを持たないTweenの生成自体を避け、警告ログの発生を防ぐ（AC-008相当）
func _play_result_row_pop_ins() -> void:
	if _entry_container == null:
		return
	var rows: Array[Control] = []
	for row in _entry_container.get_children():
		if row is Control:
			rows.append(row as Control)
	if rows.is_empty():
		return

	var stagger_tween := create_tween()
	for row in rows:
		stagger_tween.tween_callback(_pop_in_result_row.bind(row))
		stagger_tween.tween_interval(RESULT_ROW_POP_STAGGER)


# 🟡 ui-polish Plan タスク012: 指定合致した行はポップイン完了後（tween.finished）に
# ハイライト演出を開始する。タスク010のポップイン演出と時系列が重ならないようにする実装者裁量
static func _pop_in_result_row(row: Control) -> void:
	var pop_in_tween := UiEffects.play_pop_in(
		row, UiTheme.ANIM_DURATION_POP_IN, UiTheme.ANIM_EASE_DEFAULT
	)
	if row is GuildDeliveryResultRow and (row as GuildDeliveryResultRow).is_order_matched():
		pop_in_tween.finished.connect((row as GuildDeliveryResultRow).play_order_matched_highlight)


func _apply_totals() -> void:
	if _total_label == null:
		return
	_total_label.text = format_totals(_total_contribution, _total_reward)


# 🔵 CON-005。RankState/ExamState（他Featureのstate/）へは触れず、GameStateのプリミティブ
# 公開API（get_current_rank_master()）とget_state()が返す値型フィールド（in_exam/exam_quota/
# exam_quota_max、FR-009/AC-018でUI公開済み）のみを使う。
# 🔴 コードレビュー指摘対応。昇格試験中(_in_exam)はGameStateGuildDelegate.deliver_pending_products()が
# 貢献度をRankState.quotaではなくExamState.exam_quotaへ加算するため、試験中はこちらを参照しないと
# ノルマバーが試験開始前の値のまま固まってしまう
# 🟡 ui-polish Plan タスク011。animate=falseは従来通り_ready()からの初期表示で使う瞬時反映、
# animate=trueはdisplay_results()（結果表示処理）から呼ばれ、UiEffects.animate_progress_value()で
# 滑らかに変化させる（guild-delivery.md L70）
func _refresh_rank_quota(animate: bool = false) -> void:
	if _quota_bar == null:
		return
	var master := GameState.get_current_rank_master()
	var state := GameState.get_state()
	var in_exam: bool = state["in_exam"]
	_rank_name_label.text = (
		"%s%s" % [master.display_name, EXAM_RANK_LABEL_SUFFIX] if in_exam else master.display_name
	)
	var quota_max: float = state["exam_quota_max"] if in_exam else master.quota_max
	var quota: float = state["exam_quota"] if in_exam else GameState.get_current_rank_quota()
	var has_quota := quota_max > 0.0
	_quota_bar.max_value = quota_max if has_quota else EMPTY_QUOTA_MAX
	# 🔵 max_valueを先に設定することで、残量が上限を超えていてもRangeが上限へクランプする
	var target_value := quota if has_quota else 0.0
	if animate:
		UiEffects.animate_progress_value(_quota_bar, target_value, UiTheme.ANIM_DURATION_QUOTA_BAR)
	else:
		_quota_bar.value = target_value


# 🟡 FR-402。画面を閉じる導線シグナルの発行のみを行い、GameStateへの副作用は持たない
func _on_continue_pressed() -> void:
	screen_closed.emit()
