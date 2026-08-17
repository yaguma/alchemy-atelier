---
id: "004"
title: "RankProgressionを実装する"
status: done
priority: 1
dependencies: ["003"]
estimated_complexity: low
---

# Task: RankProgressionを実装する

## Goal

現在ランクIDから次ランクIDを決定する純粋関数`RankProgression.get_next_rank_id`を実装する。`GameBalance.RANK_ORDER`上のindex+1参照で、次ランクが存在しない場合は空文字列を返す。

## Interfaces

```gdscript
# features/rank/logic/rank_progression.gd
class_name RankProgression

## GameBalance.RANK_ORDER上のindex+1参照。次ランクなし・現在ランクIDが
## RANK_ORDERに存在しない場合は&""を返す 🔵 FR-010
static func get_next_rank_id(current_rank_id: StringName) -> StringName:
    pass
```

> 信号機: 🔵 ユーザーヒアリング（次ランク判定方式）・design phaseで確定。既存`rank_outcome.gd`（8行）と同型の単一責務・小規模logicファイルとして新規配置。

## Test Strategy

- [ ] 正常系: `get_next_rank_id(&"rank_g") == &"rank_f"`（先頭からの遷移）
- [ ] 正常系: `get_next_rank_id(&"rank_a") == &"rank_s"`（末尾直前からの遷移）
- [ ] 境界値（RANK_ORDER末尾）: `get_next_rank_id(&"rank_s") == &""`（次ランクなし＝ゲームクリア判定の根拠。FR-404）
- [ ] 異常系: `RANK_ORDER`に存在しないランクID（例: `&"unknown"`）を渡すと`&""`を返す（クラッシュしない。NFR-101）
- [ ] 純粋性: 同一引数に対して常に同じ結果を返す（`GameState`非依存の確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/shared/constants/game_balance.gd`のタスク003で追加した`RANK_ORDER`
- 実装のヒント: `Array.find()`でindexを取得し、`-1`（未存在）または`index+1 >= size()`（末尾）の場合に`&""`を返す
- 注意事項: 乱数・`GameState`参照を一切持たない純粋関数にする（FR-402相当の原則をDomain層全体に適用）

## Files

- 新規: `atelier/features/rank/logic/rank_progression.gd`
- テスト: `atelier/tests/unit/features/rank/test_rank_progression.gd`
