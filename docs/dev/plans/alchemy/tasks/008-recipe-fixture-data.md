---
id: "008"
title: "初期解禁レシピのマスターデータフィクスチャを作成する"
status: pending
priority: 2
dependencies: ["002"]
estimated_complexity: low
---

# Task: 初期解禁レシピのマスターデータフィクスチャを作成する

## Goal

初期状態で最低1件保証されるレシピ`recipe_healing_potion`の`.tres`フィクスチャを`res://data/recipes/`に作成する。

## Interfaces

```
res://data/recipes/recipe_healing_potion.tres

[gd_resource type="Resource" script_class="RecipeMaster" load_steps=2 format=3]

[ext_resource type="Script" path="res://features/alchemy/resources/recipe_master.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"recipe_healing_potion"
name = "回復薬"
base_contribution = 10.0
base_reward = 5.0
```

> 信号機: 🔵 `data-schema.md` L152-158のサンプル値をそのまま採用（CON-008）

## Test Strategy

- [ ] 正常系: `.tres`ファイルをGodotエディタ/`load()`でロードすると`RecipeMaster`型として認識される
- [ ] 正常系: ロード後の`id`が`&"recipe_healing_potion"`、`base_contribution`が`10.0`、`base_reward`が`5.0`である
- [ ] エッジケース: `BootScene`起動時のマスターデータロードでエラーが発生しない（既存の`atelier/features/garden`用フィクスチャ`atelier/data/materials/*.tres`と同様に整合すること）

## Implementation Notes

- 参照すべき既存コード: `atelier/data/materials/seed_herb.tres`, `atelier/data/materials/material_herb.tres`（既存`.tres`フィクスチャのフォーマット）
- 実装のヒント: Godotエディタでリソースを新規作成し`RecipeMaster`スクリプトをアタッチしてインスペクタから値を設定するか、既存`.tres`をテキストエディタで複製して書き換える
- 注意事項: ファイル配置ディレクトリ`res://data/recipes/`は本plan内で新規作成する（既存は`res://data/materials/`のみ）。タスク009（MasterDataLoader拡張）が読み込む前提のディレクトリ構成であることを確認する

## Files

- 新規: `atelier/data/recipes/recipe_healing_potion.tres`
- テスト: `atelier/tests/integration/test_recipe_fixture_load.gd`（`.tres`ロードの動作確認。GdUnit4の`load()`直接呼び出しで検証可）
