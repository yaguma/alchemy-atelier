---
id: "004"
title: "SeedMaster/MaterialMasterリソース型を実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: SeedMaster/MaterialMasterリソース型を実装する

## Goal

庭のマスターデータ型`SeedMaster`（種定義）と`MaterialMaster`（素材定義）を`features/garden/resources/`に`Resource`継承の`class_name`付きクラスとして実装する。両者とも`res://data/materials/*.tres`配下に混在配置される想定（data-schema.md L102, L128）。

## Interfaces

```gdscript
# features/garden/resources/seed_master.gd
class_name SeedMaster
extends Resource

@export var id: StringName = &""                     # 🔵 data-schema.md L106
@export var name: String = ""                         # 🔵
@export var produces_material_id: StringName = &""   # 🔵 収穫時に生成されるMaterialMasterのID
@export var maturity_turns: int = 1                   # 🔵 種別ごとに異なる（🟡TBD具体値、具体値は009タスクで仮決め）
@export var death_grace_turns: int = 2                # 🔵 成熟後の枯死猶予ターン数（🟡TBD具体値）
@export var base_quality: int = 1                     # 🔵 成熟直後に収穫した場合の品質スコア
@export var trait_pool: Array[StringName] = []        # 🔵 収穫時に一様乱数で選ばれる特性タグ候補
```

```gdscript
# features/garden/resources/material_master.gd
class_name MaterialMaster
extends Resource

@export var id: StringName = &""              # 🔵 data-schema.md L132-137
@export var name: String = ""                  # 🔵
@export var icon_path: String = ""             # 🔵
@export var shop_purchasable: bool = false     # 🔵 庭でのみ入手できる素材はfalse
@export var shop_base_quality: int = 1         # 🔵 shop_purchasable == trueの場合のみ使用
```

## Test Strategy

本タスクはDirectモード（`Resource`型定義のみ、ロジックを持たない）のため専用テストファイルは作成しない。`NFR-401`（`logic/`配下のpublic static funcが対象）の除外対象（`resources/*.gd`）に該当する。以下をレビュー観点として確認する。

- [ ] `SeedMaster`/`MaterialMaster`ともに`Resource`を継承し`class_name`が付与されている
- [ ] 全フィールドに型注釈と`@export`が付いている
- [ ] `gdlint`/`gdformat --check`が通る
- [ ] 他Featureからの参照可否ルール（`resources/*.gd`は参照可能）に反する実装（`state/`や`ui/`への依存）を持たない

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/data-schema.md` L102-148（SeedMaster/MaterialMasterのJSON例・フィールド表）
- 実装のヒント: `MaterialMaster`に旧`is_catalyst`フィールドは持たせない（`data-schema.md` L148の修正履歴の通り、触媒判定は`MaterialInstance.trait_tags.has(&"catalyst")`に一本化済み。本タスクのスコープ外だが将来の実装者向けの注意点として認識しておく）
- 注意事項: `.tres`ファイル自体（実データ）はこのタスクでは作成しない（後続タスク009で作成する）。本タスクは型定義（スキーマ）のみ

## Files

- 新規: `atelier/features/garden/resources/seed_master.gd`
- 新規: `atelier/features/garden/resources/material_master.gd`
