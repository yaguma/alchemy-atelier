---
id: "007"
title: "GameStateにランク関連フィールドを追加しtraits_unlockedをランク由来に置き換える"
status: done
priority: 3
dependencies: ["002", "003", "004"]
estimated_complexity: high
---

# Task: GameStateにランク関連フィールドを追加しtraits_unlockedをランク由来に置き換える

## Goal

`autoload/game_state.gd`に、ランク結果判定（タスク008）の前提となるランタイムフィールド（現在ランクID・ランクマスター群・ランク状態・降格回数）を追加する。既存の暫定フィールド`_traits_unlocked`を削除し、`execute_alchemy()`内の参照箇所を現在ランクの`RankMaster.traits_unlocked`由来の値に置き換える（CON-005: 既存テスト専用API`_set_traits_unlocked_for_test()`も削除し、ランク注入経由に一本化する）。`evaluate_rank_outcome`/`commit_rank_outcome`本体（タスク008）は対象外。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルへの追記・一部削除）

# --- ランク（rank）関連フィールド ---
var _current_rank_id: StringName = GameBalance.INITIAL_RANK_ID  # 🔵 FR-006
var _rank_masters: Dictionary = {}  # 🔵 FR-006。Dictionary[StringName, RankMaster]（_seed_masters等と同型）
var _rank_state: RankState = RankState.new()  # 🔵 FR-006
var _demotion_count: int = 0  # 🔵 FR-006

# var _traits_unlocked: bool = false  # 🔵 FR-201により削除（alchemy CON-007の暫定フィールドを撤去）

## _rank_mastersに_current_rank_idが存在しなければpush_error()し、
## traits_unlocked=false/quota_max=0.0/limit_turnという既定値を持つフォールバックRankMasterを返す（FR-114, CON-008）
func _get_current_rank_master_or_fallback() -> RankMaster:  # 🔴
	...

## テスト専用。_rank_mastersを直接注入する
func _set_rank_masters_for_test(masters: Dictionary) -> void:  # 🟡 FR-301
	...

## テスト専用。_current_rank_idを直接注入する
func _set_current_rank_id_for_test(rank_id: StringName) -> void:  # 🟡 FR-301
	...

## テスト専用。_rank_stateを直接注入する（内部でclone()して格納する）
func _set_rank_state_for_test(state: RankState) -> void:  # 🟡 FR-301
	...

## テスト専用。_demotion_countを直接注入する
func _set_demotion_count_for_test(count: int) -> void:  # 🟡 FR-301
	...
```

> 信号機: 🔵 `_current_rank_id`/`_rank_masters`/`_rank_state`/`_demotion_count`は既存`_seed_masters`/`_recipe_masters`と同型パターン。🔴 `_get_current_rank_master_or_fallback`のフォールバック具体値はCON-008で本plan内新規決定。🟡 テスト専用API群は既存パターン踏襲の新規補完（FR-301）

## Test Strategy

- [ ] 正常系: `reset_for_test()`実行後、`_current_rank_id`が`GameBalance.INITIAL_RANK_ID`、`_rank_masters`が空、`_rank_state.quota`が`0.0`、`_demotion_count`が`0`になっている
- [ ] 正常系: `get_state()`が`current_rank_id`・`demotion_count`・`rank_state`をキーとして含む
- [ ] エッジケース: `get_state()`の戻り値の`rank_state`（`RankState`）を変更しても`GameState`内部の`_rank_state`は変化しない（防御的コピー、FR-410）
- [ ] 正常系（AC-014）: `_set_rank_masters_for_test({&"rank_g": rank_master})` + `_set_current_rank_id_for_test(&"rank_g")`実行後、`_get_current_rank_master_or_fallback()`が注入した`rank_master`を返す
- [ ] 異常系（AC-014）: `_rank_masters`が空のまま`_get_current_rank_master_or_fallback()`を呼ぶと、`push_error()`が発行され`traits_unlocked=false`のフォールバックが返る（クラッシュしない）
- [ ] 正常系（AC-014）: `execute_alchemy()`実行時、`_get_current_rank_master_or_fallback().traits_unlocked`が`QualityCalculator.calculate_quality`・`TraitActivation.resolve_traits`へ正しく渡される（`traits_unlocked = true`の`RankMaster`を注入したケースと`false`のケースを対比確認する。alchemy plan AC-011の統合テストを本タスクで更新する形でも可）
- [ ] 異常系: `_set_traits_unlocked_for_test()`が呼び出し不能（メソッド自体が存在しない）ことをコードレビューで確認する（削除の確認、CON-005）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`_seed_masters`/`_recipe_masters`（Dictionary型マスター群のフィールド宣言パターン）、`_set_masters_for_test()`/`_set_recipe_masters_for_test()`（テスト専用APIの二重ガード実装）、`execute_alchemy()`内の`_traits_unlocked`参照2箇所（`QualityCalculator.calculate_quality(materials, _traits_unlocked)`・`TraitActivation.resolve_traits(materials, _traits_unlocked)`）
- 実装のヒント: `_traits_unlocked`削除に伴い、`execute_alchemy()`内の2箇所の参照を`_get_current_rank_master_or_fallback().traits_unlocked`に置換する。`get_state()`の`rank_state`は`_rank_state.clone()`で防御的コピーする（`_garden_state.clone()`と同じパターン）
- 注意事項: **既存のalchemy plan統合テスト（AC-011「`_traits_unlocked`切替の対比確認」に対応するテスト）が`_set_traits_unlocked_for_test()`を使用している場合、本タスクで`_set_rank_masters_for_test`+`_set_current_rank_id_for_test`を使う形へ更新する**（NFR-303が明示的に許容する破壊的変更。更新理由をコミットメッセージに記載すること）

## Files

- 変更: `atelier/autoload/game_state.gd`
- 変更（可能性あり）: `atelier/tests/integration/test_game_state_execute_alchemy.gd`（`_set_traits_unlocked_for_test()`使用箇所の更新、NFR-303）
- テスト: `atelier/tests/integration/test_game_state_rank_foundation.gd`
