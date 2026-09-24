---
id: "004"
title: "庭画面で枯死時のフェードアウト演出を追加する"
status: done
priority: 3
dependencies: ["001"]
estimated_complexity: medium
---

# Task: 庭画面で枯死時のフェードアウト演出を追加する

## Goal

`GameState.plants_withered`受信時、対象スロットが灰色化しフェードアウトする演出を追加する（`garden.md` L78）。

## Interfaces

```gdscript
# atelier/features/garden/ui/garden_screen.gd の既存 _on_plants_withered(slot_indices) を変更
# 現状: トースト表示のみ（_refreshは呼ばれない。直後の turn_growth_advanced が_refresh()を担う既存設計）
# 変更方針: 各 slot_indices について、_refresh()実行前に該当 _slot_views[i] の global_position を退避し、
#   UiEffects.fly_ghost() で複製をその場（同位置）でフェードアウトさせる方式に統一する
#   （play_wither_fade()を実ノードへ直接使うと、直後のturn_growth_advanced起因のrefreshで
#    Tween完走前にノードが破棄される恐れがあるため、fly_ghost系の複製方式に寄せてリスクを避ける）
```

```gdscript
# atelier/shared/ui/ui_effects.gd (タスク001で新設済みのplay_wither_fade()をそのまま複製ノードに対して使う)
static func play_wither_fade(target: Control, duration: float) -> Tween  # 🟡 タスク001で定義済み
```

## Test Strategy

- [ ] `_on_plants_withered([0, 2])`受信時、スロット0とスロット2それぞれに対しフェードアウト演出が開始される
- [ ] 演出開始後、既存のトースト表示（枯死通知）が引き続き行われる（既存機能の回帰確認）
- [ ] 直後に`turn_growth_advanced`シグナルによる`_refresh()`が発火しても、演出中の複製ノードはクラッシュせず自壊する
- [ ] エッジケース: `slot_indices`が空配列の場合、演出は何も発生しない

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/garden_screen.gd`の`_on_plants_withered()`のコメント（`turn_growth_advanced`が`_refresh()`を担う旨の既存記載）
- タスク003の`fly_ghost`実装（overlay_layer, global_position退避パターン）を流用する。移動先座標は退避時と同じ位置（その場でフェード）を渡す
- 既存のトースト表示ロジックは変更しない（追加のみ）

## Files

- 変更: `atelier/features/garden/ui/garden_screen.gd`
- テスト: `atelier/tests/integration/test_garden_screen_wither_animation.gd`
