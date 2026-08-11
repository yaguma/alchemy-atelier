---
id: "006"
title: "TraitActivationを実装する"
status: done
priority: 2
dependencies: ["003"]
estimated_complexity: medium
---

# Task: TraitActivationを実装する

## Goal

投入素材から発現する特性タグを判定する純粋関数`TraitActivation.resolve_traits`と、出現数を数える`count_trait_occurrences`を`features/alchemy/logic/`に実装する。

## Interfaces

```gdscript
# features/alchemy/logic/trait_activation.gd
class_name TraitActivation

## traits_unlocked=falseなら常に空配列。真の場合、同一特性タグの出現数が
## GameBalance.TRAIT_ACTIVATION_THRESHOLD以上のものだけを発現済みとして返す
## （触媒タグはこの閾値ルールの対象外のため除外する）
static func resolve_traits(
	materials: Array[MaterialInstance], traits_unlocked: bool
) -> Array[StringName]:
	...

## 投入素材中の特定特性タグの出現数を数える
static func count_trait_occurrences(
	materials: Array[MaterialInstance], trait_tag: StringName
) -> int:
	...
```

> 信号機: 🔵 `core-systems.md` L148-149（メソッド表、2026-08-10追加の実装レディネス監査#4対応版）に基づく

## Test Strategy

- [ ] 正常系: `&"holy"`タグを持つ素材が2個投入 → `activated_traits = [&"holy"]`
- [ ] 異常系: `&"holy"`タグを持つ素材が1個のみ → `activated_traits`に含まれない
- [ ] 境界値: `&"holy"`タグを持つ素材が3個以上 → `activated_traits`に`&"holy"`は1つだけ（重複追加されない）
- [ ] 境界値: `traits_unlocked = false`の場合、`&"holy"`が3個投入されていても`activated_traits`は空配列
- [ ] 正常系: `&"catalyst"`タグが2個以上あっても`activated_traits`には含まれない（発現閾値ルールの対象外）
- [ ] 正常系: `count_trait_occurrences(materials, &"holy")`が投入素材中の`&"holy"`保有数と一致する
- [ ] エッジケース: `materials`が空配列の場合`resolve_traits`は空配列、`count_trait_occurrences`は`0`を返す
- [ ] 正常系: 複数種の特性タグ（貢献度系・報酬系混在）が同時に発現条件を満たす場合、両方とも`activated_traits`に含まれる

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/logic/trait_roll.gd`（特性タグ関連のDomain層実装パターン）
- 実装のヒント: 投入素材から出現するユニークなタグ集合を`Dictionary`をordered setとして構築してから、各タグに`count_trait_occurrences`を適用しループする
- 注意事項: `&"catalyst"`は`_collect_unique_tags`で収集されても`resolve_traits`内で明示的にスキップする（`QualityCalculator`側で個別処理するため）

## Files

- 新規: `atelier/features/alchemy/logic/trait_activation.gd`
- テスト: `atelier/tests/unit/features/alchemy/test_trait_activation.gd`
