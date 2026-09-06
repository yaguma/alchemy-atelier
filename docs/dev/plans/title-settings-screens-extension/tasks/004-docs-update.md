---
id: "004"
title: "CLAUDE.mdとui-design/overview.mdを実装済み状態に更新する"
status: done
priority: 4
dependencies: ["001", "002", "003"]
estimated_complexity: low
---

# Task: CLAUDE.mdとui-design/overview.mdを実装済み状態に更新する

## Goal

`CLAUDE.md`は現在も「タイトル画面・設定画面は…設計スコープ外」と記載したままであり、`docs/design/atelier-alchemy-core/ui-design/overview.md`の画面一覧・画面遷移図もタイトル画面・一時停止メニューを反映していない。実装が完了した実態に合わせて両ドキュメントを更新する。

## Interfaces

（ドキュメントタスクのためコード的インターフェースはなし）

## Test Strategy

- [ ] `CLAUDE.md`の該当箇所（技術スタック節・「次のステップ」節）から「タイトル画面・設定画面は…設計スコープ外」という趣旨の記述が除去されている
- [ ] `CLAUDE.md`に本Plan（`title-settings-screens-extension`）の実装内容と日付が信号機コメント（🔵実装済み等）付きで追記されている（既存の更新履歴スタイルに合わせる）
- [ ] `ui-design/overview.md`の画面一覧テーブルに、タイトル画面（新設SCR番号）・一時停止メニューが追加されている
- [ ] `ui-design/overview.md`の画面遷移図（mermaid）に`[*] --> TitleScreen`・`TitleScreen --> SlotSelectScreen`・ゲーム中画面群⇔一時停止メニュー⇔TitleScreenの遷移が追加されている
- [ ] 追記箇所に既存文書のスタイル（信号機コメント、更新日付、根拠へのリンク）が踏襲されている

## Implementation Notes

- 参照すべき既存コード・文書: `CLAUDE.md`の「🔴 2026-09-06修正」のような既存の訂正コメントの書き方をそのまま踏襲する（新規追記も同じ形式にする）
- `docs/design/atelier-alchemy-core/ui-design/overview.md`の既存のSCR-007追加時の記載（「🔵 2026-09-05追加（実装〔PR #45〕反映）」）と同じ粒度・形式で、今回はPR番号ではなく本Plan（`title-settings-screens-extension`）とマージ元PR（#46）の両方を根拠として明記する
- `docs/dev/context.md`もタイトル画面追加後の起動フロー（`BootScene → TitleScreen → SlotSelectScreen → MainScene`）を反映していないため、あわせて更新する（`Project Structure`節の`atelier/scenes/boot.tscn`コメント等）

## Files

- 変更: `CLAUDE.md`
- 変更: `docs/design/atelier-alchemy-core/ui-design/overview.md`
- 変更: `docs/dev/context.md`
