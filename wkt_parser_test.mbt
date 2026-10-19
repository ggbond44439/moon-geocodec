///|
fn parse_wkt_ok(source : StringView) -> @moon_geocodec.Geometry raise {
  match @moon_geocodec.parse_wkt(source, @moon_geocodec.GeoLimits::default()) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
test "WKT parser reads point line string and polygon geometries" {
  assert_eq(
    parse_wkt_ok("POINT (1 2)"),
    @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
  )
  assert_eq(
    parse_wkt_ok("LINESTRING (0 0, 1 1, 2 -3.5)"),
    @moon_geocodec.Geometry::LineString([
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(1.0, 1.0),
      @moon_geocodec.Coordinate::xy(2.0, -3.5),
    ]),
  )
  assert_eq(
    parse_wkt_ok(
      "POLYGON ((0 0, 1 0, 1 1, 0 0), (0.25 0.25, 0.5 0.25, 0.5 0.5, 0.25 0.25))",
    ),
    @moon_geocodec.Geometry::Polygon([
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
      ],
      [
        @moon_geocodec.Coordinate::xy(0.25, 0.25),
        @moon_geocodec.Coordinate::xy(0.5, 0.25),
        @moon_geocodec.Coordinate::xy(0.5, 0.5),
        @moon_geocodec.Coordinate::xy(0.25, 0.25),
      ],
    ]),
  )
}

///|
test "WKT parser reads Z M and ZM coordinates" {
  assert_eq(
    parse_wkt_ok("POINT Z (1 2 3)"),
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    ),
  )
  assert_eq(
    parse_wkt_ok("POINT M (1 2 4)"),
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xym(1.0, 2.0, 4.0),
    ),
  )
  assert_eq(
    parse_wkt_ok("point zm (1 2 3 4)"),
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
    ),
  )
}

///|
test "WKT parser reads empty basic geometries" {
  let empty_point = parse_wkt_ok("POINT EMPTY")
  let empty_point_z = parse_wkt_ok("POINT Z EMPTY")
  let empty_line = parse_wkt_ok("LINESTRING EMPTY")
  let empty_polygon = parse_wkt_ok("POLYGON EMPTY")
  assert_eq(empty_point, @moon_geocodec.Geometry::EmptyPoint)
  assert_eq(empty_point_z, @moon_geocodec.Geometry::EmptyPoint)
  assert_eq(empty_point.kind(), @moon_geocodec.GeometryKind::Point)
  assert_eq(empty_point.coordinate_count(), 0)
  assert_eq(empty_point.bounds(), None)
  assert_eq(
    empty_line,
    (@moon_geocodec.Geometry::LineString([]) : @moon_geocodec.Geometry),
  )
  assert_eq(
    empty_polygon,
    (@moon_geocodec.Geometry::Polygon([]) : @moon_geocodec.Geometry),
  )
  assert_eq(empty_line.is_empty(), true)
  assert_eq(empty_polygon.is_empty(), true)
}

///|
test "WKT parser rejects inconsistent coordinate dimensions" {
  assert_eq(
    @moon_geocodec.parse_wkt(
      "POINT (1 2 3)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("too many ordinates", 11)),
  )
  assert_eq(
    @moon_geocodec.parse_wkt(
      "POINT Z (1 2)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("expected z ordinate", 12)),
  )
  assert_eq(
    @moon_geocodec.parse_wkt(
      "LINESTRING Z (0 0 0, 1 1)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("expected z ordinate", 24)),
  )
}

///|
test "WKT parser rejects malformed syntax with source offsets" {
  assert_eq(
    @moon_geocodec.parse_wkt("", @moon_geocodec.GeoLimits::default()),
    Err(@moon_geocodec.InvalidWkt("expected geometry type", 0)),
  )
  assert_eq(
    @moon_geocodec.parse_wkt("POINT", @moon_geocodec.GeoLimits::default()),
    Err(@moon_geocodec.InvalidWkt("expected '(' after POINT", 5)),
  )
  assert_eq(
    @moon_geocodec.parse_wkt(
      "LINESTRING (0 0,)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("expected x ordinate", 16)),
  )
  assert_eq(
    @moon_geocodec.parse_wkt(
      "POLYGON (0 0, 1 0, 1 1, 0 0)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("expected '(' to start polygon ring", 9)),
  )
  assert_eq(
    @moon_geocodec.parse_wkt(
      "POINT (1 2) x",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("unexpected token after geometry", 12)),
  )
}

///|
test "WKT parser rejects unsupported and unknown geometry types" {
  assert_eq(
    @moon_geocodec.parse_wkt(
      "MULTIPOINT (0 0)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.UnsupportedGeometry("MULTIPOINT")),
  )
  assert_eq(
    @moon_geocodec.parse_wkt(
      "CIRCLE (0 0)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("unknown geometry type", 0)),
  )
}

///|
test "WKT parser enforces coordinate limits" {
  let limits = match @moon_geocodec.GeoLimits::new(1024, 8, 8, 1) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.parse_wkt("LINESTRING (0 0, 1 1)", limits),
    Err(@moon_geocodec.LimitExceeded("coordinate count", 1, 2)),
  )
}
