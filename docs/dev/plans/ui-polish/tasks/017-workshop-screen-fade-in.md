---
id: "017"
title: "工房画面表示時のフェードイン演出を追加する"
status: done
priority: 3
dependencies: ["001"]
estimated_complexity: low
---

# Task: 工房画面表示時のフェードイン演出を追加する

## Goal

工房強化画面が表示される際にフェードインする演出を追加する（`workshop-shop.md` L69）。`visible=true`自体は`MainScene._apply_visible_phase()`側で既に設定済みのため、表示直後に`modulate.a: 0→1`させるだけでよい（昇格試験のような画面遷移競合は無い）。

## Interfaces

```gdscript
# atelier/features/workshop/ui/workshop_screen.gd への追加
func play_show_animation() -> Tween  # 🔵 modulate.a を 0→1 へフェードするだけの薄いラッパー（UiEffects汎用関数ではなくtween_propertyの直書きでも可）
```

```gdscript
# atelier/scenes/main.gd の _refresh_visible_screen() のPHASE_WORKSHOP分岐で
# _workshop_screen.refresh() の前後いずれかのタイミングで play_show_animation() を呼ぶ
```

## Test Strategy

- [ ] `PHASE_WORKSHOP`へ遷移した際、`_workshop_screen.modulate.a`が0から1へ向けて変化を開始する
- [ ] `_workshop_screen.refresh()`による表示内容（アイテム一覧・ゴールド表示）は演出完了前から正しく設定されている（演出はあくまで視覚効果で、データ表示をブロックしない）
- [ ] 同じPHASE_WORKSHOPへ連続して切り替わっても（他画面を経由せず再度workshopに戻る等）クラッシュしない
- [ ] エッジケース: `_apply_visible_phase()`が他画面から呼ばれた直後の初回表示でも正しくフェードインする

## Implementation Notes

- 参照すべき既存コード: `atelier/scenes/main.gd`の`_apply_visible_phase()`, `_refresh_visible_screen()`
- タスク016（ゴールドカウントダウン）とは独立実装可能

## Files

- 変更: `atelier/features/workshop/ui/workshop_screen.gd`, `atelier/scenes/main.gd`
- テスト: `atelier/tests/integration/test_workshop_screen_show_animation.gd`
