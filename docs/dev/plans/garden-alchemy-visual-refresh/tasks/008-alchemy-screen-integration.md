---
id: "008"
title: "調合画面にドット絵背景・カードパネル・ボタン・フォントを統合する"
status: pending
priority: 3
dependencies: ["004", "006"]
estimated_complexity: high
---

# Task: 調合画面にドット絵背景・カードパネル・ボタン・フォントを統合する

## Goal

調合画面（`alchemy_screen.tscn`）に006の背景を配置し、`AlchemySlotView`・`AlchemyPreviewPanel`・在庫リスト行（`MaterialEntryRow`等）を新設`%SlotPanel`でカード化し、既存ボタンに`ButtonStyleApplier`、テキスト要素にDotGothic16フォントを適用する。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_slot_view.gd の変更
@onready var _slot_panel: PanelContainer = %SlotPanel  # 🟡 新設ノード

func _apply_display() -> void:
	...
	_slot_panel.self_modulate = status_color(_status)  # 🟡 旧: self_modulate = status_color(_status)（line 88、rootに適用、背景が無く無効化されていた）

func _ready() -> void:
	_slot_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())  # 🟡 新規
	...
```

```gdscript
# atelier/features/alchemy/ui/alchemy_preview_panel.gd の変更
@onready var _preview_panel: PanelContainer = %PreviewPanel  # 🟡 新設ノード（プレビュー全体を1枚のカードで囲む）

func _ready() -> void:
	_preview_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())  # 🟡 新規
```

```
# alchemy_screen.tscn への追加（描画順で背面から）
AlchemyScreen (Control)
├── AlchemyBackdropPixel（instance、最背面）  # 🟡 新規
├── VBoxContainer（既存、そのまま前面に残る）
│   ├── ボタン群（実行ボタン等）  # ButtonStyleApplier適用
│   └── AlchemySlotView×4, AlchemyPreviewPanel, MaterialInventoryList内のMaterialEntryRow群
```

> 信号機: 🔵 `ButtonStyleApplier.apply_button_style()`の呼び出し方は既存パターンそのまま。🟡 `%SlotPanel`/`%PreviewPanel`新設・`self_modulate`移設・フォント適用範囲は本Planの新規設計。🔴 調合実行ボタンにどのButtonVariantを当てるかは仮決定（実行=PRIMARY確定操作で暫定。実装時に調整可）

## Test Strategy

- [ ] `AlchemySlotView`の`status_color()`が`EMPTY`/`FILLED`それぞれに対応する色を返す（既存ロジックは変更なし、回帰確認）
- [ ] `%SlotPanel.self_modulate`が状態に応じて`UiTheme.COLOR_ALCHEMY_SLOT_EMPTY`/`COLOR_ALCHEMY_SLOT_FILLED`と一致する（ルートControlの`self_modulate`ではないこと）
- [ ] `%SlotPanel`/`%PreviewPanel`が`UiTheme.make_panel_stylebox()`と同一の`StyleBoxTexture`を`panel`スロットに保持する
- [ ] 調合実行ボタンに`texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`が設定されている
- [ ] `alchemy_screen.tscn`をロードした際、`AlchemyBackdropPixel`ノードが存在し`VBoxContainer`より背面に配置されている
- [ ] `MaterialEntryRow`（在庫リスト行）も同様にカード化されている（既存テストへの回帰がないこと）
- [ ] エッジケース: 指定合致強調表示（`UiTheme.COLOR_ALCHEMY_PREVIEW_ORDER_MATCHED`）がカード化後も正しく表示される

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/alchemy_slot_view.gd`（line 88の`self_modulate`直書き箇所）、`atelier/features/alchemy/ui/alchemy_preview_panel.gd`、`atelier/features/alchemy/ui/material_entry_row.gd`/`.tscn`（存在する場合）
- 実装のヒント: 007（庭画面）と対になる実装。`%SlotPanel`のパターンは007と完全に同一にし、コード重複よりも一貫性を優先する（両者ともUiTheme経由の共通処理のため、DRYの観点で共通ヘルパー化も検討可だが、Feature間直接参照は禁止のため共通化する場合は`shared/`に置くこと）
- 注意事項: 調合は「品質を盛るか特性を宿すか」のトレードオフが核心（`docs/concept/atelier-concept.md`）のため、色分けの視認性（NFR-201）を損なわないこと。カード化後も既存の`COLOR_ALCHEMY_PREVIEW_ORDER_MATCHED`強調表示が機能するか確認する

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.tscn`, `alchemy_screen.gd`
- 変更: `atelier/features/alchemy/ui/alchemy_slot_view.gd`, `alchemy_slot_view.tscn`
- 変更: `atelier/features/alchemy/ui/alchemy_preview_panel.gd`, `alchemy_preview_panel.tscn`
- 変更: `atelier/features/alchemy/ui/material_entry_row.gd`, `material_entry_row.tscn`（存在する場合）
- 新規: `atelier/features/alchemy/ui/alchemy_backdrop.tscn`のインスタンス配置（実体は006で新規作成済み）
- テスト: `atelier/tests/unit/features/alchemy/test_alchemy_slot_view.gd`（既存テストの更新）
