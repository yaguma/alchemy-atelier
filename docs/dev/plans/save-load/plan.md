# Plan: save-load

## Requirements Summary

セーブ/ロード機能を新規追加する（`CLAUDE.md`はこれまで「セーブ/ロード機能は設計スコープ外」と明記していたが、本Planでスコープに含める）。

確定要件（ヒアリング済み）:

- **保存対象スコープ**: `GameState`が保持する全ランタイム状態（ゴールド・在庫・庭の状態・調合待ちキュー・ギルド納品の指定依頼・ランク進行状況・昇格試験状況・工房強化購入状況・現在フェーズ・ターン数）。マスターデータ（素材・レシピ・ランク・工房強化・日替わり依頼の`.tres`定義）自体は保存しない（起動時に`load_*_master_data()`で毎回再ロードする前提のため）。
- **保存スロット数**: 固定3スロット。複数プレイスルーを想定し、各スロットは独立した進行状況を持つ。
- **保存トリガー**: オートセーブのみ（手動保存UIは対象外）。`GameState.set_phase()`によるフェーズ遷移の瞬間ごとに自動保存する。フェーズ内の細かい進行（例: 調合投入中の一時状態）はセーブ対象外という前提を明示的に許容する。
- **周辺UI**: タイトル画面自体は引き続きスコープ外だが、3スロットから選ぶための最小限のスロット選択画面（起動シーケンスの一部として`BootScene`と`MainScene`の間に追加）は本Planの対象に含める。

## Design Overview

詳細インターフェースは各タスクファイル（`tasks/00N-*.md`）の `## Interfaces` を参照。要点のみ記す。

### モジュール配置

- `atelier/features/save_load/` を新規Featureとして追加する（既存5機能と同じ`logic/`・`state/`・`ui/`構成）。
  - `logic/save_data_codec.gd` — チェックサム計算・検証（Functional Core、副作用なし、`.claude/rules/security.md`の`calculate_checksum()`/`load_save_data()`方針をそのまま具体化）
  - `state/save_slot_summary.gd` — スロット選択UI用の要約データ型
  - `ui/slot_select_screen.tscn`/`.gd` — スロット選択画面
- `atelier/autoload/save_service.gd` — 新規Autoload。ファイルI/O（`user://saves/slot_{n}.json`）とスロット管理を担う（Imperative Shell）。project.godotへのAutoload登録が必要。
- `atelier/autoload/game_state_save_delegate.gd` — 既存の`game_state_{garden,alchemy,guild,rank,workshop}_delegate.gd`と同型の委譲ヘルパー。`GameState`の全private fieldへ直接アクセスし、保存用Dictionaryへの変換（`collect_save_data`）とその逆変換（`restore_save_data`）を行う。GameStateはセーブ/ロード専用のFeatureに属さない横断的な存在のため、既存delegate群と同じ`autoload/`直下に置く（🟡 既存命名パターン踏襲）。

### 既存コードへの統合ポイント（変更は最小限に留める設計）

1. **`GameState.set_phase()`** に1行追記し、フェーズが実際に変わった時のみ`SaveService.autosave()`を呼ぶ（`previous != next`ガード）。`active_slot`未設定（既定値`-1`、テスト環境はこのまま）の場合`autosave()`は即return、ファイルI/Oを一切行わない。**既存のGdUnit4テスト群（`GameState.set_phase()`を多用）に副作用を与えない**ことをタスク008で回帰確認する。
2. **`BootScene`** の遷移先を`res://scenes/main.tscn`から`res://features/save_load/ui/slot_select_screen.tscn`に変更する。
3. **`MainScene._enter_tree()`** の末尾（既存の5本の`load_*_master_data()`呼び出しの直後）に`SaveService.apply_pending_restore()`を1行追加する。

### マスターデータ参照解決の順序問題と対策（🟡 設計上の重要判断）

セーブデータ中の`current_daily_order`等はマスターデータ（`DailyOrderMaster`）への参照だが、マスターデータのロードは`MainScene._enter_tree()`で行われる一方、スロット選択はそれより前（`BootScene`後、`MainScene`遷移前）に発生する。この順序不整合を避けるため、**復元を2段階に分離**する:

1. `SlotSelectScreen`でのスロット確定時（`SaveService.select_slot_and_restore()`）は、セーブファイルの読込・検証のみを行い、検証済みDictionaryを`SaveService`内部に一時保持する（`GameState`はまだ一切変更しない）。
2. `MainScene._enter_tree()`がマスターデータをロードし終えた直後に`SaveService.apply_pending_restore()`を呼び、保持しておいたDictionaryを`GameStateSaveDelegate.restore_save_data()`経由で初めて`GameState`へ適用する。

この設計により、既存の`test_main_scene_*.gd`群（`main.tscn`を`scene_runner()`で直接起動し`BootScene`を経由しない）への影響を「末尾1行追加」だけに抑えられる。

### 新規開始（空スロット選択時）の扱い

`GameState`のAutoload初期フィールド値は、フィールド宣言時点のデフォルト値がそのまま「新規ゲームの初期状態」として機能する（`reset_for_test()`が設定する値とほぼ同一。唯一`_seed_inventory`の初期値がテスト専用リセットと素のAutoload起動時で異なる既知の差異があるが、これは本Plan由来の問題ではなく既存の挙動であり対象外とする）。そのため空スロット選択時は`SaveService`側で明示的なリセット処理を行わず、`_pending_restore`を空Dictionaryのまま保持することで「何もしない＝今日の`main.tscn`直接起動と同じ初期状態」を実現する。

## Task Dependency Graph

```
001 (SaveDataCodec: checksum/wrap)
  └─→ 002 (SaveDataCodec: validate_and_unwrap) ──┐
                                                   │
003 (GameStateSaveDelegate: collect_save_data)    │  [001/002と並行実施可]
  └─→ 004 (GameStateSaveDelegate: restore_save_data)
                                                   │
        002 ───────────────┬───────────────────────┘
                            └─→ 005 (SaveService: スロットファイルI/O)
                                  └─→ 006 (SaveService: active_slot/pending_restore)
                                        ├─→ 007 (GameState.set_phase()オートセーブフック)
                                        └─→ 008 (SlotSelectScreen UI)
                                              007, 008 ─→ 009 (Boot/MainSceneへの結線・E2E結合)
```

トポロジカル順: (001, 003 並行) → 002, 004 → 005 → 006 → (007, 008 並行可) → 009

## Cross-Plan Dependencies

既存Plan（garden/alchemy/guild/rank/workshop/rank-up/atelier-alchemy-core）とのインターフェース衝突なし。ただし以下のファイルへの変更が既存Planの実装物と交差する:

- `atelier/autoload/game_state.gd`（`set_phase()`への1行追記）
- `atelier/scenes/boot.gd`（遷移先変更）
- `atelier/scenes/main.gd`（`_enter_tree()`末尾への1行追記）
- `atelier/project.godot`（Autoload登録追加）

既存の統合テスト（`test_main_scene_*.gd`, `test_game_state_*.gd`多数）が引き続きGreenであることをタスク007・009で回帰確認する。
