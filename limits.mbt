///|
/// Resource limits shared by all MoonGeoCodec parsers.
pub(all) struct GeoLimits {
  max_text_bytes : Int
  max_depth : Int
  max_geometries : Int
  max_coordinates : Int
} derive(Eq, @debug.Debug)

///|
pub fn GeoLimits::default() -> GeoLimits {
  {
    max_text_bytes: 1048576,
    max_depth: 256,
    max_geometries: 100000,
    max_coordinates: 1000000,
  }
}

///|
pub fn GeoLimits::new(
  max_text_bytes : Int,
  max_depth : Int,
  max_geometries : Int,
  max_coordinates : Int,
) -> Result[GeoLimits, GeoError] {
  if max_text_bytes <= 0 {
    return Err(InvalidLimit("max_text_bytes", max_text_bytes))
  }
  if max_depth <= 0 {
    return Err(InvalidLimit("max_depth", max_depth))
  }
  if max_geometries <= 0 {
    return Err(InvalidLimit("max_geometries", max_geometries))
  }
  if max_coordinates <= 0 {
    return Err(InvalidLimit("max_coordinates", max_coordinates))
  }
  Ok({ max_text_bytes, max_depth, max_geometries, max_coordinates, })
}

///|
pub fn GeoLimits::check_text(
  self : GeoLimits,
  actual : Int,
) -> Result[Unit, GeoError] {
  if actual > self.max_text_bytes {
    Err(LimitExceeded("text bytes", self.max_text_bytes, actual))
  } else {
    Ok(())
  }
}

///|
pub fn GeoLimits::check_depth(
  self : GeoLimits,
  actual : Int,
) -> Result[Unit, GeoError] {
  if actual > self.max_depth {
    Err(LimitExceeded("geometry depth", self.max_depth, actual))
  } else {
    Ok(())
  }
}

///|
pub fn GeoLimits::check_geometries(
  self : GeoLimits,
  actual : Int,
) -> Result[Unit, GeoError] {
  if actual > self.max_geometries {
    Err(LimitExceeded("geometry count", self.max_geometries, actual))
  } else {
    Ok(())
  }
}

///|
pub fn GeoLimits::check_coordinates(
  self : GeoLimits,
  actual : Int,
) -> Result[Unit, GeoError] {
  if actual > self.max_coordinates {
    Err(LimitExceeded("coordinate count", self.max_coordinates, actual))
  } else {
    Ok(())
  }
}

///|
pub extend GeoLimits with Eq::{not_equal, equal}

///|
pub extend GeoLimits with @debug.Debug::{to_repr}
