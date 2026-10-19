///|
fn format_wkb_ok(geometry : @moon_geocodec.Geometry) -> Bytes raise {
  match @moon_geocodec.format_wkb(geometry) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
fn format_wkb_order_ok(
  geometry : @moon_geocodec.Geometry,
  order : @moon_geocodec.WkbByteOrder,
) -> Bytes raise {
  match @moon_geocodec.format_wkb_with_order(geometry, order) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
test "WKB writer emits exact little and big endian point bytes" {
  let point = @moon_geocodec.Geometry::Point(
    @moon_geocodec.Coordinate::xy(1.5, -2.25),
  )
  let little_expected : Array[Byte] = []
  push_wkb_order(little_expected, true)
  push_wkb_u32(little_expected, 1U, true)
  push_wkb_f64(little_expected, 1.5, true)
  push_wkb_f64(little_expected, -2.25, true)
  assert_eq(format_wkb_ok(point), Bytes::from_array(little_expected))
  let big_expected : Array[Byte] = []
  push_wkb_order(big_expected, false)
  push_wkb_u32(big_expected, 1U, false)
  push_wkb_f64(big_expected, 1.5, false)
  push_wkb_f64(big_expected, -2.25, false)
  assert_eq(
    format_wkb_order_ok(point, @moon_geocodec.WkbByteOrder::BigEndian),
    Bytes::from_array(big_expected),
  )
}

///|
test "WKB writer emits an exact little endian line string" {
  let geometry = @moon_geocodec.Geometry::LineString([
    @moon_geocodec.Coordinate::xy(0.0, 0.0),
    @moon_geocodec.Coordinate::xy(1.0, 1.0),
  ])
  let expected : Array[Byte] = []
  push_wkb_order(expected, true)
  push_wkb_u32(expected, 2U, true)
  push_wkb_u32(expected, 2U, true)
  push_wkb_f64(expected, 0.0, true)
  push_wkb_f64(expected, 0.0, true)
  push_wkb_f64(expected, 1.0, true)
  push_wkb_f64(expected, 1.0, true)
  assert_eq(format_wkb_ok(geometry), Bytes::from_array(expected))
}

///|
test "WKB writer output round trips for every geometry variant" {
  let samples : Array[@moon_geocodec.Geometry] = [
    @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
    @moon_geocodec.Geometry::EmptyPoint,
    @moon_geocodec.Geometry::LineString([
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(1.0, 1.0),
    ]),
    @moon_geocodec.Geometry::LineString([]),
    @moon_geocodec.Geometry::Polygon([
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
      ],
    ]),
    @moon_geocodec.Geometry::Polygon([]),
    @moon_geocodec.Geometry::MultiPoint([
      @moon_geocodec.Coordinate::xy(1.0, 2.0),
      @moon_geocodec.Coordinate::xy(3.0, 4.0),
    ]),
    @moon_geocodec.Geometry::MultiLineString([
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
      ],
      [],
    ]),
    @moon_geocodec.Geometry::MultiPolygon([
      [
        [
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 1.0),
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
        ],
      ],
      [],
    ]),
    @moon_geocodec.Geometry::GeometryCollection([
      @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
      @moon_geocodec.Geometry::LineString([]),
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

///|
test "WKB writer rejects dimensions and invalid coordinates" {
  assert_eq(
    @moon_geocodec.format_wkb(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
      ),
    ),
    Err(
      @moon_geocodec.InvalidCoordinate(
        "WKB writer supports only XY coordinates",
      ),
    ),
  )
  assert_eq(
    @moon_geocodec.format_wkb(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xym(1.0, 2.0, 3.0),
      ),
    ),
    Err(
      @moon_geocodec.InvalidCoordinate(
        "WKB writer supports only XY coordinates",
      ),
    ),
  )
  assert_eq(
    @moon_geocodec.format_wkb(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xy(@double.infinity, 2.0),
      ),
    ),
    Err(@moon_geocodec.InvalidCoordinate("non-finite x ordinate")),
  )
  let empty_ring : Array[@moon_geocodec.Coordinate] = []
  assert_eq(
    @moon_geocodec.format_wkb(@moon_geocodec.Geometry::Polygon([empty_ring])),
    Err(@moon_geocodec.InvalidCoordinate("polygon ring has no coordinates")),
  )
}
