---
id: "004"
title: "AlchemyScreenの納品プレースホルダーをGuildDeliveryScreen連携に差し替える"
status: pending
priority: 3
dependencies: ["003"]
estimated_complexity: medium
---

# Task: AlchemyScreenをGuildDeliveryScreenと連携させる

## Goal

`AlchemyScreen`から`GameState.delivered`シグナル購読・`_on_delivered`トースト表示（FR-108プレースホルダー実装）を削除し、`_on_end_turn_pressed()`内でスナップショット取得→`GameState.deliver_pending_products()`→`GuildDeliveryScreen.display_results()`の直接呼び出しに置き換える（FR-006, FR-404, CON-003）。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd の変更点

class_name AlchemyScreen
extends Control

# 🔵 既存の@onready群に追加。alchemy_screen.tscnへGuildDeliveryScreenを子シーンとして
# 埋め込み、unique_name_in_owner=trueで%アクセスする（AlchemyPreviewPanel/MaterialInventoryList
# と同一の埋め込みパターン）
@onready var _guild_delivery_screen: GuildDeliveryScreen = %GuildDeliveryScreen  # 🟡 埋め込み方式自体はCON-003で明示されておらず既存パターンからの妥当な推測


func _ready() -> void:
    # 既存の接続はそのまま維持。GameState.delivered.connect(_on_delivered) は削除する 🔵 FR-006
    ...


func _exit_tree() -> void:
    # GameState.delivered.disconnect(_on_delivered) 相当の解除処理は削除する 🔵 FR-006
    ...


# 🔵 FR-006/FR-404で確定済み。GameState.deliver_pending_products()という呼び出し先自体は
# 変更しないが、前後にスナップショット取得とdisplay_results()呼び出しを追加する
func _on_end_turn_pressed() -> void:
    var snapshot: Array[ProductInstance] = GameState.get_state()["pending_products"]
    var result := GameState.deliver_pending_products()
    _guild_delivery_screen.display_results(snapshot, result.value as Array[DeliveryResult])


# _on_delivered(results: Array[DeliveryResult]) -> void は削除する 🔵 FR-006
```

## Test Strategy

- [ ] **正常系（配線確認）**: `execute_alchemy()`で2件を`pending_products`へ積んだ状態で`_on_end_turn_pressed()`相当の操作を行うと、`_guild_delivery_screen.get_item_count() == 2`になる（AC-009）
- [ ] **正常系（0件時のリセット配線）**: `pending_products`が空の状態で`_on_end_turn_pressed()`相当の操作を行っても、`GuildDeliveryScreen`が例外なく`display_results([], [])`を受け取り0件表示になる（AC-008/AC-009の接続確認）
- [ ] **正常系（既存回帰確認）**: `_on_delivered`ハンドラが削除され、`_show_toast()`が「N件を納品しました」を呼ばなくなったことをコード検査またはトーストテキストの非変化で確認する（AC-009）
- [ ] **異常系**: 該当なし（削除確認・配線確認が主目的のため）
- [ ] **境界値**: 該当なし

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/alchemy_screen.gd`の`_ready()`（L45-57）・`_exit_tree()`（L60-66）・`_on_end_turn_pressed()`（L264-266、現在の1行実装）・`_on_delivered()`（L284-286、削除対象）
- 実装のヒント: `atelier/features/alchemy/ui/alchemy_screen.tscn`へ`GuildDeliveryScreen`シーンを子ノードとして追加し、`unique_name_in_owner = true`を設定して`%GuildDeliveryScreen`でアクセスできるようにする（既存の`%AlchemyPreviewPanel`等と同一パターン、`alchemy_screen.tscn` L33-39参照）
- 注意事項: `GameState.deliver_pending_products()`という呼び出し先API自体は置き換えない（FR-404）。変更は`_on_end_turn_pressed()`内の前後処理の追加と、`_ready()`/`_exit_tree()`からの`delivered`購読削除、`_on_delivered`メソッド削除に限定する。`test_alchemy_screen.gd`の既存テスト（`test_ターン終了ボタンでdeliver_pending_productsが呼ばれ納品トーストが出る()`等）は本タスクの変更によって内容が古くなるため、削除または`GuildDeliveryScreen`連携を検証する内容へ更新すること

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`
- 変更: `atelier/features/alchemy/ui/alchemy_screen.tscn`
- 変更: `atelier/tests/integration/test_alchemy_screen.gd`（納品トースト関連の既存テストを更新）
