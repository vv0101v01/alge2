///|
/// ============================================================================
/// 8. 同倫代數 (Homotopy Algebra)：強形變收縮 (SDR)、同調微擾引理 (HPL) 與 A_∞ 極小模型
/// ============================================================================
///
/// 數學定義 (Definition 8.1 - Strong Deformation Retract (SDR)):
/// 設 (V, d_V) 為高維鏈複形 (dim V = D)，(H, d_H) 為低維約化鏈複形 (dim H = r ≪ D)。
/// 強形變收縮數據 (i : H -> V, p : V -> H, h : V -> V) 滿足：
///   (SDR1) p ∘ i = id_H
///   (SDR2) id_V - i ∘ p = d_V ∘ h + h ∘ d_V
///   (SDR3 - 湮滅條件) h ∘ h = 0,  h ∘ i = 0,  p ∘ h = 0
///
/// 定理 (Theorem 8.2 - Homological Perturbation Lemma & Kadeishvili A_∞ Transfer):
/// (1) 設 δ : V -> V 為小微擾使得 (d_V + δ)^2 = 0 且 δh 冪零 ((δh)^K = 0)。
///     定義微擾轉移核 Σ = ∑_{n=0}^{K-1} (δh)^n δ，則低維空間 H 上的誘導微分為：
///       d_H^∞ = d_H + p ∘ Σ ∘ i
///     必滿足 (d_H^∞)^2 = 0，且 (H, d_H^∞) 與 (V, d_V + δ) 鏈同倫等價！
///     這將高維微擾上同調計算由 O(D^3) 降至 O(r · D) 低維極小模型。
/// (2) Kadeishvili 定理：若 V 配備結合乘法 μ : V ⊗ V -> V，則 H 上誘導 A_∞-代數結構
///     {m_k : H^{⊗k} -> H}，其中二階積與三階高倫 Massey 積為：
///       m_2(x, y) = p(μ(i(x), i(y)))
///       m_3(x, y, z) = p( μ(h(μ(i(x), i(y))), i(z)) - μ(i(x), h(μ(i(y), i(z)))) )

///|
/// 扁平化稠密矩陣（行主序 rows × cols），用於鏈複形態射與同倫算子
pub(all) struct GradedMatrix {
  rows : Int32
  cols : Int32
  data : FixedArray[Int64]
} derive(Debug, Eq)

///|
pub extend GradedMatrix with @debug.Debug::{to_repr}

///|
pub extend GradedMatrix with Eq::{equal, not_equal}

///|
pub fn GradedMatrix::zeros(rows : Int32, cols : Int32) -> GradedMatrix {
  { rows, cols, data: FixedArray::make(rows * cols, 0L), }
}

///|
pub fn GradedMatrix::identity(n : Int32) -> GradedMatrix {
  let data = FixedArray::make(n * n, 0L)
  for i = 0; i < n; i = i + 1 {
    data[i * n + i] = 1L
  }
  { rows: n, cols: n, data, }
}

///|
pub fn GradedMatrix::add(
  self : GradedMatrix,
  other : GradedMatrix,
) -> GradedMatrix {
  let n = self.data.length()
  let out = FixedArray::make(n, 0L)
  for i = 0; i < n; i = i + 1 {
    out[i] = self.data[i] + other.data[i]
  }
  { rows: self.rows, cols: self.cols, data: out, }
}

///|
pub fn GradedMatrix::sub(
  self : GradedMatrix,
  other : GradedMatrix,
) -> GradedMatrix {
  let n = self.data.length()
  let out = FixedArray::make(n, 0L)
  for i = 0; i < n; i = i + 1 {
    out[i] = self.data[i] - other.data[i]
  }
  { rows: self.rows, cols: self.cols, data: out, }
}

///|
pub fn GradedMatrix::mul(
  self : GradedMatrix,
  other : GradedMatrix,
) -> GradedMatrix {
  let r = self.rows
  let m = self.cols
  let c = other.cols
  let out = FixedArray::make(r * c, 0L)
  for i = 0; i < r; i = i + 1 {
    for k = 0; k < m; k = k + 1 {
      let aik = self.data[i * m + k]
      if aik != 0L {
        for j = 0; j < c; j = j + 1 {
          out[i * c + j] = out[i * c + j] + aik * other.data[k * c + j]
        }
      }
    }
  }
  { rows: r, cols: c, data: out, }
}

