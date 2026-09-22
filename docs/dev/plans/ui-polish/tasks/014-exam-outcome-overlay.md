---
id: "014"
title: "昇格試験の成功/失敗結果演出コンポーネントを新設する"
status: done
priority: 2
dependencies: ["001", "013"]
estimated_complexity: high
---

# Task: 昇格試験の成功/失敗結果演出コンポーネントを新設する

## Goal

昇格試験の成功/失敗確定時、専用の結果演出を表示する（`promotion-exam.md` L88、現状🔴未設計）。アーキテクチャルール「他Featureの`ui/`への直接参照禁止」を守るため、`ExamOutcomeOverlay`は`features/rank/ui/`に配置し、`AlchemyScreen`は直接参照しない。`scenes/main.gd`（Feature外のルートシーン）が`AlchemyScreen`の中継シグナルと`ExamOutcomeOverlay`の両方を仲介する。

## Interfaces

```gdscript
# atelier/features/rank/ui/exam_outcome_overlay.gd (新規)
class_name ExamOutcomeOverlay
extends Control

signal acknowledged  # プレイヤーが結果を確認した合図（確認ボタン押下）

func show_outcome(outcome: ExamOutcome.Value) -> void  # 🟡 SUCCESS/FAILUREのみ想定。CONTINUE/未確定値が渡された場合はpush_errorし何もしない
```

```gdscript
# atelier/scenes/main.gd への追加
# _exam_outcome_overlay: ExamOutcomeOverlay をMainSceneの子として保持（他4画面と同様にMainSceneが所有）
#
# タスク013で追加した _alchemy_screen.exam_result_pending(outcome) の購読ハンドラを以下に変更:
#   1. _exam_outcome_overlay.show_outcome(outcome) を呼ぶ（画面遷移はまだ行わない）
#   2. _exam_outcome_overlay.acknowledged 受信で初めて GameState.set_phase(SUCCESS→WORKSHOP or FAILURE→GARDEN) を実行する
```

## Test Strategy

- [ ] `show_outcome(ExamOutcome.SUCCESS)`呼び出し後、オーバーレイが表示され「合格」相当のテキストが設定される
- [ ] `show_outcome(ExamOutcome.FAILURE)`呼び出し後、オーバーレイが表示され「不合格」相当のテキストが設定される
- [ ] `show_outcome(ExamOutcome.CONTINUE)`（想定外の値）を渡すと`push_error()`が呼ばれ、オーバーレイは表示状態を変更しない
- [ ] 確認ボタン押下で`acknowledged`シグナルが発行される
- [ ] `MainScene`は`exam_result_pending(SUCCESS)`受信時に`_exam_outcome_overlay.show_outcome()`を呼び、`acknowledged`受信まで`GameState.set_phase()`を呼ばない
- [ ] `MainScene`は`acknowledged`受信後、SUCCESSならworkshopへ、FAILUREならgardenへ正しく`set_phase()`する
- [ ] エッジケース: オーバーレイ表示中に他の入力（タブ切替等）を受け付けない、またはブロックする方針をtdd-implementerが決定し、その方針をテストで固定する

## Implementation Notes

- 参照すべき既存コード: `atelier/features/guild/ui/guild_delivery_screen.gd`の「続ける」ボタン確認パターン（同型の確認操作UI前例）、`atelier/features/rank/ui/`配下の既存`ResultScreen`（ゲームクリア/オーバー結果画面、デザイン・配色の参考）
- `promotion-exam.md` L86の提案（成功=金色ウォッシュ、失敗=赤系ウォッシュの画面全体演出）を踏襲する
- タイマー自動送りより確認ボタン方式を推奨（実装・テストとも安定）。自動送り併用は🟡tdd-implementer裁量
- `MainScene`が`ExamOutcomeOverlay`（rank feature）と`AlchemyScreen`（alchemy feature）の両方を子として持ち仲介することで、Feature間の直接参照を回避する（`.claude/rules/architecture.md`「他Featureの`ui/`への直接参照禁止」準拠）

## Files

- 新規: `atelier/features/rank/ui/exam_outcome_overlay.gd`, `atelier/features/rank/ui/exam_outcome_overlay.tscn`
- 変更: `atelier/scenes/main.gd`, `atelier/scenes/main.tscn`
- テスト: `atelier/tests/integration/test_exam_outcome_overlay.gd`, `atelier/tests/integration/test_main_scene_exam_outcome_routing.gd`
