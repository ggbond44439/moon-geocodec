///|
fn validate_finite_coordinate(
  coordinate : Coordinate,
  path : String,
) -> Result[Unit, GeoError] {
  if coordinate.x.is_nan() || coordinate.x.is_inf() {
    Err(InvalidCoordinate(path + " has non-finite x ordinate"))
  } else if coordinate.y.is_nan() || coordinate.y.is_inf() {
    Err(InvalidCoordinate(path + " has non-finite y ordinate"))
  } else if (match coordinate.z {
      Some(value) => value.is_nan() || value.is_inf()
      None => false
    }) {
    Err(InvalidCoordinate(path + " has non-finite z ordinate"))
  } else if (match coordinate.m {
      Some(value) => value.is_nan() || value.is_inf()
      None => false
    }) {
    Err(InvalidCoordinate(path + " has non-finite m ordinate"))
  } else {
    Ok(())
  }
}

///|
fn validate_dimension_summary(
  summary : DimensionSummary,
  path : String,
) -> Result[Unit, GeoError] {
  match summary {
    Mixed =>
      Err(InvalidGeometry(path + " has inconsistent coordinate dimensions"))
    _ => Ok(())
  }
}

///|
fn validate_coordinate_array(
  coordinates : Array[Coordinate],
  path : String,
) -> Result[Unit, GeoError] {
  let mut index = 0
  for coordinate in coordinates {
    match
      validate_finite_coordinate(
        coordinate,
        path + "[" + index.to_string() + "]",
      ) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    index += 1
  }
  Ok(())
}

///|
fn has_two_distinct_coordinates(coordinates : Array[Coordinate]) -> Bool {
  for left in 0..<coordinates.length() {
    let start = left + 1
    for right in start..<coordinates.length() {
      if coordinates[left] != coordinates[right] {
        return true
      }
    }
  }
  false
}

///|
fn ring_signed_area2(ring : Array[Coordinate]) -> Double {
  let mut area = 0.0
  let end = ring.length() - 1
  for index in 0..<end {
    area += ring[index].x * ring[index + 1].y -
      ring[index + 1].x * ring[index].y
  }
  area
}

///|
fn validate_ring(
  ring : Array[Coordinate],
  ring_index : Int32,
  path : String,
) -> Result[Unit, GeoError] {
  if ring.length() < 4 {
    return Err(
      InvalidBoundary(
        path + " ring must contain at least four coordinates",
        ring_index,
      ),
    )
  }
  if ring[0] != ring[ring.length() - 1] {
    return Err(InvalidBoundary(path + " ring must be closed", ring_index))
  }
  match validate_coordinate_array(ring, path) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let area = ring_signed_area2(ring)
  if area == 0.0 || area.is_nan() || area.is_inf() {
    return Err(InvalidBoundary(path + " ring has zero area", ring_index))
  }
  Ok(())
}

///|
fn validate_line_string(
  coordinates : Array[Coordinate],
  path : String,
) -> Result[Unit, GeoError] {
  match
    validate_dimension_summary(coordinate_dimension_summary(coordinates), path) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  match validate_coordinate_array(coordinates, path) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  if coordinates.length() == 0 {
    return Ok(())
  }
  if coordinates.length() < 2 {
    return Err(InvalidGeometry(path + " must contain at least two coordinates"))
  }
  if !has_two_distinct_coordinates(coordinates) {
    return Err(InvalidGeometry(path + " must contain distinct coordinates"))
  }
  Ok(())
}

