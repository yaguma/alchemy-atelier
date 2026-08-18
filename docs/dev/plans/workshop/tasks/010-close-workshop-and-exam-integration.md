---
id: "010"
title: "close_workshop/get_purchased_count/load_workshop_master_dataを実装し昇格試験成功パスに統合する"
status: pending
priority: 3
dependencies: ["006", "007"]
estimated_complexity: medium
---

# Task: close_workshop/get_purchased_count/load_workshop_master_dataを実装し昇格試験成功パスに統合する

## Goal

`GameState.close_workshop()`・`get_purchased_count()`・`load_workshop_master_data()`を実装し（FR-015, FR-018, FR-011, FR-005）、既存`_commit_exam_success()`（rank-up planで実装済み、`atelier/autoload/game_state.gd` L575-593）の冒頭に`_can_purchase_permanent = true`を追加して昇格試験成功と工房強化フラグ開放を接続する（FR-110）。

## Interfaces

```gdscript
# atelier/autoload/game_state.gd への追加メソッド

## 🔵 FR-015, FR-111。恒久投資購入可否フラグを閉じる
func close_workshop() -> void:
	_can_purchase_permanent = false


## 🔵 FR-018。未購入（キー未登録）の場合は0を返す
func get_purchased_count(upgrade_id: StringName) -> int:
	return _purchased_upgrade_counts.get(upgrade_id, 0)


## 🔵 FR-005, FR-011, FR-115。res://data/upgrades/ から UpgradeMaster をロードし
## _upgrade_masters に格納する（既存load_alchemy_master_data()の重複ID検知パターンを踏襲）。
## 🔴 BootSceneからの呼び出し配線自体は本plan外。GameState側にAPIとして用意するのみ
func load_workshop_master_data() -> void:
	var upgrades := MasterDataLoader.load_all(&"upgrades")

	var upgrade_masters: Dictionary = {}
	for u in upgrades:
		var upgrade := u as UpgradeMaster
		if upgrade_masters.has(upgrade.id):
			push_error("工房強化アップグレードのIDが重複しています: %s" % upgrade.id)
			return
		upgrade_masters[upgrade.id] = upgrade
	_upgrade_masters = upgrade_masters
```

```gdscript
# _commit_exam_success()（既存L575-593）への変更差分。関数冒頭に1行追加するのみ、
# 既存の3分岐（次ランクなし=ゲームクリア/次ランクマスター欠落/正常昇格）は無変更
func _commit_exam_success() -> void:
	_can_purchase_permanent = true  # 🔵 FR-110（新規追加行。既存3分岐すべてに一律適用される位置）
	var next_rank_id := RankProgression.get_next_rank_id(_current_rank_id)
	# 以下、既存コード（現行L576-593）は無変更
	...
```

FR-110は「昇格試験が成功した場合」とのみ規定し分岐を限定していないため、関数冒頭（分岐前）に置くことで既存3分岐すべてに一律適用するのが最も安全側の解釈（🔵 Plan設計フェーズで確定済み）。

## Test Strategy

`docs/dev/plans/workshop/acceptance-criteria.md` AC-004（フラグ遷移部分）, AC-005, AC-015（`load_workshop_master_data()`部分）準拠。

- [ ] `close_workshop()`呼び出し後、`_can_purchase_permanent`が`false`になる（`true`の状態から呼んでも`false`のまま呼んでも冪等に`false`になる）
- [ ] `get_purchased_count(upgrade_id)`: 未購入の`upgrade_id`に対して`0`を返す
- [ ] `get_purchased_count(upgrade_id)`: `apply_upgrade()`で1回購入済みの`upgrade_id`に対して`1`を返す（タスク008/009完了後の統合確認）
- [ ] **正常系**: 昇格試験成功確定操作（`_set_exam_state_for_test()`等でSUCCESS確定直前の状態を再現した上で`commit_exam_outcome()`を呼ぶ、既存rank-up planのテストパターン踏襲）の直後、`_can_purchase_permanent == true`になる
- [ ] **正常系**: 上記の直後に`close_workshop()`を呼ぶと`_can_purchase_permanent == false`に戻る
- [ ] **異常系**: 昇格試験が失敗（FAILURE）確定した場合は`_can_purchase_permanent`が`true`にならない（`_commit_exam_failure()`側は無変更であることの回帰確認）
- [ ] **正常系**: `load_workshop_master_data()`呼び出し後、`_upgrade_masters`にタスク006で作成した5件が登録される
- [ ] **異常系**: `res://data/upgrades/`に`UpgradeMaster.id`が重複する`.tres`が存在する場合（テストフィクスチャで再現）、`push_error`が発生し`_upgrade_masters`が更新されない（既存`load_alchemy_master_data()`の重複ID検知と同型の回帰確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`の`load_alchemy_master_data()`（L143-153、重複ID検知パターンの直接の踏襲元）、`_commit_exam_success()`（L575-593、変更対象）、`atelier/tests/integration/test_game_state_exam_outcome.gd`（`_set_exam_state_for_test()`を使ったSUCCESS確定テストの既存パターン）
- 実装のヒント: `close_workshop()`/`get_purchased_count()`は1〜2行の単純な実装。`load_workshop_master_data()`は`load_alchemy_master_data()`をほぼそのまま横展開する
- 注意事項: `_commit_exam_success()`への変更は関数冒頭に1行追加するのみとし、既存3分岐のロジック（rank-up planで実装済み、直近のPR #24で修正済みの幽霊試験状態バグ対応を含む）には一切手を加えないこと。`MasterDataLoader`の`&"upgrades"`カテゴリ対応（タスク006）が先に完了している必要がある

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_workshop_commit_exam_integration.gd`
