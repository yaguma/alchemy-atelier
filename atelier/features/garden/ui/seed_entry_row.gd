class_name SeedEntryRow
extends PanelContainer

## 種一覧の1行分を表示するコンポーネント。SeedInventoryListから動的に生成・破棄される。
## 🔴 コードレビュー指摘対応で新規追加。以前は.new()でノードをコード生成していたが、
## ui-components.md「シーン外でControlノードをnew()して管理する」の禁止事項に反していたため
## 専用シーン化した。
## 🟡 garden-alchemy-visual-refresh Plan タスク007: ルートをHBoxContainerからPanelContainerに
## 変更し、ドット絵カードパネルの背景を敷けるようにした。既存の3要素はContent（HBoxContainer）
## へ移したため直下パスでは取得できなくなった。呼び出し元でrow.get_node("PlantButton")のような
## 直下パス参照をしている場合はfind_child()系に更新が必要（既存テストの参照更新済み）

signal plant_pressed(seed_id: StringName)

var _seed_id: StringName = &""

@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _plant_button: Button = %PlantButton


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.make_panel_stylebox())
	_plant_button.pressed.connect(_on_plant_pressed)
	ButtonStyleApplier.apply_button_style(_plant_button, UiTheme.ButtonVariant.PRIMARY)
	_name_label.add_theme_font_override("font", UiTheme.FONT_PIXEL_JP)
	_count_label.add_theme_font_override("font", UiTheme.FONT_PIXEL_JP)
	_plant_button.add_theme_font_override("font", UiTheme.FONT_PIXEL_JP)


## 表示名・在庫数を設定する。行のnodeのnameは呼び出し元がSeedEntry_<seed_id>形式で設定する。🔵
func setup(seed_id: StringName, display_name: String, count: int) -> void:
	_seed_id = seed_id
	_name_label.text = display_name
	_count_label.text = "x%d" % count
	_plant_button.disabled = count <= 0


func _on_plant_pressed() -> void:
	plant_pressed.emit(_seed_id)
