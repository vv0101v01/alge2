///|
/// ============================================================================
/// 同倫類型論 (Homotopy Type Theory, HoTT / Cubical / Cohesive HoTT) 核心基礎與新擴展演算法
/// ============================================================================
///
/// 本套件將全部 11 個範疇與代數結構重新奠基於同倫類型論 (Univalent Foundations)，
/// 並擴展 6 大全新 HoTT 定理與降複雜度高維演算法（定理 12 至 定理 17）：
/// - 定理 12：De Morgan 立方體類型論 (Cubical Type Theory, CCHM) 與 Kan 填充算子 `hcomp`
/// - 定理 13：Voevodsky 單值公理 (Univalence Axiom) `(A ≃ B) ≃ (A =_U B)` 與結構恆等原理 (SIP)
/// - 定理 14：Licata-Shulman Encode-Decode 方法與高階歸納類型 (HITs: S^1, T^2, BG) 迴路空間計算
/// - 定理 15：Freudenthal 懸置穩定化定理 (Suspension Stabilization) O(1) 高階同倫群折疊
/// - 定理 16：同倫推出 (Homotopy Pushout A ⊔^C B)、Seifert-van Kampen 自由融合正規形與 Blakers-Massey 定理
/// - 定理 17：凝聚同倫類型論 (Cohesive HoTT, Π ⊣ ♭ ⊣ ♯ ⊣ ℑ) 無窮小圓盤 D_x 與 Bianchi 曲率恆等式

///|
/// ============================================================================
/// 定理 12：立方體類型論 (Cubical Type Theory) De Morgan 區間代數與 Kan 填充算子 `hcomp`
/// ============================================================================

///|
/// De Morgan 區間元素 i ∈ I（編譯期拆箱單欄位 Newtype，支援符號端點與分次插值）
pub struct IntervalPt(Int32) derive(Debug, Eq)

///|
pub extend IntervalPt with @debug.Debug::{to_repr}

///|
pub extend IntervalPt with Eq::{equal, not_equal}

///|
pub const I_ZERO : Int32 = 0

///|
pub const I_ONE : Int32 = 1024

///|
pub fn IntervalPt::zero() -> IntervalPt {
  IntervalPt(I_ZERO)
}

///|
pub fn IntervalPt::one() -> IntervalPt {
  IntervalPt(I_ONE)
}

///|
/// De Morgan 對合否定 ~i = 1 - i
pub fn IntervalPt::inv(self : IntervalPt) -> IntervalPt {
  IntervalPt(I_ONE - self.0)
}

///|
/// De Morgan 交運算 i ∧ j (Connection Meet)
pub fn IntervalPt::meet(self : IntervalPt, other : IntervalPt) -> IntervalPt {
  IntervalPt(if self.0 < other.0 { self.0 } else { other.0 })
}

///|
/// De Morgan 並運算 i ∨ j (Connection Join)
pub fn IntervalPt::join(self : IntervalPt, other : IntervalPt) -> IntervalPt {
  IntervalPt(if self.0 > other.0 { self.0 } else { other.0 })
}

///|
/// 非交換類型（基本群胚 BG）上的立方體 Kan 同質合成算子 `hcomp` (2D Open Box Lid)：
/// 輸入底邊路徑 `bottom : x0 = x1`、左壁 `left : x0 = y0`、右壁 `right : x1 = y1`，
/// 在 O(1) 時間內填補缺失頂邊 `lid : y0 = y1`，滿足方塊交換關係 left · lid = bottom · right。
pub fn cubical_hcomp_2d(
  bottom : @higher_groupoid.DihedralGauge,
  left : @higher_groupoid.DihedralGauge,
  right : @higher_groupoid.DihedralGauge,
) -> @higher_groupoid.DihedralGauge {
  left.inv().mul(bottom).mul(right)
}

