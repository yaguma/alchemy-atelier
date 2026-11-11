"""classify_pr.classify() の単体テスト（標準ライブラリのunittestのみで動く）。

実行: python3 -m unittest discover -s .claude/skills/merge-readiness/scripts
"""

import unittest

from classify_pr import AUTO, BLOCKED, HUMAN, ChangedFile, classify, parse_checkboxes

GOOD_BODY = """## Test plan
- [x] 回帰テスト追加（修正前に失敗することを確認済み）
- [x] 全GdUnit4テストパス
"""


def _f(path: str, status: str = "M", added: int = 10, deleted: int = 0) -> ChangedFile:
    return ChangedFile(path=path, status=status, added=added, deleted=deleted)


def _rules(result) -> set[str]:
    return {f.rule for f in result.findings}


class TestAutoMerge(unittest.TestCase):
    def test_ロジック変更にテストが伴いCIが通れば自動マージ可(self):
        files = [
            _f("atelier/features/alchemy/logic/quality_calculator.gd"),
            _f("atelier/tests/unit/features/alchemy/test_quality_calculator.gd"),
        ]
        result = classify(files, GOOD_BODY, "pass")
        self.assertEqual(result.verdict, AUTO)

    def test_ドキュメントだけの変更は自動マージ可(self):
        result = classify([_f("docs/design/x.md", added=900)], GOOD_BODY, "pass")
        self.assertEqual(result.verdict, AUTO)
        self.assertEqual(result.reviewable_lines, 0)


class TestHumanReview(unittest.TestCase):
    def test_UI変更で描画の証拠がなければ人の確認(self):
        files = [_f("atelier/features/garden/ui/garden_screen.gd"), _f("atelier/tests/integration/test_garden_screen.gd")]
        result = classify(files, GOOD_BODY, "pass")
        self.assertEqual(result.verdict, HUMAN)
        self.assertIn("no-visual-evidence", _rules(result))

    def test_ui配下以外のシーン変更もUI変更とみなす(self):
        files = [_f("atelier/shared/debug/debug_panel.tscn"), _f("atelier/tests/integration/test_debug_panel.gd")]
        self.assertIn("no-visual-evidence", _rules(classify(files, GOOD_BODY, "pass")))

    def test_UI変更でも描画E2Eのチェック済み項目があれば証拠ありとみなす(self):
        files = [_f("atelier/features/garden/ui/garden_screen.gd"), _f("atelier/tests/integration/test_garden_screen.gd")]
        body = GOOD_BODY + "- [x] `uv run --project tests/e2e_mcp atelier-e2e` 13/13成功\n"
        result = classify(files, body, "pass")
        self.assertEqual(result.verdict, AUTO)

    def test_未チェックの検証項目があれば人の確認(self):
        files = [_f("atelier/features/alchemy/logic/a.gd"), _f("atelier/tests/unit/features/alchemy/test_a.gd")]
        body = GOOD_BODY + "- [ ] 目視確認（未実施）\n"
        result = classify(files, body, "pass")
        self.assertEqual(result.verdict, HUMAN)
        self.assertEqual(result.unverified_items, ["目視確認（未実施）"])

    def test_コード変更にテストがなければ人の確認(self):
        result = classify([_f("atelier/features/alchemy/logic/a.gd")], GOOD_BODY, "pass")
        self.assertIn("no-test", _rules(result))

    def test_危険領域に触れたら人の確認(self):
        for path in [
            "atelier/project.godot",
            "atelier/features/save_load/logic/x.gd",
            ".github/workflows/ci.yml",
            "atelier/data/recipes/a.tres",
        ]:
            with self.subTest(path=path):
                result = classify([_f(path), _f("atelier/tests/unit/test_x.gd")], GOOD_BODY, "pass")
                self.assertIn("sensitive", _rules(result))
                self.assertEqual(result.verdict, HUMAN)

    def test_CI未確定なら人の確認(self):
        result = classify([_f("docs/a.md")], GOOD_BODY, "pending")
        self.assertEqual(result.verdict, HUMAN)

    def test_PR本文がなければ人の確認(self):
        result = classify([_f("docs/a.md")], "", "pass")
        self.assertIn("no-body", _rules(result))


class TestBoundary(unittest.TestCase):
    def _files(self, lines: int) -> list[ChangedFile]:
        return [_f("atelier/features/alchemy/logic/a.gd", added=lines - 1), _f("atelier/tests/unit/test_a.gd", added=1)]

    def test_差分400行ちょうどは自動マージ可(self):
        self.assertEqual(classify(self._files(400), GOOD_BODY, "pass").verdict, AUTO)

    def test_差分401行は人の確認(self):
        result = classify(self._files(401), GOOD_BODY, "pass")
        self.assertIn("too-large", _rules(result))

    def test_uidファイルは行数に数えない(self):
        files = self._files(400) + [_f("atelier/features/alchemy/logic/a.gd.uid", added=50)]
        self.assertEqual(classify(files, GOOD_BODY, "pass").verdict, AUTO)


class TestBlocked(unittest.TestCase):
    def test_CI失敗はブロック(self):
        self.assertEqual(classify([_f("docs/a.md")], GOOD_BODY, "fail").verdict, BLOCKED)

    def test_テストファイル削除はブロック(self):
        files = [_f("atelier/tests/unit/test_a.gd", status="D", added=0, deleted=30)]
        result = classify(files, GOOD_BODY, "pass")
        self.assertEqual(result.verdict, BLOCKED)

    def test_do_skip追加はブロック(self):
        files = [_f("atelier/features/a.gd"), _f("atelier/tests/unit/test_a.gd")]
        test_diff = "+++ b/atelier/tests/unit/test_a.gd\n+func test_x(do_skip := true) -> void:\n"
        self.assertEqual(classify(files, GOOD_BODY, "pass", test_diff=test_diff).verdict, BLOCKED)

    def test_テストケースの純減は人の確認(self):
        files = [_f("atelier/features/a.gd"), _f("atelier/tests/unit/test_a.gd")]
        test_diff = "-func test_a() -> void:\n-func test_b() -> void:\n+func test_c() -> void:\n"
        self.assertIn("test-func-removed", _rules(classify(files, GOOD_BODY, "pass", test_diff=test_diff)))

    def test_リネームによる同数の入れ替えは純減とみなさない(self):
        files = [_f("atelier/features/a.gd"), _f("atelier/tests/unit/test_a.gd")]
        test_diff = "-func test_a() -> void:\n+func test_a_renamed() -> void:\n"
        self.assertNotIn("test-func-removed", _rules(classify(files, GOOD_BODY, "pass", test_diff=test_diff)))


class TestParseCheckboxes(unittest.TestCase):
    def test_チェック済みと未チェックを分ける(self):
        checked, unchecked = parse_checkboxes("- [x] A\n* [X] B\n- [ ] C\n本文\n")
        self.assertEqual(checked, ["A", "B"])
        self.assertEqual(unchecked, ["C"])

    def test_HTMLコメント内のチェックボックスは数えない(self):
        checked, unchecked = parse_checkboxes("<!--\n- [ ] 例\n-->\n- [x] A\n")
        self.assertEqual(checked, ["A"])
        self.assertEqual(unchecked, [])


if __name__ == "__main__":
    unittest.main()
