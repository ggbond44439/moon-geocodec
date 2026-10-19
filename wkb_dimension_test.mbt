///|
fn push_dimension_offset(
  out : Array[Byte],
  base_code : UInt32,
  dimension : @moon_geocodec.CoordinateDimension,
  little : Bool,
) -> Unit {
  let offset = match dimension {
    @moon_geocodec.CoordinateDimension::Xy => 0U
    @moon_geocodec.CoordinateDimension::Xyz => 1000U
    @moon_geocodec.CoordinateDimension::Xym => 2000U
    @moon_geocodec.CoordinateDimension::Xyzm => 3000U
  }
  push_wkb_order(out, little)
  push_wkb_u32(out, base_code + offset, little)
}

///|
fn push_dimensioned_coordinate(
  out : Array[Byte],
  coordinate : @moon_geocodec.Coordinate,
  dimension : @moon_geocodec.CoordinateDimension,
  little : Bool,
) -> Unit raise {
  push_wkb_f64(out, coordinate.x, little)
  push_wkb_f64(out, coordinate.y, little)
  match dimension {
    @moon_geocodec.CoordinateDimension::Xyz
    | @moon_geocodec.CoordinateDimension::Xyzm =>
      match coordinate.z {
        Some(value) => push_wkb_f64(out, value, little)
        None => fail("missing z ordinate")
      }
    _ => ()
  }
  match dimension {
    @moon_geocodec.CoordinateDimension::Xym
    | @moon_geocodec.CoordinateDimension::Xyzm =>
      match coordinate.m {
        Some(value) => push_wkb_f64(out, value, little)
        None => fail("missing m ordinate")
      }
    _ => ()
  }
}

