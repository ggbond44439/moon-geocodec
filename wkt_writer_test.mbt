///|
fn format_wkt_ok(geometry : @moon_geocodec.Geometry) -> String raise {
  match @moon_geocodec.format_wkt(geometry) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
fn parse_wkt_text(source : StringView) -> @moon_geocodec.Geometry raise {
  match @moon_geocodec.parse_wkt(source, @moon_geocodec.GeoLimits::default()) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
test "WKT writer formats basic geometries canonically" {
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
    ),
    "POINT (1 2)",
  )
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::LineString([
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
        @moon_geocodec.Coordinate::xy(2.0, -3.5),
      ]),
    ),
    "LINESTRING (0 0, 1 1, 2 -3.5)",
  )
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::Polygon([
        [
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 1.0),
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
        ],
      ]),
    ),
    "POLYGON ((0 0, 1 0, 1 1, 0 0))",
  )
}

///|
test "WKT writer emits dimension suffixes" {
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
      ),
    ),
    "POINT Z (1 2 3)",
  )
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xym(1.0, 2.0, 4.0),
      ),
    ),
    "POINT M (1 2 4)",
  )
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
      ),
    ),
    "POINT ZM (1 2 3 4)",
  )
}

///|
test "WKT writer emits empty geometries" {
  assert_eq(format_wkt_ok(@moon_geocodec.Geometry::EmptyPoint), "POINT EMPTY")
  assert_eq(
    format_wkt_ok(@moon_geocodec.Geometry::LineString([])),
    "LINESTRING EMPTY",
  )
  assert_eq(
    format_wkt_ok(@moon_geocodec.Geometry::Polygon([])),
    "POLYGON EMPTY",
  )
  assert_eq(
    format_wkt_ok(@moon_geocodec.Geometry::MultiPoint([])),
    "MULTIPOINT EMPTY",
  )
  assert_eq(
    format_wkt_ok(@moon_geocodec.Geometry::MultiLineString([])),
    "MULTILINESTRING EMPTY",
  )
  assert_eq(
    format_wkt_ok(@moon_geocodec.Geometry::MultiPolygon([])),
    "MULTIPOLYGON EMPTY",
  )
  assert_eq(
    format_wkt_ok(@moon_geocodec.Geometry::GeometryCollection([])),
    "GEOMETRYCOLLECTION EMPTY",
  )
}

///|
test "WKT writer formats multi geometries" {
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::MultiPoint([
        @moon_geocodec.Coordinate::xy(1.0, 2.0),
        @moon_geocodec.Coordinate::xy(3.0, 4.0),
      ]),
    ),
    "MULTIPOINT (1 2, 3 4)",
  )
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::MultiLineString([
        [
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 1.0),
        ],
        [
          @moon_geocodec.Coordinate::xy(2.0, 2.0),
          @moon_geocodec.Coordinate::xy(3.0, 3.0),
        ],
      ]),
    ),
    "MULTILINESTRING ((0 0, 1 1), (2 2, 3 3))",
  )
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::MultiPolygon([
        [
          [
            @moon_geocodec.Coordinate::xy(0.0, 0.0),
            @moon_geocodec.Coordinate::xy(1.0, 0.0),
            @moon_geocodec.Coordinate::xy(1.0, 1.0),
            @moon_geocodec.Coordinate::xy(0.0, 0.0),
          ],
        ],
      ]),
    ),
    "MULTIPOLYGON (((0 0, 1 0, 1 1, 0 0)))",
  )
}

