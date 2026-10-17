///|
test "Theorem 12.2: Cubical Type Theory De Morgan Interval & Kan Homogeneous Composition hcomp (2D & 3D)" {
  let i0 = @hott_foundations.IntervalPt::zero()
  let i1 = @hott_foundations.IntervalPt::one()
  // 驗證 De Morgan 律：~(i0 ∧ i1) == (~i0) ∨ (~i1) 與兩方向比較分支
  assert_eq(i0.meet(i1).inv(), i0.inv().join(i1.inv()))
  assert_eq(i1.meet(i0), i0)
  assert_eq(i1.join(i0), i1)
  assert_eq(i0.inv().inv(), i0)

  // 驗證非交換基本群胚 BD_12 上的 2D 與 3D 立方體 Kan 填充 `hcomp`
  let m = 12
  let bx = @higher_groupoid.DihedralGauge::new(3, -1, m)
  let by = @higher_groupoid.DihedralGauge::new(5, 1, m)
  let v00 = @higher_groupoid.DihedralGauge::new(2, 1, m)
  let v10 = @higher_groupoid.DihedralGauge::new(7, -1, m)
  let v01 = @higher_groupoid.DihedralGauge::new(4, -1, m)
  let v11 = @higher_groupoid.DihedralGauge::new(11, 1, m)

  let (via_101, via_011) = @hott_foundations.cubical_kan_fill_3d(
    bx, by, v00, v10, v01, v11,
  )
  // 頂面經由 (1,0,1) 與經由 (0,1,1) 的兩組正交 Kan 填充嚴格同倫相等！
  assert_eq(via_101, via_011)
}

///|
test "Theorem 13.2: Voevodsky Univalence Axiom ua Transport & Structure Identity Principle (SIP)" {
  let equiv : @hott_foundations.HalfAdjointEquiv[Int64, Int64] = {
    forward: fn(x) { x ^ 23130L },
    backward: fn(y) { y ^ 23130L },
  }
  let samples : FixedArray[Int64] = [0L, 1L, 42L, 999L, 65535L]
  assert_true(equiv.verify_coherence(samples, samples))

  // 驗證非等價映射會被半伴隨同倫檢驗器拒絕 (左逆失敗與右逆失敗)
  let bad_left : @hott_foundations.HalfAdjointEquiv[Int64, Int64] = {
    forward: fn(_x) { 0L },
    backward: fn(y) { y },
  }
  assert_true(!bad_left.verify_coherence([1L], [0L]))
  let bad_right : @hott_foundations.HalfAdjointEquiv[Int64, Int64] = {
    forward: fn(x) { x },
    backward: fn(y) { if y == 0L { 0L } else { 0L } },
  }
  assert_true(!bad_right.verify_coherence([0L], [1L]))

  let fast_step = fn(y : Int64) { y + 7L }
  let out_fast = equiv.ua_transport_endo_iter(fast_step, 100, 10L)

  let mut cur = 10L
  for s = 0; s < 100; s = s + 1 {
    cur = (equiv.backward)(fast_step((equiv.forward)(cur)))
  }
  assert_eq(out_fast, cur)
}

///|
test "Theorem 14.2: Licata-Shulman Encode-Decode for Higher Inductive Delooping BG & Torus T^2" {
  let m = 12
  let g1 = @higher_groupoid.DihedralGauge::new(4, -1, m)
  let g2 = @higher_groupoid.DihedralGauge::new(7, 1, m)
  let g3 = @higher_groupoid.DihedralGauge::new(9, -1, m)

  let path_word : FixedArray[@hott_foundations.HITLoopStep] = [
    { generator: g1, inverted: false, },
    { generator: g2, inverted: false, },
    { generator: g2, inverted: true, },
    { generator: g3, inverted: false, },
  ]
  let encoded = @hott_foundations.hit_bg_encode(m, path_word)
  assert_eq(encoded, g1.mul(g3))

  let roundtrip = @hott_foundations.hit_bg_encode(
    m,
    @hott_foundations.hit_bg_decode(encoded),
  )
  assert_eq(roundtrip, encoded)

  let torus_path : FixedArray[(Int32, Int32)] = [(2, -1), (3, 4), (-1, 2)]
  assert_eq(@hott_foundations.hit_torus_encode_winding(torus_path), (4, 5))
}

///|
test "Theorem 15.2 & 16.2: Freudenthal Suspension Stabilization, Seifert-van Kampen & Blakers-Massey" {
  // 未懸置時 (m = 0): n = 1, k = 3 > 2n = 2，尚未進入同構區 (stable_homotopy_rank == -1)
  let unstable = @hott_foundations.freudenthal_suspension_stabilize(1, 3, 0, 1)
  assert_true(!unstable.is_isomorphic_in_stable_range)
  assert_true(unstable.is_epimorphic_boundary)
  assert_eq(unstable.stable_homotopy_rank, -1)

  // 懸置 m = 2 次至 Σ^2 S^2 = S^4 時，n' = 3, k' = 5 <= 2n' = 6，嚴格進入 Freudenthal 穩定同構區！
  let stab = @hott_foundations.freudenthal_suspension_stabilize(1, 3, 2, 1)
  assert_true(stab.is_isomorphic_in_stable_range)
  assert_true(stab.is_epimorphic_boundary)
  assert_eq(stab.stabilized_connectivity, 3)
  assert_eq(stab.stable_homotopy_rank, 1)

  // 驗證 Seifert-van Kampen 同倫推出 A ⊔^C B 的融合自由積 O(|w|) 正規形消去（含 H-優先與非融合分支）
  let word : FixedArray[@hott_foundations.AmalgamatedSyllable] = [
    { side: 0, value: 0, in_amalgam_h: true, }, // 0 值單位元自動忽略
    { side: 0, value: 2, in_amalgam_h: true, }, // 棧底位於 H
    { side: 0, value: 3, in_amalgam_h: false, }, // 合併為左側 5
    { side: 1, value: 3, in_amalgam_h: true, }, // 在融合子群 C 中，跨至左側與 5 合併為 8
    { side: 1, value: 4, in_amalgam_h: false, }, // 右側非融合音節，壓入棧
    { side: 1, value: -4, in_amalgam_h: false, }, // 右側相鄰互逆，自動消去
    { side: 0, value: -2, in_amalgam_h: false, }, // 與棧頂左側 8 合併為 6
  ]
  let nf = @hott_foundations.svk_amalgamated_normal_form(word)
  assert_eq(nf.length(), 1)
  assert_eq(nf[0].value, 6)

  assert_eq(@hott_foundations.blakers_massey_excision_connectivity(2, 3), 5)
}

///|
test "Theorem 17.2: Cohesive HoTT Modalities (Π ⊣ ♭ ⊣ ♯ ⊣ ℑ) & Infinitesimal Disk D_x" {
  let adj : FixedArray[UInt64] = [
    (1UL << 1) | (1UL << 2),
    (1UL << 0) | (1UL << 2),
    (1UL << 0) | (1UL << 1),
    1UL << 4,
    1UL << 3,
  ]
  let prof = @hott_foundations.analyze_cohesive_hott_space(
    5,
    adj,
    0,
    (3L, 5L, 7L),
  )
  assert_eq(prof.shape_pi0_components, 2)
  assert_eq(prof.flat_discrete_points, 5)
  assert_true(prof.sharp_codiscrete_contractible)
  assert_eq(prof.infinitesimal_disk_size_at_origin, 3)
  assert_true(prof.bianchi_curvature_identity_holds)
}
