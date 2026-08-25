---
id: "008"
title: "MainSceneに昇格試験開始・合否分岐・終局画面へのルーティングを実装する"
status: pending
priority: 2
dependencies: ["003", "004", "005", "006", "007"]
estimated_complexity: high
---

# Task: MainSceneに昇格試験開始・合否分岐・終局画面へのルーティングを実装する

## Goal

`MainScene`が`GameState.exam_started` / `exam_outcome_confirmed` / `game_cleared` / `game_over`を購読し、昇格試験開始時のalchemyフェーズ切替、合否分岐（成功→workshop、失敗→garden）、終局（クリア/オーバー→result）を実装する。`commit_exam_outcome()`が同一フレーム内で`exam_outcome_confirmed`に続けて`game_cleared`/`game_over`を発行するケース（FR-113）で、最終的にresultフェーズが正しく上書き確定することを保証する。

## Interfaces

```gdscript
# atelier/scenes/main.gd への追加

# _ready()に追加:
#   GameState.exam_started.connect(_on_exam_started)
#   GameState.exam_outcome_confirmed.connect(_on_exam_outcome_confirmed)
#   GameState.game_cleared.connect(_on_game_cleared)
#   GameState.game_over.connect(_on_game_over)

func _on_exam_started() -> void:  # 🔵 FR-108
	GameState.set_phase(&"alchemy")
	_set_tabs_disabled(true)  # task 003で実装済みのヘルパーを流用（FR-201）

func _on_exam_outcome_confirmed(outcome: ExamOutcome.Value) -> void:  # 🔵 FR-109, FR-110
	match outcome:
		ExamOutcome.Value.SUCCESS:
			GameState.set_phase(&"workshop")
			_set_tabs_disabled(false)  # 試験終了により庭タブ解除（game_clearedで直後に再度上書きされうる）
		ExamOutcome.Value.FAILURE:
			GameState.set_phase(&"garden")
			_set_tabs_disabled(false)
		_:
			pass  # CONTINUEはフェーズ変更なし（AC-010異常系）

func _on_game_cleared() -> void:  # 🔵 FR-111, FR-113, FR-403
	GameState.set_phase(&"result")
	_set_tabs_disabled(true)  # FR-202

func _on_game_over(_demotion_count: int) -> void:  # 🔵 FR-112, FR-113, FR-403
	GameState.set_phase(&"result")
	_set_tabs_disabled(true)  # FR-202
```

## Test Strategy

- [ ] `GameState.exam_started`発行後、`get_visible_phase() == &"alchemy"`かつ庭タブが`disabled == true`
- [ ] `exam_outcome_confirmed(SUCCESS)`のみ発行（`game_cleared`は発行されない、非最終ランクのケース）された場合、最終的に`get_visible_phase() == &"workshop"`
- [ ] `exam_outcome_confirmed(FAILURE)`のみ発行（`game_over`は発行されない）された場合、最終的に`get_visible_phase() == &"garden"`
- [ ] **[AC-012相当・本Planの受入の中核]** `exam_outcome_confirmed(SUCCESS)` → `game_cleared`の順に2回発行された場合（真の最終ランクでの成功）、`monitor_signals(GameState, false)`で両方の発行を確認した上で、最終的に`get_visible_phase() == &"result"`（WorkshopScreenが`visible == false`であること）
- [ ] **[AC-012相当]** `exam_outcome_confirmed(FAILURE)` → `game_over(demotion_count)`の順に2回発行された場合、最終的に`get_visible_phase() == &"result"`（GardenScreenが`visible == false`であること）
- [ ] `game_cleared`/`game_over`発行後、タブバーの両ボタンが`disabled == true`
- [ ] **異常系**: result表示後に`GameState.set_phase()`が外部から呼ばれても、本タスクの範囲では何もガードしない（FR-403は「MainSceneが自動的に復帰しない」ことのみを規定し、外部からの強制遷移まで防ぐ設計にはしない。防御が必要なら別途Issue化を検討する旨をテストコメントで明記する）
- [ ] `exam_outcome_confirmed(CONTINUE)`受信時、フェーズが変化しない

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/autoload/game_state_rank_delegate.gd:133-155`（`commit_exam_outcome()`。`exam_outcome_confirmed.emit(outcome)`の後に`if did_clear_game: state.game_cleared.emit()`、その後に`game_over`条件チェックという順序を正確に踏襲した設計であることを再確認する）
  - `atelier/features/rank/logic/exam_outcome.gd`（`ExamOutcome.Value`のenum定義。`SUCCESS`/`FAILURE`/`CONTINUE`）
  - `atelier/features/rank/ui/result_screen.gd`（`GameState.game_cleared`/`game_over`を自己購読し表示を切り替える既存実装。ResultScreen自体は無改修）
- 実装のヒント: `_on_exam_outcome_confirmed()`と`_on_game_cleared()`/`_on_game_over()`はGodotのsignal接続順（`connect()`した順、通常は本タスクでのコード記述順）で同期的に呼ばれる。`exam_outcome_confirmed`のハンドラを先に`connect()`し、`game_cleared`/`game_over`を後に`connect()`すれば、発行順序（emit順）とハンドラ実行順が一致し「暫定遷移→上書き」が成立する。接続順を变えない（`_ready()`内でのconnect呼び出し順を意図的に維持する）ことをコードコメントに明記すること。
- 注意事項: `_set_tabs_disabled()`はtask 003で実装済みの関数を流用する（本タスクで重複定義しない）。試験失敗直後にゲームオーバー確定するケース（`exam_outcome_confirmed(FAILURE)`→`_set_tabs_disabled(false)`→直後に`game_over`→`_set_tabs_disabled(true)`）でも、最終的にdisabledがtrueで確定することをテストで明示的に確認する（境界値）。

## Files

- 変更: `atelier/scenes/main.gd`
- テスト: `atelier/tests/integration/test_main_scene_exam_and_result_routing.gd`（新規）
