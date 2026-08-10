---
id: "002"
title: "MaterialInstance型を実装する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: MaterialInstance型を実装する

## Goal

収穫・購入で得られる素材のランタイムインスタンス`MaterialInstance`を`shared/entities/material_instance.gd`に実装する。複数Feature（garden/alchemy等）で共有するため`features/garden/`配下ではなく`shared/entities/`に配置する（CON-003）。

## Interfaces

```gdscript
# shared/entities/material_instance.gd
class_name MaterialInstance
extends RefCounted

var instance_id: String              # 🔵 data-schema.md L46-53
var material_id: StringName          # 🔵
var quality_score: int               # 🔵 1〜5（S=5が上限）
var trait_tags: Array[StringName]    # 🔵

func _init(
	p_instance_id: String,
	p_material_id: StringName,
	p_quality_score: int,
	p_trait_tags: Array[StringName]
) -> void:  # 🔵
	pass

# FR-403/AC-014対応: GameState.get_state()が内部状態への参照を漏らさないための深い複製
func clone() -> MaterialInstance:  # 🔴 GameState.get_state()の防御的コピー要件を満たすための新規補完
	pass
```

## Test Strategy

- [ ] コンストラクタに渡した`instance_id`/`material_id`/`quality_score`/`trait_tags`がそれぞれのプロパティに正しく設定される
- [ ] `clone()`で生成したインスタンスの`trait_tags`配列を変更しても元のインスタンスの`trait_tags`は変化しない（配列の参照ではなく複製であることの確認）
- [ ] `clone()`で生成したインスタンスは元と別オブジェクトだが、`instance_id`/`material_id`/`quality_score`の値は等しい
- [ ] 空の`trait_tags`（`[]`）でも正常にインスタンス生成・`clone()`できる

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/data-schema.md` L46-53（`MaterialInstance`のJSON例とフィールド定義）
- 実装のヒント: `trait_tags`の複製は`trait_tags.duplicate()`（浅い複製で十分、要素が`StringName`のプリミティブ相当のため）
- 注意事項: 本タスクでは`instance_id`の採番ロジックは実装しない（呼び出し元＝`GameState`または`Harvest.harvest`が採番して渡す。採番方式は後続タスク011/012で決定する）

## Files

- 新規: `atelier/shared/entities/material_instance.gd`
- テスト: `atelier/tests/unit/shared/test_material_instance.gd`
