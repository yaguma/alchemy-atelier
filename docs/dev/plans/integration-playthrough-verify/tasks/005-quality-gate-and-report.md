---
id: "005"
title: "全体通し実行・静的解析・フォーマットチェックを行い検証レポートをまとめる"
status: pending
priority: 3
dependencies: ["004"]
estimated_complexity: low
---

# Task: 全体通し実行・静的解析・フォーマットチェックを行い検証レポートをまとめる

## Goal

`test_main_scene_full_loop_playthrough.gd`を含む全GdUnit4テストスイート・gdlint・gdformat --checkを実行して品質ゲートを通過させ、`docs/dev/plans/integration-playthrough-verify/reports/verify-<日付>.md`に結果と発見事項（あれば）を記録する。

## Interfaces

（コード変更なし。検証コマンドの実行とレポート作成のみ）

## Test Strategy

- [ ] `cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/unit/features/integration-playthrough-verify` は存在しないため、`-a res://tests/integration/test_main_scene_full_loop_playthrough.gd`単体実行がPASSすること
- [ ] `cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/`（全件、`-c`オプション併用）が既存テストを含めてPASSすること（新規テストが既存のGameState状態を汚染していないことの確認）
- [ ] `gdlint atelier/features/ atelier/shared/ atelier/autoload/ atelier/tests/`相当（対象ディレクトリはプロジェクトの`.gdlintrc`設定に合わせる）で警告が出ないこと
- [ ] `gdformat --check`で新規ファイルのフォーマット崩れがないこと
- [ ] エッジケース: 新規テストがGdUnit4のfail-fast（デフォルト）で他の既存テストの実行を止めていないか、`-c`（continue）オプション付き全件実行でも確認する

## Implementation Notes

- 参照すべき既存コード: `docs/dev/plans/rank-up/reports/verify-2026-08-18.md`等、既存Planのverifyレポート形式を踏襲
- コマンドは`.claude/rules/bash-commands.md`・`.claude/rules/testing.md`の規約通り、GdUnit4実行のみ`atelier/`への`cd`必須
- レポートには「新規に見つかったギャップ・バグ（あれば）」を明記する。タスク004で本番コード側のRankState競合等が見つかった場合はここに結論をまとめる
- 注意事項: 本タスクはコード変更を行わない検証専用タスクのため、`estimated_complexity: low`

## Files

- 新規: `docs/dev/plans/integration-playthrough-verify/reports/verify-<実施日>.md`
