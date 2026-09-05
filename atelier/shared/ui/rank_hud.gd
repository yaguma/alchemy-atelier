class_name RankHud
extends Control

## 全フェーズ共通で常時表示するヘッダー（FR-002）。ランク名・ノルマ残量バー・残ターン・
## 所持ゴールドの4要素を、GameStateの6 signalに追随して再描画する（FR-114）。
## 🟡 配置判断: 単一Featureに属さない横断UIコンポーネントのためshared/ui/に新設した。
## 🔵 GameStateの読み取りのみを行い、状態変更・フェーズ遷移は一切行わない（自己完結）。

## 🔵 設定ボタン押下の通知のみを行う。SettingsPanelの生成・表示はMainScene側の責務であり、
## RankHudはSettingsPanel型を一切参照しない（上記の自己完結方針を維持するため）
signal settings_requested

# 🔵 GuildDeliveryScreen.EXAM_RANK_LABEL_SUFFIXと同じpromotion-exam.md「{ランク名}昇格試験」表記。
# 他Featureのui/を参照しない運用ルール（architecture.md）に従い定数自体は再定義する
const EXAM_RANK_LABEL_SUFFIX := "昇格試験"
# 🔴 ノルマ上限が0（ランクマスター未ロード時のフォールバック）のままProgressBar.max_valueへ
# 代入するとratioが0除算でNaNになるため、空表示用のダミー上限へ置き換える
const EMPTY_QUOTA_MAX := 1.0
# 🔴 ランクマスター未登録時の表示名フォールバック。GameState.get_current_rank_master()は
# nullではなくdisplay_nameが空のRankMasterを返すため、空文字のまま描画されるのを防ぐ
const UNKNOWN_RANK_NAME := "ランク不明"
const TURN_REMAINING_FORMAT := "残り%dターン"
# 🔵 workshop_screen.gdのゴールド表示フォーマットを踏襲する
const GOLD_FORMAT := "%d G"

@onready var _rank_name_label: Label = %RankNameLabel
@onready var _quota_bar: ProgressBar = %QuotaBar
@onready var _turn_remaining_label: Label = %TurnRemainingLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	_apply_theme()
	refresh()

	# 🔵 自ノードの子が発行するsignalのため、破棄時にGodotが自動切断する
	# （_exit_tree()での明示的なdisconnect()は不要）
	_settings_button.pressed.connect(_on_settings_button_pressed)

	# 🟡 FR-114。GameStateはAutoloadで本ノードより寿命が長いため、_exit_tree()での
	# disconnect()が必須になる（下の_exit_tree()と1対1で対応させること）
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.turn_growth_advanced.connect(_on_turn_growth_advanced)
	GameState.rank_outcome_confirmed.connect(_on_rank_outcome_confirmed)
	GameState.delivered.connect(_on_delivered)
	GameState.exam_started.connect(_on_exam_started)
	GameState.exam_outcome_confirmed.connect(_on_exam_outcome_confirmed)


func _exit_tree() -> void:
	if GameState.gold_changed.is_connected(_on_gold_changed):
		GameState.gold_changed.disconnect(_on_gold_changed)
	if GameState.turn_growth_advanced.is_connected(_on_turn_growth_advanced):
		GameState.turn_growth_advanced.disconnect(_on_turn_growth_advanced)
	if GameState.rank_outcome_confirmed.is_connected(_on_rank_outcome_confirmed):
		GameState.rank_outcome_confirmed.disconnect(_on_rank_outcome_confirmed)
	if GameState.delivered.is_connected(_on_delivered):
		GameState.delivered.disconnect(_on_delivered)
	if GameState.exam_started.is_connected(_on_exam_started):
		GameState.exam_started.disconnect(_on_exam_started)
	if GameState.exam_outcome_confirmed.is_connected(_on_exam_outcome_confirmed):
		GameState.exam_outcome_confirmed.disconnect(_on_exam_outcome_confirmed)


## 4要素をGameStateの最新値で再描画する（🔵 FR-002, FR-114）。
## 表示更新の唯一の経路であり、_ready()と全signalハンドラがここへ集約される
func refresh() -> void:
	var state := GameState.get_state()
	var master := GameState.get_current_rank_master()
	var in_exam: bool = state["in_exam"]

	_refresh_rank_name(master, in_exam)
	_refresh_quota(state, master, in_exam)
	_refresh_turn_remaining(state, master, in_exam)
	_gold_label.text = GOLD_FORMAT % int(state["gold"])


## 現在表示中のランク名テキストを返す（🔵 テスト用。実体はLabelノードを唯一の正とする）
func get_rank_name_text() -> String:
	return _rank_name_label.text


