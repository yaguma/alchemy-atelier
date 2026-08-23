# Plan: rank-up-ui

## Requirements Summary

「Atelier」のPhase 2機能実装として、UI設計文書 [`docs/design/atelier-alchemy-core/ui-design/screens/promotion-exam.md`](../../../design/atelier-alchemy-core/ui-design/screens/promotion-exam.md) が定義する SCR-005「昇格試験画面」を実装する。先行する`rank`/`rank-up`/`rank-ui`各Planが一貫して「UI一式は別Plan」としてスコープ外にしてきた領域である。

コードベース調査の結果、`GuildDeliveryScreen`のノルマバー表示切替、`GameStateAlchemyDelegate.execute_alchemy()`の試験ターン自動消費、`GameStateRankDelegate`の試験開始/結果確定ロジック（`advance_exam_turn()`/`exam_started`/`exam_outcome_confirmed`）はすでに実装済みであることが判明した。そのため本Planは**新規シーンを作らず、既存`AlchemyScreen`（`features/alchemy/ui/alchemy_screen.gd`/`.tscn`）を試験モード対応に拡張する**方針を取る。

詳細: [requirements.md](requirements.md)（FR27件+NFR4件+CON7件、🔵23/🟡15/🔴0、赤信号はすべてユーザー確認済みで解消） | [user-stories.md](user-stories.md)（US-001〜US-603、🔵9/🟡7/🔴0） | [acceptance-criteria.md](acceptance-criteria.md)（AC-001〜AC-011、テスト43件、🔵6/🟡5/🔴0）

### 重要な既知の制約（CON-005）

`GameState.commit_rank_outcome()`/`commit_exam_outcome()`は本番コードのどこからも呼び出されておらず、実プレイでは`exam_started`/`exam_outcome_confirmed`シグナルが発火しない配線ギャップが存在する。ユーザー確認済みでこの配線トリガーの実装は本Planのスコープ外とし、統合テストでは`GameState`のシグナル直接emitまたは`commit_exam_outcome()`直接呼び出し（`test_game_state_exam_outcome.gd`と同型）で検証する。

## Design Overview

新規`PromotionExamScreen`シーンは作成せず、既存`AlchemyScreen`（290行）を拡張する。主な変更点:

1. **`.tscn`にノード3件を追加**: `%ExamTurnLabel`（残りターン表示）、`%ExamGuidanceLabel`（在庫0/解禁レシピ0時の案内）、`%AdvanceExamTurnButton`（試験ターンをクラフトせず消費）。いずれも`unique_name_in_owner=true`、初期`visible=false`。
2. **`_ready()`/`_exit_tree()`拡張**: `GameState.exam_started`/`exam_outcome_confirmed`を購読・解除（既存`product_crafted`等と同型）。
3. **`_refresh_exam_ui(state: Dictionary)`ヘルパー新設**: `_refresh()`末尾から呼び出し、残りターン表示・`%AdvanceExamTurnButton`/`%EndTurnButton`のvisible切替・案内メッセージ表示をまとめる。`GameState.get_state()`の追加呼び出しは行わない（NFR-001）。
4. **`remaining_exam_turns(exam_turn_limit, exam_elapsed_turn) -> int`（static）**: `maxi(limit - elapsed, 0)`でクランプ。
5. **`_on_product_crafted()`拡張**: `in_exam == true`の場合、既存の`_refresh()`/トースト表示に加えて`GameState.deliver_pending_products()`を自動呼び出しし`%GuildDeliveryScreen.display_results()`へ反映する（`_on_end_turn_pressed()`のスナップショットパターンを踏襲）。
6. **新規ハンドラ**: `_on_advance_exam_turn_pressed()`（`GameState.advance_exam_turn()`呼び出し→`_refresh()`）、`_on_exam_started()`（`_refresh()`＋開始トースト）、`_on_exam_outcome_confirmed(outcome: ExamOutcome.Value)`（`_refresh()`＋SUCCESS/FAILUREのみ結果トースト、CONTINUEは無言）。

変更不要（既存実装のまま）: `GuildDeliveryScreen._refresh_rank_quota()`、`GameStateRankDelegate`（`advance_exam_turn()`/`exam_started`/`exam_outcome_confirmed`実装済み）、`GameStateAlchemyDelegate.execute_alchemy()`（試験ターン自動消費実装済み）、`ResultScreen`。

### レイヤー構成

```
Presentation層  features/alchemy/ui/alchemy_screen.gd/.tscn   ← 本Planの変更対象
       ↓ signal購読（_ready/_exit_treeで接続/解除）
Application層   autoload/game_state.gd
               autoload/game_state_rank_delegate.gd（advance_exam_turn, exam_started, exam_outcome_confirmed。変更なし）
               autoload/game_state_guild_delegate.gd（deliver_pending_products。変更なし）
       ↓ 参照のみ
Domain層        features/rank/logic/exam_outcome.gd（ExamOutcome.Value型のみ参照）
```

### 既知のリスク（設計フェーズで新たに生じた実装判断、ゴール/スコープには影響しない）

- トースト・案内メッセージの日本語文言（`EXAM_MESSAGES`辞書、`EXAM_GUIDANCE_MESSAGE`）はdesign doc上もTBDのため、タスク実装時に妥当な文言として確定する（CON-003）
- `.tscn`新規ノードの配置順序（wireframeを参考にした目安）は機能的な正しさ（visible/text）にのみ依存し、順序自体を検証するACはない

## Task Dependency Graph

トポロジカル順（001が最も基盤、番号順に実行すればすべての依存が解決済みになる）:

```
001 シーン拡張とシグナル購読ライフサイクル基盤
       │
       ├─→ 002 残りターン表示とvisible切替
       │         │
       │         ├─→ 004 ターンを進めるボタンの挙動
       │         ├─→ 005 試験中自動納品
       │         └─→ 006 案内メッセージ（在庫0/解禁レシピ0）
       │
       └─→ 003 開始/結果確定トースト
```

実行順序の目安: **001 → 002・003（並行可、002を先に進めるのが自然） → 004・005・006（並行可、いずれも002に依存）**

## Cross-Plan Dependencies

- **CON-005（配線ギャップ）**: `GameState.commit_rank_outcome()`/`commit_exam_outcome()`を実プレイで呼び出すトリガー（ターン進行オーケストレーション）の実装は、本Plan完了後も未解決のまま残る。`MainScene`統合・ゲームループ配線を扱う将来Planが解消する想定（別Issue化を推奨）。
- **`atelier/scenes/main.tscn`への統合**: 本Planでは行わない（`alchemy-ui`/`rank-ui`Planと同じ境界線）。
- **`features/workshop/ui/`**: 未実装のまま。成功時の遷移先画面は将来Planのスコープ。
- **`features/rank/ui/result_screen.gd`**: 本Planの変更対象外（`rank-ui`Plan資産）。
