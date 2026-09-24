---
id: "018"
title: "工房画面で購入不可時に価格テキストを警告色にする"
status: done
priority: 4
dependencies: []
estimated_complexity: low
---

# Task: 工房画面で購入不可時に価格テキストを警告色にする

## Goal

所持ゴールドが対象価格未満の場合、該当行の価格テキストを警告色にする（`workshop-shop.md` L62）。演出（Tween）ではなく静的な状態表現であり独立タスク。

## Interfaces

```gdscript
# atelier/features/workshop/ui/upgrade_item_row.gd の既存 setup() を変更
# gold_short（所持金不足）分岐で _price_label.add_theme_color_override("font_color", UiTheme.COLOR_TOAST_WARNING)
# それ以外は _price_label.remove_theme_color_override("font_color") で通常色に戻す
```

## Test Strategy

- [ ] 所持ゴールド < アイテム価格の場合、`_price_label`に警告色のテーマオーバーライドが適用される
- [ ] 所持ゴールド >= アイテム価格の場合、警告色オーバーライドが適用されていない（通常色）
- [ ] ゴールド増減で状態が切り替わった場合、`setup()`再呼び出しにより警告色表示が正しく更新される
- [ ] エッジケース: 所持ゴールド == アイテム価格ちょうどの場合は「購入可能」（警告色にならない）として扱う

## Implementation Notes

- 参照すべき既存コード: `atelier/features/workshop/ui/upgrade_item_row.gd`の`setup()`、購入ボタン無効化ロジック（`.claude/rules`踏襲で既に無効化済みの箇所と同じ条件式を使う）
- タスク001の`UiTheme.COLOR_TOAST_WARNING`をそのまま利用する

## Files

- 変更: `atelier/features/workshop/ui/upgrade_item_row.gd`
- テスト: `atelier/tests/integration/test_upgrade_item_row_price_warning.gd`
