class_name ExamOutcomeOverlay
extends Control

## 昇格試験の成功/失敗確定時に表示する結果演出オーバーレイ（ui-polish Plan タスク014）。
## promotion-exam.md L86「画面全体が赤み/金色に色づく」を、フルスクリーンのColorRectによる
## 半透明ウォッシュで実現する。MainSceneがAlchemyScreenの中継シグナル(exam_result_pending)を
## 受けてshow_outcome()を呼び、確認ボタン押下でacknowledgedを発行するまで画面遷移をブロックする
## （他Featureのui/への直接参照禁止のため、AlchemyScreenからは直接参照しない。architecture.md参照）。

signal acknowledged  # 🔵 プレイヤーが結果を確認した合図（確認ボタン押下）

# 🔴 文言はEXAM_MESSAGES（alchemy_screen.gd）のトースト文言をそのまま踏襲する新規決定
const SUCCESS_MESSAGE_TEXT := "昇格試験に合格しました！"
const FAILURE_MESSAGE_TEXT := "昇格試験に失敗しました…"
const CONFIRM_BUTTON_TEXT := "確認"

# 🔴 新規色トークンは追加せず、既存のUiTheme色を成功=金/失敗=赤の意味で再利用する
# （design-guide.md「新しい色が必要な場合」参照。COLOR_TRAIT_HIGHLIGHTは特性発現ハイライトと
# 同じ金色、COLOR_TOAST_WARNINGはトースト警告と同じ赤系）
const SUCCESS_WASH_COLOR := UiTheme.COLOR_TRAIT_HIGHLIGHT
const FAILURE_WASH_COLOR := UiTheme.COLOR_TOAST_WARNING
const WASH_ALPHA := 0.35

@onready var _wash: ColorRect = %WashColorRect
@onready var _content_panel: PanelContainer = %ContentPanel
@onready var _message_label: Label = %MessageLabel
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	UiTheme.apply_panel_style(_content_panel)
	UiTheme.apply_pixel_font(_message_label)
	UiTheme.apply_pixel_font(_confirm_button)
	ButtonStyleApplier.apply_button_style(_confirm_button, UiTheme.ButtonVariant.PRIMARY)
	_confirm_button.text = CONFIRM_BUTTON_TEXT
	_confirm_button.pressed.connect(_on_confirm_pressed)
	visible = false


## SUCCESS/FAILUREのみ想定。CONTINUE/未確定値が渡された場合はpush_errorし、
## 表示状態(visible)・文言・ウォッシュ色のいずれも変更しない（AlchemyScreen側は
## CONTINUEでexam_result_pending自体を発行しないため、通常到達しない防御的分岐）
func show_outcome(outcome: ExamOutcome.Value) -> void:
	match outcome:
		ExamOutcome.Value.SUCCESS:
			_message_label.text = SUCCESS_MESSAGE_TEXT
			_wash.color = Color(SUCCESS_WASH_COLOR, WASH_ALPHA)
		ExamOutcome.Value.FAILURE:
			_message_label.text = FAILURE_MESSAGE_TEXT
			_wash.color = Color(FAILURE_WASH_COLOR, WASH_ALPHA)
		_:
			push_error("ExamOutcomeOverlay.show_outcome: 想定外のoutcomeです: %s" % outcome)
			return

	visible = true
	UiEffects.play_fade_in(self, UiTheme.ANIM_DURATION_FADE_SCREEN, UiTheme.ANIM_EASE_DEFAULT)


func _on_confirm_pressed() -> void:
	visible = false
	acknowledged.emit()
