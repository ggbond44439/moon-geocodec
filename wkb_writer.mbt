///|
priv enum WkbEncoding {
  IsoWkb
  Ewkb
}

///|
priv struct WkbWriter {
  bytes : Array[Byte]
  order : WkbByteOrder
  encoding : WkbEncoding
}

///|
fn WkbWriter::new(order : WkbByteOrder, encoding : WkbEncoding) -> WkbWriter {
  { bytes: [], order, encoding, }
}

///|
fn WkbWriter::write_byte_order(self : WkbWriter) -> Unit {
  match self.order {
    LittleEndian => self.bytes.push(b'\x01')
    BigEndian => self.bytes.push(b'\x00')
  }
}

///|
fn WkbWriter::write_u32(self : WkbWriter, value : UInt32) -> Unit {
  match self.order {
    LittleEndian => {
      self.bytes.push(value.land(255U).to_byte())
      self.bytes.push((value >> 8).land(255U).to_byte())
      self.bytes.push((value >> 16).land(255U).to_byte())
      self.bytes.push((value >> 24).land(255U).to_byte())
    }
    BigEndian => {
      self.bytes.push((value >> 24).land(255U).to_byte())
      self.bytes.push((value >> 16).land(255U).to_byte())
      self.bytes.push((value >> 8).land(255U).to_byte())
      self.bytes.push(value.land(255U).to_byte())
    }
  }
}

///|
fn WkbWriter::write_f64(self : WkbWriter, value : Double) -> Unit {
  let bits = value.reinterpret_as_uint64()
  for index in 0..<8 {
    let shift = match self.order {
      LittleEndian => index * 8
      BigEndian => (7 - index) * 8
    }
    self.bytes.push((bits >> shift).land(255UL).to_byte())
  }
}

///|
fn wkb_dimension_offset(dimension : CoordinateDimension) -> UInt32 {
  match dimension {
    Xy => 0U
    Xyz => 1000U
    Xym => 2000U
    Xyzm => 3000U
  }
}

///|
fn WkbWriter::write_header(
  self : WkbWriter,
  base_code : UInt32,
  dimension : CoordinateDimension,
  srid : Int32?,
) -> Unit {
  self.write_byte_order()
  match self.encoding {
    IsoWkb => self.write_u32(base_code + wkb_dimension_offset(dimension))
    Ewkb => {
      let mut type_code = base_code
      match dimension {
        Xyz | Xyzm => type_code = type_code | 0x80000000U
        _ => ()
      }
      match dimension {
        Xym | Xyzm => type_code = type_code | 0x40000000U
        _ => ()
      }
      match srid {
        Some(_) => type_code = type_code | 0x20000000U
        None => ()
      }
      self.write_u32(type_code)
      match srid {
        Some(value) => self.write_u32(value.reinterpret_as_uint())
        None => ()
      }
    }
  }
}