///|
pub fn GradedMatrix::apply_vec(
  self : GradedMatrix,
  v : FixedArray[Int64],
) -> FixedArray[Int64] {
  let out = FixedArray::make(self.rows, 0L)
  for i = 0; i < self.rows; i = i + 1 {
    let mut sum = 0L
    for j = 0; j < self.cols; j = j + 1 {
      sum = sum + self.data[i * self.cols + j] * v[j]
    }
    out[i] = sum
  }
  out
}

///|
pub fn GradedMatrix::is_zero(self : GradedMatrix) -> Bool {
  for i = 0; i < self.data.length(); i = i + 1 {
    if self.data[i] != 0L {
      return false
    }
  }
  true
}

///|
/// 強形變收縮 (SDR) 結構數據：(H, d_H) ⇄ (V, d_V) ↺ h
pub(all) struct StrongDeformationRetract {
  dim_v : Int32
  dim_h : Int32
  d_v : GradedMatrix // D × D
  d_h : GradedMatrix // r × r
  inj_i : GradedMatrix // D × r (i : H -> V)
  proj_p : GradedMatrix // r × D (p : V -> H)
  homotopy_h : GradedMatrix // D × D (h : V -> V)
} derive(Debug, Eq)

///|
pub extend StrongDeformationRetract with @debug.Debug::{to_repr}

///|
pub extend StrongDeformationRetract with Eq::{equal, not_equal}

///|
/// 嚴格驗證強形變收縮全部公理：
/// d_V^2 = 0, d_H^2 = 0, p i = id_H, id_V - i p = d_V h + h d_V, h^2 = 0, h i = 0, p h = 0
pub fn StrongDeformationRetract::verify_axioms(
  self : StrongDeformationRetract,
) -> Bool {
  let id_h = GradedMatrix::identity(self.dim_h)
  let id_v = GradedMatrix::identity(self.dim_v)
  let dv2 = self.d_v.mul(self.d_v).is_zero()
  let dh2 = self.d_h.mul(self.d_h).is_zero()
  let pi_eq_id = self.proj_p.mul(self.inj_i) == id_h
  let lhs = id_v.sub(self.inj_i.mul(self.proj_p))
  let rhs = self.d_v.mul(self.homotopy_h).add(self.homotopy_h.mul(self.d_v))
  let homotopy_rel = lhs == rhs
  let hh_zero = self.homotopy_h.mul(self.homotopy_h).is_zero()
  let hi_zero = self.homotopy_h.mul(self.inj_i).is_zero()
  let ph_zero = self.proj_p.mul(self.homotopy_h).is_zero()
  dv2 && dh2 && pi_eq_id && homotopy_rel && hh_zero && hi_zero && ph_zero
}

///|
/// 同調微擾引理 (HPL) 轉移演算法：
/// 輸入高維微擾 δ : V -> V 及冪零階數上界 `nilpotency_bound`，
/// 在公理約定 id_V - i p = d_V h + h d_V 下，計算交錯微擾核
///   Σ = ∑_{n=0}^{K-1} (-1)^n (δh)^n δ
/// 並由閉式公式返回低維極小空間 H 上的微擾後 SDR：
///   d_H^∞ = d_H + p Σ i,  i^∞ = i - h Σ i,  p^∞ = p - p Σ h,  h^∞ = h - h Σ h
pub fn StrongDeformationRetract::perturb_via_hpl(
  self : StrongDeformationRetract,
  delta : GradedMatrix,
  nilpotency_bound : Int32,
) -> StrongDeformationRetract {
  let dh = delta.mul(self.homotopy_h)
  let mut sigma = delta
  let mut term = delta
  for step = 1; step < nilpotency_bound; step = step + 1 {
    term = dh.mul(term)
    if term.is_zero() {
      break
    }
    if (step & 1) == 1 {
      sigma = sigma.sub(term)
    } else {
      sigma = sigma.add(term)
    }
  }
  // HPL 四大閉式轉移公式：
  // d_H^∞ = d_H + p Σ i
  let d_h_inf = self.d_h.add(self.proj_p.mul(sigma).mul(self.inj_i))
  // i^∞ = i - h Σ i
  let i_inf = self.inj_i.sub(self.homotopy_h.mul(sigma).mul(self.inj_i))
  // p^∞ = p - p Σ h
  let p_inf = self.proj_p.sub(self.proj_p.mul(sigma).mul(self.homotopy_h))
  // h^∞ = h - h Σ h
  let h_inf = self.homotopy_h.sub(
    self.homotopy_h.mul(sigma).mul(self.homotopy_h),
  )
  {
    dim_v: self.dim_v,
    dim_h: self.dim_h,
    d_v: self.d_v.add(delta),
    d_h: d_h_inf,
    inj_i: i_inf,
    proj_p: p_inf,
    homotopy_h: h_inf,
  }
}

