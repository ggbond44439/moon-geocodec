# MoonGeoCodec

MoonGeoCodec is a MoonBit geometry interchange library for WKT, WKB, EWKB,
and GeoJSON. It provides a typed geometry model, strict format parsing,
canonical serialization, resource limits, and cross-language interoperability
vectors for GIS and spatial data pipelines.

## Status

`0.1.2` adds a bounded WKT 1 parser for `POINT`, `LINESTRING`, and `POLYGON`,
including `Z`, `M`, `ZM`, and `EMPTY` forms. WKT, WKB, EWKB, and GeoJSON codecs
continue to be developed in subsequent milestones.

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
offset, rejects inconsistent coordinate dimensions, and enforces coordinate
limits while reading.

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
moon add ggbond44439/moon_geocodec@0.1.2
```

## Build and test

```text
moon check --target all
moon test --target all
moon build
```

## License

Apache-2.0.
