---
id: "016"
title: "PlantSlotView（庭スロット表示コンポーネント）を実装する"
status: done
priority: 4
dependencies: ["003", "004", "005", "008"]
estimated_complexity: medium
---

# Task: PlantSlotView（庭スロット表示コンポーネント）を実装する

## Goal

庭の1スロットを表示する`Control`継承コンポーネント`PlantSlotView`を`features/garden/ui/`に実装する。空き/生育中/収穫可能/枯死警告の4状態を色・アイコン・テキストの併記で表示する（FR-201〜204, NFR-201, AC-010）。

## Interfaces

```gdscript
# features/garden/ui/plant_slot_view.gd
class_name PlantSlotView
extends Control

enum Status { EMPTY, GROWING, HARVESTABLE, WITHER_WARNING }  # 🔵 FR-201〜204の4状態

signal harvest_pressed(slot_index: int)  # 🔵 US-004
signal wait_pressed(slot_index: int)     # 🟡 FR-302（任意要件、実質何もしない操作の明示ボタン）

var _slot_index: int = -1

## 空きスロットとして表示する
func setup_empty(slot_index: int) -> void:
	pass

## PlantState/SeedMasterを基に4状態のいずれかを算出し表示する。
## 内部でHarvest.is_matured/Harvest.is_deadとGameBalance.WITHER_WARNING_REMAINING_TURNSを用いて状態判定する
## 🟡 UI層からDomain層static funcを直接呼ぶ設計（表示専用の読み取りのみ、状態変更を伴わないためarchitecture.md
## 「Presentation層→Domain層参照可」に合致すると判断）
func setup(plant: PlantState, master: SeedMaster) -> void:
	pass
```

## Test Strategy

GdUnit4シーンテスト（`auto_free()` + `add_child()`でノードを構築し、直接メソッド呼び出し・signal検証を行う）:

- [ ] **正常系**: `setup_empty(0)`後、スロットが「空き」状態の見た目（色・アイコン・テキスト）で表示される（FR-201, NFR-201）
- [ ] **正常系**: `is_matured == false`の`PlantState`で`setup()`すると「生育中」状態で表示される（FR-202）
- [ ] **正常系**: `is_matured == true`かつ`is_dead == false`の`PlantState`で`setup()`すると「収穫可能」状態で表示され、収穫ボタンが有効化される（FR-203）
- [ ] **正常系**: 収穫可能状態でボタン押下すると`harvest_pressed(slot_index)`シグナルが発行される
- [ ] **境界値**: 枯死猶予の残りターン数が`GameBalance.WITHER_WARNING_REMAINING_TURNS`以下になると「枯死警告」状態に表示が切り替わる（FR-204, AC-010境界値）
- [ ] **正常系**: 「空き」「生育中」状態では収穫ボタンが無効化されている（FR-203「収穫可能スロットのみ収穫ボタンが有効化される」の裏側確認）

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/ui-design/screens/garden.md`（庭スロットの4状態表示仕様）、`.claude/rules/design-guide.md`（カード・パネルのスタイル統一ルール、色は`UiTheme`経由で参照）
- 実装のヒント: 状態算出ロジックは`setup()`内で`Harvest.is_matured(plant, master)` → 偽なら`GROWING`、真なら`Harvest.is_dead(plant, master)`で分岐、`is_dead`が偽でも残りターンが閾値以下なら`WITHER_WARNING`、という順で判定する
- 注意事項: `_process()`を定義しない（NFR-001、signal駆動の`setup()`呼び出しのみで表示を更新する）。色のハードコードは禁止、`UiTheme`定数を使用する（`.claude/rules/design-guide.md`）

## Files

- 新規: `atelier/features/garden/ui/plant_slot_view.gd`
- 新規: `atelier/features/garden/ui/plant_slot_view.tscn`
- テスト: `atelier/tests/unit/features/garden/test_plant_slot_view.gd`
