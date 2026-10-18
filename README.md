# MoonGeoCodec

MoonGeoCodec is a MoonBit geometry interchange library for WKT, WKB, EWKB,
and GeoJSON. It provides a typed geometry model, strict format parsing,
canonical serialization, resource limits, and cross-language interoperability
vectors for GIS and spatial data pipelines.

## Status

`0.1.1` adds the WKT tokenizer and configurable token limits. The current milestone establishes
the project layout, typed errors, resource limits, geometry model, and bounds
calculation. WKT, WKB, EWKB, and GeoJSON codecs are developed in subsequent
milestones.

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
moon add ggbond44439/moon_geocodec@0.1.1
```

## Build and test

```text
moon check --target all
moon test --target all
moon build
```

## License

Apache-2.0.