///|
/// Kadeishvili A_∞ 極小模型三階同倫 Massey 積：
/// m_3(x, y, z) = p( μ(h(μ(i(x), i(y))), i(z)) - μ(i(x), h(μ(i(y), i(z)))) )
pub fn StrongDeformationRetract::ainfinity_massey_m3(
  self : StrongDeformationRetract,
  mu : (FixedArray[Int64], FixedArray[Int64]) -> FixedArray[Int64],
  x : FixedArray[Int64],
  y : FixedArray[Int64],
  z : FixedArray[Int64],
) -> FixedArray[Int64] {
  let ix = self.inj_i.apply_vec(x)
  let iy = self.inj_i.apply_vec(y)
  let iz = self.inj_i.apply_vec(z)
  // 左樹分支: μ(h(μ(ix, iy)), iz)
  let xy = mu(ix, iy)
  let h_xy = self.homotopy_h.apply_vec(xy)
  let left_tree = mu(h_xy, iz)
  // 右樹分支: μ(ix, h(μ(iy, iz)))
  let yz = mu(iy, iz)
  let h_yz = self.homotopy_h.apply_vec(yz)
  let right_tree = mu(ix, h_yz)
  // 差值投影回上同調 H
  let diff = FixedArray::make(self.dim_v, 0L)
  for k = 0; k < self.dim_v; k = k + 1 {
    diff[k] = left_tree[k] - right_tree[k]
  }
  self.proj_p.apply_vec(diff)
}

///|
/// ============================================================================
/// 9. 導出代數幾何 (Derived Algebraic Geometry, Lurie / Toën-Vezzosi / Serre)
/// ============================================================================
///
/// 數學定義 (Definition 9.1 - Affine Derived Scheme & Koszul Derived Intersection):
/// 仿射導出概形 RSpec(A) 由非正分次交換微分分次代數 A ∈ cdga^{≤0}_k 表示。
/// 對於環境概形 Z = Spec(R) 中由序列 f = (f_1, ..., f_c) 定義的導出零點軌跡，
/// 其結構層由 Koszul DG-代數給出：
///   K_•(R; f_1, ..., f_c) = ( ⋀^• R^c,  d(e_j) = f_j )
/// 兩個子概形 X, Y ⊆ Z 的導出纖維積為 X ×^R_Z Y = RSpec(A ⊗^L_R B)，其同倫群為：
///   π_{-i}(A ⊗^L_R B) ≅ Tor_i^R(A, B)
///
/// 定理 (Theorem 9.2 - Serre Derived Intersection Formula & Cotangent Complex L_{B/A}):
/// (1) 當相交為非橫截或退化相交（如重數切觸或自身相交 Tor_i ≠ 0, i > 0）時，
///     經典相交僅取 Tor_0 導致維度跳躍，而 Serre 導出相交歐拉示性數：
///       χ(A ⊗^L_R B) = ∑_{i=0}^c (-1)^i dim_k Tor_i^R(A, B)
///     在平坦形變下嚴格保持局部相交重數守恆！
/// (2) 餘切複形 L_{X/k} ∈ D^{≤0}(Coh(X)) 的截斷振幅控制無窮小形變與阻礙理論：
///     虛擬維度 vdim(X) = χ( (L_{X/k})^∨ ) = ∑_{i≥0} (-1)^i rank(L_{-i})，
///     且 X 為擬光滑 (Quasi-smooth / Derived LCI) 當且僅當 L_{X/k} 集中於 [-1, 0]。

