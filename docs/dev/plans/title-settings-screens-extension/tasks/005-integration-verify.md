---
id: "005"
title: "結合確認（全テスト・gdlint・gdformat）とverifyレポートを作成する"
status: done
priority: 5
dependencies: ["001", "002", "003", "004"]
estimated_complexity: low
---

# Task: 結合確認（全テスト・gdlint・gdformat）とverifyレポートを作成する

## Goal

E1〜E4の全変更を含めた状態で、GdUnit4全テスト・gdlint・gdformat --checkを実行し、すべてパスすることを確認する。結果を`docs/dev/plans/title-settings-screens-extension/reports/verify-<日付>.md`にまとめる。

## Interfaces

（検証タスクのためコード的インターフェースはなし）

## Test Strategy

- [ ] `cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/ -c`が0エラー・0失敗で完了する
- [ ] `gdlint atelier/features/ atelier/shared/ atelier/autoload/ atelier/scenes/`が"Success: no problems found"を返す
- [ ] `gdformat --check atelier/features/ atelier/shared/ atelier/autoload/ atelier/scenes/`が差分なしを返す
- [ ] 手動プレイ確認（Godotエディタ起動）で以下のゴールデンパスが通ることを目視確認する:
  - 起動 → タイトル画面（はじめから/つづきから/設定/終了の4ボタン表示）
  - 「はじめから」→ スロット選択 → 空スロット選択 → 庭画面（ゴールド0スタート）
  - ゲーム中、常時HUDの「メニュー」ボタン → 一時停止メニュー（閉じる/設定/タイトルに戻る）表示
  - 「設定」→ 音量スライダー操作 → 「閉じる」→ 一時停止メニューに戻る
  - 「タイトルに戻る」→ タイトル画面へ即座に遷移（確認ダイアログなし）
  - 再度「はじめから」で同じ空スロットを選択 → ゴールドが0から再スタートする（前回操作の値を引き継がない、E1の修正確認）
- [ ] 500行ルール: 新規・変更ファイルすべてが500行以内であることを`wc -l`で確認する

## Implementation Notes

- 参照すべき既存コード: `docs/dev/plans/title-settings-screens/reports/verify-20260904.md`（旧実装時の検証レポート形式をそのまま踏襲する）
- 手動プレイ確認は`.claude/rules/godot-debug-tools.md`の手順（Godotエディタでの実行、リモートシーンツリーでの状態確認）に従う。`--headless`実行ではスクリーンショット撮影不可な点に注意
- E1（GameStateリセット）の効果確認は、手動プレイ確認の最終ステップ（ゴールドが0から再スタートするか）が唯一の実感できる確認ポイントであるため省略しないこと

## Files

- 新規: `docs/dev/plans/title-settings-screens-extension/reports/verify-<日付>.md`
