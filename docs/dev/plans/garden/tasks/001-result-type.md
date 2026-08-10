---
id: "001"
title: "Result型を実装する"
status: pending
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: Result型を実装する

## Goal

`Planting.plant`/`Harvest.harvest`等、Domain層の成功/失敗を表現するために必要な汎用`Result`型を`shared/entities/result.gd`に実装する。GDScriptにはジェネリクスがないため`value: Variant`を持つ設計とする。

## Interfaces

```gdscript
# shared/entities/result.gd
class_name Result
extends RefCounted

var success: bool = false          # 🔴 core-systems.mdはResult型自体の実体を定義していないための新規補完
var value: Variant = null          # 🔴 成功時ペイロード。呼び出し元は`is`で型ガードして使う
var error_code: StringName = &""   # 🔴 失敗時の理由コード

static func ok(p_value: Variant = null) -> Result:  # 🔴
	pass

static func fail(p_error_code: StringName) -> Result:  # 🔴
	pass
```

**エラーコード規約**（後続タスクで使用する`StringName`定数の一覧。このタスクでは定義しない、呼び出し側が直接`&"xxx"`で使う）:

| コード | 発生元（後続タスク） |
|---|---|
| `&"slot_full"` | Planting.plant |
| `&"seed_not_owned"` | GameState.plant_seed |
| `&"unknown_seed_id"` | GameState.plant_seed / harvest |
| `&"withered"` | Harvest.harvest |
| `&"not_matured"` | Harvest.harvest |
| `&"slot_not_found"` | GameState.harvest |

## Test Strategy

- [ ] `Result.ok(値)`で`success == true`かつ`value`に渡した値が格納される
- [ ] `Result.ok()`（引数省略）で`value == null`になる
- [ ] `Result.fail(&"slot_full")`で`success == false`かつ`error_code == &"slot_full"`になる
- [ ] `Result.fail(...)`で`value`が`null`のままである

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/core-systems.md` L61-69（`Planting.plant`/`Harvest.harvest`が`Result`型を戻り値とする旨の記載。ただし`Result`自体の実体はリポジトリ内に存在しないため本タスクで新規に土台を作る）
- 実装のヒント: `class_name Result extends RefCounted`。static factoryメソッド`ok`/`fail`のみで、外部から`Result.new()`を直接使うことは想定しない（が禁止はしない）
- 注意事項: `value`の型は`Variant`のままだが、これは汎用戻り値コンテナとしての性質上やむを得ない例外（`.claude/rules/coding-style.md`の`Variant`禁止規約は「無条件使用」を指し、呼び出し側で`is`型ガードする前提のコンテナ型は対象外と解釈する）。呼び出し元での`value`取得後は必ず型ガードすること

## Files

- 新規: `atelier/shared/entities/result.gd`
- テスト: `atelier/tests/unit/shared/test_result.gd`
