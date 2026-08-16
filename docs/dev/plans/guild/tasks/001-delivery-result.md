---
id: "001"
title: "DeliveryResult型を実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: DeliveryResult型を実装する

## Goal

`features/guild/logic/delivery_result.gd`に、納品1件の決算結果を表す`DeliveryResult`（`RefCounted`継承）を実装する。`DeliveryResolver.resolve`（タスク004）の戻り値として使われる。

## Interfaces

```gdscript
# features/guild/logic/delivery_result.gd（新規）
class_name DeliveryResult
extends RefCounted

var final_contribution: float  # 🔵 FR-002, AC-006
var final_reward: float        # 🔵 FR-002, AC-006
var order_matched: bool        # 🔵 FR-002, AC-006

func _init(p_final_contribution: float, p_final_reward: float, p_order_matched: bool) -> void:
	...
```

> 信号機: 🔵 フィールド構成はcore-systems.md L200-205クラス図に明記済み。🔴 ファイル配置（`features/guild/logic/`）はCON-003で本plan内新規決定（クラス図には配置未確定だった）

## Test Strategy

- [ ] 正常系: `DeliveryResult.new(13.0, 6.5, true)`で生成後、`final_contribution == 13.0`・`final_reward == 6.5`・`order_matched == true`が読み出せる（AC-006）
- [ ] 正常系: `order_matched = false`で生成しても他2フィールドの値は正しく保持される
- [ ] エッジケース: 同一引数で生成した2つのインスタンスの全フィールドが一致する（AC-006異常系）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/entities/product_instance.gd`・`atelier/shared/entities/result.gd`（`RefCounted`継承、`class_name`、`_init()`で全フィールドを設定するスタイル）
- 実装のヒント: プリミティブ型（`float`/`bool`）のみで構成されるため、`ProductInstance.clone()`のようなディープコピー用メソッドは不要（値型なので代入時に複製される）
- 注意事項: `shared/entities/`ではなく`features/guild/logic/`に配置する（CON-003）。他Feature（将来のrank plan等）から参照する可能性はあるが、現時点では`DeliveryResolver`と同一Featureの`logic/`に留める方針

## Files

- 新規: `atelier/features/guild/logic/delivery_result.gd`
- テスト: `atelier/tests/unit/features/guild/test_delivery_result.gd`
