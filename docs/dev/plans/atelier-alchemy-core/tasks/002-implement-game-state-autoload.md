---
id: "002"
title: "GameState Autoloadの最小骨組みを実装する"
status: done
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: GameState Autoloadの最小骨組みを実装する

## Goal

`GameState` Autoload（StateManager相当）に、最小フィールド（`current_phase`, `gold`, `current_turn`）と `get_state()` / `set_phase()` / `reset_for_test()` を実装する。他Feature用のフィールド・メソッド（在庫操作等）はこのタスクでは追加しない（CON-004）。

## Interfaces

```gdscript
# autoload/game_state.gd
extends Node

signal phase_changed(previous: StringName, next: StringName)  # 🔵 FR-005

var _current_phase: StringName = &"garden"  # 🔵 FR-004、初期値&"garden"
var _gold: int = 0                          # 🔵 FR-004
var _current_turn: int = 1                  # 🔵 FR-004、初期値1（ユーザー確認済み）

# 内部状態のディープコピーを返す。呼び出し元がArray/Dictionaryを直接改変しても
# 内部状態(_current_phase等)に影響しないことを保証する（state-management.md「get_state()戻り値の防御的コピー必須」）
func get_state() -> Dictionary:  # 🔵 FR-103
	pass

# フェーズを変更しphase_changedを発行する
func set_phase(next: StringName) -> void:  # 🔵 FR-005
	pass

# デバッグビルド限定でテスト用に内部状態を初期値へ戻す。リリースビルドでは
# 本番コードパスから実行されないようガードする
func reset_for_test() -> void:  # 🔵 FR-104, FR-201
	pass
```

`add_gold()` / `advance_turn()` / `can_transition_to()` 等の個別Feature用メソッドは実装しない（🔵 CON-004厳守、後続Planで追加）。`GameState`のフィールドは外部から直接書き換え不可（🔵 FR-406、`_`prefixでprivate扱いとし専用メソッド経由でのみ変更する設計を徹底する）。

## Test Strategy

GUTテスト自体は009タスクで作成する（GameState/RngServiceをまとめて統合テスト化するため）。本タスクでは実装のみ行い、以下をGodotエディタでの簡易確認で満たすことを目安とする。

- [ ] `GameState.get_state()` が `{"current_phase": &"garden", "gold": 0, "current_turn": 1}` を返す（初期状態）
- [ ] `GameState.get_state()` の戻り値の `Dictionary` を書き換えても、再度 `get_state()` した際に元の値のままである（ディープコピー検証、FR-103の核心）
- [ ] `GameState.set_phase(&"alchemy")` 実行後、`phase_changed` signalが `(previous=&"garden", next=&"alchemy")` で発行される
- [ ] `GameState.reset_for_test()` 実行後、`gold`/`current_turn`/`current_phase` が全て初期値に戻る
- [ ] リリースビルド相当（`OS.is_debug_build() == false`）では `reset_for_test()` が本番コードパスから実行されないようガードされている（自動テスト対象外、コードレビューで確認）

## Implementation Notes

- 参照すべき既存文書: `.claude/rules/state-management.md`「GameState（StateManager相当）」節、`.claude/rules/coding-style.md`
- `get_state()` の実装は `{...}.duplicate(true)` の形（辞書リテラルを都度生成しディープコピーする）を推奨（Plan設計より）
- `project.godot` の Autoload登録（`Project > Project Settings > Autoload`）で `GameState` を登録すること。登録名は `GameState`（クラス名と一致させる）
- 型注釈を全フィールド・全メソッドに付与すること（`Variant`無条件使用禁止）

## Files

- 新規: `atelier/autoload/game_state.gd`
- 変更: `atelier/project.godot`（Autoload登録）
- テスト: `atelier/tests/integration/test_game_state.gd`（009タスクで作成）
