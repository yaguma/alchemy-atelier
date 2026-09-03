---
id: "002"
title: "SettingsServiceを新規Autoloadとして実装する"
status: done
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: SettingsServiceを新規Autoloadとして実装する

## Goal

`user://settings.json`の読み書き、`AudioServer`バス音量・`DisplayServer`ウィンドウモードへの即時反映、演出簡略化フラグの保持を担う新規Autoload`SettingsService`を実装し、`project.godot`へ登録する（GdUnit4統合テストが`SettingsService`をグローバル参照できるようにするため、Autoload登録は本タスクで行う。CON-002）。

## Interfaces

```gdscript
# atelier/autoload/settings_service.gd
extends Node

const SETTINGS_PATH := "user://settings.json"  # 🔵 CON-003: SaveServiceのスロットとは独立したグローバルファイル
const BUS_BGM := "BGM"  # 🔴 現状AudioBusLayoutにBGM/SEバスが定義されていない。get_bus_index()が-1を返す前提でno-opにする
const BUS_SE := "SE"    # 🔴 同上

func load_settings() -> void:  # 🔵 save_service.gd load_from_slot()と同型のファイル読み込み+パース
func save_settings() -> void:  # 🔵 save_service.gd save_to_slot()と同型のファイル書き込み

func get_bgm_volume() -> float:       # 🔵
func get_se_volume() -> float:        # 🔵
func get_window_mode() -> int:        # 🔵
func get_reduced_effects() -> bool:   # 🔵

func set_bgm_volume(value: float) -> void:       # 🔵 clampf(0.0, 1.0)後にAudioServerへ即時反映（FR-104）
func set_se_volume(value: float) -> void:        # 🔵 同上（FR-105）
func set_window_mode(mode: int) -> void:         # 🔵 DisplayServer.window_set_mode()へ即時反映（FR-106）。
                                                   #    失敗時（window_get_mode()で事後検証し不一致）はpush_warning()のみ、UI表示なし（NFR-301）
func set_reduced_effects(value: bool) -> void:   # 🔵 値の保持のみ。既存画面への適用はスコープ外（CON-005, FR-302）

func reset_for_test() -> void:  # 🔵 GameStateTestSupport.guard()を使ったテスト専用リセットAPI（save_service.gdと同型）
```

## Test Strategy

- [ ] `load_settings()`実行前（`user://settings.json`未作成時）、`get_bgm_volume()`等がすべてデフォルト値を返すこと（AC-010正常系）
- [ ] `set_bgm_volume(0.5)`後、`get_bgm_volume()`が`0.5`を返すこと
- [ ] `set_bgm_volume(0.5)`→`save_settings()`→`load_settings()`（再読込）後も`get_bgm_volume()`が`0.5`を返すこと（AC-012ラウンドトリップ）
- [ ] `set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)`後、`get_window_mode()`が変更後の値を返すこと
- [ ] `set_reduced_effects(true)`後、`get_reduced_effects()`が`true`を返すこと
- [ ] エッジケース: `user://settings.json`のJSONパースに失敗する不正な内容の場合、`load_settings()`後の各getterがデフォルト値を返すこと（AC-010異常系）
- [ ] エッジケース: `AudioServer.get_bus_index(BUS_BGM)`が`-1`（バス未定義）を返す環境でも`set_bgm_volume()`がクラッシュしないこと
- [ ] エッジケース: 4値すべて変更後の`save_settings()`→`load_settings()`で全値が一致すること（AC-012、音量0%/100%の端点、ウィンドウモード両方、フラグON/OFFを含む）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/save_service.gd`（Autoloadのファイル読み書きパターン、`reset_for_test()`の実装）、`atelier/autoload/game_state_test_support.gd`（`GameStateTestSupport.guard()`）
- `AudioServer`バスが存在しない場合（`get_bus_index()`が`-1`）は反映処理をno-opにする。本Planのスコープは「バス音量制御まで」でありAudioBusLayoutへのバス追加自体は対象外（CON-004）
- `set_window_mode()`は`DisplayServer.window_set_mode()`自体が成否を返さないAPIのため、呼び出し後に`DisplayServer.window_get_mode()`で事後検証し、期待値と異なる場合のみ`push_warning()`する（UI側へのエラー通知は行わない、NFR-301）
- 音量値→dBへの変換は`linear_to_db()`（Godot組み込み関数）を使う
- 注意事項: `.claude/rules/testing.md`の罠に従い、GdUnit4統合テストで`monitor_signals(SettingsService, false)`のように第2引数を省略しないこと（本タスクではsignal発行は行わない設計のため通常は該当しないが、Autoloadである点に留意）

## Files

- 新規: `atelier/autoload/settings_service.gd`
- 変更: `atelier/project.godot`（`[autoload]`セクションへ`SettingsService="*res://autoload/settings_service.gd"`を追加。`SaveService`と同じパターン、CON-002）
- テスト: `atelier/tests/integration/test_settings_service.gd`
