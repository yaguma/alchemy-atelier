---
id: "003"
title: "ボタンへ4状態のStyleBoxを一括適用するヘルパーを追加する"
status: done
priority: 2
dependencies: ["002"]
estimated_complexity: low
---

# Task: ボタンへ4状態のStyleBoxを一括適用するヘルパーを追加する

## Goal

`Button`ノードに対して`UiTheme.ButtonVariant`を指定するだけで、normal/hover/pressed/disabledの4状態StyleBoxを一括で`add_theme_stylebox_override()`する共通関数を用意する。

## Interfaces

```gdscript
# 新規 shared/theme/button_style_applier.gd
class_name ButtonStyleApplier

static func apply_button_style(button: Button, variant: UiTheme.ButtonVariant) -> void: ...  # 🟡
```

- 内部で`button.add_theme_stylebox_override("normal", UiTheme.make_button_stylebox(variant, UiTheme.ButtonState.NORMAL))`等を4状態分＋`"focus"`（`"normal"`と同じStyleBoxを流用）呼ぶ 🔵（Godot Buttonのテーマオーバーライド標準API）
- フォント色は変更しない（既存の`main_theme.tres`のフォント設定を尊重する）🟡

## Test Strategy

`tests/integration/shared/test_button_style_applier.gd`（新規、GdUnit4統合テスト）:

- [ ] `auto_free(Button.new())`したボタンに`ButtonStyleApplier.apply_button_style(btn, UiTheme.ButtonVariant.PRIMARY)`を呼ぶと、`btn.has_theme_stylebox_override("normal")`が`true`になる
- [ ] 同様に`"hover"`, `"pressed"`, `"disabled"`の4スロットすべてに`override`が設定される
- [ ] `ButtonVariant.DANGER`を指定した場合、`btn.get_theme_stylebox("normal").border_color`が`UiTheme.COLOR_BUTTON_DANGER_BORDER`と一致する
- [ ] 同じボタンに2回呼んでもエラーにならない（上書き可能なことの確認、再適用時の冪等性）

## Implementation Notes

- 参照すべき既存コード: 現状ボタンへの個別スタイル適用パターンはプロジェクト内に存在しない（新規パターン）。`.claude/rules/coding-style.md`の型注釈規約に従う
- 実装のヒント: `Button`のテーマスロット名は`"normal"`, `"hover"`, `"pressed"`, `"disabled"`, `"focus"`（Godot 4標準）
- 注意事項: このヘルパーは`002`で追加した`make_button_stylebox()`にのみ依存し、`GameState`等ゲームロジックには一切依存しない

## Files

- 新規: `atelier/shared/theme/button_style_applier.gd`
- テスト: `atelier/tests/integration/shared/test_button_style_applier.gd`
