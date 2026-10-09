///|
test "coordinate dimensions preserve optional Z and M ordinates" {
  let xy = @moon_geocodec.Coordinate::xy(1.0, 2.0)
  let xyz = @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0)
  let xym = @moon_geocodec.Coordinate::xym(1.0, 2.0, 4.0)
  let xyzm = @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0)
  assert_eq(xy.dimension(), @moon_geocodec.Xy)
  assert_eq(xyz.dimension(), @moon_geocodec.Xyz)
  assert_eq(xym.dimension(), @moon_geocodec.Xym)
  assert_eq(xyzm.dimension(), @moon_geocodec.Xyzm)
  assert_eq(xyz.has_z(), true)
  assert_eq(xym.has_m(), true)
  assert_eq(xy.has_z(), false)
  assert_eq(xy.has_m(), false)
}

///|
test "geometry variants report stable kinds and coordinate counts" {
  let a = @moon_geocodec.Coordinate::xy(0.0, 0.0)
  let b = @moon_geocodec.Coordinate::xy(1.0, 1.0)
  let c = @moon_geocodec.Coordinate::xy(2.0, 2.0)
  let point = @moon_geocodec.Geometry::Point(a)
  let line = @moon_geocodec.Geometry::LineString([a, b])
  let polygon = @moon_geocodec.Geometry::Polygon([[a, b, c, a]])
  let collection = @moon_geocodec.Geometry::GeometryCollection([
    point, line, polygon,
  ])
  assert_eq(point.kind(), @moon_geocodec.GeometryKind::Point)
  assert_eq(line.kind(), @moon_geocodec.GeometryKind::LineString)
  assert_eq(polygon.kind(), @moon_geocodec.GeometryKind::Polygon)
  assert_eq(collection.kind(), @moon_geocodec.GeometryKind::GeometryCollection)
  assert_eq(point.coordinate_count(), 1)
  assert_eq(line.coordinate_count(), 2)
  assert_eq(polygon.coordinate_count(), 4)
  assert_eq(collection.coordinate_count(), 7)
  assert_eq(point.is_empty(), false)
}

///|
test "geometry bounds fold nested coordinates" {
  let a = @moon_geocodec.Coordinate::xy(-2.0, 4.0)
  let b = @moon_geocodec.Coordinate::xy(3.0, -1.0)
  let c = @moon_geocodec.Coordinate::xy(5.0, 7.0)
  let geometry = @moon_geocodec.Geometry::MultiLineString([[a, b], [c]])
  match geometry.bounds() {
    Some(bounds) => {
      assert_eq(bounds.min_x, -2.0)
      assert_eq(bounds.min_y, -1.0)
      assert_eq(bounds.max_x, 5.0)
      assert_eq(bounds.max_y, 7.0)
      assert_eq(bounds.width(), 7.0)
      assert_eq(bounds.height(), 8.0)
    }
    None => fail("expected bounds")
  }
}

///|
test "empty geometries have no bounds" {
  let empty_line : @moon_geocodec.Geometry = @moon_geocodec.Geometry::LineString([],
  )
  let empty_collection : @moon_geocodec.Geometry = @moon_geocodec.GeometryCollection([],
  )
  assert_eq(empty_line.is_empty(), true)
  assert_eq(empty_collection.is_empty(), true)
  assert_eq(empty_line.bounds(), None)
  assert_eq(empty_collection.bounds(), None)
}

///|
test "limits reject invalid construction and enforce bounds" {
  assert_eq(
    @moon_geocodec.GeoLimits::new(0, 1, 1, 1),
    Err(@moon_geocodec.InvalidLimit("max_text_bytes", 0)),
  )
  let limits = @moon_geocodec.GeoLimits::new(10, 2, 3, 4)
  let value = match limits {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(value.check_text(10), Ok(()))
  assert_eq(
    value.check_text(11),
    Err(@moon_geocodec.LimitExceeded("text bytes", 10, 11)),
  )
  assert_eq(
    value.check_coordinates(5),
    Err(@moon_geocodec.LimitExceeded("coordinate count", 4, 5)),
  )
}
