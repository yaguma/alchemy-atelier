"""godot-ai MCPのツール呼び出しを薄く包むクライアント。

Godotエディタのプラグインが起動しているMCPサーバー（127.0.0.1:8000）には、HTTPで直接つなぐと
エディタが発行する認証情報が要る。そのため``.mcp.json``と同じ``godot-ai attach``（stdioブリッジ）を
子プロセスとして起動し、それ経由でツールを呼ぶ。ブリッジが認証情報の受け渡しを引き受ける。
"""

from __future__ import annotations

import asyncio
import json
import time
from collections.abc import Awaitable, Callable
from typing import Any, Self

from fastmcp import Client
from fastmcp.client.transports import StdioTransport

from .checks import Rect

# .mcp.json・atelier/addons/godot_ai/と揃える版。ツール名や引数が変わると壊れるため固定する
REQUIRED_GODOT_AI_VERSION = "4.3.1"

LIVE_TIMEOUT_SEC = 30.0
POLL_INTERVAL_SEC = 0.25
NOT_READY_RETRIES = 8

# ウィンドウが裏に回ると描画・処理が止まり、ゲーム側の応答がこのコードになる
_NOT_READY_CODES = ("EVAL_GAME_NOT_READY", "GAME_NOT_READY", "stale_frame")


class EnvironmentIssue(Exception):
    """テスト対象の不具合ではなく、実行環境が原因で続けられない状態。"""


class ToolError(Exception):
    def __init__(self, tool: str, text: str) -> None:
        super().__init__(f"{tool}: {text}")
        self.tool = tool
        self.text = text

    def is_not_ready(self) -> bool:
        return any(code in self.text for code in _NOT_READY_CODES)


class GodotMcpClient:
    def __init__(self, command: str, port: int, ws_port: int) -> None:
        transport = StdioTransport(
            command=command,
            args=["attach", "--port", str(port), "--ws-port", str(ws_port), "--disable-telemetry"],
            env={"GODOT_AI_DISABLE_TELEMETRY": "true"},
        )
        self._client = Client(transport)

    async def __aenter__(self) -> Self:
        try:
            await self._client.__aenter__()
        except Exception as exc:  # 起動失敗の原因はコマンド未導入・エディタ未起動など環境側
            raise EnvironmentIssue(
                f"godot-ai MCPブリッジに接続できない（{exc}）。"
                f"`uv tool install godot-ai=={REQUIRED_GODOT_AI_VERSION}`済みか確認する"
            ) from exc
        return self

    async def __aexit__(self, *exc_info: object) -> None:
        await self._client.__aexit__(*exc_info)

    async def call(self, tool: str, arguments: dict[str, Any] | None = None) -> dict[str, Any]:
        result = await self._client.call_tool_mcp(tool, arguments or {})
        text = "".join(getattr(c, "text", "") for c in result.content)
        if result.is_error:
            raise ToolError(tool, text)
        if isinstance(result.structured_content, dict):
            return result.structured_content
        return json.loads(text) if text else {}

    async def _retry_not_ready(self, action: Callable[[], Awaitable[dict[str, Any]]]) -> dict[str, Any]:
        for attempt in range(NOT_READY_RETRIES):
            try:
                return await action()
            except ToolError as err:
                if not err.is_not_ready() or attempt == NOT_READY_RETRIES - 1:
                    if err.is_not_ready():
                        raise EnvironmentIssue(
                            f"ゲームが応答しない（{err.text}）。ゲームウィンドウを前面に出して再実行する"
                        ) from err
                    raise
                await asyncio.sleep(POLL_INTERVAL_SEC * (2**attempt))
        raise AssertionError("unreachable")

    # --- 接続・起動・停止 ---

    async def ensure_editor(self) -> None:
        data = await self.call("session_manage", {"op": "list"})
        sessions = data.get("sessions", [])
        active = [s for s in sessions if s.get("is_active")] or sessions
        if not active:
            raise EnvironmentIssue(
                "Godotエディタが接続されていない。`godot --path atelier --editor`でエディタを開いてから実行する"
            )
        session = active[0]
        for key in ("plugin_version", "server_version"):
            if session.get(key) != REQUIRED_GODOT_AI_VERSION:
                raise EnvironmentIssue(
                    f"godot-aiの{key}が{session.get(key)}（必要: {REQUIRED_GODOT_AI_VERSION}）"
                )

    async def run_scene(self, scene: str) -> None:
        await self.stop()
        await self.call("project_run", {"mode": "custom", "scene": scene, "autosave": False})
        deadline = time.monotonic() + LIVE_TIMEOUT_SEC
        while time.monotonic() < deadline:
            state = await self.call("editor_state")
            status = state.get("game_status", {}).get("status")
            if status == "break":
                raise AssertionError(
                    f"{scene}の起動時にスクリプトエラーで停止した。logs_read(source=editor)で原因を確認する"
                )
            if status == "live" and state.get("game_capture_ready"):
                return
            await asyncio.sleep(POLL_INTERVAL_SEC)
        raise EnvironmentIssue(
            f"{LIVE_TIMEOUT_SEC:g}秒待ってもゲームが起動しない。ゲームウィンドウを前面に出して再実行する"
        )

    async def stop(self) -> None:
        await self.call("project_manage", {"op": "stop"})

    # --- 実行中ゲームの操作・取得 ---

    async def eval(self, code: str) -> Any:
        data = await self._retry_not_ready(
            lambda: self.call("editor_manage", {"op": "game_eval", "params": {"code": code}})
        )
        return data.get("result")

    async def ui_elements(self, root_path: str = "") -> list[dict[str, Any]]:
        params: dict[str, Any] = {"max_depth": 32}
        if root_path:
            params["root_path"] = root_path
        data = await self._retry_not_ready(
            lambda: self.call("game_manage", {"op": "get_ui_elements", "params": params})
        )
        return list(data.get("elements", []))

    async def click(self, name: str) -> None:
        """表示中のUI要素のうち、ノード名がnameのもの（1つだけ）の中心を押す。

        パスではなく名前で探すのは、レイアウト修正で親子関係が変わってもシナリオを
        書き換えずに済むようにするため。
        """
        elements = [e for e in await self.ui_elements() if e.get("name") == name]
        if len(elements) != 1:
            raise AssertionError(f"押そうとしたUI要素{name}が{len(elements)}個表示されている（1個のはず）")
        element = elements[0]
        if element.get("disabled"):
            raise AssertionError(f"押そうとしたUI要素が無効になっている: {element.get('path')}")
        x, y = Rect.from_godot(element["global_rect"]).center
        # ボタンはpressed→releasedの2回で1クリックになる
        for pressed in (True, False):
            await self._retry_not_ready(
                lambda pressed=pressed: self.call(
                    "game_manage",
                    {
                        "op": "input_mouse",
                        "params": {"event": "button", "position": [x, y], "pressed": pressed},
                    },
                )
            )

    async def wait_until(
        self, code: str, predicate: Callable[[Any], bool], description: str, timeout: float = 10.0
    ) -> Any:
        deadline = time.monotonic() + timeout
        last: Any = None
        while time.monotonic() < deadline:
            last = await self.eval(code)
            if predicate(last):
                return last
            await asyncio.sleep(POLL_INTERVAL_SEC)
        raise AssertionError(f"{timeout:g}秒待っても{description}にならない（最後の値: {last}）")

    async def game_logs(self) -> dict[str, Any]:
        return await self.call("logs_read", {"source": "game", "count": 2000})
