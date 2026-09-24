class_name AlchemyScreenExam

## AlchemyScreenの昇格試験UI（残りターン表示・ターンを進めるボタン・案内メッセージ）に関する
## 定数・計算ロジックを切り出したstatic適用クラス。AlchemyScreen本体が500行ルールを超過した
## ための責務分割であり、振る舞いは分割前と同一
## （docs/dev/plans/ui-polish/reports/verify-2026-09-23.md参照）。

const EXAM_TURN_LABEL_FORMAT := "残り%dターン"  # 🟡 FR-106、書式は新規決定

# 🔴 文言はAI推論による新規決定（design doc上もTBD、CON-003に基づき本Planで確定）
const EXAM_MESSAGES := {
	&"exam_started": "昇格試験が始まりました！",
	&"exam_success": "昇格試験に合格しました！",
	&"exam_failure": "昇格試験に失敗しました…",
}

# 🟡 FR-205, FR-206, FR-301。文言はAI推論による新規決定（CON-003で本Plan内確定が許容）
const EXAM_GUIDANCE_MESSAGE := "投入できる素材がありません。「ターンを進める」で試験を進行できます。"


## 試験の残りターン数を算出する。負値にならないようクランプする。🔵 FR-106
static func remaining_exam_turns(exam_turn_limit: int, exam_elapsed_turn: int) -> int:
	return maxi(exam_turn_limit - exam_elapsed_turn, 0)


## in_exam状態に応じて試験用UI（残りターン表示・ターンを進めるボタン・案内メッセージ）を更新する。
## 🔴 実装判断。呼び出し元（AlchemyScreen._refresh_exam_ui()）が既に取得済みのstateを再利用し、
## 追加のGameState.get_state()呼び出しは行わない（NFR-001）
static func refresh_exam_ui(
	state: Dictionary,
	recipe_masters: Dictionary,
	exam_turn_label: Label,
	advance_exam_turn_button: Button,
	end_turn_button: Button,
	exam_guidance_label: Label
) -> void:
	var in_exam: bool = state["in_exam"]  # 🔵
	exam_turn_label.visible = in_exam  # 🔵 FR-201, FR-202
	advance_exam_turn_button.visible = in_exam  # 🔵 FR-201, FR-202, FR-406
	end_turn_button.visible = not in_exam  # 🔵 FR-203, FR-204
	if in_exam:
		var remaining := remaining_exam_turns(state["exam_turn_limit"], state["exam_elapsed_turn"])  # 🔵
		exam_turn_label.text = EXAM_TURN_LABEL_FORMAT % remaining  # 🟡

	var inventory: Array = state["inventory"]
	var unlocked_recipe_ids: Array = state["unlocked_recipe_ids"]
	# 🔴 コードレビュー指摘対応。unlocked_recipe_idsが非空でも、対応するRecipeMasterが
	# recipe_masters（マスターデータ未ロード等）に見つからなければAlchemyScreen._rebuild_recipe_options()が
	# その全IDをスキップしドロップダウンが実質空になる。「解禁レシピ0」と同じデッドロックのため、
	# 「実際に選択可能なレシピが1件も無い」ことで判定する（FR-205, FR-206）
	var has_selectable_recipe := _has_resolvable_recipe(recipe_masters, unlocked_recipe_ids)
	var should_show_guidance := in_exam and (inventory.is_empty() or not has_selectable_recipe)
	exam_guidance_label.visible = should_show_guidance
	if should_show_guidance:
		exam_guidance_label.text = EXAM_GUIDANCE_MESSAGE


## unlocked_recipe_idsのうち1件でもrecipe_masters（🔵AlchemyScreen._refresh()で更新済み）から
## 解決可能かを返す。🔴 コードレビュー指摘対応。AlchemyScreen._rebuild_recipe_options()の解決ロジックと
## 判定基準を一致させる（片方だけ更新されて乖離するのを防ぐ）
static func _has_resolvable_recipe(recipe_masters: Dictionary, unlocked_recipe_ids: Array) -> bool:
	for recipe_id in unlocked_recipe_ids:
		if recipe_masters.get(recipe_id) is RecipeMaster:
			return true
	return false
