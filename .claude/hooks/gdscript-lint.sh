#!/usr/bin/env bash
# PostToolUse(Write|Edit)フック: 編集した.gdファイル1つだけにgdformat --check / gdlintを実行する。
# 対象はCI(.github/workflows/ci.yml)と同じ atelier/{features,shared,autoload}/ 配下のみ。
# 違反時は終了コード2 + stderrでClaudeへフィードバックする（自動整形はしない）。
# gdtoolkit等が無い環境では作業を止めないよう、警告のみ出して終了コード0で抜ける。

set -u

warn() {
	echo "[gdscript-lint hook] $*" >&2
	exit 0
}

# gdtoolkit自体がPythonで動くため、JSON解析にもPythonを使う（jqはWindows環境に無いことが多い）
python_bin=""
for candidate in python python3; do
	if command -v "$candidate" > /dev/null 2>&1 && "$candidate" -c "" > /dev/null 2>&1; then
		python_bin="$candidate"
		break
	fi
done
if [ -z "$python_bin" ]; then
	warn "Pythonが見つからないためlintをスキップしました"
fi

file_path=$("$python_bin" -c '
import json, sys
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
print((data.get("tool_input") or {}).get("file_path") or "", end="")
' | tr -d '\r')

case "$file_path" in
	*.gd) ;;
	*) exit 0 ;;
esac

# Windows形式(C:\a\b)とPOSIX形式(/c/a/b)のどちらでも判定できるよう区切りを正規化する
normalized_path=${file_path//\\//}
case "$normalized_path" in
	*/atelier/features/* | */atelier/shared/* | */atelier/autoload/*) ;;
	*) exit 0 ;;
esac

if [ ! -f "$file_path" ]; then
	exit 0
fi

if ! command -v gdformat > /dev/null 2>&1 || ! command -v gdlint > /dev/null 2>&1; then
	warn "gdtoolkit(gdformat/gdlint)が見つからないためlintをスキップしました（pip install -r .github/workflows/requirements.txt）"
fi

# atelier/.gdlintrc をCIと同じく解決させるため、atelier/をカレントにして実行する
atelier_dir="${normalized_path%%/atelier/*}/atelier"
cd "$atelier_dir" 2> /dev/null || warn "atelier/ディレクトリに移動できませんでした: $atelier_dir"

format_output=$(gdformat --check "$file_path" 2>&1)
format_status=$?
lint_output=$(gdlint "$file_path" 2>&1)
lint_status=$?

if [ "$format_status" -eq 0 ] && [ "$lint_status" -eq 0 ]; then
	exit 0
fi

{
	echo "GDScriptの静的チェックで違反が見つかりました: $file_path"
	if [ "$format_status" -ne 0 ]; then
		echo "--- gdformat --check ---"
		echo "$format_output"
		echo "（gdformat --diff \"$file_path\" で差分を確認し、意図通りなら当該ファイルにのみ gdformat を適用してください）"
	fi
	if [ "$lint_status" -ne 0 ]; then
		echo "--- gdlint ---"
		echo "$lint_output"
	fi
} >&2
exit 2
