---
id: "007"
title: "ButtonStyleApplierにドット絵用のnearestフィルタ設定を追加する"
status: done
priority: 2
dependencies: ["006"]
estimated_complexity: low
---

# Task: ButtonStyleApplierにドット絵用のnearestフィルタ設定を追加する

## Goal

`atelier/shared/theme/button_style_applier.gd`の`apply_button_style()`に、ドット絵テクスチャが滲まないよう`texture_filter = TEXTURE_FILTER_NEAREST`の設定を追加する。

## Interfaces

```gdscript
# shared/theme/button_style_applier.gd（既存への追加、シグネチャ変更なし）
class_name ButtonStyleApplier

static func apply_button_style(button: Button, variant: UiTheme.ButtonVariant) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 🔵 新規追加。ドット絵の必須設定
	# 以下、既存の4状態StyleBoxOverride処理は変更なし
	...
```

## Test Strategy

`tests/integration/shared/test_button_style_applier.gd`（**既存ファイルの書き換え**。前Planの`UiPanelStyleBox`前提のassert（`get_theme_stylebox("normal").border_color`等）はタスク006の`StyleBoxTexture`実装と矛盾するため置き換える）:

- [ ] `auto_free(Button.new())`したボタンに`ButtonStyleApplier.apply_button_style(btn, UiTheme.ButtonVariant.PRIMARY)`を呼ぶと、`btn.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`になる
- [ ] `btn.has_theme_stylebox_override("normal")`が`true`になる（4スロット分、既存テストケースを踏襲）
- [ ] `ButtonVariant.DANGER`を指定した場合、`btn.get_theme_stylebox("normal").texture == UiTheme.BUTTON_TEXTURE_DANGER`と一致する（`StyleBoxTexture`化に伴うassert対象の変更）
- [ ] 同じボタンに2回呼んでもエラーにならない（冪等性、既存テストケースを維持）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/theme/button_style_applier.gd`（現状の4状態override処理はそのまま維持し、`texture_filter`設定を1行追加するのみ）
- 実装のヒント: `Button`は`CanvasItem`を継承しているため`texture_filter`プロパティを直接持つ
- 注意事項: 現状`ButtonStyleApplier`の呼び出し元は`TitleScreen`のみ（grep確認済み）のため、この変更による他画面への影響はない

## Files

- 変更: `atelier/shared/theme/button_style_applier.gd`
- テスト: `atelier/tests/integration/shared/test_button_style_applier.gd`（既存ファイルを書き換え）
