class_name UpgradeItemRow
extends HBoxContainer

## アイテム一覧の1行分を表示するコンポーネント。UpgradeItemListから動的に生成・破棄される。
## GameStateにもDomain層（PurchaseValidator）にも依存しない表示専用コンポーネント
## （SeedEntryRow/GuildDeliveryResultRowと同型）。

signal purchase_pressed(upgrade_id: StringName)  # 🔵 親（UpgradeItemList）が上位へ中継する起点

const LABEL_PURCHASE := "購入する"  # 🟡 workshop-shop.mdワイヤーフレーム準拠の暫定文言
const LABEL_GOLD_SHORTAGE := "ゴールド不足"  # 🟡 同上
const LABEL_MAX_REACHED := "購入済み"  # 🟡 同上

var _upgrade_id: StringName = &""

@onready var _name_label: Label = %NameLabel  # 🔵
@onready var _price_label: Label = %PriceLabel  # 🔵
@onready var _purchase_button: Button = %PurchaseButton  # 🔵 btn-purchase-{upgrade_id}相当


func _ready() -> void:  # 🔵 自ノードsignalのため_exit_tree()でのdisconnect不要
	_purchase_button.pressed.connect(_on_purchase_pressed)


## upgrade: 表示対象。gold: 現在の所持ゴールド。already_purchased_count: 購入済み回数。
## locked: true の場合、gold/countの結果に関わらずボタンを強制disabledにする（FR-403、
## 恒久投資タブが非活性の間に恒久投資アイテムへ渡すためのフラグ）。
## 判定優先順位は「購入済み上限到達」＞「ゴールド不足」＞「タブロック」＞「購入可能」（🟡
## AC群が組合せケース＝ゴールド不足かつ購入済み等を明示しないための実装判断。「買い切った」は
## 所持ゴールドに関わらず不変の事実であることを根拠に最優先とする）
func setup(upgrade: UpgradeMaster, gold: int, already_purchased_count: int, locked: bool) -> void:  # 🔵 FR-204, FR-205, FR-206, FR-403, FR-404
	_upgrade_id = upgrade.id
	_name_label.text = upgrade.name
	_price_label.text = "%d G" % upgrade.price

	var max_reached := already_purchased_count >= upgrade.max_purchase_count
	var gold_short := gold < upgrade.price

	if max_reached:
		_purchase_button.text = LABEL_MAX_REACHED
		_purchase_button.disabled = true
	elif gold_short:
		_purchase_button.text = LABEL_GOLD_SHORTAGE
		_purchase_button.disabled = true
	else:
		_purchase_button.text = LABEL_PURCHASE
		_purchase_button.disabled = locked  # 🔵 FR-403: 買える状態でもtab非活性なら強制disabled


## 現在のボタンラベルを返す（テスト用)。🟡 SeedEntryRowに同種の公開ゲッターがないための新規補完
func get_purchase_button_text() -> String:
	return _purchase_button.text


## 現在のボタンのdisabled状態を返す（テスト用)。🟡 同上
func is_purchase_button_disabled() -> bool:
	return _purchase_button.disabled


func _on_purchase_pressed() -> void:
	purchase_pressed.emit(_upgrade_id)
