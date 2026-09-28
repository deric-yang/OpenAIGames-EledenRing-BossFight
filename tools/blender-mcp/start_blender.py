"""Start the project-local Blender MCP bridge without changing global preferences."""

from __future__ import annotations

import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
import blender_mcp  # noqa: E402

blender_mcp.register()
server = blender_mcp.BlenderMCPServer(host="127.0.0.1", port=9877)
server.start()
bpy.context.scene["project"] = "Weeping Dunes"
print("WEEPING_DUNES_MCP_READY port=9877", flush=True)