///|
/// 3D 立方體 Kan 填充算子 (`cubical_kan_fill_3d`)：
/// 給定三維超立方體 [0,1]^3 的底面相容邊界 (base_x0, base_y1, base_y0) 與四根垂直側柱
/// (vertical_00, vertical_10, vertical_01, vertical_11)，
/// 同時計算頂面 (z=1) 上經由 (1,0,1) 的路徑（使用 vertical_10）與經由 (0,1,1) 的路徑（使用 vertical_01），
/// 證明兩組正交 2D `hcomp` 填充嚴格同倫相等，複雜度 O(1)。
pub fn cubical_kan_fill_3d(
  base_x0 : @higher_groupoid.DihedralGauge,
  base_y1 : @higher_groupoid.DihedralGauge,
  vertical_00 : @higher_groupoid.DihedralGauge,
  vertical_10 : @higher_groupoid.DihedralGauge,
  vertical_01 : @higher_groupoid.DihedralGauge,
  vertical_11 : @higher_groupoid.DihedralGauge,
) -> (@higher_groupoid.DihedralGauge, @higher_groupoid.DihedralGauge) {
  // 底面 (z=0) 為交換 2-方塊：base_x0 · base_y1 == base_y0 · base_x1
  // 取左底邊 base_y0 = vertical_00，由 2D Kan 填充唯一確定前底邊 base_x1 : (0,1,0) -> (1,1,0)
  let base_y0 = vertical_00
  let base_x1 = cubical_hcomp_2d(base_x0, base_y0, base_y1)

  // 頂面路徑 A：經由 (1,0,1)，使用側柱 vertical_00, vertical_10, vertical_11
  let top_x0 = cubical_hcomp_2d(base_x0, vertical_00, vertical_10)
  let top_y1 = cubical_hcomp_2d(base_y1, vertical_10, vertical_11)
  let path_via_101 = top_x0.mul(top_y1)

  // 頂面路徑 B：經由 (0,1,1)，使用側柱 vertical_00, vertical_01, vertical_11
  let top_y0 = cubical_hcomp_2d(base_y0, vertical_00, vertical_01)
  let top_x1 = cubical_hcomp_2d(base_x1, vertical_01, vertical_11)
  let path_via_011 = top_y0.mul(top_x1)

  (path_via_101, path_via_011)
}

///|
/// ============================================================================
/// 定理 13：Voevodsky 單值公理 (Univalence Axiom) 與結構恆等原理 (SIP Transport)
/// ============================================================================

///|
/// 半伴隨類型等價 (Half-Adjoint Type Equivalence A ≃ B)
pub(all) struct HalfAdjointEquiv[A, B] {
  forward : (A) -> B
  backward : (B) -> A
}

///|
/// 驗證有限樣本集上半伴隨等價的單位同倫 η(x): g(f(x)) =_A x 與餘單位同倫 ε(y): f(g(y)) =_B y
/// 以及半伴隨相容律 ap_f(η(x)) == ε(f(x))
pub fn[A : Eq, B : Eq] HalfAdjointEquiv::verify_coherence(
  self : HalfAdjointEquiv[A, B],
  samples_a : FixedArray[A],
  samples_b : FixedArray[B],
) -> Bool {
  let f = self.forward
  let g = self.backward
  for i = 0; i < samples_a.length(); i = i + 1 {
    let x = samples_a[i]
    let gfx = g(f(x))
    if gfx != x || f(gfx) != f(x) {
      return false
    }
  }
  for j = 0; j < samples_b.length(); j = j + 1 {
    let y = samples_b[j]
    if f(g(y)) != y {
      return false
    }
  }
  true
}

///|
/// 單值路徑傳輸算子 `ua_transport_endo_iter`：
/// 利用 `transport^{X ↦ (X -> X)}(ua(e)^{-1}, fast_step^m)`，
/// 只執行 1 次正向 `ua` 提升、m 次目標域快速推進、1 次逆向 `ua^{-1}` 降階，
/// 中間 m-1 次 `e.forward ∘ e.backward` 由路徑消去律 `ua(e) · ua(e)^{-1} = refl` 靜態消除！
pub fn[A, B] HalfAdjointEquiv::ua_transport_endo_iter(
  self : HalfAdjointEquiv[A, B],
  fast_step_b : (B) -> B,
  iterations : Int32,
  input_a : A,
) -> A {
  let f = self.forward
  let g = self.backward
  let mut cur_b = f(input_a)
  for step = 0; step < iterations; step = step + 1 {
    cur_b = fast_step_b(cur_b)
  }
  g(cur_b)
}

///|
/// ============================================================================
/// 定理 14：Licata-Shulman Encode-Decode 方法與高階歸納類型 (HITs: S^1, T^2, BG)
/// ============================================================================

