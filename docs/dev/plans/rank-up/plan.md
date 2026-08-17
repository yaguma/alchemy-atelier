# Plan: rank-up

## Requirements Summary

「Atelier」（Godot 4.x + GDScript）のPhase 2機能実装として、`rank`plan（PR #20マージ済み）が明示的にスコープ外とした**昇格試験システム本体**を実装する。`TurnLimitResolver.resolve_rank_outcome`が`PROMOTION_ELIGIBLE`を返した後（制限ターン到達かつランクノルマ0）に発生する、庭なし・専用ノルマ・超短期ターンの一発勝負局面（昇格試験）の状態管理・結果確定（次ランクへの昇格 / 同ランク再挑戦 / ゲームクリア / ゲームオーバー）を実装する。

**スコープに含む**: `features/rank/logic/`（`PromotionExamResolver`/`ExamOutcome`/`RankProgression`）・`features/rank/state/`（`ExamState`）・`shared/constants/game_balance.gd`への`RANK_ORDER`定数追加・`GameState`統合（試験開始トリガー、`execute_alchemy()`/`deliver_pending_products()`への試験対応差分、`advance_exam_turn()`、`evaluate_exam_outcome()`/`commit_exam_outcome()`、成功時の実ランク遷移・ゲームクリア判定、失敗時の再挑戦・ゲームオーバー判定）。
**スコープに含まない**: `features/rank/ui/`・`PromotionExamScene`等のUI一式・アニメーション演出・エラーメッセージ文言（別task）、`res://data/ranks/*.tres`実データ作成（別plan、コンテンツ作成）、`exam_turn_limit`/`exam_difficulty_coefficient`の具体的バランス数値確定（既存`RankMaster`フィールドをそのまま使い🟡TBDのまま追跡継続）、`atelier/autoload/game_state.gd`の500行超過リファクタリング（rank plan踏襲で今回も受容し、別Issueとして起票する）。

詳細: [requirements.md](requirements.md)（FR30件+NFR4件+CON8件、全件🔵/🟡、赤信号はヒアリングで解消済み） | [user-stories.md](user-stories.md)（US-001〜US-205） | [acceptance-criteria.md](acceptance-criteria.md)（AC-001〜AC-020）

## Design Overview

既存の確定設計（`docs/design/atelier-alchemy-core/core-systems.md` RankSystem節L273-374、`data-schema.md` `exam_state`節・RankMaster節）を正としてインターフェースを踏襲した。設計フェーズで新規決定した方針（全件ユーザー確認済み）:

- **`RankProgression`を`features/rank/logic/`に単独配置**: `GameBalance.RANK_ORDER`上のindex+1参照で次ランクIDを決定する`get_next_rank_id(current_rank_id) -> StringName`。次ランクなし（`RANK_ORDER`末尾）は空文字列`&""`で表現し、これをもってゲームクリア判定とする（`RankMaster`への`is_final_rank`等の明示フラグは追加しない）
- **`ExamState`は`RankMaster`を知らない自己完結型**: `start_exam()`時点で計算済みの`exam_quota_max`を自身のフィールドとして保持し、試験中に`RankMaster`を再参照しない（`RankState`が都度`RankMaster`を参照する設計とは異なる）
- **試験ノルマ・同ランクリセット・次ランク初期化はすべて`RankQuotaResolver.apply_contribution`/`reset_for_retry`（既存rank plan資産）を流用**: 新規Domainロジックを追加しない。「ノルマの入れ物が`RankState`か`ExamState`か」「リセット対象が同ランクか次ランクか」の違いのみ
- **`_rank_state_initialized`フラグの本番セット経路を本plan（`commit_exam_outcome()`のSUCCESS分岐）で初めて実装**: 既存フラグは`game_state_test_support.gd`経由でしか`true`にならない既知のギャップだったが、本plan外（ゲーム開始フローの初期化）の課題とは明示的に切り分ける
- **`start_exam`のnull/`limit_turn<=0`ガードと`GameState._start_exam()`側のガードは意図的な二重構造**: `PromotionExamResolver`単体でも安全な防御的プログラミングとして両方残す（ユーザー確認済み）
- **試験開始トリガーの二重開始防止（FR-201）は`GameState`側の`not _in_exam`ガードで保証**: `PromotionExamResolver.start_exam`自体は副作用のない純粋関数のため、呼び出し側の代入をガードする

