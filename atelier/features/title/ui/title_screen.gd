class_name TitleScreen
extends Control

## 🟡 title-settings-screens-extension Planでの改訂。「はじめから」「つづきから」
## 「せってい」「終了」の4項目を持つ起動時のトップ画面。新規／つづきの実際の判定は
## SlotSelectScreenの責務のため、両ボタンとも同じ遷移先へ渡すのみで本画面は分岐を持たない
## （旧FR-405の方針を維持）。旧FR-406（終了ボタンなし）はtoday's要件により撤回した。

## 🔵 分岐を持たず常にスロット選択画面へ渡す
const SLOT_SELECT_SCENE_PATH := "res://features/save_load/ui/slot_select_screen.tscn"
const MAIN_THEME := preload("res://shared/theme/main_theme.tres")

## 🟡 遷移を実際に実行するか。統合テストではシーン差し替えがGdUnit4のテストランナー自身の
## current_sceneを巻き込むため、テスト側でfalseにして遷移要求の有無のみを検証する
## （boot.gd / slot_select_screen.gdと同方針）
var scene_transition_enabled: bool = true
## 🟡 「終了」ボタンで実際にget_tree().quit()を実行するか。テスト実行自体を終了させないための
## 分離フック（scene_transition_enabledと同型）
var quit_enabled: bool = true

var _requested_next_scene_path: String = ""
var _has_requested_quit: bool = false
## 🔵 FR-407。多重起動防止のガードに使う。closedを受けてnullへ戻す
var _settings_panel: SettingsPanel = null

@onready var _root_container: VBoxContainer = %RootContainer
@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _overlay_layer: Control = %OverlayLayer


func _ready() -> void:
	_apply_theme()
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


## 🔵 遷移先として要求されたシーンパスを返す（テスト用の観測点）。未要求なら空文字列。
func get_requested_next_scene_path() -> String:
	return _requested_next_scene_path


## 🟡 「終了」が押されたことのテスト用観測点。quit_enabled=falseでも立つ。
func has_requested_quit() -> bool:
	return _has_requested_quit


func _apply_theme() -> void:
	theme = MAIN_THEME
	_root_container.add_theme_constant_override("separation", UiTheme.SPACING_LIST_ENTRY)


## 🟡 「はじめから」「つづきから」はどちらも同じ遷移先へ渡す。新規/継続の実際の判定は
## SlotSelectScreen側の責務のため、ボタンごとに遷移先を分けない
func _on_new_game_pressed() -> void:
	_go_to_slot_select()


func _on_continue_pressed() -> void:
	_go_to_slot_select()


func _go_to_slot_select() -> void:
	_requested_next_scene_path = SLOT_SELECT_SCENE_PATH
	if not scene_transition_enabled:
		return
	# ボタン押下のシグナル処理中にchange_scene_to_fileを直接呼ぶと
	# "Parent node is busy adding/removing children"エラーになるためcall_deferredで遅延させる
	get_tree().change_scene_to_file.call_deferred(SLOT_SELECT_SCENE_PATH)


## 🟡 quit_enabled=falseのテスト環境では実際には終了しない
func _on_quit_pressed() -> void:
	_has_requested_quit = true
	if quit_enabled:
		get_tree().quit()


## 🔵 FR-102, FR-407。多重起動防止・生成・破棄後の参照クリアはSettingsPanel.open_singleton()
## （shared/ui/settings_panel.gd）へ委譲する
func _on_settings_pressed() -> void:
	_settings_panel = SettingsPanel.open_singleton(
		_settings_panel, _overlay_layer, _on_settings_panel_closed
	)


## 🔵 参照を手放し、次回の「せってい」押下で再度開けるようにする
func _on_settings_panel_closed() -> void:
	_settings_panel = null
