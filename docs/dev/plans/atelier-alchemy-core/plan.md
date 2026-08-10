# Plan: atelier-alchemy-core（Phase 1: 基盤構築）

## Requirements Summary

「Atelier」プロジェクト（Godot 4.7 + GDScript）の実装における最初のPlan。`atelier/` プロジェクトのスキャフォールディング、`GameState`/`RngService` Autoloadの最小骨組み、日本語（CJK）フォント対応、`BootScene`→`MainScene`の起動フロー、GUT/gdlint/gdformatによる品質チェック基盤を整備する。庭・調合・ギルド納品・工房強化・ランク進行の各Feature実装は本Planのスコープ外（後日、別plan-nameでdev-planする）。

詳細: [requirements.md](requirements.md) | [user-stories.md](user-stories.md) | [acceptance-criteria.md](acceptance-criteria.md)

## Design Overview

Plan サブエージェントによるインターフェースファースト設計に基づく（詳細は各タスクファイルの `## Interfaces` 参照）。

- **ディレクトリ構造**: `docs/design/atelier-alchemy-core/architecture.md`「ディレクトリ構造（案）」+ FR-001の直積解釈（`workshop/state/`含む全5機能×4サブディレクトリを作成、ユーザー確認済み）
- **GameState Autoload**: 最小フィールド（`_current_phase`, `_gold`, `_current_turn`。初期値はそれぞれ `&"garden"` / `0` / `1`）+ `get_state()`（`duplicate(true)`によるディープコピー必須）+ `set_phase()` + `phase_changed` signal + `reset_for_test()`（デバッグビルド限定）。個別Feature用フィールド・メソッドはこのPlanでは実装しない（CON-004）
- **RngService Autoload**: `RandomNumberGenerator`のラップ。`set_seed()`, `randf()`, `randf_range()`, `randi_range()`
- **UiTheme + フォント**: Noto Sans JP（SIL OFL 1.1）を `res://assets/fonts/` に配置し、`res://shared/theme/main_theme.tres` の `default_font` に適用。Project Settingsのプロジェクト全体テーマとして設定 + `boot.gd`側でも明示的に再適用（テスト可能性のため冗長化）
- **MasterDataLoader**: `res://shared/loaders/master_data_loader.gd`（ユーザー確認済み。将来複数ローダーが増える見込みのため`loaders/`サブディレクトリを新設）。`validate_references(materials: Array) -> bool` は本Planではスタブ（常にtrue）
- **BootScene**: `_ready()`でフォント適用 → `MasterDataLoader.validate_references([])`呼び出し → `scenes/main.tscn`へ遷移。日本語仮ラベルで目視確認可能にする
- **MainScene**: 空の`Control`のみ（スクリプト非アタッチ）のプレースホルダ

## Task Dependency Graph

task-breakdownの検証結果（トポロジカル順）をそのまま反映。

```
001 (ディレクトリスキャフォールディング + project.godot作成)
  ├─→ 002 (GameState Autoload)         ─┐
  ├─→ 003 (RngService Autoload)        ─┤→ 009 (GameState/RngService統合テスト) ─┐
  ├─→ 004 (UiTheme・日本語フォント)     ─┐                                        │
  ├─→ 005 (MasterDataLoaderスタブ)      ─┤→ 007 (BootScene)  ─────────────────────┤→ 010 (コミット前品質ゲート確認)
  ├─→ 006 (MainSceneプレースホルダ)     ─┘                                        │
  └─→ 008 (GUTアドオン導入)            ─────────────────────────────────────────┘
```

- 002, 003, 004, 005, 006, 008 は 001 完了後に並行実装可能
- 007（BootScene）は 004・005・006 の完了が前提
- 009（統合テスト）は 002・003・008（GUT本体）の完了が前提
- 010（最終品質ゲート）は 007・009 の完了が前提

## Cross-Plan Dependencies

本Planは今後作成される各Feature Plan（庭/調合/ギルド納品/工房強化/ランク進行）の**前提**となる。後続Planは以下を再利用する:

- `autoload/game_state.gd`（`get_state()` / `set_phase()` / `phase_changed` / `reset_for_test()`）— 後続Planでフィールド・メソッドを追加していく
- `autoload/rng_service.gd`（乱数払い出しAPI）
- `shared/theme/theme.gd`（`UiTheme`）
- `shared/loaders/master_data_loader.gd`（`validate_references()`の実装を後続Planで肉付けする）
- ディレクトリ構造一式（`features/{feature}/{logic,state,resources,ui}/`）

後続Planの`dev-plan`実行時は、本Planの`plan.md`と各タスクファイルをコンテキストとして参照すること。
