///|
fn wkt2_ok(source : StringView) -> @moon_geocodec.Geometry raise {
  match @moon_geocodec.parse_wkt2(source, @moon_geocodec.GeoLimits::default()) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
fn ewkt_ok(source : StringView) -> @moon_geocodec.SpatialGeometry raise {
  match @moon_geocodec.parse_ewkt(source, @moon_geocodec.GeoLimits::default()) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
fn spatial_geometry_ok(
  geometry : @moon_geocodec.Geometry,
  srid : Int32?,
) -> @moon_geocodec.SpatialGeometry raise {
  match @moon_geocodec.SpatialGeometry::new(geometry, srid) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
test "WKT2 parser requires parenthesized multipoint coordinates" {
  let expected = @moon_geocodec.Geometry::MultiPoint([
    @moon_geocodec.Coordinate::xy(1.0, 2.0),
    @moon_geocodec.Coordinate::xy(3.0, 4.0),
  ])
  assert_eq(wkt2_ok("MULTIPOINT ((1 2), (3 4))"), expected)
  assert_eq(
    @moon_geocodec.parse_wkt2(
      "MULTIPOINT (1 2, 3 4)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(
      @moon_geocodec.InvalidWkt(
        "WKT2 requires parenthesized MULTIPOINT coordinates", 12,
      ),
    ),
  )
}

///|
test "WKT2 parser identifies unsupported curve and surface types" {
  assert_eq(
    @moon_geocodec.parse_wkt2(
      "CIRCULARSTRING (0 0, 1 1, 2 0)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.UnsupportedGeometry("CIRCULARSTRING")),
  )
  assert_eq(
    @moon_geocodec.parse_wkt2(
      "TIN (((0 0, 1 0, 0 1, 0 0)))",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.UnsupportedGeometry("TIN")),
  )
}

///|
test "WKT2 writer uses the parenthesized multipoint form" {
  let geometry = @moon_geocodec.Geometry::MultiPoint([
    @moon_geocodec.Coordinate::xy(1.0, 2.0),
    @moon_geocodec.Coordinate::xy(3.0, 4.0),
  ])
  assert_eq(@moon_geocodec.format_wkt(geometry), Ok("MULTIPOINT (1 2, 3 4)"))
  assert_eq(
    @moon_geocodec.format_wkt2(geometry),
    Ok("MULTIPOINT ((1 2), (3 4))"),
  )
}

///|
test "WKT2 output round trips for dimensions and collections" {
  let samples : Array[String] = [
    "MULTIPOINT ZM ((1 2 3 4), (5 6 7 8))", "GEOMETRYCOLLECTION Z (POINT (1 2 3), MULTIPOINT ((4 5 6), (7 8 9)))",
  ]
  for source in samples {
    let geometry = wkt2_ok(source.view())
    let text = match @moon_geocodec.format_wkt2(geometry) {
      Ok(value) => value
      Err(err) => fail(err.to_string())
    }
    assert_eq(wkt2_ok(text.view()), geometry)
    assert_eq(@moon_geocodec.format_wkt2(geometry), Ok(text))
  }
}

///|
test "EWKT parser reads optional SRID prefixes" {
  let with_srid = ewkt_ok("SRID=4326;POINT (1 2)")
  assert_eq(with_srid.srid, Some(4326))
  assert_eq(
    with_srid.geometry,
    @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
  )
  let lowercase = ewkt_ok("srid=3857;LINESTRING (0 0, 1 1)")
  assert_eq(lowercase.srid, Some(3857))
  let without_srid = ewkt_ok("POINT (1 2)")
  assert_eq(without_srid.srid, None)
}

///|
test "EWKT writer emits and validates SRID metadata" {
  let point = @moon_geocodec.Geometry::Point(
    @moon_geocodec.Coordinate::xy(1.0, 2.0),
  )
  let with_srid = spatial_geometry_ok(point, Some(4326))
  assert_eq(@moon_geocodec.format_ewkt(with_srid), Ok("SRID=4326;POINT (1 2)"))
  let without_srid = spatial_geometry_ok(point, None)
  assert_eq(@moon_geocodec.format_ewkt(without_srid), Ok("POINT (1 2)"))
  assert_eq(
    @moon_geocodec.SpatialGeometry::new(point, Some(-1)),
    Err(@moon_geocodec.InvalidSrid(-1)),
  )
  assert_eq(
    @moon_geocodec.format_ewkt({ srid: Some(-1), geometry: point, }),
    Err(@moon_geocodec.InvalidSrid(-1)),
  )
}

///|
test "EWKT parser reports malformed SRID prefixes" {
  assert_eq(
    @moon_geocodec.parse_ewkt(
      "SRID 4326;POINT (1 2)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("expected '=' after SRID", 5)),
  )
  assert_eq(
    @moon_geocodec.parse_ewkt(
      "SRID=abc;POINT (1 2)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("expected SRID number", 5)),
  )
  assert_eq(
    @moon_geocodec.parse_ewkt(
      "SRID=4326.5;POINT (1 2)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("invalid SRID", 5)),
  )
  assert_eq(
    @moon_geocodec.parse_ewkt(
      "SRID=4326 POINT (1 2)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidWkt("expected ';' after SRID", 10)),
  )
  assert_eq(
    @moon_geocodec.parse_ewkt(
      "SRID=-1;POINT (1 2)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidSrid(-1)),
  )
  assert_eq(
    @moon_geocodec.parse_ewkt("SRID=4326;", @moon_geocodec.GeoLimits::default()),
    Err(@moon_geocodec.InvalidWkt("expected geometry type", 10)),
  )
}

///|
test "EWKT output round trips through the parser" {
  let original = ewkt_ok("SRID=4326;GEOMETRYCOLLECTION Z (POINT (1 2 3))")
  let text = match @moon_geocodec.format_ewkt(original) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(text, "SRID=4326;GEOMETRYCOLLECTION Z (POINT (1 2 3))")
  assert_eq(ewkt_ok(text.view()), original)
}
