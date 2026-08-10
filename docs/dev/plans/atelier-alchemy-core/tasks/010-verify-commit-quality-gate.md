---
id: "010"
title: "コミット前品質ゲート（GUT/gdlint/gdformat/日本語フォント）を確認する"
status: done
priority: 4
dependencies: ["007", "009"]
estimated_complexity: low
---

# Task: コミット前品質ゲート（GUT/gdlint/gdformat/日本語フォント）を確認する

> 🔴 2026-08-10実施結果: GUTがAssetLib経由で導入できなかったため、実際はGdUnit4で全テストを実行して確認した（`cd atelier && GODOT_BIN="/c/Godot/godot.exe" ./addons/gdUnit4/runtest.sh -a res://tests/`、9件全パス）。以下の`## Test Strategy`のGUT実行コマンドはヒアリング当時の計画として原文を残す。

## Goal

Phase 1基盤構築の完了条件（DoD）を一括で確認する。GdUnit4全テスト・gdlint・gdformatが全てパスし、日本語フォントが正しく描画されることを確認してPlan完了とした。

## Interfaces

このタスクはコード実装を伴わない検証タスク（Directモード）。

## Test Strategy

- [ ] `godot --headless --path atelier --import` が正常終了する（クリーンチェックアウト相当の確認、FR-106, AC-010）
- [ ] `godot --headless --path atelier -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit` を実行し、009で作成した全テストがパスする（FR-107, AC-011）
- [ ] `gdlint atelier/features/ atelier/shared/ atelier/autoload/` がエラーなく完了する（FR-108, AC-012）
- [ ] `gdformat --check atelier/features/ atelier/shared/ atelier/autoload/` がフォーマット崩れなく完了する（FR-109, AC-013）
- [ ] Godotエディタで`boot.tscn`を実行し、日本語仮ラベルが矩形/豆腐文字にならず表示され、`main.tscn`へ正常遷移する（NFR-201, AC-015）
- [ ] `GameState.get_state()`のディープコピー検証テスト（009）が実際にパスしていることを再確認する（FR-103の最終確認）

いずれか1つでも失敗した場合はコミットしない（`.claude/rules/implement-workflow.md`「コミット前の必須確認」）。

## Implementation Notes

- 参照すべき既存文書: `.claude/rules/pipeline-rules.md`「Step 1: 実装完了確認」、`.claude/rules/implement-workflow.md`「コミット前の必須確認」
- 本タスクはPhase1全体の完了確認であり、001〜009すべてが完了していることが前提
- 全てパスした後、`dev-verify` スキルまたは `commit-push-pr` スキルへ進む判断はこのPlanの範囲外（ユーザー判断）

## Files

- 新規: なし
- 変更: なし
- テスト: なし（既存テストの実行確認のみ）
