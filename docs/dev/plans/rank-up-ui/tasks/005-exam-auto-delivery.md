---
id: "005"
title: "試験中の調合成功時に自動で納品まで実行する"
status: pending
priority: 2
dependencies: ["002"]
estimated_complexity: medium
---

# Task: 試験中の調合成功時に自動で納品まで実行する

## Goal

`in_exam == true`の状態で`%ExecuteButton`押下により調合が成功した場合、`_on_product_crafted()`内で自動的に`GameState.deliver_pending_products()`を呼び出し、その結果を`%GuildDeliveryScreen.display_results()`へ即座に反映する。非試験中の挙動（手動`%EndTurnButton`での納品）は変更しない。

## Interfaces

```gdscript
# 🔵 FR-101, FR-407。既存 _on_product_crafted() への追加分岐
func _on_product_crafted(product: ProductInstance) -> void:
	_refresh()  # 既存、変更なし
	_show_toast("調合しました（品質%d、発現特性%d件）" % [product.quality_score, product.activated_traits.size()])  # 既存、変更なし

	# 🔵 FR-101。in_exam中のみ自動納品する新規分岐
	# _on_end_turn_pressed()（265〜268行目）と同型のスナップショットパターンを踏襲する
	var state := GameState.get_state()
	if state["in_exam"]:
		var snapshot: Array[ProductInstance] = state["pending_products"]
		var result := GameState.deliver_pending_products()
		_guild_delivery_screen.display_results(snapshot, result.value as Array[DeliveryResult])
```

## Test Strategy

- [ ] `in_exam=true`の状態でレシピ選択・素材投入後に`%ExecuteButton`を押下すると、`%GuildDeliveryScreen.get_item_count()`が1増加する（AC-005正常系）
- [ ] 上記操作後、`GameState.get_state()["pending_products"]`が空になっている（自動納品によりキューが消費されたことの確認、AC-005正常系）
- [ ] 上記操作後、`%GuildDeliveryScreen.get_total_contribution()`/`get_total_reward()`が0より大きい値を返す（AC-005正常系）
- [ ] `in_exam=false`の状態で同様に調合すると、`%GuildDeliveryScreen.get_item_count()`は変化しない（自動納品が発火しないことの回帰確認、AC-005異常系）
- [ ] `in_exam=true`で連続して2回調合すると、2回とも自動納品され`%GuildDeliveryScreen`の表示が都度更新される（毎回display_results()が呼ばれ0件にリセットされてから再構築されることの確認、AC-005境界値）

## Implementation Notes

- 参照すべき既存コード: `alchemy_screen.gd`の`_on_end_turn_pressed()`（265〜268行目）の「実行前にスナップショットを取り、products[i]とresults[i]の対応関係を保証する」契約をそのまま踏襲する（CON-003）
- `GameState.deliver_pending_products()`は`atelier/autoload/game_state_guild_delegate.gd`に実装済み。`in_exam`中は貢献度を`ExamState.exam_quota`へ加算する分岐が既に組み込まれている（変更不要）
- `%GuildDeliveryScreen`は既存ノードで`display_results(products, results)`APIをそのまま呼べる（`GuildDeliveryScreen`自体は変更しない、FR-408）
- `result.value`の型は`Array[DeliveryResult]`（`Result`型の`value`フィールド、`shared/entities/result.gd`参照）

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`
- テスト: `atelier/tests/integration/test_alchemy_screen.gd`
