---
id: "001"
title: "ProductInstance型を実装する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: ProductInstance型を実装する

## Goal

調合実行の成果を表すランタイムインスタンス型`ProductInstance`を`shared/entities/`に実装する。複数Feature（alchemy/guild）が共有するため、`MaterialInstance`と同じ配置・スタイルに従う。

## Interfaces

```gdscript
# shared/entities/product_instance.gd
class_name ProductInstance
extends RefCounted

var recipe_id: StringName
var quality_score: int
var activated_traits: Array[StringName]
var contribution: float
var reward: float

func _init(
	p_recipe_id: StringName,
	p_quality_score: int,
	p_activated_traits: Array[StringName],
	p_contribution: float,
	p_reward: float
) -> void:
	...

## GameState.get_state()の防御的コピー要件（FR-403）を満たすためのディープコピー
func clone() -> ProductInstance:
	...
```

> 信号機: 🔵 `core-systems.md` L129-135のフィールド定義・`MaterialInstance`と同型の配置判断（CON-003）に基づく

## Test Strategy

- [ ] 正常系: 全フィールドを指定して`_init`すると、各プロパティがその値になっている
- [ ] 正常系: `clone()`で生成したインスタンスは元と同じフィールド値を持つ
- [ ] エッジケース: `clone()`後に元の`activated_traits`配列を変更しても、複製側の`activated_traits`は影響を受けない（ディープコピーの検証）
- [ ] エッジケース: `activated_traits`が空配列でも`_init`/`clone()`が正常に動作する

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/entities/material_instance.gd`（同型のRefCounted継承・`clone()`パターン）
- 実装のヒント: `MaterialInstance`のコンストラクタ引数順序・`duplicate()`呼び出し箇所をそのまま踏襲する
- 注意事項: `activated_traits`は`Array[StringName]`型注釈を必ず付ける（`Variant`禁止）。`_init`内で`p_activated_traits.duplicate()`を使い、渡された配列への参照をそのまま保持しない

## Files

- 新規: `atelier/shared/entities/product_instance.gd`
- テスト: `atelier/tests/unit/shared/test_product_instance.gd`
