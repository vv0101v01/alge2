///|
/// ============================================================================
/// 10. 1-Type 群胚 (Groupoid G)：非交換基本群胚 Π_1(X) 路徑壓縮與作用群胚 G ⋉ X
/// ============================================================================

///|
/// 非交換二面體規範群 D_m = Z_m ⋊ {+1, -1} 元素 (rot ∈ [0, m), refl ∈ {1, -1})
/// 群乘法為非交換半直積：(r1, s1) · (r2, s2) = ((r1 + s1 * r2) mod m, s1 * s2)
pub(all) struct DihedralGauge {
  rot : Int32
  refl : Int32 // +1 or -1
  modulus : Int32
} derive(Debug, Eq)

///|
pub extend DihedralGauge with @debug.Debug::{to_repr}

///|
pub extend DihedralGauge with Eq::{equal, not_equal}

///|
pub fn DihedralGauge::id(modulus : Int32) -> DihedralGauge {
  { rot: 0, refl: 1, modulus, }
}

///|
pub fn DihedralGauge::new(
  rot : Int32,
  refl : Int32,
  modulus : Int32,
) -> DihedralGauge {
  let r = rot % modulus
  let norm_r = if r < 0 { r + modulus } else { r }
  let norm_s = if refl < 0 { -1 } else { 1 }
  { rot: norm_r, refl: norm_s, modulus, }
}

///|
/// 非交換群乘法：(r1, s1) · (r2, s2) = (r1 + s1 * r2 mod m, s1 * s2)
pub fn DihedralGauge::mul(
  self : DihedralGauge,
  other : DihedralGauge,
) -> DihedralGauge {
  DihedralGauge::new(
    self.rot + self.refl * other.rot,
    self.refl * other.refl,
    self.modulus,
  )
}

///|
/// 非交換群逆元：(r, s)^{-1} = (-s * r mod m, s)
pub fn DihedralGauge::inv(self : DihedralGauge) -> DihedralGauge {
  DihedralGauge::new(-self.refl * self.rot, self.refl, self.modulus)
}

///|
/// 群共軛作用：g · h · g^{-1}
pub fn DihedralGauge::conjugate_by(
  self : DihedralGauge,
  g : DihedralGauge,
) -> DihedralGauge {
  g.mul(self).mul(g.inv())
}

///|
/// 帶權路徑壓縮基本群胚 Π_1(X) (Path-Compressed Non-Abelian Brandt Groupoid)
pub(all) struct FundamentalGroupoidUF {
  num_objects : Int32
  modulus : Int32
  parent : FixedArray[Int32]
  /// potential[u] ∈ Hom(root(u), u)
  potential : FixedArray[DihedralGauge]
}

///|
pub fn FundamentalGroupoidUF::new(
  num_objects : Int32,
  modulus : Int32,
) -> FundamentalGroupoidUF {
  let parent = FixedArray::make(num_objects, 0)
  let id_g = DihedralGauge::id(modulus)
  let potential = FixedArray::make(num_objects, id_g)
  for i = 0; i < num_objects; i = i + 1 {
    parent[i] = i
  }
  { num_objects, modulus, parent, potential, }
}

///|
/// 帶非交換上鏈合成的路徑壓縮尋根：返回 (root, p[u] ∈ Hom(root, u))
pub fn FundamentalGroupoidUF::find_with_potential(
  self : FundamentalGroupoidUF,
  u : Int32,
) -> (Int32, DihedralGauge) {
  if self.parent[u] == u {
    return (u, self.potential[u])
  }
  let (root, parent_pot) = self.find_with_potential(self.parent[u])
  let total_pot = parent_pot.mul(self.potential[u])
  self.parent[u] = root
  self.potential[u] = total_pot
  (root, total_pot)
}

///|
/// 插入可逆態射 g : u -> v，若 u, v 已連通則檢驗平坦聯絡無曲率條件 (Holonomy == g)
pub fn FundamentalGroupoidUF::add_reversible_morphism(
  self : FundamentalGroupoidUF,
  u : Int32,
  v : Int32,
  g : DihedralGauge,
) -> Bool {
  let (ru, pu) = self.find_with_potential(u)
  let (rv, pv) = self.find_with_potential(v)
  if ru == rv {
    return pu.inv().mul(pv) == g
  }
  self.parent[rv] = ru
  self.potential[rv] = pu.mul(g).mul(pv.inv())
  true
}

