---
id: "007"
title: "GameState.set_phase()にオートセーブフックを統合する"
status: done
priority: 3
dependencies: ["006"]
estimated_complexity: medium
---

# Task: GameState.set_phase()にオートセーブフックを統合する

## Goal

`GameState.set_phase()`がフェーズを実際に変更した瞬間に`SaveService.autosave()`を呼ぶよう統合する。既存の全GdUnit4テスト（`set_phase()`を多用）に副作用を与えないことを回帰確認する。

## Interfaces

```gdscript
# atelier/autoload/game_state.gd の set_phase() を変更

func set_phase(next: StringName) -> void:
	var previous := _current_phase
	_current_phase = next
	phase_changed.emit(previous, next)
	if previous != next:  # 🔵 同一フェーズへの冪等な呼び出しでの無駄な書き込みを避ける
		SaveService.autosave()
```

## Test Strategy

- [ ] `active_slot == -1`（`GameStateTestSupport`経由のテスト環境の既定値）のまま`set_phase()`を複数回呼んでも、`user://saves/`配下にファイルが一切作成されない（既存テスト群への非干渉の回帰確認）
- [ ] `SaveService.active_slot`をテストで明示的に設定した状態で`set_phase(&"alchemy")`を呼ぶと、対応するスロットファイルが更新される
- [ ] 同じフェーズへ`set_phase()`を呼んだ場合（`previous == next`）はファイルへの書き込みが発生しない（更新日時やファイル内容が変化しないことで確認する）
- [ ] `set_phase()`を連続して異なるフェーズへ呼んだ場合、都度最新の状態でファイルが上書きされる（最後の呼び出し内容が保存される）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の既存`set_phase()`実装（`phase_changed.emit()`のタイミングを変更しないこと。既存の`main.gd`等が`phase_changed`購読に依存しているため、`emit()`の位置・引数は現状維持し、その直後にオートセーブ呼び出しを追加するだけに留める）
- 実装のヒント: `SaveService`はAutoloadのため`GameState`スクリプトから直接名前参照できる（他Autoload間の参照は既存コードにも前例あり、`MasterDataLoader`等）
- 注意事項: 本タスク完了後、`cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/`で全テストスイートを実行し、既存テスト（特に`test_game_state_*.gd`, `test_main_scene_*.gd`）がすべてGreenのままであることを確認すること（`.claude/rules/implement-workflow.md`のコミット前チェックリスト）

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_autosave_on_phase_change.gd`
