---
id: "003"
title: "PurchaseValidatorを実装する"
status: done
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: PurchaseValidatorを実装する

## Goal

工房強化・ショップの購入可否判定を担うDomain層の純粋関数`PurchaseValidator.can_purchase()`・`is_permanent_upgrade()`を実装する（FR-001, FR-002, FR-003, FR-403）。

## Interfaces

```gdscript
# atelier/features/workshop/logic/purchase_validator.gd
class_name PurchaseValidator

## gold >= price and already_purchased_count < max_purchase_count を返す（FR-001, core-systems.md L252）
static func can_purchase(
	gold: int, price: int, already_purchased_count: int, max_purchase_count: int
) -> bool:  # 🔵 FR-001

## upgrade.is_permanent を返す（FR-002）
static func is_permanent_upgrade(upgrade: UpgradeMaster) -> bool:  # 🔵 FR-002
```

副作用なし、`Node`非継承、`GameState`・UI層への参照禁止（FR-403、`.claude/rules/architecture.md`Functional Core原則）。

## Test Strategy

`docs/dev/plans/workshop/acceptance-criteria.md` AC-001, AC-002準拠。

- [ ] `can_purchase(gold=500, price=500, already_purchased_count=0, max_purchase_count=1)` → `true`
- [ ] `can_purchase(gold=1000, price=500, already_purchased_count=0, max_purchase_count=1)` → `true`
- [ ] **異常系**: `can_purchase(gold=499, price=500, already_purchased_count=0, max_purchase_count=1)` → `false`（ゴールド不足）
- [ ] **境界値**: `gold == price` → `true`（`>=`であり`>`ではない）
- [ ] **境界値**: `gold == price - 1` → `false`
- [ ] **境界値**: `already_purchased_count == max_purchase_count - 1`（上限到達直前）→ `true`
- [ ] **境界値**: `already_purchased_count == max_purchase_count`（上限到達直後）→ `false`
- [ ] **境界値**: `max_purchase_count`が実質無制限の大きな値（999）の場合、`already_purchased_count`が多少増えても`true`のまま
- [ ] `is_permanent_upgrade(upgrade)`: `is_permanent = true`の`UpgradeMaster` → `true`
- [ ] `is_permanent_upgrade(upgrade)`: `is_permanent = false`の`UpgradeMaster` → `false`

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/logic/quality_calculator.gd`（`static func`のみで構成される既存Functional Coreクラスの実装パターン）、`atelier/features/garden/logic/harvest.gd`（同様の純粋関数集合）
- 実装のヒント: 論理式1行の実装。`is_permanent_upgrade`はフィールドアクセスをそのまま返すだけ
- 注意事項: `UpgradeMaster`型（タスク001）が先に定義されている必要がある

## Files

- 新規: `atelier/features/workshop/logic/purchase_validator.gd`
- テスト: `atelier/tests/unit/features/workshop/test_purchase_validator.gd`
