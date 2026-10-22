///|
priv enum DimensionSummary {
  NoDimension
  Uniform(CoordinateDimension)
  Mixed
}

///|
fn merge_dimension_summary(
  left : DimensionSummary,
  right : DimensionSummary,
) -> DimensionSummary {
  match (left, right) {
    (NoDimension, value) => value
    (value, NoDimension) => value
    (Mixed, _) => Mixed
    (_, Mixed) => Mixed
    (Uniform(a), Uniform(b)) => if a == b { Uniform(a) } else { Mixed }
  }
}

///|
fn coordinate_dimension_summary(
  coordinates : Array[Coordinate],
) -> DimensionSummary {
  let mut result = NoDimension
  for coordinate in coordinates {
    result = merge_dimension_summary(result, Uniform(coordinate.dimension()))
  }
  result
}

///|
fn ring_dimension_summary(rings : Array[Array[Coordinate]]) -> DimensionSummary {
  let mut result = NoDimension
  for ring in rings {
    result = merge_dimension_summary(result, coordinate_dimension_summary(ring))
  }
  result
}

///|
fn polygon_dimension_summary(
  polygons : Array[Array[Array[Coordinate]]],
) -> DimensionSummary {
  let mut result = NoDimension
  for polygon in polygons {
    result = merge_dimension_summary(result, ring_dimension_summary(polygon))
  }
  result
}

///|
fn collection_dimension_summary(
  geometries : Array[Geometry],
) -> DimensionSummary {
  let mut result = NoDimension
  for geometry in geometries {
    result = merge_dimension_summary(
      result,
      geometry_dimension_summary(geometry),
    )
  }
  result
}

///|
fn geometry_dimension_summary(geometry : Geometry) -> DimensionSummary {
  match geometry {
    Point(coordinate) => Uniform(coordinate.dimension())
    EmptyPoint => NoDimension
    LineString(coordinates) => coordinate_dimension_summary(coordinates)
    Polygon(rings) => ring_dimension_summary(rings)
    MultiPoint(coordinates) => coordinate_dimension_summary(coordinates)
    MultiLineString(lines) => ring_dimension_summary(lines)
    MultiPolygon(polygons) => polygon_dimension_summary(polygons)
    GeometryCollection(geometries) => collection_dimension_summary(geometries)
  }
}

///|
fn summarize_uniform_dimension(
  summary : DimensionSummary,
) -> Result[CoordinateDimension, GeoError] {
  match summary {
    Uniform(dimension) => Ok(dimension)
    Mixed => Err(InvalidCoordinate("inconsistent coordinate dimensions"))
    NoDimension => Err(InvalidCoordinate("geometry has no coordinates"))
  }
}

///|
fn write_dimension_suffix(
  builder : StringBuilder,
  dimension : CoordinateDimension,
) -> Unit {
  match dimension {
    Xy => ()
    Xyz => builder.write_string(" Z")
    Xym => builder.write_string(" M")
    Xyzm => builder.write_string(" ZM")
  }
}

///|
fn validate_coordinate(
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
  match coordinate.m {
    Some(value) =>
      if value.is_nan() || value.is_inf() {
        return Err(InvalidCoordinate("non-finite m ordinate"))
      }
    None => ()
  }
  Ok(())
}

///|
fn write_coordinate_tuple(
  builder : StringBuilder,
  coordinate : Coordinate,
  dimension : CoordinateDimension,
) -> Unit {
  builder.write_string(coordinate.x.to_string())
  builder.write_string(" ")
  builder.write_string(coordinate.y.to_string())
  match dimension {
    Xyz | Xyzm =>
      match coordinate.z {
        Some(value) => {
          builder.write_string(" ")
          builder.write_string(value.to_string())
        }
        None => ()
      }
    _ => ()
  }
  match dimension {
    Xym | Xyzm =>
      match coordinate.m {
        Some(value) => {
          builder.write_string(" ")
          builder.write_string(value.to_string())
        }
        None => ()
      }
    _ => ()
  }
}

///|
fn write_coordinate_list(
  builder : StringBuilder,
  coordinates : Array[Coordinate],
  dimension : CoordinateDimension,
) -> Result[Unit, GeoError] {
  let mut first = true
  for coordinate in coordinates {
    match validate_coordinate(coordinate, dimension) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    if !first {
      builder.write_string(", ")
    }
    write_coordinate_tuple(builder, coordinate, dimension)
    first = false
  }
  Ok(())
}

///|
fn write_sequence(
  builder : StringBuilder,
  coordinates : Array[Coordinate],
  dimension : CoordinateDimension,
  empty_message : String,
) -> Result[Unit, GeoError] {
  if coordinates.length() == 0 {
    return Err(InvalidCoordinate(empty_message))
  }
  builder.write_string("(")
  match write_coordinate_list(builder, coordinates, dimension) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  builder.write_string(")")
  Ok(())
}

