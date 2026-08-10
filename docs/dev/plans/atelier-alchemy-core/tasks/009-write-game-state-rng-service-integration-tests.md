---
id: "009"
title: "GameState/RngServiceのGUT統合テストを作成する"
status: pending
priority: 3
dependencies: ["002", "003", "008"]
estimated_complexity: medium
---

# Task: GameState/RngServiceのGUT統合テストを作成する

## Goal

`GameState`と`RngService`（いずれもAutoload）に対するGUT統合テストを作成し、特にFR-103（`get_state()`のディープコピー検証）とFR-105（RngServiceのシード再現性）を確実に回帰検知できるテストを用意する。

## Interfaces

```gdscript
# tests/integration/test_game_state.gd
extends GutTest

func before_each() -> void:
	GameState.reset_for_test()

func test_初期状態のcurrent_phaseはgardenである() -> void: pass                    # 🔵 AC-003
func test_get_stateは初期値としてgold_0とcurrent_turn_1を含む() -> void: pass       # 🔵 AC-003, FR-004
func test_set_phaseでphase_changedシグナルが発行される() -> void: pass              # 🔵 AC-003（watch_signals使用）
func test_reset_for_test実行後にgoldが初期値0へ戻る() -> void: pass                 # 🔵 AC-005

func test_get_state戻り値のDictionaryを書き換えても内部状態は変化しない() -> void: pass  # 🔵 FR-103, AC-004（最重要）
```

```gdscript
# tests/integration/test_rng_service.gd
extends GutTest

func test_同一seedで5回のrandfが完全一致する() -> void: pass   # 🔵 FR-105, AC-006（最重要）
func test_異なるseedでは乱数列が一致しない() -> void: pass      # 🔵 AC-006異常系
func test_seed_0でも例外を投げず動作する() -> void: pass        # 🔵 AC-006境界値
func test_randf_rangeは指定範囲内の値を返す() -> void: pass     # 🟡 003タスクの拡張APIのカバー
```

## Test Strategy

- [ ] `test_get_state戻り値のDictionaryを書き換えても内部状態は変化しない`: `var state := GameState.get_state(); state["current_phase"] = &"dummy"; assert_ne(GameState.get_state()["current_phase"], &"dummy")` の形で検証する
- [ ] `test_set_phaseでphase_changedシグナルが発行される`: `watch_signals(GameState)` → `GameState.set_phase(&"alchemy")` → `assert_signal_emitted_with_parameters(GameState, "phase_changed", [&"garden", &"alchemy"])`
- [ ] `test_同一seedで5回のrandfが完全一致する`: `RngService.set_seed(12345)` で2回シーケンスを取得し `assert_eq(seq1, seq2)`
- [ ] `test_異なるseedでは乱数列が一致しない`: seed 12345と54321で結果が異なることを確認
- [ ] `test_reset_for_test実行後にgoldが初期値0へ戻る`: `GameState.reset_for_test()` 後 `assert_eq(GameState.get_state()["gold"], 0)`

## Implementation Notes

- 参照すべき既存文書: `.claude/rules/testing.md`「統合テスト」節、`.claude/rules/godot-debug-tools.md`「雛形1: セーブデータリセット相当」
- `GameState`/`RngService`はAutoload（プロセス内で単一）のため、`before_each()`で`reset_for_test()`を呼びテスト間の独立性を担保する（`RngService`側は`reset_for_test()`を持たないため、各テスト内で`set_seed()`を呼び直すことで独立性を担保する）
- `-gdir`はサブディレクトリを再帰しないため、実行時は`-ginclude_subdirs`を必ず付ける

## Files

- 新規: `atelier/tests/integration/test_game_state.gd`, `atelier/tests/integration/test_rng_service.gd`
- 変更: なし
- テスト: 本タスク自体がテスト作成タスク
