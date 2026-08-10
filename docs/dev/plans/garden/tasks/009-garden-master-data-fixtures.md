---
id: "009"
title: "庭の初期マスターデータ（.tres）を作成する"
status: done
priority: 2
dependencies: ["004"]
estimated_complexity: low
---

# Task: 庭の初期マスターデータ（.tres）を作成する

## Goal

テスト・実プレイの両方で使用する初期2種（早熟の薬草・晩成の鉱石）の`SeedMaster`/`MaterialMaster`実データを`res://data/materials/`配下に`.tres`として作成する（CON-008, AC-011）。

## Interfaces

本タスクはリソースファイル（`.tres`）の作成のみで、コードのインターフェースは追加しない。以下の具体値を採用する。

| 項目 | `seed_herb`（早熟） 🔵 | `seed_ore`（晩成） 🔴 |
|---|---|---|
| `id` | `&"seed_herb"` | `&"seed_ore"` |
| `name` | "薬草の種" | "鉱石の種" |
| `produces_material_id` | `&"material_herb"` | `&"material_ore"` |
| `maturity_turns` | 2 | 5 |
| `death_grace_turns` | 2 | 3 |
| `base_quality` | 2 | 3 |
| `trait_pool` | `[&"holy", &"gold", &"none"]` | `[&"gold", &"sturdy", &"none"]` |

> `seed_herb`の値は`data-schema.md` L104-113のJSON例をそのまま採用（🔵）。`seed_ore`は`balance-design.md`「晩成＝希少鉱石(4〜5)」の範囲内で本plan内にて新規決定（🔴、CON-008でユーザー確認済みの仮決め方針に基づく）。

| 項目 | `material_herb` | `material_ore` |
|---|---|---|
| `id` | `&"material_herb"` | `&"material_ore"` |
| `name` | "薬草" | "鉱石" |
| `icon_path` | `"res://assets/icons/material_herb.png"` | `"res://assets/icons/material_ore.png"` |
| `shop_purchasable` | `false` | `false` |
| `shop_base_quality` | 0（未使用） | 0（未使用） |

## Test Strategy

本タスクはDirectモード（データファイル作成）のため専用テストファイルは作成しない。後続タスク010（MasterDataLoader）のテストがこのデータを読み込んで検証する。

- [ ] 4つの`.tres`ファイル（`seed_herb.tres`, `seed_ore.tres`, `material_herb.tres`, `material_ore.tres`）がGodotエディタでエラーなくロードできる
- [ ] `SeedMaster.produces_material_id`（`seed_herb`→`material_herb`, `seed_ore`→`material_ore`）が対応する`MaterialMaster.id`と一致している（相互参照が解決可能）
- [ ] `icon_path`が指す画像ファイルが存在しなくても`.tres`自体のロードは失敗しない（アイコン画像アセット自体は本plan外のため、パス文字列のみ設定する）

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/data-schema.md` L104-113（`seed_herb`のJSON例）
- 実装のヒント: Godotエディタでリソースファイルを新規作成する、または手動で`.tres`テキスト形式を記述する（`[gd_resource type="Resource" script_class="SeedMaster" ...]`形式）。`004`タスクで作成した`SeedMaster`/`MaterialMaster`スクリプトの`class_name`を参照する
- 注意事項: `icon_path`が指す画像アセット自体（`res://assets/icons/material_herb.png`等）はこのタスクでは作成しない（パス文字列の設定のみ、実ファイル未配置でも`.tres`ロード自体は成立する）

## Files

- 新規: `atelier/data/materials/seed_herb.tres`
- 新規: `atelier/data/materials/seed_ore.tres`
- 新規: `atelier/data/materials/material_herb.tres`
- 新規: `atelier/data/materials/material_ore.tres`
