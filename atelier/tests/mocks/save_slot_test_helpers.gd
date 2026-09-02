## 🔴 コードレビュー指摘対応。_cleanup_slots()（5ファイル）と_corrupt_slot_file()（3ファイル）が
## 同一実装のまま個別に複製されており、SaveService._slot_path()やセーブJSONのキー名を変更した際に
## 修正漏れが起きうる状態だったため、1箇所へ統合する。class_nameを持たない補助スクリプトのため、
## 利用側はconst+preloadで参照する（.claude/rules/architecture.md「公開APIパターン」の例外運用。
## tests/mocks/daily_order_pool.gdと同じパターン）。

## 全スロットのセーブファイルを削除する。before_test()/after_test()での後始末用。
static func cleanup_slots() -> void:
	for slot in range(SaveService.SLOT_COUNT):
		var path: String = SaveService._slot_path(slot)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## 保存済みファイルのgold値を1文字だけ書き換え、JSONとしては正当なまま
## チェックサムのみ不一致になる破損を作る。呼び出し元はGdUnitTestSuiteのassert_int()を
## 使うため、テストスイート側のインスタンスをselfとして受け取る。
static func corrupt_slot_file(suite: GdUnitTestSuite, slot: int) -> void:
	var path: String = SaveService._slot_path(slot)
	var read_file := FileAccess.open(path, FileAccess.READ)
	var text := read_file.get_as_text()
	read_file.close()

	var marker := '"gold":'
	var pos := text.find(marker) + marker.length()
	suite.assert_int(pos).is_greater(marker.length() - 1)
	var replacement := "9" if text[pos] != "9" else "8"
	var corrupted := text.substr(0, pos) + replacement + text.substr(pos + 1)

	var write_file := FileAccess.open(path, FileAccess.WRITE)
	write_file.store_string(corrupted)
	write_file.close()
