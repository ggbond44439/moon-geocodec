///|
/// Typed failures produced by MoonGeoCodec parsers and validators.
pub(all) enum GeoError {
  InvalidWkt(String, Int32)
  InvalidWkb(String, Int32)
  InvalidGeoJson(String, Int32)
  InvalidCoordinate(String)
  InvalidBoundary(String, Int32)
  UnsupportedGeometry(String)
  InvalidLimit(String, Int32)
  LimitExceeded(String, Int32, Int32)
  Truncated(String, Int32)
  TrailingBytes(Int32)
  InvalidSrid(Int32)
} derive(Eq, @debug.Debug)

///|
pub impl Show for GeoError with fn output(self, logger) {
  match self {
    InvalidWkt(message, offset) =>
      logger.write_string(
        "invalid WKT at offset " + offset.to_string() + ": " + message,
      )
    InvalidWkb(message, offset) =>
      logger.write_string(
        "invalid WKB at offset " + offset.to_string() + ": " + message,
      )
    InvalidGeoJson(message, offset) =>
      logger.write_string(
        "invalid GeoJSON at offset " + offset.to_string() + ": " + message,
      )
    InvalidCoordinate(message) =>
      logger.write_string("invalid coordinate: " + message)
    InvalidBoundary(message, index) =>
      logger.write_string(
        "invalid boundary at index " + index.to_string() + ": " + message,
      )
    UnsupportedGeometry(name) =>
      logger.write_string("unsupported geometry: " + name)
    InvalidLimit(name, value) =>
      logger.write_string("invalid limit " + name + ": " + value.to_string())
    LimitExceeded(name, maximum, actual) =>
      logger.write_string(
        name +
        " exceeds limit: maximum=" +
        maximum.to_string() +
        " actual=" +
        actual.to_string(),
      )
    Truncated(name, offset) =>
      logger.write_string(
        "truncated " + name + " at offset " + offset.to_string(),
      )
    TrailingBytes(offset) =>
      logger.write_string("trailing bytes at offset " + offset.to_string())
    InvalidSrid(value) =>
      logger.write_string("invalid SRID: " + value.to_string())
  }
}

///|
pub extend GeoError with Eq::{not_equal, equal}

///|
pub extend GeoError with @debug.Debug::{to_repr}

///|
pub extend GeoError with Show::{to_string, output}
