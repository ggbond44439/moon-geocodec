///|
/// Resource limits shared by all MoonGeoCodec parsers.
pub(all) struct GeoLimits {
  max_text_bytes : Int32
  max_depth : Int32
  max_geometries : Int32
  max_coordinates : Int32
  max_tokens : Int32
} derive(Eq, @debug.Debug)

///|
pub fn GeoLimits::default() -> GeoLimits {
  {
    max_text_bytes: 1048576,
    max_depth: 256,
    max_geometries: 100000,
    max_coordinates: 1000000,
    max_tokens: 2000000,
  }
}

///|
pub fn GeoLimits::new(
  max_text_bytes : Int32,
  max_depth : Int32,
  max_geometries : Int32,
  max_coordinates : Int32,
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
  Ok({
    max_text_bytes,
    max_depth,
    max_geometries,
    max_coordinates,
    max_tokens: 2000000,
  })
}

///|
pub fn GeoLimits::with_token_limit(
  self : GeoLimits,
  max_tokens : Int32,
) -> Result[GeoLimits, GeoError] {
  if max_tokens <= 0 {
    return Err(InvalidLimit("max_tokens", max_tokens))
  }
  Ok({
    max_text_bytes: self.max_text_bytes,
    max_depth: self.max_depth,
    max_geometries: self.max_geometries,
    max_coordinates: self.max_coordinates,
    max_tokens,
  })
}

///|
pub fn GeoLimits::check_text(
  self : GeoLimits,
  actual : Int32,
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
  actual : Int32,
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
  actual : Int32,
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
  actual : Int32,
) -> Result[Unit, GeoError] {
  if actual > self.max_coordinates {
    Err(LimitExceeded("coordinate count", self.max_coordinates, actual))
  } else {
    Ok(())
  }
}

///|
pub fn GeoLimits::check_tokens(
  self : GeoLimits,
  actual : Int32,
) -> Result[Unit, GeoError] {
  if actual > self.max_tokens {
    Err(LimitExceeded("token count", self.max_tokens, actual))
  } else {
    Ok(())
  }
}

///|
pub extend GeoLimits with Eq::{not_equal, equal}

///|
pub extend GeoLimits with @debug.Debug::{to_repr}