///|
/// O(α(V)) 非交換平行移動查詢：返回 Hom(u, v) 中的唯一平坦傳輸態射
pub fn FundamentalGroupoidUF::parallel_transport(
  self : FundamentalGroupoidUF,
  u : Int32,
  v : Int32,
) -> DihedralGauge? {
  let (ru, pu) = self.find_with_potential(u)
  let (rv, pv) = self.find_with_potential(v)
  if ru != rv {
    None
  } else {
    Some(pu.inv().mul(pv))
  }
}

///|
/// 驗證 Baez-Dolan 作用群胚基數定理 (Orbit-Stabilizer Groupoid Cardinality)
pub fn verify_action_groupoid_cardinality(
  group_order : Int32,
  num_elements : Int32,
  action : (Int32, Int32) -> Int32,
) -> (Int32, Int32, Int32) {
  let visited = FixedArray::make(num_elements, false)
  let mut num_orbits = 0
  let mut weighted_burnside_sum = 0
  for x = 0; x < num_elements; x = x + 1 {
    if !visited[x] {
      num_orbits = num_orbits + 1
      let mut stab_size = 0
      for g = 0; g < group_order; g = g + 1 {
        let gx = action(g, x)
        visited[gx] = true
        if gx == x {
          stab_size = stab_size + 1
        }
      }
      weighted_burnside_sum = weighted_burnside_sum + group_order / stab_size
    }
  }
  (num_orbits, weighted_burnside_sum, num_elements)
}

///|
/// ============================================================================
/// 11. 2-群 (2-Type B^2 G_2) & 交叉模 (Crossed Module, Brown-Spencer & Eckmann-Hilton)
/// ============================================================================

///|
/// 2-群中的 2-態射 Φ = (e, g) ∈ E ⋊_α G，源 1-態射為 g，目標 1-態射為 ∂(e)·g = e·g
pub(all) struct TwoGroupCell {
  surface_e : DihedralGauge
  source_g : DihedralGauge
} derive(Debug, Eq)

///|
pub extend TwoGroupCell with @debug.Debug::{to_repr}

///|
pub extend TwoGroupCell with Eq::{equal, not_equal}

///|
/// 邊界同態 ∂ : E -> G（內蘊交叉模中 ∂(e) = e）
pub fn TwoGroupCell::boundary(e : DihedralGauge) -> DihedralGauge {
  e
}

///|
/// 交叉模作用 α(g)(e) = g · e · g^{-1}
pub fn TwoGroupCell::crossed_action(
  g : DihedralGauge,
  e : DihedralGauge,
) -> DihedralGauge {
  e.conjugate_by(g)
}

///|
/// 目標 1-態射 target(e, g) = ∂(e) · g
pub fn TwoGroupCell::target_1morphism(self : TwoGroupCell) -> DihedralGauge {
  TwoGroupCell::boundary(self.surface_e).mul(self.source_g)
}

///|
/// 在底層 2-態射 `self` 的目標 1-邊界之上堆疊新的曲面通量 `top_flux_e`（消除重複源邊界構造）
pub fn TwoGroupCell::stack_above(
  self : TwoGroupCell,
  top_flux_e : DihedralGauge,
) -> TwoGroupCell {
  { surface_e: top_flux_e, source_g: self.target_1morphism(), }
}

///|
/// 檢驗交叉模兩大公理 (Equivariance & Peiffer Identity)
pub fn verify_crossed_module_axioms(
  e1 : DihedralGauge,
  e2 : DihedralGauge,
  g : DihedralGauge,
) -> Bool {
  let lhs_eq = TwoGroupCell::boundary(TwoGroupCell::crossed_action(g, e1))
  let rhs_eq = TwoGroupCell::boundary(e1).conjugate_by(g)
  let lhs_peiffer = TwoGroupCell::crossed_action(TwoGroupCell::boundary(e1), e2)
  let rhs_peiffer = e1.mul(e2).mul(e1.inv())
  lhs_eq == rhs_eq && lhs_peiffer == rhs_peiffer
}

