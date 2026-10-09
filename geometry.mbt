///|
/// Coordinate dimensionality supported by geometry interchange formats.
pub(all) enum CoordinateDimension {
  Xy
  Xyz
  Xym
  Xyzm
} derive(Eq, @debug.Debug)

///|
/// A coordinate with optional Z and M ordinates.
pub(all) struct Coordinate {
  x : Double
  y : Double
  z : Double?
  m : Double?
} derive(Eq, @debug.Debug)

///|
pub fn Coordinate::xy(x : Double, y : Double) -> Coordinate {
  { x, y, z: None, m: None, }
}

///|
pub fn Coordinate::xyz(x : Double, y : Double, z : Double) -> Coordinate {
  { x, y, z: Some(z), m: None, }
}

///|
pub fn Coordinate::xym(x : Double, y : Double, m : Double) -> Coordinate {
  { x, y, z: None, m: Some(m), }
}

///|
pub fn Coordinate::xyzm(
  x : Double,
  y : Double,
  z : Double,
  m : Double,
) -> Coordinate {
  { x, y, z: Some(z), m: Some(m), }
}

///|
pub fn Coordinate::dimension(self : Coordinate) -> CoordinateDimension {
  match (self.z, self.m) {
    (None, None) => Xy
    (Some(_), None) => Xyz
    (None, Some(_)) => Xym
    (Some(_), Some(_)) => Xyzm
  }
}

///|
pub fn Coordinate::has_z(self : Coordinate) -> Bool {
  match self.z {
    Some(_) => true
    None => false
  }
}

///|
pub fn Coordinate::has_m(self : Coordinate) -> Bool {
  match self.m {
    Some(_) => true
    None => false
  }
}

///|
pub(all) enum GeometryKind {
  Point
  LineString
  Polygon
  MultiPoint
  MultiLineString
  MultiPolygon
  GeometryCollection
} derive(Eq, @debug.Debug)

///|
/// A closed coordinate bounds box. Empty geometries have no bounds.
pub(all) struct BoundingBox {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
} derive(Eq, @debug.Debug)

///|
pub fn BoundingBox::width(self : BoundingBox) -> Double {
  self.max_x - self.min_x
}

///|
pub fn BoundingBox::height(self : BoundingBox) -> Double {
  self.max_y - self.min_y
}

///|
/// Typed geometry model independent of text and binary encodings.
pub(all) enum Geometry {
  Point(Coordinate)
  LineString(Array[Coordinate])
  Polygon(Array[Array[Coordinate]])
  MultiPoint(Array[Coordinate])
  MultiLineString(Array[Array[Coordinate]])
  MultiPolygon(Array[Array[Array[Coordinate]]])
  GeometryCollection(Array[Geometry])
} derive(Eq, @debug.Debug)

///|
pub fn Geometry::kind(self : Geometry) -> GeometryKind {
  match self {
    Point(_) => Point
    LineString(_) => LineString
    Polygon(_) => Polygon
    MultiPoint(_) => MultiPoint
    MultiLineString(_) => MultiLineString
    MultiPolygon(_) => MultiPolygon
    GeometryCollection(_) => GeometryCollection
  }
}

///|
pub fn Geometry::coordinate_count(self : Geometry) -> Int {
  match self {
    Point(_) => 1
    LineString(points) => points.length()
    Polygon(rings) => coordinate_count_rings(rings)
    MultiPoint(points) => points.length()
    MultiLineString(lines) => coordinate_count_lines(lines)
    MultiPolygon(polygons) => coordinate_count_polygons(polygons)
    GeometryCollection(geometries) => {
      let mut count = 0
      for geometry in geometries {
        count += geometry.coordinate_count()
      }
      count
    }
  }
}

///|
fn coordinate_count_rings(rings : Array[Array[Coordinate]]) -> Int {
  let mut count = 0
  for ring in rings {
    count += ring.length()
  }
  count
}

///|
fn coordinate_count_lines(lines : Array[Array[Coordinate]]) -> Int {
  coordinate_count_rings(lines)
}

///|
fn coordinate_count_polygons(polygons : Array[Array[Array[Coordinate]]]) -> Int {
  let mut count = 0
  for polygon in polygons {
    count += coordinate_count_rings(polygon)
  }
  count
}

