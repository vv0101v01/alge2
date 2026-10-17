///|
/// ============================================================================
/// 7. 線性同倫類型論 (Linear HoTT L ⊣ U)、*-自治 Chu 空間與證明網 Cut-Elimination
/// ============================================================================

///|
/// Chu 空間對偶向量對 (Primal v ∈ k^n, Dual φ ∈ (k^n)*)
pub(all) struct ChuDualPair {
  primal : FixedArray[Int64]
  dual : FixedArray[Int64]
} derive(Debug, Eq)

///|
pub extend ChuDualPair with @debug.Debug::{to_repr}

///|
pub extend ChuDualPair with Eq::{equal, not_equal}

///|
/// 線性否定對合算子 (-)^⊥ : Chu(Vect_k, k)^op -> Chu(Vect_k, k)
/// 滿足 perp(perp(A)) == A
pub fn ChuDualPair::perp(self : ChuDualPair) -> ChuDualPair {
  { primal: self.dual, dual: self.primal, }
}

///|
/// Chu 空間雙線性配對求值 ⟨v, φ⟩_A = ∑_i v_i · φ_i（對應證明網 Axiom / Cut 配對）
pub fn ChuDualPair::eval_pairing(self : ChuDualPair) -> Int64 {
  let n = self.primal.length()
  for i = 0, acc = 0L
      i < n
      i = i + 1, acc = acc + self.primal[i] * self.dual[i] {

  } nobreak {
    acc
  }
}

///|
/// 線性資源封裝：單欄位拆箱 Newtype，在編譯期消除包裝層
pub struct LinearVal[A](A) derive(Debug, Eq)

///|
pub extend LinearVal with @debug.Debug::{to_repr}

///|
pub extend LinearVal with Eq::{equal, not_equal}

///|
pub fn[A] LinearVal::mint(v : A) -> LinearVal[A] {
  LinearVal(v)
}

///|
pub fn[A] LinearVal::consume(self : LinearVal[A]) -> A {
  self.0
}

///|
/// 線性態射 A ⊸ B (Linear Homomorphism)
pub struct LinearLollipop[A, B]((A) -> B)

///|
pub fn[A, B] LinearLollipop::new(f : (A) -> B) -> LinearLollipop[A, B] {
  LinearLollipop(f)
}

///|
/// Cut-Elimination 合成規則：將 (A ⊸ B) 與 (B ⊸ C) 沿對偶公式 B / B^⊥ 消去 Cut，
/// 合成為零中間配置的直接線性態射 (A ⊸ C)
pub fn[A, B, C] LinearLollipop::cut_fuse(
  self : LinearLollipop[A, B],
  next : LinearLollipop[B, C],
) -> LinearLollipop[A, C] {
  let f = self.0
  let g = next.0
  LinearLollipop(fn(a) { g(f(a)) })
}

///|
/// 消耗線性資源並產生目標線性資源 (A, A ⊸ B) ⊢ B
pub fn[A, B] LinearLollipop::apply_linear(
  self : LinearLollipop[A, B],
  token : LinearVal[A],
) -> LinearVal[B] {
  let f = self.0
  LinearVal(f(token.0))
}

///|
/// MLL 證明網中的 Par (⅋) 開關節點：連結結論 conclusion 與左前提 left_premise、右前提 right_premise
pub(all) struct ParSwitch {
  conclusion : Int32
  left_premise : Int32
  right_premise : Int32
} derive(Debug, Eq)

///|
pub extend ParSwitch with @debug.Debug::{to_repr}

///|
pub extend ParSwitch with Eq::{equal, not_equal}

///|
/// 內部無分配並查集尋根（供 Danos-Regnier 樹性檢驗使用）
fn uf_find(parent : FixedArray[Int32], x : Int32) -> Int32 {
  let mut cur = x
  while parent[cur] != cur {
    parent[cur] = parent[parent[cur]]
    cur = parent[cur]
  }
  cur
}

///|
/// Danos-Regnier 切換準則演算法：
/// 給定證明結構的頂點數 `num_vertices`、固定邊 `fixed_edges`（含 Axiom 連結與 ⊗ 節點雙邊）
/// 以及所有 ⅋ (Par) 切換節點 `par_switches`，檢驗是否對所有 2^{|Par|} 個開關狀態，
/// 誘導圖皆為無環且連通的樹 (Connected & Acyclic)。
pub fn verify_mll_proof_net(
  num_vertices : Int32,
  fixed_edges : FixedArray[(Int32, Int32)],
  par_switches : FixedArray[ParSwitch],
) -> Bool {
  let num_pars = par_switches.length()
  if num_vertices <= 0 || fixed_edges.length() + num_pars != num_vertices - 1 {
    return false
  }
  let total_switchings = 1 << num_pars
  let parent = FixedArray::make(num_vertices, 0)
  for mask = 0; mask < total_switchings; mask = mask + 1 {
    for v = 0; v < num_vertices; v = v + 1 {
      parent[v] = v
    }
    // 由圖論定理：|E| == |V| - 1 的無向圖連通當且僅當無環 (Acyclic <=> Connected)
    for e = 0; e < fixed_edges.length(); e = e + 1 {
      let (u, v) = fixed_edges[e]
      let ru = uf_find(parent, u)
      let rv = uf_find(parent, v)
      if ru == rv {
        return false
      }
      parent[ru] = rv
    }
    for p = 0; p < num_pars; p = p + 1 {
      let sw = par_switches[p]
      let target = if ((mask >> p) & 1) == 0 {
        sw.left_premise
      } else {
        sw.right_premise
      }
      let ru = uf_find(parent, sw.conclusion)
      let rv = uf_find(parent, target)
      if ru == rv {
        return false
      }
      parent[ru] = rv
    }
  }
  true
}
