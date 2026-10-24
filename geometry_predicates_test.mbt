///|
test "point location distinguishes points lines and boundaries" {
  let point = @moon_geocodec.Geometry::Point(
    @moon_geocodec.Coordinate::xy(1.0, 2.0),
  )
  assert_eq(
    point.locate_point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
    @moon_geocodec.PointLocation::Inside,
  )
  let line = @moon_geocodec.Geometry::LineString([
    @moon_geocodec.Coordinate::xy(0.0, 0.0),
    @moon_geocodec.Coordinate::xy(4.0, 0.0),
  ])
  assert_eq(
    line.locate_point(@moon_geocodec.Coordinate::xy(2.0, 0.0)),
    @moon_geocodec.PointLocation::Inside,
  )
  assert_eq(
    line.locate_point(@moon_geocodec.Coordinate::xy(0.0, 0.0)),
    @moon_geocodec.PointLocation::Boundary,
  )
  assert_eq(
    line.locate_point(@moon_geocodec.Coordinate::xy(5.0, 0.0)),
    @moon_geocodec.PointLocation::Outside,
  )
  assert_eq(line.contains_point(@moon_geocodec.Coordinate::xy(0.0, 0.0)), false)
  assert_eq(line.covers_point(@moon_geocodec.Coordinate::xy(0.0, 0.0)), true)
}

///|
test "point location handles polygon holes and tolerance" {
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
      @moon_geocodec.Coordinate::xy(3.0, 1.0),
      @moon_geocodec.Coordinate::xy(3.0, 3.0),
      @moon_geocodec.Coordinate::xy(1.0, 3.0),
      @moon_geocodec.Coordinate::xy(1.0, 1.0),
    ],
  ])
  assert_eq(
    polygon.locate_point(@moon_geocodec.Coordinate::xy(0.5, 0.5)),
    @moon_geocodec.PointLocation::Inside,
  )
  assert_eq(
    polygon.locate_point(@moon_geocodec.Coordinate::xy(2.0, 2.0)),
    @moon_geocodec.PointLocation::Outside,
  )
  assert_eq(
    polygon.locate_point(@moon_geocodec.Coordinate::xy(0.0, 2.0)),
    @moon_geocodec.PointLocation::Boundary,
  )
  assert_eq(
    polygon.locate_point(
      @moon_geocodec.Coordinate::xy(4.0000000001, 2.0),
      tolerance=1.0e-9,
    ),
    @moon_geocodec.PointLocation::Boundary,
  )
}

///|
test "point location merges multipart geometries" {
  let geometry = @moon_geocodec.Geometry::MultiPolygon([
    [
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
        @moon_geocodec.Coordinate::xy(0.0, 1.0),
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
      ],
    ],
    [
      [
        @moon_geocodec.Coordinate::xy(10.0, 10.0),
        @moon_geocodec.Coordinate::xy(11.0, 10.0),
        @moon_geocodec.Coordinate::xy(11.0, 11.0),
        @moon_geocodec.Coordinate::xy(10.0, 11.0),
        @moon_geocodec.Coordinate::xy(10.0, 10.0),
      ],
    ],
  ])
  assert_eq(
    geometry.locate_point(@moon_geocodec.Coordinate::xy(10.5, 10.5)),
    @moon_geocodec.PointLocation::Inside,
  )
  let collection = @moon_geocodec.Geometry::GeometryCollection([
    @moon_geocodec.Geometry::LineString([
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(2.0, 0.0),
    ]),
    geometry,
  ])
  assert_eq(
    collection.locate_point(@moon_geocodec.Coordinate::xy(10.5, 10.5)),
    @moon_geocodec.PointLocation::Inside,
  )
}

///|
test "bounding boxes support containment and intersection" {
  let left : @moon_geocodec.BoundingBox = {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 4.0,
    max_y: 4.0,
  }
  let right : @moon_geocodec.BoundingBox = {
    min_x: 3.0,
    min_y: 3.0,
    max_x: 6.0,
    max_y: 6.0,
  }
  assert_eq(left.contains_xy(2.0, 2.0), true)
  assert_eq(left.contains_xy(5.0, 2.0), false)
  assert_eq(left.intersects(right), true)
  let above : @moon_geocodec.BoundingBox = {
    min_x: 0.0,
    min_y: 5.0,
    max_x: 2.0,
    max_y: 7.0,
  }
  assert_eq(left.intersects(above), false)
  let left_3d : @moon_geocodec.BoundingBox3D = {
    min_x: 0.0,
    min_y: 0.0,
    min_z: 0.0,
    max_x: 2.0,
    max_y: 2.0,
    max_z: 2.0,
  }
  let right_3d : @moon_geocodec.BoundingBox3D = {
    min_x: 1.0,
    min_y: 1.0,
    min_z: 1.0,
    max_x: 3.0,
    max_y: 3.0,
    max_z: 3.0,
  }
  assert_eq(left_3d.intersects(right_3d), true)
}
