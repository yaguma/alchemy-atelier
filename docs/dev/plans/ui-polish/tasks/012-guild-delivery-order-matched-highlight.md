---
id: "012"
title: "ギルド納品画面で指定合致時のハイライト演出を追加する"
status: done
priority: 3
dependencies: ["011"]
estimated_complexity: low
---

# Task: ギルド納品画面で指定合致時のハイライト演出を追加する

## Goal

指定合致した結果行に対し、強調演出（キラキラ）を追加する（`guild-delivery.md` L71）。GPUParticles2Dではなく、ドット絵統一済みのデザインとの一貫性を優先しTween明滅+スケールパルスで代替する（ユーザー決定）。

## Interfaces

```gdscript
# atelier/features/guild/ui/guild_delivery_result_row.gd への追加
func play_order_matched_highlight() -> Tween  # 🟡 UiEffects.play_highlight_pulse(self, UiTheme.COLOR_ORDER_MATCHED_HIGHLIGHT, ...) のラッパー
```

```gdscript
# atelier/features/guild/ui/guild_delivery_screen.gd の _add_entry_row() を変更
# order_matched == true の行に対し play_order_matched_highlight() を追加呼び出し
```

## Test Strategy

- [ ] `order_matched=true`の結果行に対し`play_order_matched_highlight()`が呼ばれる
- [ ] `order_matched=false`の結果行には演出が発生しない
- [ ] 演出は`self_modulate`の変化＋一時的な`scale`パルスで構成される（GPUParticles2Dを使用しないことの確認）
- [ ] エッジケース: 指定合致行が複数ある場合、それぞれ独立して演出が発生する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/guild/ui/guild_delivery_result_row.gd`, `guild_delivery_screen.gd`の`_add_entry_row()`
- タスク011の`show_with_animation()`によるポップイン演出と時系列が重なる場合、両方が視覚的に破綻しないよう開始タイミングをずらす（🟡tdd-implementer裁量、例: ポップイン完了後にハイライト開始）

## Files

- 変更: `atelier/features/guild/ui/guild_delivery_result_row.gd`, `atelier/features/guild/ui/guild_delivery_screen.gd`
- テスト: `atelier/tests/integration/test_guild_delivery_result_row_order_matched.gd`
