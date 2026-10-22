///|
priv struct GeoJsonWriter {
  builder : StringBuilder
}

///|
fn GeoJsonWriter::new() -> GeoJsonWriter {
  { builder: StringBuilder(), }
}

///|
fn resolve_geojson_dimension(
  summary : DimensionSummary,
) -> Result[CoordinateDimension, GeoError] {
  match summary {
    Uniform(Xy) => Ok(Xy)
    Uniform(Xyz) => Ok(Xyz)
    Uniform(Xym) | Uniform(Xyzm) =>
      Err(UnsupportedGeometry("GeoJSON M ordinates"))
    Mixed => Err(InvalidCoordinate("inconsistent coordinate dimensions"))
    NoDimension => Ok(Xy)
  }
}

///|
fn validate_geojson_writer_coordinate(
  coordinate : Coordinate,
  dimension : CoordinateDimension,
) -> Result[Unit, GeoError] {
  if coordinate.dimension() != dimension {
    return Err(
      InvalidCoordinate("coordinate dimension does not match geometry"),
    )
  }
  if coordinate.x.is_nan() || coordinate.x.is_inf() {
    return Err(InvalidCoordinate("non-finite x ordinate"))
  }
  if coordinate.y.is_nan() || coordinate.y.is_inf() {
    return Err(InvalidCoordinate("non-finite y ordinate"))
  }
  match coordinate.z {
    Some(value) =>
      if value.is_nan() || value.is_inf() {
        return Err(InvalidCoordinate("non-finite z ordinate"))
      }
    None => ()
  }
  Ok(())
}

///|
fn GeoJsonWriter::write_position(
  self : GeoJsonWriter,
  coordinate : Coordinate,
  dimension : CoordinateDimension,
) -> Result[Unit, GeoError] {
  match validate_geojson_writer_coordinate(coordinate, dimension) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  self.builder.write_string("[")
  self.builder.write_string(coordinate.x.to_string())
  self.builder.write_string(",")
  self.builder.write_string(coordinate.y.to_string())
  match dimension {
    Xyz =>
      match coordinate.z {
        Some(value) => {
          self.builder.write_string(",")
          self.builder.write_string(value.to_string())
        }
        None => ()
      }
    _ => ()
  }
  self.builder.write_string("]")
  Ok(())
}

///|
fn GeoJsonWriter::write_positions(
  self : GeoJsonWriter,
  coordinates : Array[Coordinate],
  dimension : CoordinateDimension,
) -> Result[Unit, GeoError] {
  self.builder.write_string("[")
  let mut first = true
  for coordinate in coordinates {
    if !first {
      self.builder.write_string(",")
    }
    match self.write_position(coordinate, dimension) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    first = false
  }
  self.builder.write_string("]")
  Ok(())
}

///|
fn GeoJsonWriter::write_rings(
  self : GeoJsonWriter,
  rings : Array[Array[Coordinate]],
  dimension : CoordinateDimension,
) -> Result[Unit, GeoError] {
  self.builder.write_string("[")
  let mut first = true
  for ring in rings {
    if ring.length() == 0 {
      return Err(InvalidCoordinate("polygon ring has no coordinates"))
    }
    if !first {
      self.builder.write_string(",")
    }
    match self.write_positions(ring, dimension) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    first = false
  }
  self.builder.write_string("]")
  Ok(())
}

///|
fn GeoJsonWriter::write_lines(
  self : GeoJsonWriter,
  lines : Array[Array[Coordinate]],
  dimension : CoordinateDimension,
) -> Result[Unit, GeoError] {
  self.builder.write_string("[")
  let mut first = true
  for line in lines {
    if line.length() == 0 {
      return Err(InvalidCoordinate("empty line string component"))
    }
    if !first {
      self.builder.write_string(",")
    }
    match self.write_positions(line, dimension) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    first = false
  }
  self.builder.write_string("]")
  Ok(())
}

///|
fn GeoJsonWriter::write_polygons(
  self : GeoJsonWriter,
  polygons : Array[Array[Array[Coordinate]]],
  dimension : CoordinateDimension,
) -> Result[Unit, GeoError] {
  self.builder.write_string("[")
  let mut first = true
  for polygon in polygons {
    if polygon.length() == 0 {
      return Err(InvalidCoordinate("empty polygon component"))
    }
    if !first {
      self.builder.write_string(",")
    }
    match self.write_rings(polygon, dimension) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    first = false
  }
  self.builder.write_string("]")
  Ok(())
}