///|
/// 2-群垂直合成 (Vertical Composition): top ∘_v bottom
pub fn TwoGroupCell::compose_vertical(
  top : TwoGroupCell,
  bottom : TwoGroupCell,
) -> TwoGroupCell {
  { surface_e: top.surface_e.mul(bottom.surface_e), source_g: bottom.source_g, }
}

///|
/// 2-群水平合成 (Horizontal Composition): left ∘_h right
pub fn TwoGroupCell::compose_horizontal(
  left : TwoGroupCell,
  right : TwoGroupCell,
) -> TwoGroupCell {
  let acted_e2 = TwoGroupCell::crossed_action(left.source_g, right.surface_e)
  {
    surface_e: left.surface_e.mul(acted_e2),
    source_g: left.source_g.mul(right.source_g),
  }
}

///|
/// 二維交換律定理檢驗器：對任意相容的 2×2 2-態射晶格，驗證
///   (tl ∘_v bl) ∘_h (tr ∘_v br) == (tl ∘_h tr) ∘_v (bl ∘_h br)
pub fn verify_2group_interchange(
  bl : TwoGroupCell,
  br : TwoGroupCell,
  tl_e : DihedralGauge,
  tr_e : DihedralGauge,
) -> (TwoGroupCell, TwoGroupCell) {
  let tl = bl.stack_above(tl_e)
  let tr = br.stack_above(tr_e)
  let col_left = TwoGroupCell::compose_vertical(tl, bl)
  let col_right = TwoGroupCell::compose_vertical(tr, br)
  let vert_then_horiz = TwoGroupCell::compose_horizontal(col_left, col_right)

  let row_bottom = TwoGroupCell::compose_horizontal(bl, br)
  let row_top = TwoGroupCell::compose_horizontal(tl, tr)
  let horiz_then_vert = TwoGroupCell::compose_vertical(row_top, row_bottom)
  (vert_then_horiz, horiz_then_vert)
}

///|
/// 二維非交換曲面 R × C 晶格 2-全純性積分 (2D Surface Holonomy Integration)
pub fn compute_surface_2holonomy(
  rows : Int32,
  cols : Int32,
  bottom_sources : FixedArray[DihedralGauge],
  flux_grid : FixedArray[DihedralGauge],
) -> (TwoGroupCell, TwoGroupCell) {
  let dummy : TwoGroupCell = {
    surface_e: bottom_sources[0],
    source_g: bottom_sources[0],
  }
  let cells = FixedArray::make(rows * cols, dummy)
  for c = 0; c < cols; c = c + 1 {
    let first_cell : TwoGroupCell = {
      surface_e: flux_grid[c],
      source_g: bottom_sources[c],
    }
    cells[c] = first_cell
    let mut prev = first_cell
    for r = 1; r < rows; r = r + 1 {
      let next_cell = prev.stack_above(flux_grid[r * cols + c])
      cells[r * cols + c] = next_cell
      prev = next_cell
    }
  }
  let col_acc = FixedArray::make(cols, cells[0])
  for c = 0; c < cols; c = c + 1 {
    let mut acc = cells[c]
    for r = 1; r < rows; r = r + 1 {
      acc = TwoGroupCell::compose_vertical(cells[r * cols + c], acc)
    }
    col_acc[c] = acc
  }
  let mut total_col_first = col_acc[0]
  for c = 1; c < cols; c = c + 1 {
    total_col_first = TwoGroupCell::compose_horizontal(
      total_col_first,
      col_acc[c],
    )
  }

  let row_acc = FixedArray::make(rows, cells[0])
  for r = 0; r < rows; r = r + 1 {
    let mut acc = cells[r * cols]
    for c = 1; c < cols; c = c + 1 {
      acc = TwoGroupCell::compose_horizontal(acc, cells[r * cols + c])
    }
    row_acc[r] = acc
  }
  let mut total_row_first = row_acc[0]
  for r = 1; r < rows; r = r + 1 {
    total_row_first = TwoGroupCell::compose_vertical(
      row_acc[r],
      total_row_first,
    )
  }
  (total_col_first, total_row_first)
}
