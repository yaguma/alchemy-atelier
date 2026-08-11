---
id: "012"
title: "GameStateに庭関連の内部状態とマスターデータ読み込みを追加する"
status: done
priority: 3
dependencies: ["001", "002", "003", "004", "005", "010"]
estimated_complexity: high
---

# Task: GameStateに庭関連の内部状態とマスターデータ読み込みを追加する

## Goal

`autoload/game_state.gd`（Phase1スタブ、現状`current_phase`/`gold`/`current_turn`のみ）に庭関連の内部フィールド・マスターデータ読み込み・`get_state()`の防御的コピー拡張・`reset_for_test()`の拡張を追加する。`plant_seed`/`harvest`/`advance_turn_growth`の3メソッド本体は後続タスク013〜015で実装する（本タスクでは土台のみ）。

## Interfaces

```gdscript
# autoload/game_state.gd（既存ファイルに追記・変更）

# --- 追加フィールド ---
var _garden_state: GardenState = GardenState.new()                      # 🔵 FR-001
var _seed_inventory: Array[Dictionary] = []  # [{seed_id: StringName, count: int}]  # 🔵 用語集
var _inventory: Array[MaterialInstance] = []                            # 🔵 用語集
var _seed_masters: Dictionary = {}      # Dictionary[StringName, SeedMaster]        # 🔵
var _material_masters: Dictionary = {}  # Dictionary[StringName, MaterialMaster]    # 🔵
var _material_instance_seq: int = 0     # 🔴 instance_id採番用（新規補完）
var _garden_slot_count: int = GameBalance.GARDEN_SLOT_COUNT  # 🔵 FR-006「実行時権威」の暫定置き場
                                                                # （player.permanent_upgrades本体は別plan未実装のため、
                                                                # 本plan内では庭専用フィールドとして仮に保持する）

## res://data/materials/ から SeedMaster/MaterialMaster をロードし _seed_masters/_material_masters に格納する。
## MasterDataLoader.validate_references が false の場合は push_error し、マスターは空のまま
## 🔴 BootSceneからの呼び出し配線自体は本plan外（MainScene統合と同様の理由）。GameState側にAPIとして用意するのみ
func load_garden_master_data() -> void:
	pass

## テスト分離専用。既存のreset_for_test()に庭関連フィールドの初期化を追加する
func reset_for_test() -> void:
	pass

## テスト専用。実.tresロードを介さずSeedMaster/MaterialMasterを直接注入する
## 🟡 CON-005（テスト用フィクスチャが必要）への対応
func _set_masters_for_test(seeds: Dictionary, materials: Dictionary) -> void:
	pass

## AC-014対応: garden_state/seed_inventory/inventoryを含め、内部状態への参照を漏らさないディープコピーを返す
func get_state() -> Dictionary:
	pass
```

## Test Strategy

- [ ] **正常系**: `reset_for_test()`直後、`get_state().garden_state.plants`が空配列である（AC-011）
- [ ] **正常系**: `reset_for_test()`直後、`get_state().seed_inventory`が`GameBalance.INITIAL_SEED_ID`/`INITIAL_SEED_COUNT`と一致する初期セットになっている（AC-011）
- [ ] **正常系**: `load_garden_master_data()`実行後、実際に`res://data/materials/`（タスク009で作成済み）から`seed_herb`/`seed_ore`の`SeedMaster`がロードされ、内部に保持される（間接的に`_set_masters_for_test`を経由しない検証用の統合テストとして`tests/integration/`に配置する）
- [ ] **異常系（防御的コピー）**: `get_state().garden_state.plants.append(...)`のように戻り値を変更しても、再度`get_state()`を呼んだ結果には反映されない（内部状態が変化していない）（FR-403, AC-014）
- [ ] **異常系（防御的コピー）**: `get_state().inventory`に対する変更が`GameState`内部の`_inventory`に影響しない
- [ ] **境界値**: `reset_for_test()`を複数回連続で呼んでも庭関連フィールドが正しく初期状態に戻り続ける（累積バグがないことの確認）

## Implementation Notes

- 参照すべき既存コード: `atelier/autoload/game_state.gd`（既存の`get_state()`実装パターン: 辞書リテラル生成→`duplicate(true)`。ただし本タスクの`garden_state`/`inventory`はカスタム`RefCounted`型を含むため、既存パターンをそのまま流用せず`GardenState.clone()`/`MaterialInstance.clone()`を明示的に呼ぶ必要がある。`.claude/rules/state-management.md`「`get_state()`戻り値の防御的コピー必須」を参照）
- 実装のヒント: `get_state()`は以下のような形になる:
  ```gdscript
  func get_state() -> Dictionary:
  	return {
  		"current_phase": _current_phase,
  		"gold": _gold,
  		"current_turn": _current_turn,
  		"garden_state": _garden_state.clone(),
  		"seed_inventory": _seed_inventory.duplicate(true),
  		"inventory": _inventory.map(func(m: MaterialInstance) -> MaterialInstance: return m.clone()),
  	}
  ```
- 注意事項: `reset_for_test()`は既存の`assert(OS.is_debug_build(), ...)`ガードパターンを踏襲する。`load_garden_master_data()`は`BootScene`から呼ばれる想定のAPIとして用意するが、`BootScene`側の実際の配線（`boot.gd`の変更）は本plan外（MainScene統合と同様、別task扱い）

## Files

- 変更: `atelier/autoload/game_state.gd`
- テスト: `atelier/tests/integration/test_game_state_garden.gd`