## 現在表示中の所持ゴールドテキストを返す（🔵 テスト用）
func get_gold_text() -> String:
	return _gold_label.text


## 現在表示中の残ターンテキストを返す（🔵 テスト用）
func get_turn_remaining_text() -> String:
	return _turn_remaining_label.text


## 現在表示中のノルマ達成比率（0.0〜1.0）を返す（🔵 テスト用）。
## 🔴 ProgressBar.ratioを返すことで、上限超過のクランプと上限0時の0除算回避を
## Range側の実装に一本化する（比率計算を二重に持たない）
func get_quota_ratio() -> float:
	return _quota_bar.ratio


## 設定ボタンを返す（🔵 テスト用。他画面からの押下可否操作を意図した公開ではない）
func get_settings_button() -> Button:
	return _settings_button


# 🔵 NFR-202。色・フォントサイズはUiTheme定数経由で指定し、ハードコードしない
func _apply_theme() -> void:
	for label: Label in [_rank_name_label, _turn_remaining_label, _gold_label]:
		label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_DEFAULT)
		label.add_theme_color_override("font_color", UiTheme.COLOR_HUD_TEXT)
	_quota_bar.self_modulate = UiTheme.COLOR_HUD_QUOTA_BAR
	_settings_button.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_DEFAULT)
	_settings_button.add_theme_color_override("font_color", UiTheme.COLOR_HUD_TEXT)


# 🔵 昇格試験中も含め常に押下可能。RankHudは通知するのみで、パネル表示や
# フェーズ遷移といった状態変更は一切行わない
func _on_settings_button_pressed() -> void:
	settings_requested.emit()


# 🔴 マスター未登録時はGameStateがdisplay_name空のフォールバックRankMasterを返すため、
# 空文字での描画を避けてUNKNOWN_RANK_NAMEへ差し替える
func _refresh_rank_name(master: RankMaster, in_exam: bool) -> void:
	var display_name := master.display_name
	if display_name.is_empty():
		display_name = UNKNOWN_RANK_NAME
	if in_exam:
		display_name += EXAM_RANK_LABEL_SUFFIX
	_rank_name_label.text = display_name


# 🔵 GuildDeliveryScreen._refresh_rank_quota()と同じ出し分け。昇格試験中は納品の貢献度が
# RankState.quotaではなくExamState.exam_quotaへ加算されるため、試験中はそちらを参照しないと
# バーが試験開始前の値のまま固まる
func _refresh_quota(state: Dictionary, master: RankMaster, in_exam: bool) -> void:
	var quota_max: float = state["exam_quota_max"] if in_exam else master.quota_max
	var quota: float = state["exam_quota"] if in_exam else GameState.get_current_rank_quota()
	var has_quota := quota_max > 0.0
	_quota_bar.max_value = quota_max if has_quota else EMPTY_QUOTA_MAX
	# 🔵 max_valueを先に設定することで、残量が上限を超えていてもRangeが上限へクランプする
	_quota_bar.value = quota if has_quota else 0.0


# 🔵 ui-design/overview.md txt-turn-remaining定義（limit_turn - elapsed_turn）。
# 試験中は試験専用の制限ターン/経過ターンへ切り替える。
# 🔴 elapsed_turnがlimit_turnを超えた場合（ランク結果確定前の1フレーム等）に負数を
# 表示しないようmaxi()で0へ丸める
func _refresh_turn_remaining(state: Dictionary, master: RankMaster, in_exam: bool) -> void:
	var limit_turn: int = state["exam_turn_limit"] if in_exam else master.limit_turn
	var elapsed_turn: int = (
		state["exam_elapsed_turn"] if in_exam else GameState.get_current_rank_elapsed_turn()
	)
	_turn_remaining_label.text = TURN_REMAINING_FORMAT % maxi(0, limit_turn - elapsed_turn)


# 🔵 FR-114。各signalは引数の数・型が異なるため個別のラッパーを用意し、
# 実処理はすべてrefresh()へ集約する
func _on_gold_changed(_previous_amount: int, _new_amount: int, _delta: int) -> void:
	refresh()


func _on_turn_growth_advanced(_turn: int) -> void:
	refresh()


func _on_rank_outcome_confirmed(_outcome: RankOutcome.Value) -> void:
	refresh()


func _on_delivered(_results: Array[DeliveryResult]) -> void:
	refresh()


func _on_exam_started() -> void:
	refresh()


func _on_exam_outcome_confirmed(_outcome: ExamOutcome.Value) -> void:
	refresh()