///|
test "WKT writer formats geometry collections with shared dimensions" {
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::GeometryCollection([
        @moon_geocodec.Geometry::Point(
          @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
        ),
        @moon_geocodec.Geometry::LineString([
          @moon_geocodec.Coordinate::xyz(0.0, 0.0, 0.0),
          @moon_geocodec.Coordinate::xyz(1.0, 1.0, 1.0),
        ]),
      ]),
    ),
    "GEOMETRYCOLLECTION Z (POINT (1 2 3), LINESTRING (0 0 0, 1 1 1))",
  )
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::GeometryCollection([
        @moon_geocodec.Geometry::EmptyPoint,
        @moon_geocodec.Geometry::Point(
          @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
        ),
      ]),
    ),
    "GEOMETRYCOLLECTION Z (POINT EMPTY, POINT (1 2 3))",
  )
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::GeometryCollection([
        @moon_geocodec.Geometry::Point(
          @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
        ),
        @moon_geocodec.Geometry::Point(
          @moon_geocodec.Coordinate::xym(4.0, 5.0, 6.0),
        ),
      ]),
    ),
    "GEOMETRYCOLLECTION (POINT Z (1 2 3), POINT M (4 5 6))",
  )
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::GeometryCollection([
        @moon_geocodec.Geometry::EmptyPoint,
        @moon_geocodec.Geometry::LineString([]),
      ]),
    ),
    "GEOMETRYCOLLECTION (POINT EMPTY, LINESTRING EMPTY)",
  )
}

///|
test "WKT writer output is stable and round trips through the parser" {
  let samples : Array[String] = [
    "POINT ZM (1 2 3 4)", "LINESTRING M (0 0 1, 2 3 4)", "POLYGON Z ((0 0 1, 1 0 2, 1 1 3, 0 0 1))",
    "MULTIPOINT ((1 2), (3 4))", "MULTILINESTRING Z ((0 0 1, 1 1 2))", "MULTIPOLYGON (((0 0, 1 0, 1 1, 0 0)))",
    "GEOMETRYCOLLECTION Z (POINT (1 2 3), LINESTRING (0 0 0, 1 1 1))", "GEOMETRYCOLLECTION (POINT Z (1 2 3), POINT M (4 5 6))",
    "GEOMETRYCOLLECTION (POINT EMPTY, LINESTRING EMPTY)", "POINT (1e-7 -2.5e+20)",
  ]
  for source in samples {
    let original = parse_wkt_text(source.view())
    let formatted = format_wkt_ok(original)
    let reparsed = parse_wkt_text(formatted.view())
    assert_eq(reparsed, original)
    assert_eq(format_wkt_ok(reparsed), formatted)
  }
  assert_eq(
    format_wkt_ok(
      @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(-0.0, 1.0)),
    ),
    "POINT (0 1)",
  )
}

///|
test "WKT writer rejects invalid coordinates and empty components" {
  assert_eq(
    @moon_geocodec.format_wkt(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xy(@double.not_a_number, 1.0),
      ),
    ),
    Err(@moon_geocodec.InvalidCoordinate("non-finite x ordinate")),
  )
  assert_eq(
    @moon_geocodec.format_wkt(
      @moon_geocodec.Geometry::LineString([
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xyz(1.0, 1.0, 1.0),
      ]),
    ),
    Err(@moon_geocodec.InvalidCoordinate("inconsistent coordinate dimensions")),
  )
  let empty_ring : Array[@moon_geocodec.Coordinate] = []
  assert_eq(
    @moon_geocodec.format_wkt(@moon_geocodec.Geometry::Polygon([empty_ring])),
    Err(@moon_geocodec.InvalidCoordinate("empty polygon ring")),
  )
  assert_eq(
    @moon_geocodec.format_wkt(
      @moon_geocodec.Geometry::MultiLineString([
        [],
        [@moon_geocodec.Coordinate::xy(0.0, 0.0)],
      ]),
    ),
    Err(@moon_geocodec.InvalidCoordinate("empty line string component")),
  )
  let empty_polygon : Array[Array[@moon_geocodec.Coordinate]] = []
  assert_eq(
    @moon_geocodec.format_wkt(
      @moon_geocodec.Geometry::MultiPolygon([empty_polygon]),
    ),
    Err(@moon_geocodec.InvalidCoordinate("empty polygon component")),
  )
}
