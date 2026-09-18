---
id: "011"
title: "design-guide.mdのドット絵適用範囲を庭・調合・共通UIに拡大する"
status: done
priority: 4
dependencies: ["007", "008", "009", "010"]
estimated_complexity: low
---

# Task: design-guide.mdのドット絵適用範囲を庭・調合・共通UIに拡大する

## Goal

`.claude/rules/design-guide.md`の「ドット絵技法はタイトル画面のみの例外」という記述を、庭・調合・共通UI（RankHud/TabBar）も対象に含める方針へ改訂し、guild/rank/workshopは引き続き対象外であることを明記する。

## Interfaces

コード上のインターフェースはない（ドキュメント改訂タスク）。

## Test Strategy

自動テストなし（ドキュメント変更のため）。以下を確認する:

- [ ] `design-guide.md`冒頭の改訂履歴に2026-09-18（本Plan完了日）付けの改訂コメントを追記し、変更内容（適用範囲拡大）を1文で要約している
- [ ] 「デザイン原則」節に、水彩ファンタジースタイルが**guild/rank/workshopの3画面ではデフォルトのまま**であることを明記している
- [ ] タイトル画面専用として記載されていた各種例外注記（🔵ドット絵技法の例外、ボタン4バリアント統一の例外等）を、庭・調合・共通UIにも適用される旨に更新している（タイトル画面固有の追加例外はそのまま残す。例: 4ボタン統一スタイル等）
- [ ] `docs/design/atelier-alchemy-core/ui-design/screens/garden.md`・`alchemy.md`が存在する場合、そちらにも一言リンク・整合性言及を追加する（存在しない場合はスキップしてよい）

## Implementation Notes

- 参照すべき既存コード: `.claude/rules/design-guide.md`（2026-09-16改訂コメント、「タイトル画面のみの限定的な分岐である」という現行記述箇所）
- 実装のヒント: 既存の改訂履歴コメント形式（`> 🔴 YYYY-MM-DD改訂: ...`）を踏襲する
- 注意事項: `.claude/rules/design-guide.md`はプロジェクト全体のルールファイルであり、本Plan完了後もguild/rank/workshop画面の実装者が参照する。誤って「全画面ドット絵化」と読めるような書き方をしないこと（スコープ外画面の存在を必ず明記する）

## Files

- 変更: `.claude/rules/design-guide.md`