///|
fn parse_wkb_bytes_ok(bytes : Array[Byte]) -> @moon_geocodec.Geometry raise {
  match
    @moon_geocodec.parse_wkb(
      Bytes::from_array(bytes).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
test "WKB reader parses Z M and ZM points" {
  let point_z : Array[Byte] = []
  push_dimension_offset(
    point_z,
    1U,
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  push_dimensioned_coordinate(
    point_z,
    @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  assert_eq(
    parse_wkb_bytes_ok(point_z),
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    ),
  )
  let point_m : Array[Byte] = []
  push_dimension_offset(
    point_m,
    1U,
    @moon_geocodec.CoordinateDimension::Xym,
    true,
  )
  push_dimensioned_coordinate(
    point_m,
    @moon_geocodec.Coordinate::xym(1.0, 2.0, 4.0),
    @moon_geocodec.CoordinateDimension::Xym,
    true,
  )
  assert_eq(
    parse_wkb_bytes_ok(point_m),
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xym(1.0, 2.0, 4.0),
    ),
  )
  let point_zm : Array[Byte] = []
  push_dimension_offset(
    point_zm,
    1U,
    @moon_geocodec.CoordinateDimension::Xyzm,
    false,
  )
  push_dimensioned_coordinate(
    point_zm,
    @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
    @moon_geocodec.CoordinateDimension::Xyzm,
    false,
  )
  assert_eq(
    parse_wkb_bytes_ok(point_zm),
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
    ),
  )
}

///|
test "WKB reader parses dimensioned multipart geometries" {
  let multi_point : Array[Byte] = []
  push_dimension_offset(
    multi_point,
    4U,
    @moon_geocodec.CoordinateDimension::Xyzm,
    true,
  )
  push_wkb_u32(multi_point, 2U, true)
  let first = @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0)
  let second = @moon_geocodec.Coordinate::xyzm(5.0, 6.0, 7.0, 8.0)
  push_dimension_offset(
    multi_point,
    1U,
    @moon_geocodec.CoordinateDimension::Xyzm,
    true,
  )
  push_dimensioned_coordinate(
    multi_point,
    first,
    @moon_geocodec.CoordinateDimension::Xyzm,
    true,
  )
  push_dimension_offset(
    multi_point,
    1U,
    @moon_geocodec.CoordinateDimension::Xyzm,
    true,
  )
  push_dimensioned_coordinate(
    multi_point,
    second,
    @moon_geocodec.CoordinateDimension::Xyzm,
    true,
  )
  assert_eq(
    parse_wkb_bytes_ok(multi_point),
    @moon_geocodec.Geometry::MultiPoint([first, second]),
  )
  let collection : Array[Byte] = []
  push_dimension_offset(
    collection,
    7U,
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  push_wkb_u32(collection, 1U, true)
  push_dimension_offset(
    collection,
    2U,
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  push_wkb_u32(collection, 2U, true)
  push_dimensioned_coordinate(
    collection,
    @moon_geocodec.Coordinate::xyz(0.0, 0.0, 1.0),
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  push_dimensioned_coordinate(
    collection,
    @moon_geocodec.Coordinate::xyz(1.0, 1.0, 2.0),
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  assert_eq(
    parse_wkb_bytes_ok(collection),
    @moon_geocodec.Geometry::GeometryCollection([
      @moon_geocodec.Geometry::LineString([
        @moon_geocodec.Coordinate::xyz(0.0, 0.0, 1.0),
        @moon_geocodec.Coordinate::xyz(1.0, 1.0, 2.0),
      ]),
    ]),
  )
}

///|
test "WKB reader parses empty dimensioned geometries" {
  let empty_point : Array[Byte] = []
  push_dimension_offset(
    empty_point,
    1U,
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  push_dimensioned_coordinate(
    empty_point,
    @moon_geocodec.Coordinate::xyz(
      @double.not_a_number, @double.not_a_number, @double.not_a_number,
    ),
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  assert_eq(
    parse_wkb_bytes_ok(empty_point),
    @moon_geocodec.Geometry::EmptyPoint,
  )
  let empty_line : Array[Byte] = []
  push_dimension_offset(
    empty_line,
    2U,
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  push_wkb_u32(empty_line, 0U, true)
  assert_eq(
    parse_wkb_bytes_ok(empty_line),
    (@moon_geocodec.Geometry::LineString([]) : @moon_geocodec.Geometry),
  )
  let empty_polygon : Array[Byte] = []
  push_dimension_offset(
    empty_polygon,
    3U,
    @moon_geocodec.CoordinateDimension::Xym,
    true,
  )
  push_wkb_u32(empty_polygon, 0U, true)
  assert_eq(
    parse_wkb_bytes_ok(empty_polygon),
    (@moon_geocodec.Geometry::Polygon([]) : @moon_geocodec.Geometry),
  )
  let empty_multi_point : Array[Byte] = []
  push_dimension_offset(
    empty_multi_point,
    4U,
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  push_wkb_u32(empty_multi_point, 0U, true)
  assert_eq(
    parse_wkb_bytes_ok(empty_multi_point),
    (@moon_geocodec.Geometry::MultiPoint([]) : @moon_geocodec.Geometry),
  )
  let empty_multi_line : Array[Byte] = []
  push_dimension_offset(
    empty_multi_line,
    5U,
    @moon_geocodec.CoordinateDimension::Xym,
    true,
  )
  push_wkb_u32(empty_multi_line, 0U, true)
  assert_eq(
    parse_wkb_bytes_ok(empty_multi_line),
    (@moon_geocodec.Geometry::MultiLineString([]) : @moon_geocodec.Geometry),
  )
  let empty_multi_polygon : Array[Byte] = []
  push_dimension_offset(
    empty_multi_polygon,
    6U,
    @moon_geocodec.CoordinateDimension::Xyzm,
    true,
  )
  push_wkb_u32(empty_multi_polygon, 0U, true)
  assert_eq(
    parse_wkb_bytes_ok(empty_multi_polygon),
    (@moon_geocodec.Geometry::MultiPolygon([]) : @moon_geocodec.Geometry),
  )
  let empty_collection : Array[Byte] = []
  push_dimension_offset(
    empty_collection,
    7U,
    @moon_geocodec.CoordinateDimension::Xyzm,
    true,
  )
  push_wkb_u32(empty_collection, 0U, true)
  assert_eq(
    parse_wkb_bytes_ok(empty_collection),
    (@moon_geocodec.Geometry::GeometryCollection([]) : @moon_geocodec.Geometry),
  )
}

///|
test "WKB reader rejects component dimension mismatches" {
  let multi_point : Array[Byte] = []
  push_dimension_offset(
    multi_point,
    4U,
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  push_wkb_u32(multi_point, 1U, true)
  push_dimension_offset(
    multi_point,
    1U,
    @moon_geocodec.CoordinateDimension::Xy,
    true,
  )
  push_wkb_f64(multi_point, 1.0, true)
  push_wkb_f64(multi_point, 2.0, true)
  assert_eq(
    @moon_geocodec.parse_wkb(
      Bytes::from_array(multi_point).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(
      @moon_geocodec.InvalidWkb(
        "MULTIPOINT component dimension does not match parent", 9,
      ),
    ),
  )
  let collection : Array[Byte] = []
  push_dimension_offset(
    collection,
    7U,
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  push_wkb_u32(collection, 1U, true)
  push_dimension_offset(
    collection,
    2U,
    @moon_geocodec.CoordinateDimension::Xy,
    true,
  )
  push_wkb_u32(collection, 0U, true)
  assert_eq(
    @moon_geocodec.parse_wkb(
      Bytes::from_array(collection).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(
      @moon_geocodec.InvalidWkb(
        "GEOMETRYCOLLECTION component dimension does not match parent", 9,
      ),
    ),
  )
}

///|
test "WKB writer emits dimensional type codes and ordinates" {
  let geometry = @moon_geocodec.Geometry::Point(
    @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
  )
  let expected : Array[Byte] = []
  push_dimension_offset(
    expected,
    1U,
    @moon_geocodec.CoordinateDimension::Xyzm,
    false,
  )
  push_dimensioned_coordinate(
    expected,
    @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
    @moon_geocodec.CoordinateDimension::Xyzm,
    false,
  )
  assert_eq(
    format_wkb_order_ok(geometry, @moon_geocodec.WkbByteOrder::BigEndian),
    Bytes::from_array(expected),
  )
}

///|
test "WKB writer round trips dimensional and empty geometries" {
  let z_line : Array[@moon_geocodec.Coordinate] = [
    @moon_geocodec.Coordinate::xyz(0.0, 0.0, 1.0),
    @moon_geocodec.Coordinate::xyz(1.0, 1.0, 2.0),
  ]
  let empty_line : Array[@moon_geocodec.Coordinate] = []
  let m_polygon : Array[Array[@moon_geocodec.Coordinate]] = [
    [
      @moon_geocodec.Coordinate::xym(0.0, 0.0, 1.0),
      @moon_geocodec.Coordinate::xym(1.0, 0.0, 2.0),
      @moon_geocodec.Coordinate::xym(1.0, 1.0, 3.0),
      @moon_geocodec.Coordinate::xym(0.0, 0.0, 1.0),
    ],
  ]
  let empty_polygon : Array[Array[@moon_geocodec.Coordinate]] = []
  let samples : Array[@moon_geocodec.Geometry] = [
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    ),
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xym(1.0, 2.0, 3.0),
    ),
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
    ),
    @moon_geocodec.Geometry::LineString(z_line),
    @moon_geocodec.Geometry::Polygon(m_polygon),
    @moon_geocodec.Geometry::MultiPoint([
      @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
      @moon_geocodec.Coordinate::xyzm(5.0, 6.0, 7.0, 8.0),
    ]),
    @moon_geocodec.Geometry::MultiLineString([z_line, empty_line]),
    @moon_geocodec.Geometry::MultiPolygon([m_polygon, empty_polygon]),
    @moon_geocodec.Geometry::GeometryCollection([
      @moon_geocodec.Geometry::EmptyPoint,
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
      ),
      @moon_geocodec.Geometry::LineString(z_line),
    ]),
  ]
  let orders : Array[@moon_geocodec.WkbByteOrder] = [
    @moon_geocodec.WkbByteOrder::LittleEndian,
    @moon_geocodec.WkbByteOrder::BigEndian,
  ]
  for order in orders {
    for geometry in samples {
      let bytes = format_wkb_order_ok(geometry, order)
      let parsed = match
        @moon_geocodec.parse_wkb(
          bytes.exact_view(),
          @moon_geocodec.GeoLimits::default(),
        ) {
        Ok(value) => value
        Err(err) => fail(err.to_string())
      }
      assert_eq(parsed, geometry)
    }
  }
}
