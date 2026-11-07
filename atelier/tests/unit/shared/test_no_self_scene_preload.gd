extends GdUnitTestSuite

## 🔴 Issue #91の回帰テスト。スクリプトが自分自身をアタッチしたシーン（同名の.tscn）を
## preloadすると「シーン → スクリプト → 同じシーン」の循環参照になり、エディタがシーンを先に
## 読み込む場面（ファイルシステムのプレビュー生成等）で`Parse Error: Busy`が出る。
## ゲーム実行時・ヘッドレスのテストでは再現しないため、ソースを走査して形そのものを禁止する。

const SCAN_ROOTS: Array[String] = [
	"res://features",
	"res://shared",
	"res://scenes",
	"res://autoload",
]


func test_スクリプトが自分と同名のtscnをpreloadしていない() -> void:
	var offenders: Array[String] = []
	for root in SCAN_ROOTS:
		_collect_offenders(root, offenders)

	(
		assert_array(offenders)
		. override_failure_message("自分自身のシーンをpreloadしているスクリプトがある（load()を使う）: %s" % [offenders])
		. is_empty()
	)


func _collect_offenders(dir_path: String, offenders: Array[String]) -> void:
	for sub_dir in DirAccess.get_directories_at(dir_path):
		_collect_offenders(dir_path.path_join(sub_dir), offenders)
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() != "gd":
			continue
		var script_path := dir_path.path_join(file_name)
		var own_scene_path := script_path.get_basename() + ".tscn"
		var source := FileAccess.get_file_as_string(script_path)
		if source.contains('preload("%s")' % own_scene_path):
			offenders.append(script_path)
