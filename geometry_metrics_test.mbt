///|
fn assert_double_close(actual : Double, expected : Double) -> Unit raise {
  assert_true((actual - expected).abs() < 1.0e-9)
}

///|
fn assert_centroid(
  actual : @moon_geocodec.Coordinate?,
  x : Double,
  y : Double,
  z : Double?,
) -> Unit raise {
  match actual {
    Some(value) => {
      assert_double_close(value.x, x)
      assert_double_close(value.y, y)
      match (value.z, z) {
        (Some(actual_z), Some(expected_z)) =>
          assert_double_close(actual_z, expected_z)
        (None, None) => ()
        _ => fail("centroid z mismatch")
      }
    }
    None => fail("expected centroid")
  }
}

///|
test "3D bounds include z and use zero for 2D coordinates" {
  let geometry = @moon_geocodec.Geometry::LineString([
    @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    @moon_geocodec.Coordinate::xy(4.0, 5.0),
  ])
  match geometry.bounds_3d() {
    Some(bounds) => {
      assert_eq(bounds.min_x, 1.0)
      assert_eq(bounds.min_y, 2.0)
      assert_eq(bounds.min_z, 0.0)
      assert_eq(bounds.max_x, 4.0)
      assert_eq(bounds.max_y, 5.0)
      assert_eq(bounds.max_z, 3.0)
      assert_eq(bounds.width(), 3.0)
      assert_eq(bounds.height(), 3.0)
      assert_eq(bounds.depth(), 3.0)
      assert_eq(bounds.extent(), (3.0, 3.0, 3.0))
    }
    None => fail("expected bounds")
  }
  assert_eq(
    (@moon_geocodec.Geometry::GeometryCollection([]) : @moon_geocodec.Geometry).bounds_3d(),
    None,
  )
}

///|
test "3D bounds merge polygons and collections" {
  let geometry = @moon_geocodec.Geometry::GeometryCollection([
    @moon_geocodec.Geometry::Polygon([
      [
        @moon_geocodec.Coordinate::xyz(0.0, 0.0, 1.0),
        @moon_geocodec.Coordinate::xyz(2.0, 0.0, 2.0),
        @moon_geocodec.Coordinate::xyz(2.0, 2.0, 3.0),
        @moon_geocodec.Coordinate::xyz(0.0, 0.0, 1.0),
      ],
    ]),
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyz(-1.0, 4.0, 5.0),
    ),
  ])
  match geometry.bounds_3d() {
    Some(bounds) => {
      assert_eq(bounds.min_x, -1.0)
      assert_eq(bounds.min_y, 0.0)
      assert_eq(bounds.min_z, 1.0)
      assert_eq(bounds.max_x, 2.0)
      assert_eq(bounds.max_y, 4.0)
      assert_eq(bounds.max_z, 5.0)
    }
    None => fail("expected bounds")
  }
}

///|
test "point and multipoint centroids use coordinate averages" {
  assert_centroid(
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    ).centroid(),
    1.0,
    2.0,
    Some(3.0),
  )
  assert_centroid(
    @moon_geocodec.Geometry::MultiPoint([
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(2.0, 4.0),
    ]).centroid(),
    1.0,
    2.0,
    None,
  )
  assert_eq(@moon_geocodec.Geometry::EmptyPoint.centroid(), None)
}

///|
test "line and polygon centroids are geometry weighted" {
  assert_centroid(
    @moon_geocodec.Geometry::LineString([
      @moon_geocodec.Coordinate::xyz(0.0, 0.0, 0.0),
      @moon_geocodec.Coordinate::xyz(2.0, 0.0, 2.0),
    ]).centroid(),
    1.0,
    0.0,
    Some(1.0),
  )
  assert_centroid(
    @moon_geocodec.Geometry::Polygon([
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(2.0, 0.0),
        @moon_geocodec.Coordinate::xy(2.0, 2.0),
        @moon_geocodec.Coordinate::xy(0.0, 2.0),
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
      ],
    ]).centroid(),
    1.0,
    1.0,
    None,
  )
}

///|
test "polygon holes subtract area from the centroid" {
  let polygon = @moon_geocodec.Geometry::Polygon([
    [
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(4.0, 0.0),
      @moon_geocodec.Coordinate::xy(4.0, 4.0),
      @moon_geocodec.Coordinate::xy(0.0, 4.0),
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
    ],
    [
      @moon_geocodec.Coordinate::xy(1.0, 1.0),
      @moon_geocodec.Coordinate::xy(2.0, 1.0),
      @moon_geocodec.Coordinate::xy(2.0, 2.0),
      @moon_geocodec.Coordinate::xy(1.0, 2.0),
      @moon_geocodec.Coordinate::xy(1.0, 1.0),
    ],
  ])
  assert_centroid(polygon.centroid(), 30.5 / 15.0, 30.5 / 15.0, None)
}

///|
test "geometry collections prefer the highest dimension centroid" {
  let point = @moon_geocodec.Geometry::Point(
    @moon_geocodec.Coordinate::xy(100.0, 100.0),
  )
  let line = @moon_geocodec.Geometry::LineString([
    @moon_geocodec.Coordinate::xy(0.0, 0.0),
    @moon_geocodec.Coordinate::xy(2.0, 0.0),
  ])
  assert_centroid(
    @moon_geocodec.Geometry::GeometryCollection([point, line]).centroid(),
    1.0,
    0.0,
    None,
  )
  let polygon = @moon_geocodec.Geometry::Polygon([
    [
      @moon_geocodec.Coordinate::xy(10.0, 0.0),
      @moon_geocodec.Coordinate::xy(12.0, 0.0),
      @moon_geocodec.Coordinate::xy(12.0, 2.0),
      @moon_geocodec.Coordinate::xy(10.0, 2.0),
      @moon_geocodec.Coordinate::xy(10.0, 0.0),
    ],
  ])
  assert_centroid(
    @moon_geocodec.Geometry::GeometryCollection([line, polygon]).centroid(),
    11.0,
    1.0,
    None,
  )
}

///|
test "3D polygon centroid propagates z when complete" {
  assert_centroid(
    @moon_geocodec.Geometry::Polygon([
      [
        @moon_geocodec.Coordinate::xyz(0.0, 0.0, 0.0),
        @moon_geocodec.Coordinate::xyz(2.0, 0.0, 2.0),
        @moon_geocodec.Coordinate::xyz(2.0, 2.0, 2.0),
        @moon_geocodec.Coordinate::xyz(0.0, 2.0, 0.0),
        @moon_geocodec.Coordinate::xyz(0.0, 0.0, 0.0),
      ],
    ]).centroid(),
    1.0,
    1.0,
    Some(1.0),
  )
}
