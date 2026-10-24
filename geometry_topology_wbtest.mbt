///|
test "topology ring simplicity detects crossing edges" {
  let ring = [
    Coordinate::xy(0.0, 0.0),
    Coordinate::xy(2.0, 2.0),
    Coordinate::xy(0.0, 2.0),
    Coordinate::xy(2.0, 0.0),
    Coordinate::xy(0.0, 0.0),
  ]
  assert_eq(
    topology_ring_is_simple(ring, 0, "geometry"),
    Err(InvalidBoundary("geometry ring self-intersects", 0)),
  )
}
