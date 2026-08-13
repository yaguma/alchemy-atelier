---
id: "005"
title: "QualityCalculatorを実装する"
status: done
priority: 2
dependencies: ["003"]
estimated_complexity: medium
---

# Task: QualityCalculatorを実装する

## Goal

投入素材から品質スコアを算出する純粋関数`QualityCalculator.calculate_quality`と、品質スコアから倍率を引く`quality_multiplier`を`features/alchemy/logic/`に実装する。

## Interfaces

```gdscript
# features/alchemy/logic/quality_calculator.gd
class_name QualityCalculator

## 投入素材の品質スコア平均を四捨五入し、traits_unlocked=true かつ触媒タグ保有時は
## 最終品質に+1（上限5クランプ）する。traits_unlocked=falseの場合は触媒があってもボーナス無効
static func calculate_quality(materials: Array[MaterialInstance], traits_unlocked: bool) -> int:
	...

## 品質スコア(1〜5)に対する単調非減少の乗数をGameBalance.QUALITY_MULTIPLIER_TABLEから引く
static func quality_multiplier(quality_score: int) -> float:
	...
```

> 信号機: 🔵 `core-systems.md` L146（品質確定ロジック、2026-08-05修正Critical#6対応版・2026-08-10修正実装レディネス監査#4対応版）・L147（品質倍率）に基づく

## Test Strategy

- [ ] 正常系: `quality_score = [3, 3]`（割り切れる平均） → `3`
- [ ] 正常系: `quality_score = [3, 4]`（平均3.5） → `4`（四捨五入）
- [ ] 境界値: `quality_score = [2, 3]`（平均2.5） → `3`、`quality_score = [2, 2, 3]`（平均2.33） → `2`
- [ ] 正常系: `traits_unlocked = true`かつ触媒素材（`trait_tags = [&"catalyst"]`）を含む場合、四捨五入後の値に+1される
- [ ] 境界値: 四捨五入後の値が`5`のときに触媒があっても`5`のまま（上限クランプ）
- [ ] 異常系: `traits_unlocked = false`の場合、触媒素材を含んでいてもボーナスが適用されない
- [ ] エッジケース: `materials`が空配列でもクラッシュせず`GameBalance.QUALITY_SCORE_MIN`を返す
- [ ] 正常系: `quality_multiplier(3)`が`GameBalance.QUALITY_MULTIPLIER_TABLE[3]`と一致する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/logic/harvest.gd`, `atelier/features/garden/logic/trait_roll.gd`（Domain層のstatic func実装パターン、`GameBalance`参照の仕方）
- 実装のヒント: `roundi(average)`はGodotの標準丸め（0.5を絶対値方向に丸める）で四捨五入と一致する。触媒判定は`materials.any(func(m): return m.trait_tags.has(&"catalyst"))`相当のヘルパー（`_has_catalyst`）を`static func`として切り出す
- 注意事項: 空配列時の戻り値（`GameBalance.QUALITY_SCORE_MIN`）はPlan設計時の懸念点5として記録された防御的分岐であり、`execute_alchemy`側は`SlotState.can_execute()`により実運用では到達しない。`clampi(rounded, GameBalance.QUALITY_SCORE_MIN, GameBalance.QUALITY_SCORE_MAX)`で最終クランプする

## Files

- 新規: `atelier/features/alchemy/logic/quality_calculator.gd`
- テスト: `atelier/tests/unit/features/alchemy/test_quality_calculator.gd`
