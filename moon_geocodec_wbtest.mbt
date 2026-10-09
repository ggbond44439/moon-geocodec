///|
test "internal bounds merge handles empty and non-empty sides" {
  let bounds = { min_x: 0.0, min_y: 0.0, max_x: 1.0, max_y: 1.0, }
  assert_eq(merge_bounds(None, None), None)
  assert_eq(merge_bounds(Some(bounds), None), Some(bounds))
  assert_eq(merge_bounds(None, Some(bounds)), Some(bounds))
}
