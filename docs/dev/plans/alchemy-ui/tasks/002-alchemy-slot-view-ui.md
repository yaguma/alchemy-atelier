---
id: "002"
title: "AlchemySlotView（投入枠表示コンポーネント）とUiTheme色定数を実装する"
status: done
priority: 2
dependencies: []
estimated_complexity: low
---

# Task: AlchemySlotView（投入枠表示コンポーネント）を実装する

## Goal

調合投入枠1件を表示する表示専用コンポーネント`AlchemySlotView`を実装する（AC-003, AC-005）。空/投入済みの2状態を`UiTheme`定数経由の色・テキストで判別可能にし、投入済み枠のみ「クリア」操作を受け付ける。あわせて`UiTheme`（`shared/theme/theme.gd`）へ調合画面用の色定数を追加する。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_slot_view.gd
class_name AlchemySlotView
extends Control

signal clear_requested(slot_index: int)  # 🔵 FR-102。ClearButton.pressedのみを起点とする（PlantSlotView.harvest_pressed踏襲）

enum Status { EMPTY, FILLED }

## 空きスロットとして表示する 🔵
func setup_empty(slot_index: int) -> void:
	pass

## 投入済みスロットとして表示する。material_idを暫定名称としてそのまま表示する
## （MaterialMaster辞書がGameState.get_state()に未公開のため、本Planでは名称解決を行わない） 🟡
func setup(slot_index: int, material: MaterialInstance) -> void:
	pass

func get_status() -> Status:  # テスト用 🔵
	pass

func get_slot_index() -> int:  # テスト用 🔵
	pass

static func status_text(status: Status) -> String:  # 🔵 PlantSlotView.status_text()踏襲
	pass

static func status_color(status: Status) -> Color:  # 🔵 UiTheme.COLOR_ALCHEMY_SLOT_*を参照
	pass
```

```gdscript
# atelier/shared/theme/theme.gd への追記
# 🟡 具体色コードはビジュアルデザインパス未確定のため暫定値（gardenのCOLOR_SLOT_*と同様の運用）
const COLOR_ALCHEMY_SLOT_EMPTY := Color("#B0AFA8")
const COLOR_ALCHEMY_SLOT_FILLED := Color("#7FA8C9")
```

## Test Strategy

- [ ] **正常系**: `setup_empty(0)`を呼ぶと`get_status()`が`Status.EMPTY`を返し、`_clear_button`（クリアボタン）が無効化される
- [ ] **正常系**: `setup(1, material)`（`quality_score=3`, `trait_tags=[&"holy"]`のMaterialInstance）を呼ぶと`get_status()`が`Status.FILLED`を返し、`_clear_button`が有効化される
- [ ] **正常系**: 投入済み状態で`_clear_button`を押下すると`clear_requested(slot_index)`シグナルが発行される
- [ ] **異常系**: 空状態では`_clear_button`が無効化されているため、押下操作を試みても`clear_requested`シグナルは発行されない
- [ ] **境界値**: `get_slot_index()`が`setup()`/`setup_empty()`に渡した`slot_index`と一致する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/plant_slot_view.gd`（同型パターン。`Status` enum、`_apply_display()`、`static func status_text/status_color`）、`atelier/shared/entities/material_instance.gd`（`MaterialInstance`のフィールド: `instance_id`, `material_id`, `quality_score`, `trait_tags`）
- 実装のヒント: `_apply_display()`で`self_modulate = status_color(_status)`・`_clear_button.disabled = (_status == Status.EMPTY)`を設定するパターンをPlantSlotViewからそのまま踏襲する。素材名表示は`String(material.material_id)`のフォールバック表示に留める（`MaterialMaster`名称解決は本Planのスコープ外）
- 注意事項: `clear_requested`はクリアボタン押下のみを起点とし、枠全体への`gui_input`ハンドラは追加しない（PlantSlotViewの`harvest_button`単一操作パターンとの一貫性のため）

## Files

- 新規: `atelier/features/alchemy/ui/alchemy_slot_view.gd`
- 新規: `atelier/features/alchemy/ui/alchemy_slot_view.tscn`
- 変更: `atelier/shared/theme/theme.gd`
- テスト: `atelier/tests/unit/features/alchemy/test_alchemy_slot_view.gd`
