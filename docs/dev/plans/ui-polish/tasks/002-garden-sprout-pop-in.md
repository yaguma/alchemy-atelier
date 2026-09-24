---
id: "002"
title: "庭画面で種を植えた時のポップイン演出を追加する"
status: done
priority: 3
dependencies: ["001"]
estimated_complexity: low
---

# Task: 庭画面で種を植えた時のポップイン演出を追加する

## Goal

`GameState.seed_planted`受信後、対象スロットの芽をポップインで出現させる（`docs/design/atelier-alchemy-core/ui-design/screens/garden.md` L76）。

## Interfaces

```gdscript
# atelier/features/garden/ui/plant_slot_view.gd への追加
func play_sprout_animation() -> Tween  # 🔵 UiEffects.play_pop_in(self, ...) を呼ぶだけの薄いラッパー
```

```gdscript
# atelier/features/garden/ui/garden_screen.gd の既存 _on_seed_planted() を変更
# 既存: _refresh() のみ
# 変更後: _refresh() 実行後、_slot_views[slot_index] を取得し play_sprout_animation() を呼ぶ
```

## Test Strategy

- [ ] `_on_seed_planted(slot_index, seed_id)`受信後、`_slot_views[slot_index].play_sprout_animation()`が呼ばれる
- [ ] `play_sprout_animation()`は有効な`Tween`を返す
- [ ] エッジケース: 同一フレームで連続して植付が発生しても既存Tweenと競合しクラッシュしない（`create_tween()`は都度新規生成されるため通常問題ないが、回帰として確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/garden_screen.gd`の`_on_seed_planted()`, `_slot_views`配列
- タスク001の`UiEffects.play_pop_in()`をそのまま利用する
- `_refresh()`が`_slot_views`を再構築する場合、ポップインは再構築後の新しいノードに対して呼ぶ（順序に注意）

## Files

- 変更: `atelier/features/garden/ui/plant_slot_view.gd`, `atelier/features/garden/ui/garden_screen.gd`
- テスト: `atelier/tests/integration/test_garden_screen_sprout_animation.gd`
