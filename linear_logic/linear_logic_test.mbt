///|
test "Theorem 7.2a: Chu Space *-Autonomous Involutive Duality & Cut-Elimination Pipeline" {
  let a : @linear_logic.ChuDualPair = {
    primal: [2L, 3L, 5L],
    dual: [7L, 11L, 13L],
  }
  assert_eq(a.perp().perp(), a)
  assert_eq(a.eval_pairing(), a.perp().eval_pairing())
  assert_eq(a.eval_pairing(), 2L * 7L + 3L * 11L + 5L * 13L)

  let step1 = @linear_logic.LinearLollipop::new(fn(x : Int64) { x * 4L + 1L })
  let step2 = @linear_logic.LinearLollipop::new(fn(y : Int64) { y * y })
  let step3 = @linear_logic.LinearLollipop::new(fn(z : Int64) { z - 10L })
  let cut_free = step1.cut_fuse(step2).cut_fuse(step3)

  let token = @linear_logic.LinearVal::mint(5L)
  let out = cut_free.apply_linear(token).consume()
  assert_eq(out, 431L)
}

///|
test "Theorem 7.2b: Danos-Regnier Switching Criterion for MLL Proof Nets" {
  // 合法證明網：⊢ A^⊥ ⅋ A
  let valid_axioms : FixedArray[(Int32, Int32)] = [(0, 1)]
  let valid_pars : FixedArray[@linear_logic.ParSwitch] = [
    { conclusion: 2, left_premise: 0, right_premise: 1, },
  ]
  assert_true(@linear_logic.verify_mll_proof_net(3, valid_axioms, valid_pars))

  // 邊數不符樹條件或 0 頂點應被拒絕
  assert_true(!@linear_logic.verify_mll_proof_net(0, [], []))
  assert_true(!@linear_logic.verify_mll_proof_net(3, [], valid_pars))

  // 固定邊自身含環應被拒絕
  let cycle_fixed : FixedArray[(Int32, Int32)] = [(0, 1), (0, 1)]
  assert_true(!@linear_logic.verify_mll_proof_net(3, cycle_fixed, []))

  // Par 切換分支形成環應被拒絕
  let invalid_edges : FixedArray[(Int32, Int32)] = [(0, 1)]
  let invalid_pars : FixedArray[@linear_logic.ParSwitch] = [
    { conclusion: 1, left_premise: 0, right_premise: 2, },
  ]
  assert_true(
    !@linear_logic.verify_mll_proof_net(3, invalid_edges, invalid_pars),
  )
}
