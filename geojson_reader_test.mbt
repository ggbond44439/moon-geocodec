///|
fn parse_geojson_ok(source : StringView) -> @moon_geocodec.Geometry raise {
  match
    @moon_geocodec.parse_geojson(source, @moon_geocodec.GeoLimits::default()) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
}

///|
test "GeoJSON reader parses points with and without altitude" {
  assert_eq(
    parse_geojson_ok("{\"type\":\"Point\",\"coordinates\":[1,2]}"),
    @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
  )
  assert_eq(
    parse_geojson_ok("{\"type\":\"Point\",\"coordinates\":[1,2,3]}"),
    @moon_geocodec.Geometry::Point(
      @moon_geocodec.Coordinate::xyz(1.0, 2.0, 3.0),
    ),
  )
}

///|
test "GeoJSON reader parses line strings and polygons" {
  assert_eq(
    parse_geojson_ok("{\"type\":\"LineString\",\"coordinates\":[[0,0],[1,1]]}"),
    @moon_geocodec.Geometry::LineString([
      @moon_geocodec.Coordinate::xy(0.0, 0.0),
      @moon_geocodec.Coordinate::xy(1.0, 1.0),
    ]),
  )
  assert_eq(
    parse_geojson_ok(
      "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,0],[1,1],[0,0]]]}",
    ),
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
test "GeoJSON reader parses all multi geometries" {
  assert_eq(
    parse_geojson_ok("{\"type\":\"MultiPoint\",\"coordinates\":[[1,2],[3,4]]}"),
    @moon_geocodec.Geometry::MultiPoint([
      @moon_geocodec.Coordinate::xy(1.0, 2.0),
      @moon_geocodec.Coordinate::xy(3.0, 4.0),
    ]),
  )
  assert_eq(
    parse_geojson_ok(
      "{\"type\":\"MultiLineString\",\"coordinates\":[[[0,0],[1,1]],[[2,2],[3,3]]]}",
    ),
    @moon_geocodec.Geometry::MultiLineString([
      [
        @moon_geocodec.Coordinate::xy(0.0, 0.0),
        @moon_geocodec.Coordinate::xy(1.0, 1.0),
      ],
      [
        @moon_geocodec.Coordinate::xy(2.0, 2.0),
        @moon_geocodec.Coordinate::xy(3.0, 3.0),
      ],
    ]),
  )
  assert_eq(
    parse_geojson_ok(
      "{\"type\":\"MultiPolygon\",\"coordinates\":[[[[0,0],[1,0],[1,1],[0,0]]]]}",
    ),
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
test "GeoJSON reader parses nested geometry collections" {
  assert_eq(
    parse_geojson_ok(
      "{\"type\":\"GeometryCollection\",\"geometries\":[{\"type\":\"Point\",\"coordinates\":[1,2]},{\"type\":\"GeometryCollection\",\"geometries\":[{\"type\":\"LineString\",\"coordinates\":[[0,0],[1,1]]}]}]}",
    ),
    @moon_geocodec.Geometry::GeometryCollection([
      @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
      @moon_geocodec.Geometry::GeometryCollection([
        @moon_geocodec.Geometry::LineString([
          @moon_geocodec.Coordinate::xy(0.0, 0.0),
          @moon_geocodec.Coordinate::xy(1.0, 1.0),
        ]),
      ]),
    ]),
  )
}

///|
test "GeoJSON reader parses empty geometries" {
  assert_eq(
    parse_geojson_ok("{\"type\":\"Point\",\"coordinates\":[]}"),
    @moon_geocodec.Geometry::EmptyPoint,
  )
  assert_eq(
    parse_geojson_ok("{\"type\":\"LineString\",\"coordinates\":[]}"),
    (@moon_geocodec.Geometry::LineString([]) : @moon_geocodec.Geometry),
  )
  assert_eq(
    parse_geojson_ok("{\"type\":\"Polygon\",\"coordinates\":[]}"),
    (@moon_geocodec.Geometry::Polygon([]) : @moon_geocodec.Geometry),
  )
  assert_eq(
    parse_geojson_ok("{\"type\":\"MultiPoint\",\"coordinates\":[]}"),
    (@moon_geocodec.Geometry::MultiPoint([]) : @moon_geocodec.Geometry),
  )
  assert_eq(
    parse_geojson_ok("{\"type\":\"MultiLineString\",\"coordinates\":[]}"),
    (@moon_geocodec.Geometry::MultiLineString([]) : @moon_geocodec.Geometry),
  )
  assert_eq(
    parse_geojson_ok("{\"type\":\"MultiPolygon\",\"coordinates\":[]}"),
    (@moon_geocodec.Geometry::MultiPolygon([]) : @moon_geocodec.Geometry),
  )
  assert_eq(
    parse_geojson_ok("{\"type\":\"GeometryCollection\",\"geometries\":[]}"),
    (@moon_geocodec.Geometry::GeometryCollection([]) : @moon_geocodec.Geometry),
  )
}

///|
test "GeoJSON reader imports features and feature collections" {
  assert_eq(
    parse_geojson_ok(
      "{\"type\":\"Feature\",\"properties\":{\"name\":\"a\"},\"geometry\":{\"type\":\"Point\",\"coordinates\":[1,2]}}",
    ),
    @moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0)),
  )
  assert_eq(
    parse_geojson_ok(
      "{\"type\":\"Feature\",\"properties\":null,\"geometry\":null}",
    ),
    (@moon_geocodec.Geometry::GeometryCollection([]) : @moon_geocodec.Geometry),
  )
  assert_eq(
    parse_geojson_ok(
      "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"Point\",\"coordinates\":[1,2]}},{\"type\":\"Feature\",\"properties\":{},\"geometry\":null},{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"LineString\",\"coordinates\":[[0,0],[1,1]]}}]}",
    ),
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
test "GeoJSON reader rejects malformed structures" {
  match @moon_geocodec.parse_geojson("{", @moon_geocodec.GeoLimits::default()) {
    Err(@moon_geocodec.InvalidGeoJson(_, 0)) => ()
    _ => fail("expected invalid GeoJSON error")
  }
  assert_eq(
    @moon_geocodec.parse_geojson(
      "{\"coordinates\":[1,2]}",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidGeoJson("GeoJSON object is missing 'type'", 0)),
  )
  assert_eq(
    @moon_geocodec.parse_geojson(
      "{\"type\":\"Circle\",\"coordinates\":[]}",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidGeoJson("unsupported GeoJSON type 'Circle'", 0)),
  )
  assert_eq(
    @moon_geocodec.parse_geojson(
      "{\"type\":\"Point\",\"coordinates\":[1]}",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(
      @moon_geocodec.InvalidGeoJson(
        "Point.coordinates must contain two or three ordinates", 0,
      ),
    ),
  )
  assert_eq(
    @moon_geocodec.parse_geojson(
      "{\"type\":\"LineString\",\"coordinates\":[[0,0],[1,1,2]]}",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidGeoJson("inconsistent coordinate dimensions", 0)),
  )
  assert_eq(
    @moon_geocodec.parse_geojson(
      "{\"type\":\"Polygon\",\"coordinates\":[[]]}",
      @moon_geocodec.GeoLimits::default(),
    ),
    Err(@moon_geocodec.InvalidGeoJson("polygon ring must not be empty", 0)),
  )
}

///|
test "GeoJSON reader enforces resource limits" {
  let source = "{\"type\":\"Point\",\"coordinates\":[1,2]}"
  let text_limits = match @moon_geocodec.GeoLimits::new(5, 8, 8, 32) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.parse_geojson(source, text_limits),
    Err(@moon_geocodec.LimitExceeded("text bytes", 5, source.length())),
  )
  let coordinate_limits = match @moon_geocodec.GeoLimits::new(4096, 8, 8, 1) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.parse_geojson(
      "{\"type\":\"LineString\",\"coordinates\":[[0,0],[1,1]]}", coordinate_limits,
    ),
    Err(@moon_geocodec.LimitExceeded("coordinate count", 1, 2)),
  )
  let geometry_limits = match @moon_geocodec.GeoLimits::new(4096, 8, 2, 32) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.parse_geojson(
      "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[1,2]}},{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[3,4]}}]}",
      geometry_limits,
    ),
    Err(@moon_geocodec.LimitExceeded("geometry count", 2, 3)),
  )
  let depth_limits = match @moon_geocodec.GeoLimits::new(4096, 1, 8, 32) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.parse_geojson(
      "{\"type\":\"GeometryCollection\",\"geometries\":[{\"type\":\"Point\",\"coordinates\":[1,2]}]}",
      depth_limits,
    ),
    Err(@moon_geocodec.LimitExceeded("geometry depth", 1, 2)),
  )
}
