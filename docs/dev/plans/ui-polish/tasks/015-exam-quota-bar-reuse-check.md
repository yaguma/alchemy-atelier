---
id: "015"
title: "昇格試験の試験ノルマ減少演出がタスク011の実装を流用できることを確認する"
status: done
priority: 4
dependencies: ["011", "014"]
estimated_complexity: low
---

# Task: 昇格試験の試験ノルマ減少演出がタスク011の実装を流用できることを確認する

## Goal

`promotion-exam.md` L87は「guild-delivery.mdのノルマバー減少演出を試験ノルマ版として流用する」と設計済み。タスク011で`_refresh_rank_quota(animate)`を共通化済みであれば、追加実装なしで試験中のノルマ減少にも同じアニメーションが適用されることを確認する回帰タスク。

## Interfaces

（新規インターフェースなし。既存の`_refresh_rank_quota(animate: bool)`（タスク011）が試験モード分岐でも呼ばれていることを確認する）

## Test Strategy

- [ ] 試験中（`in_exam`相当の状態）にノルマが減少した際、`_refresh_rank_quota(animate=true)`が呼ばれ、タスク011と同じアニメーションが発生する
- [ ] 試験専用の別実装（重複コード）が存在しないことをコードレビューで確認する
- [ ] エッジケース: 試験開始直後の初期表示（ノルマ変化なし）はアニメーションなしで即時表示される

## Implementation Notes

- 参照すべき既存コード: `guild_delivery_screen.gd`または`rank_hud.gd`内の試験ノルマ分岐（`in_exam`判定箇所）
- 実装追加が不要と判明した場合は、このタスクは確認テストの追加のみで完了する。もし試験モード側に未対応の分岐が見つかった場合は、タスク011のパターンをその分岐にも適用する

## Files

- 変更: なし、または`atelier/features/guild/ui/guild_delivery_screen.gd`（試験モード分岐が未対応だった場合のみ）
- テスト: `atelier/tests/integration/test_exam_quota_bar_animation_reuse.gd`
