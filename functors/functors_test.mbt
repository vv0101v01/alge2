///|
test "Theorem 1.2: Equivalence Functor FWHT Skeleton Transport O(N log N) == O(N^2) Naive" {
  let a : FixedArray[Int64] = [3L, 1L, 4L, 1L, 5L, 9L, 2L, 6L]
  let b : FixedArray[Int64] = [2L, 7L, 1L, 8L, 2L, 8L, 1L, 8L]
  let c : FixedArray[Int64] = [1L, 0L, 2L, 3L, 0L, 1L, 1L, 2L]

  // 驗證 EquivFunctor Trait 伴隨等價三角恆等式 G(F(a)) == a
  let primal_a = @functors.PrimalConv::new(a)
  assert_eq(primal_a.forward().backward(), primal_a)

  // 驗證非 2 的べき乗或長度 <= 1 的邊界安全性
  let single : FixedArray[Int64] = [42L]
  @functors.fwht_inplace(single, false)
  assert_eq(single, [42L])

  // 天真範疇合成：(a ⋆ b) ⋆ c 需兩次 O(N^2) 捲積
  let ab_naive = @functors.naive_xor_convolution(a, b)
  let abc_naive = @functors.naive_xor_convolution(ab_naive, c)

  // 等價函子提升至骨架範疇：在譜空間中直接 O(N) 對角相乘，中間零逆變換
  let sk_a = @functors.lift_to_skeleton(primal_a)
  let sk_b = @functors.lift_to_skeleton(@functors.PrimalConv::new(b))
  let sk_c = @functors.lift_to_skeleton(@functors.PrimalConv::new(c))
  let sk_abc = @functors.skeleton_compose_inplace(
    @functors.skeleton_compose_inplace(sk_a, sk_b),
    sk_c,
  )
  let abc_fast = @functors.retract_from_skeleton(sk_abc).unwrap()
  assert_eq(abc_fast, abc_naive)
}

///|
test "Theorem 2.2: Free Functor Coyoneda Map Fusion & O(log K) Monoid Homomorphism" {
  // 驗證空容器邊界條件
  let empty_src : FixedArray[Int64] = []
  let empty_lowered = @functors.Coyoneda::lift(empty_src)
    .map(fn(x) { x + 1L })
    .lower()
  assert_eq(empty_lowered, [])

  let src : FixedArray[Int64] = [1L, 2L, 3L, 4L, 5L, 6L]
  // 連續 4 次 map 在 Coyoneda 中融合為單次閉包合成，零中間陣列分配
  let coyo = @functors.Coyoneda::lift(src)
    .map(fn(x) { x * 3L })
    .map(fn(x) { x + 7L })
    .map(fn(x) { x * x })
    .map(fn(x) { x - 2L })
  let lowered = coyo.lower()
  let expected : FixedArray[Int64] = [98L, 167L, 254L, 359L, 482L, 623L]
  assert_eq(lowered, expected)

  let sum_fused = coyo.fold_fused(0L, fn(acc, v) { acc + v })
  assert_eq(sum_fused, 1983L)

  // 自由么半群泛同態 O(|w| + log K) 倍增定理驗證
  let modulus = 1000000007L
  let word : FixedArray[Int64] = [2L, 3L, 5L]
  let gen_map = fn(g : Int64) -> @functors.AffineEndo {
    { a: g, b: g + 1L, modulus, }
  }
  let repeat_k = 12L
  let fast_hom = @functors.free_monoid_hom_power(
    word, gen_map, repeat_k, modulus,
  )

  // 對照天真展開 K * |w| 步
  let mut naive_hom = @functors.AffineEndo::id(modulus)
  for r = 0; r < 12; r = r + 1 {
    for i = 0; i < word.length(); i = i + 1 {
      naive_hom = gen_map(word[i]).compose(naive_hom)
    }
  }
  assert_eq(fast_hom, naive_hom)
}

///|
test "Theorem 3.2: Flat Functor Kan Extension Contraction O(N) == Naive O(N^3)" {
  let r1 : FixedArray[@functors.WeightedEdge] = [
    { src: 0, dst: 1, weight: 3L, },
    { src: 2, dst: 1, weight: 5L, },
    { src: 1, dst: 3, weight: 2L, },
  ]
  let r2 : FixedArray[@functors.WeightedEdge] = [
    { src: 1, dst: 2, weight: 4L, },
    { src: 3, dst: 4, weight: 7L, },
    { src: 1, dst: 4, weight: 6L, },
  ]
  let r3 : FixedArray[@functors.WeightedEdge] = [
    { src: 2, dst: 5, weight: 10L, },
    { src: 4, dst: 6, weight: 2L, },
    { src: 4, dst: 7, weight: 3L, },
  ]
  let fast = @functors.flat_kan_chain_contraction(r1, r2, r3, 8)
  let naive = @functors.naive_cubic_chain_contraction(r1, r2, r3)
  assert_eq(fast, naive)
  assert_eq(fast, 630L)
}
