---
id: "007"
title: "庭画面にドット絵背景・カードパネル・ボタン・フォントを統合する"
status: done
priority: 3
dependencies: ["004", "005"]
estimated_complexity: high
---

# Task: 庭画面にドット絵背景・カードパネル・ボタン・フォントを統合する

## Goal

庭画面（`garden_screen.tscn`）に005の背景を配置し、`PlantSlotView`・在庫リスト行（`SeedEntryRow`等）を新設`%SlotPanel`でカード化し、既存ボタン（`EndTurnButton`/`ShopButton`等）に`ButtonStyleApplier`、テキスト要素にDotGothic16フォントを適用する。

## Interfaces

```gdscript
# atelier/features/garden/ui/plant_slot_view.gd の変更
@onready var _slot_panel: PanelContainer = %SlotPanel  # 🟡 新設ノード

func _apply_display() -> void:
	if _status_label == null:
		return
	_status_label.text = status_text(_status)
	_status_icon.text = status_icon(_status)
	_slot_panel.self_modulate = status_color(_status)  # 🟡 旧: self_modulate = status_color(_status)（rootに適用、背景が無く無効化されていた）
	_harvest_button.disabled = not _harvest_enabled

func _ready() -> void:
	_slot_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())  # 🟡 新規
	_harvest_button.pressed.connect(_on_harvest_pressed)
	_wait_button.pressed.connect(_on_wait_pressed)
	ButtonStyleApplier.apply_button_style(_harvest_button, UiTheme.ButtonVariant.PRIMARY)  # 🟡 新規
	ButtonStyleApplier.apply_button_style(_wait_button, UiTheme.ButtonVariant.SECONDARY)  # 🟡 新規
	_apply_display()
```

```
# garden_screen.tscn への追加（描画順で背面から）
GardenScreen (Control)
├── GardenBackdropPixel（instance、最背面）  # 🟡 新規
├── VBoxContainer（既存、そのまま前面に残る）
│   ├── HeaderRow > EndTurnButton, ShopButton  # ButtonStyleApplier適用
│   └── ...（PlantSlotView×4、SeedInventoryList内のSeedEntryRow群）
```

> 信号機: 🔵 `ButtonStyleApplier.apply_button_style()`のシグネチャ・呼び出し方は既存パターンそのまま。🟡 `%SlotPanel`新設・`self_modulate`移設・フォント適用範囲は本Planの新規設計。🔴 `EndTurnButton`/`ShopButton`にどのButtonVariantを当てるかは仮決定（EndTurnButton=PRIMARY確定操作、ShopButton=SECONDARYで暫定。実装時に画面バランスを見て調整可）

## Test Strategy

- [ ] `PlantSlotView`の`setup_empty()`呼び出し後、`%SlotPanel.self_modulate`が`UiTheme.COLOR_SLOT_EMPTY`と一致する（ルートControlの`self_modulate`ではないことも確認）
- [ ] `PlantSlotView`の`setup()`で`HARVESTABLE`状態になった場合、`%SlotPanel.self_modulate`が`UiTheme.COLOR_SLOT_HARVESTABLE`と一致する
- [ ] `%SlotPanel`が`add_theme_stylebox_override("panel", ...)`で`UiTheme.make_panel_stylebox()`と同一の`StyleBoxTexture`を保持する
- [ ] `_harvest_button`/`_wait_button`に`texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`が設定されている（`ButtonStyleApplier`適用の確認）
- [ ] `garden_screen.tscn`をシーンとしてロードした際、`GardenBackdropPixel`ノードが存在し、`VBoxContainer`より背面（ツリー順で前）に配置されている
- [ ] `SeedEntryRow`（在庫リスト行）も同様に`%SlotPanel`相当のカード化がされている（既存テストへの回帰がないこと）
- [ ] エッジケース: `setup_data_error()`呼び出し時も`%SlotPanel.self_modulate`が`UiTheme.COLOR_SLOT_DATA_ERROR`になる

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/plant_slot_view.gd`/`.tscn`（現状の`self_modulate`直書き箇所、line 144）、`atelier/features/garden/ui/seed_entry_row.gd`/`.tscn`（在庫リスト行、`ENTRY_SEPARATION`ローカル定数に注意）、`atelier/features/title/ui/title_screen.gd`（`ButtonStyleApplier`呼び出しパターン）
- 実装のヒント: `%SlotPanel`は既存のルートControl直下に新設する`PanelContainer`とし、既存の子ノード（`StatusLabel`等）をその内側に移す。既存のGdUnit4テスト（`tests/unit/features/garden/`, `tests/integration/`配下）で`self_modulate`を直接検証しているテストがあれば、参照先を`%SlotPanel.self_modulate`に更新する
- 注意事項: Feature間参照禁止ルール（`.claude/rules/architecture.md`）に従い、`UiTheme`/`ButtonStyleApplier`は`shared/`配下のためgarden機能から参照して問題ない。フォント適用は`UiTheme.FONT_PIXEL_JP`を`add_theme_font_override("font", UiTheme.FONT_PIXEL_JP)`で個別ノードに適用する方式（`main_theme.tres`のデフォルトフォントは変更しない、既存のタイトル画面と同じ方針）

## Files

- 変更: `atelier/features/garden/ui/garden_screen.tscn`, `garden_screen.gd`
- 変更: `atelier/features/garden/ui/plant_slot_view.gd`, `plant_slot_view.tscn`
- 変更: `atelier/features/garden/ui/seed_entry_row.gd`, `seed_entry_row.tscn`（存在する場合、在庫リスト行のカード化）
- 新規: `atelier/features/garden/ui/garden_backdrop.tscn`のインスタンス配置（実体は005で新規作成済み）
- テスト: `atelier/tests/unit/features/garden/test_plant_slot_view.gd`（既存テストの更新）
