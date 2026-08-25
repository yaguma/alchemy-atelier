---
id: "003"
title: "MainSceneに庭⇔調合の共通タブバーを実装する"
status: pending
priority: 2
dependencies: ["002"]
estimated_complexity: medium
---

# Task: MainSceneに庭⇔調合の共通タブバーを実装する

## Goal

`GardenScreen`/`AlchemyScreen`自体を改修せず、`MainScene`がタブバー（庭/調合の2ボタン）を保持し押下で`GameState.set_phase()`を呼ぶことで、庭⇔調合を自由に行き来できるようにする。試験中・結果画面表示中はタブを操作不能にする。

## Interfaces

```gdscript
# atelier/scenes/main.gd への追加
@onready var _garden_tab_button: Button = %GardenTabButton      # 🔵
@onready var _alchemy_tab_button: Button = %AlchemyTabButton    # 🔵

# _ready()に追加:
#   _garden_tab_button.pressed.connect(_on_garden_tab_pressed)
#   _alchemy_tab_button.pressed.connect(_on_alchemy_tab_pressed)
#   GameState.exam_started.connect(_on_exam_started_for_tabs)          # FR-201
#   GameState.exam_outcome_confirmed.connect(_on_exam_outcome_for_tabs) # FR-201解除
#   （result遷移時のタブ無効化はtask 008で実装するphase_changed経由の分岐に統合してよい）

func _on_garden_tab_pressed() -> void:    # 🔵 FR-101
	GameState.set_phase(&"garden")

func _on_alchemy_tab_pressed() -> void:   # 🔵 FR-102
	GameState.set_phase(&"alchemy")

func _update_tab_selected_visual(phase: StringName) -> void:  # 🟡 NFR-201。選択中タブの強調表示
	_garden_tab_button.button_pressed = (phase == &"garden")  # 例: Buttonのtoggle_mode運用、または
	_alchemy_tab_button.button_pressed = (phase == &"alchemy") # self_modulate切替でも可（実装時に選択）

func _set_tabs_disabled(disabled: bool) -> void:  # 🔵 FR-201, FR-202
	_garden_tab_button.disabled = disabled
	_alchemy_tab_button.disabled = disabled

func get_is_garden_tab_disabled() -> bool  # 🟡 テスト用ゲッター
func get_is_alchemy_tab_disabled() -> bool # 🟡 テスト用ゲッター
```

```
# atelier/scenes/main.tscn への追加
├── TabBar (HBoxContainer, 4画面より前面/上部に配置)
│   ├── GardenTabButton (Button, unique_name_in_owner, text="庭")
│   └── AlchemyTabButton (Button, unique_name_in_owner, text="調合")
```

## Test Strategy

- [ ] 「調合」タブ押下で`GameState.set_phase(&"alchemy")`が呼ばれ`phase_changed(&"garden", &"alchemy")`が発行され、AlchemyScreenのみ可視になる
- [ ] 「庭」タブ押下で同様に庭へ戻る
- [ ] `garden_screen.gd` / `alchemy_screen.gd`の`signal`宣言が既存（`shop_requested`のみ）から増えていない（本タスクでの改修対象ではないことの回帰確認）
- [ ] `GameState.exam_started`受信後、庭タブが`disabled == true`になる
- [ ] `exam_outcome_confirmed`（SUCCESS/FAILUREいずれも）受信後、庭タブの`disabled`が解除される
- [ ] **境界値**: 現在表示中のタブを再度押下しても`phase_changed`の発行や表示状態を壊さない（同一フェーズへの`set_phase()`が冪等であることの確認）
- [ ] **異常系**: 試験中（庭タブdisabled状態）に庭タブを強制的に`pressed.emit()`してもフェーズが変化しない

## Implementation Notes

- 参照すべき既存コード: `atelier/features/workshop/ui/workshop_screen.gd`の`_permanent_tab_button.disabled`運用（同種のタブdisabled制御の既存パターン）
- 実装のヒント: 選択中タブの視覚強調（NFR-201）は`UiTheme`定数経由で色を切り替える。`design-guide.md`のボタン4種のいずれにも厳密には該当しないため、既存の`Button`の`button_pressed`（トグル状態）とテーマの`pressed`ステートスタイルを流用するのが簡便。
- 注意事項: `_set_tabs_disabled(true)`の呼び出しは本タスクでは`exam_started`/`exam_outcome_confirmed`のみに配線する。result遷移時（`game_cleared`/`game_over`）のタブ無効化はtask 008で扱うため、本タスクでは`TODO`コメント等を残さず、単に該当signalを購読しない（task 008で購読を追加する）。

## Files

- 変更: `atelier/scenes/main.gd`, `atelier/scenes/main.tscn`
- テスト: `atelier/tests/integration/test_main_scene_tab_bar.gd`（新規）
