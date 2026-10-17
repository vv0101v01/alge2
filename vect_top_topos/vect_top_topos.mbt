///|
/// ============================================================================
/// 4. Vect_k (依賴線性類型族 ∏_{i:I} k) & Kronecker 雙函子張量分解
/// ============================================================================

///|
/// 編譯期常數：有限體 F_p 的素數模 p = 998244353 (2^23 * 7 * 17 + 1)
pub const MOD_P : Int64 = 998244353L

///|
/// 零成本拆箱有限體元素：在編譯後直接映射為暫存器 Int64
pub struct Fp(Int64) derive(Debug, Eq)

///|
pub extend Fp with @debug.Debug::{to_repr}

///|
pub extend Fp with Eq::{equal, not_equal}

///|
pub fn Fp::new(v : Int64) -> Fp {
  let r = v % MOD_P
  Fp(if r < 0L { r + MOD_P } else { r })
}

///|
pub fn Fp::raw(self : Fp) -> Int64 {
  self.0
}

///|
pub fn Fp::add(self : Fp, other : Fp) -> Fp {
  let s = self.0 + other.0
  Fp(if s >= MOD_P { s - MOD_P } else { s })
}

///|
pub fn Fp::sub(self : Fp, other : Fp) -> Fp {
  let d = self.0 - other.0
  Fp(if d < 0L { d + MOD_P } else { d })
}

///|
pub fn Fp::mul(self : Fp, other : Fp) -> Fp {
  Fp(self.0 * other.0 % MOD_P)
}

///|
pub fn Fp::pow(self : Fp, exp : Int64) -> Fp {
  let mut base = self
  let mut e = exp
  let mut acc = Fp(1L)
  while e > 0L {
    if (e & 1L) == 1L {
      acc = acc.mul(base)
    }
    base = base.mul(base)
    e = e >> 1
  }
  acc
}

///|
/// 費馬小定理求乘法逆元 a^{p-2} mod p
pub fn Fp::inv(self : Fp) -> Fp {
  self.pow(MOD_P - 2L)
}

///|
/// Vect_k 中單一模空間 V_m 的線性自同態 A_m ∈ End_k(k^n)
pub(all) struct LinearEndo {
  dim : Int32
  entries : FixedArray[Fp] // 扁平化 dim × dim 矩陣
} derive(Debug, Eq)

///|
pub extend LinearEndo with @debug.Debug::{to_repr}

///|
pub extend LinearEndo with Eq::{equal, not_equal}

///|
/// 利用雙函子交換律，以 O(d · n^{d+1}) 計算 (A_0 ⊗ A_1 ⊗ ... ⊗ A_{d-1}) v
pub fn kronecker_bifunctor_apply(
  factors : FixedArray[LinearEndo],
  state : FixedArray[Fp],
) -> FixedArray[Fp] {
  let total_len = state.length()
  let mut cur = state.copy()
  let mut next = FixedArray::make(total_len, Fp(0L))
  let mut stride = 1
  for idx = factors.length() - 1; idx >= 0; idx = idx - 1 {
    let op = factors[idx]
    let n = op.dim
    let mat = op.entries
    let block = stride * n
    for base = 0; base < total_len; base = base + block {
      for offset = 0; offset < stride; offset = offset + 1 {
        for r = 0; r < n; r = r + 1 {
          let mut sum = Fp(0L)
          let row_off = r * n
          for c = 0; c < n; c = c + 1 {
            sum = sum.add(mat[row_off + c].mul(cur[base + c * stride + offset]))
          }
          next[base + r * stride + offset] = sum
        }
      }
    }
    let tmp = cur
    cur = next
    next = tmp
    stride = block
  }
  cur
}

///|
/// 對照組：天真 O(n^{2d}) 實化完整 Kronecker 張量積矩陣並相乘
pub fn naive_kronecker_apply(
  factors : FixedArray[LinearEndo],
  state : FixedArray[Fp],
) -> FixedArray[Fp] {
  let n_total = state.length()
  let out = FixedArray::make(n_total, Fp(0L))
  for row = 0; row < n_total; row = row + 1 {
    let mut sum = Fp(0L)
    for col = 0; col < n_total; col = col + 1 {
      let mut coeff = Fp(1L)
      let mut r_tmp = row
      let mut c_tmp = col
      for idx = factors.length() - 1; idx >= 0; idx = idx - 1 {
        let d = factors[idx].dim
        let r_i = r_tmp % d
        let c_i = c_tmp % d
        r_tmp = r_tmp / d
        c_tmp = c_tmp / d
        coeff = coeff.mul(factors[idx].entries[r_i * d + c_i])
      }
      sum = sum.add(coeff.mul(state[col]))
    }
    out[row] = sum
  }
  out
}

