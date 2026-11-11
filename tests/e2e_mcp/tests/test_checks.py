"""checks.pyの判定ロジックの単体テスト（Godot・MCP不要）。"""

from atelier_e2e.checks import (
    ControlInfo,
    Rect,
    check_container_children_not_collapsed,
    check_has_backdrop,
    check_logs_clean,
    check_no_overlap,
    check_not_empty,
    check_within_viewport,
)

VIEWPORT = Rect(0, 0, 1280, 720)


def control(
    path: str,
    rect: Rect,
    *,
    parent_is_container: bool = True,
    clipped: bool = False,
    has_visible_children: bool = True,
) -> ControlInfo:
    return ControlInfo(path, "Control", rect, parent_is_container, clipped, has_visible_children)


class TestRect:
    def test_辺が接しているだけなら重ならない(self) -> None:
        assert not Rect(0, 0, 100, 100).overlaps(Rect(100, 0, 100, 100))

    def test_一部でも重なれば重なりとみなす(self) -> None:
        assert Rect(0, 0, 100, 100).overlaps(Rect(99, 99, 10, 10))

    def test_座標誤差の範囲なら内側とみなす(self) -> None:
        assert VIEWPORT.contains(Rect(0, 0, 1280.3, 720.3))

    def test_get_ui_elements形式から作れる(self) -> None:
        rect = Rect.from_godot({"position": {"x": 1, "y": 2}, "size": {"x": 3, "y": 4}})
        assert rect == Rect(1, 2, 3, 4)


class TestCheckWithinViewport:
    def test_画面内なら違反なし(self) -> None:
        assert check_within_viewport([control("/a", Rect(0, 0, 1280, 720))], VIEWPORT) == []

    def test_下端からはみ出したら違反(self) -> None:
        violations = check_within_viewport([control("/a/Quit", Rect(520, 664.6, 240, 82))], VIEWPORT)
        assert len(violations) == 1
        assert "/a/Quit" in violations[0]

    def test_はみ出した子孫は親だけ報告する(self) -> None:
        controls = [
            control("/a/Panel/Label", Rect(-62, 187, 124, 24)),
            control("/a/Panel", Rect(-72, 177, 144, 158)),
        ]
        violations = check_within_viewport(controls, VIEWPORT)
        assert len(violations) == 1
        assert "/a/Panel " in violations[0]

    def test_名前の前方一致だけの別ノードは子孫扱いしない(self) -> None:
        controls = [control("/a/Panel", Rect(-1, 0, 10, 10)), control("/a/Panel2", Rect(-1, 0, 10, 10))]
        assert len(check_within_viewport(controls, VIEWPORT)) == 2

    def test_祖先で切り取られるControlは対象外(self) -> None:
        controls = [control("/a/Scroll/Item", Rect(0, 900, 100, 50), clipped=True)]
        assert check_within_viewport(controls, VIEWPORT) == []

    def test_大きさ0のControlは対象外(self) -> None:
        assert check_within_viewport([control("/a", Rect(-10, 0, 0, 0))], VIEWPORT) == []


class TestCheckContainerChildrenNotCollapsed:
    def test_中身のあるContainerの子が0に潰れたら違反(self) -> None:
        violations = check_container_children_not_collapsed([control("/Grid/Slot_0", Rect(0, 256, 0, 0))])
        assert len(violations) == 1

    def test_高さだけ0でも違反(self) -> None:
        assert len(check_container_children_not_collapsed([control("/V/Row", Rect(0, 0, 1280, 0))])) == 1

    def test_子を持たない区切り用Controlは対象外(self) -> None:
        controls = [control("/V/Spacer", Rect(0, 0, 0, 0), has_visible_children=False)]
        assert check_container_children_not_collapsed(controls) == []

    def test_親がContainerでなければ対象外(self) -> None:
        controls = [control("/Root/Overlay", Rect(0, 0, 0, 0), parent_is_container=False)]
        assert check_container_children_not_collapsed(controls) == []


class TestCheckNoOverlap:
    def test_重ならなければ違反なし(self) -> None:
        assert check_no_overlap({"slot": Rect(0, 276, 144, 158)}, {"preview": Rect(0, 438, 1280, 100)}) == []

    def test_重なれば組ごとに違反(self) -> None:
        violations = check_no_overlap(
            {"slot": Rect(-72, 177, 144, 158)},
            {"recipe": Rect(0, 192, 1280, 32), "preview": Rect(0, 260, 1280, 100)},
        )
        assert len(violations) == 2


class TestCheckNotEmpty:
    def test_大きさ0を検出する(self) -> None:
        assert check_not_empty({"a": Rect(0, 0, 0, 0), "b": Rect(0, 0, 1, 1)}) == [
            "大きさが0になっている: a (0, 0, 0x0)"
        ]


class TestCheckHasBackdrop:
    def test_覆う背景があれば違反なし(self) -> None:
        result = {"found": True, "rect": [0, 106, 1280, 102], "covering": ["/root/Main/TabBarPanel"]}
        assert check_has_backdrop("TabBar", result) == []

    def test_覆う背景がなければ違反(self) -> None:
        result = {"found": True, "rect": [0, 106, 1280, 82], "covering": []}
        assert len(check_has_backdrop("TabBar", result)) == 1

    def test_対象が見つからなければ違反(self) -> None:
        assert "見つからない" in check_has_backdrop("TabBar", {"found": False})[0]


class TestCheckLogsClean:
    def test_infoだけなら違反なし(self) -> None:
        assert check_logs_clean([{"level": "info", "text": "hello"}]) == []

    def test_errorとwarningを検出する(self) -> None:
        lines = [{"level": "error", "text": "boom"}, {"level": "warning", "text": "careful"}]
        assert len(check_logs_clean(lines)) == 2

    def test_godot_aiヘルパー自身のログは無視する(self) -> None:
        lines = [{"level": "warning", "text": "[godot_ai game_helper] registered mcp capture\n"}]
        assert check_logs_clean(lines) == []
