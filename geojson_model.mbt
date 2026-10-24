///|
pub(all) struct GeoJsonFeature {
  id : Json?
  geometry : Geometry?
  properties : Json
} derive(Eq)

///|
pub(all) enum GeoJsonObject {
  Geometry(Geometry)
  Feature(GeoJsonFeature)
  FeatureCollection(Array[GeoJsonFeature])
} derive(Eq)

///|
pub extend GeoJsonFeature with Eq::{not_equal, equal}

///|
pub extend GeoJsonObject with Eq::{not_equal, equal}
