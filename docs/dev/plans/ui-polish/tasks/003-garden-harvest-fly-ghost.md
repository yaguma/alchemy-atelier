---
id: "003"
title: "庭画面で収穫時に素材アイコンが在庫へ飛ぶ演出を追加する"
status: done
priority: 3
dependencies: ["001"]
estimated_complexity: medium
---

# Task: 庭画面で収穫時に素材アイコンが在庫へ飛ぶ演出を追加する

## Goal

`GameState.material_harvested`受信時、収穫元スロットから種在庫リストへ素材アイコンが飛ぶ演出を追加する（`garden.md` L77）。

## Interfaces

```gdscript
# atelier/features/garden/ui/garden_screen.gd の既存 _on_material_harvested(material, slot_index) を変更
# 変更方針:
#   1. _refresh() を呼ぶ「前」に _slot_views[slot_index] の global_position を退避する
#   2. 退避したノードを UiEffects.fly_ghost() の source として使う（複製元は_refresh()で破棄される前に複製されるため安全）
#   3. _refresh() を実行（既存の状態更新）
#   4. UiEffects.fly_ghost(overlay_layer, 退避したsourceノード, _seed_inventory_list.global_position, duration) を呼ぶ
```

```gdscript
# GardenScreen に overlay_layer 用の Control を1つ追加（workshop_screen.gd の %OverlayLayer 前例踏襲）
@onready var _overlay_layer: Control = %OverlayLayer  # 🔵 workshop_screen.gdの既存パターン踏襲
```

## Test Strategy

- [x] `_on_material_harvested(material, slot_index)`受信時、`_overlay_layer`の子ノード数が一時的に1増える
- [x] 演出完了（`Tween.finished`）後、`_overlay_layer`の子ノード数が元に戻る
- [x] 演出完了後、通常の`_refresh()`による状態更新(スロットが空になる、在庫リストに素材が追加される)が正しく反映されている
- [x] エッジケース: `_refresh()`が`_slot_views[slot_index]`を先に破棄してしまうタイミング不整合が起きないこと（global_position退避が`_refresh()`より前であることを回帰テストで担保）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/garden_screen.gd`の`_on_material_harvested()`, `_refresh()`
- `_seed_inventory_list`（種在庫リストコンポーネント）の`global_position`を飛翔先として使う。リスト内の特定行位置までは追わず、リスト全体の位置で十分（🟡tdd-implementer裁量）
- workshop_screen.gdの`%OverlayLayer`実装を参照し、GardenScreenのシーン(.tscn)にも同名ノードを追加する

## Files

- 変更: `atelier/features/garden/ui/garden_screen.gd`, `atelier/features/garden/ui/garden_screen.tscn`
- テスト: `atelier/tests/integration/test_garden_screen_harvest_animation.gd`
