class_name AlchemyPreviewPanel
extends Control

## 調合のライブプレビュー（品質・発現特性・見込み貢献度・見込み報酬）を表示する
## 表示専用コンポーネント（US-101, AC-007）。
## 🔵 計算パイプライン（QualityCalculator〜DeliveryResolver）は本コンポーネントの責務外であり、
## GameStateにもDomain層にも一切依存しない。算出済みの値をshow_preview()で受け取って表示するのみ。

const EMPTY_PLACEHOLDER := "-"
const TRAITS_NONE_TEXT := "なし"
const ORDER_MATCHED_TEXT := "指定合致"
const TRAIT_SEPARATOR := ", "
# 🟡 Issue #66（FR-713）。中間素材は納品しないため見込み値の代わりに出す暫定表記（ui-design未確定）
const INTERMEDIATE_VALUE_TEXT := "中間素材として在庫に追加（納品しない）"
const INTERMEDIATE_TRAITS_FORMAT := "凝縮特性: %s"

var _order_matched: bool = false
var _quality_text: String = ""
var _traits_text: String = ""
var _value_text: String = ""

# 🟡 garden-alchemy-visual-refresh Plan タスク008
@onready var _preview_panel: PanelContainer = %PreviewPanel
@onready var _quality_label: Label = %QualityLabel
@onready var _traits_label: Label = %TraitsLabel
@onready var _value_label: Label = %ValueLabel
@onready var _order_match_label: Label = %OrderMatchLabel


func _ready() -> void:
	# 🟡 プレビュー全体を1枚のカードで囲む。make_panel_stylebox()はキャッシュ済みの単一インスタンス
	UiTheme.apply_panel_style(_preview_panel)
	for label: Label in [_quality_label, _traits_label, _value_label, _order_match_label]:
		UiTheme.apply_pixel_font(label)
	if _quality_text.is_empty():
		show_empty()
	else:
		_apply_display()


## 計算済みの見込み値を表示する。order_matchedがtrueの場合は指定合致を示す視覚的強調を行う。
## 🔵 activated_traitsは発現済みのタグのみを受け取る前提（FR-404により「あと1個」ヒントは表示しない）。
func show_preview(
	quality_score: int,
	activated_traits: Array[StringName],
	final_contribution: float,
	final_reward: float,
	order_matched: bool
) -> void:
	_quality_text = format_quality(quality_score)
	_traits_text = format_traits(activated_traits)
	_value_text = format_value(final_contribution, final_reward)
	_order_matched = order_matched
	_apply_display()


## 中間素材レシピのプレビュー。納品しないため見込み貢献度・報酬の代わりに在庫へ加わる旨を出す
## （🔵 Issue #66、FR-713-002）。trait_tagsは凝縮後のタグ（同じタグの重複を含む）を受け取る
func show_intermediate_preview(quality_score: int, trait_tags: Array[StringName]) -> void:
	_quality_text = format_quality(quality_score)
	var traits_text := TraitTagText.format(trait_tags)
	_traits_text = (
		INTERMEDIATE_TRAITS_FORMAT % (TRAITS_NONE_TEXT if traits_text.is_empty() else traits_text)
	)
	_value_text = INTERMEDIATE_VALUE_TEXT
	_order_matched = false
	_apply_display()


## レシピ未選択・0投入時の初期/空表示に戻す（AC-007異常系）。🔵
func show_empty() -> void:
	_quality_text = "品質: %s" % EMPTY_PLACEHOLDER
	_traits_text = "発現特性: %s" % EMPTY_PLACEHOLDER
	_value_text = ("見込み貢献度: %s / 見込み報酬: %s" % [EMPTY_PLACEHOLDER, EMPTY_PLACEHOLDER])
	_order_matched = false
	_apply_display()


## 現在プレビュー中の内容が指定依頼に合致しているかを返す。🔵
func is_order_matched() -> bool:
	return _order_matched


## 品質スコアの表示文字列を組み立てる。🔵 txt-preview-quality
static func format_quality(quality_score: int) -> String:
	return "品質: %d" % quality_score


## 発現特性一覧の表示文字列を組み立てる。未発現時は「なし」を表示する。🔵 txt-preview-traits
static func format_traits(activated_traits: Array[StringName]) -> String:
	if activated_traits.is_empty():
		return "発現特性: %s" % TRAITS_NONE_TEXT
	var tags: PackedStringArray = []
	for tag in activated_traits:
		tags.append(String(tag))
	return "発現特性: %s" % TRAIT_SEPARATOR.join(tags)


## 見込み貢献度・見込み報酬の表示文字列を組み立てる。🔵 txt-preview-value
static func format_value(final_contribution: float, final_reward: float) -> String:
	return "見込み貢献度: %.1f / 見込み報酬: %.1f" % [final_contribution, final_reward]


# 🔵 NFR-201: 指定合致は色だけでなく専用テキストの表示/非表示でも判別できるようにする
func _apply_display() -> void:
	if _quality_label == null:
		return
	_quality_label.text = _quality_text
	_traits_label.text = _traits_text
	_value_label.text = _value_text
	_order_match_label.text = ORDER_MATCHED_TEXT
	_order_match_label.visible = _order_matched
	_order_match_label.self_modulate = UiTheme.COLOR_ALCHEMY_PREVIEW_ORDER_MATCHED
