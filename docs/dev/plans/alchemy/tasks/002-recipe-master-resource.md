---
id: "002"
title: "RecipeMasterマスターデータ型を実装する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: RecipeMasterマスターデータ型を実装する

## Goal

調合物の設計図となるマスターデータ型`RecipeMaster`を`features/alchemy/resources/`に`Resource`継承で実装する。`SeedMaster`/`MaterialMaster`と同スタイルに従う。

## Interfaces

```gdscript
# features/alchemy/resources/recipe_master.gd
class_name RecipeMaster
extends Resource

@export var id: StringName = &""
@export var name: String = ""
@export var base_contribution: float = 0.0
@export var base_reward: float = 0.0
```

> 信号機: 🔵 `data-schema.md` L150-166のフィールド定義に基づく。🔴 `id`の型は要件定義書本文では`String`表記だが、`SeedMaster`/`MaterialMaster`の既存実装が`StringName`を採用済みのため、既存実装優先で`StringName`とする（Plan設計時の懸念点1、要件定義書側の表記との差異は許容する）

## Test Strategy

- [ ] 正常系: `RecipeMaster.new()`で生成し、`@export`フィールドに値を設定すると期待通り読み書きできる
- [ ] 正常系: `id`/`name`/`base_contribution`/`base_reward`のデフォルト値が仕様通り（空文字列・0.0）である
- [ ] エッジケース: `.tres`からロードした`RecipeMaster`インスタンスが`RecipeMaster`型として扱える（`is RecipeMaster`が真）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/resources/seed_master.gd`, `atelier/features/garden/resources/material_master.gd`（`Resource`継承・`@export`の書き方）
- 実装のヒント: ロジックを持たないデータ定義のみのファイルであり、`static func`等は含めない
- 注意事項: `resources/*.gd`は他Featureから参照可能な公開APIの一部（`.claude/rules/architecture.md`「公開APIパターン」）。フィールド名は`data-schema.md`のJSON例（`id`, `name`, `base_contribution`, `base_reward`）と完全一致させる

## Files

- 新規: `atelier/features/alchemy/resources/recipe_master.gd`
- テスト: `atelier/tests/unit/features/alchemy/test_recipe_master.gd`