///|
/// ============================================================================
/// 5. Top (綜合同倫論可縮纖維) & Alexandrov 同倫極小核收縮
/// ============================================================================

///|
/// 計算大小為 n (0 ≤ n ≤ 64) 的全集位元掩碼（消除重複位移邏輯與 64 位元溢位）
pub fn universe_mask_for_size(n : Int32) -> UInt64 {
  if n <= 0 {
    0UL
  } else if n >= 64 {
    0xFFFFFFFFFFFFFFFFUL
  } else {
    (1UL << n) - 1UL
  }
}

///|
/// 檢查非空嚴格錐 `strict_cone` 在錐族 `cones` 中是否存在唯一頂點 y 使得 `strict_cone ⊆ cones[y]`
fn has_unique_cone_apex(
  n : Int32,
  strict_cone : UInt64,
  cones : FixedArray[UInt64],
) -> Bool {
  if strict_cone == 0UL {
    return false
  }
  for y = 0; y < n; y = y + 1 {
    let y_bit = 1UL << y
    if (strict_cone & y_bit) != 0UL && (strict_cone & cones[y]) == strict_cone {
      return true
    }
  }
  false
}

///|
/// 有限 Alexandrov T_0 拓撲空間（以 64-bit 位元掩碼編碼開集預序）
pub(all) struct AlexandrovSpace {
  num_points : Int32
  /// upset[x] 的第 y 個 bit 為 1 當且僅當 x ≤ y (即 y ∈ U_x)
  upset : FixedArray[UInt64]
  /// downset[x] 的第 y 個 bit 為 1 當且僅當 y ≤ x (即 y ∈ F_x)
  downset : FixedArray[UInt64]
} derive(Debug, Eq)

///|
pub extend AlexandrovSpace with @debug.Debug::{to_repr}

///|
pub extend AlexandrovSpace with Eq::{equal, not_equal}

///|
/// 由有向關係建立 Alexandrov 拓撲空間（自動計算自反傳遞閉包 Warshall 位元演算法）
pub fn AlexandrovSpace::from_relations(
  n : Int32,
  edges : FixedArray[(Int32, Int32)],
) -> AlexandrovSpace {
  let up = FixedArray::make(n, 0UL)
  for i = 0; i < n; i = i + 1 {
    up[i] = 1UL << i
  }
  for k = 0; k < edges.length(); k = k + 1 {
    let (u, v) = edges[k]
    up[u] = up[u] | (1UL << v)
  }
  for k = 0; k < n; k = k + 1 {
    let k_bit = 1UL << k
    for i = 0; i < n; i = i + 1 {
      if (up[i] & k_bit) != 0UL {
        up[i] = up[i] | up[k]
      }
    }
  }
  let down = FixedArray::make(n, 0UL)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      if (up[i] & (1UL << j)) != 0UL {
        down[j] = down[j] | (1UL << i)
      }
    }
  }
  { num_points: n, upset: up, downset: down, }
}

///|
/// 位元並行強形變收縮：消去所有 Up-beat 與 Down-beat 可縮纖維點，返回同倫極小核存活掩碼
pub fn AlexandrovSpace::homotopy_core_mask(self : AlexandrovSpace) -> UInt64 {
  let n = self.num_points
  let mut active = universe_mask_for_size(n)
  let mut changed = true
  while changed {
    changed = false
    for x = 0; x < n; x = x + 1 {
      let x_bit = 1UL << x
      if (active & x_bit) != 0UL {
        let not_x = x_bit.lnot()
        let strict_up = self.upset[x] & active & not_x
        let strict_down = self.downset[x] & active & not_x
        let is_beat = has_unique_cone_apex(n, strict_up, self.upset) ||
          has_unique_cone_apex(n, strict_down, self.downset)
        if is_beat {
          active = active & not_x
          changed = true
        }
      }
    }
  }
  active
}

///|
/// 在給定子空間掩碼上透過 Rota-Leinster 莫比烏斯反演計算歐拉示性數 χ(X) = ∑_{x≤y} μ(x,y)
pub fn AlexandrovSpace::euler_characteristic_on_mask(
  self : AlexandrovSpace,
  mask : UInt64,
) -> Int32 {
  let n = self.num_points
  let mu = FixedArray::make(n * n, 0)
  for i = 0; i < n; i = i + 1 {
    if (mask & (1UL << i)) != 0UL {
      mu[i * n + i] = 1
    }
  }
  for step = 0; step < n; step = step + 1 {
    let mut updated = false
    for x = 0; x < n; x = x + 1 {
      if (mask & (1UL << x)) != 0UL {
        for y = 0; y < n; y = y + 1 {
          let y_bit = 1UL << y
          if x != y && (mask & y_bit) != 0UL && (self.upset[x] & y_bit) != 0UL {
            let mut sum = 0
            for z = 0; z < n; z = z + 1 {
              let z_bit = 1UL << z
              if z != y &&
                (mask & z_bit) != 0UL &&
                (self.upset[x] & z_bit) != 0UL &&
                (self.upset[z] & y_bit) != 0UL {
                sum = sum + mu[x * n + z]
              }
            }
            let next_val = -sum
            if mu[x * n + y] != next_val {
              mu[x * n + y] = next_val
              updated = true
            }
          }
        }
      }
    }
    if !updated {
      break
    }
  }
  let mut chi = 0
  for x = 0; x < n; x = x + 1 {
    if (mask & (1UL << x)) != 0UL {
      for y = 0; y < n; y = y + 1 {
        if (mask & (1UL << y)) != 0UL && (self.upset[x] & (1UL << y)) != 0UL {
          chi = chi + mu[x * n + y]
        }
      }
    }
  }
  chi
}

