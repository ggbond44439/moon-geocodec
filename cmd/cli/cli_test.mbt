///|
fn cli_ok(args : Array[String]) -> String raise {
  match @cli.execute_cli(args) {
    Ok(value) => value
    Err(err) => fail(err)
  }
}

///|
test "CLI inspect reports geometry metrics" {
  let output = cli_ok(["inspect", "wkt", "POINT Z (1 2 3)"])
  assert_true(output.contains("format: wkt"))
  assert_true(output.contains("kind: Point"))
  assert_true(output.contains("dimension: XYZ"))
  assert_true(output.contains("coordinates: 1"))
  assert_true(output.contains("bounds3d: 1 2 3 1 2 3"))
  assert_true(output.contains("centroid: 1 2 3"))
  assert_true(output.contains("length: 0"))
  assert_true(output.contains("area: 0"))
  assert_true(output.contains("valid: true"))
  assert_true(output.contains("topology: true"))
}

///|
test "CLI validate reports structural validity" {
  assert_eq(
    @cli.execute_cli(["validate", "wkt", "LINESTRING (0 0, 1 1)"]),
    Ok("valid"),
  )
  match @cli.execute_cli(["validate", "wkt", "LINESTRING (0 0)"]) {
    Err(message) =>
      assert_true(message.contains("must contain at least two coordinates"))
    Ok(_) => fail("expected invalid geometry")
  }
}

///|
test "CLI validate-topology checks topological validity" {
  assert_eq(
    @cli.execute_cli([
      "validate-topology", "wkt", "POLYGON ((0 0, 4 0, 4 4, 0 4, 0 0))",
    ]),
    Ok("valid"),
  )
  let crossing_hole = "POLYGON ((0 0, 4 0, 4 4, 0 4, 0 0), (3 3, 5 3, 5 5, 3 5, 3 3))"
  match @cli.execute_cli(["validate-topology", "wkt", crossing_hole]) {
    Err(message) => assert_true(message.contains("hole intersects shell"))
    Ok(_) => fail("expected topology error")
  }
}

///|
test "CLI converts between WKT WKB GeoJSON and EWKT" {
  let geojson = cli_ok(["convert", "wkt", "geojson", "POINT (1 2)"])
  assert_eq(geojson, "{\"type\":\"Point\",\"coordinates\":[1,2]}")
  let wkb = cli_ok(["convert", "wkt", "wkb", "POINT (1 2)"])
  assert_eq(cli_ok(["convert", "wkb", "wkt", wkb]), "POINT (1 2)")
  let ewkb = cli_ok(["convert", "ewkt", "ewkb", "SRID=4326;POINT (1 2)"])
  assert_eq(cli_ok(["convert", "ewkb", "ewkt", ewkb]), "SRID=4326;POINT (1 2)")
  assert_eq(cli_ok(["convert", "geojson", "wkt", geojson]), "POINT (1 2)")
}

///|
test "CLI rejects unknown formats and malformed hex" {
  match @cli.execute_cli(["convert", "xml", "wkt", "x"]) {
    Err(message) => assert_true(message.contains("unsupported format"))
    Ok(_) => fail("expected format error")
  }
  match @cli.execute_cli(["convert", "wkb", "wkt", "abc"]) {
    Err(message) => assert_true(message.contains("even number"))
    Ok(_) => fail("expected hex error")
  }
}