///|
fn validate_wkb_writer_coordinate(
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
fn WkbWriter::write_coordinate(
  self : WkbWriter,
  coordinate : Coordinate,
  dimension : CoordinateDimension,
) -> Result[Unit, GeoError] {
  match validate_wkb_writer_coordinate(coordinate, dimension) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  self.write_f64(coordinate.x)
  self.write_f64(coordinate.y)
  match dimension {
    Xyz | Xyzm =>
      match coordinate.z {
        Some(value) => self.write_f64(value)
        None => ()
      }
    _ => ()
  }
  match dimension {
    Xym | Xyzm =>
      match coordinate.m {
        Some(value) => self.write_f64(value)
        None => ()
      }
    _ => ()
  }
  Ok(())
}

///|
fn WkbWriter::write_point_geometry(
  self : WkbWriter,
  coordinate : Coordinate,
  dimension : CoordinateDimension,
  srid : Int32?,
) -> Result[Unit, GeoError] {
  self.write_header(1U, dimension, srid)
  self.write_coordinate(coordinate, dimension)
}

///|
fn WkbWriter::write_empty_point_geometry(
  self : WkbWriter,
  dimension : CoordinateDimension,
  srid : Int32?,
) -> Unit {
  self.write_header(1U, dimension, srid)
  self.write_f64(@double.not_a_number)
  self.write_f64(@double.not_a_number)
  match dimension {
    Xyz | Xyzm => self.write_f64(@double.not_a_number)
    _ => ()
  }
  match dimension {
    Xym | Xyzm => self.write_f64(@double.not_a_number)
    _ => ()
  }
}

///|
fn WkbWriter::write_coordinates(
  self : WkbWriter,
  coordinates : Array[Coordinate],
  dimension : CoordinateDimension,
) -> Result[Unit, GeoError] {
  for coordinate in coordinates {
    match self.write_coordinate(coordinate, dimension) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(())
}

///|
fn WkbWriter::write_line_string_geometry(
  self : WkbWriter,
  coordinates : Array[Coordinate],
  dimension : CoordinateDimension,
  srid : Int32?,
) -> Result[Unit, GeoError] {
  self.write_header(2U, dimension, srid)
  self.write_u32(coordinates.length().reinterpret_as_uint())
  self.write_coordinates(coordinates, dimension)
}

///|
fn WkbWriter::write_polygon_geometry(
  self : WkbWriter,
  rings : Array[Array[Coordinate]],
  dimension : CoordinateDimension,
  srid : Int32?,
) -> Result[Unit, GeoError] {
  self.write_header(3U, dimension, srid)
  self.write_u32(rings.length().reinterpret_as_uint())
  for ring in rings {
    if ring.length() == 0 {
      return Err(InvalidCoordinate("polygon ring has no coordinates"))
    }
    self.write_u32(ring.length().reinterpret_as_uint())
    match self.write_coordinates(ring, dimension) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(())
}

///|
fn WkbWriter::write_multi_point_geometry(
  self : WkbWriter,
  coordinates : Array[Coordinate],
  dimension : CoordinateDimension,
  srid : Int32?,
) -> Result[Unit, GeoError] {
  self.write_header(4U, dimension, srid)
  self.write_u32(coordinates.length().reinterpret_as_uint())
  for coordinate in coordinates {
    match self.write_point_geometry(coordinate, dimension, None) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(())
}

///|
fn WkbWriter::write_multi_line_string_geometry(
  self : WkbWriter,
  lines : Array[Array[Coordinate]],
  dimension : CoordinateDimension,
  srid : Int32?,
) -> Result[Unit, GeoError] {
  self.write_header(5U, dimension, srid)
  self.write_u32(lines.length().reinterpret_as_uint())
  for line in lines {
    match self.write_line_string_geometry(line, dimension, None) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(())
}

///|
fn WkbWriter::write_multi_polygon_geometry(
  self : WkbWriter,
  polygons : Array[Array[Array[Coordinate]]],
  dimension : CoordinateDimension,
  srid : Int32?,
) -> Result[Unit, GeoError] {
  self.write_header(6U, dimension, srid)
  self.write_u32(polygons.length().reinterpret_as_uint())
  for polygon in polygons {
    match self.write_polygon_geometry(polygon, dimension, None) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(())
}

///|
fn WkbWriter::write_geometry_collection_geometry(
  self : WkbWriter,
  geometries : Array[Geometry],
  dimension : CoordinateDimension,
  srid : Int32?,
) -> Result[Unit, GeoError] {
  self.write_header(7U, dimension, srid)
  self.write_u32(geometries.length().reinterpret_as_uint())
  for geometry in geometries {
    match self.write_geometry(geometry, dimension, None) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(())
}

///|
fn WkbWriter::write_geometry(
  self : WkbWriter,
  geometry : Geometry,
  dimension : CoordinateDimension,
  srid : Int32?,
) -> Result[Unit, GeoError] {
  match geometry {
    Point(coordinate) => self.write_point_geometry(coordinate, dimension, srid)
    EmptyPoint => {
      self.write_empty_point_geometry(dimension, srid)
      Ok(())
    }
    LineString(coordinates) =>
      self.write_line_string_geometry(coordinates, dimension, srid)
    Polygon(rings) => self.write_polygon_geometry(rings, dimension, srid)
    MultiPoint(coordinates) =>
      self.write_multi_point_geometry(coordinates, dimension, srid)
    MultiLineString(lines) =>
      self.write_multi_line_string_geometry(lines, dimension, srid)
    MultiPolygon(polygons) =>
      self.write_multi_polygon_geometry(polygons, dimension, srid)
    GeometryCollection(geometries) =>
      self.write_geometry_collection_geometry(geometries, dimension, srid)
  }
}

///|
fn resolve_wkb_dimension(
  geometry : Geometry,
) -> Result[CoordinateDimension, GeoError] {
  match geometry_dimension_summary(geometry) {
    Uniform(value) => Ok(value)
    NoDimension => Ok(Xy)
    Mixed => Err(InvalidCoordinate("inconsistent coordinate dimensions"))
  }
}

///|
/// Serializes a geometry as little-endian WKB.
pub fn format_wkb(geometry : Geometry) -> Result[Bytes, GeoError] {
  format_wkb_with_order(geometry, LittleEndian)
}

///|
/// Serializes a geometry as WKB using the requested byte order.
pub fn format_wkb_with_order(
  geometry : Geometry,
  order : WkbByteOrder,
) -> Result[Bytes, GeoError] {
  let dimension = match resolve_wkb_dimension(geometry) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let writer = WkbWriter::new(order, IsoWkb)
  match writer.write_geometry(geometry, dimension, None) {
    Ok(_) => Ok(Bytes::from_array(writer.bytes))
    Err(err) => Err(err)
  }
}

///|
/// Serializes a spatial geometry as little-endian EWKB.
pub fn format_ewkb(value : SpatialGeometry) -> Result[Bytes, GeoError] {
  format_ewkb_with_order(value, LittleEndian)
}

///|
/// Serializes a spatial geometry as EWKB using the requested byte order.
pub fn format_ewkb_with_order(
  value : SpatialGeometry,
  order : WkbByteOrder,
) -> Result[Bytes, GeoError] {
  match value.srid {
    Some(srid) => if srid < 0 { return Err(InvalidSrid(srid)) }
    None => ()
  }
  let dimension = match resolve_wkb_dimension(value.geometry) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let writer = WkbWriter::new(order, Ewkb)
  match writer.write_geometry(value.geometry, dimension, value.srid) {
    Ok(_) => Ok(Bytes::from_array(writer.bytes))
    Err(err) => Err(err)
  }
}
