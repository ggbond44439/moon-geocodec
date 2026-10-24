///|
fn coordinate_z_or_zero(coordinate : Coordinate) -> Double {
  match coordinate.z {
    Some(value) => value
    None => 0.0
  }
}

///|
fn point_bounds_3d(coordinate : Coordinate) -> BoundingBox3D {
  let z = coordinate_z_or_zero(coordinate)
  {
    min_x: coordinate.x,
    min_y: coordinate.y,
    min_z: z,
    max_x: coordinate.x,
    max_y: coordinate.y,
    max_z: z,
  }
}

///|
fn extend_bounds_3d(
  bounds : BoundingBox3D,
  coordinate : Coordinate,
) -> BoundingBox3D {
  let z = coordinate_z_or_zero(coordinate)
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
    min_z: if z < bounds.min_z {
      z
    } else {
      bounds.min_z
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
    max_z: if z > bounds.max_z {
      z
    } else {
      bounds.max_z
    },
  }
}

///|
fn bounds_3d_from_coordinates(
  coordinates : Array[Coordinate],
) -> BoundingBox3D? {
  let mut result : BoundingBox3D? = None
  for coordinate in coordinates {
    result = match result {
      Some(current) => Some(extend_bounds_3d(current, coordinate))
      None => Some(point_bounds_3d(coordinate))
    }
  }
  result
}

///|
fn bounds_3d_from_rings(rings : Array[Array[Coordinate]]) -> BoundingBox3D? {
  let mut result : BoundingBox3D? = None
  for ring in rings {
    result = merge_bounds_3d(result, bounds_3d_from_coordinates(ring))
  }
  result
}

///|
fn bounds_3d_from_polygons(
  polygons : Array[Array[Array[Coordinate]]],
) -> BoundingBox3D? {
  let mut result : BoundingBox3D? = None
  for polygon in polygons {
    result = merge_bounds_3d(result, bounds_3d_from_rings(polygon))
  }
  result
}

///|
fn merge_bounds_3d(
  left : BoundingBox3D?,
  right : BoundingBox3D?,
) -> BoundingBox3D? {
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
        min_z: if a.min_z < b.min_z {
          a.min_z
        } else {
          b.min_z
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
        max_z: if a.max_z > b.max_z {
          a.max_z
        } else {
          b.max_z
        },
      })
  }
}

///|
pub fn Geometry::bounds_3d(self : Geometry) -> BoundingBox3D? {
  match self {
    Point(coordinate) => Some(point_bounds_3d(coordinate))
    EmptyPoint => None
    LineString(coordinates) => bounds_3d_from_coordinates(coordinates)
    Polygon(rings) => bounds_3d_from_rings(rings)
    MultiPoint(coordinates) => bounds_3d_from_coordinates(coordinates)
    MultiLineString(lines) => bounds_3d_from_rings(lines)
    MultiPolygon(polygons) => bounds_3d_from_polygons(polygons)
    GeometryCollection(geometries) => {
      let mut result : BoundingBox3D? = None
      for geometry in geometries {
        result = merge_bounds_3d(result, geometry.bounds_3d())
      }
      result
    }
  }
}

///|
pub fn Geometry::dimension(self : Geometry) -> CoordinateDimension? {
  match geometry_dimension_summary(self) {
    Uniform(value) => Some(value)
    _ => None
  }
}

///|
priv enum CentroidKind {
  PointKind
  LineKind
  AreaKind
}

///|
priv struct CentroidData {
  kind : CentroidKind
  weight : Double
  x_sum : Double
  y_sum : Double
  z_sum : Double
  z_complete : Bool
}

///|
fn centroid_kind_rank(kind : CentroidKind) -> Int32 {
  match kind {
    PointKind => 0
    LineKind => 1
    AreaKind => 2
  }
}

///|
fn merge_centroid_data(
  left : CentroidData?,
  right : CentroidData?,
) -> CentroidData? {
  match (left, right) {
    (None, None) => None
    (Some(value), None) => Some(value)
    (None, Some(value)) => Some(value)
    (Some(a), Some(b)) => {
      let rank_a = centroid_kind_rank(a.kind)
      let rank_b = centroid_kind_rank(b.kind)
      if rank_a > rank_b {
        Some(a)
      } else if rank_b > rank_a {
        Some(b)
      } else {
        Some({
          kind: a.kind,
          weight: a.weight + b.weight,
          x_sum: a.x_sum + b.x_sum,
          y_sum: a.y_sum + b.y_sum,
          z_sum: a.z_sum + b.z_sum,
          z_complete: a.z_complete && b.z_complete,
        })
      }
    }
  }
}

