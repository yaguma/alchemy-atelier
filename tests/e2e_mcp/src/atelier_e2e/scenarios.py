"""通常の開始手順（タイトル → はじめから → スロット選択 → 庭 → 調合タブ）を実際に操作し、
各画面で描画後のレイアウトを検証するシナリオ。

画面ごとの共通チェック（画面外へのはみ出し・Containerの子の潰れ）に加え、
#87・#88・#89で見つかった不具合の再発を個別に確かめる。
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

from . import checks, probes
from .checks import ControlInfo, Rect
from .client import GodotMcpClient

BOOT_SCENE = "res://scenes/boot.tscn"
NEW_SLOT_TEXT = "新規開始"


@dataclass
class CheckResult:
    screen: str
    name: str
    violations: list[str] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return not self.violations


@dataclass
class LayoutSnapshot:
    viewport: Rect
    controls: list[ControlInfo]

    def find(self, suffix: str) -> list[ControlInfo]:
        return [c for c in self.controls if c.path.endswith(suffix)]

    def rect_of(self, suffix: str) -> Rect | None:
        found = self.find(suffix)
        return found[0].rect if len(found) == 1 else None


class Runner:
    def __init__(self, client: GodotMcpClient) -> None:
        self.client = client
        self.results: list[CheckResult] = []
        # E2Eが選んだ空きスロット。後片付けでこのスロットのセーブだけを消す
        self._new_slot: int | None = None

    def record(self, screen: str, name: str, violations: list[str]) -> None:
        self.results.append(CheckResult(screen, name, violations))

    async def snapshot(self) -> LayoutSnapshot:
        data = await self.client.eval(probes.LAYOUT_SNAPSHOT)
        return LayoutSnapshot(
            viewport=Rect.from_list(data["viewport"]),
            controls=[ControlInfo.from_snapshot(c) for c in data["controls"]],
        )

    async def wait_screen(self, scene: str, phase: str = "") -> None:
        def reached(value: Any) -> bool:
            return value.get("scene") == scene and (not phase or value.get("phase") == phase)

        target = f"{scene}（phase={phase}）" if phase else scene
        await self.client.wait_until(probes.CURRENT_SCENE_AND_PHASE, reached, f"画面が{target}")

    async def check_common_layout(self, screen: str) -> LayoutSnapshot:
        snap = await self.snapshot()
        self.record(
            screen, "画面外にはみ出していない", checks.check_within_viewport(snap.controls, snap.viewport)
        )
        self.record(
            screen,
            "Containerの子が大きさ0に潰れていない",
            checks.check_container_children_not_collapsed(snap.controls),
        )
        return snap

    # --- 画面ごとのシナリオ ---

    async def title(self) -> None:
        await self.client.run_scene(BOOT_SCENE)
        await self.wait_screen("TitleScreen")
        snap = await self.check_common_layout("title")
        buttons = {c.path: c.rect for c in snap.controls if c.type == "Button"}
        violations = [] if buttons else ["タイトル画面にボタンが1つも表示されていない"]
        violations += [
            f"{path} {rect} が画面{snap.viewport}に収まっていない"
            for path, rect in buttons.items()
            if not snap.viewport.contains(rect)
        ]
        self.record("title", "#88 全ボタンが1280×720に収まる", violations)

    async def slot_select(self) -> None:
        await self.client.click("NewGameButton")
        await self.wait_screen("SlotSelectScreen")
        await self.check_common_layout("slot_select")

        # セーブ済みのスロットを選ぶとその状態が復元され、初期状態からの検証にならない
        elements = await self.client.ui_elements()
        labels = [
            e
            for e in elements
            if str(e.get("name", "")).startswith("SlotInfoLabel") and e.get("text") == NEW_SLOT_TEXT
        ]
        if not labels:
            raise AssertionError("空きスロット（新規開始）がない。セーブデータを1つ以上消してから実行する")
        slot_index = int(str(labels[0]["name"]).removeprefix("SlotInfoLabel"))
        self._new_slot = slot_index
        await self.client.click(f"SlotButton{slot_index}")

    async def discard_new_slot(self) -> None:
        """空きスロットを選ぶとオートセーブでセーブが作られるため、実行後に消して元に戻す。

        ゲームが動いている間にしか消せないので、停止前に呼ぶ（失敗時も）。
        """
        if self._new_slot is None:
            return
        result = await self.client.eval(probes.discard_new_slot_probe(self._new_slot))
        if result.get("error", 0) != 0:
            raise AssertionError(
                f"E2Eが作ったセーブ（スロット{self._new_slot + 1}）を削除できなかった: {result}"
            )
        self._new_slot = None

    async def garden(self) -> None:
        await self.wait_screen("Main", "garden")
        # 以降のフェーズ遷移でオートセーブさせないよう、ここで一度片付ける
        await self.discard_new_slot()
        await self.check_common_layout("garden")
        for name in ("RankHud", "TabBar"):
            result = await self.client.eval(probes.backdrop_probe(name))
            self.record(
                "garden", f"#89 {name}の行の背後に背景がある", checks.check_has_backdrop(name, result)
            )

    async def alchemy(self) -> None:
        await self.client.click("AlchemyTabButton")
        await self.wait_screen("Main", "alchemy")
        snap = await self.check_common_layout("alchemy")

        slots: dict[str, Rect] = {}
        for c in snap.controls:
            name = c.path.rsplit("/", 1)[-1]
            if name.startswith("AlchemySlot_"):
                slots[c.path] = c.rect
                panel = snap.rect_of(f"{c.path}/SlotPanel")
                if panel is not None:
                    slots[f"{c.path}/SlotPanel"] = panel
        others = {
            suffix: rect
            for suffix in ("/RecipeOptionButton", "/DailyOrderLabel", "/AlchemyPreviewPanel")
            if (rect := snap.rect_of(suffix)) is not None
        }
        violations = [] if slots else ["投入枠（AlchemySlot_*）が1つも表示されていない"]
        violations += [] if len(others) == 3 else [f"比較対象の一部が見つからない: {sorted(others)}"]
        violations += checks.check_not_empty(slots)
        violations += checks.check_no_overlap(slots, others)
        self.record("alchemy", "#87 投入枠が潰れず、レシピ選択・プレビューと重ならない", violations)

    async def game_logs(self) -> None:
        data = await self.client.game_logs()
        violations = checks.check_logs_clean(data.get("lines", []))
        editor_errors = int(data.get("editor_errors_count", 0) or 0)
        if editor_errors:
            violations.append(
                f"実行中にエディタ側でエラーが{editor_errors}件記録された"
                "（起動時のパースエラー等。logs_read(source=editor)で確認する）"
            )
        self.record("all", "ゲームログにerror/warningがない", violations)


SCENARIO_ORDER: list[tuple[str, Callable[[Runner], Any]]] = [
    ("title", Runner.title),
    ("slot_select", Runner.slot_select),
    ("garden", Runner.garden),
    ("alchemy", Runner.alchemy),
    ("logs", Runner.game_logs),
]