///|
fn write_geometry_header(
  builder : StringBuilder,
  name : String,
  dimension : CoordinateDimension,
  inherited_dimension : CoordinateDimension?,
) -> Result[Unit, GeoError] {
  match inherited_dimension {
    Some(parent) =>
      if parent != dimension {
        Err(InvalidCoordinate("geometry dimension does not match collection"))
      } else {
        builder.write_string(name)
        Ok(())
      }
    None => {
      builder.write_string(name)
      write_dimension_suffix(builder, dimension)
      Ok(())
    }
  }
}

///|
fn write_empty_geometry(builder : StringBuilder, name : String) -> Unit {
  builder.write_string(name)
  builder.write_string(" EMPTY")
}

///|
fn write_point_geometry(
  builder : StringBuilder,
  coordinate : Coordinate,
  inherited_dimension : CoordinateDimension?,
) -> Result[Unit, GeoError] {
  let dimension = coordinate.dimension()
  match
    write_geometry_header(builder, "POINT", dimension, inherited_dimension) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  match validate_coordinate(coordinate, dimension) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  builder.write_string(" (")
  write_coordinate_tuple(builder, coordinate, dimension)
  builder.write_string(")")
  Ok(())
}

///|
fn write_line_string_geometry(
  builder : StringBuilder,
  coordinates : Array[Coordinate],
  inherited_dimension : CoordinateDimension?,
) -> Result[Unit, GeoError] {
  if coordinates.length() == 0 {
    write_empty_geometry(builder, "LINESTRING")
    return Ok(())
  }
  let dimension = match
    summarize_uniform_dimension(coordinate_dimension_summary(coordinates)) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match
    write_geometry_header(builder, "LINESTRING", dimension, inherited_dimension) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  builder.write_string(" ")
  write_sequence(builder, coordinates, dimension, "empty line string")
}

