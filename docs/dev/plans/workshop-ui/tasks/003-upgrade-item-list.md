---
id: "003"
title: "UpgradeItemListコンポーネントを新規作成する"
status: done
priority: 2
dependencies: ["002"]
estimated_complexity: medium
---

# Task: UpgradeItemListコンポーネントを新規作成する

## Goal

1タブ分（恒久投資 or 消耗投資）のアイテム一覧を表示する`UpgradeItemList`（`Control`継承）を新規作成する。整形済み（フィルタ・ソート済み）の`UpgradeMaster`配列を`setup()`で受け取り、`UpgradeItemRow`を全行破棄→再生成する。行からの購入要求を`purchase_requested(upgrade_id)`として上位へ中継する（FR-004, FR-005, NFR-001, NFR-301）。

## Interfaces

```gdscript
# atelier/features/workshop/ui/upgrade_item_list.gd
class_name UpgradeItemList
extends Control

## 1タブ分（恒久 or 消耗）のアイテム一覧を表示し、購入操作の起点となる表示専用コンポーネント。
## GameStateに依存せず、整形済み配列をsetup()で受け取る（SeedInventoryListと同型）。
## フィルタ・ソート（is_permanentでの絞り込み、価格降順→id昇順）は呼び出し元（WorkshopScreen）の
## 責務とし、本コンポーネントは受け取った配列をそのままの順序で描画するのみ（CON-002: モード引数を
## 持たない設計をList自体も踏襲する）。

signal purchase_requested(upgrade_id: StringName)  # 🔵

const UpgradeItemRowScene = preload("res://features/workshop/ui/upgrade_item_row.tscn")
const ENTRY_SEPARATION := 8

var _upgrades: Array[UpgradeMaster] = []
var _gold: int = 0
var _purchased_counts: Dictionary = {}  # Dictionary[StringName, int]
var _locked: bool = false

@onready var _entry_container: VBoxContainer = %EntryContainer

## upgrades: 表示順に整列済み（呼び出し元がFR-004のフィルタ・ソートを完了させている前提）。
## locked: このタブ全体を強制disabled表示にするか（恒久投資タブ×can_purchase_permanent=false時にtrue）
func setup(
	upgrades: Array[UpgradeMaster], gold: int, purchased_counts: Dictionary, locked: bool
) -> void:  # 🔵
	_upgrades = upgrades
	_gold = gold
	_purchased_counts = purchased_counts
	_locked = locked
	_rebuild()

## 現在表示しているアイテム行の件数を返す（テスト用）。🔵 SeedInventoryList.get_entry_count()踏襲
func get_entry_count() -> int:
	if _entry_container == null:
		return 0
	return _entry_container.get_child_count()

func _ready() -> void:
	_entry_container.add_theme_constant_override("separation", ENTRY_SEPARATION)
	_rebuild()

func _rebuild() -> void:  # 🔵 NFR-001「全行破棄→再生成」パターン
	# setup()がシーンツリー追加前に呼ばれた場合は、_ready()で改めて構築する
	if _entry_container == null:
		return

	for child in _entry_container.get_children():
		_entry_container.remove_child(child)
		child.queue_free()

	for upgrade in _upgrades:
		_add_entry_row(upgrade)

func _add_entry_row(upgrade: UpgradeMaster) -> void:
	var row: UpgradeItemRow = UpgradeItemRowScene.instantiate()
	row.name = "UpgradeItem_%s" % upgrade.id
	_entry_container.add_child(row)
	var already_purchased_count: int = _purchased_counts.get(upgrade.id, 0)
	row.setup(upgrade, _gold, already_purchased_count, _locked)
	row.purchase_pressed.connect(_on_row_purchase_pressed)

func _on_row_purchase_pressed(upgrade_id: StringName) -> void:
	purchase_requested.emit(upgrade_id)
```

`.tscn`構造: `Control`（ルート） → `VBoxContainer(%EntryContainer)`（`UpgradeItemRow`を動的に格納）。`seed_inventory_list.tscn`と同型構造。

## Test Strategy

- [ ] `setup([])`（空配列）で初期化した場合、`get_entry_count()`が0を返す
- [ ] `setup([upgrade_a, upgrade_b])`で初期化した場合、`get_entry_count()`が2を返し、渡した配列の順序通りに行が生成される（行の`name`が`"UpgradeItem_%s" % upgrade.id`になっていることで順序を確認する）
- [ ] `setup()`を複数回呼び出した場合、直前の行がすべて破棄され新しい配列の内容だけが残る（全行破棄→再生成、NFR-001）
- [ ] いずれかの行の購入ボタンを押下すると、`UpgradeItemList.purchase_requested`シグナルが対応する`upgrade_id`を引数に発行される（行の`purchase_pressed`が正しく中継されることを確認する）
- [ ] `setup(upgrades, gold, purchased_counts, locked=true)`で構築した場合、生成された各行が`locked=true`で`setup()`されている（各行の購入ボタンが強制disabledになっていることを`is_purchase_button_disabled()`で確認する）
- [ ] エッジケース: `_ready()`より前に`setup()`が呼ばれても（シーンツリー未追加の状態）クラッシュせず、`_ready()`後に正しく再構築される（`SeedInventoryList._rebuild()`のnullガードと同型の挙動を確認する）

## Implementation Notes

- 参照すべき既存コード: `atelier/features/garden/ui/seed_inventory_list.gd`（List層の完全な実装パターン。`_rebuild()`のnullガード・全破棄ロジック・行生成後の`add_child()`→`setup()`→シグナル接続の順序を厳密に踏襲する）
- 実装のヒント: `UpgradeItemRow`の`@onready`変数は`add_child()`によるシーンツリー追加後の`_ready()`で解決されるため、`setup()`は必ず`add_child()`の後に呼ぶこと（`SeedEntryRow`と同一契約、先に呼ぶとラベル参照がnullのままクラッシュする）
- 注意事項: 本コンポーネント自身はソート・フィルタを行わない（`WorkshopScreen`側の責務）。GameStateには一切依存しない

## Files

- 新規: `atelier/features/workshop/ui/upgrade_item_list.gd`
- 新規: `atelier/features/workshop/ui/upgrade_item_list.tscn`
- テスト: `atelier/tests/unit/features/workshop/test_upgrade_item_list.gd`
