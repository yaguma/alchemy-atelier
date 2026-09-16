---
id: "008"
title: "全体の回帰確認（gdlint/gdformat/GdUnit4全件、コミット済み確認を含む）を実施する"
status: done
priority: 5
dependencies: ["001", "002", "003", "004", "005", "006", "007"]
estimated_complexity: low
---

# Task: 全体の回帰確認（gdlint/gdformat/GdUnit4全件、コミット済み確認を含む）を実施する

## Goal

001〜007の実装がすべて完了した後、プロジェクトの品質ゲート（GdUnit4全件・gdlint・gdformat --check）を通過することを確認する。加えて、本Planの発端となった`screen-design-update`の「計画書は完了扱いだが実コードが存在しない」という事故を繰り返さないよう、**実際に新規ファイルがワーキングツリー上に存在し、`git status`で変更として認識されること**を明示的に確認する。

## Interfaces

コード上のインターフェースはない（検証タスク）。

## Test Strategy

- [ ] `cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/ -c`が0エラー・0失敗で完了する
- [ ] `gdlint atelier/features/ atelier/shared/ atelier/autoload/`が本Plan変更ファイルに関して警告0件（既存の`game_state.gd`等の無関係な既存警告は許容し、新規リグレッションでないことをgit blame/git logで確認する）
- [ ] `gdformat --check atelier/features/ atelier/shared/ atelier/autoload/`がフォーマット崩れなしを報告する
- [ ] `git status`で`ui_panel_stylebox.gd`, `theme.gd`（変更）, `button_style_applier.gd`, `title_backdrop.gd`/`.tscn`, `title_emblem.png`, `title_screen.gd`/`.tscn`（変更）, `screens/title.md`が全て「変更あり」として検出される（＝本当にファイルが作られたことの物理的確認）
- [ ] Godotエディタでの手動プレイ確認（`.claude/rules/godot-debug-tools.md`参照）で、タイトル画面がダーク背景・青紫系を使わず表示され、4ボタンがクリック可能であることを目視確認する（`--headless`実行ではスクリーンショットが撮れないため、実施できない場合はその旨を明言する）

## Implementation Notes

- 参照すべき既存コード: `docs/dev/plans/screen-design-update/reports/verify-2026-09-12.md`（同種の検証レポートのフォーマット参考。ただし当該レポート自体が実コード不在のまま「全PASS」と記録した反面教師でもあるため、本タスクでは**実際にコマンドを実行した生ログ**を報告書に残すこと）
- 実装のヒント: 検証結果は`docs/dev/plans/title-screen-design/reports/verify-<実施日>.md`に、実行コマンドと実際の出力を伴って記録する
- 注意事項: テスト・lint・formatの実行結果は必ず実際のコマンド出力を貼り付け、要約のみで済ませない（今回の教訓を踏まえた念押し）

## Files

- 新規: `docs/dev/plans/title-screen-design/reports/verify-<実施日>.md`