///|
fn write_polygon_rings(
  builder : StringBuilder,
  rings : Array[Array[Coordinate]],
  dimension : CoordinateDimension,
) -> Result[Unit, GeoError] {
  let mut first = true
  for ring in rings {
    if !first {
      builder.write_string(", ")
    }
    match write_sequence(builder, ring, dimension, "empty polygon ring") {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    first = false
  }
  Ok(())
}

///|
fn write_polygon_geometry(
  builder : StringBuilder,
  rings : Array[Array[Coordinate]],
  inherited_dimension : CoordinateDimension?,
) -> Result[Unit, GeoError] {
  if rings.length() == 0 {
    write_empty_geometry(builder, "POLYGON")
    return Ok(())
  }
  for ring in rings {
    if ring.length() == 0 {
      return Err(InvalidCoordinate("empty polygon ring"))
    }
  }
  let dimension = match
    summarize_uniform_dimension(ring_dimension_summary(rings)) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match
    write_geometry_header(builder, "POLYGON", dimension, inherited_dimension) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  builder.write_string(" (")
  match write_polygon_rings(builder, rings, dimension) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  builder.write_string(")")
  Ok(())
}

///|
fn write_multi_point_coordinates(
  builder : StringBuilder,
  coordinates : Array[Coordinate],
  dimension : CoordinateDimension,
  wrapped : Bool,
) -> Result[Unit, GeoError] {
  let mut first = true
  for coordinate in coordinates {
    match validate_coordinate(coordinate, dimension) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    if !first {
      builder.write_string(", ")
    }
    if wrapped {
      builder.write_string("(")
    }
    write_coordinate_tuple(builder, coordinate, dimension)
    if wrapped {
      builder.write_string(")")
    }
    first = false
  }
  Ok(())
}

///|
fn write_multi_point_geometry(
  builder : StringBuilder,
  coordinates : Array[Coordinate],
  inherited_dimension : CoordinateDimension?,
  dialect : WktDialect,
) -> Result[Unit, GeoError] {
  if coordinates.length() == 0 {
    write_empty_geometry(builder, "MULTIPOINT")
    return Ok(())
  }
  let dimension = match
    summarize_uniform_dimension(coordinate_dimension_summary(coordinates)) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match
    write_geometry_header(builder, "MULTIPOINT", dimension, inherited_dimension) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  builder.write_string(" (")
  match
    write_multi_point_coordinates(
      builder,
      coordinates,
      dimension,
      dialect == Wkt2,
    ) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  builder.write_string(")")
  Ok(())
}

///|
fn write_multi_line_string_geometry(
  builder : StringBuilder,
  lines : Array[Array[Coordinate]],
  inherited_dimension : CoordinateDimension?,
) -> Result[Unit, GeoError] {
  if lines.length() == 0 {
    write_empty_geometry(builder, "MULTILINESTRING")
    return Ok(())
  }
  for line in lines {
    if line.length() == 0 {
      return Err(InvalidCoordinate("empty line string component"))
    }
  }
  let dimension = match
    summarize_uniform_dimension(ring_dimension_summary(lines)) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match
    write_geometry_header(
      builder, "MULTILINESTRING", dimension, inherited_dimension,
    ) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  builder.write_string(" (")
  let mut first = true
  for line in lines {
    if !first {
      builder.write_string(", ")
    }
    match
      write_sequence(builder, line, dimension, "empty line string component") {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    first = false
  }
  builder.write_string(")")
  Ok(())
}

///|
fn write_multi_polygon_geometry(
  builder : StringBuilder,
  polygons : Array[Array[Array[Coordinate]]],
  inherited_dimension : CoordinateDimension?,
) -> Result[Unit, GeoError] {
  if polygons.length() == 0 {
    write_empty_geometry(builder, "MULTIPOLYGON")
    return Ok(())
  }
  for polygon in polygons {
    if polygon.length() == 0 {
      return Err(InvalidCoordinate("empty polygon component"))
    }
    for ring in polygon {
      if ring.length() == 0 {
        return Err(InvalidCoordinate("empty polygon ring"))
      }
    }
  }
  let dimension = match
    summarize_uniform_dimension(polygon_dimension_summary(polygons)) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match
    write_geometry_header(
      builder, "MULTIPOLYGON", dimension, inherited_dimension,
    ) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  builder.write_string(" (")
  let mut first = true
  for polygon in polygons {
    if !first {
      builder.write_string(", ")
    }
    builder.write_string("(")
    match write_polygon_rings(builder, polygon, dimension) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    builder.write_string(")")
    first = false
  }
  builder.write_string(")")
  Ok(())
}

///|
fn write_geometry_collection_geometry(
  builder : StringBuilder,
  geometries : Array[Geometry],
  inherited_dimension : CoordinateDimension?,
  dialect : WktDialect,
) -> Result[Unit, GeoError] {
  if geometries.length() == 0 {
    write_empty_geometry(builder, "GEOMETRYCOLLECTION")
    return Ok(())
  }
  let summary = collection_dimension_summary(geometries)
  builder.write_string("GEOMETRYCOLLECTION")
  let child_dimension : CoordinateDimension? = match inherited_dimension {
    Some(parent) => {
      match summary {
        Uniform(dimension) =>
          if dimension != parent {
            return Err(
              InvalidCoordinate("geometry dimension does not match collection"),
            )
          }
        Mixed =>
          return Err(
            InvalidCoordinate("mixed dimensions in dimensioned collection"),
          )
        NoDimension => ()
      }
      Some(parent)
    }
    None =>
      match summary {
        Uniform(dimension) => {
          write_dimension_suffix(builder, dimension)
          Some(dimension)
        }
        Mixed | NoDimension => None
      }
  }
  builder.write_string(" (")
  let mut first = true
  for geometry in geometries {
    if !first {
      builder.write_string(", ")
    }
    match write_geometry(builder, geometry, child_dimension, dialect) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    first = false
  }
  builder.write_string(")")
  Ok(())
}

///|
fn write_geometry(
  builder : StringBuilder,
  geometry : Geometry,
  inherited_dimension : CoordinateDimension?,
  dialect : WktDialect,
) -> Result[Unit, GeoError] {
  match geometry {
    Point(coordinate) =>
      write_point_geometry(builder, coordinate, inherited_dimension)
    EmptyPoint => {
      write_empty_geometry(builder, "POINT")
      Ok(())
    }
    LineString(coordinates) =>
      write_line_string_geometry(builder, coordinates, inherited_dimension)
    Polygon(rings) =>
      write_polygon_geometry(builder, rings, inherited_dimension)
    MultiPoint(coordinates) =>
      write_multi_point_geometry(
        builder, coordinates, inherited_dimension, dialect,
      )
    MultiLineString(lines) =>
      write_multi_line_string_geometry(builder, lines, inherited_dimension)
    MultiPolygon(polygons) =>
      write_multi_polygon_geometry(builder, polygons, inherited_dimension)
    GeometryCollection(geometries) =>
      write_geometry_collection_geometry(
        builder, geometries, inherited_dimension, dialect,
      )
  }
}

///|
fn format_wkt_dialect(
  geometry : Geometry,
  dialect : WktDialect,
) -> Result[String, GeoError] {
  let builder = StringBuilder()
  match write_geometry(builder, geometry, None, dialect) {
    Ok(_) => Ok(builder.to_string())
    Err(err) => Err(err)
  }
}

///|
pub fn format_wkt(geometry : Geometry) -> Result[String, GeoError] {
  format_wkt_dialect(geometry, Wkt1)
}

///|
pub fn format_wkt2(geometry : Geometry) -> Result[String, GeoError] {
  format_wkt_dialect(geometry, Wkt2)
}

///|
pub fn format_ewkt(value : SpatialGeometry) -> Result[String, GeoError] {
  let text = match format_wkt(value.geometry) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match value.srid {
    Some(srid) =>
      if srid < 0 {
        Err(InvalidSrid(srid))
      } else {
        Ok("SRID=" + srid.to_string() + ";" + text)
      }
    None => Ok(text)
  }
}
