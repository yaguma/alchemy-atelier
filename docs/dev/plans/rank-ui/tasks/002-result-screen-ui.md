---
id: "002"
title: "ResultScreen(SCR-006結果画面)を実装しgame_over/game_clearedを自己購読する"
status: done
priority: 2
dependencies: ["001"]
estimated_complexity: medium
---

# Task: ResultScreen(SCR-006結果画面)を実装しgame_over/game_clearedを自己購読する

## Goal

`features/rank/ui/result_screen.gd`/`.tscn`として単一`Control`継承の`ResultScreen`を新規実装する。`GameState.game_over`・`GameState.game_cleared`（タスク001で追加）を`_ready()`で自己購読し、`ResultKind`に応じて`%ResultMessageLabel`のテキストのみを排他的に切替える。ボタン等のインタラクティブ要素・統計情報表示は持たない。

## Interfaces

```gdscript
# atelier/features/rank/ui/result_screen.gd
class_name ResultScreen
extends Control

## 結果画面。GameState.game_over / GameState.game_cleared を自己購読し、
## クリア表示/オーバー表示を単一Control内で排他的に切り替える。
## 閉じる/次へ進むボタン・統計情報表示は実装しない（FR-402, FR-404）。

enum ResultKind { NONE, CLEAR, OVER }  # 🔵 FR-401（排他性）を型で表現

const CLEAR_MESSAGE_TEXT := "ゲームクリア"  # 🟡 文言は暫定（ui-design/overview.mdでSCR-006詳細設計は未作成）
const OVER_MESSAGE_TEXT := "ゲームオーバー"  # 🟡 同上
const INITIAL_MESSAGE_TEXT := ""  # 🟡 シグナル未発行時は結果種別未確定（AC-003境界値）

var _result_kind: ResultKind = ResultKind.NONE  # 🔵 排他状態を保持する唯一のソース

@onready var _result_message_label: Label = %ResultMessageLabel

func _ready() -> void:  # 🔵 FR-001
	_apply_result_kind()
	GameState.game_over.connect(_on_game_over)
	GameState.game_cleared.connect(_on_game_cleared)

func _exit_tree() -> void:  # 🔵 FR-104
	if GameState.game_over.is_connected(_on_game_over):
		GameState.game_over.disconnect(_on_game_over)
	if GameState.game_cleared.is_connected(_on_game_cleared):
		GameState.game_cleared.disconnect(_on_game_cleared)

## テスト用。現在の表示種別を返す 🟡 FR-301
func get_result_kind() -> ResultKind:
	return _result_kind

func _on_game_cleared() -> void:  # 🔵 FR-102
	_result_kind = ResultKind.CLEAR
	_apply_result_kind()

func _on_game_over(_demotion_count: int) -> void:  # 🔵 FR-103, FR-404（demotion_countは意図的に未使用）
	_result_kind = ResultKind.OVER
	_apply_result_kind()

func _apply_result_kind() -> void:
	if _result_message_label == null:
		return
	match _result_kind:
		ResultKind.CLEAR:
			_result_message_label.text = CLEAR_MESSAGE_TEXT
		ResultKind.OVER:
			_result_message_label.text = OVER_MESSAGE_TEXT
		_:
			_result_message_label.text = INITIAL_MESSAGE_TEXT
```

シーン構成（`result_screen.tscn`）: ルート`Control`（フル画面anchor）→`CenterContainer`→`ResultMessageLabel`（`Label`、`unique_name_in_owner=true`）の3ノードのみ。`Button`ノードは含めない（FR-402, AC-006）。統計情報表示用ノードも含めない（FR-404, AC-008）。フォントは`project.godot`のプロジェクト共通テーマ（`main_theme.tres`、Noto Sans JP適用済み）に委ね、個別オーバーライドは行わない（NFR-201）。

## Test Strategy

配置先: `atelier/tests/integration/test_result_screen.gd`（新規）、`scene_runner()`または`auto_free()`+`add_child()`でシーンツリーに接続してテストする

- [ ] **正常系**: `GameState.game_cleared`を発行→`ResultScreen.get_result_kind()`が`ResultKind.CLEAR`になり、`%ResultMessageLabel.text`が`"ゲームクリア"`になることを確認する（AC-001, AC-002対応）
- [ ] **正常系**: `GameState.game_over`を発行→`get_result_kind()`が`ResultKind.OVER`になり、`%ResultMessageLabel.text`が`"ゲームオーバー"`になることを確認する
- [ ] **異常系**: `_ready()`直後、いずれのシグナルも発行していない状態で`get_result_kind()`が`ResultKind.NONE`、`%ResultMessageLabel.text`が空文字であることを確認する
- [ ] **異常系**: `_ready()`後、両シグナルへの接続が`GameState.game_over.is_connected(...)`/`GameState.game_cleared.is_connected(...)`でともに`true`になることを確認する
- [ ] **異常系**: ノードを`queue_free()`等でシーンツリーから除去（`_exit_tree()`実行）した後、両シグナルへの接続がともに`false`になることを確認する
- [ ] **境界値**: `game_cleared`発行後に`game_over`を発行すると、後着の`game_over`が優先され`get_result_kind()`が`ResultKind.OVER`になる（逆順でも同様に後着優先）ことを確認する（FR-401, AC-005の排他性検証）
- [ ] **境界値**: `demotion_count`に`0`を渡して`game_over`を発行しても、`%ResultMessageLabel.text`が`"ゲームオーバー"`のままで`demotion_count`の値自体は表示に使われないことを確認する（FR-404）
- [ ] **レビュー確認**: `result_screen.tscn`に`Button`ノード（またはそれに類する押下可能なコントロール）が含まれないこと（AC-006）、統計情報表示用ノードが`%ResultMessageLabel`以外に存在しないこと（AC-008）、`_process()`/`_physics_process()`を定義していないこと（NFR-001）をコードレビューで確認する
- [ ] **レビュー確認**: `atelier/scenes/main.tscn`に`ResultScreen`ノードが追加されていないこと（AC-007, CON-004）を確認する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/alchemy_screen.gd`（`_ready()`でのシグナル購読・`_exit_tree()`での`disconnect()`・テスト用ゲッターパターン）、`.claude/rules/state-management.md`・`.claude/rules/ui-components.md`の`PhaseIndicator`/`GoldDisplay`コード例
- 実装のヒント: `_result_kind`単一フィールドへの無条件上書きだけで排他性（FR-401）が自動的に満たされる設計。追加の排他制御ロジックは不要
- 注意事項: タスク001で`GameState.game_cleared`が実装済みであることが前提。`GameState`はAutoloadのため、テストでは`monitor_signals(GameState, false)`を明示すること（第2引数省略でAutoloadが誤解放される既知の罠）

## Files

- 新規: `atelier/features/rank/ui/result_screen.gd`
- 新規: `atelier/features/rank/ui/result_screen.tscn`
- テスト: `atelier/tests/integration/test_result_screen.gd`
