# Plan: rank

## Requirements Summary

「Atelier」（Godot 4.x + GDScript）のPhase 2機能実装として、RankSystem（ランク進行）のうち**通常ランク進行**部分を実装する。庭（garden）・調合（alchemy）・ギルド納品（guild）は既にDomain層・GameState統合まで設計/実装が完了しており（guildはドキュメントのみ、コード実装は未着手。下記「前提条件」参照）、本planでは「納品で得た貢献度がランクノルマを削り、制限ターン到達時に昇格試験へ進める状態（`PROMOTION_ELIGIBLE`）または同一ランクでの再挑戦（`DEMOTION`）が確定する」までの一連の判定・状態管理を実装する。

**スコープに含む**: `features/rank/logic/`（`RankQuotaResolver`/`TurnLimitResolver`/`RankOutcome`）・`features/rank/resources/`（`RankMaster`）・`features/rank/state/`（`RankState`）・`shared/constants/game_balance.gd`への定数追加・`GameState`統合（`_accumulated_contribution`をノルマ消費へ置き換え、`_traits_unlocked`をランク由来へ置き換え、降格回数管理・ゲームオーバー判定、`evaluate_rank_outcome`/`commit_rank_outcome`クエリ・確定メソッド新設）。
**スコープに含まない**: `PromotionExamResolver`・`ExamState`・`ExamOutcome`（昇格試験本体、別plan「promotion-exam」）、昇格成功時の実ランク遷移（別plan「promotion-exam」）、`res://data/ranks/*.tres`実データ作成（別plan、コンテンツ作成）、`GameState.advance_turn()`相当のターン進行メソッド新設（別plan、ターンサイクル設計）、`features/rank/ui/`（別task）。

詳細: [requirements.md](requirements.md)（FR36件+NFR8件+CON12件、🔵38/🟡10/🔴8、全件承認済み） | [user-stories.md](user-stories.md) | [acceptance-criteria.md](acceptance-criteria.md)（AC-001〜017）

## Design Overview

既存の確定設計（`docs/design/atelier-alchemy-core/core-systems.md` RankSystem節、`data-schema.md` `rank_state`・RankMaster節）を正としてインターフェースを踏襲した。設計フェーズで判明した実装ギャップは、ヒアリングでユーザー確認済みの方針（赤信号8件は全件承認済み）に従う:

- **`RankOutcome`を`features/rank/logic/`に単独配置**: `TurnLimitResolver`（同一Featureの`logic/`）と`GameState`（Application層）の両方から参照する必要があり、`state/`（`GameState`専用）には置けないため（CON-003）
- **ランク結果APIを`evaluate_rank_outcome()`（副作用なし）と`commit_rank_outcome()`（副作用あり）に分離**: UIの先読み表示用途と実際の降格確定用途でライフサイクルが異なるため（CON-009。`.claude/rules/architecture.md`「検証責務のレイヤー配置原則」に準拠）
- **ランクマスター欠落時のフォールバック**: `_rank_masters`に該当IDが無い場合、`traits_unlocked=false`（安全側）・`quota_max=0.0`・`limit_turn=0`を返し`push_error()`で報告する（CON-008）
- **既存暫定フィールドの撤去**: guild planが設けた`_accumulated_contribution`（guild CON-004）とalchemy planが設けた`_traits_unlocked`（alchemy CON-007）を、本planが正式な権威（`RankQuotaResolver`によるノルマ消費・現在ランクの`RankMaster.traits_unlocked`）へ置き換えて削除する。既存テスト専用API`_set_traits_unlocked_for_test()`も削除し、`_set_rank_masters_for_test`+`_set_current_rank_id_for_test`によるランク注入経由に一本化する（CON-005）
- **`RankState`は`RankMaster`を知らない**: 生成・初期化は`RankQuotaResolver.reset_for_retry`または`GameState`が担う独立した型とする

### レイヤー構成

