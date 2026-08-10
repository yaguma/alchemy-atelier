---
id: "005"
title: "MasterDataLoaderの検証ロジックの骨組み（スタブ）を実装する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: low
---

# Task: MasterDataLoaderの検証ロジックの骨組み（スタブ）を実装する

## Goal

`shared/loaders/master_data_loader.gd` にマスターデータ相互参照検証の関数シグネチャを定義する。実マスターデータ型（`MaterialMaster`等）は後続Planで作られるため、本タスクでは中身は未実装のスタブ（常にtrueを返す）とする（CON-003）。

## Interfaces

```gdscript
# shared/loaders/master_data_loader.gd
class_name MasterDataLoader

# 指定カテゴリの.tresを全ロードする。Phase1ではスタブ（空配列固定）
static func load_all(category: StringName) -> Array:  # 🔵 FR-009のシグネチャ例に準拠
	# TODO(後続Plan): res://data/<category>/*.tres を列挙してロードする
	return []

# 素材配列の相互参照が解決可能かを検証する。Phase1ではスタブ（常にtrue）
static func validate_references(materials: Array) -> bool:  # 🔵 FR-009
	# TODO(後続Plan): materials内のcatalyst_tag / recipe.material_id等の相互参照を検証する
	return true
```

拡張方針（🟡 後続Planへの引き継ぎメモ、本タスクでは決定しない）: recipes/ranks/upgrades/daily_ordersの検証が必要になった段階で、引数追加または単一エントリポイント（`validate_all(dataset: Dictionary) -> bool`）への置き換えを検討する。

## Test Strategy

Domain層の`static func`だが、本Planでは中身がスタブのため簡易確認のみとする（本格的なテストは実マスターデータ型が揃う後続Planで追加）。

- [ ] `MasterDataLoader.load_all(&"materials")` が空配列 `[]` を返す
- [ ] `MasterDataLoader.validate_references([])` が `true` を返す
- [ ] `MasterDataLoader.validate_references([1, 2, 3])`（ダミー値）でも例外を投げず `true` を返す（スタブとして安全に動作することの確認）

## Implementation Notes

- 参照すべき既存文書: `.claude/rules/godot-best-practices.md`「一括プリロードとリソースキャッシュ」節（`MasterDataLoader.load_all`/`validate_references`の呼び出し例）
- `shared/loaders/` はユーザー確認済みの新規サブディレクトリ（将来複数のローダーが増えることを見越した配置）
- `class_name`付きの静的クラス（`Node`非継承）とし、Domain層相当（Infrastructure層寄りだが本Planでは`shared/`直下に配置）として副作用を持たせない

## Files

- 新規: `atelier/shared/loaders/master_data_loader.gd`
- 変更: なし
- テスト: `atelier/tests/integration/test_master_data_loader.gd`（簡易確認用、任意）
