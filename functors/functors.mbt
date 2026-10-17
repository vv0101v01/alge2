///|
/// ============================================================================
/// 1. 單值等價函子 (Univalent Equivalence Functor) & 伴隨等價骨架傳輸
/// ============================================================================
///
/// 同倫類型論定義 (HoTT Definition 1.1 - Half-Adjoint Equivalence & Univalence):
/// 函數 f : A -> B 為同倫等價 isEquiv(f)，若配備偽逆 g : B -> A、
/// 單位路徑 η : ∏_{x:A} (g(f(x)) =_A x)、餘單位路徑 ε : ∏_{y:B} (f(g(y)) =_B y)
/// 及半伴隨相容同倫 τ : ∏_{x:A} ap_f(η(x)) = ε(f(x))。
///
/// 定理 (Theorem 1.2 - Univalent Convolution-Diagonal Skeleton Transport):
/// 設 C 為 XOR 捲積代數類型 (k[Z_2^d], ⋆)，Sk(D) 為點態對角譜骨架類型 (k^{2^d}, ⊙)。
/// 快速 Walsh-Hadamard 變換 F = FWHT : C ≃ Sk(D) 為伴隨等價：
///   F(a ⋆ b) = F(a) ⊙ F(b),   G(y) = (1/2^d) F(y)
/// 由單值公理路徑消去律 ua(e)^{-1} · ua(e) = refl，m 重捲積態射鏈的中間 m-1 次
/// 逆變換在編譯時靜態消去，時間複雜度由 O(m · N^2) 降至 O(N log N + m · N)。

///|
/// 原範疇對象 (Primal Convolution Object in C)：單欄位 Newtype，編譯期拆箱零開銷
pub struct PrimalConv[A](A) derive(Debug, Eq)

///|
pub extend PrimalConv with @debug.Debug::{to_repr}

///|
pub extend PrimalConv with Eq::{equal, not_equal}

///|
pub fn[A] PrimalConv::new(value : A) -> PrimalConv[A] {
  PrimalConv(value)
}

///|
pub fn[A] PrimalConv::unwrap(self : PrimalConv[A]) -> A {
  self.0
}

///|
/// 骨架對偶範疇對象 (Skeleton Diagonal Object in Sk(D))：單欄位 Newtype，編譯期拆箱零開銷
pub struct SpectralSkeleton[A](A) derive(Debug, Eq)

///|
pub extend SpectralSkeleton with @debug.Debug::{to_repr}

///|
pub extend SpectralSkeleton with Eq::{equal, not_equal}

///|
pub fn[A] SpectralSkeleton::new(value : A) -> SpectralSkeleton[A] {
  SpectralSkeleton(value)
}

///|
pub fn[A] SpectralSkeleton::unwrap(self : SpectralSkeleton[A]) -> A {
  self.0
}

///|
/// 等價函子 Trait：以編譯期單態化 (Monomorphization) 分派正逆伴隨函子
pub trait EquivFunctor {
  /// F : C -> D (Forward equivalence functor)
  fn forward(Self) -> Self
  /// G : D -> C (Pseudo-inverse functor)
  fn backward(Self) -> Self
}

///|
/// 編譯期常數：Walsh-Hadamard 8 維蝴蝶掩碼與正規化偏移
pub const HADAMARD_DIM_LOG2 : Int32 = 3

///|
pub const HADAMARD_DIM : Int32 = 1 << HADAMARD_DIM_LOG2

///|
/// 原地快速 Walsh-Hadamard 變換 (O(N log N))，無額外堆分配。
/// 要求長度 n 為 2 的べき乗 (n > 0 && (n & (n - 1)) == 0)。
pub fn fwht_inplace(buf : FixedArray[Int64], invert : Bool) -> Unit {
  let n = buf.length()
  if n <= 1 || (n & (n - 1)) != 0 {
    return
  }
  for len = 1; len < n; len = len << 1 {
    let step = len << 1
    for i = 0; i < n; i = i + step {
      for j = 0; j < len; j = j + 1 {
        let u = buf[i + j]
        let v = buf[i + j + len]
        buf[i + j] = u + v
        buf[i + j + len] = u - v
      }
    }
  }
  if invert {
    let n64 = n.to_int64()
    for i = 0; i < n; i = i + 1 {
      buf[i] = buf[i] / n64
    }
  }
}