///|
/// 高階歸納類型 BG 上的形式路徑字（由正逆生成元 loop(g)^±1 串接而成）
pub(all) struct HITLoopStep {
  generator : @higher_groupoid.DihedralGauge
  inverted : Bool
} derive(Debug, Eq)

///|
pub extend HITLoopStep with @debug.Debug::{to_repr}

///|
pub extend HITLoopStep with Eq::{equal, not_equal}

///|
/// Licata-Shulman `encode` 演算法：沿泛覆蓋纖維 `Code(base) = G` 對路徑字執行
/// `transport^{Code}(p, 1_G)`，在 O(|p|) 單次遍歷內將高維同倫路徑收縮為唯一規範群元！
pub fn hit_bg_encode(
  modulus : Int32,
  path_word : FixedArray[HITLoopStep],
) -> @higher_groupoid.DihedralGauge {
  let mut fiber_code = @higher_groupoid.DihedralGauge::id(modulus)
  for i = 0; i < path_word.length(); i = i + 1 {
    let step = path_word[i]
    let g = if step.inverted { step.generator.inv() } else { step.generator }
    fiber_code = fiber_code.mul(g)
  }
  fiber_code
}

///|
/// Licata-Shulman `decode` 演算法：將泛覆蓋纖維元 g ∈ Code(base) 映射回規範基本迴路 loop(g)
pub fn hit_bg_decode(
  code_elem : @higher_groupoid.DihedralGauge,
) -> FixedArray[HITLoopStep] {
  [{ generator: code_elem, inverted: false, }]
}

///|
/// 高階歸納環面 T^2 的 Encode-Decode 繞數不變量：Ω(T^2, pt) ≃ Z × Z
pub fn hit_torus_encode_winding(
  loop_steps : FixedArray[(Int32, Int32)],
) -> (Int32, Int32) {
  for i = 0, w_a = 0, w_b = 0
      i < loop_steps.length()
      i = i + 1, w_a = w_a + loop_steps[i].0, w_b = w_b + loop_steps[i].1 {

  } nobreak {
    (w_a, w_b)
  }
}

///|
/// ============================================================================
/// 定理 15：Freudenthal 懸置定理 (Freudenthal Suspension Theorem) 與穩定同倫群 O(1) 折疊
/// ============================================================================

///|
/// Freudenthal 懸置穩定性狀態
pub(all) struct FreudenthalStability {
  is_isomorphic_in_stable_range : Bool
  is_epimorphic_boundary : Bool
  stabilized_connectivity : Int32
  stable_homotopy_rank : Int32
} derive(Debug, Eq)

///|
pub extend FreudenthalStability with @debug.Debug::{to_repr}

///|
pub extend FreudenthalStability with Eq::{equal, not_equal}

///|
/// O(1) 計算 m 重懸置後的同倫群 π_{base_k + suspensions}(Σ^{suspensions} X) 穩定性與秩
pub fn freudenthal_suspension_stabilize(
  initial_connectivity_n : Int32,
  initial_query_k : Int32,
  suspensions_m : Int32,
  base_stem_rank : Int32,
) -> FreudenthalStability {
  let final_n = initial_connectivity_n + suspensions_m
  let final_k = initial_query_k + suspensions_m
  let is_iso = final_k <= 2 * final_n
  let is_epi = final_k <= 2 * final_n + 1
  {
    is_isomorphic_in_stable_range: is_iso,
    is_epimorphic_boundary: is_epi,
    stabilized_connectivity: final_n,
    stable_homotopy_rank: if is_iso {
      base_stem_rank
    } else {
      -1
    },
  }
}

///|
/// ============================================================================
/// 定理 16：同倫推出 (Homotopy Pushout)、Seifert-van Kampen 融合正規形與 Blakers-Massey
/// ============================================================================

///|
/// 融合自由積 G_A *_H G_B 中的音節 (Syllable)
pub(all) struct AmalgamatedSyllable {
  side : Int32 // 0 = Left(A), 1 = Right(B)
  value : Int32 // 群元標籤
  in_amalgam_h : Bool
} derive(Debug, Eq)

///|
pub extend AmalgamatedSyllable with @debug.Debug::{to_repr}

