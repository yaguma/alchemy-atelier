---
id: "007"
title: "GameStateに工房強化フィールドとテスト専用APIを追加する"
status: done
priority: 1
dependencies: ["001"]
estimated_complexity: medium
---

# Task: GameStateに工房強化フィールドとテスト専用APIを追加する

## Goal

`GameState`に工房強化・ショップ関連の新規フィールド3件を追加し、`get_state()`・`reset_for_test()`へ統合、テスト専用API2件を`GameStateTestSupport`経由で提供する（FR-009, FR-010, FR-011, FR-012, FR-013, FR-014, FR-017）。`apply_upgrade()`本体（タスク008/009）が依存する土台を先に用意するタスク。

## Interfaces

```gdscript
# atelier/autoload/game_state.gd への追加フィールド（既存フィールド群の末尾、_last_exam_outcome宣言の後）

# --- 工房強化・ショップ（workshop）関連フィールド ---
var _can_purchase_permanent: bool = false  # 🔵 FR-009
var _purchased_upgrade_counts: Dictionary = {}  # 🔵 FR-010 Dictionary[StringName, int]
var _upgrade_masters: Dictionary = {}  # 🔵 FR-011 Dictionary[StringName, UpgradeMaster]
```

```gdscript
# get_state()への追加（既存"exam_turn_limit"キーの直後）
"can_purchase_permanent": _can_purchase_permanent,  # 🔵 FR-017
```

`_purchased_upgrade_counts`・`_upgrade_masters`は`get_state()`に含めない（FR-017は`can_purchase_permanent`のみを要求。購入回数照会はタスク010の`get_purchased_count()`で代替し、NFR-102の内部Dictionary非露出を満たす。Plan設計フェーズで確定済み）。

```gdscript
# reset_for_test()への追加（既存"_last_exam_outcome = ExamOutcome.Value.CONTINUE"の後）
_can_purchase_permanent = false  # 🔵 FR-014
_purchased_upgrade_counts = {}  # 🔵 FR-014
_upgrade_masters = {}  # 🔵 FR-014
```

```gdscript
# game_state.gd側テスト専用API（既存テスト専用APIの末尾に追加、1行委譲パターン）
## 🔵 テスト専用。can_purchase_permanentを工房強化画面の開閉操作を介さず直接注入する（FR-012）
func _set_can_purchase_permanent_for_test(value: bool) -> void:
	GameStateTestSupport.set_can_purchase_permanent(self, value)

## 🔵 テスト専用。purchased_upgrade_countsをapply_upgrade()を介さず直接注入する（FR-013）
func _set_purchased_upgrade_counts_for_test(counts: Dictionary) -> void:
	GameStateTestSupport.set_purchased_upgrade_counts(self, counts)
```

```gdscript
# atelier/autoload/game_state_test_support.gd側（実装本体、既存set_alchemy_slot_count()等と同型）
static func set_can_purchase_permanent(state: GameStateScript, value: bool) -> void:
	if not guard("_set_can_purchase_permanent_for_test"):
		return
	state._can_purchase_permanent = value

## 内部正本は独立コピーとして保持する（既存set_current_daily_order()等と同方針）
static func set_purchased_upgrade_counts(state: GameStateScript, counts: Dictionary) -> void:
	if not guard("_set_purchased_upgrade_counts_for_test"):
		return
	state._purchased_upgrade_counts = counts.duplicate()
```

`_upgrade_masters`用のテスト専用APIは不要（🟡 Plan設計フェーズの判断: `apply_upgrade(upgrade)`は引数で直接`UpgradeMaster`を受け取り`_upgrade_masters`を内部参照しないため、テストは`UpgradeMaster.new()`を直接構築して渡せば足りる。`_upgrade_masters`はタスク010の`load_workshop_master_data()`結果保持専用）。

## Test Strategy

`docs/dev/plans/workshop/acceptance-criteria.md` AC-017準拠。

- [ ] `GameState.reset_for_test()`直後、`_can_purchase_permanent`が`false`、`_purchased_upgrade_counts`・`_upgrade_masters`が空`Dictionary`になっている
- [ ] `_set_can_purchase_permanent_for_test(true)`呼び出し後、`GameState.get_state().can_purchase_permanent`が`true`になる
- [ ] `_set_purchased_upgrade_counts_for_test({...})`呼び出し後、注入した内容が反映される（`apply_upgrade()`が未実装のこの時点では、フィールド直接参照や後続タスクのテストで検証してもよい）
- [ ] `_set_purchased_upgrade_counts_for_test()`呼び出し後、引数の`Dictionary`を呼び出し元で変更しても内部状態が汚染されない（`duplicate()`の防御的コピー確認）
- [ ] `get_state()`が返す`Dictionary`を呼び出し元で変更しても`GameState`内部の正本データが汚染されない（`can_purchase_permanent`はプリミティブ`bool`のため元々コピーだが、既存の防御的コピー原則との一貫性確認）
- [ ] **異常系**: リリースビルド相当のガード下（`OS.is_debug_build() == false`相当）では、テスト専用APIが`GameStateTestSupport.guard()`により無効化される（既存パターンの踏襲確認。`push_error`が呼ばれ状態変更されないことを確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`（`_seed_masters`等の既存フィールド宣言スタイル、`get_state()`実装L80-113、`reset_for_test()`実装L681-711）、`atelier/autoload/game_state_test_support.gd`（`set_seed_inventory()`/`set_alchemy_slot_count()`等の1行委譲パターン）
- 実装のヒント: 既存フィールド・既存テスト専用APIの完全な横展開。新規ロジックの発明は不要
- 注意事項: `UpgradeMaster`型（タスク001）が先に定義されている必要がある（`_upgrade_masters: Dictionary`の型コメントで参照するため）。本タスクは`apply_upgrade()`本体を実装しない（タスク008/009の対象）

## Files

- 変更: `atelier/autoload/game_state.gd`, `atelier/autoload/game_state_test_support.gd`
- テスト: `atelier/tests/integration/test_game_state_workshop_fields.gd`
