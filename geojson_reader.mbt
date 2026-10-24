///|
priv struct GeoJsonParser {
  limits : GeoLimits
  mut coordinate_count : Int32
  mut geometry_count : Int32
}

///|
fn GeoJsonParser::new(limits : GeoLimits) -> GeoJsonParser {
  { limits, coordinate_count: 0, geometry_count: 0, }
}

///|
fn GeoJsonParser::begin_geometry(
  self : GeoJsonParser,
  depth : Int32,
) -> Result[Unit, GeoError] {
  match self.limits.check_depth(depth) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  self.geometry_count += 1
  self.limits.check_geometries(self.geometry_count)
}

///|
fn GeoJsonParser::record_coordinate(
  self : GeoJsonParser,
) -> Result[Unit, GeoError] {
  self.coordinate_count += 1
  self.limits.check_coordinates(self.coordinate_count)
}

///|
fn geojson_error(message : String) -> GeoError {
  InvalidGeoJson(message, 0)
}

///|
fn geojson_field(
  object : Map[String, Json],
  key : String,
  context : String,
) -> Result[Json, GeoError] {
  match object.get(key) {
    Some(value) => Ok(value)
    None => Err(geojson_error(context + " is missing '" + key + "'"))
  }
}

///|
fn geojson_object(
  value : Json,
  context : String,
) -> Result[Map[String, Json], GeoError] {
  match value {
    Object(object) => Ok(object)
    _ => Err(geojson_error(context + " must be an object"))
  }
}

///|
fn geojson_array(
  value : Json,
  context : String,
) -> Result[Array[Json], GeoError] {
  match value {
    Array(values) => Ok(values)
    _ => Err(geojson_error(context + " must be an array"))
  }
}

///|
fn geojson_string(value : Json, context : String) -> Result[String, GeoError] {
  match value {
    String(text) => Ok(text)
    _ => Err(geojson_error(context + " must be a string"))
  }
}

///|
fn geojson_number(value : Json, context : String) -> Result[Double, GeoError] {
  match value {
    Number(number, ..) =>
      if number.is_nan() || number.is_inf() {
        Err(geojson_error(context + " must be finite"))
      } else {
        Ok(number)
      }
    _ => Err(geojson_error(context + " must be a number"))
  }
}

///|
fn geojson_type(object : Map[String, Json]) -> Result[String, GeoError] {
  let value = match object.get("type") {
    Some(value) => value
    None => return Err(geojson_error("GeoJSON object is missing 'type'"))
  }
  geojson_string(value, "GeoJSON 'type'")
}

///|
fn validate_geojson_dimensions(geometry : Geometry) -> Result[Unit, GeoError] {
  match geometry_dimension_summary(geometry) {
    Mixed => Err(geojson_error("inconsistent coordinate dimensions"))
    _ => Ok(())
  }
}

