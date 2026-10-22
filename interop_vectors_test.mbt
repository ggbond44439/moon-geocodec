///|
fn interop_hex_digit(code : Int32) -> Int32? {
  if code >= 48 && code <= 57 {
    Some(code - 48)
  } else if code >= 65 && code <= 70 {
    Some(code - 65 + 10)
  } else if code >= 97 && code <= 102 {
    Some(code - 97 + 10)
  } else {
    None
  }
}

///|
fn interop_hex(source : StringView) -> Bytes raise {
  let bytes : Array[Byte] = []
  let mut high = -1
  for character in source.iter() {
    let digit = match interop_hex_digit(character.to_int()) {
      Some(value) => value
      None => fail("invalid interoperability hex")
    }
    if high < 0 {
      high = digit
    } else {
      bytes.push((high * 16 + digit).to_byte())
      high = -1
    }
  }
  if high >= 0 {
    fail("odd interoperability hex")
  }
  Bytes::from_array(bytes)
}

///|
test "reference WKB vectors parse and serialize" {
  let point_wkb = "0101000000000000000000f03f0000000000000040"
  let point = @moon_geocodec.Geometry::Point(
    @moon_geocodec.Coordinate::xy(1.0, 2.0),
  )
  assert_eq(
    @moon_geocodec.parse_wkb(
      interop_hex(point_wkb).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Ok(point),
  )
  assert_eq(@moon_geocodec.format_wkb(point), Ok(interop_hex(point_wkb)))
  let line_wkb = "01020000000200000000000000000000000000000000000000000000000000f03f000000000000f03f"
  let line = @moon_geocodec.Geometry::LineString([
    @moon_geocodec.Coordinate::xy(0.0, 0.0),
    @moon_geocodec.Coordinate::xy(1.0, 1.0),
  ])
  assert_eq(
    @moon_geocodec.parse_wkb(
      interop_hex(line_wkb).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Ok(line),
  )
  assert_eq(@moon_geocodec.format_wkb(line), Ok(interop_hex(line_wkb)))
  let polygon_wkb = "010300000001000000050000000000000000000000000000000000000000000000000010400000000000000000000000000000104000000000000010400000000000000000000000000000104000000000000000000000000000000000"
  let polygon = @moon_geocodec.Geometry::Polygon([
    [
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(4.0, 0.0),
      @moon_geocodec.Coordinate::xy(4.0, 4.0),
      @moon_geocodec.Coordinate::xy(0.0, 4.0),
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
    ],
  ])
  assert_eq(
    @moon_geocodec.parse_wkb(
      interop_hex(polygon_wkb).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Ok(polygon),
  )
  assert_eq(@moon_geocodec.format_wkb(polygon), Ok(interop_hex(polygon_wkb)))
}

///|
test "reference EWKB vectors carry PostGIS SRID and dimensions" {
  let ewkb = "01010000a0e6100000000000000000f03f00000000000000400000000000000840"
  let value = match
    @moon_geocodec.parse_ewkb(
      interop_hex(ewkb).exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(value.srid, Some(4326))
  assert_eq(
    value.geometry,
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    ),
  )
  assert_eq(@moon_geocodec.format_ewkb(value), Ok(interop_hex(ewkb)))
}

///|
test "reference GeoJSON vector parses and serializes" {
  let text = "{\"type\":\"Point\",\"coordinates\":[1,2]}"
  let point = @moon_geocodec.Geometry::Point(
    @moon_geocodec.Coordinate::xy(1.0, 2.0),
  )
  assert_eq(
    @moon_geocodec.parse_geojson(text, @moon_geocodec.GeoLimits::default()),
    Ok(point),
  )
  assert_eq(@moon_geocodec.format_geojson(point), Ok(text))
}
