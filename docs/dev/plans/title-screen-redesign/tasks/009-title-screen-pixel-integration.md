---
id: "009"
title: "TitleScreen本体にドット絵スタイル（フォント・フィルタ）を統合する"
status: done
priority: 2
dependencies: ["002", "005", "007", "008"]
estimated_complexity: medium
---

# Task: TitleScreen本体にドット絵スタイル（フォント・フィルタ）を統合する

## Goal

`TitleScreen._apply_theme()`のフォント指定を`UiTheme.FONT_MAIN`から`UiTheme.FONT_PIXEL_JP`に差し替え、`EmblemRect`と4ボタンに`texture_filter`のnearest設定を追加する。`.tscn`のノード構成（`LogoContainer`/`RootContainer`のレイアウト比率）自体は変更不要見込み。

## Interfaces

```gdscript
# features/title/ui/title_screen.gd（既存の_apply_theme()への変更）
class_name TitleScreen
extends Control

# 🔴 現行の40はNoto Sans JP基準の値。DotGothic16はグリッド設計（16px単位）のため
# 32px（16の倍数）に見直すことを推奨するが、実アセット確認後に微調整してよい
const LOGO_FONT_SIZE := 40  # 🔴 32等への変更を検討

@onready var _emblem_rect: TextureRect = %EmblemRect  # 🟡 新規@onready追加


func _apply_theme() -> void:
	theme = MAIN_THEME
	_root_container.add_theme_constant_override("separation", UiTheme.SPACING_LIST_ENTRY)
	_logo_label.add_theme_font_override("font", UiTheme.FONT_PIXEL_JP)  # 🔵 FONT_MAINから変更
	_logo_label.add_theme_font_size_override("font_size", LOGO_FONT_SIZE)
	_emblem_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 🔵 新規、ドット絵の必須設定

	# 🟡 ボタン4つにもフォントoverrideを追加（main_theme.tresは触らずノード単位で完結させる）
	for button in [_new_game_button, _continue_button, _settings_button, _quit_button]:
		button.add_theme_font_override("font", UiTheme.FONT_PIXEL_JP)

	ButtonStyleApplier.apply_button_style(_new_game_button, UiTheme.ButtonVariant.PRIMARY)
	ButtonStyleApplier.apply_button_style(_continue_button, UiTheme.ButtonVariant.SECONDARY)
	ButtonStyleApplier.apply_button_style(_settings_button, UiTheme.ButtonVariant.TERTIARY)
	ButtonStyleApplier.apply_button_style(_quit_button, UiTheme.ButtonVariant.SECONDARY)
```

`.tscn`変更: `title_backdrop.tscn`（タスク008で置き換え済み）・`title_emblem.png`（タスク005で置き換え済み）は参照パスが同じため`title_screen.tscn`側の`ext_resource`パスは変更不要のはず。`%EmblemRect`ノードに`unique_name_in_owner`を追加する必要はない（既存で設定済み、`%EmblemRect`として参照可能）。

## Test Strategy

`tests/integration/test_title_screen.gd`（既存ファイルへの追記。既存10件＋前Planで追加された6件、計16件は無修正でPASSし続けること。ただし前Planが追加した「`%NewGameButton`が`has_theme_stylebox_override("normal")`を持つ」等のstylebox override確認系は本タスクでも引き続き成立するため無修正でよい）:

- [ ] `%LogoLabel`のフォントが`UiTheme.FONT_PIXEL_JP`に設定されている（`get_theme_font("font") == UiTheme.FONT_PIXEL_JP`）
- [ ] `%EmblemRect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`である
- [ ] `%NewGameButton`/`%ContinueButton`/`%SettingsButton`/`%QuitButton`それぞれの`texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`である（タスク007の`ButtonStyleApplier`変更が反映されていることの確認）
- [ ] 既存の`get_requested_next_scene_path()`/`has_requested_quit()`系テスト（遷移・終了要求の観測）が無修正でPASSし続ける（回帰確認）
- [ ] `find_child("TitleBackdrop", true, false)`・`find_child("LogoContainer", true, false)`が引き続き見つかる（前Planのテストを維持）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/title/ui/title_screen.gd`の現行`_apply_theme()`（上記Interfacesに現状のコードを再掲済み）
- 実装のヒント: `_apply_theme()`は`_ready()`冒頭で呼ばれる既存構造を維持する。既存の遷移・終了ロジック（`_go_to_slot_select()`, `_on_quit_pressed()`, `_on_settings_pressed()`）には一切手を入れない
- 注意事項:
  - `LOGO_FONT_SIZE`の値見直し（40→32等）はタスク005で生成したロゴ・タスク002で導入したフォントの実際の見た目を確認してから判断してよい（🔴、必須ではない）
  - `main_theme.tres`（プロジェクト全体のデフォルトテーマ）自体は変更しないこと。フォント差し替えはノード単位の`add_theme_font_override()`のみで完結させる

## Files

- 変更: `atelier/features/title/ui/title_screen.gd`
- 変更: `atelier/features/title/ui/title_screen.tscn`（変更が必要な場合のみ。ノード構成自体は無変更で済む見込み）
- テスト: `atelier/tests/integration/test_title_screen.gd`（既存ファイルに追記）
