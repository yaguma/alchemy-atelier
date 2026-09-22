---
id: "006"
title: "調合画面で素材投入時のスライド演出を追加する"
status: done
priority: 3
dependencies: ["001"]
estimated_complexity: medium
---

# Task: 調合画面で素材投入時のスライド演出を追加する

## Goal

`_on_material_place_requested()`実行時、投入元の素材カードが在庫から投入枠へスライドする演出を追加する（`alchemy.md` L82）。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/material_inventory_list.gd への追加
func find_row_global_position(instance_id: String) -> Vector2  # 🟡 新規: 対象素材の在庫行のglobal_positionを返す（見つからない場合はVector2.ZEROまたはリスト自体の位置を返すフォールバック、実装時に決定）
```

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd の既存 _on_material_place_requested() を変更
# 変更方針:
#   1. 投入前に _material_inventory_list.find_row_global_position(instance_id) で開始位置を取得
#   2. 既存の状態更新シーケンス（_placed_material_ids.append() → _rebuild_slots() → _material_inventory_list.setup()）を実行
#   3. 直後に新スロット _slot_views[新index] の global_position を終了位置として UiEffects.fly_ghost() を呼ぶ
```

## Test Strategy

- [ ] `find_row_global_position()`が対象`instance_id`の行の位置を正しく返す
- [ ] `find_row_global_position()`に存在しない`instance_id`を渡した場合、クラッシュせずフォールバック値を返す
- [ ] `_on_material_place_requested()`実行後、投入枠スロットの位置へ向けたゴースト演出が発生する
- [ ] 演出中でも既存の状態更新（投入枠に素材が反映される、在庫から除外される）が即座に行われている（演出はあくまで視覚効果で、状態はブロックしない）
- [ ] エッジケース: 投入枠がすでに満杯で投入が拒否されるケースでは演出が発生しない

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/alchemy_screen.gd`の`_on_material_place_requested()`, `MaterialInventoryList.setup()`
- タスク001の`UiEffects.fly_ghost()`をそのまま利用する。overlay_layerはタスク003同様`%OverlayLayer`をAlchemyScreenにも新設する
- 状態更新（データ整合性）を演出完了と切り離す。演出はあくまで見た目の追加であり、テストが`await tween.finished`していなくても状態アサーションが独立して成立するよう実装する

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`, `atelier/features/alchemy/ui/material_inventory_list.gd`, `atelier/features/alchemy/ui/alchemy_screen.tscn`
- テスト: `atelier/tests/integration/test_alchemy_screen_material_slide_animation.gd`
