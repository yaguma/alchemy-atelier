---
id: "001"
title: "UpgradeEffectDescriberを実装する"
status: done
priority: 1
dependencies: []
estimated_complexity: low
---

# Task: UpgradeEffectDescriberを実装する

## Goal

`UpgradeMaster`の`effect_type`/`effect_value`から、確認ダイアログに表示する日本語の効果説明文を生成する純粋関数を実装する。

## Interfaces

```gdscript
# atelier/features/workshop/logic/upgrade_effect_describer.gd
class_name UpgradeEffectDescriber

## effect_typeに応じた日本語説明文を返す（副作用なし、他Featureのマスターデータ参照禁止）。
## 未知のeffect_typeの場合は空文字列を返す（PurchaseValidator.is_valid_effect()で
## 事前に弾かれる想定のため防御的分岐、UI側の表示欠落で気づける）
static func describe(upgrade: UpgradeMaster) -> String:  # 🔵 5種類のeffect_typeを網羅
	pass
```

信号機:
- 🔵 `alchemy_slot_increase` → `"調合の投入枠が%d増えます" % effect_value`（`upgrade_alchemy_slot.tres`の`name`="投入枠+1"と整合する内容）
- 🔵 `garden_slot_increase` → `"庭の仕込み枠が%d増えます" % effect_value`
- 🔵 `catalyst_stock` → `"触媒素材を1個獲得します"`（`_apply_upgrade_effect()`が常に1個生成する仕様に対応、`game_state_workshop_delegate.gd:77-84`）
- 🟡 `recipe_unlock` → `"新しいレシピが解放されます"`（`effect_value`のレシピIDを人間可読名に解決するのはスコープ外。他Featureのマスターデータ参照を避けるため汎用文言とする）
- 🟡 `seed_name_purchase` → `"新しい種を購入できるようになります"`（同上の理由で汎用文言）
- 🟡 未知の`effect_type` → `""`（空文字列。呼び出し元は空文字列時に説明欄を非表示/空表示にする想定）

## Test Strategy

- [ ] `effect_type = &"alchemy_slot_increase"`, `effect_value = 1` で `"調合の投入枠が1増えます"` を返す
- [ ] `effect_type = &"garden_slot_increase"`, `effect_value = 2` で `"庭の仕込み枠が2増えます"` を返す
- [ ] `effect_type = &"catalyst_stock"` で `"触媒素材を1個獲得します"` を返す（`effect_value`の値に関わらず固定文言）
- [ ] `effect_type = &"recipe_unlock"`, `effect_value = &"recipe_mana_tonic"` で `"新しいレシピが解放されます"` を返す
- [ ] `effect_type = &"seed_name_purchase"`, `effect_value = &"seed_ore"` で `"新しい種を購入できるようになります"` を返す
- [ ] エッジケース: `effect_type = &"unknown_type"`（未知）で空文字列 `""` を返す

## Implementation Notes

- 参照すべき既存コード: `atelier/features/workshop/logic/purchase_validator.gd`（同じ5種類の`effect_type`を`match`で網羅する`is_valid_effect()`の書き方を踏襲する）
- 参照すべき既存コード: `atelier/autoload/game_state_workshop_delegate.gd`の`_apply_upgrade_effect()`（各`effect_type`が実際に何をするかの正確な仕様）
- `class-definitions-order`（`.gdlintrc`）に従い、`class_name`宣言直後にdocstring、staticなユーティリティクラスのため`extends`不要（`PurchaseValidator`と同型）
- `effect_value`の型は`PurchaseValidator.is_valid_effect()`で事前検証済み（呼び出し元が保証）という前提のため、本関数内で改めて型ガードを重複させない（`_apply_upgrade_effect()`と同じ設計判断）

## Files

- 新規: `atelier/features/workshop/logic/upgrade_effect_describer.gd`
- テスト: `atelier/tests/unit/features/workshop/test_upgrade_effect_describer.gd`
