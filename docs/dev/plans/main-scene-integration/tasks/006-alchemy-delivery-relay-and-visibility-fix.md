---
id: "006"
title: "AlchemyScreenにdelivery_confirmed中継signalを追加しGuildDeliveryScreenの常時表示バグを修正する"
status: pending
priority: 2
dependencies: ["002"]
estimated_complexity: medium
---

# Task: AlchemyScreenにdelivery_confirmed中継signalを追加しGuildDeliveryScreenの常時表示バグを修正する

## Goal

`AlchemyScreen`に埋め込み済みの`GuildDeliveryScreen`（`%GuildDeliveryScreen`）について、(1) 表示すべき結果がある時だけ`visible=true`になるよう修正し、(2) 「続ける」ボタン（`screen_closed`）を`AlchemyScreen`が内部購読し新規`delivery_confirmed` signalとして中継発行することで、`MainScene`が他Featureの`ui/`を直接参照せずに「結果確認後→庭画面へ戻る」を実現できるようにする。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd への変更（CON-003で改修許容される唯一の既存画面）
signal delivery_confirmed  # 🔵 FR-107, FR-402。MainSceneはこのsignalのみを購読しGuildDeliveryScreen
                            # の存在を意識しない

# _ready()に追加:
#   _guild_delivery_screen.screen_closed.connect(_on_delivery_screen_closed)
# _exit_tree()に追加:
#   対応するis_connected()ガード付きdisconnect

func _on_delivery_screen_closed() -> void:  # 🔵 FR-107, FR-203
	_guild_delivery_screen.visible = false
	delivery_confirmed.emit()

# _deliver_and_display()を変更（既存の唯一の表示更新経路、alchemy_screen.gd:338-341）:
func _deliver_and_display(products: Array[ProductInstance]) -> void:
	var result := GameState.deliver_pending_products()
	_guild_delivery_screen.display_results(products, result.value as Array[DeliveryResult])
	_guild_delivery_screen.visible = true  # 🔵 FR-203（新規追加行）
```

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.tscn への変更
# GuildDeliveryScreenノードに visible = false を追加（現状指定なし＝常時表示のバグを修正）
```

## Test Strategy

- [ ] `AlchemyScreen`インスタンス化直後（一度も納品していない状態）、`%GuildDeliveryScreen.visible == false`
- [ ] `_deliver_and_display()`が呼ばれた後（`display_results()`実行後）、`%GuildDeliveryScreen.visible == true`
- [ ] `GuildDeliveryScreen`の「続ける」ボタン押下（`screen_closed`発行）後、`%GuildDeliveryScreen.visible == false`に戻る
- [ ] `GuildDeliveryScreen`の「続ける」ボタン押下後、`AlchemyScreen.delivery_confirmed`が発行される（`monitor_signals`で検証）
- [ ] 試験中の自動納品（`_on_product_crafted()`経由で`in_exam`時に`_deliver_and_display()`が呼ばれるケース）でも同じ`visible`制御が働く
- [ ] **異常系**: 空の結果配列で`display_results([], [])`相当のケースでも`visible`制御がクラッシュしない
- [ ] **回帰確認**: `_on_end_turn_pressed()`, `_on_product_crafted()`等、既存の呼び出し元コードの契約（`_deliver_and_display()`のシグネチャ・戻り値）が変更されていない

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/features/alchemy/ui/alchemy_screen.gd:338-341`（`_deliver_and_display()`の現状実装）
  - `atelier/features/guild/ui/guild_delivery_screen.gd:155-157`（`_on_continue_pressed()`が`screen_closed`を発行するのみで副作用を持たない既存実装。**このファイル自体は変更しない**、`GuildDeliveryScreen`はGuild Featureの所有物であり本Planの改修対象はAlchemyScreen側のみ）
  - `atelier/features/alchemy/ui/alchemy_screen.tscn:53-55`（`%GuildDeliveryScreen`ノード定義）
- 実装のヒント: `visible = false`を`.tscn`側とスクリプト側のどちらで初期化するかは、`.tscn`（`GuildDeliveryScreen`ノードのプロパティに`visible = false`を追加）で行うのが最もシンプル。スクリプト側の`_ready()`で明示的に`false`にする二重管理は避ける。
- 注意事項: 本タスクは`GuildDeliveryScreen`自身（`atelier/features/guild/ui/guild_delivery_screen.gd`/`.tscn`）を変更しない。すべての変更は`AlchemyScreen`側（CON-003の許容範囲）に閉じる。

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`, `atelier/features/alchemy/ui/alchemy_screen.tscn`
- テスト: `atelier/tests/integration/test_alchemy_screen.gd`（既存ファイルへのテストケース追記）
