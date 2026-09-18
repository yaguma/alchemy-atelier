---
id: "008"
title: "工房強化・ショップ画面にドット絵背景・カードパネル・ボタン・フォントを統合する"
status: done
priority: 3
dependencies: ["005"]
estimated_complexity: high
---

# Task: 工房強化・ショップ画面にドット絵背景・カードパネル・ボタン・フォントを統合する

## Goal

`WorkshopScreen`（`workshop_screen.tscn`）に005の背景を配置し、既存の`VBoxContainer`を新設`%ContentPanel`でカード化、`UpgradeItemRow`を新設`%RowPanel`でカード化し、タブボタン・`CloseButton`に`ButtonStyleApplier`、テキスト要素にDotGothic16フォントを適用する（購入確認ダイアログ自体は009で別途対応）。

## Interfaces

```gdscript
# atelier/features/workshop/ui/workshop_screen.gd の変更
@onready var _content_panel: PanelContainer = %ContentPanel  # 🟡 新設ノード

func _ready() -> void:
	_content_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())  # 🟡 新規
	_permanent_tab_button.pressed.connect(_on_permanent_tab_pressed)
	_consumable_tab_button.pressed.connect(_on_consumable_tab_pressed)
	_permanent_list.purchase_requested.connect(_on_purchase_requested)
	_consumable_list.purchase_requested.connect(_on_purchase_requested)
	_close_button.pressed.connect(_on_close_pressed)
	ButtonStyleApplier.apply_button_style(_permanent_tab_button, UiTheme.ButtonVariant.SECONDARY)  # 🔴 新規
	ButtonStyleApplier.apply_button_style(_consumable_tab_button, UiTheme.ButtonVariant.SECONDARY)  # 🔴 新規
	ButtonStyleApplier.apply_button_style(_close_button, UiTheme.ButtonVariant.SECONDARY)  # 🔴 新規
	UiTheme.apply_pixel_font(self)  # 🟡 ルート一括適用
	_refresh()
```

```gdscript
# atelier/features/workshop/ui/upgrade_item_row.gd の変更
@onready var _row_panel: PanelContainer = %RowPanel  # 🟡 新設ノード

func _ready() -> void:
	_row_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())  # 🟡 新規
	ButtonStyleApplier.apply_button_style(_purchase_button, UiTheme.ButtonVariant.PRIMARY)  # 🔴 新規、購入確定操作としてPRIMARY
```

```
# workshop_screen.tscn への追加（描画順で背面から）
WorkshopScreen (Control)
├── WorkshopBackdropPixel（instance、最背面）  # 🟡 新規
├── VBoxContainer（既存ルート直下を%ContentPanelでラップ）  # 🟡 新規PanelContainer挿入
│   └── ...（HeaderRow, TabRow, PermanentList/ConsumableList, ToastLabel, CloseButton）
├── OverlayLayer（既存、確認ダイアログ用。%ContentPanelより前面のまま変更なし）
```

> 信号機: 🔵 `ButtonStyleApplier`呼び出し方は既存パターンそのまま。🟡 `%ContentPanel`/`%RowPanel`新設・フォント適用範囲は新規設計。🔴 タブボタン/CloseButtonのButtonVariantは仮決定（design-guide.mdの意味論に沿った初期案、実装時に調整可）。現状タブボタンは`toggle_mode`ではなく`disabled`（購入可否）でのみ制御されており「選択中タブ」の視覚差が無い点は既知（012の回帰確認タスクで実機確認）

## Test Strategy

- [ ] `WorkshopScreen`をシーンとしてロードした際、`WorkshopBackdropPixel`ノードが存在し、既存`VBoxContainer`より背面（ツリー順で前）に配置されている
- [ ] `%ContentPanel`が`UiTheme.make_panel_stylebox()`と同一の`StyleBoxTexture`を保持する
- [ ] `_permanent_tab_button`/`_consumable_tab_button`/`_close_button`に`texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`が設定されている
- [ ] `refresh()`実行後に生成された各`UpgradeItemRow`の`%RowPanel`が`UiTheme.make_panel_stylebox()`と同一の`StyleBoxTexture`を保持し、`_purchase_button`に`ButtonStyleApplier`適用の痕跡（NEAREST）がある
- [ ] 既存のタブ切替テスト（`get_active_tab()`）・ゴールド表示・購入可否（`disabled`）ロジックが引き続き全件パスする（表示ロジック自体は変更していないことの回帰確認）
- [ ] エッジケース: `_permanent_tab_button.disabled == true`（購入不可）の状態でも、ButtonStyleApplier適用後の見た目（DISABLED状態のmodulate_color）が正しく反映される

## Implementation Notes

- 参照すべき既存コード: `docs/dev/plans/garden-alchemy-visual-refresh/tasks/007-garden-screen-integration.md`と実際に適用された実装（パネル挿入・フォント適用パターン）、`atelier/features/garden/ui/seed_entry_row.gd`/`.tscn`（在庫リスト行のカード化パターン）
- 実装のヒント: `%ContentPanel`は既存ルート`Control`直下に新設する`PanelContainer`とし、既存の`VBoxContainer`をその内側に移す。`%OverlayLayer`はダイアログ表示用のため`%ContentPanel`の外側（兄弟ノード、より前面）に維持する
- 注意事項: 本タスクは`workshop_screen.gd`のコメント「購入フロー・閉じるボタンは別task」という過去のスコープ境界コメント（1行目付近）とは無関係（購入フロー自体の実装は完了済み、本タスクは見た目のみの変更）。`_close_button`が未接続だった過去の経緯（コメント参照）は既に解消済みであることを実装確認時に検証する

## Files

- 変更: `atelier/features/workshop/ui/workshop_screen.tscn`, `workshop_screen.gd`
- 変更: `atelier/features/workshop/ui/upgrade_item_row.gd`, `upgrade_item_row.tscn`
- 新規: `atelier/features/workshop/ui/workshop_backdrop.tscn`のインスタンス配置（実体は005で新規作成済み）
- テスト: `atelier/tests/unit/features/workshop/`（既存テストの更新）, `atelier/tests/integration/test_workshop_screen*.gd`（既存テストの更新）
