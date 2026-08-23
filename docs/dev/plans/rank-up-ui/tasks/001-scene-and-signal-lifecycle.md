---
id: "001"
title: "AlchemyScreenに試験モード用ノードとシグナル購読ライフサイクルを追加する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: AlchemyScreenに試験モード用ノードとシグナル購読ライフサイクルを追加する

## Goal

`alchemy_screen.tscn`に試験モード専用の新規ノード3件（残りターン表示・案内メッセージ・ターンを進めるボタン）を追加し、`alchemy_screen.gd`から`@onready`で参照できるようにする。あわせて`GameState.exam_started`/`exam_outcome_confirmed`を`_ready()`で購読し`_exit_tree()`で解除する、他シグナル（`product_crafted`等）と同型のライフサイクルを実装する。このタスク単体では表示内容の更新ロジックは実装しない（後続タスク002/003が担当）。

## Interfaces

```gdscript
# alchemy_screen.tscn への追加ノード（すべて unique_name_in_owner=true, 初期 visible=false）
# 🔵 設計フェーズで確定済み
@onready var _exam_turn_label: Label = %ExamTurnLabel               # 🔵
@onready var _advance_exam_turn_button: Button = %AdvanceExamTurnButton  # 🔵
@onready var _exam_guidance_label: Label = %ExamGuidanceLabel       # 🔵（表示ロジックは後続タスク）

# _ready() に追加する購読（既存 product_crafted/execute_alchemy_failed と同型）🔵
# GameState.exam_started.connect(_on_exam_started)
# GameState.exam_outcome_confirmed.connect(_on_exam_outcome_confirmed)

# _exit_tree() に追加する解除（is_connected()ガード必須）🔵
# if GameState.exam_started.is_connected(_on_exam_started):
#     GameState.exam_started.disconnect(_on_exam_started)
# if GameState.exam_outcome_confirmed.is_connected(_on_exam_outcome_confirmed):
#     GameState.exam_outcome_confirmed.disconnect(_on_exam_outcome_confirmed)

# このタスクではハンドラの中身は空実装（pass）でよい。中身は002/003で実装する
func _on_exam_started() -> void:
	pass  # 🔵 002/003で実装

func _on_exam_outcome_confirmed(outcome: ExamOutcome.Value) -> void:
	pass  # 🔵 型注釈必須（NFR-101）。002/003で実装
```

配置根拠（🔴 実装判断、機能的な正しさはvisible/textのみに依存し順序は自由に変更してよい）:
- `%ExamTurnLabel`: `VBoxContainer`直下の先頭（`%RecipeOptionButton`の直前）
- `%ExamGuidanceLabel`: `%MaterialInventoryList`の直後
- `%AdvanceExamTurnButton`: `ActionRow`内`%ExecuteButton`の直後・`%ShopButton`の前

## Test Strategy

- [ ] `_ready()`後、`GameState.exam_started.is_connected(...)`が`true`を返す（AC-009正常系）
- [ ] `_ready()`後、`GameState.exam_outcome_confirmed.is_connected(...)`が`true`を返す（AC-009正常系）
- [ ] `queue_free()`で破棄後（`_exit_tree()`実行後）、両シグナルの`is_connected(...)`が`false`を返す（AC-009正常系）
- [ ] 破棄後に`GameState.exam_started.emit()`/`GameState.exam_outcome_confirmed.emit(ExamOutcome.Value.CONTINUE)`を発行してもエラーが発生しない（AC-009異常系。既存`test_破棄後にGameStateのシグナルを発行しても例外が発生しない()`と同型の検証を追加）
- [ ] 画面生成直後、`%ExamTurnLabel`/`%ExamGuidanceLabel`/`%AdvanceExamTurnButton`の`visible`が`false`である（初期状態の境界値）
- [ ] 既存テスト（`test_alchemy_screen.gd`の全ケース）が回帰しないことを確認する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/alchemy/ui/alchemy_screen.gd`の`_ready()`（46〜57行目）・`_exit_tree()`（60〜64行目）の`product_crafted`/`execute_alchemy_failed`購読パターンをそのまま踏襲する
- `.tscn`編集はGodotエディタまたはテキストエディタでの直接編集のいずれでもよいが、既存ノードの親子構造・プロパティは一切変更しないこと（FR-408、CON-001）
- `ExamOutcome`は`features/rank/logic/exam_outcome.gd`の`class_name`をそのままグローバル参照する（`const`再宣言禁止）
- このタスクは「土台」のみで、`_on_exam_started()`/`_on_exam_outcome_confirmed()`の中身（トースト表示等）はタスク003で実装する。空実装のままでもテストは通る設計にする

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.tscn`
- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`
- テスト: `atelier/tests/integration/test_alchemy_screen.gd`
