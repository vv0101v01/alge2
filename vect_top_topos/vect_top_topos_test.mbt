///|
test "Theorem 4.2: Vect_k Bifunctorial Kronecker Factorization O(d n^{d+1}) == Naive O(n^{2d})" {
  let fp = @vect_top_topos.Fp::new
  // 驗證負數模歸一化、減法與平方差代數恆等式 (a - b)(a + b) == a^2 - b^2
  let a_val = fp(-17L)
  let b_val = fp(42L)
  assert_eq(
    a_val.sub(b_val).mul(a_val.add(b_val)),
    a_val.mul(a_val).sub(b_val.mul(b_val)),
  )

  // 3 個 2x2 線性算子 A_0 ⊗ A_1 ⊗ A_2 作用於 2^3 = 8 維張量態空間
  let a0 : @vect_top_topos.LinearEndo = {
    dim: 2,
    entries: [fp(2L), fp(3L), fp(5L), fp(7L)],
  }
  let a1 : @vect_top_topos.LinearEndo = {
    dim: 2,
    entries: [fp(11L), fp(13L), fp(17L), fp(19L)],
  }
  let a2 : @vect_top_topos.LinearEndo = {
    dim: 2,
    entries: [fp(23L), fp(29L), fp(31L), fp(37L)],
  }
  let state : FixedArray[@vect_top_topos.Fp] = [
    fp(1L),
    fp(2L),
    fp(3L),
    fp(4L),
    fp(5L),
    fp(6L),
    fp(7L),
    fp(8L),
  ]
  let factors : FixedArray[@vect_top_topos.LinearEndo] = [a0, a1, a2]
  let fast = @vect_top_topos.kronecker_bifunctor_apply(factors, state)
  let naive = @vect_top_topos.naive_kronecker_apply(factors, state)
  assert_eq(fast, naive)

  // 驗證有限體費馬逆元 a * a^{-1} = 1 (mod 998244353)
  let x = fp(123456789L)
  assert_eq(x.mul(x.inv()), fp(1L))
}

///|
test "Theorem 5.2: Top Alexandrov Beat-Point Homotopy Core Collapse Preserves Euler Characteristic" {
  // 驗證全集位元掩碼邊界 (n <= 0, n == 8, n >= 64)
  assert_eq(@vect_top_topos.universe_mask_for_size(0), 0UL)
  assert_eq(@vect_top_topos.universe_mask_for_size(64), 0xFFFFFFFFFFFFFFFFUL)

  let edges : FixedArray[(Int32, Int32)] = [
    (0, 1),
    (0, 2),
    (1, 3),
    (2, 3),
    (4, 6),
    (4, 7),
    (5, 6),
    (5, 7),
  ]
  let space = @vect_top_topos.AlexandrovSpace::from_relations(8, edges)
  let full_mask = @vect_top_topos.universe_mask_for_size(8)
  let core_mask = space.homotopy_core_mask()

  let chi_full = space.euler_characteristic_on_mask(full_mask)
  let chi_core = space.euler_characteristic_on_mask(core_mask)
  assert_eq(chi_full, 1)
  assert_eq(chi_core, 1)
  assert_eq(
    core_mask,
    (1UL << 0) | (1UL << 4) | (1UL << 5) | (1UL << 6) | (1UL << 7),
  )
}

///|
test "Theorem 6.2: Topos Subobject Classifier Ω, Heyting Logic & Lawvere-Tierney Axioms" {
  let space = @vect_top_topos.AlexandrovSpace::from_relations(5, [
    (0, 1),
    (0, 2),
    (1, 3),
    (1, 4),
  ])
  let site = @vect_top_topos.ToposSite::new(space)
  let top = site.truth()
  assert_eq(top.bits(), 31UL)
  let s1 = site.generate_sieve((1UL << 1) | (1UL << 2))
  let s2 = site.generate_sieve((1UL << 3) | (1UL << 0))

  // 驗證非經典直覺主義邏輯：在預層 Topos 中 S1 ∨ ¬S1 ≠ ⊤ (排中律不一定成立)
  let not_s1 = site.heyting_not(s1)
  let excluded_middle = s1.join(not_s1)
  assert_true(excluded_middle != top)

  // 但經過左精確模態 ○_{¬¬} 層化後，○_{¬¬}(S1 ∨ ¬S1) == ⊤ (Glivenko 定理)！
  assert_eq(site.lawvere_tierney_dense(excluded_middle), top)

  // 驗證 Lawvere-Tierney 三公理：
  assert_eq(site.lawvere_tierney_dense(top), top)
  let js2 = site.lawvere_tierney_dense(s2)
  assert_eq(site.lawvere_tierney_dense(js2), js2)
  let lhs = site.lawvere_tierney_dense(s1.meet(s2))
  let rhs = site.lawvere_tierney_dense(s1).meet(site.lawvere_tierney_dense(s2))
  assert_eq(lhs, rhs)

  assert_true(site.kripke_joyal_forces(0, s1.meet(s2)))
}
