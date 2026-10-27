class_name TraitTagText

## 🔵 Issue #66。素材の特性タグを画面表示用の文字列にする。
## 中間素材は同じタグを重複して持つ（凝縮）ため、「holy, holy」ではなく「holy×2」とまとめて表示する。

const SEPARATOR := ", "
const COUNT_FORMAT := "%s×%d"


## タグの初出順を保ったまま、重複をまとめた表示文字列を返す。空配列なら空文字
static func format(trait_tags: Array[StringName]) -> String:
	var order: Array[StringName] = []
	var counts: Dictionary = {}
	for tag in trait_tags:
		if not counts.has(tag):
			order.append(tag)
			counts[tag] = 0
		counts[tag] += 1

	var parts: PackedStringArray = []
	for tag in order:
		var count: int = counts[tag]
		parts.append(String(tag) if count == 1 else COUNT_FORMAT % [String(tag), count])
	return SEPARATOR.join(parts)
