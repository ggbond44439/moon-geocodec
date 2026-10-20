# MoonGeoCodec

MoonGeoCodec is a MoonBit geometry interchange library for WKT, WKB, EWKB,
and GeoJSON. It provides a typed geometry model, strict format parsing,
canonical serialization, resource limits, and cross-language interoperability
vectors for GIS and spatial data pipelines.

## Status

`0.1.9` adds PostGIS-compatible EWKB reading and writing with dimension flags
and embedded SRIDs. GeoJSON import/export continues in subsequent milestones.

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
- Interoperability vectors checked against PostGIS, Shapely, and QGIS

## Explicit non-goals

MoonGeoCodec is not a geometry engine. Buffer, union, intersection, overlay,
spatial indexing, and GEOS-level operations are outside the initial scope.

## Install

```text
moon add ggbond44439/moon_geocodec@0.1.9
```

## Build and test

```text
moon check --target all
moon test --target all
moon build
```

## License

Apache-2.0.
