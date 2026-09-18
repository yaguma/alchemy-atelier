---
id: "012"
title: "全体の回帰確認（gdlint/gdformat/GdUnit4全件、目視確認を含む）を実施する"
status: done
priority: 5
dependencies: ["011"]
estimated_complexity: medium
---

# Task: 全体の回帰確認（gdlint/gdformat/GdUnit4全件、目視確認を含む）を実施する

## Goal

001〜011の実装完了後、プロジェクトの品質ゲート（GdUnit4全件・gdlint・gdformat --check）を通過することを確認する。あわせて、guild/workshop/rankの3画面を実機（Godotエディタ手動プレイ）またはスクリーンショットで目視確認し、garden/alchemy/RankHud/TabBarとの見た目の一貫性・レイアウト破綻の有無を確認する。

## Interfaces

コード上のインターフェースはない（検証タスク）。

## Test Strategy

- [ ] `cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/ -c`が0エラー・0失敗で完了する（guild/workshop/rankの既存テストを含む全件）
- [ ] `gdlint atelier/features/ atelier/shared/ atelier/autoload/`が本Plan変更ファイルに関して警告0件
- [ ] `gdformat --check atelier/features/ atelier/shared/ atelier/autoload/`がフォーマット崩れなしを報告する
- [ ] `godot --headless --path atelier --import`がエラーなく完了する（新規アセット3点のインポート確認）
- [ ] `git status`で本Plan対象ファイル（`guild_delivery_backdrop.gd/.tscn`, `workshop_backdrop.gd/.tscn`, `rank_result_backdrop.gd/.tscn`, `guild_delivery_screen.tscn`, `workshop_screen.tscn`, `purchase_confirm_dialog.tscn`, `result_screen.tscn`, `design-guide.md`, 新規PNG3点）が全て「変更あり」として物理的に検出される
- [ ] guild（納品結果、調合実行から到達）・workshop（工房強化画面を開く）・rank（ゲームクリア/オーバー到達）の3画面を、Godotエディタでの手動プレイまたは`screen-craft`/`playwright-visual-check`相当の手段で可能な範囲で目視確認し、garden/alchemy/RankHud/TabBarとの統一感・テキスト可読性・レイアウト破綻の有無を確認する。実施できない場合はその旨を明言し、既知のフォローアップ事項として記録する
- [ ] `PurchaseConfirmDialog`（009）が`WorkshopScreen`の`%OverlayLayer`上で正しく中央付近に表示され、背後の`WorkshopBackdropPixel`・`%ContentPanel`とレイヤー順が破綻していないことを確認する

## Implementation Notes

- 参照すべき既存コード: `docs/dev/plans/garden-alchemy-visual-refresh/reports/verify-2026-09-18.md`・`verify-2026-09-18-tasks-007-012.md`（前Planの検証レポート、フォーマット参考）
- 実装のヒント: 検証結果は`docs/dev/plans/pixel-art-remaining-screens/reports/verify-<実施日>.md`に、実行コマンドと実際の出力を伴って記録する
- 注意事項: `GuildDeliveryScreen`は`AlchemyScreen`への埋め込みオーバーレイのため、調合実行→納品結果表示の一連の操作フローで確認する必要がある（`ResultScreen`同様、単体シーン起動だけでは実際の重なり順の問題を見落とす可能性がある）

## Files

- 新規: `docs/dev/plans/pixel-art-remaining-screens/reports/verify-<実施日>.md`
