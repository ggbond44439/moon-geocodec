///|
fn push_wkb_order(out : Array[Byte], little : Bool) -> Unit {
  out.push(if little { b'\x01' } else { b'\x00' })
}

///|
fn push_wkb_u32(out : Array[Byte], value : UInt32, little : Bool) -> Unit {
  if little {
    out.push(value.land(255U).to_byte())
    out.push((value >> 8).land(255U).to_byte())
    out.push((value >> 16).land(255U).to_byte())
    out.push((value >> 24).land(255U).to_byte())
  } else {
    out.push((value >> 24).land(255U).to_byte())
    out.push((value >> 16).land(255U).to_byte())
    out.push((value >> 8).land(255U).to_byte())
    out.push(value.land(255U).to_byte())
  }
}

///|
fn push_wkb_f64(out : Array[Byte], value : Double, little : Bool) -> Unit {
  let bits = value.reinterpret_as_uint64()
  for index in 0..<8 {
    let shift = if little { index * 8 } else { (7 - index) * 8 }
    out.push((bits >> shift).land(255UL).to_byte())
  }
}

///|
fn push_wkb_point(
  out : Array[Byte],
  x : Double,
  y : Double,
  little : Bool,
) -> Unit {
  push_wkb_order(out, little)
  push_wkb_u32(out, 1U, little)
  push_wkb_f64(out, x, little)
  push_wkb_f64(out, y, little)
}

///|
fn parse_wkb_ok(bytes : Array[Byte]) -> @moon_geocodec.Geometry raise {
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
test "WKB reader parses little and big endian points" {
  let little : Array[Byte] = []
  push_wkb_order(little, true)
  push_wkb_u32(little, 1U, true)
  push_wkb_f64(little, 1.5, true)
  push_wkb_f64(little, -2.25, true)
  assert_eq(
    parse_wkb_ok(little),
    @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.5, -2.25)),
  )
  let big : Array[Byte] = []
  push_wkb_order(big, false)
  push_wkb_u32(big, 1U, false)
  push_wkb_f64(big, 1.5, false)
  push_wkb_f64(big, -2.25, false)
  assert_eq(
    parse_wkb_ok(big),
    @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.5, -2.25)),
  )
}

///|
test "WKB reader parses line strings and polygons" {
  let line : Array[Byte] = []
  push_wkb_order(line, true)
  push_wkb_u32(line, 2U, true)
  push_wkb_u32(line, 2U, true)
  push_wkb_f64(line, 0.0, true)
  push_wkb_f64(line, 0.0, true)
  push_wkb_f64(line, 1.0, true)
  push_wkb_f64(line, 1.0, true)
  assert_eq(
    parse_wkb_ok(line),
    @moon_geocodec.Geometry::LineString([
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(1.0, 1.0),
    ]),
  )
  let polygon : Array[Byte] = []
  push_wkb_order(polygon, true)
  push_wkb_u32(polygon, 3U, true)
  push_wkb_u32(polygon, 1U, true)
  push_wkb_u32(polygon, 4U, true)
  push_wkb_f64(polygon, 0.0, true)
  push_wkb_f64(polygon, 0.0, true)
  push_wkb_f64(polygon, 1.0, true)
  push_wkb_f64(polygon, 0.0, true)
  push_wkb_f64(polygon, 1.0, true)
  push_wkb_f64(polygon, 1.0, true)
  push_wkb_f64(polygon, 0.0, true)
  push_wkb_f64(polygon, 0.0, true)
  assert_eq(
    parse_wkb_ok(polygon),
    @moon_geocodec.Geometry::Polygon([
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
      ],
    ]),
  )
}

