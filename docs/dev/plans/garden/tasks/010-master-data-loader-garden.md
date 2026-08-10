---
id: "010"
title: "MasterDataLoaderに庭マスターデータのロード・検証を実装する"
status: pending
priority: 2
dependencies: ["004", "009"]
estimated_complexity: medium
---

# Task: MasterDataLoaderに庭マスターデータのロード・検証を実装する

## Goal

現状スタブ（常に空配列/true返却）の`shared/loaders/master_data_loader.gd`に、`res://data/materials/`配下の`SeedMaster`/`MaterialMaster`を実際にロードする`load_all(&"materials")`と、両者の相互参照（`SeedMaster.produces_material_id` → `MaterialMaster.id`）を検証する`validate_references()`を実装する。

## Interfaces

```gdscript
# shared/loaders/master_data_loader.gd
class_name MasterDataLoader

## &"materials"のとき res://data/materials/ 配下の全.tresをロードして返す（SeedMaster/MaterialMaster混在）
## 🔵 data-schema.md L102, L128（両方とも同一ディレクトリ配下という記述に基づく）
static func load_all(category: StringName) -> Array:
	pass

## SeedMaster.produces_material_id が同一Array内のMaterialMaster.idを指しているか検証する
## 🔵 data-schema.md L255「マスターデータ間のID相互参照が解決可能か」
static func validate_references(materials: Array) -> bool:
	pass
```

## Test Strategy

- [ ] **正常系**: `load_all(&"materials")`が`res://data/materials/`配下の`.tres`（タスク009で作成した4件）を全てロードし、`SeedMaster`が2件・`MaterialMaster`が2件含まれる配列を返す
- [ ] **正常系**: ロードした`SeedMaster`インスタンスの`id`/`maturity_turns`等のフィールドがタスク009で設定した値と一致する
- [ ] **正常系**: タスク009のデータに対し`validate_references()`が`true`を返す（`seed_herb`→`material_herb`, `seed_ore`→`material_ore`が両方解決可能）
- [ ] **異常系**: `SeedMaster.produces_material_id`が存在しない`MaterialMaster.id`を指すテスト用配列を渡すと`validate_references()`が`false`を返す
- [ ] **異常系**: 未知のカテゴリ（例: `&"unknown_category"`）で`load_all`を呼ぶと空配列を返す（クラッシュしない）
- [ ] **境界値**: 空配列（`[]`）を`validate_references()`に渡すと`true`を返す（検証対象がなければエラーなし）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/loaders/master_data_loader.gd`（現状スタブ実装を確認）、`docs/design/atelier-alchemy-core/data-schema.md` L246-256（起動時検証の方針）
- 実装のヒント: `DirAccess.open(dir_path)`でディレクトリを列挙し、`.tres`拡張子のファイルを`load()`する。`load()`で得たリソースを`is SeedMaster`/`is MaterialMaster`で型判定して同一配列に格納する
- 注意事項: 本タスクではテスト実行環境（`res://data/materials/`）が実際に存在すること（タスク009で作成済み）を前提とする。GdUnit4のテストは実際の`res://data/materials/`パスに対して実行してよい（テスト専用の別ディレクトリを新設する必要はない、CON-005は`SeedMaster`/`MaterialMaster`型自体のテスト用フィクスチャが必要な場合の規定であり、本タスクは実データを検証する統合的な性質のテストであるため対象外と判断する）

## Files

- 変更: `atelier/shared/loaders/master_data_loader.gd`
- テスト: `atelier/tests/unit/shared/test_master_data_loader.gd`
