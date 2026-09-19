---
id: "009"
title: "購入確認ダイアログにカードパネル・ボタン・フォントを統合する"
status: done
priority: 3
dependencies: []
estimated_complexity: medium
---

# Task: 購入確認ダイアログにカードパネル・ボタン・フォントを統合する

## Goal

`PurchaseConfirmDialog`（`purchase_confirm_dialog.tscn`）の`RootContainer`を新設`%DialogPanel`でカード化し、`ConfirmButton`/`CancelButton`に`ButtonStyleApplier`、テキスト要素にDotGothic16フォントを適用する。モーダルダイアログのため専用背景1枚絵は作らない（既存の共通カードパネルのみで完結する）。

## Interfaces

```gdscript
# atelier/features/workshop/ui/purchase_confirm_dialog.gd の変更
@onready var _dialog_panel: PanelContainer = %DialogPanel  # 🟡 新設ノード（RootContainerをラップ）
@onready var _confirm_button: Button = %ConfirmButton  # 🔵 既存
@onready var _cancel_button: Button = %CancelButton  # 🔵 既存

func _ready() -> void:
	_dialog_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())  # 🟡 新規
	ButtonStyleApplier.apply_button_style(_confirm_button, UiTheme.ButtonVariant.PRIMARY)  # 🔵 design-guide.mdの「確定」意味論に直接一致
	ButtonStyleApplier.apply_button_style(_cancel_button, UiTheme.ButtonVariant.SECONDARY)  # 🔵 design-guide.mdの「キャンセル・戻る」意味論に直接一致
	UiTheme.apply_pixel_font(self)  # 🟡 ルート一括適用
```

```
# purchase_confirm_dialog.tscn の構造変更
PurchaseConfirmDialog (Control)
└── DialogPanel（PanelContainer、新設、既存RootContainerをラップ）  # 🟡 新規
	└── RootContainer（既存VBoxContainer）
		└── TitleLabel, NameLabel, PriceLabel, EffectLabel, ButtonRow(ConfirmButton, CancelButton)
```

> 信号機: 🔵 `ConfirmButton`=PRIMARY・`CancelButton`=SECONDARYはdesign-guide.mdのボタン表の意味論にそのまま一致する高確信度の割当て。🟡 `%DialogPanel`新設・フォント適用は新規設計

## Test Strategy

- [ ] `PurchaseConfirmDialog`をシーンとしてロードした際、`%DialogPanel`が`UiTheme.make_panel_stylebox()`と同一の`StyleBoxTexture`を保持する
- [ ] `_confirm_button`/`_cancel_button`に`texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`が設定されている
- [ ] 既存の表示更新ロジック（`NameLabel`/`PriceLabel`/`EffectLabel`のテキスト設定）が引き続き全件パスする（表示ロジック自体は変更していないことの回帰確認）
- [ ] `WorkshopScreen.%OverlayLayer`に本ダイアログを`add_child()`した状態でも、`%DialogPanel`のレイアウトが画面中央付近に収まる（既存の`CenterContainer`相当の配置有無を実装確認時に検証し、無ければ追加を検討する）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/ui/pause_menu.gd`（既存の設定パネルオーバーレイ構造、`_settings_panel`の追加/削除パターン。ただしボタンスタイルは未適用のため参考は構造のみ）、`docs/dev/plans/garden-alchemy-visual-refresh/`の`%SlotPanel`/`%ContentPanel`新設パターン
- 実装のヒント: `workshop_screen.gd`が`_confirm_dialog`を`%OverlayLayer`へ`add_child()`する既存フローを変更しないこと。本タスクは`purchase_confirm_dialog.tscn`内部の見た目のみを変更する
- 注意事項: 本タスクは005（`WorkshopBackdropPixel`）に依存しない（ダイアログは背景アセットを使わず既存カードパネルのみで完結するため）。008（workshop-screen-integration）と並行実装可能

## Files

- 変更: `atelier/features/workshop/ui/purchase_confirm_dialog.tscn`, `purchase_confirm_dialog.gd`
- テスト: `atelier/tests/integration/test_workshop_screen_purchase_confirm.gd`（既存テストの更新）
