///|
fn push_ewkb_header(
  out : Array[Byte],
  base_code : UInt32,
  dimension : @moon_geocodec.CoordinateDimension,
  srid : Int32?,
  little : Bool,
) -> Unit {
  let mut type_code = base_code
  match dimension {
    @moon_geocodec.CoordinateDimension::Xyz
    | @moon_geocodec.CoordinateDimension::Xyzm =>
      type_code = type_code | 0x80000000U
    _ => ()
  }
  match dimension {
    @moon_geocodec.CoordinateDimension::Xym
    | @moon_geocodec.CoordinateDimension::Xyzm =>
      type_code = type_code | 0x40000000U
    _ => ()
  }
  match srid {
    Some(_) => type_code = type_code | 0x20000000U
    None => ()
  }
  push_wkb_order(out, little)
  push_wkb_u32(out, type_code, little)
  match srid {
    Some(value) => push_wkb_u32(out, value.reinterpret_as_uint(), little)
    None => ()
  }
}

///|
fn parse_ewkb_ok(bytes : Array[Byte]) -> @moon_geocodec.SpatialGeometry raise {
  match
    @moon_geocodec.parse_ewkb(
      Bytes::from_array(bytes).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
test "EWKB reader parses PostGIS point with SRID" {
  let bytes : Array[Byte] = []
  push_ewkb_header(
    bytes,
    1U,
    @moon_geocodec.CoordinateDimension::Xy,
    Some(4326),
    true,
  )
  push_wkb_f64(bytes, 1.0, true)
  push_wkb_f64(bytes, 2.0, true)
  let parsed = parse_ewkb_ok(bytes)
  assert_eq(parsed.srid, Some(4326))
  assert_eq(
    parsed.geometry,
    @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
  )
}

///|
test "EWKB reader combines ZM flags and SRID in big endian" {
  let bytes : Array[Byte] = []
  push_ewkb_header(
    bytes,
    1U,
    @moon_geocodec.CoordinateDimension::Xyzm,
    Some(3857),
    false,
  )
  push_dimensioned_coordinate(
    bytes,
    @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
    @moon_geocodec.CoordinateDimension::Xyzm,
    false,
  )
  assert_eq(parse_ewkb_ok(bytes), {
    srid: Some(3857),
    geometry: @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
    ),
  })
}

///|
test "EWKB reader validates nested SRIDs and dimensions" {
  let collection : Array[Byte] = []
  push_ewkb_header(
    collection,
    7U,
    @moon_geocodec.CoordinateDimension::Xyz,
    Some(4326),
    true,
  )
  push_wkb_u32(collection, 1U, true)
  push_ewkb_header(
    collection,
    1U,
    @moon_geocodec.CoordinateDimension::Xyz,
    None,
    true,
  )
  push_dimensioned_coordinate(
    collection,
    @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  assert_eq(parse_ewkb_ok(collection), {
    srid: Some(4326),
    geometry: @moon_geocodec.Geometry::GeometryCollection([
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
      ),
    ]),
  })
  let mismatch : Array[Byte] = []
  push_ewkb_header(
    mismatch,
    7U,
    @moon_geocodec.CoordinateDimension::Xyz,
    Some(4326),
    true,
  )
  push_wkb_u32(mismatch, 1U, true)
  push_ewkb_header(
    mismatch,
    1U,
    @moon_geocodec.CoordinateDimension::Xyz,
    Some(3857),
    true,
  )
  push_dimensioned_coordinate(
    mismatch,
    @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    @moon_geocodec.CoordinateDimension::Xyz,
    true,
  )
  assert_eq(
    @moon_geocodec.parse_ewkb(
      Bytes::from_array(mismatch).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkb("nested SRID does not match parent", 13)),
  )
}

///|
test "WKB reader rejects EWKB high-bit type codes" {
  let bytes : Array[Byte] = []
  push_ewkb_header(
    bytes,
    1U,
    @moon_geocodec.CoordinateDimension::Xy,
    Some(4326),
    true,
  )
  push_wkb_f64(bytes, 1.0, true)
  push_wkb_f64(bytes, 2.0, true)
  assert_eq(
    @moon_geocodec.parse_wkb(
      Bytes::from_array(bytes).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.UnsupportedGeometry("WKB type 536870913")),
  )
}

///|
test "EWKB writer emits PostGIS-compatible bytes" {
  let value = match
    @moon_geocodec.SpatialGeometry::new(
      @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
      Some(4326),
    ) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  let expected : Array[Byte] = [
    b'\x01', b'\x01', b'\x00', b'\x00', b'\x20', b'\xE6', b'\x10', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\xF0', b'\x3F', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x40',
  ]
  assert_eq(@moon_geocodec.format_ewkb(value), Ok(Bytes::from_array(expected)))
}

///|
test "EWKB writer keeps SRID on the root geometry" {
  let collection = @moon_geocodec.Geometry::GeometryCollection([
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    ),
  ])
  let value = match
    @moon_geocodec.SpatialGeometry::new(collection, Some(4326)) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  let bytes = match @moon_geocodec.format_ewkb(value) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(bytes.length(), 42)
  assert_eq(parse_ewkb_ok(bytes.to_array()), value)
}

///|
test "EWKB output round trips dimensions and byte orders" {
  let geometry = @moon_geocodec.Geometry::MultiPoint([
    @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
    @moon_geocodec.Coordinate::xyzm(5.0, 6.0, 7.0, 8.0),
  ])
  let value = match @moon_geocodec.SpatialGeometry::new(geometry, Some(4979)) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  let orders : Array[@moon_geocodec.WkbByteOrder] = [
    @moon_geocodec.WkbByteOrder::LittleEndian,
    @moon_geocodec.WkbByteOrder::BigEndian,
  ]
  for order in orders {
    let bytes = match @moon_geocodec.format_ewkb_with_order(value, order) {
      Ok(value) => value
      Err(err) => fail(err.to_string())
    }
    assert_eq(parse_ewkb_ok(bytes.to_array()), value)
  }
}

///|
test "EWKB writer rejects invalid SRIDs and mixed dimensions" {
  let point = @moon_geocodec.Geometry::Point(
    @moon_geocodec.Coordinate::xy(1.0, 2.0),
  )
  assert_eq(
    @moon_geocodec.format_ewkb({ srid: Some(-1), geometry: point, }),
    Err(@moon_geocodec.InvalidSrid(-1)),
  )
  assert_eq(
    @moon_geocodec.format_ewkb({
      srid: Some(4326),
      geometry: @moon_geocodec.Geometry::GeometryCollection([
        point,
        @moon_geocodec.Geometry::Point(
          @moon_geocodec.Coordinate::xyz(3.0, 4.0, 5.0),
        ),
      ]),
    }),
    Err(@moon_geocodec.InvalidCoordinate("inconsistent coordinate dimensions")),
  )
}
