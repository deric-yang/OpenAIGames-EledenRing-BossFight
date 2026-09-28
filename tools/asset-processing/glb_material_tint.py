"""Preserve a Blender cloth tint explicitly in glTF's standard base color factor."""
from __future__ import annotations

import json
import struct
from pathlib import Path


def apply_cloth_tint(path):
    """Patch only material metadata, preserving all binary mesh and image data."""
    path = Path(path)
    data = path.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    document = json.loads(data[20:20 + length])
    for material in document['materials']:
        if material.get('name') == 'Knight_Charcoal_Cloth':
            material['pbrMetallicRoughness']['baseColorFactor'] = [0.24, 0.255, 0.28, 1]
    encoded = json.dumps(document, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    chunks = struct.pack('<II', len(encoded), 0x4E4F534A) + encoded + data[20 + length:]
    path.write_bytes(struct.pack('<III', 0x46546C67, 2, len(chunks) + 12) + chunks)