///|
/// 導出張量積 A ⊗^L_R B 的 Koszul 分次鏈複形數據
pub(all) struct KoszulDerivedIntersection {
  codim : Int32
  /// 各非正分次 -i (i = 0..codim) 的 Tor_i^R(A, B) 上同調維度
  tor_ranks : FixedArray[Int32]
} derive(Debug, Eq)

///|
pub extend KoszulDerivedIntersection with @debug.Debug::{to_repr}

///|
pub extend KoszulDerivedIntersection with Eq::{equal, not_equal}

///|
/// 由顯式 Koszul 微分餘核維度構造導出相交複形：
/// 對於餘維數 c 的退化相交（其中有效獨立橫截方程數為 r_eff ≤ c，切觸重數為 mult），
/// 剩餘 d_deg = c - r_eff 個退化方向在 Koszul 外代數 ⋀^• k^{d_deg} 上誘導二項式 Tor 群：
///   dim_k Tor_i^R(A, B) = mult · C(c - r_eff, i)
pub fn KoszulDerivedIntersection::from_degeneracy(
  codim : Int32,
  effective_transverse_rank : Int32,
  contact_multiplicity : Int32,
) -> KoszulDerivedIntersection {
  let deg_defect = codim - effective_transverse_rank
  let tor = FixedArray::make(codim + 1, 0)
  for i = 0; i <= deg_defect; i = i + 1 {
    // 計算二項式係數 C(deg_defect, i)
    let mut binom = 1
    for k = 1; k <= i; k = k + 1 {
      binom = binom * (deg_defect - k + 1) / k
    }
    tor[i] = contact_multiplicity * binom
  }
  { codim, tor_ranks: tor, }
}

///|
/// 經典代數幾何天真長相交重數：僅見 0 階截斷 π_0(A ⊗^L_R B) = Tor_0^R(A, B)
pub fn KoszulDerivedIntersection::classical_naive_multiplicity(
  self : KoszulDerivedIntersection,
) -> Int32 {
  self.tor_ranks[0]
}

///|
/// Serre 導出相交重數公式：χ(A ⊗^L_R B) = ∑_{i=0}^c (-1)^i dim_k Tor_i^R(A, B)
/// 納入所有高階同倫修正項 Tor_1, Tor_2, ...
pub fn KoszulDerivedIntersection::serre_derived_multiplicity(
  self : KoszulDerivedIntersection,
) -> Int32 {
  let mut chi = 0
  for i = 0; i <= self.codim; i = i + 1 {
    let sign = if (i & 1) == 0 { 1 } else { -1 }
    chi = chi + sign * self.tor_ranks[i]
  }
  chi
}

///|
/// 餘切複形 L_{X/k} (Illusie-Quillen Cotangent Complex) 在 [-2, 0] 階的分次秩表示：
/// degree 0: Ω^1 (平滑微分 1-形式秩)
/// degree -1: I / I^2 (正規叢 / 方程生成元秩)
/// degree -2: Syz (方程間的高階合衝阻礙秩)
pub(all) struct CotangentComplex {
  deg0_omega_rank : Int32
  deg_minus1_conormal_rank : Int32
  deg_minus2_syzygy_rank : Int32
} derive(Debug, Eq)

///|
pub extend CotangentComplex with @debug.Debug::{to_repr}

///|
pub extend CotangentComplex with Eq::{equal, not_equal}

///|
/// 計算導出概形的虛擬維度 (Virtual Dimension)：
/// vdim(X) = rank(L_0) - rank(L_{-1}) + rank(L_{-2})
pub fn CotangentComplex::virtual_dimension(self : CotangentComplex) -> Int32 {
  self.deg0_omega_rank -
  self.deg_minus1_conormal_rank +
  self.deg_minus2_syzygy_rank
}

///|
/// 判定導出概形是否為擬光滑 (Quasi-smooth / Derived Complete Intersection)：
/// 當且僅當餘切複形 L_{X/k} 的同調振幅完全落在 [-1, 0]（無 -2 階合衝阻礙）
pub fn CotangentComplex::is_quasi_smooth(self : CotangentComplex) -> Bool {
  self.deg_minus2_syzygy_rank == 0
}
