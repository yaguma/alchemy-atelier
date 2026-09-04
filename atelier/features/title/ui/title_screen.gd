class_name TitleScreen
extends Control

## 🔵 FR-002。「はじめる」「せってい」の2項目のみを持つ起動時のトップ画面。
## 新規／つづきの分岐はSlotSelectScreenの責務のため本画面は持たない（FR-405）。
## ゲーム終了ボタン（FR-406）・遷移アニメーション（FR-401）も持たない。

## 🔵 FR-101。分岐を持たず常にスロット選択画面へ渡す
const SLOT_SELECT_SCENE_PATH := "res://features/save_load/ui/slot_select_screen.tscn"
const MAIN_THEME := preload("res://shared/theme/main_theme.tres")

## 🟡 遷移を実際に実行するか。統合テストではシーン差し替えがGdUnit4のテストランナー自身の
## current_sceneを巻き込むため、テスト側でfalseにして遷移要求の有無のみを検証する
## （boot.gd / slot_select_screen.gdと同方針）
var scene_transition_enabled: bool = true

var _requested_next_scene_path: String = ""
## 🔵 FR-407。多重起動防止のガードに使う。closedを受けてnullへ戻す
var _settings_panel: SettingsPanel = null

@onready var _root_container: VBoxContainer = %RootContainer
@onready var _start_button: Button = %StartButton
@onready var _settings_button: Button = %SettingsButton
@onready var _overlay_layer: Control = %OverlayLayer


func _ready() -> void:
	_apply_theme()
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)


## 🔵 遷移先として要求されたシーンパスを返す（テスト用の観測点）。未要求なら空文字列。
func get_requested_next_scene_path() -> String:
	return _requested_next_scene_path


func _apply_theme() -> void:
	theme = MAIN_THEME
	_root_container.add_theme_constant_override("separation", UiTheme.SPACING_LIST_ENTRY)


## 🔵 FR-101, FR-405
func _on_start_pressed() -> void:
	_requested_next_scene_path = SLOT_SELECT_SCENE_PATH
	if not scene_transition_enabled:
		return
	# ボタン押下のシグナル処理中にchange_scene_to_fileを直接呼ぶと
	# "Parent node is busy adding/removing children"エラーになるためcall_deferredで遅延させる
	get_tree().change_scene_to_file.call_deferred(SLOT_SELECT_SCENE_PATH)


## 🔵 FR-102, FR-407。多重起動防止・生成・破棄後の参照クリアはSettingsPanel.open_singleton()
## （shared/ui/settings_panel.gd）へ委譲する
func _on_settings_pressed() -> void:
	_settings_panel = SettingsPanel.open_singleton(
		_settings_panel, _overlay_layer, _on_settings_panel_closed
	)


## 🔵 参照を手放し、次回の「せってい」押下で再度開けるようにする
func _on_settings_panel_closed() -> void:
	_settings_panel = null
