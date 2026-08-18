---
id: "005"
title: "触媒常備の対象となるmaterial_catalystマスターデータを新規作成する"
status: pending
priority: 2
dependencies: []
estimated_complexity: low
---

# Task: 触媒常備の対象となるmaterial_catalystマスターデータを新規作成する

## Goal

`res://data/materials/`に専用`MaterialMaster` `.tres`（`material_catalyst`）を新規作成する（FR-016）。ユーザーヒアリングで、既存素材の流用ではなく専用IDの新規作成が確定している。

## Interfaces

```
# atelier/data/materials/material_catalyst.tres
[gd_resource type="Resource" script_class="MaterialMaster" load_steps=2 format=3]

[ext_resource type="Script" path="res://features/garden/resources/material_master.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"material_catalyst"
name = "触媒"
icon_path = "res://assets/icons/material_catalyst.png"
shop_purchasable = true
shop_base_quality = 3
```

🔵 `data-schema.md`のMaterialMaster節（L131-137）記載例をそのまま反映。`id`は`GameBalance.CATALYST_MATERIAL_ID`（タスク002）と一致させること。

## Test Strategy

`docs/dev/plans/workshop/acceptance-criteria.md` AC-011準拠（前半部分）。

- [ ] `res://data/materials/`に`material_catalyst.tres`が存在する
- [ ] `MasterDataLoader.load_all(&"materials")`が既存4件（`material_herb`/`material_ore`/`seed_herb`/`seed_ore`）＋新規1件の計5件を返す
- [ ] 新規`.tres`の`id`が`GameBalance.CATALYST_MATERIAL_ID`（`&"material_catalyst"`）、`shop_purchasable`が`true`、`shop_base_quality`が`3`と一致する

## Implementation Notes

- 参照すべき既存コード: `atelier/data/materials/material_herb.tres`（フォーマットの踏襲元）、`atelier/features/garden/resources/material_master.gd`（フィールド定義: `id`, `name`, `icon_path`, `shop_purchasable: bool`, `shop_base_quality: int`）
- 実装のヒント: 既存`.tres`をコピーしてid/name/shop_purchasable/shop_base_qualityを変更する。`icon_path`は実アセットが未作成でも既存パターンに合わせた仮パスでよい（アセット自体の存在確認は本plan外）
- 注意事項: 本タスクはDirectモード。`shop_base_quality`は`MaterialMaster`のスキーマ上の必須フィールドとして設定するが、実際の`catalyst_stock`購入時の`MaterialInstance.quality_score`は`GameBalance.CATALYST_BASE_QUALITY_SCORE`（既存定数）を使用し、この`shop_base_quality`は参照しない（CON-010、design phaseで確定済みの意図的な差異）

## Files

- 新規: `atelier/data/materials/material_catalyst.tres`