///|
test "WKB reader parses multipart geometries with mixed child endianness" {
  let multi_point : Array[Byte] = []
  push_wkb_order(multi_point, true)
  push_wkb_u32(multi_point, 4U, true)
  push_wkb_u32(multi_point, 2U, true)
  push_wkb_point(multi_point, 1.0, 2.0, true)
  push_wkb_point(multi_point, 3.0, 4.0, false)
  assert_eq(
    parse_wkb_ok(multi_point),
    @moon_geocodec.Geometry::MultiPoint([
      @moon_geocodec.Coordinate::xy(1.0, 2.0),
      @moon_geocodec.Coordinate::xy(3.0, 4.0),
    ]),
  )
  let multi_line : Array[Byte] = []
  push_wkb_order(multi_line, true)
  push_wkb_u32(multi_line, 5U, true)
  push_wkb_u32(multi_line, 1U, true)
  push_wkb_order(multi_line, true)
  push_wkb_u32(multi_line, 2U, true)
  push_wkb_u32(multi_line, 2U, true)
  push_wkb_f64(multi_line, 0.0, true)
  push_wkb_f64(multi_line, 0.0, true)
  push_wkb_f64(multi_line, 1.0, true)
  push_wkb_f64(multi_line, 1.0, true)
  assert_eq(
    parse_wkb_ok(multi_line),
    @moon_geocodec.Geometry::MultiLineString([
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
      ],
    ]),
  )
  let multi_polygon : Array[Byte] = []
  push_wkb_order(multi_polygon, true)
  push_wkb_u32(multi_polygon, 6U, true)
  push_wkb_u32(multi_polygon, 1U, true)
  push_wkb_order(multi_polygon, true)
  push_wkb_u32(multi_polygon, 3U, true)
  push_wkb_u32(multi_polygon, 1U, true)
  push_wkb_u32(multi_polygon, 4U, true)
  push_wkb_f64(multi_polygon, 0.0, true)
  push_wkb_f64(multi_polygon, 0.0, true)
  push_wkb_f64(multi_polygon, 1.0, true)
  push_wkb_f64(multi_polygon, 0.0, true)
  push_wkb_f64(multi_polygon, 1.0, true)
  push_wkb_f64(multi_polygon, 1.0, true)
  push_wkb_f64(multi_polygon, 0.0, true)
  push_wkb_f64(multi_polygon, 0.0, true)
  assert_eq(
    parse_wkb_ok(multi_polygon),
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
  )
}

///|
test "WKB reader parses geometry collections" {
  let collection : Array[Byte] = []
  push_wkb_order(collection, true)
  push_wkb_u32(collection, 7U, true)
  push_wkb_u32(collection, 2U, true)
  push_wkb_point(collection, 1.0, 2.0, true)
  push_wkb_order(collection, true)
  push_wkb_u32(collection, 2U, true)
  push_wkb_u32(collection, 2U, true)
  push_wkb_f64(collection, 0.0, true)
  push_wkb_f64(collection, 0.0, true)
  push_wkb_f64(collection, 1.0, true)
  push_wkb_f64(collection, 1.0, true)
  assert_eq(
    parse_wkb_ok(collection),
    @moon_geocodec.Geometry::GeometryCollection([
      @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
      @moon_geocodec.Geometry::LineString([
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
      ]),
    ]),
  )
}

///|
test "WKB reader parses empty basic geometries" {
  let empty_point : Array[Byte] = []
  push_wkb_order(empty_point, true)
  push_wkb_u32(empty_point, 1U, true)
  push_wkb_f64(empty_point, @double.not_a_number, true)
  push_wkb_f64(empty_point, @double.not_a_number, true)
  assert_eq(parse_wkb_ok(empty_point), @moon_geocodec.Geometry::EmptyPoint)
  let empty_line : Array[Byte] = []
  push_wkb_order(empty_line, true)
  push_wkb_u32(empty_line, 2U, true)
  push_wkb_u32(empty_line, 0U, true)
  assert_eq(
    parse_wkb_ok(empty_line),
    (@moon_geocodec.Geometry::LineString([]) : @moon_geocodec.Geometry),
  )
  let empty_polygon : Array[Byte] = []
  push_wkb_order(empty_polygon, true)
  push_wkb_u32(empty_polygon, 3U, true)
  push_wkb_u32(empty_polygon, 0U, true)
  assert_eq(
    parse_wkb_ok(empty_polygon),
    (@moon_geocodec.Geometry::Polygon([]) : @moon_geocodec.Geometry),
  )
  let empty_multi_point : Array[Byte] = []
  push_wkb_order(empty_multi_point, true)
  push_wkb_u32(empty_multi_point, 4U, true)
  push_wkb_u32(empty_multi_point, 0U, true)
  assert_eq(
    parse_wkb_ok(empty_multi_point),
    (@moon_geocodec.Geometry::MultiPoint([]) : @moon_geocodec.Geometry),
  )
  let empty_collection : Array[Byte] = []
  push_wkb_order(empty_collection, true)
  push_wkb_u32(empty_collection, 7U, true)
  push_wkb_u32(empty_collection, 0U, true)
  assert_eq(
    parse_wkb_ok(empty_collection),
    (@moon_geocodec.Geometry::GeometryCollection([]) : @moon_geocodec.Geometry),
  )
}

