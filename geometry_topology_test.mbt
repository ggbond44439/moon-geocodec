///|
test "topology validation accepts simple geometries" {
  let line = @moon_geocodec.Geometry::LineString([
    @moon_geocodec.Coordinate::xy(0.0, 0.0),
    @moon_geocodec.Coordinate::xy(1.0, 1.0),
    @moon_geocodec.Coordinate::xy(2.0, 0.0),
  ])
  assert_eq(@moon_geocodec.validate_geometry_topology(line), Ok(()))
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
  assert_eq(@moon_geocodec.validate_geometry_topology(polygon), Ok(()))
}

///|
test "topology validation rejects self-intersecting lines" {
  let line = @moon_geocodec.Geometry::LineString([
    @moon_geocodec.Coordinate::xy(0.0, 0.0),
    @moon_geocodec.Coordinate::xy(2.0, 2.0),
    @moon_geocodec.Coordinate::xy(0.0, 2.0),
    @moon_geocodec.Coordinate::xy(2.0, 0.0),
  ])
  assert_eq(
    @moon_geocodec.validate_geometry_topology(line),
    Err(@moon_geocodec.InvalidGeometry("geometry self-intersects")),
  )
}

///|
test "topology validation rejects holes outside and crossing shells" {
  let outside = @moon_geocodec.Geometry::Polygon([
    [
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(4.0, 0.0),
      @moon_geocodec.Coordinate::xy(4.0, 4.0),
      @moon_geocodec.Coordinate::xy(0.0, 4.0),
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
    ],
    [
      @moon_geocodec.Coordinate::xy(5.0, 5.0),
      @moon_geocodec.Coordinate::xy(6.0, 5.0),
      @moon_geocodec.Coordinate::xy(6.0, 6.0),
      @moon_geocodec.Coordinate::xy(5.0, 6.0),
      @moon_geocodec.Coordinate::xy(5.0, 5.0),
    ],
  ])
  assert_eq(
    @moon_geocodec.validate_geometry_topology(outside),
    Err(@moon_geocodec.InvalidBoundary("geometry hole is outside shell", 1)),
  )
  let crossing = @moon_geocodec.Geometry::Polygon([
    [
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(4.0, 0.0),
      @moon_geocodec.Coordinate::xy(4.0, 4.0),
      @moon_geocodec.Coordinate::xy(0.0, 4.0),
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
    ],
    [
      @moon_geocodec.Coordinate::xy(3.0, 3.0),
      @moon_geocodec.Coordinate::xy(5.0, 3.0),
      @moon_geocodec.Coordinate::xy(5.0, 5.0),
      @moon_geocodec.Coordinate::xy(3.0, 5.0),
      @moon_geocodec.Coordinate::xy(3.0, 3.0),
    ],
  ])
  assert_eq(
    @moon_geocodec.validate_geometry_topology(crossing),
    Err(@moon_geocodec.InvalidBoundary("geometry hole intersects shell", 1)),
  )
}

///|
test "topology validation rejects overlapping multipolygons" {
  let geometry = @moon_geocodec.Geometry::MultiPolygon([
    [
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(2.0, 0.0),
        @moon_geocodec.Coordinate::xy(2.0, 2.0),
        @moon_geocodec.Coordinate::xy(0.0, 2.0),
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
      ],
    ],
    [
      [
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
        @moon_geocodec.Coordinate::xy(3.0, 1.0),
        @moon_geocodec.Coordinate::xy(3.0, 3.0),
        @moon_geocodec.Coordinate::xy(1.0, 3.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
      ],
    ],
  ])
  assert_eq(
    @moon_geocodec.validate_geometry_topology(geometry),
    Err(
      @moon_geocodec.InvalidGeometry(
        "geometry.polygons[0] overlaps polygons[1]",
      ),
    ),
  )
}