### レイヤー構成

```
Presentation層  features/rank/ui/              対象外（本plan外、CON-002）
       ↓ (未実装。UI plan側でexam_started/exam_outcome_confirmed購読を行う想定)
Application層   autoload/game_state.gd         evaluate_exam_outcome, commit_exam_outcome,
                                                advance_exam_turn, _start_exam（内部）
       ↓ (static call)
Domain層        features/rank/logic/          PromotionExamResolver, RankProgression,
                                                ExamOutcome（副作用なし）
                                                + 既存RankQuotaResolver（流用）
       ↓ (読み取り/生成)
Infrastructure層 features/rank/state/          ExamState（GameStateのみ参照）
                features/rank/resources/       RankMaster（既存、変更なし）
                shared/constants/game_balance.gd（RANK_ORDER追記）
```

## Task Dependency Graph

トポロジカル順（001が最も基盤、番号順に実行すればすべての依存が解決済みになる）:

```
001 ExamOutcome enum / 002 ExamState型 / 003 GameBalance.RANK_ORDER  （並行可）
003     └→ 004 RankProgression [dep: 003]
001,002 └→ 005 PromotionExamResolver [dep: 001,002]
001,002 └→ 006 GameState試験基盤（フィールド・シグナル・get_state()・テストAPI） [dep: 001,002]
005,006 └→ 007 GameState試験開始トリガー（commit_rank_outcome統合） [dep: 005,006]
005,006 └→ 008 GameState execute_alchemy試験ターン消費 [dep: 005,006]
006     └→ 009 GameState deliver_pending_products試験分岐 [dep: 006]
005,006 └→ 010 GameState advance_exam_turn [dep: 005,006]
004,006 └→ 011 GameState試験結果評価・確定（成功/失敗/ゲームクリア/ゲームオーバー） [dep: 004,006]
```

実行順序の目安: **001〜003（並行可）→ 004〜006（並行可、006は001・002に依存）→ 007〜010（並行可、いずれも005・006または006に依存）→ 011**

### ⚠️ 前提条件

**本planは`rank` plan（PR #20マージ済み）の実装完了を前提とする。** `RankQuotaResolver`・`TurnLimitResolver`・`RankOutcome`・`RankMaster`（`exam_turn_limit`/`exam_difficulty_coefficient`フィールド含む）・`RankState`・`GameState`のランク基盤（`_current_rank_id`/`_rank_state`/`_demotion_count`/`_rank_masters`/`_rank_state_initialized`/`evaluate_rank_outcome`/`commit_rank_outcome`/`is_game_over`/`rank_outcome_confirmed`/`game_over`）はすべて実装済み（既にマージ済みのため着手ブロッカーなし）。

## Cross-Plan Dependencies

- **`GameState._rank_state_initialized`（本番セット経路を新設）**: rank planが導入したフラグは`game_state_test_support.gd`経由でしか`true`にならない既知のギャップだった。本planのタスク011（`_commit_exam_success()`）が唯一の本番コード経路としてこれを`true`にする。初回（Gランク）の初期化タイミングは本plan外（ゲーム開始/初期化フロー、未着手）の課題として明示的に切り分ける
- **`GameState._current_rank_id`・`_rank_state`・`_demotion_count`（rank planが型・初期値契約のみ確定させたフィールド）**: 本planのタスク011が、これらを実際に変更する初めての経路（昇格試験成功/失敗時の更新ロジック）を実装する
- **`GameBalance.RANK_ORDER`（新設）**: 将来のコンテンツ作成plan（`res://data/ranks/*.tres`実データ作成）が、この定数の順序と矛盾しないランクIDを持つ`.tres`ファイルを作成する必要がある
- **`exam_started`・`exam_outcome_confirmed`シグナル（新設、MAY要件）**: 別task・別plan（UI実装）がこれらを購読する想定。既存の`rank_outcome_confirmed`・`game_over`と対称なパターン
- **`MainScene`統合・`PromotionExamScene` UI**: 本plan外。別task・別planで行う
- **`atelier/autoload/game_state.gd`の500行超過**: 本plan完了時点でさらに行数が増加する見込み。rank plan検証レポートの推奨（分割検討）を再度受容し、独立したリファクタリングIssueとして起票することを次plan着手前に検討する
