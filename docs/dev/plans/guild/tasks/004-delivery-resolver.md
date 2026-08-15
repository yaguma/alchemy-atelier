---
id: "004"
title: "DeliveryResolverを実装する"
status: pending
priority: 2
dependencies: ["001", "002"]
estimated_complexity: medium
---

# Task: DeliveryResolverを実装する

## Goal

`features/guild/logic/delivery_resolver.gd`に、納品判定・最終価値算出を担う副作用なしの`DeliveryResolver`（`matches_order`・`resolve`の2 static func）を実装する。`daily_order = null`時の非合致契約（昇格試験からの呼び出し想定）を含む。

## Interfaces

```gdscript
# features/guild/logic/delivery_resolver.gd（新規）
class_name DeliveryResolver

## daily_order=nullの場合は必ずfalseを返す（FR-201, AC-003）。
## condition_type="item"ならproduct.recipe_id == daily_order.target_recipe_idで判定（FR-101, AC-001）。
## condition_type="trait"ならproduct.activated_traits.has(daily_order.target_trait)で判定（FR-102, AC-002）
static func matches_order(product: ProductInstance, daily_order: DailyOrderMaster) -> bool:  # 🔵
	...

## matches_orderの結果に応じて指定合致ボーナスをfinal_contribution/final_rewardへ適用する。
## 合致時: final_contribution = product.contribution * daily_order.match_bonus_multiplier（FR-103, AC-004）
## 非合致時: 倍率1.0のまま（FR-104, AC-005）。daily_order=null時も非合致として倍率1.0（FR-201, AC-003）
static func resolve(product: ProductInstance, daily_order: DailyOrderMaster) -> DeliveryResult:  # 🔵
	...
```

> 信号機: 🔵 core-systems.md L211-214のメソッド表に完全準拠。乱数不使用（FR-402, AC-013）・`GameState`等の外部状態を参照しない純粋関数（FR-401, AC-013）

## Test Strategy

- [ ] 正常系（AC-001）: `condition_type="item"`・`target_recipe_id`一致 → `matches_order`が`true`
- [ ] 正常系（AC-001）: `condition_type="item"`・`target_recipe_id`不一致 → `matches_order`が`false`
- [ ] 正常系（AC-002）: `condition_type="trait"`・`activated_traits`に`target_trait`を含む → `matches_order`が`true`
- [ ] 正常系（AC-002）: `condition_type="trait"`・`activated_traits`が空配列 → `matches_order`が`false`
- [ ] 異常系（AC-003）: `daily_order = null` → `matches_order`が`false`、`resolve`は`order_matched = false`・倍率1.0でクラッシュしない
- [ ] 正常系（AC-004）: 合致時、`contribution = 10.0, reward = 5.0, match_bonus_multiplier = 1.3`で`final_contribution = 13.0`・`final_reward = 6.5`
- [ ] 境界値（AC-004）: `match_bonus_multiplier = 1.5`のインスタンスでは1.5倍が適用される（`GameBalance`定数ではなくインスタンス値を使う、CON-006）
- [ ] 正常系（AC-005）: 非合致時、`final_contribution`・`final_reward`が元の値のまま変化しない
- [ ] 境界値（AC-004）: `contribution = 0.0`・`reward = 0.0`でも乗算結果が`0.0`のまま破綻しない
- [ ] 異常系（AC-007）: `condition_type`が`"item"`/`"trait"`以外の未知値の場合、`matches_order`が`false`を返しクラッシュしない（NFR-101）
- [ ] 異常系（AC-013）: 同一引数で複数回呼び出しても常に同じ結果を返す（純粋性の確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/logic/quality_calculator.gd`（`logic/`層の`static func`実装スタイル・コメント規約）
- 実装のヒント: `matches_order`冒頭で`if daily_order == null: return false`のガードを最初に置く（CON-008）。`resolve`も同様に`daily_order == null`または`matches_order`が`false`のケースを1本化し、`order_matched`変数に結果を保持してから`final_contribution`/`final_reward`を計算する
- 注意事項: 指定合致ボーナスの適用は本関数が一手に担う。`ProductValueCalculator`側では絶対に適用しない（FR-403, AC-014。二重乗算バグの再発防止）

## Files

- 新規: `atelier/features/guild/logic/delivery_resolver.gd`
- テスト: `atelier/tests/unit/features/guild/test_delivery_resolver.gd`
