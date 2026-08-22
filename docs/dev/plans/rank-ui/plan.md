# Plan: rank-ui

## Requirements Summary

「Atelier」のUI設計文書 `docs/design/atelier-alchemy-core/ui-design/overview.md` が定義する **SCR-006「結果画面（ゲームクリア/ゲームオーバー）」** を新規実装する。現状`atelier/features/rank/ui/`は`.gitkeep`のみで完全未着手。ランク進行・昇格試験のドメインロジック（`RankQuotaResolver`/`TurnLimitResolver`/`RankOutcome`/`RankMaster`/`RankState`/`PromotionExamResolver`/`ExamOutcome`/`RankProgression`/`ExamState`、`autoload/game_state.gd`＋`autoload/game_state_rank_delegate.gd`）は先行Plan（rank・rank-up）で実装・マージ済み。

本Planには前提作業として重要な設計ギャップの解消を含む。現在、「Sランク（最終ランク）で昇格試験に成功した＝ゲームクリア」を明示的に区別するsignal/APIが存在しない。`game_state_rank_delegate.gd`の`_commit_exam_success()`は、次ランクが存在しない（真のゲームクリア）場合と、次ランクのRankMasterがマスターデータに未登録（エラー）の場合の両方で、`_current_rank_id`を変えずに早期returnするため、既存シグナルだけではこの2つを区別できない。本Planで新規シグナル`game_cleared`を追加し解消する。

**スコープに含む**: `GameState.game_cleared`シグナルの新設と`_commit_exam_success()`内の発行ロジック、`features/rank/ui/result_screen.gd`/`.tscn`（`ResultScreen`）の新規実装。
**スコープに含まない**: SCR-005昇格試験画面（PromotionExamScreen、別Plan）、`atelier/scenes/main.tscn`への統合（`current_phase`に応じた`visible`切替、別task・別Plan）、閉じる/次へ進むボタン等のインタラクション（タイトル・セーブロードが設計スコープ外のため実質的な終端画面とする）、統計情報表示（到達ランク・降格回数・所持ゴールド等）。

詳細: [requirements.md](requirements.md)（FR16件+NFR4件+CON7件、🔵23/🟡4/🔴0、全件承認済み） | [user-stories.md](user-stories.md)（US-001〜US-007） | [acceptance-criteria.md](acceptance-criteria.md)（AC-001〜AC-008、テスト24件）

## Design Overview

### 新規コンポーネント

- **`ResultScreen`**（`features/rank/ui/result_screen.gd`/`.tscn`）: 単一`Control`継承シーン。`GameState.game_over`・`GameState.game_cleared`を`_ready()`で自己購読し、`ResultKind`（`NONE`/`CLEAR`/`OVER`）の単一フィールドで排他的に表示を切替える。`%ResultMessageLabel`（`Label`）のテキストのみを書き換え、統計情報・ボタンは一切持たない。`_exit_tree()`で両シグナルを`disconnect()`する（`PhaseIndicator`/`GoldDisplay`と同型パターン）。テスト用ゲッター`get_result_kind() -> ResultKind`を提供する。

### GameStateの拡張

`atelier/autoload/game_state.gd`に新規シグナル`game_cleared`（引数なし）を追加する。既存`game_over(demotion_count: int)`と対称的な位置（19行目付近）に宣言する。

`atelier/autoload/game_state_rank_delegate.gd`の`_commit_exam_success()`内、`next_rank_id == &""`の真のゲームクリア分岐（161-163行目付近）からのみ`state.game_cleared.emit()`を発行する。次ランクのRankMaster欠落エラー分岐（166-169行目、`_warn_missing_next_rank_master()`）からは発行しない（既存の`push_error()`のみ維持）。

### データフロー

```
ゲームクリア経路:
GameState.commit_exam_outcome() → _commit_exam_success()
  next_rank_id == &"" → _in_exam=false → game_cleared.emit()
  → ResultScreen._on_game_cleared() → _result_kind=CLEAR → %ResultMessageLabel.text更新

ゲームオーバー経路（既存ロジック、変更なし）:
GameState.commit_rank_outcome()/commit_exam_outcome() → is_game_over()==true → game_over.emit(demotion_count)
  → ResultScreen._on_game_over() → _result_kind=OVER → %ResultMessageLabel.text更新
```

同一セッション内で両シグナルが発行された場合も、後着のハンドラが`_result_kind`を無条件上書きするため同時表示にはならない（FR-401, AC-005）。

### レイヤー構成

```
Presentation層  features/rank/ui/result_screen.gd/.tscn
       ↓ signal購読（connect/disconnect、_exit_tree()で解除必須）
Application層   autoload/game_state.gd（game_cleared宣言）
               autoload/game_state_rank_delegate.gd（_commit_exam_success()内で発行）
       ↓ static call（参照のみ、変更なし）
Domain層        features/rank/logic/rank_progression.gd（get_next_rank_id）
               features/rank/logic/promotion_exam_resolver.gd, exam_outcome.gd
```

CON-005（`features/rank/ui/`は他Featureの`state/`・`ui/`を直接参照しない）に準拠し、ResultScreenは`GameState`シグナルのみを参照する。

### 既存パターンの踏襲元

- `atelier/features/alchemy/ui/alchemy_screen.gd`: `_ready()`でのシグナル購読、`_exit_tree()`での`disconnect()`、テスト用ゲッターパターン
- `.claude/rules/state-management.md`・`.claude/rules/ui-components.md`: `PhaseIndicator`/`GoldDisplay`の「状態監視するコンポーネント」パターン

## Task Dependency Graph

```
[001 game-state-game-cleared-signal]
              |
              ▼
[002 result-screen-ui]
```

トポロジカル順: 001 → 002（線形依存。001が`game_cleared`シグナルを新設し、002がそれを購読する実装を含むため）

## Cross-Plan Dependencies

- **`GameState.game_cleared`（新設）**: 将来`MainScene`統合Plan（未着手）が、このシグナルおよび既存`game_over`を購読して画面遷移（`ResultScreen`の`visible`切替）を行う想定。本Planはシグナルの新設とResultScreen単体の実装のみを担う。
- **SCR-005昇格試験画面（PromotionExamScreen）**: 本Plan外。別Planのスコープ。
- **`atelier/scenes/main.tscn`**: 本Planでは変更しない（CON-004, FR-403, AC-007）。
- **`features/rank/logic/`・`features/rank/state/`（rank・rank-up Plan資産）**: すべて実装済みで本Planは変更しない。`RankProgression.get_next_rank_id()`を参照のみ行う。
