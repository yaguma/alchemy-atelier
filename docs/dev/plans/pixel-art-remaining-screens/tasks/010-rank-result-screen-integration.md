---
id: "010"
title: "結果画面にドット絵背景・カードパネル・フォントを統合する"
status: done
priority: 3
dependencies: ["006"]
estimated_complexity: medium
---

# Task: 結果画面にドット絵背景・カードパネル・フォントを統合する

## Goal

`ResultScreen`（`result_screen.tscn`）に006の背景を配置し、既存の`CenterContainer`を新設`%ContentPanel`でカード化し、`ResultMessageLabel`にDotGothic16フォントを適用する。本画面にボタンは存在しないため（`result_screen.gd`のコメント参照）、ボタンスタイル適用は対象外。

## Interfaces

```gdscript
# atelier/features/rank/ui/result_screen.gd の変更
@onready var _content_panel: PanelContainer = %ContentPanel  # 🟡 新設ノード（CenterContainerをラップ）
@onready var _result_message_label: Label = %ResultMessageLabel  # 🔵 既存

func _ready() -> void:  # 🔵 FR-001
	_content_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())  # 🟡 新規
	UiTheme.apply_pixel_font(self)  # 🟡 新規
	_apply_result_kind()
	GameState.game_over.connect(_on_game_over)
	GameState.game_cleared.connect(_on_game_cleared)
```

```
# result_screen.tscn への追加（描画順で背面から）
ResultScreen (Control)
├── RankResultBackdropPixel（instance、最背面）  # 🟡 新規
├── ContentPanel（PanelContainer、新設、既存CenterContainerをラップ）  # 🟡 新規
│   └── CenterContainer（既存）
│       └── ResultMessageLabel（既存）
```

> 信号機: 🔵 `_apply_result_kind()`等の既存メソッド・FR番号コメントは一切変更しない（表示ロジックは対象外）。🟡 `%ContentPanel`新設・背景配置・フォント適用は新規設計

## Test Strategy

- [ ] `ResultScreen`をシーンとしてロードした際、`RankResultBackdropPixel`ノードが存在し、既存`CenterContainer`より背面（ツリー順で前）に配置されている
- [ ] `%ContentPanel`が`UiTheme.make_panel_stylebox()`と同一の`StyleBoxTexture`を保持する
- [ ] `_on_game_cleared()`呼び出し後、`get_result_kind()`が`ResultKind.CLEAR`を返し、`%ResultMessageLabel.text`が`CLEAR_MESSAGE_TEXT`と一致する（既存ロジックの回帰確認）
- [ ] `_on_game_over(0)`呼び出し後、`get_result_kind()`が`ResultKind.OVER`を返し、`%ResultMessageLabel.text`が`OVER_MESSAGE_TEXT`と一致する（既存ロジックの回帰確認）
- [ ] エッジケース: `_ready()`直後（どちらのシグナルも未発行）は`%ResultMessageLabel.text`が`INITIAL_MESSAGE_TEXT`（空文字）のままである

## Implementation Notes

- 参照すべき既存コード: `docs/dev/plans/garden-alchemy-visual-refresh/tasks/007-garden-screen-integration.md`と実際に適用された実装（パネル挿入・フォント適用パターン）
- 実装のヒント: `%ContentPanel`は既存ルート`Control`直下に新設する`PanelContainer`とし、既存の`CenterContainer`をその内側に移す。`CenterContainer`自体のセンタリング挙動は変更しない
- 注意事項: `result_screen.gd`のコメント「閉じる/次へ進むボタン・統計情報表示は実装しない（FR-402, FR-404）」というスコープ境界を尊重し、本タスクでもボタンを追加しない

## Files

- 変更: `atelier/features/rank/ui/result_screen.tscn`, `result_screen.gd`
- 新規: `atelier/features/rank/ui/rank_result_backdrop.tscn`のインスタンス配置（実体は006で新規作成済み）
- テスト: `atelier/tests/integration/test_rank_result_screen.gd`または既存の対応するテストファイル（既存テストの更新。ファイル名は実装確認時に特定する）
