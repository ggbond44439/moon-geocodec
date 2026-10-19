///|
pub(all) enum WkbByteOrder {
  LittleEndian
  BigEndian
} derive(Eq, @debug.Debug)

///|
priv struct WkbReader {
  data : BytesView
  mut offset : Int32
  limits : GeoLimits
  mut coordinate_count : Int32
  mut geometry_count : Int32
}

///|
fn WkbReader::new(data : BytesView, limits : GeoLimits) -> WkbReader {
  { data, offset: 0, limits, coordinate_count: 0, geometry_count: 0, }
}

///|
fn WkbReader::read_byte(
  self : WkbReader,
  context : String,
) -> Result[Byte, GeoError] {
  let offset = self.offset
  match self.data.get(offset) {
    Some(value) => {
      self.offset += 1
      Ok(value)
    }
    None => Err(Truncated(context, offset))
  }
}

///|
fn WkbReader::read_byte_order(
  self : WkbReader,
) -> Result[WkbByteOrder, GeoError] {
  let offset = self.offset
  let value = match self.read_byte("byte order") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match value.to_int() {
    0 => Ok(BigEndian)
    1 => Ok(LittleEndian)
    _ => Err(InvalidWkb("invalid byte order", offset))
  }
}

///|
fn WkbReader::read_u32(
  self : WkbReader,
  order : WkbByteOrder,
  context : String,
) -> Result[UInt32, GeoError] {
  let b0 = match self.read_byte(context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let b1 = match self.read_byte(context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let b2 = match self.read_byte(context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let b3 = match self.read_byte(context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match order {
    LittleEndian =>
      Ok(
        b0.to_uint() |
        (b1.to_uint() << 8) |
        (b2.to_uint() << 16) |
        (b3.to_uint() << 24),
      )
    BigEndian =>
      Ok(
        (b0.to_uint() << 24) |
        (b1.to_uint() << 16) |
        (b2.to_uint() << 8) |
        b3.to_uint(),
      )
  }
}

///|
fn WkbReader::read_f64(
  self : WkbReader,
  order : WkbByteOrder,
  context : String,
) -> Result[Double, GeoError] {
  let mut bits : UInt64 = 0UL
  match order {
    LittleEndian =>
      for index in 0..<8 {
        let value = match self.read_byte(context) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        bits = bits | (value.to_uint64() << (index * 8))
      }
    BigEndian =>
      for _ in 0..<8 {
        let value = match self.read_byte(context) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        bits = (bits << 8) | value.to_uint64()
      }
  }
  Ok(bits.reinterpret_as_double())
}

///|
fn WkbReader::read_count_with_order(
  self : WkbReader,
  order : WkbByteOrder,
  context : String,
) -> Result[Int32, GeoError] {
  let offset = self.offset
  let value = match self.read_u32(order, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if value > 2147483647U {
    Err(InvalidWkb(context + " exceeds supported range", offset))
  } else {
    Ok(value.reinterpret_as_int())
  }
}

///|
fn WkbReader::record_coordinate(self : WkbReader) -> Result[Unit, GeoError] {
  self.coordinate_count += 1
  self.limits.check_coordinates(self.coordinate_count)
}

///|
fn validate_coordinate_values(
  x : Double,
  y : Double,
  z : Double?,
  m : Double?,
) -> Result[Unit, GeoError] {
  if x.is_nan() || x.is_inf() {
    Err(InvalidCoordinate("non-finite x ordinate"))
  } else if y.is_nan() || y.is_inf() {
    Err(InvalidCoordinate("non-finite y ordinate"))
  } else if (match z {
      Some(value) => value.is_nan() || value.is_inf()
      None => false
    }) {
    Err(InvalidCoordinate("non-finite z ordinate"))
  } else if (match m {
      Some(value) => value.is_nan() || value.is_inf()
      None => false
    }) {
    Err(InvalidCoordinate("non-finite m ordinate"))
  } else {
    Ok(())
  }
}

///|
fn is_empty_point_values(
  x : Double,
  y : Double,
  z : Double?,
  m : Double?,
) -> Bool {
  x.is_nan() &&
  y.is_nan() &&
  (match z {
    Some(value) => value.is_nan()
    None => true
  }) &&
  (match m {
    Some(value) => value.is_nan()
    None => true
  })
}

///|
fn WkbReader::read_ordinate_values(
  self : WkbReader,
  order : WkbByteOrder,
  dimension : CoordinateDimension,
) -> Result[(Double, Double, Double?, Double?), GeoError] {
  let x = match self.read_f64(order, "x ordinate") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let y = match self.read_f64(order, "y ordinate") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let z : Double? = match dimension {
    Xyz | Xyzm =>
      match self.read_f64(order, "z ordinate") {
        Ok(value) => Some(value)
        Err(err) => return Err(err)
      }
    _ => None
  }
  let m : Double? = match dimension {
    Xym | Xyzm =>
      match self.read_f64(order, "m ordinate") {
        Ok(value) => Some(value)
        Err(err) => return Err(err)
      }
    _ => None
  }
  Ok((x, y, z, m))
}

///|
fn WkbReader::read_coordinate(
  self : WkbReader,
  order : WkbByteOrder,
  dimension : CoordinateDimension,
) -> Result[Coordinate, GeoError] {
  let (x, y, z, m) = match self.read_ordinate_values(order, dimension) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match validate_coordinate_values(x, y, z, m) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  match self.record_coordinate() {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok({ x, y, z, m, })
}

///|
fn WkbReader::read_coordinates(
  self : WkbReader,
  order : WkbByteOrder,
  dimension : CoordinateDimension,
  count : Int32,
) -> Result[Array[Coordinate], GeoError] {
  if count > self.limits.max_coordinates {
    return Err(
      LimitExceeded("coordinate count", self.limits.max_coordinates, count),
    )
  }
  let coordinates : Array[Coordinate] = []
  for _ in 0..<count {
    let coordinate = match self.read_coordinate(order, dimension) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    coordinates.push(coordinate)
  }
  Ok(coordinates)
}

///|
fn WkbReader::read_point_geometry(
  self : WkbReader,
  order : WkbByteOrder,
  dimension : CoordinateDimension,
) -> Result[Geometry, GeoError] {
  let (x, y, z, m) = match self.read_ordinate_values(order, dimension) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if is_empty_point_values(x, y, z, m) {
    return Ok(EmptyPoint)
  }
  match validate_coordinate_values(x, y, z, m) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  match self.record_coordinate() {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(Point({ x, y, z, m, }))
}

///|
fn WkbReader::read_line_string_geometry(
  self : WkbReader,
  order : WkbByteOrder,
  dimension : CoordinateDimension,
) -> Result[Geometry, GeoError] {
  let count = match
    self.read_count_with_order(order, "LINESTRING coordinate count") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let coordinates = match self.read_coordinates(order, dimension, count) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(LineString(coordinates))
}

///|
fn WkbReader::read_polygon_geometry(
  self : WkbReader,
  order : WkbByteOrder,
  dimension : CoordinateDimension,
) -> Result[Geometry, GeoError] {
  let ring_count = match
    self.read_count_with_order(order, "POLYGON ring count") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let rings : Array[Array[Coordinate]] = []
  for _ in 0..<ring_count {
    let count_offset = self.offset
    let point_count = match
      self.read_count_with_order(order, "polygon ring coordinate count") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if point_count == 0 {
      return Err(InvalidWkb("polygon ring has no coordinates", count_offset))
    }
    let ring = match self.read_coordinates(order, dimension, point_count) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    rings.push(ring)
  }
  Ok(Polygon(rings))
}

///|
fn WkbReader::read_multi_point_geometry(
  self : WkbReader,
  order : WkbByteOrder,
  dimension : CoordinateDimension,
  depth : Int32,
) -> Result[Geometry, GeoError] {
  let count = match
    self.read_count_with_order(order, "MULTIPOINT geometry count") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let points : Array[Coordinate] = []
  for _ in 0..<count {
    let component_offset = self.offset
    let (component, component_dimension) = match self.read_geometry(depth + 1) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if component_dimension != dimension {
      return Err(
        InvalidWkb(
          "MULTIPOINT component dimension does not match parent", component_offset,
        ),
      )
    }
    match component {
      Point(coordinate) => points.push(coordinate)
      EmptyPoint =>
        return Err(
          InvalidWkb(
            "empty point in MULTIPOINT is not supported", component_offset,
          ),
        )
      _ =>
        return Err(
          InvalidWkb("MULTIPOINT component must be a point", component_offset),
        )
    }
  }
  Ok(MultiPoint(points))
}

///|
fn WkbReader::read_multi_line_string_geometry(
  self : WkbReader,
  order : WkbByteOrder,
  dimension : CoordinateDimension,
  depth : Int32,
) -> Result[Geometry, GeoError] {
  let count = match
    self.read_count_with_order(order, "MULTILINESTRING geometry count") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let lines : Array[Array[Coordinate]] = []
  for _ in 0..<count {
    let component_offset = self.offset
    let (component, component_dimension) = match self.read_geometry(depth + 1) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if component_dimension != dimension {
      return Err(
        InvalidWkb(
          "MULTILINESTRING component dimension does not match parent", component_offset,
        ),
      )
    }
    match component {
      LineString(coordinates) => lines.push(coordinates)
      _ =>
        return Err(
          InvalidWkb(
            "MULTILINESTRING component must be a line string", component_offset,
          ),
        )
    }
  }
  Ok(MultiLineString(lines))
}

///|
fn WkbReader::read_multi_polygon_geometry(
  self : WkbReader,
  order : WkbByteOrder,
  dimension : CoordinateDimension,
  depth : Int32,
) -> Result[Geometry, GeoError] {
  let count = match
    self.read_count_with_order(order, "MULTIPOLYGON geometry count") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let polygons : Array[Array[Array[Coordinate]]] = []
  for _ in 0..<count {
    let component_offset = self.offset
    let (component, component_dimension) = match self.read_geometry(depth + 1) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if component_dimension != dimension {
      return Err(
        InvalidWkb(
          "MULTIPOLYGON component dimension does not match parent", component_offset,
        ),
      )
    }
    match component {
      Polygon(rings) => polygons.push(rings)
      _ =>
        return Err(
          InvalidWkb(
            "MULTIPOLYGON component must be a polygon", component_offset,
          ),
        )
    }
  }
  Ok(MultiPolygon(polygons))
}

///|
fn WkbReader::read_geometry_collection_geometry(
  self : WkbReader,
  order : WkbByteOrder,
  dimension : CoordinateDimension,
  depth : Int32,
) -> Result[Geometry, GeoError] {
  let count = match
    self.read_count_with_order(order, "GEOMETRYCOLLECTION geometry count") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let geometries : Array[Geometry] = []
  for _ in 0..<count {
    let component_offset = self.offset
    let (geometry, component_dimension) = match self.read_geometry(depth + 1) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if component_dimension != dimension {
      return Err(
        InvalidWkb(
          "GEOMETRYCOLLECTION component dimension does not match parent", component_offset,
        ),
      )
    }
    geometries.push(geometry)
  }
  Ok(GeometryCollection(geometries))
}

///|
fn decode_wkb_type(
  type_code : UInt32,
) -> Result[(UInt32, CoordinateDimension), GeoError] {
  if type_code >= 1U && type_code <= 7U {
    Ok((type_code, Xy))
  } else if type_code >= 1001U && type_code <= 1007U {
    Ok((type_code - 1000U, Xyz))
  } else if type_code >= 2001U && type_code <= 2007U {
    Ok((type_code - 2000U, Xym))
  } else if type_code >= 3001U && type_code <= 3007U {
    Ok((type_code - 3000U, Xyzm))
  } else {
    Err(UnsupportedGeometry("WKB type " + type_code.to_string()))
  }
}

///|
fn WkbReader::read_geometry(
  self : WkbReader,
  depth : Int32,
) -> Result[(Geometry, CoordinateDimension), GeoError] {
  match self.limits.check_depth(depth) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  self.geometry_count += 1
  match self.limits.check_geometries(self.geometry_count) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let order = match self.read_byte_order() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let type_code = match self.read_u32(order, "geometry type") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (base_code, dimension) = match decode_wkb_type(type_code) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let geometry = if base_code == 1U {
    self.read_point_geometry(order, dimension)
  } else if base_code == 2U {
    self.read_line_string_geometry(order, dimension)
  } else if base_code == 3U {
    self.read_polygon_geometry(order, dimension)
  } else if base_code == 4U {
    self.read_multi_point_geometry(order, dimension, depth)
  } else if base_code == 5U {
    self.read_multi_line_string_geometry(order, dimension, depth)
  } else if base_code == 6U {
    self.read_multi_polygon_geometry(order, dimension, depth)
  } else if base_code == 7U {
    self.read_geometry_collection_geometry(order, dimension, depth)
  } else {
    Err(UnsupportedGeometry("WKB type " + type_code.to_string()))
  }
  match geometry {
    Ok(value) => Ok((value, dimension))
    Err(err) => Err(err)
  }
}

///|
pub fn parse_wkb(
  source : BytesView,
  limits : GeoLimits,
) -> Result[Geometry, GeoError] {
  let reader = WkbReader::new(source, limits)
  let (geometry, _) = match reader.read_geometry(1) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if reader.offset != source.length() {
    Err(TrailingBytes(reader.offset))
  } else {
    Ok(geometry)
  }
}

///|
pub extend WkbByteOrder with Eq::{not_equal, equal}

///|
pub extend WkbByteOrder with @debug.Debug::{to_repr}
