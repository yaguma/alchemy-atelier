---
id: "005"
title: "RankHudに歯車ボタンとsettings_requestedシグナルを追加する"
status: done
priority: 2
dependencies: []
estimated_complexity: low
---

# Task: RankHudに歯車ボタンとsettings_requestedシグナルを追加する

## Goal

全フェーズ共通ヘッダー`RankHud`に歯車アイコンボタンを追加し、押下時に`settings_requested`シグナルを発行する。`RankHud`自身は「GameStateの読み取りのみを行い状態変更・フェーズ遷移は一切行わない自己完結コンポーネント」という既存方針を維持するため、`SettingsPanel`のインスタンス化・`add_child()`は行わない（それはMainScene側の責務、タスク006）。

## Interfaces

```gdscript
# atelier/shared/ui/rank_hud.gd （既存ファイルへの追記）

signal settings_requested  # 🔵 FR-007, FR-103。歯車ボタン押下時に発行するのみで、
                            #    RankHud自身はSettingsPanelを一切参照しない

@onready var _settings_button: Button = %SettingsButton  # 🔵

# _ready()に1行追記
# _settings_button.pressed.connect(_on_settings_button_pressed)

func _on_settings_button_pressed() -> void:  # 🔵 settings_requested.emit()のみ
func get_settings_button() -> Button:  # 🔵 rank_hud.gdの既存get_*()パターンに倣うテスト用ゲッター
```

## Test Strategy

- [ ] `RankHud`表示直後、歯車ボタン（`%SettingsButton`）が存在すること（FR-007）
- [ ] 歯車ボタン押下で`settings_requested`シグナルが発火すること（AC-005）
- [ ] 昇格試験中（`GameState`の`in_exam = true`）でも歯車ボタンが押下可能（`disabled = false`）であること（AC-005、NFR-203）
- [ ] 歯車ボタン押下時に`GameState.set_phase()`が一度も呼ばれないこと（AC-011、既存の自己完結方針の維持確認）
- [ ] エッジケース: `RankHud`が`_exit_tree()`で破棄された後もクラッシュしないこと（既存の`GameState`signal購読解除パターンに影響がないことの回帰確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/ui/rank_hud.gd`（既存の4要素構成、`_apply_theme()`、テスト用ゲッターのパターン）、`atelier/shared/ui/rank_hud.tscn`（`HBoxContainer`直下に`unique_name_in_owner = true`でノードを追加する構成）
- `rank_hud.tscn`へ`Button`ノード（`name="SettingsButton"`, `unique_name_in_owner = true`）を追加する。既存の4要素（ランク名・ノルマバー・残ターン・ゴールド）の並び順は変更しない
- 歯車アイコンは既存プロジェクトにアイコンアセットがないため、暫定でテキストボタン（例: 文字「⚙」または「せってい」）とする。正式なアイコン化は本Planのスコープ外（デザインパス未整備、design-guide.md参照）
- 注意事項: 本タスクは`SettingsPanel`型を一切参照しない。`settings_requested`シグナルの発行のみに責務を限定し、既存のRankHud自己完結方針（コメントに明記済み）を壊さないこと

## Files

- 変更: `atelier/shared/ui/rank_hud.gd`
- 変更: `atelier/shared/ui/rank_hud.tscn`
- テスト: `atelier/tests/integration/test_rank_hud.gd`（既存ファイルへのテストケース追記）
