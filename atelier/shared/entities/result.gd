# 🔴 core-systems.mdはPlanting.plant/Harvest.harvestの戻り値がResult型である旨のみ記載し、
# Result自体の実体は定義していないため、本ファイルで汎用の成功/失敗コンテナとして新規補完する。
class_name Result
extends RefCounted

var success: bool = false
var value: Variant = null
var error_code: StringName = &""


## 🔴 成功結果を生成する（value省略時はnullのまま）。呼び出し元はvalue取得後に必ず型ガードすること
static func ok(p_value: Variant = null) -> Result:
	var result := Result.new()
	result.success = true
	result.value = p_value
	return result


## 🔴 失敗結果を生成する。error_codeはドメインごとに呼び出し側が定義する規約（例: &"slot_full"）に従う
static func fail(p_error_code: StringName) -> Result:
	var result := Result.new()
	result.success = false
	result.error_code = p_error_code
	return result
