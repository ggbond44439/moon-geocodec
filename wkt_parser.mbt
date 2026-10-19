///|
priv struct WktParser {
  tokens : Array[WktToken]
  mut index : Int32
  limits : GeoLimits
  mut coordinate_count : Int32
}

///|
fn WktParser::new(tokens : Array[WktToken], limits : GeoLimits) -> WktParser {
  { tokens, index: 0, limits, coordinate_count: 0, }
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
fn WktParser::take_dimension(self : WktParser) -> CoordinateDimension {
  let token = self.current()
  if token.kind == Word {
    if word_matches(token.text, "ZM") {
      self.advance()
      Xyzm
    } else if word_matches(token.text, "Z") {
      self.advance()
      Xyz
    } else if word_matches(token.text, "M") {
      self.advance()
      Xym
    } else {
      Xy
    }
  } else {
    Xy
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
fn WktParser::parse_geometry(self : WktParser) -> Result[Geometry, GeoError] {
  let header = self.current()
  if header.kind != Word {
    return Err(InvalidWkt("expected geometry type", header.offset))
  }
  self.advance()
  let name = header.text
  let dimension = self.take_dimension()
  let is_point = word_matches(name, "POINT")
  let is_line_string = word_matches(name, "LINESTRING")
  let is_polygon = word_matches(name, "POLYGON")
  if !(is_point || is_line_string || is_polygon) {
    if word_matches(name, "MULTIPOINT") ||
      word_matches(name, "MULTILINESTRING") ||
      word_matches(name, "MULTIPOLYGON") ||
      word_matches(name, "GEOMETRYCOLLECTION") {
      return Err(UnsupportedGeometry(name))
    }
    return Err(InvalidWkt("unknown geometry type", header.offset))
  }
  if self.current_is_word("EMPTY") {
    self.advance()
    let geometry = if is_point {
      EmptyPoint
    } else if is_line_string {
      LineString([])
    } else {
      Polygon([])
    }
    return self.finish(geometry)
  }
  let geometry = if is_point {
    match self.parse_point_geometry(dimension) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
  } else if is_line_string {
    match self.parse_line_string_geometry(dimension) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
  } else {
    match self.parse_polygon_geometry(dimension) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
  }
  self.finish(geometry)
}

///|
pub fn parse_wkt(
  source : StringView,
  limits : GeoLimits,
) -> Result[Geometry, GeoError] {
  match limits.check_geometries(1) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  match limits.check_depth(1) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let tokens = match tokenize_wkt(source, limits) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  WktParser::new(tokens, limits).parse_geometry()
}
