---
id: "004"
title: "レシピ解禁対象となる第2レシピのマスターデータを新規作成する"
status: done
priority: 2
dependencies: []
estimated_complexity: low
---

# Task: レシピ解禁対象となる第2レシピのマスターデータを新規作成する

## Goal

`res://data/recipes/`に既存`recipe_healing_potion`とは別の第2の`RecipeMaster` `.tres`を新規作成し、工房強化「レシピ解禁」の購入対象を用意する（FR-007）。

## Interfaces

```
# atelier/data/recipes/recipe_mana_tonic.tres
[gd_resource type="Resource" script_class="RecipeMaster" load_steps=2 format=3]

[ext_resource type="Script" path="res://features/alchemy/resources/recipe_master.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"recipe_mana_tonic"
name = "魔力秘薬"
base_contribution = 15.0
base_reward = 8.0
```

🔵 数値は既存`recipe_healing_potion`（`base_contribution=10.0, base_reward=5.0`）より高めの仮値（FR-007「数値は仮値でよい」に準拠）。`id`は`GameBalance.SECOND_RECIPE_ID`（タスク002）と一致させること。

## Test Strategy

`docs/dev/plans/workshop/acceptance-criteria.md` AC-016準拠。

- [ ] `res://data/recipes/`に`recipe_healing_potion.tres`とは別の`.tres`が存在する
- [ ] `MasterDataLoader.load_all(&"recipes")`が既存1件＋新規1件の計2件の`RecipeMaster`を返す
- [ ] 新規`.tres`の`id`が`GameBalance.SECOND_RECIPE_ID`（`&"recipe_mana_tonic"`）と一致する
- [ ] **異常系**: 購入前（`_unlocked_recipe_ids`に未追加の状態）で`execute_alchemy(&"recipe_mana_tonic", ...)`を呼ぶと`&"recipe_not_unlocked"`相当のエラーで失敗する（既存`AlchemySystem`の未解禁レシピ検証がそのまま機能することの確認。実装済みロジックの回帰確認のみで新規実装は伴わない）

## Implementation Notes

- 参照すべき既存コード: `atelier/data/recipes/recipe_healing_potion.tres`（フォーマットの完全な踏襲元）、`atelier/features/alchemy/resources/recipe_master.gd`（フィールド定義: `id: StringName`, `name: String`, `base_contribution: float`, `base_reward: float`）
- 実装のヒント: 既存`.tres`をコピーしてid/name/数値のみ変更する
- 注意事項: 本タスクはDirectモード（マスターデータ作成のみ、ロジック変更なし）。`recipe_unlock`購入によって`_unlocked_recipe_ids`へ追加された後の解禁確認はタスク009（`apply_upgrade()`のeffect_type分岐）側のAC-010で検証する

## Files

- 新規: `atelier/data/recipes/recipe_mana_tonic.tres`
