---
id: "006"
title: "TitleScreen本体に新スタイル（背景・ロゴ・ボタン）を適用する"
status: done
priority: 2
dependencies: ["002", "003", "004", "005"]
estimated_complexity: medium
---

# Task: TitleScreen本体に新スタイル（背景・ロゴ・ボタン）を適用する

## Goal

`TitleScreen`のルートに`TitleBackdrop`（`005`）とロゴ画像（`004`）＋「アトリエ」ロゴ文字`Label`を組み込み、`%NewGameButton`/`%ContinueButton`/`%SettingsButton`/`%QuitButton`にボタンvariant別のスタイルを適用する。

## Interfaces

```gdscript
# features/title/ui/title_screen.gd（既存への追加）
func _apply_theme() -> void: ...   # 🔵 rank_hud.gdの既存パターン（_apply_theme()を_ready()冒頭で呼ぶ）を踏襲。既存の_apply_theme()実装（theme = MAIN_THEME; セパレーション設定）に追記する形で拡張する
```

`_apply_theme()`内で追加すること（🔴 具体的なvariant割り当ては`plan.md`の設計に従う）:
- `ButtonStyleApplier.apply_button_style(_new_game_button, UiTheme.ButtonVariant.PRIMARY)`
- `ButtonStyleApplier.apply_button_style(_continue_button, UiTheme.ButtonVariant.SECONDARY)`
- `ButtonStyleApplier.apply_button_style(_settings_button, UiTheme.ButtonVariant.TERTIARY)`
- `ButtonStyleApplier.apply_button_style(_quit_button, UiTheme.ButtonVariant.SECONDARY)`

`.tscn`変更（🔴 具体的なノード階層順序はAI裁量）:
- `title_screen.tscn`のルート直下・最初の子として`TitleBackdropScene`のインスタンスを追加する（`%RootContainer`より背面に描画されるようツリー順で先頭に置く）
- ロゴ用に`LogoContainer`（`Control`または`VBoxContainer`）を新設し、`%RootContainer`（ボタン列）より前面・上部に配置。中に`TextureRect`（`title_emblem.png`）＋`Label`（「アトリエ」、`UiTheme.FONT_MAIN`・大きめフォントサイズ）を持つ

## Test Strategy

既存テスト`tests/integration/test_title_screen.gd`への追記（新規アサーションのみ、既存テストは無修正でPASSし続けること）:

- [ ] `TitleScreen`インスタンス化後、`find_child("TitleBackdrop", true, false)`でルートの背景ノードが見つかる
- [ ] `%NewGameButton`が`has_theme_stylebox_override("normal")`を持つ（新スタイルが適用されていることの確認）
- [ ] `%ContinueButton`/`%SettingsButton`/`%QuitButton`も同様に`has_theme_stylebox_override("normal")`を持つ
- [ ] `find_child("LogoContainer", true, false)`でロゴ部のノードが見つかる
- [ ] 既存の`get_requested_next_scene_path()`/`has_requested_quit()`系テスト（遷移・終了要求の観測）が無修正でPASSし続ける（回帰確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/title/ui/title_screen.gd`（既存`_apply_theme()`, `_ready()`）, `atelier/shared/ui/rank_hud.gd`（`_apply_theme()`パターンの先例）
- 実装のヒント: `_apply_theme()`は`_ready()`冒頭（既存のsignal接続より前）で呼ぶ。既存の遷移・終了ロジック（`_go_to_slot_select()`, `_on_quit_pressed()`等）には一切手を入れない
- 注意事項: `TitleBackdrop`は`005`で`mouse_filter = MOUSE_FILTER_IGNORE`が設定済みのため、既存のボタン操作を妨げないことを確認する。`%OverlayLayer`（`SettingsPanel`表示用）より背面、`%RootContainer`より背面という描画順（ツリー順）を保つこと

## Files

- 変更: `atelier/features/title/ui/title_screen.gd`
- 変更: `atelier/features/title/ui/title_screen.tscn`
- テスト: `atelier/tests/integration/test_title_screen.gd`（既存ファイルに追記）
