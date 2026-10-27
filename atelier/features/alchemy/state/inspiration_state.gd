class_name InspirationState
extends RefCounted

## 熟練ひらめきのランタイム状態（🔵 Issue #67、FR-714-001/008）。GameStateが1つ保持する。
## ひらめいたレシピはラン間で持ち越さないため、新規ゲーム開始時に新しいインスタンスへ置き換える。

var mastery: Dictionary = {}  # StringName(recipe_id) -> int。レシピごとの調合回数（ひらめくと0に戻る）
var inspired_recipe_ids: Array[StringName] = []  # このランでひらめいたレシピ


## 🔵 GameState.get_state()の防御的コピー要件に合わせた複製。値はint/StringNameのため浅い複製で十分
func clone() -> InspirationState:
	var cloned := InspirationState.new()
	cloned.mastery = mastery.duplicate()
	cloned.inspired_recipe_ids = inspired_recipe_ids.duplicate()
	return cloned