///|
/// ============================================================================
/// 6. Topos (∞-Topos 單純命題宇宙 Ω ≡ hProp 與左精確模態 ○ : U -> U)
/// ============================================================================

///|
/// 子對象分類子 Ω 的篩對象（零成本單欄位拆箱 Newtype）
pub struct SieveOmega(UInt64) derive(Debug, Eq)

///|
pub extend SieveOmega with @debug.Debug::{to_repr}

///|
pub extend SieveOmega with Eq::{equal, not_equal}

///|
pub fn SieveOmega::bits(self : SieveOmega) -> UInt64 {
  self.0
}

///|
/// 預層 Topos 的基底範疇 (Poset Site P)
pub(all) struct ToposSite {
  space : AlexandrovSpace
  universe_mask : UInt64
} derive(Debug, Eq)

///|
pub extend ToposSite with @debug.Debug::{to_repr}

///|
pub extend ToposSite with Eq::{equal, not_equal}

///|
pub fn ToposSite::new(space : AlexandrovSpace) -> ToposSite {
  { space, universe_mask: universe_mask_for_size(space.num_points), }
}

///|
/// 將任意點集生成向下閉篩 (Downward Closure ↓S)
pub fn ToposSite::generate_sieve(
  self : ToposSite,
  raw_bits : UInt64,
) -> SieveOmega {
  let n = self.space.num_points
  let mut s = 0UL
  for p = 0; p < n; p = p + 1 {
    if (raw_bits & (1UL << p)) != 0UL {
      s = s | self.space.downset[p]
    }
  }
  SieveOmega(s & self.universe_mask)
}

///|
pub fn ToposSite::truth(self : ToposSite) -> SieveOmega {
  SieveOmega(self.universe_mask)
}

///|
pub fn ToposSite::bottom(_self : ToposSite) -> SieveOmega {
  SieveOmega(0UL)
}

///|
pub fn SieveOmega::meet(self : SieveOmega, other : SieveOmega) -> SieveOmega {
  SieveOmega(self.0 & other.0)
}

///|
pub fn SieveOmega::join(self : SieveOmega, other : SieveOmega) -> SieveOmega {
  SieveOmega(self.0 | other.0)
}

///|
/// Heyting 內部邏輯蘊含 (S1 ⇒ S2) : p ⊩ (S1 ⇒ S2) iff (↓p ∩ S1) ⊆ S2
pub fn ToposSite::heyting_implies(
  self : ToposSite,
  s1 : SieveOmega,
  s2 : SieveOmega,
) -> SieveOmega {
  let n = self.space.num_points
  let mut res = 0UL
  for p = 0; p < n; p = p + 1 {
    let down_p = self.space.downset[p] & self.universe_mask
    let lhs = down_p & s1.0
    if (lhs & s2.0) == lhs {
      res = res | (1UL << p)
    }
  }
  SieveOmega(res)
}

///|
/// Heyting 偽補 (內部否定 ¬S = S ⇒ ⊥)
pub fn ToposSite::heyting_not(self : ToposSite, s : SieveOmega) -> SieveOmega {
  self.heyting_implies(s, self.bottom())
}

///|
/// Lawvere-Tierney / 左精確模態雙重否定稠密算子 ○_{¬¬}(S) = ¬¬S : Ω -> Ω
pub fn ToposSite::lawvere_tierney_dense(
  self : ToposSite,
  s : SieveOmega,
) -> SieveOmega {
  self.heyting_not(self.heyting_not(s))
}

///|
/// Kripke-Joyal 語義強制檢驗：判斷階段 p 是否強制滿足內部公式對應篩 S (p ⊩ φ)
pub fn ToposSite::kripke_joyal_forces(
  self : ToposSite,
  stage_p : Int32,
  formula_sieve : SieveOmega,
) -> Bool {
  let down_p = self.space.downset[stage_p] & self.universe_mask
  (down_p & formula_sieve.0) == down_p
}
