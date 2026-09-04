---
id: "003"
title: "SettingsPanel UIを実装する"
status: done
priority: 2
dependencies: ["002"]
estimated_complexity: medium
---

# Task: SettingsPanel UIを実装する

## Goal

`TitleScreen`と`RankHud`の両方から共通コンポーネントとしてインスタンス化される、設定パネルUI（`settings_panel.tscn`/`.gd`）を実装する。音量スライダー・ウィンドウモードトグル・演出簡略化トグル・閉じるボタンを持ち、Escapeキーでも閉じられる。閉じる操作で`SettingsService.save_settings()`を呼びノードを解放する。

## Interfaces

```gdscript
# atelier/features/settings/ui/settings_panel.gd
class_name SettingsPanel
extends Control

signal closed  # 🔵 FR-107, FR-108。呼び出し元（TitleScreen/RankHud経由でMainScene）が
               #    自身が保持する参照をnullへ戻すために購読する

@onready var _bgm_slider: HSlider = %BgmSlider              # 🔵
@onready var _se_slider: HSlider = %SeSlider                # 🔵
@onready var _window_mode_toggle: CheckButton = %WindowModeToggle       # 🔵
@onready var _reduced_effects_toggle: CheckButton = %ReducedEffectsToggle  # 🔵
@onready var _close_button: Button = %CloseButton           # 🔵

func _ready() -> void:               # 🔵 テーマ適用、SettingsServiceの現在値でスライダー/トグル初期化、シグナル接続
func _unhandled_input(event: InputEvent) -> void:  # 🔵 FR-303。ui_cancelアクション（Escapeキー既定）で_on_close_pressed()を呼びhandledにする

func _on_bgm_changed(value: float) -> void:            # 🔵 FR-104。SettingsService.set_bgm_volume()へ委譲
func _on_se_changed(value: float) -> void:             # 🔵 FR-105。SettingsService.set_se_volume()へ委譲
func _on_window_mode_toggled(pressed: bool) -> void:   # 🔵 FR-106
func _on_reduced_effects_toggled(pressed: bool) -> void:  # 🔵
func _on_close_pressed() -> void:                      # 🔵 FR-107, FR-108。save_settings()→closed.emit()→queue_free()の順

# テスト用ゲッター（rank_hud.gdのget_*_text()パターンに倣う）
func get_bgm_slider_value() -> float:  # 🔵
func get_se_slider_value() -> float:   # 🔵
```

## Test Strategy

- [ ] `_ready()`直後、各スライダー/トグルの初期値が`SettingsService`の現在値と一致すること
- [ ] BGM音量スライダーを`0.5`に操作すると`SettingsService.get_bgm_volume()`が`0.5`を返すこと（AC-006）
- [ ] SE音量スライダーを`0.5`に操作すると`SettingsService.get_se_volume()`が`0.5`を返すこと（AC-006）
- [ ] ウィンドウモードトグルをONにすると`SettingsService.get_window_mode()`が`DisplayServer.WINDOW_MODE_FULLSCREEN`を返すこと（AC-007）
- [ ] 演出簡略化トグルをONにすると`SettingsService.get_reduced_effects()`が`true`を返すこと（AC-008）
- [ ] 閉じるボタン押下で`closed`シグナルが発火し、`user://settings.json`に現在値が書き込まれること（AC-009）
- [ ] 閉じるボタン押下後、パネル自身のノードが`queue_free()`されること
- [ ] エッジケース: Escapeキー押下（`ui_cancel`アクション）で閉じるボタン押下と同じ結果（`closed`発火・保存・`queue_free()`）になること（AC-013正常系）
- [ ] エッジケース: BGM音量スライダーの端点（0%・100%）操作で正しく反映されること（AC-006境界値）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/save_load/ui/slot_select_screen.gd`（UIシーンの構成パターン、シーン内ユニーク名`%Name`の使い方）、`atelier/features/workshop/ui/workshop_screen.gd`（閉じるボタンの実装、`.claude/rules/ui-components.md`のコンポーネント基本形）
- スライダーの値域は`0.0`〜`1.0`（`HSlider.min_value = 0.0`, `max_value = 1.0`, `step`は`.tscn`側で設定）
- `_unhandled_input()`でのEscapeキー処理後は`get_viewport().set_input_as_handled()`を呼び、背後の画面（庭/調合等）へイベントが伝播しないようにする
- 色・角丸・余白は`UiTheme`定数経由で指定し、ハードコードしない（NFR-202、`.claude/rules/design-guide.md`）
- 日本語フォントは`res://shared/theme/main_theme.tres`を適用する（NFR-201）
- 注意事項: 本コンポーネントは`GameState`・`SaveService`を一切参照しない（FR-402, FR-403）。多重起動防止（FR-407）は本タスクの責務外で、呼び出し元（004 TitleScreen, 006 MainScene）が担う

## Files

- 新規: `atelier/features/settings/ui/settings_panel.tscn`
- 新規: `atelier/features/settings/ui/settings_panel.gd`
- テスト: `atelier/tests/integration/test_settings_panel.gd`
