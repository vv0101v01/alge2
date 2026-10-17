///|
test "Theorem 10.2: Non-Abelian Fundamental Groupoid Path-Compressed Transport & Action Groupoid Cardinality" {
  let m = 12
  let g1 = @higher_groupoid.DihedralGauge::new(3, -1, m)
  let g2 = @higher_groupoid.DihedralGauge::new(4, 1, m)
  assert_true(g1.mul(g2) != g2.mul(g1))
  assert_eq(g1.mul(g1.inv()), @higher_groupoid.DihedralGauge::id(m))

  let groupoid = @higher_groupoid.FundamentalGroupoidUF::new(5, m)
  let e01 = @higher_groupoid.DihedralGauge::new(2, -1, m)
  let e12 = @higher_groupoid.DihedralGauge::new(5, 1, m)
  let e23 = @higher_groupoid.DihedralGauge::new(7, -1, m)

  assert_true(groupoid.add_reversible_morphism(0, 1, e01))
  assert_true(groupoid.add_reversible_morphism(1, 2, e12))
  assert_true(groupoid.add_reversible_morphism(2, 3, e23))

  // 未連通分量 (0 與 4) 平行移動應返回 None
  assert_eq(groupoid.parallel_transport(0, 4), None)

  // O(α(V)) 直接查詢 0 -> 3 的非交換平行移動，必等於 e01 · e12 · e23
  let expected_03 = e01.mul(e12).mul(e23)
  assert_eq(groupoid.parallel_transport(0, 3), Some(expected_03))

  assert_true(groupoid.add_reversible_morphism(0, 3, expected_03))
  let curved = @higher_groupoid.DihedralGauge::new(1, 1, m)
  assert_true(!groupoid.add_reversible_morphism(0, 3, curved))

  let action = fn(g : Int32, x : Int32) -> Int32 {
    if x < 4 {
      (x + g) % 4
    } else {
      4 + (x - 4 + g) % 2
    }
  }
  let (orbits, burnside_numer, total_x) = @higher_groupoid.verify_action_groupoid_cardinality(
    4, 6, action,
  )
  assert_eq(orbits, 2)
  assert_eq(burnside_numer, total_x)
}

///|
test "Theorem 11.2: 2-Group Crossed Module Peiffer Identity & 2D Surface Holonomy Interchange Law" {
  let m = 12
  let e1 = @higher_groupoid.DihedralGauge::new(5, -1, m)
  let e2 = @higher_groupoid.DihedralGauge::new(3, 1, m)
  let g = @higher_groupoid.DihedralGauge::new(7, -1, m)

  assert_true(@higher_groupoid.verify_crossed_module_axioms(e1, e2, g))

  let bl : @higher_groupoid.TwoGroupCell = {
    surface_e: @higher_groupoid.DihedralGauge::new(2, -1, m),
    source_g: @higher_groupoid.DihedralGauge::new(3, 1, m),
  }
  let br : @higher_groupoid.TwoGroupCell = {
    surface_e: @higher_groupoid.DihedralGauge::new(7, 1, m),
    source_g: @higher_groupoid.DihedralGauge::new(4, -1, m),
  }
  let tl_e = @higher_groupoid.DihedralGauge::new(5, -1, m)
  let tr_e = @higher_groupoid.DihedralGauge::new(9, -1, m)

  let (vert_first, horiz_first) = @higher_groupoid.verify_2group_interchange(
    bl, br, tl_e, tr_e,
  )
  assert_eq(vert_first, horiz_first)

  let bottom_sources : FixedArray[@higher_groupoid.DihedralGauge] = [
    @higher_groupoid.DihedralGauge::new(1, -1, m),
    @higher_groupoid.DihedralGauge::new(4, 1, m),
    @higher_groupoid.DihedralGauge::new(7, -1, m),
    @higher_groupoid.DihedralGauge::new(2, 1, m),
  ]
  let flux_grid : FixedArray[@higher_groupoid.DihedralGauge] = [
    @higher_groupoid.DihedralGauge::new(3, -1, m),
    @higher_groupoid.DihedralGauge::new(5, 1, m),
    @higher_groupoid.DihedralGauge::new(2, -1, m),
    @higher_groupoid.DihedralGauge::new(9, 1, m),
    @higher_groupoid.DihedralGauge::new(11, 1, m),
    @higher_groupoid.DihedralGauge::new(4, -1, m),
    @higher_groupoid.DihedralGauge::new(6, -1, m),
    @higher_groupoid.DihedralGauge::new(1, 1, m),
    @higher_groupoid.DihedralGauge::new(8, -1, m),
    @higher_groupoid.DihedralGauge::new(7, 1, m),
    @higher_groupoid.DihedralGauge::new(10, -1, m),
    @higher_groupoid.DihedralGauge::new(5, -1, m),
  ]
  let (col_first, row_first) = @higher_groupoid.compute_surface_2holonomy(
    3, 4, bottom_sources, flux_grid,
  )
  assert_eq(col_first, row_first)
}