///|
test "WKB reader rejects malformed binary structures" {
  let limits = @moon_geocodec.GeoLimits::default()
  assert_eq(
    @moon_geocodec.parse_wkb(
      Bytes::from_array(([] : Array[Byte])).exact_view(),
      limits,
    ),
    Err(@moon_geocodec.Truncated("byte order", 0)),
  )
  assert_eq(
    @moon_geocodec.parse_wkb(Bytes::from_array([b'\x01']).exact_view(), limits),
    Err(@moon_geocodec.Truncated("geometry type", 1)),
  )
  assert_eq(
    @moon_geocodec.parse_wkb(Bytes::from_array([b'\x02']).exact_view(), limits),
    Err(@moon_geocodec.InvalidWkb("invalid byte order", 0)),
  )
  let unsupported : Array[Byte] = []
  push_wkb_order(unsupported, true)
  push_wkb_u32(unsupported, 8U, true)
  assert_eq(
    @moon_geocodec.parse_wkb(
      Bytes::from_array(unsupported).exact_view(),
      limits,
    ),
    Err(@moon_geocodec.UnsupportedGeometry("WKB type 8")),
  )
  let trailing : Array[Byte] = []
  push_wkb_point(trailing, 1.0, 2.0, true)
  trailing.push(b'\x00')
  assert_eq(
    @moon_geocodec.parse_wkb(Bytes::from_array(trailing).exact_view(), limits),
    Err(@moon_geocodec.TrailingBytes(21)),
  )
  let infinite : Array[Byte] = []
  push_wkb_order(infinite, true)
  push_wkb_u32(infinite, 1U, true)
  push_wkb_f64(infinite, @double.infinity, true)
  push_wkb_f64(infinite, 2.0, true)
  assert_eq(
    @moon_geocodec.parse_wkb(Bytes::from_array(infinite).exact_view(), limits),
    Err(@moon_geocodec.InvalidCoordinate("non-finite x ordinate")),
  )
}

///|
test "WKB reader rejects invalid counts and empty polygon rings" {
  let huge : Array[Byte] = []
  push_wkb_order(huge, true)
  push_wkb_u32(huge, 2U, true)
  push_wkb_u32(huge, 4294967295U, true)
  assert_eq(
    @moon_geocodec.parse_wkb(
      Bytes::from_array(huge).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(
      @moon_geocodec.InvalidWkb(
        "LINESTRING coordinate count exceeds supported range", 5,
      ),
    ),
  )
  let empty_ring : Array[Byte] = []
  push_wkb_order(empty_ring, true)
  push_wkb_u32(empty_ring, 3U, true)
  push_wkb_u32(empty_ring, 1U, true)
  push_wkb_u32(empty_ring, 0U, true)
  assert_eq(
    @moon_geocodec.parse_wkb(
      Bytes::from_array(empty_ring).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkb("polygon ring has no coordinates", 9)),
  )
}

///|
test "WKB reader enforces coordinate geometry and depth limits" {
  let line : Array[Byte] = []
  push_wkb_order(line, true)
  push_wkb_u32(line, 2U, true)
  push_wkb_u32(line, 2U, true)
  push_wkb_f64(line, 0.0, true)
  push_wkb_f64(line, 0.0, true)
  push_wkb_f64(line, 1.0, true)
  push_wkb_f64(line, 1.0, true)
  let coordinate_limits = match @moon_geocodec.GeoLimits::new(1024, 8, 8, 1) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.parse_wkb(
      Bytes::from_array(line).exact_view(),
      coordinate_limits,
    ),
    Err(@moon_geocodec.LimitExceeded("coordinate count", 1, 2)),
  )
  let collection : Array[Byte] = []
  push_wkb_order(collection, true)
  push_wkb_u32(collection, 7U, true)
  push_wkb_u32(collection, 1U, true)
  push_wkb_point(collection, 1.0, 2.0, true)
  let geometry_limits = match @moon_geocodec.GeoLimits::new(1024, 8, 1, 8) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.parse_wkb(
      Bytes::from_array(collection).exact_view(),
      geometry_limits,
    ),
    Err(@moon_geocodec.LimitExceeded("geometry count", 1, 2)),
  )
  let depth_limits = match @moon_geocodec.GeoLimits::new(1024, 1, 8, 8) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.parse_wkb(
      Bytes::from_array(collection).exact_view(),
      depth_limits,
    ),
    Err(@moon_geocodec.LimitExceeded("geometry depth", 1, 2)),
  )
}
