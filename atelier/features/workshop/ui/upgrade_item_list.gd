class_name UpgradeItemList
extends Control

## 1タブ分（恒久 or 消耗）のアイテム一覧を表示し、購入操作の起点となる表示専用コンポーネント。
## GameStateに依存せず、整形済み配列をsetup()で受け取る（SeedInventoryListと同型）。
## フィルタ・ソート（is_permanentでの絞り込み、価格降順→id昇順）は呼び出し元（WorkshopScreen）の
## 責務とし、本コンポーネントは受け取った配列をそのままの順序で描画するのみ（CON-002: モード引数を
## 持たない設計をList自体も踏襲する）。

signal purchase_requested(upgrade_id: StringName)  # 🔵

const UpgradeItemRowScene = preload("res://features/workshop/ui/upgrade_item_row.tscn")

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


## 🔴 コードレビュー指摘対応。UpgradeItemListはextends Controlであり、素のControlの
## get_minimum_size()は常に(0,0)を返す（子の内容を自動集計しない）。workshop_screen.tscnの
## 親VBoxContainerはこれをそのまま採用し本コンポーネントの行を0高さにしてしまい、
## _entry_container内の実際のアイテム行は表示上あふれ出るだけで、行の確保領域自体は0のまま
## PermanentList/ConsumableList同士やToastLabel等とほぼ同じY座標に重なって描画される
## 不具合があった（plant_slot_view.gdと同根）。_entry_containerのcombined_minimum_sizeを
## そのまま転送することで、親に正しい行高を伝える
func _get_minimum_size() -> Vector2:
	if _entry_container == null:
		return Vector2.ZERO
	return _entry_container.get_combined_minimum_size()


func _ready() -> void:
	_entry_container.add_theme_constant_override("separation", UiTheme.SPACING_LIST_ENTRY)
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
