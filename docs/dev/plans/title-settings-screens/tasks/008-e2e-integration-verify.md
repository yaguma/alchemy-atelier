---
id: "008"
title: "起動〜設定操作の結合確認と既存回帰テストを検証する"
status: done
priority: 1
dependencies: ["006", "007"]
estimated_complexity: medium
---

# Task: 起動〜設定操作の結合確認と既存回帰テストを検証する

## Goal

`BootScene → TitleScreen → SlotSelectScreen → MainScene`という新しい起動フロー全体と、タイトル画面・ゲーム中の両方からの設定パネル開閉フローをGdUnit4のシーンテストで結合確認する。あわせて、既存の全テストスイート（`test_main_scene_*.gd`, `test_game_state_*.gd`, `test_boot_scene.gd`, `test_rank_hud.gd`等）がGreenのままであることを確認する。

## Interfaces

本タスクは新規インターフェースを追加しない。既存インターフェース（`TitleScreen`, `SettingsPanel`, `SettingsService`, `MainScene`, `BootScene`）を組み合わせた結合テストのみを実装する。

```gdscript
# atelier/tests/integration/test_title_settings_e2e.gd
extends GdUnitTestSuite
# 🔵 save-load Planのtask009（Boot/MainSceneへの結線・E2E結合）と同型の結合確認タスク
```

## Test Strategy

- [ ] `scene_runner("res://scenes/boot.tscn")`起動→遷移要求パスが`title_screen.tscn`であることを確認する
- [ ] `scene_runner("res://features/title/ui/title_screen.tscn")`起動→「はじめる」押下→遷移要求パスが`slot_select_screen.tscn`であることを確認する（`TitleScreen`単体では`SlotSelectScreen`以降には遷移しないため、ここまでの結合確認とする）
- [ ] `TitleScreen`起動→「せってい」押下→設定パネルで音量変更→閉じる→`user://settings.json`に変更値が保存されていることを確認する
- [ ] `scene_runner("res://scenes/main.tscn")`起動→`RankHud`の歯車ボタン押下→設定パネル表示→閉じる→`GameState.get_state().current_phase`が開く前と変わらないことを確認する
- [ ] 上記操作の一連の流れで`SaveService`のオートセーブ呼び出し回数が増加しないことを確認する（AC-011の結合レベル再確認）
- [ ] 既存テストスイート全体（`cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/ -c`）がすべてGreenであることを確認する（`-c`で継続実行し、fail-fastで見落とさないようにする）
- [ ] エッジケース: `test_main_scene_happy_path.gd`等、`main.tscn`を直接`scene_runner()`起動する既存テストが、本Planの`%SettingsOverlayLayer`追加後もノード解決エラーなく動作すること

## Implementation Notes

- 参照すべき既存コード: `atelier/tests/integration/test_main_scene_happy_path.gd`（`scene_runner()`を使った既存の結合テストパターン）、`docs/dev/plans/save-load/tasks/009-*.md`（相当するタスクがあれば参照。E2E結合の粒度感を揃える）
- `gdlint atelier/features/ atelier/shared/ atelier/autoload/`と`gdformat --check atelier/features/ atelier/shared/ atelier/autoload/`もあわせて実行し、Pass することを確認する（`.claude/rules/implement-workflow.md`のコミット前チェックリスト）
- 本タスクの実行前に、001〜007で作成したテストファイルは既にそれぞれのタスクの中でGreenになっている前提。本タスクは「機能横断の結合」と「既存機能への非破壊」の両方を確認する最終ゲート
- 注意事項: 実際のファイルI/O（`user://settings.json`）を伴うテストは、テスト前後で該当ファイルの状態が他のテストに影響しないよう`before_test()`/`after_test()`でのクリーンアップを検討する（`SettingsService.reset_for_test()`を活用する）

## Files

- 新規: `atelier/tests/integration/test_title_settings_e2e.gd`
- 変更: なし（既存ファイルの修正が必要になった場合はこのタスク内で対応し、`plan.md`に記録する）
- テスト: `atelier/tests/integration/test_title_settings_e2e.gd`
