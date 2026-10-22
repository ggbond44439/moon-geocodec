///|
fn main {
  let source = "POLYGON ((0 0, 4 0, 4 4, 0 4, 0 0))"
  let limits = @moon_geocodec.GeoLimits::default()
  let geometry = match @moon_geocodec.parse_wkt(source, limits) {
    Ok(value) => value
    Err(err) => {
      eprintln(err.to_string())
      return
    }
  }
  let normalized = match @moon_geocodec.normalize_geometry(geometry) {
    Ok(value) => value
    Err(err) => {
      eprintln(err.to_string())
      return
    }
  }
  let wkt = match @moon_geocodec.format_wkt(normalized) {
    Ok(value) => value
    Err(err) => {
      eprintln(err.to_string())
      return
    }
  }
  let geojson = match @moon_geocodec.format_geojson(normalized) {
    Ok(value) => value
    Err(err) => {
      eprintln(err.to_string())
      return
    }
  }
  let wkb = match @moon_geocodec.format_wkb(normalized) {
    Ok(value) => value
    Err(err) => {
      eprintln(err.to_string())
      return
    }
  }
  println("WKT: " + wkt)
  println("GeoJSON: " + geojson)
  println("WKB bytes: " + wkb.length().to_string())
  match normalized.bounds_3d() {
    Some(bounds) =>
      println(
        "Extent: " +
        bounds.width().to_string() +
        " x " +
        bounds.height().to_string() +
        " x " +
        bounds.depth().to_string(),
      )
    None => ()
  }
  match normalized.centroid() {
    Some(center) =>
      println("Centroid: " + center.x.to_string() + " " + center.y.to_string())
    None => ()
  }
}
