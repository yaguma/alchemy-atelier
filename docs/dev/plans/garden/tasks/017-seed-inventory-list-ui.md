---
id: "017"
title: "SeedInventoryList（手持ち種一覧コンポーネント）を実装する"
status: done
priority: 4
dependencies: ["004"]
estimated_complexity: low
---

# Task: SeedInventoryList（手持ち種一覧コンポーネント）を実装する

## Goal

手持ちの種一覧を表示し、植え付け操作の起点となる`Control`継承コンポーネント`SeedInventoryList`を`features/garden/ui/`に実装する（US-001, ui-design/screens/garden.md「手持ち種一覧」）。

## Interfaces

```gdscript
# features/garden/ui/seed_inventory_list.gd
class_name SeedInventoryList
extends Control

signal seed_plant_requested(seed_id: StringName)  # 🔵 US-001

## seed_inventory（[{seed_id, count}]）とseed_masters（表示名解決用）を受け取り一覧を再構築する
func setup(seed_inventory: Array, seed_masters: Dictionary) -> void:
	pass
```

## Test Strategy

- [ ] **正常系**: `setup()`に2種類（`count > 0`）の種在庫を渡すと、2件の種エントリが表示される
- [ ] **正常系**: 各エントリの表示名が`seed_masters`から解決した`SeedMaster.name`と一致する
- [ ] **正常系**: エントリの「植える」ボタンを押下すると、対応する`seed_id`で`seed_plant_requested`シグナルが発行される
- [ ] **異常系**: `count == 0`の種エントリは一覧に表示されない、または「植える」ボタンが無効化される（在庫切れが視覚的に分かる）
- [ ] **境界値**: 空の`seed_inventory`（`[]`）で`setup()`しても一覧が空のまま正常に表示される（クラッシュしない）

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/ui-design/screens/garden.md`（手持ち種一覧の仕様）、`.claude/rules/godot-best-practices.md`「オブジェクトプーリング」（一覧項目が多くなる場合の将来的な最適化観点。本タスクでは種類数が少数想定のためプーリングは不要と判断してよい）
- 実装のヒント: `setup()`実行時に既存の子ノード（種エントリ表示用ノード）を`queue_free()`してから再構築するシンプルな実装でよい（`CardList`パターン、`.claude/rules/ui-components.md`「子コンポーネントを持つコンポーネント」参照）
- 注意事項: `seed_masters`に存在しない`seed_id`（マスター未ロード等の異常系）が渡された場合でもクラッシュしないよう、表示名解決時に`null`チェックを行う（NFR-101関連）

## Files

- 新規: `atelier/features/garden/ui/seed_inventory_list.gd`
- 新規: `atelier/features/garden/ui/seed_inventory_list.tscn`
- テスト: `atelier/tests/unit/features/garden/test_seed_inventory_list.gd`
