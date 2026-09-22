---
id: "013"
title: "昇格試験結果確定のシグナル配線を中継方式に是正する"
status: done
priority: 1
dependencies: []
estimated_complexity: high
---

# Task: 昇格試験結果確定のシグナル配線を中継方式に是正する

## Goal

現状、`GameState.exam_outcome_confirmed`を`AlchemyScreen`と`MainScene`が直接かつ同時に購読しており、ノード生成順（子→親）により`AlchemyScreen`側ハンドラが先に走った直後、同じ同期呼び出しの中で`MainScene`側が`GameState.set_phase()`を呼んで`AlchemyScreen`自体を`visible=false`にしてしまう。これにより`AlchemyScreen`内に結果演出を足しても描画前に消える。本タスクは、`GuildDeliveryScreen`の「続ける」ボタン起点の中継シグナル（`screen_closed → AlchemyScreen.delivery_confirmed → MainScene`）と同型のパターンへ配線を是正する。タスク014（結果演出コンポーネント）の前提ブロッカー。

## Interfaces

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd への追加
signal exam_result_pending(outcome: ExamOutcome.Value)  # 🔵 SUCCESS/FAILURE確定時、画面遷移を伴わず発行する中継シグナル
```

```gdscript
# atelier/features/alchemy/ui/alchemy_screen.gd の既存 _on_exam_outcome_confirmed(outcome) を変更
# 変更方針:
#   - outcome が CONTINUE の場合: 既存通り即座に処理する（画面遷移が絡まないため変更不要）
#   - outcome が SUCCESS/FAILURE の場合: GameState.set_phase()等の画面遷移処理は一切行わず、
#     exam_result_pending.emit(outcome) を発行するのみに留める
#     （AlchemyScreen自身は GameState.exam_outcome_confirmed を今後も購読し続けるが、
#      遷移処理の実行はMainScene側へ完全移管する）
```

```gdscript
# atelier/scenes/main.gd の変更
# 変更方針:
#   - GameState.exam_outcome_confirmed の直接購読を廃止する
#   - _alchemy_screen.exam_result_pending を新規購読し、SUCCESS/FAILUREの画面遷移処理
#     （既存 _on_exam_outcome_confirmed() のロジックをほぼそのまま移設）をここで実行する
#   - ただし実際のフェーズ遷移（GameState.set_phase()呼び出し）は、タスク014のExamOutcomeOverlay
#     による確認操作（acknowledged）を待ってから実行する（詳細はタスク014側のInterfaces参照）
```

## Test Strategy

- [ ] `AlchemyScreen`が`GameState.exam_outcome_confirmed(SUCCESS)`を受けた時、`exam_result_pending(SUCCESS)`を発行し、`GameState.set_phase()`は呼ばない
- [ ] `AlchemyScreen`が`GameState.exam_outcome_confirmed(FAILURE)`を受けた時も同様に`exam_result_pending(FAILURE)`のみ発行する
- [ ] `AlchemyScreen`が`GameState.exam_outcome_confirmed(CONTINUE)`を受けた時は、従来通り画面遷移を伴わない処理がその場で完結する（回帰確認）
- [ ] `MainScene`は`_alchemy_screen.exam_result_pending`受信後も、（タスク014実装前の時点では）遷移処理を即座に実行する暫定実装でよい。ただし既存のフェーズ遷移統合テストが引き続きパスすること
- [ ] 既存のGdUnit4フェーズ遷移テスト（`atelier/tests/integration/`配下、試験成功/失敗時のフェーズ遷移を検証しているファイル）を洗い出し、新しい購読経路に合わせて改修し全てパスさせる
- [ ] エッジケース: `AlchemyScreen`がまだシーンツリーに追加されていないタイミングで`exam_outcome_confirmed`が発火しないこと（既存の初期化順序を壊さない）

## Implementation Notes

- 参照すべき既存コード: `atelier/scenes/main.gd`の`_on_exam_outcome_confirmed()`（L85-90付近のコメントに接続順序依存の記載あり、これを削除・書き直す）、`atelier/features/alchemy/ui/alchemy_screen.gd`の`_on_exam_outcome_confirmed()`、既存の`delivery_confirmed`シグナル実装（同型パターンの前例）
- 影響範囲が大きいタスクのため、まず既存のGdUnit4統合テストで「試験成功→workshop遷移」「試験失敗→garden遷移」を検証しているテストファイルを`Grep`等で特定してから着手する
- `.claude/rules/state-management.md`の「signal（EventBus相当）」節に従い、`Autoload`（`GameState`）への購読は`MainScene._exit_tree()`で解除する必要がある一方、`AlchemyScreen`（子ノード）が発行する`exam_result_pending`への`MainScene`側の購読は、同一シーンツリー内の親子関係であっても発行元がAutoloadではなく子ノードであるため解除要否を実装時に確認する

## Files

- 変更: `atelier/features/alchemy/ui/alchemy_screen.gd`, `atelier/scenes/main.gd`
- テスト: 既存のフェーズ遷移統合テスト群（`atelier/tests/integration/`配下、実装時に特定して改修）
