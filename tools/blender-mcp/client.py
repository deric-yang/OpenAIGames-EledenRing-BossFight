"""Call the project-scoped Blender MCP server for scene inspection or scripts."""

from __future__ import annotations

import asyncio
import json
import os
from pathlib import Path
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parent
MCP_COMMAND = Path(
    os.environ.get(
        "BLENDER_MCP_COMMAND",
        str(ROOT / "mcp-for-blender"),
    )
)


async def main() -> None:
    environment = dict(
        os.environ,
        BLENDER_HOST="127.0.0.1",
        BLENDER_PORT="9877",
        BLENDER_MCP_DISABLE_TELEMETRY="1",
    )
    params = StdioServerParameters(command=str(MCP_COMMAND), env=environment)
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            if len(sys.argv) == 1:
                catalog = await session.list_tools()
                print(json.dumps({"tools": [tool.name for tool in catalog.tools]}))
                return
            code = Path(sys.argv[1]).resolve().read_text()
            result = await session.call_tool("execute_blender_code", {"code": code})
            payload = result.model_dump()
            print(json.dumps(payload, ensure_ascii=False))
            error_text = ""
            for block in payload.get("content", []):
                if block.get("type") == "text":
                    error_text += block.get("text", "")
            failure_markers = (
                "Error executing code",
                "Traceback (most recent call last)",
                "Exception:",
                "RuntimeError:",
                "NameError:",
                "SyntaxError:",
            )
            if result.isError or any(marker in error_text for marker in failure_markers):
                raise RuntimeError(error_text or "Blender MCP script failed")


if __name__ == "__main__":
    asyncio.run(main())