///|
fn validate_polygon(
  rings : Array[Array[Coordinate]],
  path : String,
) -> Result[Unit, GeoError] {
  match validate_dimension_summary(ring_dimension_summary(rings), path) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  if rings.length() == 0 {
    return Ok(())
  }
  for index, ring in rings {
    match validate_ring(ring, index, path) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(())
}

///|
fn validate_geometry_at(
  geometry : Geometry,
  path : String,
) -> Result[Unit, GeoError] {
  match geometry {
    Point(coordinate) => validate_finite_coordinate(coordinate, path)
    EmptyPoint => Ok(())
    LineString(coordinates) => validate_line_string(coordinates, path)
    Polygon(rings) => validate_polygon(rings, path)
    MultiPoint(coordinates) => {
      match
        validate_dimension_summary(
          coordinate_dimension_summary(coordinates),
          path,
        ) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      validate_coordinate_array(coordinates, path)
    }
    MultiLineString(lines) => {
      match validate_dimension_summary(ring_dimension_summary(lines), path) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      for index, line in lines {
        let line_path = path + ".lines[" + index.to_string() + "]"
        if line.length() == 0 {
          return Err(
            InvalidGeometry(
              line_path + " must contain at least two coordinates",
            ),
          )
        }
        match validate_line_string(line, line_path) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
    MultiPolygon(polygons) => {
      match
        validate_dimension_summary(polygon_dimension_summary(polygons), path) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      for index, polygon in polygons {
        let polygon_path = path + ".polygons[" + index.to_string() + "]"
        if polygon.length() == 0 {
          return Err(InvalidGeometry(polygon_path + " must not be empty"))
        }
        match validate_polygon(polygon, polygon_path) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
    GeometryCollection(geometries) => {
      for index, child in geometries {
        let child_path = path + ".geometries[" + index.to_string() + "]"
        match validate_geometry_at(child, child_path) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
  }
}

///|
/// Validates the structural invariants of a geometry.
pub fn validate_geometry(geometry : Geometry) -> Result[Unit, GeoError] {
  validate_geometry_at(geometry, "geometry")
}

///|
fn dedupe_consecutive(coordinates : Array[Coordinate]) -> Array[Coordinate] {
  let result : Array[Coordinate] = []
  for coordinate in coordinates {
    if result.length() == 0 || result[result.length() - 1] != coordinate {
      result.push(coordinate)
    }
  }
  result
}

///|
fn normalize_line(
  coordinates : Array[Coordinate],
  path : String,
) -> Result[Array[Coordinate], GeoError] {
  let normalized = dedupe_consecutive(coordinates)
  match
    validate_dimension_summary(coordinate_dimension_summary(normalized), path) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  match validate_coordinate_array(normalized, path) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  if normalized.length() > 0 && normalized.length() < 2 {
    return Err(
      InvalidGeometry(path + " must contain at least two distinct coordinates"),
    )
  }
  Ok(normalized)
}

///|
fn normalize_ring(
  ring : Array[Coordinate],
  ring_index : Int32,
  path : String,
) -> Result[Array[Coordinate], GeoError] {
  let normalized = dedupe_consecutive(ring)
  if normalized.length() == 0 {
    return Err(InvalidBoundary(path + " ring must not be empty", ring_index))
  }
  let closed = if normalized[0] == normalized[normalized.length() - 1] {
    normalized
  } else {
    let result = normalized.copy()
    result.push(result[0])
    result
  }
  match validate_ring(closed, ring_index, path) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(closed)
}

///|
fn normalize_polygon(
  rings : Array[Array[Coordinate]],
  path : String,
) -> Result[Array[Array[Coordinate]], GeoError] {
  if rings.length() == 0 {
    return Ok([])
  }
  let normalized : Array[Array[Coordinate]] = []
  for index, ring in rings {
    let closed = match normalize_ring(ring, index, path) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let area = ring_signed_area2(closed)
    let oriented = if (index == 0 && area < 0.0) || (index > 0 && area > 0.0) {
      closed.rev()
    } else {
      closed
    }
    normalized.push(oriented)
  }
  Ok(normalized)
}

///|
fn normalize_geometry_at(
  geometry : Geometry,
  path : String,
) -> Result[Geometry, GeoError] {
  match geometry {
    Point(coordinate) =>
      match validate_finite_coordinate(coordinate, path) {
        Ok(_) => Ok(Point(coordinate))
        Err(err) => Err(err)
      }
    EmptyPoint => Ok(EmptyPoint)
    LineString(coordinates) => {
      let normalized = match normalize_line(coordinates, path) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      Ok(LineString(normalized))
    }
    Polygon(rings) => {
      let normalized = match normalize_polygon(rings, path) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      Ok(Polygon(normalized))
    }
    MultiPoint(coordinates) => {
      match
        validate_dimension_summary(
          coordinate_dimension_summary(coordinates),
          path,
        ) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      match validate_coordinate_array(coordinates, path) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      Ok(MultiPoint(coordinates.copy()))
    }
    MultiLineString(lines) => {
      let normalized : Array[Array[Coordinate]] = []
      for index, line in lines {
        let line_path = path + ".lines[" + index.to_string() + "]"
        let value = match normalize_line(line, line_path) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        if value.length() == 0 {
          return Err(InvalidGeometry(line_path + " must not be empty"))
        }
        normalized.push(value)
      }
      Ok(MultiLineString(normalized))
    }
    MultiPolygon(polygons) => {
      let normalized : Array[Array[Array[Coordinate]]] = []
      for index, polygon in polygons {
        let polygon_path = path + ".polygons[" + index.to_string() + "]"
        let value = match normalize_polygon(polygon, polygon_path) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        if value.length() == 0 {
          return Err(InvalidGeometry(polygon_path + " must not be empty"))
        }
        normalized.push(value)
      }
      Ok(MultiPolygon(normalized))
    }
    GeometryCollection(geometries) => {
      let normalized : Array[Geometry] = []
      for index, child in geometries {
        let child_path = path + ".geometries[" + index.to_string() + "]"
        let value = match normalize_geometry_at(child, child_path) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        normalized.push(value)
      }
      Ok(GeometryCollection(normalized))
    }
  }
}

///|
/// Normalizes ring closure, consecutive duplicates, and ring direction.
pub fn normalize_geometry(geometry : Geometry) -> Result[Geometry, GeoError] {
  let normalized = match normalize_geometry_at(geometry, "geometry") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match validate_geometry(normalized) {
    Ok(_) => Ok(normalized)
    Err(err) => Err(err)
  }
}