///|
fn centroid_data_from_points(coordinates : Array[Coordinate]) -> CentroidData? {
  if coordinates.length() == 0 {
    return None
  }
  let mut x_sum = 0.0
  let mut y_sum = 0.0
  let mut z_sum = 0.0
  let mut z_complete = true
  for coordinate in coordinates {
    x_sum += coordinate.x
    y_sum += coordinate.y
    match coordinate.z {
      Some(value) => z_sum += value
      None => z_complete = false
    }
  }
  Some({
    kind: PointKind,
    weight: coordinates.length().to_double(),
    x_sum,
    y_sum,
    z_sum,
    z_complete,
  })
}

///|
fn segment_length(
  start : Coordinate,
  end : Coordinate,
) -> (Double, Double?, Bool) {
  let dx = end.x - start.x
  let dy = end.y - start.y
  match (start.z, end.z) {
    (Some(start_z), Some(end_z)) => {
      let dz = end_z - start_z
      (
        (dx * dx + dy * dy + dz * dz).sqrt(),
        Some((start_z + end_z) / 2.0),
        true,
      )
    }
    _ => ((dx * dx + dy * dy).sqrt(), None, false)
  }
}

///|
fn centroid_data_from_line(coordinates : Array[Coordinate]) -> CentroidData? {
  if coordinates.length() == 0 {
    return None
  }
  if coordinates.length() == 1 {
    return centroid_data_from_points(coordinates)
  }
  let mut weight = 0.0
  let mut x_sum = 0.0
  let mut y_sum = 0.0
  let mut z_sum = 0.0
  let mut z_complete = true
  let end_index = coordinates.length() - 1
  for index in 0..<end_index {
    let start = coordinates[index]
    let end = coordinates[index + 1]
    let (length, midpoint_z, has_z) = segment_length(start, end)
    weight += length
    x_sum += (start.x + end.x) / 2.0 * length
    y_sum += (start.y + end.y) / 2.0 * length
    match midpoint_z {
      Some(value) => z_sum += value * length
      None => z_complete = false
    }
    if !has_z {
      z_complete = false
    }
  }
  if weight == 0.0 {
    return centroid_data_from_points(coordinates)
  }
  Some({ kind: LineKind, weight, x_sum, y_sum, z_sum, z_complete, })
}

///|
fn centroid_ring_area2(ring : Array[Coordinate]) -> Double {
  let mut area = 0.0
  let end_index = ring.length() - 1
  for index in 0..<end_index {
    area += ring[index].x * ring[index + 1].y -
      ring[index + 1].x * ring[index].y
  }
  area
}

///|
fn centroid_ring(
  ring : Array[Coordinate],
) -> (Double, Double, Double, Double?, Bool)? {
  if ring.length() < 4 {
    return None
  }
  let area2 = centroid_ring_area2(ring)
  if area2 == 0.0 || area2.is_nan() || area2.is_inf() {
    return None
  }
  let mut x_sum = 0.0
  let mut y_sum = 0.0
  let mut z_sum = 0.0
  let mut z_count = 0
  let mut z_complete = true
  let end_index = ring.length() - 1
  for index in 0..<end_index {
    let start = ring[index]
    let end = ring[index + 1]
    let cross = start.x * end.y - end.x * start.y
    x_sum += (start.x + end.x) * cross
    y_sum += (start.y + end.y) * cross
    match start.z {
      Some(value) => {
        z_sum += value
        z_count += 1
      }
      None => z_complete = false
    }
  }
  let area = area2.abs() / 2.0
  let centroid_x = x_sum / (3.0 * area2)
  let centroid_y = y_sum / (3.0 * area2)
  let centroid_z = if z_complete && z_count > 0 {
    Some(z_sum / z_count.to_double())
  } else {
    None
  }
  Some((area, centroid_x, centroid_y, centroid_z, z_complete))
}

