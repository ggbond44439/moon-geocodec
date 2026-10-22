"""Optional cross-language verification for MoonGeoCodec reference vectors."""

import json
import pathlib
import sys

try:
    from shapely import wkb, wkt
    from shapely.geometry import shape
except ImportError:
    print("shapely is not installed; skipping optional interoperability check")
    sys.exit(0)


root = pathlib.Path(__file__).resolve().parent
vectors = json.loads((root / "reference_vectors.json").read_text(encoding="utf-8"))

for vector in vectors:
    if "wkt" in vector and "wkb" in vector:
        geometry = wkt.loads(vector["wkt"])
        expected_wkb = vector["wkb"].lower()
        encoded = wkb.dumps(geometry, hex=True, byte_order=1).lower()
        if encoded != expected_wkb:
            raise SystemExit(
                f"{vector['name']}: WKB mismatch\n"
                f"  shapely={encoded}\n  fixture={expected_wkb}"
            )
        decoded = wkb.loads(bytes.fromhex(expected_wkb))
        if not geometry.equals_exact(decoded, 0.0):
            raise SystemExit(f"{vector['name']}: WKB geometry mismatch")

    if "geojson" in vector and "wkt" in vector:
        expected_json = json.loads(vector["geojson"])
        if not wkt.loads(vector["wkt"]).equals_exact(shape(expected_json), 0.0):
            raise SystemExit(f"{vector['name']}: GeoJSON geometry mismatch")

print(f"verified {len(vectors)} vectors with shapely")
