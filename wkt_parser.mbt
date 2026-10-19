///|
priv struct WktParser {
  tokens : Array[WktToken]
  mut index : Int32
  limits : GeoLimits
  mut coordinate_count : Int32
  mut geometry_count : Int32
}

///|
fn WktParser::new(tokens : Array[WktToken], limits : GeoLimits) -> WktParser {
  { tokens, index: 0, limits, coordinate_count: 0, geometry_count: 0, }
}

///|
fn WktParser::current(self : WktParser) -> WktToken {
  self.tokens[self.index]
}

///|
fn WktParser::advance(self : WktParser) -> Unit {
  self.index += 1
}

///|
fn word_matches(value : String, expected : String) -> Bool {
  value.equal_ignore_ascii_case(expected)
}

///|
fn WktParser::current_is_word(self : WktParser, expected : String) -> Bool {
  let token = self.current()
  token.kind == Word && word_matches(token.text, expected)
}

///|
fn WktParser::take_dimension_suffix(self : WktParser) -> CoordinateDimension? {
  let token = self.current()
  if token.kind == Word {
    if word_matches(token.text, "ZM") {
      self.advance()
      Some(Xyzm)
    } else if word_matches(token.text, "Z") {
      self.advance()
      Some(Xyz)
    } else if word_matches(token.text, "M") {
      self.advance()
      Some(Xym)
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn WktParser::expect_kind(
  self : WktParser,
  kind : WktTokenKind,
  message : String,
) -> Result[Unit, GeoError] {
  let token = self.current()
  if token.kind != kind {
    Err(InvalidWkt(message, token.offset))
  } else {
    self.advance()
    Ok(())
  }
}

///|
fn WktParser::parse_number(
  self : WktParser,
  message : String,
) -> Result[Double, GeoError] {
  let token = self.current()
  if token.kind != Number {
    return Err(InvalidWkt(message, token.offset))
  }
  let value = @string.parse_double(token.text.view()) catch {
    _ => return Err(InvalidWkt("number out of range", token.offset))
  }
  self.advance()
  Ok(value)
}

///|
fn WktParser::parse_coordinate(
  self : WktParser,
  dimension : CoordinateDimension,
) -> Result[Coordinate, GeoError] {
  let x = match self.parse_number("expected x ordinate") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let y = match self.parse_number("expected y ordinate") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let z : Double? = match dimension {
    Xyz | Xyzm =>
      match self.parse_number("expected z ordinate") {
        Ok(value) => Some(value)
        Err(err) => return Err(err)
      }
    _ => None
  }
  let m : Double? = match dimension {
    Xym | Xyzm =>
      match self.parse_number("expected m ordinate") {
        Ok(value) => Some(value)
        Err(err) => return Err(err)
      }
    _ => None
  }
  if self.current().kind == Number {
    return Err(InvalidWkt("too many ordinates", self.current().offset))
  }
  self.coordinate_count += 1
  match self.limits.check_coordinates(self.coordinate_count) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok({ x, y, z, m, })
}

///|
fn WktParser::parse_coordinate_list(
  self : WktParser,
  dimension : CoordinateDimension,
) -> Result[Array[Coordinate], GeoError] {
  let coordinates : Array[Coordinate] = []
  while true {
    let coordinate = match self.parse_coordinate(dimension) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    coordinates.push(coordinate)
    if self.current().kind == Comma {
      self.advance()
    } else {
      break
    }
  }
  Ok(coordinates)
}

///|
fn WktParser::parse_ring(
  self : WktParser,
  dimension : CoordinateDimension,
) -> Result[Array[Coordinate], GeoError] {
  match self.expect_kind(LParen, "expected '(' to start polygon ring") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let coordinates = match self.parse_coordinate_list(dimension) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match self.expect_kind(RParen, "expected ')' after polygon ring") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(coordinates)
}

///|
fn WktParser::parse_point_geometry(
  self : WktParser,
  dimension : CoordinateDimension,
) -> Result[Geometry, GeoError] {
  match self.expect_kind(LParen, "expected '(' after POINT") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let coordinate = match self.parse_coordinate(dimension) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match self.expect_kind(RParen, "expected ')' after POINT coordinate") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(Point(coordinate))
}

///|
fn WktParser::parse_line_string_geometry(
  self : WktParser,
  dimension : CoordinateDimension,
) -> Result[Geometry, GeoError] {
  match self.expect_kind(LParen, "expected '(' after LINESTRING") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let coordinates = match self.parse_coordinate_list(dimension) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match self.expect_kind(RParen, "expected ')' after LINESTRING coordinates") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(LineString(coordinates))
}

///|
fn WktParser::parse_polygon_geometry(
  self : WktParser,
  dimension : CoordinateDimension,
) -> Result[Geometry, GeoError] {
  match self.expect_kind(LParen, "expected '(' after POLYGON") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let rings : Array[Array[Coordinate]] = []
  while true {
    let ring = match self.parse_ring(dimension) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    rings.push(ring)
    if self.current().kind == Comma {
      self.advance()
    } else {
      break
    }
  }
  match self.expect_kind(RParen, "expected ')' after POLYGON rings") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(Polygon(rings))
}

///|
fn WktParser::parse_multi_point_geometry(
  self : WktParser,
  dimension : CoordinateDimension,
) -> Result[Geometry, GeoError] {
  match self.expect_kind(LParen, "expected '(' after MULTIPOINT") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let points : Array[Coordinate] = []
  let wrapped = self.current().kind == LParen
  while true {
    let coordinate = if wrapped {
      match
        self.expect_kind(LParen, "expected '(' before MULTIPOINT coordinate") {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      let coordinate = match self.parse_coordinate(dimension) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      match
        self.expect_kind(RParen, "expected ')' after MULTIPOINT coordinate") {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      coordinate
    } else {
      match self.parse_coordinate(dimension) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
    }
    points.push(coordinate)
    if self.current().kind == Comma {
      self.advance()
      if wrapped && self.current().kind != LParen {
        return Err(
          InvalidWkt(
            "expected '(' before MULTIPOINT coordinate",
            self.current().offset,
          ),
        )
      }
      if !wrapped && self.current().kind == LParen {
        return Err(
          InvalidWkt("mixed MULTIPOINT coordinate forms", self.current().offset),
        )
      }
    } else {
      break
    }
  }
  match self.expect_kind(RParen, "expected ')' after MULTIPOINT coordinates") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(MultiPoint(points))
}

///|
fn WktParser::parse_multi_line_string_geometry(
  self : WktParser,
  dimension : CoordinateDimension,
) -> Result[Geometry, GeoError] {
  match self.expect_kind(LParen, "expected '(' after MULTILINESTRING") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let lines : Array[Array[Coordinate]] = []
  while true {
    match
      self.expect_kind(LParen, "expected '(' before MULTILINESTRING component") {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    let coordinates = match self.parse_coordinate_list(dimension) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    match
      self.expect_kind(RParen, "expected ')' after MULTILINESTRING component") {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    lines.push(coordinates)
    if self.current().kind == Comma {
      self.advance()
    } else {
      break
    }
  }
  match
    self.expect_kind(RParen, "expected ')' after MULTILINESTRING coordinates") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(MultiLineString(lines))
}

///|
fn WktParser::parse_multi_polygon_geometry(
  self : WktParser,
  dimension : CoordinateDimension,
) -> Result[Geometry, GeoError] {
  match self.expect_kind(LParen, "expected '(' after MULTIPOLYGON") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let polygons : Array[Array[Array[Coordinate]]] = []
  while true {
    match self.expect_kind(LParen, "expected '(' before MULTIPOLYGON polygon") {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    let rings : Array[Array[Coordinate]] = []
    while true {
      let ring = match self.parse_ring(dimension) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      rings.push(ring)
      if self.current().kind == Comma {
        self.advance()
      } else {
        break
      }
    }
    match self.expect_kind(RParen, "expected ')' after MULTIPOLYGON polygon") {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    polygons.push(rings)
    if self.current().kind == Comma {
      self.advance()
    } else {
      break
    }
  }
  match self.expect_kind(RParen, "expected ')' after MULTIPOLYGON polygons") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(MultiPolygon(polygons))
}

///|
fn WktParser::parse_geometry_collection_geometry(
  self : WktParser,
  dimension : CoordinateDimension?,
  depth : Int32,
) -> Result[Geometry, GeoError] {
  match self.expect_kind(LParen, "expected '(' after GEOMETRYCOLLECTION") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let geometries : Array[Geometry] = []
  while true {
    let geometry = match self.parse_geometry(dimension, depth) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    geometries.push(geometry)
    if self.current().kind == Comma {
      self.advance()
    } else {
      break
    }
  }
  match
    self.expect_kind(RParen, "expected ')' after GEOMETRYCOLLECTION members") {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(GeometryCollection(geometries))
}

///|
fn geometry_kind_from_name(name : String) -> GeometryKind? {
  if word_matches(name, "POINT") {
    Some(Point)
  } else if word_matches(name, "LINESTRING") {
    Some(LineString)
  } else if word_matches(name, "POLYGON") {
    Some(Polygon)
  } else if word_matches(name, "MULTIPOINT") {
    Some(MultiPoint)
  } else if word_matches(name, "MULTILINESTRING") {
    Some(MultiLineString)
  } else if word_matches(name, "MULTIPOLYGON") {
    Some(MultiPolygon)
  } else if word_matches(name, "GEOMETRYCOLLECTION") {
    Some(GeometryCollection)
  } else {
    None
  }
}

///|
fn WktParser::finish(
  self : WktParser,
  geometry : Geometry,
) -> Result[Geometry, GeoError] {
  let token = self.current()
  if token.kind != End {
    Err(InvalidWkt("unexpected token after geometry", token.offset))
  } else {
    Ok(geometry)
  }
}

///|
fn WktParser::parse_geometry(
  self : WktParser,
  inherited_dimension : CoordinateDimension?,
  depth : Int32,
) -> Result[Geometry, GeoError] {
  match self.limits.check_depth(depth) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  self.geometry_count += 1
  match self.limits.check_geometries(self.geometry_count) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let header = self.current()
  if header.kind != Word {
    return Err(InvalidWkt("expected geometry type", header.offset))
  }
  self.advance()
  let name = header.text
  let suffix_token = self.current()
  let suffix = self.take_dimension_suffix()
  let declared_dimension : CoordinateDimension? = match
    (inherited_dimension, suffix) {
    (Some(parent), Some(child)) =>
      if parent == child {
        Some(parent)
      } else {
        return Err(
          InvalidWkt(
            "dimension suffix conflicts with enclosing geometry",
            suffix_token.offset,
          ),
        )
      }
    (Some(parent), None) => Some(parent)
    (None, Some(child)) => Some(child)
    (None, None) => None
  }
  let dimension = match declared_dimension {
    Some(value) => value
    None => Xy
  }
  let kind = match geometry_kind_from_name(name) {
    Some(value) => value
    None => return Err(InvalidWkt("unknown geometry type", header.offset))
  }
  if self.current_is_word("EMPTY") {
    self.advance()
    let geometry = match kind {
      Point => EmptyPoint
      LineString => LineString([])
      Polygon => Polygon([])
      MultiPoint => MultiPoint([])
      MultiLineString => MultiLineString([])
      MultiPolygon => MultiPolygon([])
      GeometryCollection => GeometryCollection([])
    }
    return Ok(geometry)
  }
  match kind {
    Point =>
      match self.parse_point_geometry(dimension) {
        Ok(value) => Ok(value)
        Err(err) => Err(err)
      }
    LineString =>
      match self.parse_line_string_geometry(dimension) {
        Ok(value) => Ok(value)
        Err(err) => Err(err)
      }
    Polygon =>
      match self.parse_polygon_geometry(dimension) {
        Ok(value) => Ok(value)
        Err(err) => Err(err)
      }
    MultiPoint =>
      match self.parse_multi_point_geometry(dimension) {
        Ok(value) => Ok(value)
        Err(err) => Err(err)
      }
    MultiLineString =>
      match self.parse_multi_line_string_geometry(dimension) {
        Ok(value) => Ok(value)
        Err(err) => Err(err)
      }
    MultiPolygon =>
      match self.parse_multi_polygon_geometry(dimension) {
        Ok(value) => Ok(value)
        Err(err) => Err(err)
      }
    GeometryCollection =>
      match
        self.parse_geometry_collection_geometry(declared_dimension, depth + 1) {
        Ok(value) => Ok(value)
        Err(err) => Err(err)
      }
  }
}

///|
pub fn parse_wkt(
  source : StringView,
  limits : GeoLimits,
) -> Result[Geometry, GeoError] {
  let tokens = match tokenize_wkt(source, limits) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let parser = WktParser::new(tokens, limits)
  let geometry = match parser.parse_geometry(None, 1) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  parser.finish(geometry)
}
