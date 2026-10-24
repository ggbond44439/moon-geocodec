///|
pub(all) enum PointLocation {
  Outside
  Boundary
  Inside
} derive(Eq, @debug.Debug)

///|
fn predicate_abs(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn predicate_epsilon(tolerance : Double) -> Double {
  predicate_abs(tolerance)
}

///|
fn predicate_equal_xy(
  left : Coordinate,
  right : Coordinate,
  epsilon : Double,
) -> Bool {
  predicate_abs(left.x - right.x) <= epsilon &&
  predicate_abs(left.y - right.y) <= epsilon
}

///|
fn predicate_cross(
  start : Coordinate,
  first : Coordinate,
  second : Coordinate,
) -> Double {
  (first.x - start.x) * (second.y - start.y) -
  (first.y - start.y) * (second.x - start.x)
}

///|
fn predicate_between(
  value : Double,
  low : Double,
  high : Double,
  epsilon : Double,
) -> Bool {
  let min_value = if low < high { low } else { high }
  let max_value = if low > high { low } else { high }
  value >= min_value - epsilon && value <= max_value + epsilon
}

///|
fn predicate_point_on_segment(
  point : Coordinate,
  start : Coordinate,
  end : Coordinate,
  epsilon : Double,
) -> Bool {
  if predicate_abs(predicate_cross(start, end, point)) > epsilon {
    return false
  }
  predicate_between(point.x, start.x, end.x, epsilon) &&
  predicate_between(point.y, start.y, end.y, epsilon)
}

///|
fn predicate_ring_location(
  point : Coordinate,
  ring : Array[Coordinate],
  epsilon : Double,
) -> PointLocation {
  let mut inside = false
  let end = ring.length() - 1
  for index in 0..<end {
    let start = ring[index]
    let finish = ring[index + 1]
    if predicate_point_on_segment(point, start, finish, epsilon) {
      return PointLocation::Boundary
    }
    let crosses = (start.y > point.y) != (finish.y > point.y)
    if crosses {
      let intersection_x = start.x +
        (point.y - start.y) * (finish.x - start.x) / (finish.y - start.y)
      if point.x < intersection_x {
        inside = !inside
      }
    }
  }
  if inside {
    PointLocation::Inside
  } else {
    PointLocation::Outside
  }
}

///|
fn predicate_line_location(
  point : Coordinate,
  line : Array[Coordinate],
  epsilon : Double,
) -> PointLocation {
  if line.length() == 0 {
    return PointLocation::Outside
  }
  let closed = predicate_equal_xy(line[0], line[line.length() - 1], epsilon)
  let end = line.length() - 1
  let mut boundary = false
  for index in 0..<end {
    let start = line[index]
    let finish = line[index + 1]
    if predicate_point_on_segment(point, start, finish, epsilon) {
      if closed {
        return PointLocation::Inside
      }
      if predicate_equal_xy(point, start, epsilon) ||
        predicate_equal_xy(point, finish, epsilon) {
        boundary = true
      } else {
        return PointLocation::Inside
      }
    }
  }
  if boundary {
    PointLocation::Boundary
  } else {
    PointLocation::Outside
  }
}

///|
fn predicate_polygon_location(
  point : Coordinate,
  rings : Array[Array[Coordinate]],
  epsilon : Double,
) -> PointLocation {
  if rings.length() == 0 {
    return PointLocation::Outside
  }
  match predicate_ring_location(point, rings[0], epsilon) {
    PointLocation::Outside => PointLocation::Outside
    PointLocation::Boundary => PointLocation::Boundary
    PointLocation::Inside => {
      for index in 1..<rings.length() {
        match predicate_ring_location(point, rings[index], epsilon) {
          PointLocation::Inside => return PointLocation::Outside
          PointLocation::Boundary => return PointLocation::Boundary
          PointLocation::Outside => ()
        }
      }
      PointLocation::Inside
    }
  }
}

///|
fn predicate_merge_location(
  current : PointLocation,
  next : PointLocation,
) -> PointLocation {
  if current == PointLocation::Inside || next == PointLocation::Inside {
    PointLocation::Inside
  } else if current == PointLocation::Boundary ||
    next == PointLocation::Boundary {
    PointLocation::Boundary
  } else {
    PointLocation::Outside
  }
}

///|
fn predicate_geometry_location(
  geometry : Geometry,
  point : Coordinate,
  epsilon : Double,
) -> PointLocation {
  match geometry {
    Point(coordinate) =>
      if predicate_equal_xy(point, coordinate, epsilon) {
        PointLocation::Inside
      } else {
        PointLocation::Outside
      }
    EmptyPoint => PointLocation::Outside
    LineString(line) => predicate_line_location(point, line, epsilon)
    Polygon(rings) => predicate_polygon_location(point, rings, epsilon)
    MultiPoint(points) => {
      let mut result = PointLocation::Outside
      for coordinate in points {
        if predicate_equal_xy(point, coordinate, epsilon) {
          result = PointLocation::Inside
          break
        }
      }
      result
    }
    MultiLineString(lines) => {
      let mut result = PointLocation::Outside
      for line in lines {
        result = predicate_merge_location(
          result,
          predicate_line_location(point, line, epsilon),
        )
      }
      result
    }
    MultiPolygon(polygons) => {
      let mut result = PointLocation::Outside
      for polygon in polygons {
        result = predicate_merge_location(
          result,
          predicate_polygon_location(point, polygon, epsilon),
        )
      }
      result
    }
    GeometryCollection(geometries) => {
      let mut result = PointLocation::Outside
      for child in geometries {
        result = predicate_merge_location(
          result,
          predicate_geometry_location(child, point, epsilon),
        )
      }
      result
    }
  }
}

///|
pub fn Geometry::locate_point(
  self : Geometry,
  point : Coordinate,
  tolerance~ : Double = 1.0e-12,
) -> PointLocation {
  predicate_geometry_location(self, point, predicate_epsilon(tolerance))
}

///|
pub fn Geometry::contains_point(
  self : Geometry,
  point : Coordinate,
  tolerance~ : Double = 1.0e-12,
) -> Bool {
  self.locate_point(point, tolerance~) == PointLocation::Inside
}

///|
pub fn Geometry::covers_point(
  self : Geometry,
  point : Coordinate,
  tolerance~ : Double = 1.0e-12,
) -> Bool {
  let location = self.locate_point(point, tolerance~)
  location == PointLocation::Inside || location == PointLocation::Boundary
}

///|
pub fn BoundingBox::contains_xy(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> Bool {
  x >= self.min_x && x <= self.max_x && y >= self.min_y && y <= self.max_y
}

///|
pub fn BoundingBox::intersects(self : BoundingBox, other : BoundingBox) -> Bool {
  self.min_x <= other.max_x &&
  self.max_x >= other.min_x &&
  self.min_y <= other.max_y &&
  self.max_y >= other.min_y
}

///|
pub fn BoundingBox3D::intersects(
  self : BoundingBox3D,
  other : BoundingBox3D,
) -> Bool {
  self.min_x <= other.max_x &&
  self.max_x >= other.min_x &&
  self.min_y <= other.max_y &&
  self.max_y >= other.min_y &&
  self.min_z <= other.max_z &&
  self.max_z >= other.min_z
}

///|
pub extend PointLocation with Eq::{not_equal, equal}

///|
pub extend PointLocation with @debug.Debug::{to_repr}
