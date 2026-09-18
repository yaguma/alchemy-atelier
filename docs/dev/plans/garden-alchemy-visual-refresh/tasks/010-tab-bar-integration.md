---
id: "010"
title: "TabBarのタブボタンにドット絵ボタンスタイル・フォントを適用する"
status: done
priority: 3
dependencies: ["004"]
estimated_complexity: medium
---

# Task: TabBarのタブボタンにドット絵ボタンスタイル・フォントを適用する

## Goal

`main.tscn`の`GardenTabButton`/`AlchemyTabButton`（`toggle_mode=true`）に既存の`ButtonStyleApplier`を適用し、DotGothic16フォントを適用する。新規アセットは生成しない（ヒアリング確定方針）。

## Interfaces

```gdscript
# atelier/scenes/main.gd の変更（_ready()等の初期化処理に追加）
func _apply_tab_bar_style() -> void:  # 🟡 新規ヘルパー
	ButtonStyleApplier.apply_button_style(_garden_tab_button, UiTheme.ButtonVariant.SECONDARY)  # 🔴 仮決定
	ButtonStyleApplier.apply_button_style(_alchemy_tab_button, UiTheme.ButtonVariant.SECONDARY)  # 🔴 仮決定
```

> 信号機: 🔵 `ButtonStyleApplier.apply_button_style()`の呼び出し方は既存パターンそのまま。🔴 `ButtonVariant.SECONDARY`（クリーム系）を両タブに適用し、選択中は既存の`toggle_mode`の`pressed`ステート（`make_button_stylebox()`のPRESSED = 暗化）で選択中タブを表現する設計は仮決定。**実機確認で「選択中タブ」の視認性が不十分な場合、`012-regression-check`で調整方針を再検討する**（ヒアリングで既存ボタン流用は確定済みだが、具体的なバリアント組み合わせは実装時の裁量）

## Test Strategy

- [ ] `_garden_tab_button`/`_alchemy_tab_button`に`texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`が設定されている
- [ ] `_garden_tab_button`/`_alchemy_tab_button`が`normal`/`hover`/`pressed`/`disabled`の4状態全てに`StyleBoxTexture`オーバーライドを保持する（`has_theme_stylebox_override()`で確認）
- [ ] `_update_tab_selected_visual(PHASE_GARDEN)`呼び出し後も`_garden_tab_button.button_pressed`が`true`になる既存ロジックが回帰しない（`main.gd` line 254-256の既存動作を維持）
- [ ] フォントサイズが`UiTheme.BUTTON_FONT_SIZE`になっている

## Implementation Notes

- 参照すべき既存コード: `atelier/scenes/main.gd`（`_garden_tab_button`/`_alchemy_tab_button`の`@onready`宣言、`_update_tab_selected_visual()`）、`atelier/features/title/ui/title_screen.gd`（`ButtonStyleApplier`呼び出しパターン）
- 実装のヒント: `_ready()`内、既存のシグナル接続処理の近くに`_apply_tab_bar_style()`呼び出しを追加する
- 注意事項: TabBar自体（`HBoxContainer`）の背景パネル化は本タスクの対象外（ボタン単位のスタイル適用のみ）。TabBar全体の背景要否は`012-regression-check`で実機確認した上で判断する

## Files

- 変更: `atelier/scenes/main.gd`
- テスト: `atelier/tests/integration/test_main_scene.gd`（存在する場合、既存テストの更新。無ければ新規作成は任意）
