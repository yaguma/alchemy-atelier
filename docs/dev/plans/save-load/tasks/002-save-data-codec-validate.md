---
id: "002"
title: "SaveDataCodecの検証・アンラップ関数を実装する"
status: done
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: SaveDataCodecの検証・アンラップ関数を実装する

## Goal

`JSON.parse()`が返した生の`Variant`を検証し、正当なセーブデータであれば`data`部分のDictionaryを、不正・破損時は空Dictionaryを返す純粋関数を実装する。`.claude/rules/security.md`の`load_save_data()`の型ガード方針を踏襲する。

## Interfaces

```gdscript
# atelier/features/save_load/logic/save_data_codec.gd に追記

## JSON.parse()の結果（Variant）を検証する。
## 検証内容: (1) Dictionaryであること (2) "data"キーがDictionaryであること
## (3) "checksum"キーがStringであり calculate_checksum(data) と一致すること
## (4) "data"が_is_valid_save_data()を満たすこと
## いずれかを満たさなければ空Dictionary{}を返す（呼び出し元は空判定でエラー扱いする）。
## 🔵 意図的な改ざん検出はできない前提（security.mdの既知の割り切りをそのまま継承、偶発的破損の検出のみが目的）
static func validate_and_unwrap(raw: Variant) -> Dictionary

## data（Variant）が保存用Dictionaryとして最低限の構造を満たすかを返す。
## トップレベルキーの型のみ検証し、ネストしたinventory等の配列要素までは検証しない
## （🟡 個人開発規模の割り切り。security.mdの_is_valid_save_data()と同水準の検証範囲）
## 必須キーと期待型: current_phase(String), gold(int|float), current_turn(int|float),
## garden_state(Dictionary), seed_inventory(Array), inventory(Array), material_instance_seq(int|float),
## garden_slot_count(int|float), unlocked_recipe_ids(Array), pending_products(Array),
## alchemy_slot_count(int|float), current_daily_order_id(String), current_rank_id(String),
## demotion_count(int|float), rank_state(Dictionary), rank_state_initialized(bool),
## last_rank_outcome(int|float), in_exam(bool), exam_state(Dictionary),
## last_exam_outcome(int|float), has_cleared_game(bool), can_purchase_permanent(bool),
## purchased_upgrade_counts(Dictionary), saved_at_unix(int|float)
static func _is_valid_save_data(data: Variant) -> bool
```

## Test Strategy

- [ ] `wrap_with_checksum()`で生成した正当なDictionaryを`validate_and_unwrap()`に渡すと元の`data`がそのまま返る
- [ ] `raw`がDictionaryでない場合（例: 配列、文字列、null）は空Dictionaryが返る
- [ ] `"data"`キーが存在しない場合は空Dictionaryが返る
- [ ] `"checksum"`が正しい`data`に対して改変されている場合（1文字違い）は空Dictionaryが返る
- [ ] `data`内の必須キー（例: `gold`）が欠落している場合は空Dictionaryが返る
- [ ] `data`内の型が不一致の場合（例: `gold`が文字列）は空Dictionaryが返る
- [ ] JSONの数値はfloatとしてパースされうるため、`gold`が`100.0`（float）でも正当と判定される（GodotのJSONパーサ仕様への対応、境界値）

## Implementation Notes

- 参照すべき既存コード: `.claude/rules/security.md`の`load_save_data()`/`_is_valid_save_data()`サンプル（int/floatの両方を許容する型ガードパターン）
- 実装のヒント: `Dictionary.get(key)`で安全にキーアクセスし、型チェックは`is`演算子で行う（`Variant`無条件使用禁止、`.claude/rules/coding-style.md`）
- 注意事項: ネストした`garden_state`/`rank_state`/`exam_state`/`pending_products`等の内部構造検証はタスク005（`restore_save_data()`）側で個別に型ガードしながら復元するため、本タスクでは深追いしない

## Files

- 変更: `atelier/features/save_load/logic/save_data_codec.gd`
- テスト: `atelier/tests/unit/features/save_load/test_save_data_codec.gd`（001のテストファイルに追記）
