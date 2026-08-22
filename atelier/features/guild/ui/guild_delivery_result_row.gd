class_name GuildDeliveryResultRow
extends HBoxContainer

## 納品結果リストの1項目（調合物名・品質・発現特性・指定依頼合致・貢献度・報酬）を表示する
## 表示専用コンポーネント（FR-003, FR-201, FR-202）。
## 🔵 GameStateにもDomain層（DeliveryResolver等）にも一切依存しない。呼び出し元がProductInstance/
## DeliveryResultから取り出したプリミティブ値をsetup()で受け取って表示するのみ。

const ORDER_MATCHED_TEXT := "指定合致"
const TRAITS_NONE_TEXT := "なし"
const TRAIT_SEPARATOR := ", "

# 🔴 コードレビュー指摘対応。AlchemyPreviewPanel/MaterialEntryRowと同名の
# QualityLabel/TraitsLabel/ValueLabel/OrderMatchLabelは、本コンポーネントがAlchemyScreen配下に
# 埋め込まれた際に範囲指定なしのfind_child()が誤ったノードを拾う脆さを生むため、Delivery接頭辞で一意化する
@onready var _name_label: Label = %DeliveryNameLabel
@onready var _quality_label: Label = %DeliveryQualityLabel
@onready var _traits_label: Label = %DeliveryTraitsLabel
@onready var _order_match_label: Label = %DeliveryOrderMatchLabel
@onready var _value_label: Label = %DeliveryValueLabel


## 納品結果1件の表示内容を設定する。add_child()後に呼ぶこと（@onready参照の解決後である必要がある）。
## 🔵 MaterialEntryRow.setup()と同一契約
func setup(
	recipe_name: String,
	quality_score: int,
	activated_traits: Array[StringName],
	order_matched: bool,
	final_contribution: float,
	final_reward: float
) -> void:
	_name_label.text = recipe_name
	_quality_label.text = format_quality(quality_score)
	_traits_label.text = format_traits(activated_traits)
	_value_label.text = format_value(final_contribution, final_reward)
	# 🔵 NFR-201: 指定合致は色だけでなく専用テキストの表示/非表示でも判別できるようにする
	_order_match_label.text = ORDER_MATCHED_TEXT
	_order_match_label.visible = order_matched


## 品質スコアの表示文字列を組み立てる。🔵 AlchemyPreviewPanel.format_quality踏襲
static func format_quality(quality_score: int) -> String:
	return "品質: %d" % quality_score


## 発現特性一覧の表示文字列を組み立てる。未発現時は「なし」を表示する。🔵 同上
static func format_traits(activated_traits: Array[StringName]) -> String:
	if activated_traits.is_empty():
		return "発現特性: %s" % TRAITS_NONE_TEXT
	var tags: PackedStringArray = []
	for tag in activated_traits:
		tags.append(String(tag))
	return "発現特性: %s" % TRAIT_SEPARATOR.join(tags)


## 確定済みの貢献度・報酬の表示文字列を組み立てる。
## 🔵 プレビューではなく納品結果（確定値）のため「見込み」は付けない
static func format_value(final_contribution: float, final_reward: float) -> String:
	return "貢献度: %.1f / 報酬: %.1f" % [final_contribution, final_reward]
