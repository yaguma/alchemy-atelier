---
id: "016"
title: "工房画面で購入成功時のゴールドカウントダウン演出を追加する"
status: done
priority: 3
dependencies: ["001"]
estimated_complexity: medium
---

# Task: 工房画面で購入成功時のゴールドカウントダウン演出を追加する

## Goal

購入成功時、ゴールド表示を即座に書き換えず、購入前→購入後の数値をカウントダウンさせる演出を追加する（`workshop-shop.md` L68）。

## Interfaces

```gdscript
# atelier/features/workshop/ui/workshop_screen.gd への追加
func _animate_gold_countdown(from_value: int, to_value: int, duration: float) -> Tween  # 🔵 Tween.tween_method()でfrom→toを補間し、_gold_label.textを都度更新
```

```gdscript
# atelier/features/workshop/ui/workshop_screen.gd の既存 _execute_purchase() 成功分岐を変更
# 変更: _gold_label.text の即時書き換えを _animate_gold_countdown(購入前ゴールド, 購入後ゴールド, duration) に置換
```

## Test Strategy

- [ ] 購入成功後、`_gold_label.text`が即座には購入後の値にならず、`Tween.finished`後に購入後の値と一致する
- [ ] カウントダウン中の中間値は`from_value`と`to_value`の間の値のみを取る（範囲外の値を表示しない）
- [ ] 購入失敗（所持金不足）時はカウントダウンが発生せず、ゴールド表示も変化しない
- [ ] エッジケース: `from_value == to_value`（価格0のアイテム等、通常起こらないが）の場合でもクラッシュせず即完了する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/workshop/ui/workshop_screen.gd`の`_execute_purchase()`
- `Tween.tween_method()`で整数値を補間し、`_gold_label.text = "%d G" % int(value)`のような整形を都度行う（既存のゴールド表示フォーマットに合わせる）

## Files

- 変更: `atelier/features/workshop/ui/workshop_screen.gd`
- テスト: `atelier/tests/integration/test_workshop_screen_gold_countdown.gd`
