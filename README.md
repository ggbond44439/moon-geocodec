# MoonGeoCodec

MoonGeoCodec is a MoonBit geometry interchange library for WKT, WKB, EWKB,
and GeoJSON. It provides a typed geometry model, strict format parsing,
canonical serialization, resource limits, and cross-language interoperability
vectors for GIS and spatial data pipelines.

## Status

`0.2.0` is the first release with the complete WKT/WKB/EWKB/GeoJSON pipeline,
validation, metrics, interoperability vectors, and CLI.

## WKT parser

```moonbit
let geometry = match @moon_geocodec.parse_wkt(
  "POLYGON ((0 0, 1 0, 1 1, 0 0))",
  @moon_geocodec.GeoLimits::default(),
) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
assert_eq(geometry.kind(), @moon_geocodec.GeometryKind::Polygon)
```

The parser reports malformed syntax as `GeoError::InvalidWkt` with a source
offset, rejects inconsistent coordinate dimensions, and enforces coordinate,
geometry-count, and collection-depth limits while reading.

## WKT writer

```moonbit
let text = match @moon_geocodec.format_wkt(geometry) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
assert_eq(text, "POLYGON ((0 0, 1 0, 1 1, 0 0))")
```

The writer emits uppercase geometry names, deterministic spacing, `Z`, `M`,
and `ZM` suffixes, and `EMPTY` forms. It rejects non-finite coordinates,
inconsistent dimensions, and empty multipart components.

## WKT2 and EWKT

```moonbit
let wkt2 = match @moon_geocodec.parse_wkt2(
  "MULTIPOINT ((1 2), (3 4))",
  @moon_geocodec.GeoLimits::default(),
) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
assert_eq(
  @moon_geocodec.format_wkt2(wkt2),
  Ok("MULTIPOINT ((1 2), (3 4))"),
)

let ewkt = match @moon_geocodec.parse_ewkt(
  "SRID=4326;POINT (1 2)",
  @moon_geocodec.GeoLimits::default(),
) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
assert_eq(ewkt.srid, Some(4326))
assert_eq(
  @moon_geocodec.format_ewkt(ewkt),
  Ok("SRID=4326;POINT (1 2)"),
)
```

WKT 2 uses parenthesized `MULTIPOINT` coordinates. Curve and surface types
outside the current geometry model are reported as `UnsupportedGeometry`.
EWKT SRIDs are optional, must be non-negative, and are stored separately from
the geometry.

## WKB reader

```moonbit
let geometry = match @moon_geocodec.parse_wkb(
  bytes.exact_view(),
  @moon_geocodec.GeoLimits::default(),
) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
```

The reader supports all seven WKB geometry types in `XY`, `XYZ`, `XYM`, and
`XYZM` forms using both byte orders. Nested geometries may use independent byte
order, while component dimensions must match their parent. Truncation, invalid
type codes, dimension mismatches, trailing bytes, and resource-limit violations
produce typed errors.

## WKB writer

```moonbit
let bytes = match @moon_geocodec.format_wkb(geometry) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
let big_endian = match @moon_geocodec.format_wkb_with_order(
  geometry,
  @moon_geocodec.WkbByteOrder::BigEndian,
) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
```

`format_wkb` emits little-endian WKB by default. The writer supports all seven
geometry types in `XY`, `XYZ`, `XYM`, and `XYZM` forms, empty geometries,
multipart components, and `GeometryCollection` recursion. Dimensioned empty
children inherit the enclosing geometry dimension. The writer rejects mixed
dimensions, non-finite ordinates, and empty polygon rings with typed errors.

## EWKB

```moonbit
let value = match @moon_geocodec.parse_ewkb(
  ewkb_bytes.exact_view(),
  @moon_geocodec.GeoLimits::default(),
) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
let encoded = match @moon_geocodec.format_ewkb(value) {
  Ok(bytes) => bytes
  Err(err) => fail(err.to_string())
}
```

EWKB supports PostGIS `Z`, `M`, and `SRID` type flags, including combined
`Z/M/SRID` geometries. SRIDs are stored on `SpatialGeometry`; the writer emits
the SRID on the root geometry while nested components carry only matching
dimension flags. `parse_wkb` remains strict ISO WKB and rejects EWKB high-bit
type codes.

## GeoJSON import

```moonbit
let geometry = match @moon_geocodec.parse_geojson(
  "{\"type\":\"Point\",\"coordinates\":[1,2]}",
  @moon_geocodec.GeoLimits::default(),
) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
assert_eq(
  geometry,
  @moon_geocodec.Geometry::Point(
    @moon_geocodec.Coordinate::xy(1.0, 2.0),
  ),
)
```

The importer supports all seven GeoJSON geometry types, two- and
three-dimensional positions, empty geometry arrays, Features, and
FeatureCollections. Feature properties and bounding boxes are ignored because
the output is the typed geometry model. Null feature geometries are skipped;
FeatureCollections are represented as `GeometryCollection`.

