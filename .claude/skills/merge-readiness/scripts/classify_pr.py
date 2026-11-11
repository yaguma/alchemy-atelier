#!/usr/bin/env python3
"""PRの差分とPR本文から「人がコードを見ずにマージしてよいか」の機械的な判定を出す。

判定は3段階:
  BLOCKED                 マージしてはいけない（CI失敗・テスト削除・skip追加など）
  HUMAN_REVIEW_REQUIRED   人の確認が要る（危険領域・検証の抜け・大きな差分など）
  AUTO_MERGE_OK           機械的に見る限り、人がコードを見なくてよい

このスクリプトが見るのは「差分の形」と「PR本文に書かれた検証の証拠」だけで、
コードの正しさは見ない。正しさはCI（GdUnit4）とAIレビュー（/code-review）が担う。
最終判定は merge-readiness スキルが、この結果・CIの結果・AIレビューの結果を合わせて出す。

使い方:
  python3 classify_pr.py --base origin/main --head HEAD [--body pr_body.md] [--ci pass|fail|pending|unknown]
終了コード: 0=AUTO_MERGE_OK / 1=HUMAN_REVIEW_REQUIRED / 2=BLOCKED / 3=実行エラー
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass, field

AUTO = "AUTO_MERGE_OK"
HUMAN = "HUMAN_REVIEW_REQUIRED"
BLOCKED = "BLOCKED"
_RANK = {AUTO: 0, HUMAN: 1, BLOCKED: 2}

# 人が判断すべき領域。ここに触れたPRは、テストやレビューが通っていても人に回す。
# 理由は「壊れたときの影響が大きい」か「正しさがゲームデザイン上の判断で、テストで決まらない」のどちらか。
SENSITIVE_PATTERNS: dict[str, str] = {
    ".github/*": "CI・リポジトリ設定（検証の仕組みそのもの）",
    ".claude/settings.json": "Claude Codeの権限・フック設定",
    ".claude/hooks/*": "Claude Codeのフック",
    ".claude/skills/merge-readiness/*": "マージ判定の仕組みそのもの",
    ".mcp.json": "MCPサーバー設定",
    "atelier/project.godot": "プロジェクト設定（Autoload・入力・描画設定）",
    "atelier/export_presets.cfg": "エクスポート設定",
    "atelier/addons/*": "外部アドオン",
    "atelier/autoload/save_service.gd": "セーブデータの読み書き（データ損失のリスク）",
    "atelier/features/save_load/*": "セーブデータの読み書き（データ損失のリスク）",
    "atelier/shared/constants/game_balance.gd": "バランス数値（正しさがゲームデザインの判断）",
    "atelier/data/*": "マスターデータ（正しさがゲームデザインの判断）",
}

# 描画しないと分からない変更。GdUnit4は--headlessで描画しないため、見た目の証拠が別に要る。
UI_PATTERNS = [
    "atelier/features/*/ui/*",
    "atelier/shared/ui/*",
    "atelier/shared/theme/*",
    "atelier/scenes/*",
    "atelier/assets/*",
    "atelier/*.tscn",  # 上記以外の場所のシーン（shared/debug/等）も描画に関わる
]

# 振る舞いを持つコード。変更するならテストの追加・変更が伴うはず。
CODE_PATTERNS = [
    "atelier/features/*.gd",
    "atelier/shared/*.gd",
    "atelier/autoload/*.gd",
    "atelier/scenes/*.gd",
]

TEST_PATTERNS = ["atelier/tests/*", "tests/e2e_mcp/*"]

# 行数を数えないファイル（自動生成・バイナリ・ドキュメント）
IGNORE_FOR_SIZE = ["*.uid", "*.import", "*.png", "*.ttf", "*.lock", "docs/*", "*.md"]

# この行数を超える差分は、AIレビューの見落としが増えるため人に回す
MAX_REVIEWABLE_LINES = 400

# PR本文の「見た目を確認した」証拠として認めるキーワード（チェック済み項目にあること）
VISUAL_EVIDENCE_KEYWORDS = ["atelier-e2e", "godot-visual-check", "描画E2E", "スクリーンショット"]

_CHECKBOX = re.compile(r"^\s*[-*]\s*\[( |x|X)\]\s*(.+)$")
_TEST_FUNC = re.compile(r"^[-+]\s*func\s+test_")
_HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)


@dataclass
class ChangedFile:
    path: str
    status: str  # A / M / D / R...
    added: int
    deleted: int


@dataclass
class Finding:
    verdict: str
    rule: str
    message: str


@dataclass
class Result:
    verdict: str
    findings: list[Finding] = field(default_factory=list)
    unverified_items: list[str] = field(default_factory=list)
    reviewable_lines: int = 0
    changed_files: int = 0


def _match(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(path, p) for p in patterns)


def parse_checkboxes(body: str) -> tuple[list[str], list[str]]:
    """PR本文のチェックボックスを (チェック済み, 未チェック) に分ける。"""
    checked: list[str] = []
    unchecked: list[str] = []
    body = _HTML_COMMENT.sub("", body)  # PRテンプレートの説明コメント内の例は数えない
    for line in body.splitlines():
        m = _CHECKBOX.match(line)
        if not m:
            continue
        (checked if m.group(1) in "xX" else unchecked).append(m.group(2).strip())
    return checked, unchecked


def count_removed_test_funcs(diff_text: str) -> tuple[int, int]:
    """テストファイルの差分から (削除された test_ 関数の数, 追加された数) を数える。"""
    removed = added = 0
    for line in diff_text.splitlines():
        if line.startswith(("---", "+++")):
            continue
        if _TEST_FUNC.match(line):
            if line.startswith("-"):
                removed += 1
            else:
                added += 1
    return removed, added


def classify(
    files: list[ChangedFile],
    body: str,
    ci: str,
    test_diff: str = "",
    code_diff: str = "",
) -> Result:
    """差分・PR本文・CI結果から判定を出す（純粋関数）。"""
    findings: list[Finding] = []

    def add(verdict: str, rule: str, message: str) -> None:
        findings.append(Finding(verdict, rule, message))

    # --- CI ---
    if ci == "fail":
        add(BLOCKED, "ci", "CIが失敗している")
    elif ci != "pass":
        add(HUMAN, "ci", f"CIの結果が確定していない（{ci}）。成功を確認してから判定し直す")

    paths = [f.path for f in files]
    test_files = [f for f in files if _match(f.path, TEST_PATTERNS)]
    code_files = [f for f in files if _match(f.path, CODE_PATTERNS) and not _match(f.path, TEST_PATTERNS)]
    ui_files = [f for f in files if _match(f.path, UI_PATTERNS)]

    # --- テストを弱める変更 ---
    deleted_tests = [f.path for f in test_files if f.status.startswith("D") and f.path.endswith(".gd")]
    if deleted_tests:
        add(BLOCKED, "test-deleted", f"テストファイルが削除されている: {', '.join(deleted_tests)}")
    removed_funcs, added_funcs = count_removed_test_funcs(test_diff)
    if removed_funcs > added_funcs:
        add(
            HUMAN,
            "test-func-removed",
            f"テストケースが純減している（削除{removed_funcs}件・追加{added_funcs}件）。意図した削除か人が確認する",
        )
    if re.search(r"^\+.*\bdo_skip\b", test_diff, re.MULTILINE):
        add(BLOCKED, "test-skip", "テストにdo_skipが追加されている（testing.md 禁止事項）")
    if re.search(r"^\+\s*print\(", code_diff, re.MULTILINE):
        add(HUMAN, "print", "本番コードにprint()が追加されている（coding-style.md 禁止事項）")

    # --- 危険領域 ---
    for pattern, reason in SENSITIVE_PATTERNS.items():
        hit = [p for p in paths if fnmatch.fnmatch(p, pattern)]
        if hit:
            add(HUMAN, "sensitive", f"{reason}: {', '.join(hit)}")

    # --- コード変更にテストが伴っているか ---
    if code_files and not test_files:
        add(HUMAN, "no-test", "コードを変更しているのにテストの追加・変更がない")

    # --- 見た目の証拠 ---
    checked, unchecked = parse_checkboxes(body)
    if ui_files:
        has_visual = any(k in item for item in checked for k in VISUAL_EVIDENCE_KEYWORDS)
        if not has_visual:
            add(
                HUMAN,
                "no-visual-evidence",
                "UI・シーン・アセットを変更しているが、描画E2E（atelier-e2e）または"
                "godot-visual-checkで確認したというチェック済み項目がPR本文にない",
            )

    # --- 未検証項目 ---
    if not body.strip():
        add(HUMAN, "no-body", "PR本文（Test plan）がなく、何を検証したか分からない")
    elif not checked and not unchecked:
        add(HUMAN, "no-test-plan", "PR本文にTest planのチェックボックスがない")
    if unchecked:
        add(HUMAN, "unverified", f"未実施の検証項目が{len(unchecked)}件ある")

    # --- 差分の大きさ ---
    reviewable = sum(f.added + f.deleted for f in files if not _match(f.path, IGNORE_FOR_SIZE))
    if reviewable > MAX_REVIEWABLE_LINES:
        add(HUMAN, "too-large", f"差分が{reviewable}行あり、AIレビューで見切れる大きさ（{MAX_REVIEWABLE_LINES}行）を超える")

    verdict = max((f.verdict for f in findings), key=_RANK.__getitem__, default=AUTO)
    return Result(
        verdict=verdict,
        findings=findings,
        unverified_items=unchecked,
        reviewable_lines=reviewable,
        changed_files=len(files),
    )


# ---------------------------------------------------------------------------
# git から入力を集める部分（副作用あり）
# ---------------------------------------------------------------------------


def _git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def collect_files(base: str, head: str) -> list[ChangedFile]:
    rng = f"{base}...{head}"
    status: dict[str, str] = {}
    for line in _git("diff", "--name-status", "--no-renames", rng).splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            status[parts[-1]] = parts[0]
    files: list[ChangedFile] = []
    for line in _git("diff", "--numstat", "--no-renames", rng).splitlines():
        added, deleted, path = line.split("\t", 2)
        files.append(
            ChangedFile(
                path=path,
                status=status.get(path, "M"),
                added=int(added) if added != "-" else 0,
                deleted=int(deleted) if deleted != "-" else 0,
            )
        )
    return files


def collect_diff(base: str, head: str, pathspecs: list[str]) -> str:
    return _git("diff", "--no-renames", f"{base}...{head}", "--", *pathspecs)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--body", help="PR本文を書いたファイル（省略時は本文なしとして扱う）")
    parser.add_argument("--ci", default="unknown", choices=["pass", "fail", "pending", "unknown"])
    args = parser.parse_args()

    try:
        files = collect_files(args.base, args.head)
        test_diff = collect_diff(args.base, args.head, ["atelier/tests"])
        code_diff = collect_diff(
            args.base, args.head, ["atelier/features", "atelier/shared", "atelier/autoload", "atelier/scenes"]
        )
        body = ""
        if args.body:
            with open(args.body, encoding="utf-8") as fh:
                body = fh.read()
    except (subprocess.CalledProcessError, OSError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3

    result = classify(files, body, args.ci, test_diff=test_diff, code_diff=code_diff)
    out = asdict(result)
    print(json.dumps(out, ensure_ascii=False, indent=2))
    return _RANK[result.verdict]


if __name__ == "__main__":
    sys.exit(main())
