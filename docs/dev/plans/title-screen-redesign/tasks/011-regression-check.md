---
id: "011"
title: "全体の回帰確認（gdlint/gdformat/GdUnit4全件、project.godot変更の影響確認を含む）を実施する"
status: done
priority: 5
dependencies: ["001", "002", "003", "004", "005", "006", "007", "008", "009", "010"]
estimated_complexity: medium
---

# Task: 全体の回帰確認（gdlint/gdformat/GdUnit4全件、project.godot変更の影響確認を含む）を実施する

## Goal

001〜010の実装がすべて完了した後、プロジェクトの品質ゲート（GdUnit4全件・gdlint・gdformat --check）を通過することを確認する。加えて、タスク001（`project.godot`のViewportストレッチ設定）がゲーム全体に及ぼす影響（既存5画面のテスト・可能な範囲での目視）を明示的に確認する。

## Interfaces

コード上のインターフェースはない（検証タスク）。

## Test Strategy

- [ ] `cd atelier && ./addons/gdUnit4/runtest.sh -a res://tests/ -c`が0エラー・0失敗で完了する（庭・調合・ギルド納品・ランク・工房強化の既存テストを含む全件）
- [ ] `gdlint atelier/features/ atelier/shared/ atelier/autoload/`が本Plan変更ファイルに関して警告0件
- [ ] `gdformat --check atelier/features/ atelier/shared/ atelier/autoload/`がフォーマット崩れなしを報告する
- [ ] `git status`で本Plan対象ファイル（`project.godot`, `theme.gd`, `button_style_applier.gd`, `title_backdrop.gd`/`.tscn`, `title_screen.gd`/`.tscn`, ドット絵PNG群, `dotgothic16_regular.ttf`, `design-guide.md`）が全て「変更あり」として物理的に検出される
- [ ] `atelier/assets/ui/pixel/`, `atelier/assets/ui/title/`, `atelier/assets/fonts/`配下に想定通りのファイルが揃っていることを確認する
- [ ] **project.godot変更の波及確認（本Plan固有）**: タスク001の`[display]`設定変更後も、庭・調合・ギルド納品・ランク・工房強化それぞれの既存GdUnit4シーンテストが引き続きPASSすることを確認する（上記の全件テストPASSに含まれる）。加えてGodotエディタでの手動プレイ確認が可能であれば、既存5画面のレイアウトが著しく破綻していないか目視確認し、結果をレポートに明記する。`--headless`実行では確認できないため、実施できない場合はその旨を明言し、`plan.md`のCross-Plan Dependenciesで既に記録した既知のフォローアップ事項として扱う
- [ ] タイトル画面がドット絵アセット（背景・ロゴ・4ボタン）とドット絵フォントで表示され、ダーク背景・青紫系を使わず、4ボタンがクリック可能であることを可能な範囲で確認する

## Implementation Notes

- 参照すべき既存コード: `docs/dev/plans/title-screen-design/reports/verify-2026-09-15.md`（前Planの検証レポート、フォーマット参考）
- 実装のヒント: 検証結果は`docs/dev/plans/title-screen-redesign/reports/verify-<実施日>.md`に、実行コマンドと実際の出力を伴って記録する
- 注意事項: テスト・lint・formatの実行結果は必ず実際のコマンド出力を貼り付け、要約のみで済ませない。project.godot変更の波及確認は本Planの中で最もリスクが高い項目のため、省略しないこと

## Files

- 新規: `docs/dev/plans/title-screen-redesign/reports/verify-<実施日>.md`
