---
id: "009"
title: "RankHudをカードパネル・ドット絵フォントで統合する"
status: pending
priority: 3
dependencies: ["004"]
estimated_complexity: medium
---

# Task: RankHudをカードパネル・ドット絵フォントで統合する

## Goal

`RankHud`（`atelier/shared/ui/rank_hud.gd`）のルート`HBoxContainer`を`PanelContainer`でラップし、共通カードパネルを適用する。テキスト要素にDotGothic16フォント、`MenuButton`に`ButtonStyleApplier`を適用する。

## Interfaces

```gdscript
# atelier/shared/ui/rank_hud.gd の変更（構造変更）
# 変更前: RankHud (HBoxContainer, 背景なし)
# 変更後:
# RankHud (PanelContainer)  # 🟡 新設、ルート型変更
# └── HBoxContainer（既存の子要素はそのまま内側に残す）
#     ├── RankNameLabel, QuotaBar, TurnRemainingLabel, GoldLabel, MenuButton

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())  # 🟡 新規（自身がPanelContainerになるため直接呼び出し）
	ButtonStyleApplier.apply_button_style(_menu_button, UiTheme.ButtonVariant.TERTIARY)  # 🟡 新規、控えめな操作のためTERTIARY
	...（既存の_apply_theme()呼び出し等）
```

> 信号機: 🔵 `ButtonStyleApplier`呼び出しは既存パターンそのまま。🟡 ルートノード型を`HBoxContainer`から`PanelContainer`に変更する構造変更は本Planの新規設計（`PanelContainer`は単一の子しか直接レイアウトできないため、既存`HBoxContainer`を子として残す2階層構造にする）。`MenuButton`の`ButtonVariant.TERTIARY`選定は🔴仮決定（実機確認で調整可）

## Test Strategy

- [ ] `RankHud`のルートノードの型が`PanelContainer`になっている
- [ ] ルートが`add_theme_stylebox_override("panel", ...)`で`UiTheme.make_panel_stylebox()`と同一の`StyleBoxTexture`を保持する
- [ ] 既存の`RankNameLabel`/`QuotaBar`/`TurnRemainingLabel`/`GoldLabel`の表示ロジック（`_on_*_changed`ハンドラ等）が構造変更後も動作する（既存統合テストの回帰確認）
- [ ] `_menu_button`（`MenuButton`）に`texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`が設定されている
- [ ] `_exit_tree()`でのAutoloadシグナル購読解除が構造変更後も引き続き機能する（既存テストの回帰確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/ui/rank_hud.gd`/`.tscn`の現状構造、`atelier/features/title/ui/title_screen.gd`の`ButtonStyleApplier`呼び出しパターン
- 実装のヒント: `.tscn`ファイルでルートノードの型を変更する場合、Godotエディタでの手動再構築が確実（`PanelContainer`を新規ルートにし、既存`HBoxContainer`をリペアレントする）。スクリプトの`extends`宣言も`HBoxContainer`から`PanelContainer`に変更する
- 注意事項: `RankHud`は5画面すべて（garden/alchemy/guild/rank/workshop）で常時表示される共通UIのため、本Planのスコープ外画面（guild/rank/workshop）でも見た目が変わる点に注意（`.claude/rules/design-guide.md`改訂（011）でこの点も明記する）

## Files

- 変更: `atelier/shared/ui/rank_hud.gd`, `rank_hud.tscn`
- テスト: `atelier/tests/integration/test_rank_hud.gd`（存在する場合、既存テストの更新）
