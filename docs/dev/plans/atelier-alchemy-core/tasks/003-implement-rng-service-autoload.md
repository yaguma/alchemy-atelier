---
id: "003"
title: "RngService Autoloadの最小骨組みを実装する"
status: pending
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: RngService Autoloadの最小骨組みを実装する

## Goal

`RngService` Autoloadに `RandomNumberGenerator` をラップした最小APIを実装し、同一seedで同一の乱数列を再現できるようにする。Domain層（`logic/*.gd`）へは払い出した値のみを引数で渡す設計とし、RngService自体をDomain層へ注入しない。

## Interfaces

```gdscript
# autoload/rng_service.gd
extends Node

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()  # 🔵 FR-006

# 乱数シードを設定する。同一seedで以降のrandf()等が同一列を返すことを保証する
func set_seed(seed: int) -> void:  # 🔵 FR-006, FR-105
	pass

# 0.0〜1.0のfloat乱数を返す
func randf() -> float:  # 🔵 FR-006
	pass

# from〜toの範囲のfloat乱数を返す
func randf_range(from: float, to: float) -> float:  # 🟡 要件に明記なし。庭の枯死判定等の閾値比較用途を想定した拡張API
	pass

# from〜to(inclusive)の範囲のint乱数を返す
func randi_range(from: int, to: int) -> int:  # 🟡 要件に明記なし。特性抽選の個数決定等の用途を想定した拡張API
	pass
```

## Test Strategy

GUTテスト自体は009タスクで作成する。本タスクでは実装のみ行い、以下を満たすことを目安とする。

- [ ] `set_seed(12345)` 後に `randf()` を5回呼んだ結果と、再度 `set_seed(12345)` してから `randf()` を5回呼んだ結果が完全一致する（FR-105の核心）
- [ ] 異なるseedを設定した場合、乱数列が一致しない
- [ ] `seed = 0` を設定しても例外を投げず動作する（境界値）
- [ ] `randf_range(from, to)` が常に `[from, to]` の範囲内の値を返す

## Implementation Notes

- 参照すべき既存文書: `.claude/rules/tdd-implementation.md`「テストダブル使用」節（`double(RngServiceScript)`パターン。本タスクでは不要、009の統合テストは実値検証で足りる）
- `RandomNumberGenerator.seed` プロパティへの代入で `set_seed()` を実装する（Godot標準API）
- `project.godot` の Autoload登録で `RngService` を登録すること
- Domain層（後続Planの`logic/*.gd`）は乱数値を引数で受け取る設計のため、本タスクではDomain層との連携コードは書かない

## Files

- 新規: `atelier-alchemy/autoload/rng_service.gd`
- 変更: `atelier-alchemy/project.godot`（Autoload登録）
- テスト: `atelier-alchemy/tests/integration/test_rng_service.gd`（009タスクで作成）
