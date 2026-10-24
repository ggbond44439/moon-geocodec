///|
test "GeoJSON object API preserves feature properties and id" {
  let source = "{\"type\":\"Feature\",\"id\":\"road-1\",\"properties\":{\"name\":\"A\"},\"geometry\":{\"type\":\"Point\",\"coordinates\":[1,2]}}"
  let object = match
    @moon_geocodec.parse_geojson_object(
      source,
      @moon_geocodec.GeoLimits::default(),
    ) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.format_geojson_object(object),
    Ok(
      "{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[1,2]},\"properties\":{\"name\":\"A\"},\"id\":\"road-1\"}",
    ),
  )
  assert_eq(
    @moon_geocodec.parse_geojson(source, @moon_geocodec.GeoLimits::default()),
    Ok(@moon_geocodec.Geometry::Point(@moon_geocodec.Coordinate::xy(1.0, 2.0))),
  )
}

///|
test "GeoJSON object API preserves feature collections" {
  let source = "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"name\":\"A\"},\"geometry\":{\"type\":\"Point\",\"coordinates\":[1,2]}},{\"type\":\"Feature\",\"properties\":null,\"geometry\":null}]}"
  let object = match
    @moon_geocodec.parse_geojson_object(
      source,
      @moon_geocodec.GeoLimits::default(),
    ) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.format_geojson_object(object),
    Ok(
      "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[1,2]},\"properties\":{\"name\":\"A\"}},{\"type\":\"Feature\",\"geometry\":null,\"properties\":null}]}",
    ),
  )
}
