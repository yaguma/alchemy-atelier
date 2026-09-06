---
id: "002"
title: "TitleScreenに「はじめから」「つづきから」「終了」を追加する"
status: done
priority: 2
dependencies: []
estimated_complexity: low
---

# Task: TitleScreenに「はじめから」「つづきから」「終了」を追加する

## Goal

既存の`TitleScreen`（旧実装、`atelier/features/title/ui/title_screen.gd`）は「はじめる」「せってい」の2ボタンのみを持つ。今回確定した要件（はじめから／つづきから／設定／終了の4ボタン）との差分である「はじめから」「つづきから」への分割と「終了」ボタンを追加する。「せってい」ボタンと`SettingsPanel`連携は変更しない。

## Interfaces

```gdscript
# atelier/features/title/ui/title_screen.gd（既存ファイルの変更）
class_name TitleScreen
extends Control

const SLOT_SELECT_SCENE_PATH := "res://features/save_load/ui/slot_select_screen.tscn"  # 既存、変更なし

## 「終了」ボタンで実際にget_tree().quit()を実行するかのテスト分離フック。 🟡 新規追加
var quit_enabled: bool = true

var _requested_next_scene_path: String = ""
var _has_requested_quit: bool = false  # 🟡 新規追加
var _settings_panel: SettingsPanel = null  # 既存、変更なし

@onready var _root_container: VBoxContainer = %RootContainer
@onready var _new_game_button: Button = %NewGameButton    # 🟡 既存の%StartButtonを置き換え、「はじめから」
@onready var _continue_button: Button = %ContinueButton   # 🟡 新規追加、「つづきから」
@onready var _settings_button: Button = %SettingsButton   # 既存、変更なし
@onready var _quit_button: Button = %QuitButton           # 🟡 新規追加、「終了」
@onready var _overlay_layer: Control = %OverlayLayer      # 既存、変更なし

func get_requested_next_scene_path() -> String  # 既存、変更なし
func has_requested_quit() -> bool  # 🟡 新規追加、テスト用観測点
```

「はじめから」「つづきから」は**同一の遷移先**（`SLOT_SELECT_SCENE_PATH`）へ遷移する共通ハンドラを使う（新規/継続の実際の判定は`SlotSelectScreen`側の責務、という既存方針を維持）。 🔵

```gdscript
## 🟡 既存の_on_start_pressed()と同じ処理内容だが、呼び出し元ボタンが2つになるため
## ハンドラ名を意図が伝わる形に変更する（_on_start_pressed → _on_new_game_pressed /
## _on_continue_pressedの2メソッドとし、内部で共通処理へ委譲する）
func _on_new_game_pressed() -> void:
	_go_to_slot_select()

func _on_continue_pressed() -> void:
	_go_to_slot_select()

func _go_to_slot_select() -> void:
	_requested_next_scene_path = SLOT_SELECT_SCENE_PATH
	if not scene_transition_enabled:
		return
	get_tree().change_scene_to_file.call_deferred(SLOT_SELECT_SCENE_PATH)

## 🟡 quit_enabled=falseのテスト環境では実際には終了しない
func _on_quit_pressed() -> void:
	_has_requested_quit = true
	if quit_enabled:
		get_tree().quit()
```

## Test Strategy

- [ ] 「はじめから」ボタン押下で`get_requested_next_scene_path()`が`SLOT_SELECT_SCENE_PATH`になる（既存の`test_はじめるボタン押下でスロット選択画面への遷移を要求する`相当のケースを名称変更して維持）
- [ ] 「つづきから」ボタン押下でも`get_requested_next_scene_path()`が`SLOT_SELECT_SCENE_PATH`になる（新規ケース、同一遷移先であることの確認）
- [ ] 「終了」ボタン押下（`quit_enabled=false`）で`has_requested_quit()`が`true`になり、`get_tree().quit()`は実際には呼ばれない（テスト実行自体が終了してしまわないことの確認）
- [ ] 「設定」ボタン押下時の既存の挙動（`SettingsPanel.open_singleton()`呼び出し、二重起動防止）に回帰がない（既存テストをそのまま実行して確認するのみ、新規ケース不要）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/title/ui/title_screen.gd`（現行実装全体）、`atelier/features/title/ui/title_screen.tscn`（`%StartButton`のノード定義）、`atelier/tests/integration/test_title_screen.gd`（既存テストの構造・命名パターン）
- `.tscn`側は`%StartButton`を`%NewGameButton`にリネームし、その隣に`%ContinueButton`・`%QuitButton`を追加する（`VBoxContainer`内に追加するだけで、レイアウトは`UiTheme.SPACING_LIST_ENTRY`のセパレーションに従い自動的に整列する）
- 既存テストで`%StartButton`または`get_start_button()`のような形でノードを参照している箇所があれば、リネームに合わせて更新する（`Grep`で`StartButton`を検索して漏れがないか確認すること）
- `quit_enabled`は`scene_transition_enabled`と同型のテスト分離フックのため、命名・配置（フィールド宣言の並び）を揃える

## Files

- 変更: `atelier/features/title/ui/title_screen.gd`
- 変更: `atelier/features/title/ui/title_screen.tscn`
- 変更: `atelier/tests/integration/test_title_screen.gd`
