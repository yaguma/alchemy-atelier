---
id: "007"
title: "ギルド納品結果画面にドット絵背景・カードパネル・ボタン・フォントを統合する"
status: done
priority: 3
dependencies: ["004"]
estimated_complexity: high
---

# Task: ギルド納品結果画面にドット絵背景・カードパネル・ボタン・フォントを統合する

## Goal

`GuildDeliveryScreen`（`guild_delivery_screen.tscn`）に004の背景を配置し、既存の`VBoxContainer`を新設`%ContentPanel`でカード化、`GuildDeliveryResultRow`を新設`%RowPanel`でカード化し、`ContinueButton`に`ButtonStyleApplier`、テキスト要素にDotGothic16フォントを適用する。

## Interfaces

```gdscript
# atelier/features/guild/ui/guild_delivery_screen.gd の変更
@onready var _content_panel: PanelContainer = %ContentPanel  # 🟡 新設ノード
@onready var _continue_button: Button = %ContinueButton  # 🔵 既存

func _ready() -> void:
	_content_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())  # 🟡 新規
	_entry_container.add_theme_constant_override("separation", ENTRY_SEPARATION)
	_continue_button.pressed.connect(_on_continue_pressed)
	ButtonStyleApplier.apply_button_style(_continue_button, UiTheme.ButtonVariant.PRIMARY)  # 🔴 新規、確定操作としてPRIMARY
	UiTheme.apply_pixel_font(self)  # 🟡 ルート一括適用（子孫のLabel/Buttonへ個別override不要ならこの方式、既存パターンとの整合はgarden/alchemyの実装確認結果に合わせて調整）
	_refresh_rank_quota()
	_apply_totals()
```

```gdscript
# atelier/features/guild/ui/guild_delivery_result_row.gd の変更
@onready var _row_panel: PanelContainer = %RowPanel  # 🟡 新設ノード

func _ready() -> void:
	_row_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())  # 🟡 新規
```

```
# guild_delivery_screen.tscn への追加（描画順で背面から）
GuildDeliveryScreen (Control)
├── GuildDeliveryBackdropPixel（instance、最背面）  # 🟡 新規
├── VBoxContainer（既存ルート直下を%ContentPanelでラップ）  # 🟡 新規PanelContainer挿入
│   └── ...（RankRow, ScrollContainer/EntryContainer, TotalLabel, ContinueButton）
```

> 信号機: 🔵 `ButtonStyleApplier.apply_button_style()`のシグネチャ・呼び出し方は既存パターンそのまま。🟡 `%ContentPanel`/`%RowPanel`新設・フォント適用範囲は本Planの新規設計（実際の適用方法はtask011（garden-alchemy-visual-refresh）007/008の実装済みコードを読んで一致させること、`UiTheme.apply_pixel_font(self)`のルート一括適用が採用されているかは要確認）。🔴 `ContinueButton`のButtonVariantは仮決定（PRIMARY確定。実装時に画面バランスを見て調整可）

## Test Strategy

- [ ] `GuildDeliveryScreen`をシーンとしてロードした際、`GuildDeliveryBackdropPixel`ノードが存在し、既存`VBoxContainer`より背面（ツリー順で前）に配置されている
- [ ] `%ContentPanel`が`add_theme_stylebox_override("panel", ...)`で`UiTheme.make_panel_stylebox()`と同一の`StyleBoxTexture`を保持する
- [ ] `_continue_button`に`texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`が設定されている（`ButtonStyleApplier`適用の確認）
- [ ] `display_results()`呼び出し後、生成された各`GuildDeliveryResultRow`の`%RowPanel`が`UiTheme.make_panel_stylebox()`と同一の`StyleBoxTexture`を保持する
- [ ] 既存の`test_guild_delivery_screen.gd`（表示更新ロジックのテスト）が引き続き全件パスする（表示ロジック自体は変更していないことの回帰確認）
- [ ] エッジケース: `display_results([], [])`（0件）呼び出し後も`%ContentPanel`・背景の表示は破綻しない（既存の空リスト処理はそのまま）

## Implementation Notes

- 参照すべき既存コード: `docs/dev/plans/garden-alchemy-visual-refresh/tasks/007-garden-screen-integration.md`と実際に適用された`atelier/features/garden/ui/garden_screen.gd`/`.tscn`（パネル挿入・フォント適用の実装パターン）、`atelier/features/garden/ui/seed_entry_row.gd`/`.tscn`（在庫リスト行のカード化パターン、`%RowPanel`相当のノード名を実装から確認する）
- 実装のヒント: `%ContentPanel`は既存ルート`Control`直下に新設する`PanelContainer`とし、既存の`VBoxContainer`をその内側に移す。`ScrollContainer`/`EntryContainer`のレイアウトサイズフラグが崩れないよう注意する
- 注意事項: `GuildDeliveryScreen`は`AlchemyScreen`への埋め込みオーバーレイ（`alchemy_screen.tscn`内の`%GuildDeliveryScreen`）のため、本タスクの変更が`alchemy_screen.tscn`側の既存レイアウト・可視性制御（`visible = false`初期値等）に影響しないことを確認する

## Files

- 変更: `atelier/features/guild/ui/guild_delivery_screen.tscn`, `guild_delivery_screen.gd`
- 変更: `atelier/features/guild/ui/guild_delivery_result_row.gd`, `guild_delivery_result_row.tscn`
- 新規: `atelier/features/guild/ui/guild_delivery_backdrop.tscn`のインスタンス配置（実体は004で新規作成済み）
- テスト: `atelier/tests/integration/test_guild_delivery_screen.gd`（既存テストの更新・追加）
