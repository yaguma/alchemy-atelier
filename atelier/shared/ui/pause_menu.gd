class_name PauseMenu
extends Control

## 🟡 title-settings-screens-extension Plan。ゲーム中に常時表示のHUDボタン（RankHud）から
## 開く一時停止メニュー。「閉じる／設定／タイトルに戻る」の3項目を持つ。
## 旧実装（RankHudの歯車ボタンがSettingsPanelを直接開く）を置き換え、
## 「タイトルに戻る」導線を追加する。SettingsPanel.open_singleton()をそのまま再利用し、
## ロジックを重複させない。CON-005を踏襲しGameState・SaveServiceは一切参照しない。

signal closed  # 「閉じる」押下時。呼び出し元（MainScene）が自身の参照をnullへ戻すために購読する

const TITLE_SCENE_PATH := "res://features/title/ui/title_screen.tscn"
const MAIN_THEME := preload("res://shared/theme/main_theme.tres")

## 🟡 遷移を実際に実行するか。統合テストではシーン差し替えがGdUnit4のテストランナー自身の
## current_sceneを巻き込むため、テスト側でfalseにして遷移要求の有無のみを検証する
## （TitleScreen.scene_transition_enabledと同方針）
var scene_transition_enabled: bool = true

var _requested_next_scene_path: String = ""
var _settings_panel: SettingsPanel = null

@onready var _root_container: VBoxContainer = %RootContainer
@onready var _close_button: Button = %CloseButton
@onready var _settings_button: Button = %SettingsButton
@onready var _title_button: Button = %TitleButton
@onready var _overlay_layer: Control = %OverlayLayer


func _ready() -> void:
	_apply_theme()
	_close_button.pressed.connect(_on_close_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_title_button.pressed.connect(_on_title_pressed)


## 「タイトルに戻る」のテスト用観測点。未要求なら空文字列。
func get_requested_next_scene_path() -> String:
	return _requested_next_scene_path


func _apply_theme() -> void:
	theme = MAIN_THEME
	_root_container.add_theme_constant_override("separation", UiTheme.SPACING_LIST_ENTRY)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


## SettingsPanelの多重起動防止はopen_singleton()（既存の静的ヘルパー）へ委譲する
func _on_settings_pressed() -> void:
	_settings_panel = SettingsPanel.open_singleton(
		_settings_panel, _overlay_layer, _on_settings_panel_closed
	)


func _on_settings_panel_closed() -> void:
	_settings_panel = null


## 🔵 確認ダイアログなしで即座に遷移する（既存のオートセーブが進行を保護するため確認不要、
## という確定要件）
func _on_title_pressed() -> void:
	_requested_next_scene_path = TITLE_SCENE_PATH
	if not scene_transition_enabled:
		return
	# ボタン押下のシグナル処理中にchange_scene_to_fileを直接呼ぶと
	# "Parent node is busy adding/removing children"エラーになるためcall_deferredで遅延させる
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE_PATH)


## 🔵 SettingsPanel.open_singleton()と同型の多重起動防止パターン。呼び出し元（MainScene）は
## 戻り値を自身の参照フィールドへ代入し、on_closedコールバックでそのフィールドをnullへ戻す
## 実装のみを担えばよい
static func open_singleton(
	current: PauseMenu, overlay_parent: Node, on_closed: Callable
) -> PauseMenu:
	if is_instance_valid(current):
		return current
	var menu: PauseMenu = (preload("res://shared/ui/pause_menu.tscn") as PackedScene).instantiate()
	menu.closed.connect(on_closed)
	overlay_parent.add_child(menu)
	return menu
