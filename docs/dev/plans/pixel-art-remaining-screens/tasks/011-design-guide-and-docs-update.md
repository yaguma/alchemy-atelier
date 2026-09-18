---
id: "011"
title: "design-guide.mdと関連画面設計書のドット絵適用範囲を全画面に拡大する"
status: pending
priority: 4
dependencies: ["007", "008", "009", "010"]
estimated_complexity: low
---

# Task: design-guide.mdと関連画面設計書のドット絵適用範囲を全画面に拡大する

## Goal

`.claude/rules/design-guide.md`の「guild・rank・workshopの3画面は水彩ファンタジースタイルのまま対象外」という現行記述を、本Plan完了後の実態（全画面ドット絵統一）に合わせて改訂する。あわせて`docs/design/atelier-alchemy-core/ui-design/screens/workshop-shop.md`・`promotion-exam.md`に garden.md/alchemy.md と同様のドット絵反映注記を追加し、`guild-delivery.md`の既存注記（実装より先行して書かれていた記述）が実態と一致することを確認する。

## Interfaces

コード上のインターフェースはない（ドキュメント改訂タスク）。

## Test Strategy

自動テストなし（ドキュメント変更のため）。以下を確認する:

- [ ] `design-guide.md`冒頭の改訂履歴に本Plan完了日付けの改訂コメントを追記し、変更内容（適用範囲をguild/rank/workshopまで拡大）を1文で要約している
- [ ] 「デザイン原則」節・ドット絵例外注記（2026-09-16・2026-09-18付）の「guild（ギルド納品）・rank（ランク進行・昇格試験）・workshop（工房強化）の3画面は対象外」という記述を削除または「全画面がドット絵技法で統一された」旨に更新している
- [ ] 水彩ファンタジースタイルの記述自体は削除せず、「将来水彩を使う場合の設計原則」として残すか、明確に「現在は全画面未使用」である旨を注記する（過去の記述を無言で消さず、変更履歴として残す既存の文化に従う）
- [ ] `docs/design/atelier-alchemy-core/ui-design/screens/workshop-shop.md`・`promotion-exam.md`の冒頭に、`garden.md`/`alchemy.md`（2026-09-18追記）と同型の「本画面はドット絵技法に刷新済み」注記を追加している
- [ ] `docs/design/atelier-alchemy-core/ui-design/screens/guild-delivery.md`の既存6行目の注記（本Plan着手前から存在していた「ドット絵技法に刷新済み」という記述）が、本Plan完了後の実態と一致することを確認し、日付・Plan名参照が本Plan（`pixel-art-remaining-screens`）を指すよう必要なら修正する

## Implementation Notes

- 参照すべき既存コード: `.claude/rules/design-guide.md`（2026-09-16/2026-09-18改訂コメント、現行の「guild/rank/workshopは対象外」記述箇所）、`docs/design/atelier-alchemy-core/ui-design/screens/alchemy.md`・`garden.md`（6行目付近の注記フォーマット）、`docs/design/atelier-alchemy-core/ui-design/screens/guild-delivery.md`（既存の先行注記）
- 実装のヒント: 既存の改訂履歴コメント形式（`> 🔵`/`> 🔴 YYYY-MM-DD改訂: ...`）を踏襲する。`guild-delivery.md`の既存注記は本Planの着手前から存在していた（`docs/dev/plans/pixel-art-remaining-screens/plan.md`の「Cross-Plan Dependencies」参照）ため、ドキュメントドリフトの経緯を消さず「先行して書かれていたが実装が追いついていなかった」旨を一言残すとCLAUDE.mdの文化（過去の記載誤りを隠さず記録する）に沿う
- 注意事項: `.claude/rules/design-guide.md`はプロジェクト全体のルールファイルであり、以降の全画面実装者が参照する。ボタン4バリアントの意味論・角丸規定・カラー参照ルール自体は変更しないこと（適用範囲の記述のみ更新する）

## Files

- 変更: `.claude/rules/design-guide.md`
- 変更: `docs/design/atelier-alchemy-core/ui-design/screens/workshop-shop.md`
- 変更: `docs/design/atelier-alchemy-core/ui-design/screens/promotion-exam.md`
- 変更（必要な場合のみ）: `docs/design/atelier-alchemy-core/ui-design/screens/guild-delivery.md`