## GeoJSON export and conversions

```moonbit
let text = match @moon_geocodec.format_geojson(geometry) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
assert_eq(
  text,
  "{\"type\":\"Point\",\"coordinates\":[1,2]}",
)
```

`format_geojson` writes deterministic compact GeoJSON with fixed key order. It
supports `XY` and `XYZ` positions, empty geometries, multipart geometries, and
GeometryCollections. M-only and ZM geometries are rejected because GeoJSON has
no standard M ordinate.

Conversion helpers bridge formats without exposing intermediate steps:

- `wkt_to_geojson`
- `geojson_to_wkt`
- `wkb_to_geojson`
- `geojson_to_wkb`

## Geometry validation and normalization

```moonbit
let normalized = match @moon_geocodec.normalize_geometry(geometry) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
assert_eq(@moon_geocodec.validate_geometry(normalized), Ok(()))
```

Validation checks finite coordinates, dimension consistency, line minimum
length and distinctness, polygon ring length, closure and area, and multipart
component structure. Normalization removes consecutive duplicate coordinates,
closes polygon rings, orients exterior rings counter-clockwise and interior
rings clockwise, then validates the result.

## 3D bounds and centroids

```moonbit
let bounds = geometry.bounds_3d()
let center = geometry.centroid()
```

`bounds_3d` returns a `BoundingBox3D` with `width`, `height`, `depth`, and an
`extent` tuple. Missing Z ordinates contribute `0.0`, so 2D and mixed-height
data retain deterministic three-dimensional bounds.

`centroid` is geometry-aware: points use coordinate averages, lines use
segment-length weighting, polygons use signed area with holes subtracted, and
GeometryCollections prefer their highest-dimensional members. Z is included
when all contributing coordinates provide it.

## CLI

The executable supports geometry inspection, structural validation, and format
conversion:

```text
moon run cmd/main -- inspect wkt "POINT Z (1 2 3)"
moon run cmd/main -- validate wkt "POLYGON ((0 0, 1 0, 1 1, 0 0))"
moon run cmd/main -- convert wkt geojson "POINT (1 2)"
moon run cmd/main -- convert ewkt ewkb "SRID=4326;POINT (1 2)"
```

Supported formats are `wkt`, `wkt2`, `ewkt`, `wkb`, `ewkb`, and `geojson`.
WKB and EWKB values use hexadecimal strings. `inspect` reports kind,
dimension, coordinate count, 2D/3D bounds, extent, centroid, SRID, and
structural validity.

## Interoperability vectors

Reference WKB, EWKB, and GeoJSON vectors live in
`interop/reference_vectors.json`. The MoonBit test suite validates them
directly. If Shapely is available, run:

```text
python -m pip install -r interop/requirements.txt
python interop/verify_shapely.py
```

The vector set includes 2D points, line strings, polygons, SRID-bearing EWKB,
and Z-bearing EWKB.

## Fuzzing and hardening

The test suite includes deterministic pseudorandom WKB/EWKB inputs, truncated
WKT/WKT2/GeoJSON inputs, and byte-size limits for binary parsers. Malformed
inputs are expected to return typed errors without panics.

## Examples and release

Run the end-to-end example with:

```text
moon run examples/quickstart
```

The release includes the reusable library, the `cmd/cli` command layer, the
`cmd/main` executable, and the reference vectors under `interop/`.

## WKT lexer

```moonbit
let tokens = match @moon_geocodec.tokenize_wkt(
  "POINT Z (1 2 3)",
  @moon_geocodec.GeoLimits::default(),
) {
  Ok(value) => value
  Err(err) => fail(err.to_string())
}
assert_eq(tokens[0].text(), "POINT")
assert_eq(tokens[1].text(), "Z")
```

The lexer returns token kinds, source text, and code-unit offsets. It rejects
malformed numbers and unexpected characters with `GeoError::InvalidWkt`, and
enforces both text-byte and token-count limits.

## Scope

- Point, LineString, Polygon, MultiPoint, MultiLineString, MultiPolygon, and
  GeometryCollection
- 2D, XYZ, XYM, and XYZM coordinates
- Strict WKT 1/2 parsing and canonical formatting
- WKB and EWKB binary codecs with endian and SRID support
- GeoJSON import/export
- Bounded parsing with typed diagnostics
- CLI inspection, validation, and conversion commands
- Interoperability vectors for WKB, EWKB, and GeoJSON

## Explicit non-goals

MoonGeoCodec is not a geometry engine. Buffer, union, intersection, overlay,
spatial indexing, and GEOS-level operations are outside the initial scope.

## Install

```text
moon add ggbond44439/moon_geocodec@0.2.0
```

## Build and test

```text
moon check --target all
moon test --target all
moon build
```

## License

Apache-2.0.
