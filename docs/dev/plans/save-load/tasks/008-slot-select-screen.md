---
id: "008"
title: "SlotSelectScreenを実装する"
status: done
priority: 3
dependencies: ["006"]
estimated_complexity: high
---

# Task: SlotSelectScreenを実装する

## Goal

3固定スロットの状況（新規/続き/破損）を表示し、プレイヤーが選択したスロットを`SaveService.select_slot_and_restore()`へ渡してから`main.tscn`へ遷移する画面を実装する。

## Interfaces

```gdscript
# atelier/features/save_load/ui/slot_select_screen.gd
class_name SlotSelectScreen
extends Control

## 各スロットボタン押下→SaveService.select_slot_and_restore()呼び出し→
## 成功ならmain.tscnへ遷移、失敗（破損）なら警告表示のうえ選択を確定しない
signal slot_selection_failed(slot: int, error_code: StringName)  # 🟡 UIテスト用の観測点

func _ready() -> void:
	_refresh_slot_buttons()

## SaveService.get_slot_summary()を3スロット分取得し、ボタン/ラベルへ反映する。
## is_empty=trueなら「新規開始」、falseなら「つづきから」+ gold/current_rank_id/current_turn/
## saved_at_unixから整形した日時、is_corrupted=trueなら「セーブデータが壊れています（新規開始で上書き）」
## を表示する（🟡 破損時のUX方針: 選択自体は許可し新規ゲーム扱いで上書きする。要再確認事項として明示）
func _refresh_slot_buttons() -> void

func _on_slot_button_pressed(slot: int) -> void:
	var result: Result = SaveService.select_slot_and_restore(slot)
	if not result.success:
		slot_selection_failed.emit(slot, result.error_code)
		_refresh_slot_buttons()  # 破損表示のまま留まる。プレイヤーが再度同じボタンを押せば新規ゲーム扱いで進める分岐は別途検討
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
```

## Test Strategy

- [ ] 3スロットとも未使用の状態で画面を開くと、3つとも「新規開始」表示になる
- [ ] 1つのスロットが保存済みの状態で画面を開くと、そのスロットのみ「つづきから」表示+ゴールド/ランク/ターン数が保存値と一致する
- [ ] 破損したスロットがある状態で画面を開くと、そのスロットが「セーブデータが壊れています」表示になる
- [ ] 新規スロットのボタンを押すと`SaveService.active_slot`がそのスロット番号になり、`main.tscn`への遷移が呼ばれる（`scene_runner()`経由でシグナル/メソッド呼び出しを検証、実際のシーン読込完了までは検証しない）
- [ ] 既存セーブのあるスロットのボタンを押すと、`GameState`側は`apply_pending_restore()`をまだ呼んでいないため未変更のまま（2段階復元の1段階目のみが実行されたことの確認）、かつ`main.tscn`への遷移が呼ばれる
- [ ] 破損スロットのボタンを押すと`slot_selection_failed`シグナルが発行され、`main.tscn`への遷移は呼ばれない

## Implementation Notes

- 参照すべき既存コード: `.claude/rules/ui-components.md`の`Control`継承コンポーネントの基本形、`atelier/features/workshop/ui/workshop_screen.gd`（`Result.success`を見て早期returnする既存パターン、`context.md`のError Handling節参照）
- 実装のヒント: `.tscn`は`VBoxContainer`+スロット数分の`Button`+情報`Label`の組み合わせで最小構成にする（`.claude/rules/design-guide.md`のカード/ボタンスタイルを流用可能だが、本タスクのスコープは機能実装優先でスタイル調整は任意）
- 注意事項: このシーンは`BootScene`から遷移してくる前提のため、`SaveService`（Autoload）以外の依存を持たせない。`GameState`のマスターデータはまだロードされていない前提でUIを組むこと（`get_slot_summary()`はマスターデータに依存しない設計になっている、task 005参照）

## Files

- 新規: `atelier/features/save_load/ui/slot_select_screen.tscn`
- 新規: `atelier/features/save_load/ui/slot_select_screen.gd`
- テスト: `atelier/tests/integration/test_slot_select_screen.gd`