```
Presentation層  features/rank/ui/              対象外（本plan外、FR-407）
       ↓ (未実装。UI plan側でrank_outcome_confirmed/game_over購読を行う想定)
Application層   autoload/game_state.gd         evaluate_rank_outcome, commit_rank_outcome, is_game_over
       ↓ (static call)
Domain層        features/rank/logic/          RankQuotaResolver, TurnLimitResolver, RankOutcome（副作用なし）
       ↓ (読み取り/生成)
Infrastructure層 features/rank/resources/      RankMaster
                features/rank/state/           RankState（GameStateのみ参照、FR-409）
                shared/entities/               Result（既存、変更なし）
                shared/constants/game_balance.gd（MAX_DEMOTION_COUNT, INITIAL_RANK_ID追記）
```

## Task Dependency Graph

トポロジカル順（001が最も基盤、番号順に実行すればすべての依存が解決済みになる）:

```
001 RankOutcome enum / 002 RankMaster型 / 003 GameBalanceランク定数 / 004 RankState型  （並行可）
002,004 └→ 005 RankQuotaResolver [dep: 002,004]
001     └→ 006 TurnLimitResolver [dep: 001]
002,003,004 └→ 007 GameState rank基盤（フィールド・traits_unlocked置換・テストAPI） [dep: 002,003,004]
005,006,007 └→ 008 GameState.evaluate_rank_outcome/commit_rank_outcome + 納品統合 [dep: 005,006,007]
```

実行順序の目安: **001〜004（並行可）→ 005〜007（並行可、007は002・003・004に依存）→ 008**

### ⚠️ 前提条件（CON-010）

**本planは`guild` planのコード実装完了を前提とする。** 本plan着手時点（2026-08-16）で`atelier/features/guild/`は空であり、`docs/dev/plans/guild/`はドキュメント（要件定義・タスク分解）のみ生成済みでコード実装は未着手。タスク008（`GameState.evaluate_rank_outcome`等）は`GameState.deliver_pending_products()`の既存実装（guild plan tasks/006）を変更する内容を含むため、**guild planのタスク001〜006が実装・マージされた後に着手すること**。タスク001〜007はguild実装の有無によらず着手可能（007はalchemy planの既存コード`_traits_unlocked`にのみ依存）。

## Cross-Plan Dependencies

- **`GameState._accumulated_contribution`（消費・削除）**: guild planが暫定的に設けたフィールドを、本planのタスク008が`RankQuotaResolver.apply_contribution`による`_rank_state.quota`更新へ完全に置き換えて削除する。guild planのAC-010相当のテストは本planのAC-009向けに書き換える
- **`GameState._traits_unlocked`（消費・削除）**: alchemy planが暫定的に設けたフィールドを、本planのタスク007が現在ランクの`RankMaster.traits_unlocked`へ置き換えて削除する。alchemy planのAC-011相当のテスト（`_set_traits_unlocked_for_test()`使用箇所）は本planでランク注入経由へ更新する
- **`GameState._current_rank_id`・`_rank_state`・`_demotion_count`（新設）**: 後続のpromotion-exam planが、昇格試験成功時に`_current_rank_id`を次ランクへ進める処理と`reset_demotion_count_on_promotion()`相当のAPI呼び出しを行う想定。本planはこれらのフィールドの型・初期値契約のみを確定させる
- **`features/rank/logic/rank_outcome.gd`（`RankOutcome`）**: 本plan内で新規作成する。promotion-exam planが`PromotionExamResolver.resolve_outcome`の`ExamOutcome`とは別の型として、通常ループの結果判定に本型を参照する可能性がある
- **`shared/constants/game_balance.gd`**: 本plan（タスク003）でランク関連定数のみ追記する。他Feature（garden/alchemy/guild）の既存定数は変更しない
- **`MainScene`統合・RankScreen/GameOverScreen UI**: 本plan外。別task・別planで行う
