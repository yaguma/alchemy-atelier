---
id: "003"
title: "工房強化のUI購入とGameState反映を検証するステップを実装する"
status: pending
priority: 2
dependencies: ["002"]
estimated_complexity: medium
---

# Task: 工房強化のUI購入とGameState反映を検証するステップを実装する

## Goal

タスク002で到達したworkshop画面から、実データ`upgrade_alchemy_slot`をUI操作のみで購入し、ゴールド減算と`GameState._alchemy_slot_count`加算が実際に反映されること、その後CloseButtonでalchemy画面へ復帰できることを検証する。

## Interfaces

```gdscript
## GameState.load_workshop_master_data()で読み込まれる実データのUpgradeItemRowを
## upgrade_idから見つけて%PurchaseButtonを押下する
func _purchase_upgrade(main: MainScene, upgrade_id: StringName) -> void:
	pass  # 🔵 upgrade_item_list.gd L61の命名規則 "UpgradeItem_%s" % upgrade.id 準拠

func test_G昇格後の工房で恒久強化を購入すると反映されalchemyへ復帰する() -> void:
	pass
```

> 信号機: 🔵 ノード命名規則は`upgrade_item_list.gd`(L61)・`upgrade_item_row.gd`(L18 `%PurchaseButton`)で実装済みコードから直接確認済み。🟡 `GameState._alchemy_slot_count`が購入直後に即座に読み取り可能か（テスト専用ゲッターの有無）は`atelier/autoload/game_state.gd`側の公開状況を実装時に確認すること（`test_game_state_apply_upgrade_effects.gd`では`GameState._alchemy_slot_count`を直接参照しているため恐らく可能、🔵に近いが実装時に再確認）。

## Test Strategy

- [ ] workshop画面表示中、`GameState.load_workshop_master_data()`済みの状態で`_purchase_upgrade(main, &"upgrade_alchemy_slot")`を実行すると`GameState.get_state()["gold"]`が購入価格分減少すること
- [ ] 購入後`GameState._alchemy_slot_count`が購入前より1増えていること（`test_game_state_apply_upgrade_effects.gd`の`alchemy_slot_increase`検証と同じ観測点）
- [ ] 購入後`CloseButton`を押下すると`main.get_visible_phase()`が`&"alchemy"`に戻ること（試験合格直後はalchemy起点でworkshopへ遷移しているため）
- [ ] エッジケース: 所持ゴールドが価格未満の場合は購入ボタン押下してもゴールドが減らず`_alchemy_slot_count`も変化しないこと（既存`apply_upgrade`のバリデーションに委譲されるため、テスト専用ゴールドセッターで意図的に低ゴールド状態を作って確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/tests/integration/test_workshop_screen.gd`（UpgradeItemList/Rowの探索パターン）, `atelier/tests/integration/test_game_state_apply_upgrade_effects.gd`（`_alchemy_slot_count`観測パターン）, `atelier/data/upgrades/upgrade_alchemy_slot.tres`（実データの価格・効果値）
- `GameState.load_workshop_master_data()`をどのタイミングで呼ぶか要確認: `MainScene._enter_tree()`が起動時に自動で呼んでいる可能性がある（`test_main_scene_exam_flow.gd`ではワークショップ画面遷移前に明示呼び出しをしていない）。二重ロードで実データが上書きされて問題ないか実装時に確認する
- 注意事項: 本タスクはPlanの主目的である「工房強化購入→効果が次周に反映される」ことの確認が目的。全effect_type網羅は`test_game_state_apply_upgrade_effects.gd`の責務でありスコープ外

## Files

- 変更: `atelier/tests/integration/test_main_scene_full_loop_playthrough.gd`
