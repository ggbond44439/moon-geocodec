///|
fn format_geojson_ok(geometry : @moon_geocodec.Geometry) -> String raise {
  match @moon_geocodec.format_geojson(geometry) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
test "GeoJSON writer emits canonical point and line strings" {
  assert_eq(
    format_geojson_ok(
      @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
    ),
    "{\"type\":\"Point\",\"coordinates\":[1,2]}",
  )
  assert_eq(
    format_geojson_ok(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
      ),
    ),
    "{\"type\":\"Point\",\"coordinates\":[1,2,3]}",
  )
  assert_eq(
    format_geojson_ok(
      @moon_geocodec.Geometry::LineString([
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
      ]),
    ),
    "{\"type\":\"LineString\",\"coordinates\":[[0,0],[1,1]]}",
  )
}

///|
test "GeoJSON writer emits polygons and multipart geometries" {
  assert_eq(
    format_geojson_ok(
      @moon_geocodec.Geometry::Polygon([
        [
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 1.0),
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
        ],
      ]),
    ),
    "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,0],[1,1],[0,0]]]}",
  )
  assert_eq(
    format_geojson_ok(
      @moon_geocodec.Geometry::MultiPoint([
        @moon_geocodec.Coordinate::xy(1.0, 2.0),
        @moon_geocodec.Coordinate::xy(3.0, 4.0),
      ]),
    ),
    "{\"type\":\"MultiPoint\",\"coordinates\":[[1,2],[3,4]]}",
  )
  assert_eq(
    format_geojson_ok(
      @moon_geocodec.Geometry::MultiLineString([
        [
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 1.0),
        ],
      ]),
    ),
    "{\"type\":\"MultiLineString\",\"coordinates\":[[[0,0],[1,1]]]}",
  )
  assert_eq(
    format_geojson_ok(
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
    ),
    "{\"type\":\"MultiPolygon\",\"coordinates\":[[[[0,0],[1,0],[1,1],[0,0]]]]}",
  )
}

///|
test "GeoJSON writer emits empty geometries and collections" {
  assert_eq(
    format_geojson_ok(@moon_geocodec.Geometry::EmptyPoint),
    "{\"type\":\"Point\",\"coordinates\":[]}",
  )
  assert_eq(
    format_geojson_ok(@moon_geocodec.Geometry::LineString([])),
    "{\"type\":\"LineString\",\"coordinates\":[]}",
  )
  assert_eq(
    format_geojson_ok(@moon_geocodec.Geometry::MultiPolygon([])),
    "{\"type\":\"MultiPolygon\",\"coordinates\":[]}",
  )
  assert_eq(
    format_geojson_ok(
      @moon_geocodec.Geometry::GeometryCollection([
        @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
        @moon_geocodec.Geometry::LineString([
          @moon_geocodec.Coordinate::xyz(0.0, 0.0, 1.0),
          @moon_geocodec.Coordinate::xyz(1.0, 1.0, 2.0),
        ]),
      ]),
    ),
    "{\"type\":\"GeometryCollection\",\"geometries\":[{\"type\":\"Point\",\"coordinates\":[1,2]},{\"type\":\"LineString\",\"coordinates\":[[0,0,1],[1,1,2]]}]}",
  )
}

///|
test "GeoJSON output round trips through the importer" {
  let samples : Array[@moon_geocodec.Geometry] = [
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    ),
    @moon_geocodec.Geometry::LineString([
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(1.0, 1.0),
    ]),
    @moon_geocodec.Geometry::Polygon([
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
      ],
    ]),
    @moon_geocodec.Geometry::MultiPoint([
      @moon_geocodec.Coordinate::xy(1.0, 2.0),
      @moon_geocodec.Coordinate::xy(3.0, 4.0),
    ]),
    @moon_geocodec.Geometry::GeometryCollection([
      @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xyz(3.0, 4.0, 5.0),
      ),
    ]),
    @moon_geocodec.Geometry::GeometryCollection([]),
  ]
  for geometry in samples {
    let text = format_geojson_ok(geometry)
    assert_eq(parse_geojson_ok(text.view()), geometry)
    assert_eq(format_geojson_ok(parse_geojson_ok(text.view())), text)
  }
}

///|
test "GeoJSON writer rejects unsupported dimensions and invalid components" {
  assert_eq(
    @moon_geocodec.format_geojson(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xym(1.0, 2.0, 3.0),
      ),
    ),
    Err(@moon_geocodec.UnsupportedGeometry("GeoJSON M ordinates")),
  )
  assert_eq(
    @moon_geocodec.format_geojson(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xyzm(1.0, 2.0, 3.0, 4.0),
      ),
    ),
    Err(@moon_geocodec.UnsupportedGeometry("GeoJSON M ordinates")),
  )
  assert_eq(
    @moon_geocodec.format_geojson(
      @moon_geocodec.Geometry::LineString([
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xyz(1.0, 1.0, 2.0),
      ]),
    ),
    Err(@moon_geocodec.InvalidCoordinate("inconsistent coordinate dimensions")),
  )
  assert_eq(
    @moon_geocodec.format_geojson(
      @moon_geocodec.Geometry::Point(
        @moon_geocodec.Coordinate::xy(@double.infinity, 2.0),
      ),
    ),
    Err(@moon_geocodec.InvalidCoordinate("non-finite x ordinate")),
  )
  let empty_line : Array[@moon_geocodec.Coordinate] = []
  assert_eq(
    @moon_geocodec.format_geojson(
      @moon_geocodec.Geometry::MultiLineString([empty_line]),
    ),
    Err(@moon_geocodec.InvalidCoordinate("empty line string component")),
  )
}

///|
test "format conversion helpers bridge WKT WKB and GeoJSON" {
  assert_eq(
    @moon_geocodec.wkt_to_geojson(
      "POINT Z (1 2 3)",
      @moon_geocodec.GeoLimits::default(),
    ),
    Ok("{\"type\":\"Point\",\"coordinates\":[1,2,3]}"),
  )
  assert_eq(
    @moon_geocodec.geojson_to_wkt(
      "{\"type\":\"LineString\",\"coordinates\":[[0,0],[1,1]]}",
      @moon_geocodec.GeoLimits::default(),
    ),
    Ok("LINESTRING (0 0, 1 1)"),
  )
  let geometry = @moon_geocodec.Geometry::Point(
    @moon_geocodec.Coordinate::xy(1.0, 2.0),
  )
  let wkb = match @moon_geocodec.format_wkb(geometry) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.wkb_to_geojson(
      wkb.exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Ok("{\"type\":\"Point\",\"coordinates\":[1,2]}"),
  )
  let encoded = match
    @moon_geocodec.geojson_to_wkb(
      "{\"type\":\"Point\",\"coordinates\":[1,2]}",
      @moon_geocodec.GeoLimits::default(),
    ) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.parse_wkb(
      encoded.exact_view(),
      @moon_geocodec.GeoLimits::default(),
    ),
    Ok(geometry),
  )
}
