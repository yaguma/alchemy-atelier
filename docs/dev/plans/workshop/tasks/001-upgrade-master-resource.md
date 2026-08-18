---
id: "001"
title: "UpgradeMasterリソース型を定義する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: UpgradeMasterリソース型を定義する

## Goal

工房強化・ショップの購入対象マスターデータ型`UpgradeMaster`を`Resource`継承クラスとして定義する（FR-004）。

## Interfaces

```gdscript
# atelier/features/workshop/resources/upgrade_master.gd
class_name UpgradeMaster
extends Resource

@export var id: StringName = &""              # 🔵 FR-004
@export var name: String = ""                 # 🔵 FR-004
@export var is_permanent: bool = false         # 🔵 FR-004
@export var price: int = 0                     # 🔵 FR-004
@export var effect_type: StringName = &""      # 🔵 FR-004。alchemy_slot_increase/garden_slot_increase/recipe_unlock/catalyst_stock/seed_name_purchaseの5種類
@export var effect_value: Variant = null        # 🔵 FR-004。effect_typeに応じてint/StringNameを取る契約フィールド（設計都合のVariant濫用ではなく要件が明示する契約）
@export var max_purchase_count: int = 1        # 🔵 FR-004
```

## Test Strategy

`resources/*.gd`はロジックを持たないマスターデータ型定義のため、`.claude/rules/testing.md`「除外対象」に該当し専用テストは不要（既存`RecipeMaster`/`MaterialMaster`と同様）。フィールドの読み書きはタスク006（MasterDataLoader統合）・タスク008〜010（GameState統合）の中で間接的に検証される。

- [ ] `UpgradeMaster.new()`でインスタンス化でき、全7フィールドに値を設定・取得できることをスクリプト単体で確認（gdlint/gdformat通過を含む最低限の確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/resources/recipe_master.gd`（`class_name` + `extends Resource` + `@export`フィールドのみのパターン）、`atelier/features/garden/resources/material_master.gd`（同様のシンプルなマスターデータ型）
- 実装のヒント: 既存の`RecipeMaster`/`MaterialMaster`をそのまま模倣すればよい。ロジックを一切持たせない
- 注意事項: `effect_value`のみ`Variant`型だが、`.claude/rules/coding-style.md`の「`Variant`型の無条件使用は禁止」はDomain層の判断ロジックに対する規約であり、Resource型のマスターデータフィールド自体（要件が明示する契約）には適用されない。値の解釈・型ガードはタスク009の`GameState.apply_upgrade()`側で行う

## Files

- 新規: `atelier/features/workshop/resources/upgrade_master.gd`
