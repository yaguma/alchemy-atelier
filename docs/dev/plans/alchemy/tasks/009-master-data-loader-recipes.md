---
id: "009"
title: "MasterDataLoaderにrecipesカテゴリ対応を追加する"
status: done
priority: 2
dependencies: ["002", "008"]
estimated_complexity: medium
---

# Task: MasterDataLoaderにrecipesカテゴリ対応を追加する

## Goal

既存の`shared/loaders/master_data_loader.gd`（現状`&"materials"`カテゴリのみ対応のスタブ）に`&"recipes"`カテゴリの読み込みを追加し、`res://data/recipes/`配下の`RecipeMaster`をロードできるようにする。既存の`materials`ロード処理は変更しない。

## Interfaces

```gdscript
# shared/loaders/master_data_loader.gd（既存ファイルへの追記・変更）
class_name MasterDataLoader

const MATERIALS_DIR := "res://data/materials/"
const RECIPES_DIR := "res://data/recipes/"  # 新規
const TRES_EXTENSION := ".tres"

## categoryに対応するディレクトリ配下の全.tresをロードして返す
## &"materials"の場合SeedMaster/MaterialMaster混在、&"recipes"の場合RecipeMasterのみ
static func load_all(category: StringName) -> Array:
	# 既存ロジックを流用しつつ、resourceの型フィルタをcategoryに応じて分岐する
	...

static func _resolve_dir_path(category: StringName) -> String:
	match category:
		&"materials":
			return MATERIALS_DIR
		&"recipes":  # 新規
			return RECIPES_DIR
		_:
			return ""
```

> 信号機: 🔴 Plan設計時の懸念点3（`load_alchemy_master_data()`はFR-301のMAY要件だが、機能させるには本タスクの拡張が前提。既存`load_all`の型フィルタ判定を`category`に応じて分岐させる設計は本タスクでの新規補完）

## Test Strategy

- [ ] 正常系: `MasterDataLoader.load_all(&"recipes")`が`res://data/recipes/`配下の`.tres`を`RecipeMaster`の配列として返す
- [ ] 正常系: `MasterDataLoader.load_all(&"materials")`が既存通り`SeedMaster`/`MaterialMaster`混在配列を返す（回帰確認）
- [ ] 異常系: `MasterDataLoader.load_all(&"unknown_category")`が空配列を返す（既存の`_resolve_dir_path`のデフォルト分岐と同じ挙動）
- [ ] エッジケース: `res://data/recipes/`配下に`RecipeMaster`以外の型のリソースが混在していても、`&"recipes"`カテゴリでは`RecipeMaster`のみがフィルタされる

## Implementation Notes

- 参照すべき既存コード: 本ファイル自身（`atelier/shared/loaders/master_data_loader.gd`）の既存`load_all`/`_resolve_dir_path`実装
- 実装のヒント: `load_all`内の型フィルタ条件（`resource is SeedMaster or resource is MaterialMaster`）を、`category`ごとに許可する型集合を切り替える形にリファクタリングする（例: `category == &"recipes"`なら`resource is RecipeMaster`のみを許可）。既存の`materials`分岐の挙動は変更しない
- 注意事項: `validate_references()`（`SeedMaster`/`MaterialMaster`のID相互参照検証）は`RecipeMaster`が他IDを参照しないため対象外のまま変更不要（`data-schema.md` RecipeMaster節に相互参照の記載なし）

## Files

- 変更: `atelier/shared/loaders/master_data_loader.gd`
- テスト: `atelier/tests/integration/test_master_data_loader_recipes.gd`
