---
id: "006"
title: "MainSceneに設定パネルのオーバーレイ表示を統合する"
status: done
priority: 2
dependencies: ["003", "005"]
estimated_complexity: medium
---

# Task: MainSceneに設定パネルのオーバーレイ表示を統合する

## Goal

`MainScene`が`RankHud.settings_requested`シグナルを購読し、`SettingsPanel`のインスタンスを`add_child()`でオーバーレイ表示する。多重起動を防止し、設定パネルの開閉が現在のフェーズ表示・`GameState`・`SaveService`に一切影響を与えないことを保証する。

## Interfaces

```gdscript
# atelier/scenes/main.gd （既存ファイルへの追記）

const SettingsPanelScene := preload("res://features/settings/ui/settings_panel.tscn")  # 🔵

var _settings_panel: SettingsPanel = null  # 🔵 FR-407多重起動防止ガード用の参照保持

@onready var _settings_overlay_layer: Control = %SettingsOverlayLayer  # 🔵 全フェーズ画面の最前面に配置する親ノード

# _ready()に1行追記（RankHudは同一シーンツリー内の子ノードのため_exit_tree()でのdisconnect不要）
# _rank_hud.settings_requested.connect(_on_settings_requested)

func _on_settings_requested() -> void:       # 🔵 FR-103, FR-407
func _on_settings_panel_closed() -> void:    # 🔵 _settings_panelをnullへ戻す
```

## Test Strategy

- [ ] 庭フェーズ表示中に`RankHud.settings_requested`を発火させると、シーンツリー上に`SettingsPanel`ノードが1つ追加されること（AC-005）
- [ ] `SettingsPanel`表示中も現在のフェーズ画面（例: `GardenScreen`）の`visible`状態が変化しないこと（AC-011、FR-201）
- [ ] `SettingsPanel`の開閉前後で`GameState.get_state().current_phase`が変化しないこと（AC-011、FR-402）
- [ ] `SettingsPanel`操作中に`SaveService`のオートセーブ（`autosave()`呼び出し回数）が増加しないこと（AC-011、FR-403）
- [ ] 昇格試験中（`in_exam = true`）に`settings_requested`を発火させても`SettingsPanel`が正しく表示されること（AC-005正常系）
- [ ] エッジケース: `settings_requested`を2回連続で発火させても`SettingsPanel`ノード数が1のままであること（FR-407）
- [ ] エッジケース: `SettingsPanel`の`closed`シグナル発火後に再度`settings_requested`を発火させると、新しい`SettingsPanel`インスタンスが生成されること

## Implementation Notes

- 参照すべき既存コード: `atelier/scenes/main.gd`（`_ready()`での`RankHud`関連ノード取得、シグナル接続パターン、既存の4画面visible排他切替ロジックには一切手を加えないこと）、`atelier/features/title/ui/title_screen.gd`（タスク004で実装する同型の多重起動防止パターン、`is_instance_valid(_settings_panel)`チェック）
- `atelier/scenes/main.tscn`に`%SettingsOverlayLayer`という名前の`Control`（`anchors_preset = 15`でフルスクリーン、既存4画面より後ろに置かず最後の子として配置し描画順で最前面にする）を追加する。既存の庭/調合/工房/結果の4画面ノードや`RankHud`ノードの構成・順序は変更しない
- 多重起動防止は004（TitleScreen）と同じ`is_instance_valid(_settings_panel)`パターンを踏襲する
- 注意事項: `RankHud`は同一シーンツリー内の子ノードのため、`settings_requested`への接続は`_exit_tree()`での明示的な`disconnect()`は不要（`.claude/rules/state-management.md`参照）。`GameState`のsignalへの接続ではないことに注意
- 本タスクは`GameState.set_phase()`・`SaveService.autosave()`のいずれも呼び出さないコードのみを追加する（既存の`_on_phase_changed()`等の分岐に一切手を加えない）

## Files

- 変更: `atelier/scenes/main.gd`
- 変更: `atelier/scenes/main.tscn`
- テスト: `atelier/tests/integration/test_main_scene_settings_overlay.gd`
