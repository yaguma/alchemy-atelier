# Plan: debug-playtest-support

## Requirements Summary

CLAUDE.md「次のステップ」記載の残作業のうち、「5機能を通した結合プレイ（庭→調合→ギルド納品→ランク進行→工房強化のループが実機で通しで回るか）の確認はまだ行われていない」に対応する。

- G→F→Eの2段階昇格ループ自体は `test_main_scene_full_loop_playthrough.gd`（GdUnit4シーンテスト）で既にシーンレベルの自動検証が済んでいる。
- CLAUDE.mdが指す「実機で通しで回るか」は**人間による実プレイでの確認**を意味するが、本環境にはGodotのGUI操作を自動化するツールが無いため、Claude自身が代わりにプレイすることはできない。
- そのため本Planのスコープは「人間が実プレイでの確認を素早く行えるようにする支援」に限定する:
  1. デバッグビルド限定の常設デバッグパネル（ゴールド付与・ノルマ即達成/ターン即時終了・次ランクへジャンプの3操作）
  2. その支援ツールを使って庭→調合→ギルド納品→ランク進行（G〜S全ランク）→工房強化のループを一通り確認するための手順書（チェックリスト）
- プレイ中に見つかる可能性のあるバグの修正は本Planのスコープ外とする（発見時は別途新規Planとして起票する）。

## Design Overview

### アーキテクチャ方針

- 既存の `game_state_*_delegate.gd` パターン（Application層、`GameStateScript`を引数に取るstatic func）を踏襲し、`game_state_debug_delegate.gd` を新設する。
- デバッグ専用APIのビルド制限は `game_state_test_support.gd` が既に持つ `GameStateTestSupport.guard(function_name: String) -> bool`（`OS.is_debug_build()`チェック + push_error）をそのまま再利用する。新規の類似ヘルパーは作らない。
- 3つの新規debug操作は「デバッグ専用の状態注入」ではなく「実プレイ中に呼ばれる正規の状態遷移トリガー」であるため、`*_for_test`系（`game_state_test_support.gd`）とは別ファイル（`game_state_debug_delegate.gd`）に分離する。役割が違うため混在させない。
- UIコンポーネント（DebugPanel）からGameStateのDomain層を直接呼び出すことは禁止（state-management.md）のため、GameStateファサードに3つの新規publicメソッドを追加し、UIは必ずそれ経由で呼ぶ。

### 🔴 既知のリスク: `.gdlintrc` の `max-public-methods` 上限

`atelier/.gdlintrc` の `max-public-methods` は既に29（直近まで29回緩和済み、コメント参照）に達している。今回3メソッド追加すると32が必要になる。task 001でその緩和とコメント追記（緩和理由・Plan名を既存コメント群と同形式で追記）をあわせて行う。

### 3つのdebug操作の実現方法（既存ロジックの再利用）

| 操作 | 実現方法 | 参照済み既存コード |
|---|---|---|
| ゴールド付与 | 固定量（例: +1000）を`_gold`に加算 | `GameStateTestSupport.set_gold()`と同様の直接フィールド操作 |
| ノルマ即達成/ターン即時終了 | `alchemy_screen.gd:_on_end_turn_pressed()`と同じ「`deliver_pending_products()` → `commit_rank_outcome()`」の2呼び出しをそのまま踏襲 | `atelier/features/alchemy/ui/alchemy_screen.gd` L413-416 |
| 次ランクへジャンプ | `RankProgression.get_next_rank_id()` / `is_true_final_rank()` で次ランクIDを解決し、`_current_rank_id`を更新後`RankQuotaResolver.reset_for_retry(next_master)`で`_rank_state`を初期化。末尾ランクでは何もしない | `atelier/autoload/game_state_rank_delegate.gd` L229-231（昇格時と同じ初期化パターン） / `atelier/features/rank/logic/rank_progression.gd` |

### UI設計

- `atelier/shared/debug/debug_panel.gd` + `.tscn`（`Control`継承、`main.tscn`の最後尾の子として常時最前面に配置。`%SettingsOverlayLayer`と同じ配置パターン）。
- `_ready()`冒頭で`OS.is_debug_build()`が偽なら`queue_free()`で自分自身を除去する（本番ビルドでは一切残らない。godot-debug-tools.md「禁止事項」準拠）。
- ボタン3つ（ゴールド+1000／ノルマ即達成／次ランクへ）を縦に並べた小さなパネル。デザインガイド（水彩/ドット絵）には従わない最小限の見た目でよい（QA専用、プレイヤー向け画面ではないため`design-guide.md`の対象外とする）。
- ゴールド定数（+1000等）は`GameBalance`にもUiThemeにも置かない。ゲームバランスにもUIデザインにも影響しないQA専用の値のため、`debug_panel.gd`内のローカル定数とする。

## Task Dependency Graph

```
001 (GameStateへのデバッグ支援API追加)
  └─ 002 (DebugPanelシーン/スクリプトの実装)
       └─ 003 (MainSceneへのDebugPanel組み込み)
            └─ 004 (手動プレイテスト手順書の作成)
```

直列依存（並行実施の余地は小さい）。

## Cross-Plan Dependencies

なし。既存の`pixel-art-remaining-screens`等の完了済みPlanとは独立。
