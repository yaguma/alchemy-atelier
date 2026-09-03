# Plan: title-settings-screens

## Requirements Summary

これまで「未実装・設計スコープ外」だったタイトル画面・設定画面を新規に追加する。詳細: [requirements.md](requirements.md) | [user-stories.md](user-stories.md) | [acceptance-criteria.md](acceptance-criteria.md)

現在の起動フロー `BootScene → SlotSelectScreen（新規/つづき統合選択）→ MainScene` の手前に、新規Feature `features/title/` の`TitleScreen`（「はじめる」「せってい」の2項目メニューのみ）を追加する。「せってい」からは新規Feature `features/settings/` の`SettingsPanel`（BGM/SE音量・ウィンドウモード・演出簡略化フラグ）をオーバーレイ表示し、この`SettingsPanel`は`RankHud`の歯車ボタンからゲームプレイ中にも共通コンポーネントとして呼び出せる。設定値は新規Autoload`SettingsService`が`user://settings.json`（全セーブスロット共通のグローバル設定ファイル）として管理し、`GameState`・`SaveService`には一切影響を与えない独立した仕組みとする。

2026-09-03のヒアリングで以下を確定済み（要件ドキュメントの赤信号はすべて解消済み）:
- Escapeキーでの設定パネルクローズに対応する
- 「せってい」ボタン/歯車ボタンの多重起動は既存インスタンスがあれば無視する
- 画面モード変更失敗時は`push_warning()`のみでUIエラー表示は行わない

## Design Overview

詳細インターフェースは各タスクファイル（`tasks/00N-*.md`）の`## Interfaces`を参照。要点のみ記す。

### モジュール配置

```
atelier/features/title/
└── ui/title_screen.tscn + .gd

atelier/features/settings/
├── logic/settings_codec.gd       # Functional Core。JSON化・パース・型検証（チェックサムなし）
├── state/settings_data.gd        # BGM/SE音量・ウィンドウモード・演出簡略化フラグ
└── ui/settings_panel.tscn + .gd  # TitleScreenとRankHudの両方から共通コンポーネントとして利用

atelier/autoload/settings_service.gd  # 新規Autoload。user://settings.jsonのファイルI/O、
                                        # AudioServerバス音量・DisplayServerウィンドウモードへの即時反映
```

### 既存コードへの統合ポイント（変更は最小限に留める設計）

1. **`BootScene`**（`atelier/scenes/boot.gd`）の遷移先を`slot_select_screen.tscn`から`title_screen.tscn`に変更する（タスク007）。
2. **`RankHud`**（`atelier/shared/ui/rank_hud.gd`/`.tscn`）に歯車ボタンを追加し、押下時は`settings_requested`シグナルを発行するのみに留める（タスク005）。`RankHud`は「GameStateの読み取りのみを行い状態変更・フェーズ遷移は一切行わない自己完結コンポーネント」という既存方針を維持し、`SettingsPanel`のインスタンス化は行わない。
3. **`MainScene`**（`atelier/scenes/main.gd`/`.tscn`）が`RankHud.settings_requested`を購読し、`SettingsPanel`を`%SettingsOverlayLayer`へ`add_child()`する（タスク006）。多重起動防止・`GameState`/`SaveService`への非干渉をこのタスクで保証する。
4. **`TitleScreen`**自身も同様の多重起動防止パターンで`SettingsPanel`をオーバーレイ表示する（タスク004）。

### 設計上の重要判断

- **`SettingsPanel`は独立オーバーレイとし、新フェーズとして`GameState.set_phase()`に乗せない**（要件FR-402/FR-403）。workshopのような新フェーズ方式は、フェーズ変更のたびに`SaveService.autosave()`が走る既存の仕組み（`GameState.set_phase()`のガード）と衝突するため採用しない。
- **`RankHud`はシグナル発行のみ、`add_child()`の実行はMainScene**。これにより既存の「RankHudは状態変更・フェーズ遷移を一切行わない自己完結コンポーネント」という設計方針（既存コードのコメントに明記済み）を壊さない。
- **音声再生システム・既存画面への演出（Tween）は現状プロジェクトに一切存在しない**ため、音量設定は`AudioServer`バス音量の制御まで、演出簡略化フラグは値の保持・取得APIの提供までをスコープとする（CON-004, CON-005）。将来これらを実装するPlanがこの土台を利用する前提。
- **`SettingsService`のAutoload登録はタスク002（Service実装）で前倒しして行う**（`project.godot`変更）。GdUnit4統合テストが`SettingsService`をAutoload経由でグローバル参照できるようにするため、既存の`SaveService`実装時と同様の順序とする。

## Task Dependency Graph

```
001 (SettingsData + SettingsCodec)
  └─→ 002 (SettingsService Autoload + project.godot登録)
        └─→ 003 (SettingsPanel UI)
              ├─→ 004 (TitleScreen UI) ──────────────┐
              └─→ 006 (MainScene統合) ←── 005 (RankHud歯車ボタン、001系列と独立に並行実施可)
                                              │
                              004, 002 ──────→ 007 (BootScene遷移先変更)
                                              │
                              006, 007 ──────→ 008 (E2E結合確認・既存回帰確認)
```

トポロジカル順: 001 → 002 → 003 → (004, 005 並行可) → 006 → 007 → 008
（005は001〜003と並行して着手可能。006は003と005の両方の完了を待つ）

## Cross-Plan Dependencies

既存Plan（garden/alchemy/guild/rank/workshop/rank-up/atelier-alchemy-core/save-load）とのインターフェース衝突なし。ただし以下の既存ファイルへの変更が既存実装物と交差する:

- `atelier/scenes/boot.gd`（遷移先変更。save-load Planのタスク009で一度変更済みの箇所を再変更）
- `atelier/scenes/main.gd` / `main.tscn`（`%SettingsOverlayLayer`追加、`RankHud.settings_requested`購読の追記）
- `atelier/shared/ui/rank_hud.gd` / `rank_hud.tscn`（歯車ボタン追加）
- `atelier/project.godot`（`SettingsService`のAutoload登録追加）

既存の統合テスト（`test_main_scene_*.gd`, `test_boot_scene.gd`, `test_rank_hud.gd`, `test_game_state_*.gd`多数）が引き続きGreenであることをタスク008で回帰確認する。`GameState`・`SaveService`本体のロジックには一切変更を加えない。
