///|
fn benchmark_geometry() -> @moon_geocodec.Geometry {
  let coordinates : Array[@moon_geocodec.Coordinate] = []
  for index in 0..<1000 {
    coordinates.push(
      @moon_geocodec.Coordinate::xy(index.to_double(), (index % 10).to_double()),
    )
  }
  @moon_geocodec.Geometry::LineString(coordinates)
}

///|
fn bench_geometry_ok(
  result : Result[@moon_geocodec.Geometry, @moon_geocodec.GeoError],
) -> @moon_geocodec.Geometry {
  match result {
    Ok(value) => value
    Err(_) => abort("benchmark WKT/WKB/GeoJSON parse failed")
  }
}

///|
fn bench_string_ok(result : Result[String, @moon_geocodec.GeoError]) -> String {
  match result {
    Ok(value) => value
    Err(_) => abort("benchmark formatting failed")
  }
}

///|
fn bench_bytes_ok(result : Result[Bytes, @moon_geocodec.GeoError]) -> Bytes {
  match result {
    Ok(value) => value
    Err(_) => abort("benchmark WKB formatting failed")
  }
}

///|
test "bench WKT parse 1000 points" (it : @bench.T) {
  let text = bench_string_ok(@moon_geocodec.format_wkt(benchmark_geometry()))
  it.bench(fn() {
    let geometry = bench_geometry_ok(
      @moon_geocodec.parse_wkt(text, @moon_geocodec.GeoLimits::default()),
    )
    it.keep(geometry.coordinate_count())
  })
}

///|
test "bench WKB parse 1000 points" (it : @bench.T) {
  let bytes = bench_bytes_ok(@moon_geocodec.format_wkb(benchmark_geometry()))
  let view = bytes.exact_view()
  it.bench(fn() {
    let geometry = bench_geometry_ok(
      @moon_geocodec.parse_wkb(view, @moon_geocodec.GeoLimits::default()),
    )
    it.keep(geometry.coordinate_count())
  })
}

///|
test "bench GeoJSON parse 1000 points" (it : @bench.T) {
  let text = bench_string_ok(
    @moon_geocodec.format_geojson(benchmark_geometry()),
  )
  it.bench(fn() {
    let geometry = bench_geometry_ok(
      @moon_geocodec.parse_geojson(text, @moon_geocodec.GeoLimits::default()),
    )
    it.keep(geometry.coordinate_count())
  })
}

///|
test "bench geometry length and area" (it : @bench.T) {
  let geometry = benchmark_geometry()
  it.bench(fn() { it.keep(geometry.length() + geometry.area()) })
}
