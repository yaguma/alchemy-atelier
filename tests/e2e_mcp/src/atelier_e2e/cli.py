"""描画E2Eの実行入口。``uv run --project tests/e2e_mcp atelier-e2e``で実行する。

終了コード: 0=全チェック成功 / 1=チェック失敗（不具合の可能性） / 2=実行環境の問題（エディタ未起動等）
"""

from __future__ import annotations

import argparse
import asyncio
import sys

from .client import EnvironmentIssue, GodotMcpClient, ToolError
from .scenarios import SCENARIO_ORDER, CheckResult, Runner

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_ENVIRONMENT = 2


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="atelier-e2e",
        description="godot-ai MCPで描画中のゲーム画面を操作・検証する（ローカル専用・CI対象外）",
    )
    parser.add_argument("--godot-ai-command", default="godot-ai", help="godot-aiコマンド（既定: godot-ai）")
    parser.add_argument("--port", type=int, default=8000, help="MCPサーバーのHTTPポート（既定: 8000）")
    parser.add_argument("--ws-port", type=int, default=9500, help="WebSocketポート（既定: 9500）")
    return parser.parse_args(argv)


async def _run(args: argparse.Namespace) -> tuple[list[CheckResult], str | None]:
    """チェック結果と、続行できなくなった理由（環境起因なら``"ENV: ..."``）を返す。"""
    async with GodotMcpClient(args.godot_ai_command, args.port, args.ws_port) as client:
        await client.ensure_editor()
        runner = Runner(client)
        aborted: str | None = None
        try:
            for name, scenario in SCENARIO_ORDER:
                # 画面遷移に失敗したら後続の画面には進めないが、ログの確認だけは行う
                if aborted and name != "logs":
                    continue
                try:
                    await scenario(runner)
                except (AssertionError, ToolError) as err:
                    runner.record(name, "画面の操作・遷移", [str(err)])
                    aborted = f"{name}で中断: {err}"
        finally:
            try:
                await runner.discard_new_slot()
            except (AssertionError, ToolError, EnvironmentIssue) as err:
                print(f"[WARN] セーブの後片付けに失敗した: {err}", file=sys.stderr)
            # 失敗した場合もゲームを必ず止める（受け入れ基準）
            await client.stop()
        return runner.results, aborted


def _report(results: list[CheckResult]) -> None:
    for r in results:
        mark = "PASS" if r.passed else "FAIL"
        print(f"[{mark}] {r.screen}: {r.name}")
        for v in r.violations:
            print(f"       - {v}")
    failed = sum(not r.passed for r in results)
    print(f"\n{len(results) - failed}/{len(results)} チェック成功")


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    # Windowsの既定（cp932）のままだとGit Bash上で日本語が文字化けする
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    try:
        results, aborted = asyncio.run(_run(args))
    except EnvironmentIssue as err:
        print(f"[ENV] 実行環境の問題で中止した（テスト対象の不具合ではない）: {err}", file=sys.stderr)
        return EXIT_ENVIRONMENT
    _report(results)
    if aborted:
        print(f"途中で中断: {aborted}", file=sys.stderr)
    return EXIT_OK if all(r.passed for r in results) and not aborted else EXIT_FAILED


if __name__ == "__main__":
    sys.exit(main())
