---
id: "018"
title: "GardenScreen（庭画面本体）を実装する"
status: pending
priority: 4
dependencies: ["013", "014", "015", "016", "017"]
estimated_complexity: high
---

# Task: GardenScreen（庭画面本体）を実装する

## Goal

`PlantSlotView`・`SeedInventoryList`・ターン終了ボタン・ショップ導線プレースホルダーを統合した`GardenScreen`を実装する。`GameState`のsignalを購読して画面を更新し、単体（`MainScene`非組み込み）でGdUnit4シーンテストにより種植え→ターン終了→収穫の一連フローが検証できる状態にする（FR-404, FR-406, US-001〜US-007）。

## Interfaces

```gdscript
# features/garden/ui/garden_screen.gd
class_name GardenScreen
extends Control

signal shop_requested()  # 🔵 FR-301（プレースホルダー導線）

const PlantSlotViewScene = preload("res://features/garden/ui/plant_slot_view.tscn")

@onready var _slots_container: Container = %SlotsContainer
@onready var _seed_inventory_list: SeedInventoryList = %SeedInventoryList
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _shop_button: Button = %ShopButton

func _ready() -> void:
	pass

## GameState.get_state()を再取得し、スロット一覧・種一覧を再構築する
func _refresh() -> void:
	pass

func _exit_tree() -> void:
	pass
```

## Test Strategy

GdUnit4の`scene_runner("res://features/garden/ui/garden_screen.tscn")`を用いたシーンテスト（`.claude/rules/testing.md`「E2E相当のテスト」参照）:

- [ ] **正常系（種植えフロー）**: `SeedInventoryList`から種植えを要求すると`GameState.plant_seed`が呼ばれ、`GardenScreen`の該当スロット表示が「生育中」に更新される（US-001）
- [ ] **正常系（ターン終了フロー）**: `EndTurnButton`押下で`GameState.advance_turn_growth()`が呼ばれ、生育中スロットの表示が進行する（US-003）
- [ ] **正常系（収穫フロー）**: 収穫可能スロットの収穫ボタン押下で`GameState.harvest`が呼ばれ、該当スロットが「空き」表示に戻り、収穫結果（品質・特性）に応じた通知が行われる（US-004, US-005）
- [ ] **正常系（枯死通知）**: `plants_withered`シグナル受信時に対象スロットの枯死通知が表示される（FR-303, US-006）
- [ ] **正常系（ショップ導線）**: `ShopButton`押下で`shop_requested`シグナルが発行され、`GardenState`等の状態は変化しない（AC-012, FR-405）
- [ ] **異常系**: 植え付け失敗（スロット満杯・種在庫切れ）時にトースト等のフィードバックが表示される（NFR-202）
- [ ] **保守性確認**: `GardenScreen`のソースが`exam_state`/`in_exam`を一切参照していないことを`grep`で確認する（FR-406）

## Implementation Notes

- 参照すべき既存コード: `docs/design/atelier-alchemy-core/ui-design/screens/garden.md`（画面構成・イベント一覧: `OnSeedPlanted`, `OnHarvested`, `OnPlantWithered`, `OnTurnEnded`）、`.claude/rules/ui-components.md`（`_exit_tree()`での破棄チェックリスト）
- 実装のヒント: `_ready()`で`GameState`の各signal（`seed_planted`, `plant_seed_failed`, `material_harvested`, `harvest_failed`, `plants_withered`, `turn_growth_advanced`）を購読し、いずれも`_refresh()`または個別のフィードバック表示メソッドを呼ぶ。`_exit_tree()`で全て`disconnect()`する（`GameState`はAutoloadのため明示的解除必須）
- 注意事項: 本タスクの完了をもって「MainSceneへの組み込みは別task」（FR-404）とするスコープ境界を厳守する。`GardenScreen`単体の`.tscn`をGdUnit4の`scene_runner()`でロードしてテストが通ることを完了条件とし、`MainScene`側のタブ切替・`visible`制御は一切実装しない

## Files

- 新規: `atelier/features/garden/ui/garden_screen.gd`
- 新規: `atelier/features/garden/ui/garden_screen.tscn`
- テスト: `atelier/tests/integration/test_garden_screen.gd`
