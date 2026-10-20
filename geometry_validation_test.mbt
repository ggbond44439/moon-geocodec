///|
test "geometry validation accepts structurally valid geometries" {
  let sample = @moon_geocodec.Geometry::GeometryCollection([
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    ),
    @moon_geocodec.Geometry::LineString([
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(1.0, 1.0),
    ]),
    @moon_geocodec.Geometry::Polygon([
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
      ],
    ]),
    @moon_geocodec.Geometry::GeometryCollection([]),
  ])
  assert_eq(@moon_geocodec.validate_geometry(sample), Ok(()))
}

///|
test "geometry validation rejects coordinate and line errors" {
  assert_eq(
    @moon_geocodec.validate_geometry(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xy(@double.infinity, 2.0),
      ),
    ),
    Err(@moon_geocodec.InvalidCoordinate("geometry has non-finite x ordinate")),
  )
  assert_eq(
    @moon_geocodec.validate_geometry(
      @moon_geocodec.Geometry::LineString([
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
      ]),
    ),
    Err(
      @moon_geocodec.InvalidGeometry(
        "geometry must contain at least two coordinates",
      ),
    ),
  )
  assert_eq(
    @moon_geocodec.validate_geometry(
      @moon_geocodec.Geometry::LineString([
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
      ]),
    ),
    Err(
      @moon_geocodec.InvalidGeometry(
        "geometry must contain distinct coordinates",
      ),
    ),
  )
  assert_eq(
    @moon_geocodec.validate_geometry(
      @moon_geocodec.Geometry::LineString([
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xyz(1.0, 1.0, 1.0),
      ]),
    ),
    Err(
      @moon_geocodec.InvalidGeometry(
        "geometry has inconsistent coordinate dimensions",
      ),
    ),
  )
}

///|
test "geometry validation rejects malformed polygon rings" {
  assert_eq(
    @moon_geocodec.validate_geometry(
      @moon_geocodec.Geometry::Polygon([
        [
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 1.0),
          @moon_geocodec.Coordinate::xy(0.0, 1.0),
        ],
      ]),
    ),
    Err(@moon_geocodec.InvalidBoundary("geometry ring must be closed", 0)),
  )
  assert_eq(
    @moon_geocodec.validate_geometry(
      @moon_geocodec.Geometry::Polygon([
        [
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 0.0),
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
        ],
      ]),
    ),
    Err(
      @moon_geocodec.InvalidBoundary(
        "geometry ring must contain at least four coordinates", 0,
      ),
    ),
  )
  assert_eq(
    @moon_geocodec.validate_geometry(
      @moon_geocodec.Geometry::Polygon([
        [
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 1.0),
          @moon_geocodec.Coordinate::xy(2.0, 2.0),
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
        ],
      ]),
    ),
    Err(@moon_geocodec.InvalidBoundary("geometry ring has zero area", 0)),
  )
}

///|
test "geometry validation checks multipart components" {
  let empty_line : Array[@moon_geocodec.Coordinate] = []
  assert_eq(
    @moon_geocodec.validate_geometry(
      @moon_geocodec.Geometry::MultiLineString([empty_line]),
    ),
    Err(
      @moon_geocodec.InvalidGeometry(
        "geometry.lines[0] must contain at least two coordinates",
      ),
    ),
  )
  let empty_polygon : Array[Array[@moon_geocodec.Coordinate]] = []
  assert_eq(
    @moon_geocodec.validate_geometry(
      @moon_geocodec.Geometry::MultiPolygon([empty_polygon]),
    ),
    Err(
      @moon_geocodec.InvalidGeometry("geometry.polygons[0] must not be empty"),
    ),
  )
}

///|
test "geometry normalization removes duplicates and closes rings" {
  let line = @moon_geocodec.Geometry::LineString([
    @moon_geocodec.Coordinate::xy(0.0, 0.0),
    @moon_geocodec.Coordinate::xy(0.0, 0.0),
    @moon_geocodec.Coordinate::xy(1.0, 1.0),
  ])
  assert_eq(
    @moon_geocodec.normalize_geometry(line),
    Ok(
      @moon_geocodec.Geometry::LineString([
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
      ]),
    ),
  )
  let polygon = @moon_geocodec.Geometry::Polygon([
    [
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(1.0, 0.0),
      @moon_geocodec.Coordinate::xy(1.0, 1.0),
    ],
  ])
  assert_eq(
    @moon_geocodec.normalize_geometry(polygon),
    Ok(
      @moon_geocodec.Geometry::Polygon([
        [
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 1.0),
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
        ],
      ]),
    ),
  )
}

///|
test "geometry normalization orients exterior and interior rings" {
  let polygon = @moon_geocodec.Geometry::Polygon([
    [
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(0.0, 2.0),
      @moon_geocodec.Coordinate::xy(2.0, 2.0),
      @moon_geocodec.Coordinate::xy(2.0, 0.0),
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
    ],
    [
      @moon_geocodec.Coordinate::xy(0.5, 0.5),
      @moon_geocodec.Coordinate::xy(1.5, 0.5),
      @moon_geocodec.Coordinate::xy(1.5, 1.5),
      @moon_geocodec.Coordinate::xy(0.5, 1.5),
      @moon_geocodec.Coordinate::xy(0.5, 0.5),
    ],
  ])
  let expected = @moon_geocodec.Geometry::Polygon([
    [
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(2.0, 0.0),
      @moon_geocodec.Coordinate::xy(2.0, 2.0),
      @moon_geocodec.Coordinate::xy(0.0, 2.0),
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
    ],
    [
      @moon_geocodec.Coordinate::xy(0.5, 0.5),
      @moon_geocodec.Coordinate::xy(0.5, 1.5),
      @moon_geocodec.Coordinate::xy(1.5, 1.5),
      @moon_geocodec.Coordinate::xy(1.5, 0.5),
      @moon_geocodec.Coordinate::xy(0.5, 0.5),
    ],
  ])
  assert_eq(@moon_geocodec.normalize_geometry(polygon), Ok(expected))
}

///|
test "geometry normalization is idempotent and validates its result" {
  let geometry = @moon_geocodec.Geometry::GeometryCollection([
    @moon_geocodec.Geometry::LineString([
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(2.0, 0.0),
    ]),
    @moon_geocodec.Geometry::Polygon([
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(0.0, 1.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
      ],
    ]),
  ])
  let normalized = match @moon_geocodec.normalize_geometry(geometry) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(@moon_geocodec.validate_geometry(normalized), Ok(()))
  assert_eq(@moon_geocodec.normalize_geometry(normalized), Ok(normalized))
}
