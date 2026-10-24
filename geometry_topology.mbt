///|
let topology_epsilon : Double = 1.0e-12

///|
priv enum RingLocation {
  Outside
  Inside
  Boundary
} derive(Eq)

///|
fn topology_abs(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn topology_equal_xy(left : Coordinate, right : Coordinate) -> Bool {
  topology_abs(left.x - right.x) <= topology_epsilon &&
  topology_abs(left.y - right.y) <= topology_epsilon
}

///|
fn topology_cross(
  start : Coordinate,
  first : Coordinate,
  second : Coordinate,
) -> Double {
  (first.x - start.x) * (second.y - start.y) -
  (first.y - start.y) * (second.x - start.x)
}

///|
fn topology_between(value : Double, low : Double, high : Double) -> Bool {
  value >= (if low < high { low } else { high }) - topology_epsilon &&
  value <= (if low > high { low } else { high }) + topology_epsilon
}

///|
fn topology_point_on_segment(
  point : Coordinate,
  start : Coordinate,
  end : Coordinate,
) -> Bool {
  if topology_abs(topology_cross(start, end, point)) > topology_epsilon {
    return false
  }
  topology_between(point.x, start.x, end.x) &&
  topology_between(point.y, start.y, end.y)
}

///|
fn topology_segments_intersect(
  a : Coordinate,
  b : Coordinate,
  c : Coordinate,
  d : Coordinate,
) -> Bool {
  let o1 = topology_cross(a, b, c)
  let o2 = topology_cross(a, b, d)
  let o3 = topology_cross(c, d, a)
  let o4 = topology_cross(c, d, b)
  if (
      (o1 > topology_epsilon && o2 < -topology_epsilon) ||
      (o1 < -topology_epsilon && o2 > topology_epsilon)
    ) &&
    (
      (o3 > topology_epsilon && o4 < -topology_epsilon) ||
      (o3 < -topology_epsilon && o4 > topology_epsilon)
    ) {
    return true
  }
  (topology_abs(o1) <= topology_epsilon && topology_point_on_segment(c, a, b)) ||
  (topology_abs(o2) <= topology_epsilon && topology_point_on_segment(d, a, b)) ||
  (topology_abs(o3) <= topology_epsilon && topology_point_on_segment(a, c, d)) ||
  (topology_abs(o4) <= topology_epsilon && topology_point_on_segment(b, c, d))
}

///|
fn topology_ring_is_simple(
  ring : Array[Coordinate],
  ring_index : Int32,
  path : String,
) -> Result[Unit, GeoError] {
  let edges = ring.length() - 1
  for index in 0..<edges {
    if topology_equal_xy(ring[index], ring[index + 1]) {
      return Err(InvalidBoundary(path + " has a zero-length edge", ring_index))
    }
  }
  for left in 0..<edges {
    let start = left + 1
    for right in start..<edges {
      let adjacent = right == left + 1 || (left == 0 && right == edges - 1)
      if adjacent {
        continue
      }
      if topology_segments_intersect(
          ring[left],
          ring[left + 1],
          ring[right],
          ring[right + 1],
        ) {
        return Err(InvalidBoundary(path + " ring self-intersects", ring_index))
      }
    }
  }
  Ok(())
}

///|
fn topology_line_is_simple(
  line : Array[Coordinate],
  path : String,
) -> Result[Unit, GeoError] {
  if line.length() == 0 {
    return Ok(())
  }
  let edges = line.length() - 1
  for index in 0..<edges {
    if topology_equal_xy(line[index], line[index + 1]) {
      return Err(InvalidGeometry(path + " has a zero-length segment"))
    }
  }
  let closed = topology_equal_xy(line[0], line[line.length() - 1])
  for left in 0..<edges {
    let start = left + 1
    for right in start..<edges {
      let adjacent = right == left + 1 ||
        (closed && left == 0 && right == edges - 1)
      if adjacent {
        continue
      }
      if topology_segments_intersect(
          line[left],
          line[left + 1],
          line[right],
          line[right + 1],
        ) {
        return Err(InvalidGeometry(path + " self-intersects"))
      }
    }
  }
  Ok(())
}

///|
fn topology_point_in_ring(
  point : Coordinate,
  ring : Array[Coordinate],
) -> RingLocation {
  let mut inside = false
  let end = ring.length() - 1
  for index in 0..<end {
    let start = ring[index]
    let end = ring[index + 1]
    if topology_point_on_segment(point, start, end) {
      return Boundary
    }
    let crosses = (start.y > point.y) != (end.y > point.y)
    if crosses {
      let intersection_x = start.x +
        (point.y - start.y) * (end.x - start.x) / (end.y - start.y)
      if point.x < intersection_x {
        inside = !inside
      }
    }
  }
  if inside {
    Inside
  } else {
    Outside
  }
}

///|
fn topology_rings_intersect(
  left : Array[Coordinate],
  right : Array[Coordinate],
) -> Bool {
  let left_end = left.length() - 1
  let right_end = right.length() - 1
  for left_index in 0..<left_end {
    for right_index in 0..<right_end {
      if topology_segments_intersect(
          left[left_index],
          left[left_index + 1],
          right[right_index],
          right[right_index + 1],
        ) {
        return true
      }
    }
  }
  false
}

///|
fn topology_point_in_polygon(
  point : Coordinate,
  polygon : Array[Array[Coordinate]],
) -> RingLocation {
  if polygon.length() == 0 {
    return Outside
  }
  match topology_point_in_ring(point, polygon[0]) {
    Outside => Outside
    Boundary => Boundary
    Inside => {
      for index in 1..<polygon.length() {
        match topology_point_in_ring(point, polygon[index]) {
          Inside => return Outside
          Boundary => return Boundary
          Outside => ()
        }
      }
      Inside
    }
  }
}

///|
fn validate_polygon_topology(
  rings : Array[Array[Coordinate]],
  path : String,
) -> Result[Unit, GeoError] {
  if rings.length() == 0 {
    return Ok(())
  }
  match topology_ring_is_simple(rings[0], 0, path) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  for index in 1..<rings.length() {
    let hole = rings[index]
    match topology_ring_is_simple(hole, index, path) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    if topology_rings_intersect(rings[0], hole) {
      return Err(InvalidBoundary(path + " hole intersects shell", index))
    }
    match topology_point_in_ring(hole[0], rings[0]) {
      Inside => ()
      _ => return Err(InvalidBoundary(path + " hole is outside shell", index))
    }
    for other in 1..<index {
      if topology_rings_intersect(hole, rings[other]) {
        return Err(InvalidBoundary(path + " holes intersect", index))
      }
      if topology_point_in_ring(hole[0], rings[other]) == Inside ||
        topology_point_in_ring(rings[other][0], hole) == Inside {
        return Err(InvalidBoundary(path + " holes overlap", index))
      }
    }
  }
  Ok(())
}

///|
fn validate_multi_polygon_topology(
  polygons : Array[Array[Array[Coordinate]]],
  path : String,
) -> Result[Unit, GeoError] {
  for index, polygon in polygons {
    let polygon_path = path + ".polygons[" + index.to_string() + "]"
    match validate_polygon_topology(polygon, polygon_path) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  for left in 0..<polygons.length() {
    let start = left + 1
    for right in start..<polygons.length() {
      let left_polygon = polygons[left]
      let right_polygon = polygons[right]
      for left_ring in left_polygon {
        for right_ring in right_polygon {
          if topology_rings_intersect(left_ring, right_ring) {
            return Err(
              InvalidGeometry(
                path +
                ".polygons[" +
                left.to_string() +
                "] overlaps polygons[" +
                right.to_string() +
                "]",
              ),
            )
          }
        }
      }
      if left_polygon.length() > 0 && right_polygon.length() > 0 {
        if topology_point_in_polygon(left_polygon[0][0], right_polygon) ==
          Inside ||
          topology_point_in_polygon(right_polygon[0][0], left_polygon) == Inside {
          return Err(
            InvalidGeometry(
              path +
              ".polygons[" +
              left.to_string() +
              "] overlaps polygons[" +
              right.to_string() +
              "]",
            ),
          )
        }
      }
    }
  }
  Ok(())
}

///|
fn validate_geometry_topology_at(
  geometry : Geometry,
  path : String,
) -> Result[Unit, GeoError] {
  match geometry {
    Point(_) => Ok(())
    EmptyPoint => Ok(())
    LineString(line) => topology_line_is_simple(line, path)
    Polygon(rings) => validate_polygon_topology(rings, path)
    MultiPoint(_) => Ok(())
    MultiLineString(lines) => {
      for index, line in lines {
        let line_path = path + ".lines[" + index.to_string() + "]"
        match topology_line_is_simple(line, line_path) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
    MultiPolygon(polygons) => validate_multi_polygon_topology(polygons, path)
    GeometryCollection(geometries) => {
      for index, child in geometries {
        let child_path = path + ".geometries[" + index.to_string() + "]"
        match validate_geometry_topology_at(child, child_path) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
  }
}

///|
pub fn validate_geometry_topology(
  geometry : Geometry,
) -> Result[Unit, GeoError] {
  match validate_geometry(geometry) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  validate_geometry_topology_at(geometry, "geometry")
}
