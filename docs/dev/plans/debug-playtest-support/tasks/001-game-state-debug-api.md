---
id: "001"
title: "GameStateへのデバッグ支援APIを追加する"
status: done
priority: 1
dependencies: []
estimated_complexity: medium
---

# Task: GameStateへのデバッグ支援APIを追加する

## Goal

デバッグビルド限定で「ゴールド付与」「ノルマ即達成（ターン即時終了）」「次ランクへジャンプ」を行える3つのpublicメソッドをGameStateファサードに追加し、実装本体は`game_state_debug_delegate.gd`へ委譲する。

## Interfaces

```gdscript
# atelier/autoload/game_state_debug_delegate.gd（新規）
class_name GameStateDebugDelegate
const GameStateScript = preload("res://autoload/game_state.gd")

# 🔵 GameStateTestSupport.set_gold()と同型の直接フィールド操作。DEBUG_GOLD_AMOUNTは
# 本ファイル内のローカル定数とする（GameBalance/UiThemeいずれにも該当しないQA専用値のため）
static func debug_add_gold(state: GameStateScript) -> void

# 🔵 alchemy_screen.gd:_on_end_turn_pressed()と同じ
# 「deliver_pending_products() → commit_rank_outcome()」を踏襲する
static func debug_force_end_turn(state: GameStateScript) -> Result

# 🔵 rank_progression.gdのRankProgression.get_next_rank_id()/is_true_final_rank()と
# game_state_rank_delegate.gdの昇格時初期化パターン（RankQuotaResolver.reset_for_retry()）を踏襲。
# 末尾ランク（is_true_final_rank()がtrue）または次ランクのRankMaster未登録時は何もしない
static func debug_jump_to_next_rank(state: GameStateScript) -> void
```

```gdscript
# atelier/autoload/game_state.gd（変更・追加分のみ）
# 🔵 GameStateTestSupport.guard()をそのまま再利用し、リリースビルドでは
# push_error+早期returnで何もしない（reset_for_test()と同じガード形）
func debug_add_gold() -> void
func debug_force_end_turn() -> Result
func debug_jump_to_next_rank() -> void
```

> 🔴 `.gdlintrc`の`max-public-methods`が現在29（上限）のため、3メソッド追加により32への緩和が必要。
> 既存コメント（L37-43）と同形式で「debug-playtest-support Planでdebug_add_gold()・
> debug_force_end_turn()・debug_jump_to_next_rank()の3本を追加し29を超えたため32へ再緩和する」
> という趣旨のコメントを追記すること。

## Test Strategy

- [ ] `debug_add_gold()`を呼ぶと所持ゴールドが固定量（+1000）増加する
- [ ] `debug_force_end_turn()`を呼ぶと、`pending_products`に納品待ちがある状態で納品決算が実行され`pending_products`が空になる
- [ ] `debug_force_end_turn()`を呼ぶと、ノルマを消化済みの状態では`commit_rank_outcome()`の結果として昇格判定（`in_exam`がtrueになる等）が反映される
- [ ] `debug_jump_to_next_rank()`を呼ぶと、`current_rank_id`が`RankProgression.get_next_rank_id()`の返すIDに変わり、`rank_state.quota`が次ランクの`quota_max`にリセットされる
- [ ] エッジケース: 現在ランクが`RANK_ORDER`末尾（`is_true_final_rank()`がtrue）の状態で`debug_jump_to_next_rank()`を呼んでも`current_rank_id`が変化しない
- [ ] エッジケース: リリースビルドを模した状態（`OS.is_debug_build()`がfalseの経路）では3メソッドいずれも状態を変化させない（`GameStateTestSupport.guard()`と同じ検証方法に倣う。実機での完全なリリースビルド検証はGdUnit4実行環境の制約上できないため、既存の`reset_for_test()`のテストパターンに合わせた検証で代替する）

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/autoload/game_state_test_support.gd`（`guard()`関数、および`set_gold()`等の直接フィールド操作パターン）
  - `atelier/autoload/game_state_rank_delegate.gd` L81-95, L229-241（`commit_rank_outcome()`の実装、`reset_for_retry()`の使い方）
  - `atelier/features/alchemy/ui/alchemy_screen.gd` L413-416（`_on_end_turn_pressed()`の2呼び出し）
  - `atelier/features/rank/logic/rank_progression.gd`（`get_next_rank_id()`, `is_true_final_rank()`）
- 実装のヒント: `debug_force_end_turn()`は既存の`GameState.deliver_pending_products()`と`GameState.commit_rank_outcome()`をそのまま順に呼ぶだけでよい（新規ロジック不要）。UI側のギルド納品結果パネル表示（`_guild_delivery_screen.display_results()`相当）は本タスクでは行わない（デバッグ用途のため結果画面のポップアップは省略してよい）。
- 注意事項: `game_state_debug_delegate.gd`は`state._current_rank_id`等の`_`prefixフィールドに直接アクセスするため、既存delegateファイル群と同じ「Autoloadモジュール内部」という扱いになる。他Featureからはこのdelegateを直接参照せず、必ず`GameState`ファサード経由にすること。

## Files

- 新規: `atelier/autoload/game_state_debug_delegate.gd`
- 変更: `atelier/autoload/game_state.gd`（3メソッド追加）
- 変更: `atelier/.gdlintrc`（`max-public-methods: 29` → `32`、理由コメント追記）
- テスト: `atelier/tests/integration/test_game_state_debug_support.gd`