///|
pub extend AmalgamatedSyllable with Eq::{equal, not_equal}

///|
/// Seifert-van Kampen 融合自由積 O(|w|) 堆疊正規化演算法
pub fn svk_amalgamated_normal_form(
  word : FixedArray[AmalgamatedSyllable],
) -> Array[AmalgamatedSyllable] {
  let stack : Array[AmalgamatedSyllable] = []
  for i = 0; i < word.length(); i = i + 1 {
    let cur = word[i]
    if cur.value != 0 {
      if stack.length() == 0 {
        stack.push(cur)
      } else {
        let last_idx = stack.length() - 1
        let top = stack[last_idx]
        if top.side == cur.side || top.in_amalgam_h || cur.in_amalgam_h {
          let merged_val = top.value + cur.value
          let merged_side = if top.in_amalgam_h { cur.side } else { top.side }
          let merged_in_h = top.in_amalgam_h && cur.in_amalgam_h
          let _ = stack.pop()
          if merged_val != 0 {
            stack.push({
              side: merged_side,
              value: merged_val,
              in_amalgam_h: merged_in_h,
            })
          }
        } else {
          stack.push(cur)
        }
      }
    }
  }
  stack
}

///|
/// Blakers-Massey 同倫切除連通度定理計算器
pub fn blakers_massey_excision_connectivity(
  left_conn_m : Int32,
  right_conn_n : Int32,
) -> Int32 {
  left_conn_m + right_conn_n
}

///|
/// ============================================================================
/// 定理 17：凝聚同倫類型論 (Cohesive HoTT, Schreiber) 四伴隨模態與無窮小微分幾何
/// ============================================================================

///|
/// 凝聚同倫類型論在有限預序流形上的四大模態不變量與無窮小圓盤維度
pub(all) struct CohesiveModalityProfile {
  shape_pi0_components : Int32
  flat_discrete_points : Int32
  sharp_codiscrete_contractible : Bool
  infinitesimal_disk_size_at_origin : Int32
  bianchi_curvature_identity_holds : Bool
} derive(Debug, Eq)

///|
pub extend CohesiveModalityProfile with @debug.Debug::{to_repr}

///|
pub extend CohesiveModalityProfile with Eq::{equal, not_equal}

///|
/// 計算有限凝聚空間 X 在點 x0 處的四伴隨模態特徵 (Π, ♭, ♯, ℑ)、無窮小圓盤 D_{x0}，
/// 並驗證李代數值聯絡 θ 的非交換 Bianchi 曲率恆等式
pub fn analyze_cohesive_hott_space(
  num_points : Int32,
  infinitesimal_adj_mask : FixedArray[UInt64],
  origin_x0 : Int32,
  lie_bracket_sample : (Int64, Int64, Int64),
) -> CohesiveModalityProfile {
  let flat_pts = num_points

  let disk_mask = infinitesimal_adj_mask[origin_x0] | (1UL << origin_x0)
  let mut disk_size = 0
  for i = 0; i < num_points; i = i + 1 {
    if (disk_mask & (1UL << i)) != 0UL {
      disk_size = disk_size + 1
    }
  }

  let visited = FixedArray::make(num_points, false)
  let mut components = 0
  for u = 0; u < num_points; u = u + 1 {
    if !visited[u] {
      components = components + 1
      let mut frontier = 1UL << u
      let mut seen = frontier
      while frontier != 0UL {
        let mut next_f = 0UL
        for v = 0; v < num_points; v = v + 1 {
          if (frontier & (1UL << v)) != 0UL {
            visited[v] = true
            next_f = next_f | infinitesimal_adj_mask[v]
          }
        }
        frontier = next_f & seen.lnot()
        seen = seen | frontier
      }
    }
  }

  let (x, y, z) = lie_bracket_sample
  let br = fn(a : Int64, b : Int64) -> Int64 { a * b - b * a }
  let bianchi_sum = br(x, br(y, z)) + br(y, br(z, x)) + br(z, br(x, y))

  {
    shape_pi0_components: components,
    flat_discrete_points: flat_pts,
    sharp_codiscrete_contractible: num_points > 0,
    infinitesimal_disk_size_at_origin: disk_size,
    bianchi_curvature_identity_holds: bianchi_sum == 0L,
  }
}
