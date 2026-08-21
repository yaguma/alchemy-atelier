---
id: "003"
title: "MaterialInventoryList（素材在庫一覧コンポーネント）を実装する"
status: done
priority: 2
dependencies: []
estimated_complexity: low
---

# Task: MaterialInventoryList（素材在庫一覧コンポーネント）を実装する

## Goal

在庫素材を一覧表示し、クリックで投入枠への配置操作を起点とする`Control`継承コンポーネント`MaterialInventoryList`を`features/alchemy/ui/`に実装する（US-001, AC-002, AC-004）。行表示（`MaterialEntryRow`相当）は本タスク内の実装詳細として扱い、別タスクに分割しない（gardenの`SeedInventoryList`/`SeedEntryRow`踏襲）。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/material_inventory_list.gd
class_name MaterialInventoryList
extends Control

signal material_place_requested(material_instance_id: String)  # 🔵 FR-101

## 表示対象のMaterialInstance配列を受け取り一覧を再構築する。
## 呼び出し元（AlchemyScreen）が投入済み素材を除外済みの配列を渡す契約とする
## （「投入済み」はドメイン層に存在しないUIローカルな一時状態のため） 🟡
func setup(materials: Array[MaterialInstance]) -> void:
	pass

func get_entry_count() -> int:  # テスト用 🔵
	pass
```

```gdscript
# atelier/features/alchemy/ui/material_entry_row.gd（本タスク内で実装、Filesにのみ明記しInterfacesは省略可）
class_name MaterialEntryRow
extends HBoxContainer

signal place_pressed(material_instance_id: String)

func setup(material: MaterialInstance) -> void:
	pass
```

## Test Strategy

- [ ] **正常系**: `setup()`に2件の`MaterialInstance`を渡すと、2件のエントリが表示される
- [ ] **正常系**: 各エントリに`quality_score`・`trait_tags`が表示される
- [ ] **正常系**: エントリの「配置」ボタン（またはカード自体）を押下すると、対応する`instance_id`で`material_place_requested`シグナルが発行される
- [ ] **境界値**: 空の配列（`[]`）で`setup()`しても一覧が空のまま正常に表示される（クラッシュしない）
- [ ] **境界値**: 大量（20件程度）の素材を渡しても表示が破綻しない

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/seed_inventory_list.gd` + `seed_entry_row.gd`（同型パターン。`CardList`方式で`setup()`実行時に既存子ノードを`queue_free()`してから再構築する）、`atelier/shared/entities/material_instance.gd`
- 実装のヒント: 「投入済み除外」のフィルタリングはこのコンポーネント自身では行わない。`AlchemyScreen`側が事前にフィルタ済み配列を渡す契約とすることで、「投入済み」という概念（ドメイン層にもGameStateにも存在しないUIローカルな一時状態）をこのコンポーネントに持ち込まない
- 注意事項: 素材名表示は`MaterialMaster`名称解決を行わず`String(material.material_id)`のフォールバック表示に留める（タスク002のAlchemySlotViewと同方針、本Planのスコープ外）

## Files

- 新規: `atelier/features/alchemy/ui/material_inventory_list.gd`
- 新規: `atelier/features/alchemy/ui/material_inventory_list.tscn`
- 新規: `atelier/features/alchemy/ui/material_entry_row.gd`
- 新規: `atelier/features/alchemy/ui/material_entry_row.tscn`
- テスト: `atelier/tests/unit/features/alchemy/test_material_inventory_list.gd`
