---
id: "006"
title: "WorkshopScreenの閉じるボタンを実装する"
status: done
priority: 4
dependencies: ["004"]
estimated_complexity: low
---

# Task: WorkshopScreenの閉じるボタンを実装する

## Goal

`WorkshopScreen`（task 004で作成済み）の`%CloseButton`を接続し、押下時に`GameState.close_workshop()`を呼び出した上で`screen_closed`シグナルを発行する（FR-104）。

## Interfaces

```gdscript
# atelier/features/workshop/ui/workshop_screen.gd への追加分（既存の_ready()を拡張する）

func _ready() -> void:
	_permanent_tab_button.pressed.connect(_on_permanent_tab_pressed)
	_consumable_tab_button.pressed.connect(_on_consumable_tab_pressed)
	_permanent_list.purchase_requested.connect(_on_purchase_requested)
	_consumable_list.purchase_requested.connect(_on_purchase_requested)
	_close_button.pressed.connect(_on_close_pressed)  # 🔵 本タスクで追加
	_refresh()

## FR-104: close_workshop()呼び出し後にscreen_closedを発行する。
## close_workshop()は_can_purchase_permanentをfalseに戻すだけの冪等操作のため、
## 通常アクセス状態（既にfalse）で呼んでも副作用はない（design doc「閉じるボタンは
## 恒久投資強制表示時も含め常に閉じる/次へとして機能する」に対応）
func _on_close_pressed() -> void:  # 🟡 FR-104
	GameState.close_workshop()
	screen_closed.emit()
```

> 信号機: 🟡 FR-104自体がヒアリングでの推奨設計として🟡確定済み（`docs/dev/plans/workshop-ui/requirements.md` FR-104参照）。`screen_closed`シグナル自体は`GuildDeliveryScreen.screen_closed`と同型のためシグナル宣言部分は🔵。

## Test Strategy

- [ ] `%CloseButton`を押下すると、`WorkshopScreen.screen_closed`シグナルが発行される
- [ ] `_set_can_purchase_permanent_for_test(true)`の状態（恒久投資タブが活性）で`%CloseButton`を押下すると、`GameState.get_state()["can_purchase_permanent"]`がfalseになる（`close_workshop()`が呼ばれたことの確認）
- [ ] 通常アクセス状態（`can_purchase_permanent`が既にfalse）で`%CloseButton`を押下しても、エラーやクラッシュなく`screen_closed`が発行され、`can_purchase_permanent`はfalseのまま変化しない（冪等性の確認）
- [ ] `%CloseButton`押下は`GameState`のゴールド・購入済み回数・`upgrade_masters`のいずれにも影響しない（`close_workshop()`が`_can_purchase_permanent`以外のフィールドを変更しないことの確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/guild/ui/guild_delivery_screen.gd`の`_on_continue_pressed()`（`screen_closed`相当のシグナル発行パターン。ただしGuildDeliveryScreenの`_on_continue_pressed()`はGameStateへの副作用を持たない点が本タスクとの違い。本タスクは`close_workshop()`という画面固有のドメイン操作を伴う）、`atelier/autoload/game_state_workshop_delegate.gd`の`close_workshop()`実装（`_can_purchase_permanent = false`のみを行う一行実装であることを確認する）
- 実装のヒント: `_on_close_pressed()`は`GameState.close_workshop()`→`screen_closed.emit()`の2行で完結する。`_refresh()`の呼び出しは不要（画面を閉じる操作のため再描画する意味がない）
- 注意事項: 呼び出し元（`shop_requested`シグナルの発行元やMainScene）が`screen_closed`をどう処理するか（画面遷移・非表示化等）は本Planのスコープ外（FR-401）

## Files

- 変更: `atelier/features/workshop/ui/workshop_screen.gd`
- テスト: `atelier/tests/integration/test_workshop_screen.gd`（task 004/005で作成したファイルにテストケース追加）