///|
fn GeoJsonParser::parse_position(
  self : GeoJsonParser,
  value : Json,
  context : String,
) -> Result[Coordinate, GeoError] {
  let values = match geojson_array(value, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let coordinate = if values.length() == 2 {
    let x = match geojson_number(values[0], context + "[0]") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let y = match geojson_number(values[1], context + "[1]") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    Coordinate::xy(x, y)
  } else if values.length() == 3 {
    let x = match geojson_number(values[0], context + "[0]") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let y = match geojson_number(values[1], context + "[1]") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let z = match geojson_number(values[2], context + "[2]") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    Coordinate::xyz(x, y, z)
  } else {
    return Err(geojson_error(context + " must contain two or three ordinates"))
  }
  match self.record_coordinate() {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(coordinate)
}

///|
fn GeoJsonParser::parse_positions(
  self : GeoJsonParser,
  value : Json,
  context : String,
) -> Result[Array[Coordinate], GeoError] {
  let values = match geojson_array(value, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let coordinates : Array[Coordinate] = []
  for index, position in values {
    let coordinate = match
      self.parse_position(position, context + "[" + index.to_string() + "]") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    coordinates.push(coordinate)
  }
  Ok(coordinates)
}

///|
fn GeoJsonParser::parse_rings(
  self : GeoJsonParser,
  value : Json,
  context : String,
) -> Result[Array[Array[Coordinate]], GeoError] {
  let values = match geojson_array(value, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let rings : Array[Array[Coordinate]] = []
  for index, ring_value in values {
    let ring = match
      self.parse_positions(ring_value, context + "[" + index.to_string() + "]") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if ring.length() == 0 {
      return Err(geojson_error("polygon ring must not be empty"))
    }
    rings.push(ring)
  }
  Ok(rings)
}

///|
fn GeoJsonParser::parse_lines(
  self : GeoJsonParser,
  value : Json,
  context : String,
) -> Result[Array[Array[Coordinate]], GeoError] {
  let values = match geojson_array(value, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let lines : Array[Array[Coordinate]] = []
  for index, line_value in values {
    let line = match
      self.parse_positions(line_value, context + "[" + index.to_string() + "]") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if line.length() == 0 {
      return Err(geojson_error("multiline component must not be empty"))
    }
    lines.push(line)
  }
  Ok(lines)
}

///|
fn GeoJsonParser::parse_polygons(
  self : GeoJsonParser,
  value : Json,
  context : String,
) -> Result[Array[Array[Array[Coordinate]]], GeoError] {
  let values = match geojson_array(value, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let polygons : Array[Array[Array[Coordinate]]] = []
  for index, polygon_value in values {
    let polygon = match
      self.parse_rings(polygon_value, context + "[" + index.to_string() + "]") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if polygon.length() == 0 {
      return Err(geojson_error("multipolygon component must not be empty"))
    }
    polygons.push(polygon)
  }
  Ok(polygons)
}

///|
fn GeoJsonParser::parse_point(
  self : GeoJsonParser,
  coordinates : Json,
) -> Result[Geometry, GeoError] {
  let values = match geojson_array(coordinates, "Point.coordinates") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if values.length() == 0 {
    return Ok(EmptyPoint)
  }
  let coordinate = match self.parse_position(coordinates, "Point.coordinates") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(Point(coordinate))
}

///|
fn GeoJsonParser::parse_geometry_object(
  self : GeoJsonParser,
  value : Json,
  depth : Int32,
) -> Result[Geometry, GeoError] {
  let object = match geojson_object(value, "geometry") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let kind = match geojson_type(object) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match self.begin_geometry(depth) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let geometry = if kind == "Point" {
    let coordinates = match geojson_field(object, "coordinates", "Point") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    self.parse_point(coordinates)
  } else if kind == "LineString" {
    let coordinates = match geojson_field(object, "coordinates", "LineString") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    match self.parse_positions(coordinates, "LineString.coordinates") {
      Ok(value) => Ok(LineString(value))
      Err(err) => Err(err)
    }
  } else if kind == "Polygon" {
    let coordinates = match geojson_field(object, "coordinates", "Polygon") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    match self.parse_rings(coordinates, "Polygon.coordinates") {
      Ok(value) => Ok(Polygon(value))
      Err(err) => Err(err)
    }
  } else if kind == "MultiPoint" {
    let coordinates = match geojson_field(object, "coordinates", "MultiPoint") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    match self.parse_positions(coordinates, "MultiPoint.coordinates") {
      Ok(value) => Ok(MultiPoint(value))
      Err(err) => Err(err)
    }
  } else if kind == "MultiLineString" {
    let coordinates = match
      geojson_field(object, "coordinates", "MultiLineString") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    match self.parse_lines(coordinates, "MultiLineString.coordinates") {
      Ok(value) => Ok(MultiLineString(value))
      Err(err) => Err(err)
    }
  } else if kind == "MultiPolygon" {
    let coordinates = match
      geojson_field(object, "coordinates", "MultiPolygon") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    match self.parse_polygons(coordinates, "MultiPolygon.coordinates") {
      Ok(value) => Ok(MultiPolygon(value))
      Err(err) => Err(err)
    }
  } else if kind == "GeometryCollection" {
    let geometries = match
      geojson_field(object, "geometries", "GeometryCollection") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let values = match
      geojson_array(geometries, "GeometryCollection.geometries") {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let children : Array[Geometry] = []
    for child in values {
      let geometry = match self.parse_geometry_object(child, depth + 1) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      children.push(geometry)
    }
    Ok(GeometryCollection(children))
  } else {
    Err(geojson_error("unsupported GeoJSON type '" + kind + "'"))
  }
  let geometry = match geometry {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if kind == "GeometryCollection" {
    Ok(geometry)
  } else {
    match validate_geojson_dimensions(geometry) {
      Ok(_) => Ok(geometry)
      Err(err) => Err(err)
    }
  }
}

///|
fn GeoJsonParser::parse_feature(
  self : GeoJsonParser,
  feature : Json,
  depth : Int32,
) -> Result[GeoJsonFeature, GeoError] {
  let object = match geojson_object(feature, "Feature") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let kind = match geojson_type(object) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if kind != "Feature" {
    return Err(geojson_error("expected a GeoJSON Feature"))
  }
  let geometry = match geojson_field(object, "geometry", "Feature") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let parsed_geometry = match geometry {
    Null => None
    _ => {
      let parsed = match self.parse_geometry_object(geometry, depth) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      Some(parsed)
    }
  }
  let properties = match object.get("properties") {
    Some(value) =>
      match value {
        Object(_) => value
        Null => Json::null()
        _ =>
          return Err(
            geojson_error("Feature.properties must be an object or null"),
          )
      }
    None => Json::null()
  }
  Ok({ id: object.get("id"), geometry: parsed_geometry, properties, })
}

///|
fn GeoJsonParser::parse_feature_collection_features(
  self : GeoJsonParser,
  value : Json,
  depth : Int32,
) -> Result[Array[GeoJsonFeature], GeoError] {
  let object = match geojson_object(value, "FeatureCollection") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match self.begin_geometry(depth) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let features = match geojson_field(object, "features", "FeatureCollection") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let values = match geojson_array(features, "FeatureCollection.features") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let parsed_features : Array[GeoJsonFeature] = []
  for feature in values {
    let parsed = match self.parse_feature(feature, depth + 1) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    parsed_features.push(parsed)
  }
  Ok(parsed_features)
}

///|
pub fn parse_geojson_object(
  source : StringView,
  limits : GeoLimits,
) -> Result[GeoJsonObject, GeoError] {
  match limits.check_text(source.length()) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let value = @json.parse(source) catch {
    err => return Err(geojson_error("invalid JSON: " + err.to_string()))
  }
  let object = match geojson_object(value, "GeoJSON root") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let kind = match geojson_type(object) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let parser = GeoJsonParser::new(limits)
  if kind == "Feature" {
    match parser.parse_feature(value, 1) {
      Ok(feature) => Ok(Feature(feature))
      Err(err) => Err(err)
    }
  } else if kind == "FeatureCollection" {
    match parser.parse_feature_collection_features(value, 1) {
      Ok(features) => Ok(FeatureCollection(features))
      Err(err) => Err(err)
    }
  } else {
    match parser.parse_geometry_object(value, 1) {
      Ok(geometry) => Ok(Geometry(geometry))
      Err(err) => Err(err)
    }
  }
}

///|
pub fn parse_geojson(
  source : StringView,
  limits : GeoLimits,
) -> Result[Geometry, GeoError] {
  let object = match parse_geojson_object(source, limits) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match object {
    Geometry(geometry) => Ok(geometry)
    Feature(feature) =>
      match feature.geometry {
        Some(geometry) => Ok(geometry)
        None => Ok(GeometryCollection([]))
      }
    FeatureCollection(features) => {
      let geometries : Array[Geometry] = []
      for feature in features {
        match feature.geometry {
          Some(geometry) => geometries.push(geometry)
          None => ()
        }
      }
      Ok(GeometryCollection(geometries))
    }
  }
}
