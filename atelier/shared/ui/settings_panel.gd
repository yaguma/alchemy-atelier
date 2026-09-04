class_name SettingsPanel
extends Control

## 🔵 FR-104〜FR-108, FR-303。TitleScreenとRankHudの両方から共通コンポーネントとして
## インスタンス化される設定パネル。音量2種・ウィンドウモード・演出簡略化の4項目を操作し、
## 変更は即座にSettingsServiceへ委譲する（永続化は閉じる操作のタイミングでまとめて行う）。
## 🔵 CON-005: GameState・SaveServiceは一切参照しない。多重起動防止も呼び出し元の責務。

## 🔵 FR-107, FR-108。呼び出し元（TitleScreen/RankHud経由でMainScene）が
## 自身の保持する参照をnullへ戻すために購読する
signal closed

const MAIN_THEME := preload("res://shared/theme/main_theme.tres")
## 🔵 FR-303。Godot組み込みアクション。既定でEscapeキーが割り当てられている
const ACTION_CANCEL: StringName = &"ui_cancel"

@onready var _root_container: VBoxContainer = %RootContainer
@onready var _bgm_slider: HSlider = %BgmSlider
@onready var _se_slider: HSlider = %SeSlider
@onready var _window_mode_toggle: CheckButton = %WindowModeToggle
@onready var _reduced_effects_toggle: CheckButton = %ReducedEffectsToggle
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_apply_theme()
	# 🔵 値の反映はシグナル接続より先に行う。逆順にすると初期化の代入自体が
	# value_changed/toggledを発火させ、SettingsServiceへ無意味な書き戻しが走る
	_load_current_values()
	_connect_signals()


## 🔵 FR-303。Escapeキーで閉じるボタンと同じ結果（保存→closed発行→解放）にする。
## 背後の画面へイベントが伝播しないよう、解放前にhandled化しておく
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION_CANCEL):
		return
	get_viewport().set_input_as_handled()
	_on_close_pressed()


## 🔵 BGM音量スライダーの現在値を返す（テスト用の観測点）
func get_bgm_slider_value() -> float:
	return _bgm_slider.value


## 🔵 SE音量スライダーの現在値を返す（テスト用の観測点）
func get_se_slider_value() -> float:
	return _se_slider.value


func _apply_theme() -> void:
	theme = MAIN_THEME
	_root_container.add_theme_constant_override("separation", UiTheme.SPACING_LIST_ENTRY)
	for label: Label in [%TitleLabel as Label, %BgmLabel as Label, %SeLabel as Label]:
		label.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE_DEFAULT)
		label.add_theme_color_override("font_color", UiTheme.COLOR_HUD_TEXT)


func _load_current_values() -> void:
	_bgm_slider.value = SettingsService.get_bgm_volume()
	_se_slider.value = SettingsService.get_se_volume()
	_window_mode_toggle.button_pressed = (
		SettingsService.get_window_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	_reduced_effects_toggle.button_pressed = SettingsService.get_reduced_effects()


func _connect_signals() -> void:
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	_se_slider.value_changed.connect(_on_se_changed)
	_window_mode_toggle.toggled.connect(_on_window_mode_toggled)
	_reduced_effects_toggle.toggled.connect(_on_reduced_effects_toggled)
	_close_button.pressed.connect(_on_close_pressed)


## 🔵 FR-104
func _on_bgm_changed(value: float) -> void:
	SettingsService.set_bgm_volume(value)


## 🔵 FR-105
func _on_se_changed(value: float) -> void:
	SettingsService.set_se_volume(value)


## 🔵 FR-106。トグルはフルスクリーンかどうかの2値のみを扱う
func _on_window_mode_toggled(pressed: bool) -> void:
	var mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED
	)
	SettingsService.set_window_mode(mode)


func _on_reduced_effects_toggled(pressed: bool) -> void:
	SettingsService.set_reduced_effects(pressed)


## 🔵 FR-107, FR-108。永続化してからclosedを発行し、最後に自身を解放する。
## 解放を最後に置くのは、購読側がハンドラ内で本ノードを参照できるようにするため
func _on_close_pressed() -> void:
	# 🔴 queue_free()はフレーム終了まで解放を遅らせるため、同一フレーム内に届いた
	# 2つ目の閉じる操作（Escape連打・ボタン押下との重複）で保存とclosedが二重に走りうる
	if is_queued_for_deletion():
		return

	SettingsService.save_settings()
	closed.emit()
	queue_free()


## 🔴 コードレビュー指摘対応（simplification）。TitleScreen（features/title/）とMainSceneで
## 「既存インスタンスがあれば無視、新規生成してoverlay_parentへadd_child、closedで
## 呼び出し元の参照をnullへ戻す」という多重起動防止パターン（FR-407）が一字一句近い形で
## 重複していたため、この静的ヘルパーへ集約する。呼び出し元は戻り値を自身の参照フィールドへ
## 代入し、on_closedコールバックでそのフィールドをnullへ戻す実装のみを担えばよい
static func open_singleton(
	current: SettingsPanel, overlay_parent: Node, on_closed: Callable
) -> SettingsPanel:
	if is_instance_valid(current):
		return current
	var panel: SettingsPanel = (
		(preload("res://shared/ui/settings_panel.tscn") as PackedScene).instantiate()
	)
	panel.closed.connect(on_closed)
	overlay_parent.add_child(panel)
	return panel
