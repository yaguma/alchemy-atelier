---
id: "005"
title: "庭画面のスロット満杯エラーをユーザー向け文言に変換する"
status: done
priority: 4
dependencies: []
estimated_complexity: low
---

# Task: 庭画面のスロット満杯エラーをユーザー向け文言に変換する

## Goal

現状`error_code`を生文字列でそのままトースト表示している（例:「種「seed_herb」を植えられませんでした（slot_full）」）箇所を、`AlchemyScreen.ERROR_MESSAGES`と同型の変換辞書経由の文言に置き換える（`garden.md` L70）。これは演出ではなく機能ギャップの是正であり、UiEffects/UiThemeに依存しない独立タスク。

## Interfaces

```gdscript
# atelier/features/garden/ui/garden_screen.gd への追加
const ERROR_MESSAGES: Dictionary[StringName, String] = {
    &"slot_full": "庭スロットに空きがありません",  # 🔵 garden.md L70の文言をそのまま採用
}  # 🔵 alchemy_screen.gdのERROR_MESSAGESと同型

static func error_message(error_code: StringName) -> String  # 🔵 未知のerror_codeはerror_code文字列をそのまま返すフォールバック
```

## Test Strategy

- [ ] `error_message(&"slot_full")`が「庭スロットに空きがありません」を返す
- [ ] `error_message(&"unknown_code")`（辞書に無いキー）は元の`error_code`をフォールバック表示する
- [ ] `_on_plant_seed_failed(seed_id, &"slot_full")`受信時、トーストに新文言が表示される（旧: 生文字列表示ではないことを確認）
- [ ] エッジケース: 既存の他のerror_code（存在すれば）が引き続き正しく表示される回帰確認

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/alchemy_screen.gd`の`ERROR_MESSAGES`定数と使用箇所（同型パターンの前例）
- 演出（Tween）は一切不要。文言変換のみ

## Files

- 変更: `atelier/features/garden/ui/garden_screen.gd`
- テスト: `atelier/tests/unit/features/garden/test_garden_screen_error_messages.gd`
