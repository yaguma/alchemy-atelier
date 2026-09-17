---
id: "012"
title: "全体の回帰確認（gdlint/gdformat/GdUnit4全件、実測補正・目視確認を含む）を実施する"
status: done
priority: 5
dependencies: ["011"]
estimated_complexity: medium
---

# Task: 全体の回帰確認（gdlint/gdformat/GdUnit4全件、実測補正・目視確認を含む）を実施する

## Goal

001〜011の実装完了後、プロジェクトの品質ゲート（GdUnit4全件・gdlint・gdformat --check）を通過することを確認する。加えて、001で🔴とした`PANEL_TEXTURE_MARGIN`の実測補正、および実機での目視確認（可能な範囲で）を行う。

## Interfaces

コード上のインターフェースはない（検証タスク）。

## Test Strategy

- [ ] `cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/ -c`が0エラー・0失敗で完了する（庭・調合・共通UIの既存テストを含む全件）
- [ ] `gdlint atelier/features/ atelier/shared/ atelier/autoload/`が本Plan変更ファイルに関して警告0件
- [ ] `gdformat --check atelier/features/ atelier/shared/ atelier/autoload/`がフォーマット崩れなしを報告する
- [ ] `godot --headless --path atelier --import`がエラーなく完了する（新規アセット3点のインポート確認）
- [ ] `git status`で本Plan対象ファイル（`theme.gd`, `garden_backdrop.gd/.tscn`, `alchemy_backdrop.gd/.tscn`, `garden_screen.tscn`, `alchemy_screen.tscn`, `rank_hud.gd/.tscn`, `main.gd`, `design-guide.md`, 新規PNG3点）が全て「変更あり」として物理的に検出される
- [ ] `PANEL_TEXTURE_MARGIN`（004で暫定値20とした値）を実際の`panel_pixel.png`で色解析・目視確認し、過不足があれば補正する（`BUTTON_TEXTURE_MARGIN`実測時の手順を踏襲）
- [ ] TabBar（010）の選択中タブ視認性、RankHud（009）を含む5画面全体でのパネル色分けの視認性（self_modulateによるドット絵tintがアンチエイリアスなしで許容できる見た目か）を、Godotエディタでの手動プレイまたは`playwright-visual-check`/`screen-craft`スキルで可能な範囲で確認し、結果をレポートに明記する。実施できない場合はその旨を明言し、既知のフォローアップ事項として記録する

## Implementation Notes

- 参照すべき既存コード: `docs/dev/plans/title-screen-redesign/reports/verify-2026-09-16.md`（前Planの検証レポート、フォーマット参考）
- 実装のヒント: 検証結果は`docs/dev/plans/garden-alchemy-visual-refresh/reports/verify-<実施日>.md`に、実行コマンドと実際の出力を伴って記録する
- 注意事項: `009-rank-hud-integration`はRankHudが5画面共通のため、本Planのスコープ外画面（guild/rank/workshop）にも見た目の影響が及ぶ。それらの画面でレイアウトが破綻していないかも可能な範囲で確認すること（`title-screen-redesign`タスク011の「project.godot変更の波及確認」と同様の位置づけ）

## Files

- 新規: `docs/dev/plans/garden-alchemy-visual-refresh/reports/verify-<実施日>.md`
