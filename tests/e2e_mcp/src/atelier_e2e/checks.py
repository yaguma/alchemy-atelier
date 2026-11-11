"""描画中のUIから取った値を判定する純粋関数群。

MCPやGodotには依存しないので、pytestで単体テストできる（tests/test_checks.py）。
判定はスクリーンショットの画素比較ではなく、Controlの矩形と状態の値で行う
（見た目の小さな変更でテストが壊れないようにするため。Issue #93）。
各関数は違反内容の文字列のリストを返し、空なら合格とする。
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from typing import Any

# 浮動小数の座標誤差（Containerの割り付けで小数が出る）を違反とみなさない幅
EPSILON_PX = 0.5

# godot-aiのゲーム側ヘルパー自身が出す起動ログ。不具合ではないので判定から除く
IGNORED_LOG_PREFIXES = ("[godot_ai game_helper]",)


@dataclass(frozen=True)
class Rect:
    x: float
    y: float
    w: float
    h: float

    @property
    def right(self) -> float:
        return self.x + self.w

    @property
    def bottom(self) -> float:
        return self.y + self.h

    @property
    def center(self) -> tuple[float, float]:
        return (self.x + self.w / 2, self.y + self.h / 2)

    def is_empty(self) -> bool:
        return self.w <= EPSILON_PX or self.h <= EPSILON_PX

    def contains(self, other: Rect) -> bool:
        return (
            other.x >= self.x - EPSILON_PX
            and other.y >= self.y - EPSILON_PX
            and other.right <= self.right + EPSILON_PX
            and other.bottom <= self.bottom + EPSILON_PX
        )

    def overlaps(self, other: Rect) -> bool:
        """辺が接しているだけの場合は重なりとみなさない。"""
        return (
            self.x < other.right - EPSILON_PX
            and other.x < self.right - EPSILON_PX
            and self.y < other.bottom - EPSILON_PX
            and other.y < self.bottom - EPSILON_PX
        )

    def __str__(self) -> str:
        return f"({self.x:g}, {self.y:g}, {self.w:g}x{self.h:g})"

    @staticmethod
    def from_godot(value: Mapping[str, Any]) -> Rect:
        """get_ui_elementsの``{"position": {x, y}, "size": {x, y}}``形式から作る。"""
        pos = value["position"]
        size = value["size"]
        return Rect(float(pos["x"]), float(pos["y"]), float(size["x"]), float(size["y"]))

    @staticmethod
    def from_list(value: Iterable[float]) -> Rect:
        """probes.pyのGDScriptが返す``[x, y, w, h]``形式から作る。"""
        x, y, w, h = (float(v) for v in value)
        return Rect(x, y, w, h)


@dataclass(frozen=True)
class ControlInfo:
    """probes.LAYOUT_SNAPSHOTが返す、表示中のControl1つ分の情報。"""

    path: str
    type: str
    rect: Rect
    # 親がContainer系（VBoxContainer/GridContainer等）か
    parent_is_container: bool
    # 祖先にclip_contentsやScrollContainerがあり、画面外にはみ出しても切り取られるか
    clipped: bool
    # 表示中の子Controlを持つか（中身のあるラッパーかどうか）
    has_visible_children: bool

    @staticmethod
    def from_snapshot(value: Mapping[str, Any]) -> ControlInfo:
        return ControlInfo(
            path=str(value["path"]),
            type=str(value["type"]),
            rect=Rect.from_list(value["rect"]),
            parent_is_container=bool(value["parent_is_container"]),
            clipped=bool(value["clipped"]),
            has_visible_children=bool(value["has_visible_children"]),
        )


def check_within_viewport(controls: Iterable[ControlInfo], viewport: Rect) -> list[str]:
    """画面外にはみ出しているControlを返す（#88: タイトルの「終了」ボタンのはみ出し）。

    スクロール領域など、祖先で切り取られるControlと大きさ0のControlは対象外とする。
    はみ出したControlの子孫は一緒にはみ出すだけなので、最も上位のControlだけを報告する。
    """
    reported: list[str] = []
    violations = []
    for c in sorted(controls, key=lambda c: c.path.count("/")):
        if c.clipped or c.rect.is_empty() or viewport.contains(c.rect):
            continue
        if any(c.path.startswith(f"{parent}/") for parent in reported):
            continue
        reported.append(c.path)
        violations.append(f"画面{viewport}の外にはみ出している: {c.path} {c.rect}")
    return violations


def check_container_children_not_collapsed(controls: Iterable[ControlInfo]) -> list[str]:
    """Containerの子なのに幅か高さが0に潰れている、中身のあるControlを返す。

    「実コンテンツを包むだけのControl」をForwardingControlにし忘れると、
    親Containerが最小サイズ(0,0)を採用して行が潰れる（#87、ui-components.md参照）。
    子を持たない区切り用のControlは潰れていても実害がないので対象外とする。
    """
    violations = []
    for c in controls:
        if c.parent_is_container and c.has_visible_children and c.rect.is_empty():
            violations.append(f"Containerの子が大きさ0に潰れている: {c.path} {c.rect}")
    return violations


def check_no_overlap(targets: Mapping[str, Rect], others: Mapping[str, Rect]) -> list[str]:
    """targetsの各矩形がothersのどれとも重なっていないことを確かめる。"""
    violations = []
    for t_name, t_rect in targets.items():
        for o_name, o_rect in others.items():
            if t_rect.overlaps(o_rect):
                violations.append(f"{t_name} {t_rect} が {o_name} {o_rect} と重なっている")
    return violations


def check_not_empty(rects: Mapping[str, Rect]) -> list[str]:
    return [f"大きさが0になっている: {name} {rect}" for name, rect in rects.items() if rect.is_empty()]


def check_has_backdrop(target: str, result: Mapping[str, Any]) -> list[str]:
    """probes.backdrop_probe()の結果から、targetの背後に背景があるか判定する（#89）。

    背景がないと、Godotの既定クリアカラー（ダークグレー）がそのまま見える。
    """
    if not result.get("found", False):
        return [f"{target} がシーンツリーに見つからない"]
    covering = result.get("covering", [])
    if covering:
        return []
    message = (
        f"{target} {Rect.from_list(result['rect'])} の背後を覆う背景"
        "（Panel/PanelContainerのStyleBox、TextureRect、ColorRect等）がない"
    )
    return [message]


def check_logs_clean(lines: Iterable[Mapping[str, Any]]) -> list[str]:
    """実行中ゲームのログにerror/warningがないことを確かめる。"""
    violations = []
    for line in lines:
        level = str(line.get("level", ""))
        if level not in ("error", "warning"):
            continue
        text = str(line.get("text", "")).strip()
        if text.startswith(IGNORED_LOG_PREFIXES):
            continue
        violations.append(f"ゲームログに{level}: {text}")
    return violations
