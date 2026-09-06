---
id: "003"
title: "ゲーム中の一時停止導線（PauseMenu）を追加する"
status: done
priority: 3
dependencies: ["001", "002"]
estimated_complexity: medium
---

# Task: ゲーム中の一時停止導線（PauseMenu）を追加する

## Goal

旧実装（`RankHud`の歯車ボタン→`settings_requested`→`MainScene`が`SettingsPanel`を直接開く）には「タイトルに戻る」導線が無い。今回確定した要件（常時HUDボタン→「閉じる／設定／タイトルに戻る」の一時停止メニュー）を満たすため、`PauseMenu`を新設し、`RankHud`のボタンの遷移先を「設定パネル直行」から「PauseMenu経由」へ差し替える。ボタンの意味が変わるため、`settings_requested`/`%SettingsButton`/「設定」という命名は`menu_requested`/`%MenuButton`/「メニュー」へリネームする（後方互換シムは作らず、名称を実態に合わせて直接変更する）。

## Interfaces

```gdscript
# atelier/shared/ui/pause_menu.gd（新設。RankHud/SettingsPanelと同じくshared/ui/に配置）
class_name PauseMenu
extends Control

const TITLE_SCENE_PATH := "res://features/title/ui/title_screen.tscn"

signal closed  # 「閉じる」押下時。呼び出し元（MainScene）が自身の参照をnullへ戻すために購読する。 🔵 SettingsPanel.closedと同型

var scene_transition_enabled: bool = true  # 既存の遷移テストフックと同型 🔵

var _requested_next_scene_path: String = ""
var _settings_panel: SettingsPanel = null  # 🔵 「設定」押下でSettingsPanel.open_singleton()を呼ぶ。二重管理はしない

@onready var _root_container: VBoxContainer = %RootContainer
@onready var _close_button: Button = %CloseButton
@onready var _settings_button: Button = %SettingsButton
@onready var _title_button: Button = %TitleButton
@onready var _overlay_layer: Control = %OverlayLayer  # SettingsPanel埋め込み先（PauseMenu自身が最前面のため、その中に重ねる）

## 「タイトルに戻る」のテスト用観測点。 🔵
func get_requested_next_scene_path() -> String

## 🔴 コードレビュー指摘対応。SettingsPanel.open_singleton()と同じ多重起動防止パターンを
## 踏襲する（PauseMenu自体も呼び出し元がopen_singleton()で多重生成を防ぐ設計にするため、
## この静的ヘルパーをSettingsPanelと同型でPauseMenuにも用意する）
static func open_singleton(current: PauseMenu, overlay_parent: Node, on_closed: Callable) -> PauseMenu
```

```gdscript
# atelier/shared/ui/pause_menu.gd（続き、押下ハンドラ）

## 🔵 SettingsPanel.open_singleton()をそのまま再利用する。PauseMenu自身のoverlay_layer内に
## 重ねて表示することで、閉じる操作の順序（設定→PauseMenu→ゲーム画面）が自然になる
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
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE_PATH)

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
```

```gdscript
# atelier/shared/ui/rank_hud.gd（既存ファイルの変更、リネーム）
signal menu_requested  # 変更前: settings_requested

@onready var _menu_button: Button = %MenuButton  # 変更前: _settings_button / %SettingsButton, text="メニュー"（変更前"設定"）

func get_menu_button() -> Button  # 変更前: get_settings_button()

func _on_menu_button_pressed() -> void:  # 変更前: _on_settings_button_pressed()
	menu_requested.emit()
```

```gdscript
# atelier/scenes/main.gd（既存ファイルの変更）
var _pause_menu: PauseMenu = null  # 変更前: _settings_panel: SettingsPanel

func _ready() -> void:
	# ...
	_rank_hud.menu_requested.connect(_on_menu_requested)  # 変更前: settings_requested.connect(_on_settings_requested)

func _on_menu_requested() -> void:  # 変更前: _on_settings_requested()
	_pause_menu = PauseMenu.open_singleton(_pause_menu, _settings_overlay_layer, _on_pause_menu_closed)

func _on_pause_menu_closed() -> void:  # 変更前: _on_settings_panel_closed()
	_pause_menu = null
```

## Test Strategy

- [ ] `RankHud`の`%MenuButton`押下で`menu_requested`シグナルが発行される（既存の「設定ボタン押下でsettings_requestedが発行される」テストをリネームして維持）
- [ ] `PauseMenu.open_singleton()`で生成したインスタンスの「設定」ボタン押下で埋め込み`SettingsPanel`が表示される
- [ ] `PauseMenu`の「閉じる」ボタン押下で`closed`シグナルが発行され、ノードが解放される
- [ ] `PauseMenu`の「タイトルに戻る」ボタン押下（`scene_transition_enabled=false`）で`get_requested_next_scene_path()`が`"res://features/title/ui/title_screen.tscn"`になる
- [ ] `MainScene`上で`RankHud.menu_requested`発行後、`_pause_menu`が生成され画面に表示される。もう一度発行しても多重生成されない（`open_singleton()`の冪等性、既存の`SettingsPanel`向けテストと同型で検証）
- [ ] `PauseMenu`表示中に庭画面等でゲーム状態を操作しても（本タスクでは操作手段が無いため）`GameState`に変化がないことを、少なくとも表示前後で`GameState.get_state()`が変わらないことで確認する

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/ui/settings_panel.gd`の`open_singleton()`実装（`PauseMenu`にもほぼ同じ形でコピー、`SettingsPanel`とロジックを共有する共通基底クラスへの抽出は本タスクのスコープ外とする。2つ目の類似実装が出た時点で共通化を検討するのが妥当な判断）
- `PauseMenu`は`MainScene`側の`_settings_overlay_layer`（4画面より後ろに配置済みの最前面オーバーレイ層）にそのまま追加する。新しいオーバーレイ層を追加する必要はない
- **リネーム箇所の網羅的なgrep確認が必須**（`architecture.md`「リファクタリング後検証」参照）: `settings_requested`・`_settings_button`・`%SettingsButton`（RankHud側のみ、`SettingsPanel`側の`%CloseButton`等は無関係）・`get_settings_button`・`_on_settings_button_pressed`・`_on_settings_requested`（MainScene側）を`Grep`で検索し、`atelier/tests/integration/test_rank_hud.gd`・`atelier/tests/integration/test_main_scene_settings_overlay.gd`の参照も含めて漏れなく更新する
- 「設定」というボタンテキスト自体も「メニュー」に変更する（`rank_hud.tscn`の`text = "設定"`を`text = "メニュー"`へ）

## Files

- 新規: `atelier/shared/ui/pause_menu.tscn`
- 新規: `atelier/shared/ui/pause_menu.gd`
- 変更: `atelier/shared/ui/rank_hud.gd`
- 変更: `atelier/shared/ui/rank_hud.tscn`
- 変更: `atelier/scenes/main.gd`
- テスト: `atelier/tests/integration/test_pause_menu.gd`（新規）
- テスト: `atelier/tests/integration/test_rank_hud.gd`（リネーム反映）
- テスト: `atelier/tests/integration/test_main_scene_settings_overlay.gd`（リネーム反映、ファイル名も`test_main_scene_pause_menu.gd`への変更を検討）
