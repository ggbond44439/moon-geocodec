///|
priv struct WkbWriter {
  bytes : Array[Byte]
  order : WkbByteOrder
}

///|
fn WkbWriter::new(order : WkbByteOrder) -> WkbWriter {
  { bytes: [], order, }
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
fn WkbWriter::write_header(self : WkbWriter, type_code : UInt32) -> Unit {
  self.write_byte_order()
  self.write_u32(type_code)
}

///|
fn validate_wkb_writer_coordinate(
  coordinate : Coordinate,
) -> Result[Unit, GeoError] {
  if coordinate.dimension() != Xy {
    return Err(InvalidCoordinate("WKB writer supports only XY coordinates"))
  }
  if coordinate.x.is_nan() || coordinate.x.is_inf() {
    return Err(InvalidCoordinate("non-finite x ordinate"))
  }
  if coordinate.y.is_nan() || coordinate.y.is_inf() {
    return Err(InvalidCoordinate("non-finite y ordinate"))
  }
  Ok(())
}

///|
fn WkbWriter::write_coordinate(
  self : WkbWriter,
  coordinate : Coordinate,
) -> Result[Unit, GeoError] {
  match validate_wkb_writer_coordinate(coordinate) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  self.write_f64(coordinate.x)
  self.write_f64(coordinate.y)
  Ok(())
}

///|
fn WkbWriter::write_point_geometry(
  self : WkbWriter,
  coordinate : Coordinate,
) -> Result[Unit, GeoError] {
  self.write_header(1U)
  self.write_coordinate(coordinate)
}

///|
fn WkbWriter::write_empty_point_geometry(self : WkbWriter) -> Unit {
  self.write_header(1U)
  self.write_f64(@double.not_a_number)
  self.write_f64(@double.not_a_number)
}

///|
fn WkbWriter::write_coordinates(
  self : WkbWriter,
  coordinates : Array[Coordinate],
) -> Result[Unit, GeoError] {
  for coordinate in coordinates {
    match self.write_coordinate(coordinate) {
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
) -> Result[Unit, GeoError] {
  self.write_header(2U)
  self.write_u32(coordinates.length().reinterpret_as_uint())
  self.write_coordinates(coordinates)
}

///|
fn WkbWriter::write_polygon_geometry(
  self : WkbWriter,
  rings : Array[Array[Coordinate]],
) -> Result[Unit, GeoError] {
  self.write_header(3U)
  self.write_u32(rings.length().reinterpret_as_uint())
  for ring in rings {
    if ring.length() == 0 {
      return Err(InvalidCoordinate("polygon ring has no coordinates"))
    }
    self.write_u32(ring.length().reinterpret_as_uint())
    match self.write_coordinates(ring) {
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
) -> Result[Unit, GeoError] {
  self.write_header(4U)
  self.write_u32(coordinates.length().reinterpret_as_uint())
  for coordinate in coordinates {
    match self.write_point_geometry(coordinate) {
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
) -> Result[Unit, GeoError] {
  self.write_header(5U)
  self.write_u32(lines.length().reinterpret_as_uint())
  for line in lines {
    match self.write_line_string_geometry(line) {
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
) -> Result[Unit, GeoError] {
  self.write_header(6U)
  self.write_u32(polygons.length().reinterpret_as_uint())
  for polygon in polygons {
    match self.write_polygon_geometry(polygon) {
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
) -> Result[Unit, GeoError] {
  self.write_header(7U)
  self.write_u32(geometries.length().reinterpret_as_uint())
  for geometry in geometries {
    match self.write_geometry(geometry) {
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
) -> Result[Unit, GeoError] {
  match geometry {
    Point(coordinate) => self.write_point_geometry(coordinate)
    EmptyPoint => {
      self.write_empty_point_geometry()
      Ok(())
    }
    LineString(coordinates) => self.write_line_string_geometry(coordinates)
    Polygon(rings) => self.write_polygon_geometry(rings)
    MultiPoint(coordinates) => self.write_multi_point_geometry(coordinates)
    MultiLineString(lines) => self.write_multi_line_string_geometry(lines)
    MultiPolygon(polygons) => self.write_multi_polygon_geometry(polygons)
    GeometryCollection(geometries) =>
      self.write_geometry_collection_geometry(geometries)
  }
}

///|
/// Serializes a geometry as little-endian 2D WKB.
pub fn format_wkb(geometry : Geometry) -> Result[Bytes, GeoError] {
  format_wkb_with_order(geometry, LittleEndian)
}

///|
/// Serializes a geometry as 2D WKB using the requested byte order.
pub fn format_wkb_with_order(
  geometry : Geometry,
  order : WkbByteOrder,
) -> Result[Bytes, GeoError] {
  let writer = WkbWriter::new(order)
  match writer.write_geometry(geometry) {
    Ok(_) => Ok(Bytes::from_array(writer.bytes))
    Err(err) => Err(err)
  }
}