///|
pub fn Geometry::is_empty(self : Geometry) -> Bool {
  self.coordinate_count() == 0
}

///|
pub fn Geometry::bounds(self : Geometry) -> BoundingBox? {
  match self {
    Point(coordinate) => Some(point_bounds(coordinate))
    LineString(points) => bounds_from_coordinates(points)
    Polygon(rings) => bounds_from_rings(rings)
    MultiPoint(points) => bounds_from_coordinates(points)
    MultiLineString(lines) => bounds_from_lines(lines)
    MultiPolygon(polygons) => bounds_from_polygons(polygons)
    GeometryCollection(geometries) => {
      let mut result : BoundingBox? = None
      for geometry in geometries {
        result = merge_bounds(result, geometry.bounds())
      }
      result
    }
  }
}

///|
fn point_bounds(coordinate : Coordinate) -> BoundingBox {
  {
    min_x: coordinate.x,
    min_y: coordinate.y,
    max_x: coordinate.x,
    max_y: coordinate.y,
  }
}

///|
fn extend_bounds(bounds : BoundingBox, coordinate : Coordinate) -> BoundingBox {
  {
    min_x: if coordinate.x < bounds.min_x {
      coordinate.x
    } else {
      bounds.min_x
    },
    min_y: if coordinate.y < bounds.min_y {
      coordinate.y
    } else {
      bounds.min_y
    },
    max_x: if coordinate.x > bounds.max_x {
      coordinate.x
    } else {
      bounds.max_x
    },
    max_y: if coordinate.y > bounds.max_y {
      coordinate.y
    } else {
      bounds.max_y
    },
  }
}

///|
fn bounds_from_coordinates(coordinates : Array[Coordinate]) -> BoundingBox? {
  let mut result : BoundingBox? = None
  for coordinate in coordinates {
    result = match result {
      Some(current) => Some(extend_bounds(current, coordinate))
      None => Some(point_bounds(coordinate))
    }
  }
  result
}

///|
fn bounds_from_rings(rings : Array[Array[Coordinate]]) -> BoundingBox? {
  let mut result : BoundingBox? = None
  for ring in rings {
    result = merge_bounds(result, bounds_from_coordinates(ring))
  }
  result
}

///|
fn bounds_from_lines(lines : Array[Array[Coordinate]]) -> BoundingBox? {
  bounds_from_rings(lines)
}

///|
fn bounds_from_polygons(
  polygons : Array[Array[Array[Coordinate]]],
) -> BoundingBox? {
  let mut result : BoundingBox? = None
  for polygon in polygons {
    result = merge_bounds(result, bounds_from_rings(polygon))
  }
  result
}

///|
fn merge_bounds(left : BoundingBox?, right : BoundingBox?) -> BoundingBox? {
  match (left, right) {
    (None, None) => None
    (Some(value), None) => Some(value)
    (None, Some(value)) => Some(value)
    (Some(a), Some(b)) =>
      Some({
        min_x: if a.min_x < b.min_x {
          a.min_x
        } else {
          b.min_x
        },
        min_y: if a.min_y < b.min_y {
          a.min_y
        } else {
          b.min_y
        },
        max_x: if a.max_x > b.max_x {
          a.max_x
        } else {
          b.max_x
        },
        max_y: if a.max_y > b.max_y {
          a.max_y
        } else {
          b.max_y
        },
      })
  }
}

///|
pub extend CoordinateDimension with Eq::{not_equal, equal}

///|
pub extend CoordinateDimension with @debug.Debug::{to_repr}

///|
pub extend Coordinate with Eq::{not_equal, equal}

///|
pub extend Coordinate with @debug.Debug::{to_repr}

///|
pub extend GeometryKind with Eq::{not_equal, equal}

///|
pub extend GeometryKind with @debug.Debug::{to_repr}

///|
pub extend BoundingBox with Eq::{not_equal, equal}

///|
pub extend BoundingBox with @debug.Debug::{to_repr}

///|
pub extend Geometry with Eq::{not_equal, equal}

///|
pub extend Geometry with @debug.Debug::{to_repr}
