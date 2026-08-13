---
id: "007"
title: "ProductValueCalculatorを実装する"
status: done
priority: 2
dependencies: ["003"]
estimated_complexity: medium
---

# Task: ProductValueCalculatorを実装する

## Goal

品質倍率・特性ボーナスから調合物の貢献度・報酬を算出する純粋関数群を`features/alchemy/logic/`に実装する。特性ボーナスの系統別（貢献度系/報酬系）乗算合成もこの層の責務とする。

## Interfaces

```gdscript
# features/alchemy/logic/product_value_calculator.gd
class_name ProductValueCalculator

## base_contribution × quality_mult × trait_bonus
## match_bonus_multiplier相当の引数は受け取らない（FR-406、二重乗算バグ再発防止）
static func calculate_contribution(
	base_contribution: float, quality_mult: float, trait_bonus: float
) -> float:
	...

## base_reward × quality_mult × trait_bonus
static func calculate_reward(base_reward: float, quality_mult: float, trait_bonus: float) -> float:
	...

## activated_traitsのうちGameBalance.TRAIT_CONTRIBUTION_BONUSに登録されたタグの倍率を乗算合成する
static func resolve_contribution_bonus(activated_traits: Array[StringName]) -> float:
	...

## activated_traitsのうちGameBalance.TRAIT_REWARD_BONUSに登録されたタグの倍率を乗算合成する
static func resolve_reward_bonus(activated_traits: Array[StringName]) -> float:
	...
```

> 信号機: `calculate_contribution`/`calculate_reward`は🔵（`core-systems.md` L151-152, L154「2026-08-05修正Critical#4対応」, FR-406）。`resolve_contribution_bonus`/`resolve_reward_bonus`は🔴（`core-systems.md`のクラス図・メソッド表に存在しない追加API。FR-401/NFR-401の趣旨からDomain層に新設した設計判断、Plan設計時の懸念点4）

## Test Strategy

- [ ] 正常系: `calculate_contribution(10.0, 1.5, 1.3)`が`19.5`を返す
- [ ] 正常系: `calculate_reward(5.0, 1.5, 1.0)`が`7.5`を返す
- [ ] 正常系: `resolve_contribution_bonus([&"holy", &"purify"])`が`TRAIT_CONTRIBUTION_BONUS[&"holy"] * TRAIT_CONTRIBUTION_BONUS[&"purify"]`と一致する（乗算合成）
- [ ] 正常系: `resolve_contribution_bonus([&"gold"])`（報酬系タグのみ）が`1.0`を返す（系統をまたいで乗算しない）
- [ ] 異常系: `resolve_contribution_bonus([])`（空配列）が`1.0`を返す
- [ ] 境界値: `resolve_contribution_bonus([&"holy", &"purify", &"heal"])`（貢献度系3種すべて）が3倍率すべての積になる
- [ ] エッジケース: `calculate_contribution`/`calculate_reward`のシグネチャに`match_bonus_multiplier`相当の引数が存在しないことをコードで確認する（FR-406）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/logic/quality_calculator.gd`（タスク005で先に実装される。同ディレクトリの他Domain層ファイルとスタイルを揃える）
- 実装のヒント: `resolve_contribution_bonus`/`resolve_reward_bonus`は共通のプライベートヘルパー`_multiply_bonus(activated_traits, bonus_table)`に委譲する（`bonus_table.has(tag)`で登録済みタグのみ乗算し、未登録タグは無視する）
- 注意事項: `resolve_contribution_bonus`に報酬系タグを渡しても無視されること（系統間の非干渉）を必ずテストする。`core-systems.md`のクラス図に無い追加APIのため、実装後に設計文書側への反映（同期）を検討する旨をコードコメントに残す

## Files

- 新規: `atelier/features/alchemy/logic/product_value_calculator.gd`
- テスト: `atelier/tests/unit/features/alchemy/test_product_value_calculator.gd`
