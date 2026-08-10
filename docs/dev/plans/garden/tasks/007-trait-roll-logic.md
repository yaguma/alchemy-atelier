---
id: "007"
title: "TraitRoll（特性選択ロジック）を実装する"
status: done
priority: 2
dependencies: ["004"]
estimated_complexity: low
---

# Task: TraitRoll（特性選択ロジック）を実装する

## Goal

収穫時に`SeedMaster.trait_pool`から特性タグを1つ選択する純粋関数`TraitRoll.roll_trait`を`features/garden/logic/trait_roll.gd`に実装する（FR-402）。乱数は`RngService`から払い出された値を引数として受け取り、自己生成しない。

## Interfaces

```gdscript
# features/garden/logic/trait_roll.gd
class_name TraitRoll

## seed_master.trait_poolからrng_value（[0,1)想定）を用いて一様に1つ選択する（🔵 core-systems.md L45-48, L69）
static func roll_trait(seed_master: SeedMaster, rng_value: float) -> StringName:
	pass
```

## Test Strategy

- [ ] **正常系**: `trait_pool = [&"holy", &"gold", &"none"]`のとき`rng_value = 0.0`で`&"holy"`（先頭）が選ばれる
- [ ] **正常系**: 同じ`trait_pool`で`rng_value`が末尾に近い値（例: `0.99`）のとき`&"none"`（末尾）が選ばれる
- [ ] **正常系**: `rng_value`が中間値のとき、対応するインデックスの要素が選ばれる（`int(rng_value * pool.size())`の計算を検証）
- [ ] **境界値**: `trait_pool`の要素数が1つのみの場合、`rng_value`の値によらず常にその1要素が返る
- [ ] **境界値**: `rng_value = 1.0`（本来`RngService`が返さない値だが防御的に）でも配列範囲外アクセスにならず末尾要素が返る（`clampi`でガードする）

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/core-systems.md` L45-48, L69（`TraitRoll`のクラス図・主要メソッド表）
- 実装のヒント: `var index := clampi(int(rng_value * pool.size()), 0, pool.size() - 1)`で範囲外アクセスを防止する
- 注意事項: `RandomNumberGenerator`等を内部で直接インスタンス化しないこと（FR-402、AC-013で`grep`検証される）

## Files

- 新規: `atelier/features/garden/logic/trait_roll.gd`
- テスト: `atelier/tests/unit/features/garden/test_trait_roll.gd`
