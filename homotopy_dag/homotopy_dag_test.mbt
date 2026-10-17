///|
test "Theorem 8.2: Homotopy Algebra SDR Axioms, HPL Perturbation Transfer & A_infinity m_3" {
  // 構造 6 維高維鏈複形 V = k^6 與 2 維極小上同調空間 H = k^2 的強形變收縮 (SDR)
  // 基向量: e_0, e_1 為上同調代表元；
  // 兩對可縮胞腔對：d_V(e_2) = e_3, d_V(e_4) = e_5；收縮同倫 h(e_3) = e_2, h(e_5) = e_4。
  let d_v : @homotopy_dag.GradedMatrix = {
    rows: 6,
    cols: 6,
    data: [
      0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L,
      0L, 1L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L, 0L,
    ],
  }
  let d_h = @homotopy_dag.GradedMatrix::zeros(2, 2)
  let inj_i : @homotopy_dag.GradedMatrix = {
    rows: 6,
    cols: 2,
    data: [1L, 0L, 0L, 1L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L],
  }
  let proj_p : @homotopy_dag.GradedMatrix = {
    rows: 2,
    cols: 6,
    data: [1L, 0L, 0L, 0L, 0L, 0L, 0L, 1L, 0L, 0L, 0L, 0L],
  }
  let homotopy_h : @homotopy_dag.GradedMatrix = {
    rows: 6,
    cols: 6,
    data: [
      0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L, 0L, 0L, 0L,
      0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L, 0L, 0L, 0L, 0L, 0L, 0L,
    ],
  }
  let sdr : @homotopy_dag.StrongDeformationRetract = {
    dim_v: 6,
    dim_h: 2,
    d_v,
    d_h,
    inj_i,
    proj_p,
    homotopy_h,
  }
  assert_true(sdr.verify_axioms())

  // 引入含一階與二階冪零鏈條的微擾 δ : V -> V：
  // δ(e_0) = 3 e_3 + 2 e_5, δ(e_2) = -5 e_1, δ(e_4) = 4 e_3
  // 一階項 -(δ h δ)(e_0): h(δ e_0) = 3 e_2 + 2 e_4 => δ(3 e_2 + 2 e_4) = -15 e_1 + 8 e_3
  // 二階項 +(δ h)^2 δ(e_0): h(-15 e_1 + 8 e_3) = 8 e_2 => δ(8 e_2) = -40 e_1
  // 總轉移 p Σ i (e_0) = (+15 - 40) e_1 = -25 e_1！
  let delta : @homotopy_dag.GradedMatrix = {
    rows: 6,
    cols: 6,
    data: [
      0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, -5L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 3L,
      0L, 0L, 0L, 4L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 2L, 0L, 0L, 0L, 0L, 0L,
    ],
  }
  let perturbed_sdr = sdr.perturb_via_hpl(delta, 5)
  assert_true(perturbed_sdr.verify_axioms())
  assert_eq(perturbed_sdr.d_h.data[1 * 2 + 0], -25L)

  // 驗證 Kadeishvili A_∞ 三階 Massey 積 m_3(x, y, z)
  let mu = fn(
    u : FixedArray[Int64],
    v : FixedArray[Int64],
  ) -> FixedArray[Int64] {
    [7L * u[2] * v[1], 0L, 0L, 2L * u[0] * v[0], 0L, 0L]
  }
  let x : FixedArray[Int64] = [1L, 0L]
  let y : FixedArray[Int64] = [1L, 0L]
  let z : FixedArray[Int64] = [0L, 1L]
  let m3_xyz = sdr.ainfinity_massey_m3(mu, x, y, z)
  assert_eq(m3_xyz, [14L, 0L])
}

///|
test "Theorem 9.2: Derived Algebraic Geometry Koszul Tor, Serre Multiplicity & Cotangent Complex" {
  let transverse = @homotopy_dag.KoszulDerivedIntersection::from_degeneracy(
    2, 2, 3,
  )
  assert_eq(transverse.tor_ranks, [3, 0, 0])
  assert_eq(transverse.classical_naive_multiplicity(), 3)
  assert_eq(transverse.serre_derived_multiplicity(), 3)

  let non_transverse = @homotopy_dag.KoszulDerivedIntersection::from_degeneracy(
    2, 1, 4,
  )
  assert_eq(non_transverse.tor_ranks, [4, 4, 0])
  assert_eq(non_transverse.classical_naive_multiplicity(), 4)
  assert_eq(non_transverse.serre_derived_multiplicity(), 0)

  let lci_scheme : @homotopy_dag.CotangentComplex = {
    deg0_omega_rank: 5,
    deg_minus1_conormal_rank: 2,
    deg_minus2_syzygy_rank: 0,
  }
  assert_true(lci_scheme.is_quasi_smooth())
  assert_eq(lci_scheme.virtual_dimension(), 3)

  let obstructed_scheme : @homotopy_dag.CotangentComplex = {
    deg0_omega_rank: 5,
    deg_minus1_conormal_rank: 3,
    deg_minus2_syzygy_rank: 1,
  }
  assert_true(!obstructed_scheme.is_quasi_smooth())
  assert_eq(obstructed_scheme.virtual_dimension(), 3)
}
