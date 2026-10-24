///|
priv enum CliFormat {
  Wkt
  Wkt2
  Ewkt
  Wkb
  Ewkb
  GeoJson
}

///|
fn parse_cli_format(name : String) -> Result[CliFormat, String] {
  if name == "wkt" || name == "wkt1" {
    Ok(Wkt)
  } else if name == "wkt2" {
    Ok(Wkt2)
  } else if name == "ewkt" {
    Ok(Ewkt)
  } else if name == "wkb" {
    Ok(Wkb)
  } else if name == "ewkb" {
    Ok(Ewkb)
  } else if name == "geojson" || name == "json" {
    Ok(GeoJson)
  } else {
    Err("unsupported format '" + name + "'")
  }
}

///|
fn cli_format_name(format : CliFormat) -> String {
  match format {
    Wkt => "wkt"
    Wkt2 => "wkt2"
    Ewkt => "ewkt"
    Wkb => "wkb"
    Ewkb => "ewkb"
    GeoJson => "geojson"
  }
}

///|
fn hex_digit(code : Int32) -> Int32? {
  if code >= 48 && code <= 57 {
    Some(code - 48)
  } else if code >= 65 && code <= 70 {
    Some(code - 65 + 10)
  } else if code >= 97 && code <= 102 {
    Some(code - 97 + 10)
  } else {
    None
  }
}

///|
fn decode_hex(input : String) -> Result[Bytes, String] {
  let bytes : Array[Byte] = []
  let mut high = -1
  for character in input.iter() {
    let code = character.to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      continue
    }
    let digit = match hex_digit(code) {
      Some(value) => value
      None => return Err("invalid hexadecimal input")
    }
    if high < 0 {
      high = digit
    } else {
      bytes.push((high * 16 + digit).to_byte())
      high = -1
    }
  }
  if high >= 0 {
    Err("hexadecimal input must have an even number of digits")
  } else {
    Ok(Bytes::from_array(bytes))
  }
}

///|
fn encode_hex(bytes : Bytes) -> String {
  let builder = StringBuilder()
  for byte in bytes {
    builder.write_string(byte.to_hex())
  }
  builder.to_string()
}

///|
fn decode_input(
  format : CliFormat,
  input : String,
) -> Result[@moon_geocodec.SpatialGeometry, String] {
  let limits = @moon_geocodec.GeoLimits::default()
  let geometry = match format {
    Wkt =>
      match @moon_geocodec.parse_wkt(input.view(), limits) {
        Ok(value) => value
        Err(err) => return Err(err.to_string())
      }
    Wkt2 =>
      match @moon_geocodec.parse_wkt2(input.view(), limits) {
        Ok(value) => value
        Err(err) => return Err(err.to_string())
      }
    GeoJson =>
      match @moon_geocodec.parse_geojson(input.view(), limits) {
        Ok(value) => value
        Err(err) => return Err(err.to_string())
      }
    Ewkt =>
      return @moon_geocodec.parse_ewkt(input.view(), limits)
        |> Result::map_err(fn(err) { err.to_string() })
    Wkb => {
      let bytes = match decode_hex(input) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      match @moon_geocodec.parse_wkb(bytes.exact_view(), limits) {
        Ok(value) => value
        Err(err) => return Err(err.to_string())
      }
    }
    Ewkb => {
      let bytes = match decode_hex(input) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      return @moon_geocodec.parse_ewkb(bytes.exact_view(), limits)
        |> Result::map_err(fn(err) { err.to_string() })
    }
  }
  Ok({ srid: None, geometry, })
}

///|
fn encode_output(
  format : CliFormat,
  value : @moon_geocodec.SpatialGeometry,
) -> Result[String, String] {
  match format {
    Wkt =>
      @moon_geocodec.format_wkt(value.geometry)
      |> Result::map_err(fn(err) { err.to_string() })
    Wkt2 =>
      @moon_geocodec.format_wkt2(value.geometry)
      |> Result::map_err(fn(err) { err.to_string() })
    Ewkt =>
      @moon_geocodec.format_ewkt(value)
      |> Result::map_err(fn(err) { err.to_string() })
    Wkb =>
      match @moon_geocodec.format_wkb(value.geometry) {
        Ok(bytes) => Ok(encode_hex(bytes))
        Err(err) => Err(err.to_string())
      }
    Ewkb =>
      match @moon_geocodec.format_ewkb(value) {
        Ok(bytes) => Ok(encode_hex(bytes))
        Err(err) => Err(err.to_string())
      }
    GeoJson =>
      @moon_geocodec.format_geojson(value.geometry)
      |> Result::map_err(fn(err) { err.to_string() })
  }
}

///|
fn dimension_text(dimension : @moon_geocodec.CoordinateDimension) -> String {
  match dimension {
    @moon_geocodec.CoordinateDimension::Xy => "XY"
    @moon_geocodec.CoordinateDimension::Xyz => "XYZ"
    @moon_geocodec.CoordinateDimension::Xym => "XYM"
    @moon_geocodec.CoordinateDimension::Xyzm => "XYZM"
  }
}

///|
fn coordinate_text(coordinate : @moon_geocodec.Coordinate) -> String {
  let base = coordinate.x.to_string() + " " + coordinate.y.to_string()
  match coordinate.z {
    Some(value) => base + " " + value.to_string()
    None => base
  }
}

///|
fn bounds_text(bounds : @moon_geocodec.BoundingBox) -> String {
  bounds.min_x.to_string() +
  " " +
  bounds.min_y.to_string() +
  " " +
  bounds.max_x.to_string() +
  " " +
  bounds.max_y.to_string()
}

