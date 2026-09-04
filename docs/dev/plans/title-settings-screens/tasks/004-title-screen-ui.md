---
id: "004"
title: "TitleScreen UIを実装する"
status: done
priority: 2
dependencies: ["003"]
estimated_complexity: low
---

# Task: TitleScreen UIを実装する

## Goal

「はじめる」「せってい」の2項目メニューのみを持つ`TitleScreen`（`title_screen.tscn`/`.gd`）を実装する。「はじめる」押下で`SlotSelectScreen`へシーン遷移し、「せってい」押下で`SettingsPanel`をオーバーレイ表示する（多重起動を防止する）。ゲーム終了ボタン・新規/つづきの分岐ロジック・画面遷移アニメーションは持たない。

## Interfaces

```gdscript
# atelier/features/title/ui/title_screen.gd
class_name TitleScreen
extends Control

const SLOT_SELECT_SCENE_PATH := "res://features/save_load/ui/slot_select_screen.tscn"  # 🔵 FR-101
const SettingsPanelScene := preload("res://features/settings/ui/settings_panel.tscn")   # 🔵 FR-102

var scene_transition_enabled: bool = true  # 🔵 boot.gd/slot_select_screen.gdと同じテスト用フラグパターン
var _requested_next_scene_path: String = ""
var _settings_panel: SettingsPanel = null  # 🔵 FR-407多重起動防止ガード用の参照保持

@onready var _start_button: Button = %StartButton        # 🔵 FR-002
@onready var _settings_button: Button = %SettingsButton  # 🔵 FR-002
@onready var _overlay_layer: Control = %OverlayLayer     # 🔵 SettingsPanelのadd_child()先

func _ready() -> void:  # 🔵 テーマ適用、ボタンのsignal接続
func get_requested_next_scene_path() -> String:  # 🔵 boot_scene.gdと同型のテスト用観測点

func _on_start_pressed() -> void:      # 🔵 FR-101, FR-405（分岐ロジックを持たない）
func _on_settings_pressed() -> void:   # 🔵 FR-102, FR-407
func _on_settings_panel_closed() -> void:  # 🔵 _settings_panelをnullへ戻し再度開けるようにする
```

## Test Strategy

- [ ] `TitleScreen`表示直後、ボタンが「はじめる」「せってい」の2つのみ存在すること（AC-002）
- [ ] ゲーム終了・アプリケーション終了に相当するボタンが存在しないこと（AC-002、FR-406）
- [ ] 「はじめる」ボタン押下後、`get_requested_next_scene_path()`が`res://features/save_load/ui/slot_select_screen.tscn`を返すこと（AC-003）
- [ ] 「せってい」ボタン押下後、シーンツリー上に`SettingsPanel`ノードが1つ存在すること（AC-004）
- [ ] 「せってい」ボタン押下後も`TitleScreen`自体のシーン遷移が発生しないこと（`get_requested_next_scene_path()`が空文字列のまま）（AC-004）
- [ ] エッジケース: 「せってい」ボタンを2回連続で押下してもシーンツリー上の`SettingsPanel`ノード数が1のままであること（AC-004境界値、FR-407）
- [ ] エッジケース: `SettingsPanel`の`closed`シグナル発火後に再度「せってい」を押下すると、新しい`SettingsPanel`インスタンスが生成されること（多重起動防止が過剰に働かないことの確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/scenes/boot.gd`（`scene_transition_enabled`によるテスト用の遷移抑止パターン、`call_deferred`での`change_scene_to_file`）、`atelier/features/save_load/ui/slot_select_screen.gd`（シーン遷移とテスト用ゲッターの実装）
- 多重起動防止は`is_instance_valid(_settings_panel)`チェックで実現する。`SettingsPanel.closed`シグナルのハンドラで`_settings_panel = null`にすることで、次回の「せってい」押下時に新規インスタンス化できる状態に戻す
- タイトルロゴ等の見た目要素（FR-301、任意要件）は本タスクでは実装しない（Could Have、US-401）。ボタン数のアサーションに影響しないことのみ確認できればよい
- 画面遷移アニメーションは実装しない（FR-401）。`Tween`生成コードを含めないこと
- 色・角丸・余白は`UiTheme`定数経由で指定する（NFR-202）
- 注意事項: `_ready()`実行中に`change_scene_to_file`を直接呼ぶと"Parent node is busy..."エラーになるため、`boot.gd`と同様`call_deferred`で遅延させること

## Files

- 新規: `atelier/features/title/ui/title_screen.tscn`
- 新規: `atelier/features/title/ui/title_screen.gd`
- テスト: `atelier/tests/integration/test_title_screen.gd`