///|
/// 為 `PrimalConv[FixedArray[Int64]]` 實作 `EquivFunctor` Trait（編譯期單態化分派）
pub impl EquivFunctor for PrimalConv[FixedArray[Int64]] with fn forward(self) {
  let arr = self.unwrap().copy()
  fwht_inplace(arr, false)
  PrimalConv::new(arr)
}

///|
pub impl EquivFunctor for PrimalConv[FixedArray[Int64]] with fn backward(self) {
  let arr = self.unwrap().copy()
  fwht_inplace(arr, true)
  PrimalConv::new(arr)
}

///|
pub extend PrimalConv with EquivFunctor::{forward, backward}

///|
/// 將原範疇對象提升至對偶骨架譜範疇 F : C -> Sk(D)
pub fn lift_to_skeleton(
  primal : PrimalConv[FixedArray[Int64]],
) -> SpectralSkeleton[FixedArray[Int64]] {
  SpectralSkeleton::new(primal.forward().unwrap())
}

///|
/// 在骨架範疇 Sk(D) 內執行 O(N) 對角態射合成（零中間逆變換）
pub fn skeleton_compose_inplace(
  acc : SpectralSkeleton[FixedArray[Int64]],
  rhs : SpectralSkeleton[FixedArray[Int64]],
) -> SpectralSkeleton[FixedArray[Int64]] {
  let a = acc.unwrap()
  let b = rhs.unwrap()
  let n = a.length()
  for i = 0; i < n; i = i + 1 {
    a[i] = a[i] * b[i]
  }
  SpectralSkeleton::new(a)
}

///|
/// 由骨架範疇透過偽逆函子 G : Sk(D) -> C 還原（滿足 G(F(x)) = x）
pub fn retract_from_skeleton(
  spectral : SpectralSkeleton[FixedArray[Int64]],
) -> PrimalConv[FixedArray[Int64]] {
  PrimalConv::new(spectral.unwrap()).backward()
}

///|
/// 對照組：天真 O(N^2) 範疇 XOR 捲積（用於驗證定理同構性）
pub fn naive_xor_convolution(
  a : FixedArray[Int64],
  b : FixedArray[Int64],
) -> FixedArray[Int64] {
  let n = a.length()
  let out = FixedArray::make(n, 0L)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      out[i ^ j] = out[i ^ j] + a[i] * b[j]
    }
  }
  out
}

///|
/// ============================================================================
/// 2. 自由函子 (Free HIT Functor) & 米田路徑纖維 J-融合 (Coyoneda Lemma)
/// ============================================================================

///|
/// 餘米田自由函子包裝：將基礎容器與延遲合成態射 X -> A 綁定
pub struct Coyoneda[X, A] {
  source : FixedArray[X]
  morphism : (X) -> A
}

///|
/// 單位自然變換 η : F(X) -> Coyoneda(F)(X)
pub fn[X] Coyoneda::lift(source : FixedArray[X]) -> Coyoneda[X, X] {
  { source, morphism: fn(x) { x }, }
}

///|
/// 自由函子態射提升：僅合成函數閉包，O(1) 時間、零容器分配！
pub fn[X, A, B] Coyoneda::map(
  self : Coyoneda[X, A],
  f : (A) -> B,
) -> Coyoneda[X, B] {
  let prev = self.morphism
  { source: self.source, morphism: fn(x) { f(prev(x)) }, }
}

///|
/// 伴隨降階 ε : Coyoneda(F)(A) -> F(A)，僅執行唯一一次 O(N) 迴圈
pub fn[X, A] Coyoneda::lower(self : Coyoneda[X, A]) -> FixedArray[A] {
  let n = self.source.length()
  if n == 0 {
    return []
  }
  let f = self.morphism
  let first = f(self.source[0])
  let out = FixedArray::make(n, first)
  for i = 1; i < n; i = i + 1 {
    out[i] = f(self.source[i])
  }
  out
}

///|
/// 自由函子融合摺疊：連最終容器都不分配，直接沿么半群二元運算歸約 (Zero-Allocation)
pub fn[X, A, M] Coyoneda::fold_fused(
  self : Coyoneda[X, A],
  init : M,
  combine : (M, A) -> M,
) -> M {
  let f = self.morphism
  let n = self.source.length()
  for i = 0, acc = init; i < n; i = i + 1, acc = combine(acc, f(self.source[i])) {

  } nobreak {
    acc
  }
}

