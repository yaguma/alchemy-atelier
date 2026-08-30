---
id: "002"
title: "指定依頼の絞り込み・抽選を行う純粋関数DailyOrderSelectorを実装する"
status: done
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: 指定依頼の絞り込み・抽選を行う純粋関数DailyOrderSelectorを実装する

## Goal

現在の解禁状況（解禁済みレシピ・特性解禁フラグ）で達成可能な`DailyOrderMaster`のみへ絞り込み、その中から乱数値で1件を均一抽選する副作用のない純粋関数`DailyOrderSelector`を実装する。

## Interfaces

```gdscript
# atelier/features/guild/logic/daily_order_selector.gd（新規、Functional Core）
class_name DailyOrderSelector

## 現在の解禁状況で達成可能なDailyOrderMasterのみへ絞り込む純粋関数。
## condition_type=="item"はtarget_recipe_idがunlocked_recipe_idsに含まれるもの、
## condition_type=="trait"はtraits_unlocked==trueの場合のみ残す。
## 未知のcondition_type、空文字ターゲット（target_recipe_id/target_trait）のエントリは除外する
## 🔵 FR-005, FR-203, NFR-302
static func filter_achievable(
	all_orders: Array[DailyOrderMaster],
	unlocked_recipe_ids: Array[StringName],
	traits_unlocked: bool,
) -> Array[DailyOrderMaster]

## 絞り込み済みプールから乱数値[0.0, 1.0)を用いて1件を均一抽選する純粋関数。
## プールが空の場合はnullを返す。同じrandom_valueに対して常に同じ結果を返す（決定的）。
## item/traitの種別で重み付けはしない（CON-012、絞り込み後プール全体から均一抽選）
## 🔵 FR-006, FR-301, FR-404
static func select(pool: Array[DailyOrderMaster], random_value: float) -> DailyOrderMaster
```

## Test Strategy

- [ ] 解禁済みレシピを対象とする`"item"`エントリが絞り込み結果に含まれる
- [ ] `traits_unlocked == true`のとき`"trait"`エントリが絞り込み結果に含まれる
- [ ] 未解禁レシピを対象とする`"item"`エントリが絞り込み結果から除外される
- [ ] `traits_unlocked == false`のとき`"trait"`エントリがすべて除外される
- [ ] `select()`は同一の乱数値を2回渡すと同一の`DailyOrderMaster`が返る（決定性）
- [ ] `select()`は異なる乱数値でプール内の異なる要素が選出されうる
- [ ] **異常系**: `condition_type`が`"item"`/`"trait"`以外の未知値のエントリが絞り込み結果から除外される
- [ ] **異常系**: `target_recipe_id`/`target_trait`が空文字のエントリが絞り込み結果から除外される
- [ ] **境界値**: `all_orders`が空配列の場合、絞り込み結果も空配列になる
- [ ] **境界値**: `unlocked_recipe_ids`が空配列の場合、`"item"`エントリがすべて除外される
- [ ] **境界値**: `select()`にプールが空配列で渡された場合、`null`を返す
- [ ] **境界値**: `select()`にプールが1件のみの場合、どの乱数値（0.0〜1.0未満の境界含む）でもその1件が返る
- [ ] **境界値**: `select()`に`random_value == 0.0`および`random_value`がほぼ`1.0`（例: 0.9999）の場合でも、プール外のインデックスにアクセスしない

## Implementation Notes

- 参照すべき既存コード:
  - `atelier/features/guild/logic/delivery_resolver.gd`（同じguild Feature内の既存純粋関数。ファイル冒頭の記述順序・スタイルを踏襲する）
  - `.claude/rules/tdd-implementation.md`「Domain層で乱数を自己生成しない」（`RngService`から払い出された値を引数で受け取る設計。本関数自体は`RngService`をimportしない）
  - `.claude/rules/architecture.md`「Functional Core, Imperative Shell」（`static func`、`Node`非継承、副作用なし）
- 実装のヒント: `select()`のインデックス変換は`floori(random_value * pool.size())`とし、`clampi()`で`[0, pool.size() - 1]`にクランプすることで、`random_value`が理論上の境界値（0.0や1.0に極めて近い値）でも配列範囲外アクセスを防ぐ。`filter_achievable()`は`for order in all_orders:`で1件ずつ判定し、`match order.condition_type:`の3分岐（`"item"`, `"trait"`, `_`（未知値は除外））で書くと`coding-style.md`の型安全方針に沿う。
- 注意事項: 本関数は`GameState`を一切参照しない（FR-404）。テストは`RngService`を`mock()`せず、乱数値を直接引数として渡す形で書く（NFR-103）。

## Files

- 新規: `atelier/features/guild/logic/daily_order_selector.gd`
- テスト: `atelier/tests/unit/features/guild/test_daily_order_selector.gd`（新規）
