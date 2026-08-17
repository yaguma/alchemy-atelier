---
id: "005"
title: "PromotionExamResolverを実装する"
status: done
priority: 1
dependencies: ["001", "002"]
estimated_complexity: medium
---

# Task: PromotionExamResolverを実装する

## Goal

昇格試験の状態遷移（開始・ターン進行・結果判定）を担うDomain層の純粋関数集合`PromotionExamResolver`を実装する。

## Interfaces

```gdscript
# features/rank/logic/promotion_exam_resolver.gd
class_name PromotionExamResolver

## rank_master==null または limit_turn<=0（ゼロ除算防止）の場合は push_error() した上で
## ゼロ値のExamStateを返す 🔵 FR-002, NFR-101
static func start_exam(rank_master: RankMaster) -> ExamState:
    pass

## 引数を破壊的に変更せず、exam_elapsed_turnを+1した新規ExamStateを返す 🔵 FR-003, FR-403
static func advance_turn(exam_state: ExamState) -> ExamState:
    pass

## exam_quota<=0 なら最優先でSUCCESS。exam_elapsed_turn>=exam_turn_limit かつ
## exam_quota>0 ならFAILURE。それ以外はCONTINUE 🔵 FR-004
static func resolve_outcome(exam_state: ExamState) -> ExamOutcome.Value:
    pass
```

> 信号機: 🔵 `core-systems.md`L334-336に既存仕様あり、design phaseで擬似コード確定済み。`start_exam`のnullガードとGameState側ガードの二重構造はユーザー確認済み（意図的な設計）。

## Test Strategy

### start_exam
- [ ] 正常系: `quota_max=100, limit_turn=10, exam_turn_limit=3, coefficient=1.5` → `exam_quota_max == 45.0`かつ`exam_quota == 45.0`
- [ ] 正常系: `exam_elapsed_turn == 0`、`exam_turn_limit == rank_master.exam_turn_limit`で初期化される
- [ ] 異常系: `rank_master == null`を渡すと`push_error()`が呼ばれゼロ値の`ExamState`が返る
- [ ] 異常系: `limit_turn == 0`の`RankMaster`を渡すとゼロ除算せず`push_error()`が呼ばれゼロ値の`ExamState`が返る
- [ ] 境界値: `exam_difficulty_coefficient == 0`の場合、`exam_quota_max == 0`で初期化される

### advance_turn
- [ ] 正常系: `exam_elapsed_turn=0` → 戻り値が`1`、引数`a`は変化しない
- [ ] 境界値: `exam_elapsed_turn == exam_turn_limit - 1`から+1して上限ちょうどに到達する
- [ ] 不変性: 戻り値と引数が別インスタンス（`is`で非同一参照を確認）

### resolve_outcome
- [ ] 正常系: `exam_quota=50(>0), exam_elapsed_turn=1 < exam_turn_limit=3` → `CONTINUE`
- [ ] 境界値（SUCCESS境界）: `exam_quota == 0`ちょうど → `SUCCESS`
- [ ] 境界値（FAILURE境界）: `exam_elapsed_turn == exam_turn_limit`かつ`exam_quota > 0` → `FAILURE`
- [ ] 異常系: `exam_quota`が負値でも`<=0`条件により`SUCCESS`扱いになる

## Implementation Notes

- 参照すべき既存コード: `atelier/features/rank/logic/rank_quota_resolver.gd`（`reset_for_retry`のnull-guardパターン）、`atelier/features/rank/logic/turn_limit_resolver.gd`（3値判定ロジックの構造）
- 実装のヒント: design phaseの擬似コードをそのまま実装に落とし込める
- 注意事項: 内部で乱数生成・`GameState`/`RngService`参照を一切行わない（FR-402）

## Files

- 新規: `atelier/features/rank/logic/promotion_exam_resolver.gd`
- テスト: `atelier/tests/unit/features/rank/test_promotion_exam_resolver.gd`
