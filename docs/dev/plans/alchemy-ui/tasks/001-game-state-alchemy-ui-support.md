---
id: "001"
title: "GameStateへ調合UI向けアクセッサ（recipe_masters/alchemy_slot_count/is_current_rank_traits_unlocked）を追加する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: GameStateへ調合UI向けアクセッサを追加する

## Goal

`AlchemyScreen`がレシピ詳細情報・投入枠上限・現在ランクの特性解禁状態を取得できるよう、`GameState.get_state()`へ`recipe_masters`/`alchemy_slot_count`を追加公開し、`GameState.is_current_rank_traits_unlocked() -> bool`を新規追加する（CON-001, CON-002, AC-015）。

## Interfaces

```gdscript
# atelier/autoload/game_state.gd の get_state() 内、既存の
# "seed_masters": _seed_masters.duplicate(), / "garden_slot_count": _garden_slot_count,
# の並びに揃えて以下を追記する

func get_state() -> Dictionary:
	return {
		# ...既存キー...
		"recipe_masters": _recipe_masters.duplicate(),    # 🔵 seed_masters公開と同型。マスターデータ（Resource、不変前提）のため浅いduplicate()で十分
		"alchemy_slot_count": _alchemy_slot_count,          # 🔵 garden_slot_count公開と同型。int値型のため複製不要
		# ...既存キー...
	}


## 🔴 新規追加。既存privateヘルパー_get_current_rank_master_or_fallback()を再利用し、
## execute_alchemy()実行時のtraits_unlocked判定と完全に同一ロジックで算出する
## （UI予測とDomain層再評価の不一致を防ぐ、NFR-101関連）
func is_current_rank_traits_unlocked() -> bool:
	return _get_current_rank_master_or_fallback().traits_unlocked
```

## Test Strategy

- [ ] **正常系**: `_set_recipe_masters_for_test()`で2件のレシピを注入後、`get_state().recipe_masters`が2件とも含む辞書を返す
- [ ] **正常系**: `_set_alchemy_slot_count_for_test(6)`後、`get_state().alchemy_slot_count`が`6`を返す
- [ ] **正常系**: `_set_rank_masters_for_test()`で`traits_unlocked = true`のランクマスターを注入し`_set_current_rank_id_for_test()`で現在ランクに設定後、`is_current_rank_traits_unlocked()`が`true`を返す
- [ ] **正常系**: 同様に`traits_unlocked = false`のランクマスターで`false`を返す
- [ ] **異常系**: 現在ランクに対応する`RankMaster`が未登録（マスター未ロード）の場合、`_get_current_rank_master_or_fallback()`のフォールバック（`traits_unlocked = false`）により`is_current_rank_traits_unlocked()`が`false`を返し、例外を投げない
- [ ] **防御的コピー確認**: `get_state().recipe_masters`を取得後、返却された辞書へキーを追加しても`GameState`内部の`_recipe_masters`に影響しない（浅いduplicate()で辞書自体は独立するが、値のResourceインスタンス自体は共有される点を踏まえ、辞書の追加/削除に対する独立性のみ検証する）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`（`get_state()`実装、L88-129）、`atelier/autoload/game_state.gd`の`_get_current_rank_master_or_fallback()`（L219-230、既存private関数をそのまま再利用する）
- 実装のヒント: `_recipe_masters`/`_alchemy_slot_count`は既に`GameState`のフィールドとして存在する（`game_state.gd` L39, L43）。`_set_recipe_masters_for_test()`/`_set_alchemy_slot_count_for_test()`もテスト専用APIとして既に存在する（`game_state_test_support.gd`参照）ため、本タスクは`get_state()`辞書へのキー追加と、新規publicメソッド1つの追加のみで完結する
- 注意事項: `is_current_rank_traits_unlocked()`は`GameStateAlchemyDelegate.execute_alchemy()`が内部で行っている`state._get_current_rank_master_or_fallback().traits_unlocked`と全く同じ式であることを確認し、ロジックの重複実装をしないこと（両者が将来的に乖離しないよう、`GameState`本体の同一private関数を参照する）

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_alchemy_ui_support.gd`