///|
fn bounds_3d_text(bounds : @moon_geocodec.BoundingBox3D) -> String {
  bounds.min_x.to_string() +
  " " +
  bounds.min_y.to_string() +
  " " +
  bounds.min_z.to_string() +
  " " +
  bounds.max_x.to_string() +
  " " +
  bounds.max_y.to_string() +
  " " +
  bounds.max_z.to_string()
}

///|
fn geometry_kind_text(kind : @moon_geocodec.GeometryKind) -> String {
  match kind {
    @moon_geocodec.GeometryKind::Point => "Point"
    @moon_geocodec.GeometryKind::LineString => "LineString"
    @moon_geocodec.GeometryKind::Polygon => "Polygon"
    @moon_geocodec.GeometryKind::MultiPoint => "MultiPoint"
    @moon_geocodec.GeometryKind::MultiLineString => "MultiLineString"
    @moon_geocodec.GeometryKind::MultiPolygon => "MultiPolygon"
    @moon_geocodec.GeometryKind::GeometryCollection => "GeometryCollection"
  }
}

///|
fn inspect_text(
  format : CliFormat,
  value : @moon_geocodec.SpatialGeometry,
) -> String {
  let builder = StringBuilder()
  builder.write_string("format: " + cli_format_name(format))
  builder.write_string("\nkind: " + geometry_kind_text(value.geometry.kind()))
  let dimension = if value.geometry.is_empty() {
    "empty"
  } else {
    match value.geometry.dimension() {
      Some(value) => dimension_text(value)
      None => "mixed"
    }
  }
  builder.write_string("\ndimension: " + dimension)
  builder.write_string(
    "\ncoordinates: " + value.geometry.coordinate_count().to_string(),
  )
  builder.write_string("\nempty: " + value.geometry.is_empty().to_string())
  match value.srid {
    Some(srid) => builder.write_string("\nsrid: " + srid.to_string())
    None => ()
  }
  match value.geometry.bounds() {
    Some(bounds) => builder.write_string("\nbounds2d: " + bounds_text(bounds))
    None => ()
  }
  match value.geometry.bounds_3d() {
    Some(bounds) => {
      builder.write_string("\nbounds3d: " + bounds_3d_text(bounds))
      builder.write_string(
        "\nextent3d: " +
        bounds.width().to_string() +
        " " +
        bounds.height().to_string() +
        " " +
        bounds.depth().to_string(),
      )
    }
    None => ()
  }
  match value.geometry.centroid() {
    Some(centroid) =>
      builder.write_string("\ncentroid: " + coordinate_text(centroid))
    None => ()
  }
  builder.write_string("\nlength: " + value.geometry.length().to_string())
  builder.write_string("\narea: " + value.geometry.area().to_string())
  match @moon_geocodec.validate_geometry(value.geometry) {
    Ok(_) => builder.write_string("\nvalid: true")
    Err(err) =>
      builder.write_string("\nvalid: false\nvalidation: " + err.to_string())
  }
  match @moon_geocodec.validate_geometry_topology(value.geometry) {
    Ok(_) => builder.write_string("\ntopology: true")
    Err(err) =>
      builder.write_string(
        "\ntopology: false\ntopology_error: " + err.to_string(),
      )
  }
  builder.to_string()
}

///|
fn usage() -> String {
  "MoonGeoCodec " +
  @moon_geocodec.VERSION +
  "\n\n" +
  "Usage:\n" +
  "  moon-geocodec inspect <format> <input>\n" +
  "  moon-geocodec validate <format> <input>\n" +
  "  moon-geocodec validate-topology <format> <input>\n" +
  "  moon-geocodec convert <from> <to> <input>\n" +
  "\nFormats: wkt, wkt2, ewkt, wkb, ewkb, geojson\n" +
  "WKB and EWKB inputs/outputs use hexadecimal strings."
}

///|
pub fn execute_cli(args : Array[String]) -> Result[String, String] {
  if args.length() == 0 || args[0] == "help" || args[0] == "--help" {
    return Ok(usage())
  }
  if args[0] == "version" || args[0] == "--version" {
    return Ok(@moon_geocodec.VERSION)
  }
  if args[0] == "inspect" {
    if args.length() != 3 {
      return Err("usage: moon-geocodec inspect <format> <input>")
    }
    let format = match parse_cli_format(args[1]) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let value = match decode_input(format, args[2]) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    Ok(inspect_text(format, value))
  } else if args[0] == "validate" {
    if args.length() != 3 {
      return Err("usage: moon-geocodec validate <format> <input>")
    }
    let format = match parse_cli_format(args[1]) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let value = match decode_input(format, args[2]) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    match @moon_geocodec.validate_geometry(value.geometry) {
      Ok(_) => Ok("valid")
      Err(err) => Err(err.to_string())
    }
  } else if args[0] == "validate-topology" {
    if args.length() != 3 {
      return Err("usage: moon-geocodec validate-topology <format> <input>")
    }
    let format = match parse_cli_format(args[1]) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let value = match decode_input(format, args[2]) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    match @moon_geocodec.validate_geometry_topology(value.geometry) {
      Ok(_) => Ok("valid")
      Err(err) => Err(err.to_string())
    }
  } else if args[0] == "convert" {
    if args.length() != 4 {
      return Err("usage: moon-geocodec convert <from> <to> <input>")
    }
    let source_format = match parse_cli_format(args[1]) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let target_format = match parse_cli_format(args[2]) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let value = match decode_input(source_format, args[3]) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    encode_output(target_format, value)
  } else {
    Err("unknown command '" + args[0] + "'\n\n" + usage())
  }
}