///|
fn centroid_data_from_polygon(
  rings : Array[Array[Coordinate]],
) -> CentroidData? {
  if rings.length() == 0 {
    return None
  }
  let shell = match centroid_ring(rings[0]) {
    Some(value) => value
    None => return None
  }
  let (shell_area, shell_x, shell_y, shell_z, shell_z_complete) = shell
  if shell_area == 0.0 {
    return None
  }
  let mut weight = shell_area
  let mut x_sum = shell_area * shell_x
  let mut y_sum = shell_area * shell_y
  let mut z_sum = match shell_z {
    Some(value) => shell_area * value
    None => 0.0
  }
  let mut z_complete = shell_z_complete
  for index in 1..<rings.length() {
    let hole = match centroid_ring(rings[index]) {
      Some(value) => value
      None => continue
    }
    let (area, x, y, z, hole_z_complete) = hole
    weight -= area
    x_sum -= area * x
    y_sum -= area * y
    if z_complete && hole_z_complete {
      match z {
        Some(value) => z_sum -= area * value
        None => z_complete = false
      }
    } else {
      z_complete = false
    }
  }
  if weight <= 0.0 {
    return None
  }
  Some({ kind: AreaKind, weight, x_sum, y_sum, z_sum, z_complete, })
}

///|
fn centroid_data_from_polygons(
  polygons : Array[Array[Array[Coordinate]]],
) -> CentroidData? {
  let mut result : CentroidData? = None
  for polygon in polygons {
    result = merge_centroid_data(result, centroid_data_from_polygon(polygon))
  }
  result
}

///|
fn polygon_perimeter(rings : Array[Array[Coordinate]]) -> Double {
  let mut total = 0.0
  for ring in rings {
    let end = ring.length() - 1
    for index in 0..<end {
      let (length, _, _) = segment_length(ring[index], ring[index + 1])
      total += length
    }
  }
  total
}

///|
fn polygon_area(rings : Array[Array[Coordinate]]) -> Double {
  if rings.length() == 0 {
    return 0.0
  }
  let mut area = centroid_ring_area2(rings[0]).abs() / 2.0
  for index in 1..<rings.length() {
    area -= centroid_ring_area2(rings[index]).abs() / 2.0
  }
  if area > 0.0 {
    area
  } else {
    0.0
  }
}

///|
pub fn Geometry::length(self : Geometry) -> Double {
  match self {
    Point(_) => 0.0
    EmptyPoint => 0.0
    LineString(line) => {
      let end = line.length() - 1
      let mut total = 0.0
      for index in 0..<end {
        let (length, _, _) = segment_length(line[index], line[index + 1])
        total += length
      }
      total
    }
    Polygon(rings) => polygon_perimeter(rings)
    MultiPoint(_) => 0.0
    MultiLineString(lines) => {
      let mut total = 0.0
      for line in lines {
        let end = line.length() - 1
        for index in 0..<end {
          let (length, _, _) = segment_length(line[index], line[index + 1])
          total += length
        }
      }
      total
    }
    MultiPolygon(polygons) => {
      let mut total = 0.0
      for polygon in polygons {
        total += polygon_perimeter(polygon)
      }
      total
    }
    GeometryCollection(geometries) => {
      let mut total = 0.0
      for child in geometries {
        total += child.length()
      }
      total
    }
  }
}

///|
pub fn Geometry::area(self : Geometry) -> Double {
  match self {
    Point(_) => 0.0
    EmptyPoint => 0.0
    LineString(_) => 0.0
    Polygon(rings) => polygon_area(rings)
    MultiPoint(_) => 0.0
    MultiLineString(_) => 0.0
    MultiPolygon(polygons) => {
      let mut total = 0.0
      for polygon in polygons {
        total += polygon_area(polygon)
      }
      total
    }
    GeometryCollection(geometries) => {
      let mut total = 0.0
      for child in geometries {
        total += child.area()
      }
      total
    }
  }
}

///|
fn centroid_data(geometry : Geometry) -> CentroidData? {
  match geometry {
    Point(coordinate) => centroid_data_from_points([coordinate])
    EmptyPoint => None
    LineString(coordinates) => centroid_data_from_line(coordinates)
    Polygon(rings) => centroid_data_from_polygon(rings)
    MultiPoint(coordinates) => centroid_data_from_points(coordinates)
    MultiLineString(lines) => {
      let mut result : CentroidData? = None
      for line in lines {
        result = merge_centroid_data(result, centroid_data_from_line(line))
      }
      result
    }
    MultiPolygon(polygons) => centroid_data_from_polygons(polygons)
    GeometryCollection(geometries) => {
      let mut result : CentroidData? = None
      for child in geometries {
        result = merge_centroid_data(result, centroid_data(child))
      }
      result
    }
  }
}

///|
pub fn Geometry::centroid(self : Geometry) -> Coordinate? {
  let data = match centroid_data(self) {
    Some(value) => value
    None => return None
  }
  if data.weight <= 0.0 {
    return None
  }
  let z = if data.z_complete { Some(data.z_sum / data.weight) } else { None }
  Some({ x: data.x_sum / data.weight, y: data.y_sum / data.weight, z, m: None, })
}