///|
/// 2x2 仿射轉移么半群元素：代表 f(x) = a * x + b (mod p)
pub(all) struct AffineEndo {
  a : Int64
  b : Int64
  modulus : Int64
} derive(Debug, Eq)

///|
pub extend AffineEndo with @debug.Debug::{to_repr}

///|
pub extend AffineEndo with Eq::{equal, not_equal}

///|
pub fn AffineEndo::id(modulus : Int64) -> AffineEndo {
  { a: 1L, b: 0L, modulus, }
}

///|
pub fn AffineEndo::compose(self : AffineEndo, other : AffineEndo) -> AffineEndo {
  let m = self.modulus
  let a = self.a * other.a % m
  let b = (self.a * other.b + self.b) % m
  { a, b, modulus: m, }
}

///|
/// 自由么半群泛同態倍增定理：計算自由字 w 重複 K 次後的同態像 φ(w^K)
/// 複雜度：O(|w| + log K)，對比天真重放 O(K · |w|)
pub fn[Gen] free_monoid_hom_power(
  word : FixedArray[Gen],
  generator_map : (Gen) -> AffineEndo,
  repeat_k : Int64,
  modulus : Int64,
) -> AffineEndo {
  let mut base = AffineEndo::id(modulus)
  for i = 0; i < word.length(); i = i + 1 {
    base = generator_map(word[i]).compose(base)
  }
  let mut result = AffineEndo::id(modulus)
  let mut exp = repeat_k
  while exp > 0L {
    if (exp & 1L) == 1L {
      result = base.compose(result)
    }
    base = base.compose(base)
    exp = exp >> 1
  }
  result
}

///|
/// ============================================================================
/// 3. 平坦函子 (Flat Functor) & 同倫拉回 Beck-Chevalley 縮並
/// ============================================================================

///|
/// 二元帶權關係邊 (Weighted Morphism in Finite Category)
pub(all) struct WeightedEdge {
  src : Int32
  dst : Int32
  weight : Int64
} derive(Debug, Eq)

///|
pub extend WeightedEdge with @debug.Debug::{to_repr}

///|
pub extend WeightedEdge with Eq::{equal, not_equal}

///|
/// 平坦函子拉回張量縮並器：在 O(|R1| + |R2| + |R3| + key_bound) 線性時間內
/// 計算 ∑_{(a,b)∈R1, (b,c)∈R2, (c,d)∈R3} w1(a,b) * w2(b,c) * w3(c,d)
pub fn flat_kan_chain_contraction(
  r1 : FixedArray[WeightedEdge],
  r2 : FixedArray[WeightedEdge],
  r3 : FixedArray[WeightedEdge],
  key_bound : Int32,
) -> Int64 {
  let fiber_b = FixedArray::make(key_bound, 0L)
  for i = 0; i < r1.length(); i = i + 1 {
    let e = r1[i]
    fiber_b[e.dst] = fiber_b[e.dst] + e.weight
  }
  let fiber_c = FixedArray::make(key_bound, 0L)
  for i = 0; i < r3.length(); i = i + 1 {
    let e = r3[i]
    fiber_c[e.src] = fiber_c[e.src] + e.weight
  }
  let mut total = 0L
  for i = 0; i < r2.length(); i = i + 1 {
    let e = r2[i]
    total = total + fiber_b[e.src] * e.weight * fiber_c[e.dst]
  }
  total
}

///|
/// 對照組：天真 O(N^3) 三重迴圈笛卡兒積拉回（用於驗證平坦函子定理）
pub fn naive_cubic_chain_contraction(
  r1 : FixedArray[WeightedEdge],
  r2 : FixedArray[WeightedEdge],
  r3 : FixedArray[WeightedEdge],
) -> Int64 {
  let mut total = 0L
  for i = 0; i < r1.length(); i = i + 1 {
    for j = 0; j < r2.length(); j = j + 1 {
      if r1[i].dst == r2[j].src {
        for k = 0; k < r3.length(); k = k + 1 {
          if r2[j].dst == r3[k].src {
            total = total + r1[i].weight * r2[j].weight * r3[k].weight
          }
        }
      }
    }
  }
  total
}
