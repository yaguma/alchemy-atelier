---
id: "008"
title: "GameState.apply_upgrade()の共通検証・ゴールド減算・シグナル発行を実装する"
status: pending
priority: 2
dependencies: ["003", "007"]
estimated_complexity: medium
---

# Task: GameState.apply_upgrade()の共通検証・ゴールド減算・シグナル発行を実装する

## Goal

`GameState.apply_upgrade(upgrade: UpgradeMaster) -> Result`の共通パイプライン（null検証・恒久フラグ検証・`PurchaseValidator.can_purchase`実行直前再評価・ゴールド減算・購入回数カウント更新・`gold_changed`シグナル発行・`Result`返却）を実装する（FR-101, FR-102, FR-103, FR-104, FR-112, FR-113, FR-114, FR-401, FR-402）。`effect_type`別の状態反映（`_alchemy_slot_count`加算等の5分岐）は次タスク009で実装するため、本タスクでは`match`文の各分岐を空実装（no-op、`pass`）にしておく。

## Interfaces

```gdscript
# atelier/autoload/game_state.gd への追加メソッド

## 🔵 FR-101〜FR-104, FR-112〜FR-114, FR-401〜FR-402。
## 検証(1)null(2)恒久フラグ(3)can_purchase再評価の順に行い、
## 全て通過した場合のみ状態変更をすべて完了させてからgold_changedを発行する。
## いずれかの検証に失敗した場合はいかなる状態も変更しない（AC-003, AC-014）。
## effect_type別の状態反映は_apply_upgrade_effect()に委譲する（タスク009でno-op実装から差し替え）
func apply_upgrade(upgrade: UpgradeMaster) -> Result:
	# 1. null防御（FR-112）
	if upgrade == null:
		return Result.fail(&"invalid_upgrade")

	# 2. 恒久投資フラグ検証（FR-103, FR-201, FR-202, FR-203）
	if PurchaseValidator.is_permanent_upgrade(upgrade) and not _can_purchase_permanent:
		return Result.fail(&"workshop_closed")

	# 3. 実行直前の再評価（FR-101, FR-102, FR-401, FR-402）
	var already_purchased_count: int = _purchased_upgrade_counts.get(upgrade.id, 0)
	if not PurchaseValidator.can_purchase(
		_gold, upgrade.price, already_purchased_count, upgrade.max_purchase_count
	):
		return Result.fail(&"cannot_purchase")

	# --- 状態変更フェーズ（全て完了するまでシグナル発行しない） ---
	var previous_gold := _gold
	_gold -= upgrade.price  # FR-104

	_apply_upgrade_effect(upgrade)  # タスク009で実装。本タスクではno-op

	_purchased_upgrade_counts[upgrade.id] = already_purchased_count + 1  # FR-113

	gold_changed.emit(previous_gold, _gold, _gold - previous_gold)  # FR-104

	return Result.ok(upgrade)  # FR-114


## 🔴 本タスクではno-op（pass）。タスク009でeffect_type別の5分岐（FR-105〜FR-109）を実装する
func _apply_upgrade_effect(upgrade: UpgradeMaster) -> void:
	pass
```

エラーコード`&"workshop_closed"`・`&"cannot_purchase"`は🔴→🟡（design phaseで命名案として提示、既存コードのsnake_case規約に準拠した妥当な推測。他に確定した命名根拠はないためこの案を採用する）。

## Test Strategy

`docs/dev/plans/workshop/acceptance-criteria.md` AC-003, AC-004（フラグ拒否部分のみ）, AC-006, AC-007, AC-013, AC-014, AC-018準拠。`effect_type`別の効果検証（AC-008〜012）は次タスク009で行う。

- [ ] **正常系**: ゴールドが十分・恒久フラグ不問（消耗投資）の場合、`Result.ok(upgrade)`が返り購入が成立する
- [ ] **異常系**: `_gold = upgrade.price - 1`で呼び出すと`Result.fail()`が返り、`_gold`が変化しない
- [ ] **境界値**: `_gold == upgrade.price`（ちょうど同額）では購入が成立する
- [ ] **異常系**: `is_permanent = true`のUpgradeMasterを`_can_purchase_permanent = false`のまま購入しようとすると`Result.fail()`が返り、`_gold`が変化しない
- [ ] **正常系**: `is_permanent = false`のUpgradeMaster（消耗投資）は`_can_purchase_permanent`の値に関わらず購入できる
- [ ] **正常系**: 購入成立時、`_gold`が`price`分減算される
- [ ] **正常系**: 購入成立時、`gold_changed(previous_amount, new_amount, delta)`シグナルが正しい引数で発行される（`monitor_signals(GameState, false)`で監視）
- [ ] **異常系**: 購入が拒否された場合は`gold_changed`シグナルが発行されない
- [ ] **正常系**: 購入成立時、`_purchased_upgrade_counts[upgrade.id]`が1増える（未登録キーは0から開始）
- [ ] **境界値**: `already_purchased_count == max_purchase_count - 1`（上限到達直前）の2回目呼び出しは`Result.fail()`が返り、`_purchased_upgrade_counts`がそれ以上増えない
- [ ] **異常系**: `apply_upgrade(null)`を呼び出すとクラッシュせず`Result.fail(&"invalid_upgrade")`が返り、いかなる状態も変化しない
- [ ] **異常系（アトミック性・総合）**: ゴールド不足・恒久フラグfalse・購入回数上限到達のいずれかに該当する場合、`_gold`・`_purchased_upgrade_counts`のいずれも呼び出し前と完全に一致する（部分適用が発生しない）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`execute_alchemy()`（検証失敗時に状態を一切変更しないアトミック性パターン）、`deliver_pending_products()`（`gold_changed`発行パターン、L309-345）、`Result`型（`atelier/shared/entities/result.gd`）
- 実装のヒント: 検証(2)恒久フラグ→(3)can_purchase再評価の順序は要件文書のFR番号順（101〜103）とは逆だが、外部から観測可能な差異（Result成否）はない（Plan設計フェーズで確認済み）。消耗投資では恒久フラグ判定がコスト0で即座にスキップされるため、この順序の方が自然
- 注意事項: `PurchaseValidator`（タスク003）・`GameState`workshopフィールド（タスク007）が先に完了している必要がある。`_apply_upgrade_effect()`は本タスクでは`pass`のみとし、5種類の`effect_type`分岐は次タスク009に委ねる。本タスクのテストは`effect_type`の具体的な値に依存しない検証のみで構成すること（`effect_type`は任意のダミー値でよい）

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_apply_upgrade_validation.gd`