///|
fn GeoJsonWriter::write_geometry(
  self : GeoJsonWriter,
  geometry : Geometry,
) -> Result[Unit, GeoError] {
  match geometry {
    Point(coordinate) => {
      let dimension = match
        resolve_geojson_dimension(Uniform(coordinate.dimension())) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      self.builder.write_string("{\"type\":\"Point\",\"coordinates\":")
      match self.write_position(coordinate, dimension) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      self.builder.write_string("}")
      Ok(())
    }
    EmptyPoint => {
      self.builder.write_string("{\"type\":\"Point\",\"coordinates\":[]}")
      Ok(())
    }
    LineString(coordinates) => {
      self.builder.write_string("{\"type\":\"LineString\",\"coordinates\":")
      if coordinates.length() == 0 {
        self.builder.write_string("[]")
      } else {
        let dimension = match
          resolve_geojson_dimension(coordinate_dimension_summary(coordinates)) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        match self.write_positions(coordinates, dimension) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      self.builder.write_string("}")
      Ok(())
    }
    Polygon(rings) => {
      self.builder.write_string("{\"type\":\"Polygon\",\"coordinates\":")
      if rings.length() == 0 {
        self.builder.write_string("[]")
      } else {
        let dimension = match
          resolve_geojson_dimension(ring_dimension_summary(rings)) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        match self.write_rings(rings, dimension) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      self.builder.write_string("}")
      Ok(())
    }
    MultiPoint(coordinates) => {
      self.builder.write_string("{\"type\":\"MultiPoint\",\"coordinates\":")
      if coordinates.length() == 0 {
        self.builder.write_string("[]")
      } else {
        let dimension = match
          resolve_geojson_dimension(coordinate_dimension_summary(coordinates)) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        match self.write_positions(coordinates, dimension) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      self.builder.write_string("}")
      Ok(())
    }
    MultiLineString(lines) => {
      self.builder.write_string(
        "{\"type\":\"MultiLineString\",\"coordinates\":",
      )
      if lines.length() == 0 {
        self.builder.write_string("[]")
      } else {
        let dimension = match
          resolve_geojson_dimension(ring_dimension_summary(lines)) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        match self.write_lines(lines, dimension) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      self.builder.write_string("}")
      Ok(())
    }
    MultiPolygon(polygons) => {
      self.builder.write_string("{\"type\":\"MultiPolygon\",\"coordinates\":")
      if polygons.length() == 0 {
        self.builder.write_string("[]")
      } else {
        let dimension = match
          resolve_geojson_dimension(polygon_dimension_summary(polygons)) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        match self.write_polygons(polygons, dimension) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      self.builder.write_string("}")
      Ok(())
    }
    GeometryCollection(geometries) => {
      self.builder.write_string(
        "{\"type\":\"GeometryCollection\",\"geometries\":[",
      )
      let mut first = true
      for child in geometries {
        if !first {
          self.builder.write_string(",")
        }
        match self.write_geometry(child) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
        first = false
      }
      self.builder.write_string("]}")
      Ok(())
    }
  }
}

///|
pub fn format_geojson(geometry : Geometry) -> Result[String, GeoError] {
  let writer = GeoJsonWriter::new()
  match writer.write_geometry(geometry) {
    Ok(_) => Ok(writer.builder.to_string())
    Err(err) => Err(err)
  }
}

///|
pub fn wkt_to_geojson(
  source : StringView,
  limits : GeoLimits,
) -> Result[String, GeoError] {
  let geometry = match parse_wkt(source, limits) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  format_geojson(geometry)
}

///|
pub fn geojson_to_wkt(
  source : StringView,
  limits : GeoLimits,
) -> Result[String, GeoError] {
  let geometry = match parse_geojson(source, limits) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  format_wkt(geometry)
}

///|
pub fn wkb_to_geojson(
  source : BytesView,
  limits : GeoLimits,
) -> Result[String, GeoError] {
  let geometry = match parse_wkb(source, limits) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  format_geojson(geometry)
}

///|
pub fn geojson_to_wkb(
  source : StringView,
  limits : GeoLimits,
) -> Result[Bytes, GeoError] {
  let geometry = match parse_geojson(source, limits) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  format_wkb(geometry)
}
