# Response changes log — numeric deltas per stage

Records how results move as each stage of `RESPONSE_PLAN.md` is applied. The
Stage 0 baseline is the reference for every later comparison. Environment:
MATLAB 26.1.0.3234472 (R2026a) Update 1.

## Stage 0 — Baseline (reference)

Captured via `reproduce_review`, saved to `RESPONSE_BASELINE.mat`. No source
changes. Code Analyzer: 0 findings. Unit tests: 4/4 passed.

| Quantity | Baseline |
|---|---:|
| Level 1 RMS relative parameter error | 0.00572112 |
| Level 2 in-sample R² (strain 1 / 2) | 0.949728 / 0.945828 |
| Level 3 objective weight error | 0.0157222 |
| Level 3 mean control RMSE | 2.89809e-05 |
| Level 4 player weight errors | 0.0100154 / 0.00107388 |
| Level 4 mean control RMSE | 0.00136474 |

Defect reproductions at baseline (all confirmed):

| Finding | Baseline observation |
|---|---|
| F1 small damping | `converged=1` after 1 iteration; unilateral improvements ≈ 0.0794 / 0.0728 |
| F2 bound-active | inferred ≈ [0, 0.9425, 0.0575, 0], weight error 0.0813, control RMSE 0.00476 |
| F3-A planner maxIter=0 | planner exit 0, control RMSE exactly 0, weight error 0.8066 |
| F3-B game maxIter=1 | demos and validations `converged=0` |
| F4 quadrature | noise-free growth RMS 0.0042 / 0.0030 → ZOH-consistent 0.0006 / 0.0005 |
| F5 leakage | 100% of held-out windows share raw samples (both strains) |
| F6 non-finite | NaN time and NaN control both return all-finite states |
| F7 two-time contract | `simulateCommunity(...,[0 1],[0 1],...)` returns 28×5 |
| F8 support metric | zero-noise `supportRecovered=1` with 1 false positive |
| F9 separation | one-row matrix → rank 1, separation Inf, uniform weights |

## Stage 1 — Solver-success gating and Nash certificate (findings 1, 3)

Files: `solveOpenLoopNash.m`, `solveCommunityPlanner.m`,
`runLevel3InverseOptimalControl.m`, `runLevel4InverseDifferentialGame.m`,
`runInverseLadderCaseStudy.m`, `testInverseLadderCaseStudy.m`.

What changed:
- `solveOpenLoopNash` now certifies an equilibrium only when the unilateral
  best-response check passes **and** the certifying re-optimizations succeed with
  finite outputs. The damped-iterate change (`bestResponseGap`) is retained as a
  reported diagnostic, not a certificate. New fields: `status`
  (`verified`/`unverified`), `solverSuccess`, `finalExitFlags`,
  `innerSolvesSucceeded`. `converged` now equals the repaired certificate.
- `solveCommunityPlanner` returns `success` (positive exit flag + finite outputs).
- Levels 3 and 4 record demonstration/validation success and report reproduction
  RMSEs only when the generating solves succeeded; otherwise RMSEs are `NaN` and
  `status = "unverified"` (with a warning). The top-level runner prints `status`.
- Certificate wording states the equilibrium is local and numerical (criterion 2).

Verification (MATLAB R2026a Update 1): Code Analyzer 0 findings; unit tests
**6/6** (added `testNashCertificateRejectsSmallDamping`,
`testFailedPlannerSolvesAreUnverified`).

| Case | Baseline | After Stage 1 |
|---|---|---|
| Default L3 | weight err 0.0157222, cRMSE 2.89809e-05 | **unchanged**, `status=verified` |
| Default L4 | weight err 0.0100154 / 0.00107388, cRMSE 0.00136474 | **unchanged**, `status=verified` |
| F1 damping=0.001 | `converged=1` (false certificate) | `converged=0`, `status=unverified`, max improvement 0.0794 |
| F3-A planner maxIter=0 | exit 0, control RMSE **exactly 0** reported | `status=unverified`, control RMSE **NaN** |
| F3-B game maxIter=1 | metrics returned despite `converged=0` | `status=unverified`, control RMSE **NaN**, demos not verified |

No default coefficient, weight, or error metric changed; the only behavioral
change on default runs is the added, explicit `verified` status.

## Stage 2 — Bound handling and identifiability diagnostics (findings 2, 9)

Files: `runLevel3InverseOptimalControl.m`, `runLevel4InverseDifferentialGame.m`,
`inferSimplexWeights.m`, `runInverseLadderCaseStudy.m`,
`testInverseLadderCaseStudy.m`.

What changed:
- Removed the "fewer than four interior controls ⇒ restore all rows" fallback in
  Levels 3 and 4. Only genuinely interior stationarity rows are used, pooled
  across demonstrations; bound-active rows (whose gradient is balanced by a
  bound multiplier) no longer enter the unconstrained stationarity system.
- `inferSimplexWeights`: the singular spectrum is padded to the number of
  features, so a wide (row-deficient) matrix reports genuine underdetermination
  instead of an infinite separation. Added `matrixRank`, `nullity`,
  `fullSingularValues`, and `locallyIdentifiable` (rank ≥ features−1: three
  independent rows identify four normalized weights). Empty matrices are handled.
- Levels 3 and 4 report `identifiable` and `interiorRowCount`, and warn when the
  objective is not identified. The top-level runner prints identifiability.
- Interior-row pooling with rank reporting is the approved first pass; the full
  bound-gradient (KKT) inequalities remain a follow-up.

Verification (MATLAB R2026a Update 1): Code Analyzer 0 findings; unit tests
**8/8** (added `testBoundActiveDemonstrationNotIdentifiable`,
`testUnderdeterminedSeparationIsFinite`).

| Case | Baseline | After Stage 2 |
|---|---|---|
| Default L3 | weight err 0.0157222, cRMSE 2.89809e-05 | **unchanged**, `identifiable=1` |
| Default L4 | weight err 0.0100154 / 0.00107388, cRMSE 0.00136474 | **unchanged**, `identifiable=[true true]` |
| F2 bound-active (`trueWeights=[0;1;0;0]`) | inferred ≈ [0, 0.9425, 0.0575, 0], weight error 0.0813 (confidently wrong) | `identifiable=0`, interior rows 0, weights fall back to prior [0.25 0.25 0.25 0.25], flagged not identified |
| F9 one-row matrix | rank 1, separation **Inf** | rank 1, nullity 3, separation **0** (finite), `identifiable=0` |

Removing the fallback did **not** change any default result, confirming the
fallback was never triggered by the shipped demonstrations (they contain enough
interior controls); it only removes the silent misuse of bound rows under
supported configurations such as F2.

## Stage 3 — Level 2 quadrature, folds, and support metric (findings 4, 5, 8; results regenerated)

Files: `runLevel2ModelDiscovery.m` (rewritten), `defaultInverseLadderConfig.m`,
`runInverseLadderCaseStudy.m`, `testInverseLadderCaseStudy.m`. Regenerated:
`inverse_ladder_results.mat`, `inverse_ladder_summary.png`.

What changed:
- **Quadrature (finding 4):** the allocation-dependent candidates (`Monod x
  allocation` and `Allocation`) are integrated with a left-held zero-order
  convention, matching the piecewise-constant control that generated the data,
  instead of trapezoidally averaging across control switches. State-derived
  candidates keep trapezoidal integration.
- **Fold leakage (finding 5):** the LASSO penalty is now selected by
  leave-one-experiment-out cross-validation, so overlapping windows never
  straddle a train/validation split and per-experiment smoothing cannot leak
  between folds. Selection is deterministic (no dependence on the global RNG
  state). `fitR2` is documented as an in-sample integrated-growth statistic.
- **Independent prediction (criterion 3):** two separate held-out experiments
  (distinct initial states, independent noise seed) are generated and used only
  to report generalization (`holdoutR2`, `holdoutRmse`). They are not used to
  select the penalty.
- **Support metric (finding 8):** `supportRecovered` now means exact recovery
  for both strains (every true term present and zero false positives). Added
  `trueTermsRecovered`, `falsePositiveCount`, `missedCount`,
  `exactSupportRecovered`.
- Runner prints in-sample R², held-out R², and exact-support recovery; the
  earlier mislabeled "derivative-fit R^2" wording is corrected.

Verification (MATLAB R2026a Update 1): Code Analyzer 0 findings; unit tests
**9/9** (added `testLevel2SupportMetricIsExact`).

| Quantity | Baseline | After Stage 3 |
|---|---|---|
| Level 2 in-sample R² (strain 1 / 2) | 0.949728 / 0.945828 | 0.9567 / 0.9425 |
| Level 2 held-out prediction R² (strain 1 / 2) | not reported | 0.9430 / 0.9622 |
| `supportRecovered` | 1 (ignored false positives) | **0** (exact match) |
| Strain 1 support | Monod, Monod×allocation | Monod, Monod×allocation (recovered; false pos 0, missed 0) |
| Strain 2 support | Monod, +Allocation (spurious) | Monod, +Allocation (false pos 1, missed 1 — ambiguity persists) |
| Selected penalty λ* (strain 1 / 2) | n/a (random-fold IndexMinMSE) | 1.09e-4 / 4.24e-3 |

Regenerated Level 2 coefficients:

| Term | Strain 1 | Strain 2 |
|---|---:|---:|
| Monod cross-feeding | 0.5177 | 0.4076 |
| Monod × allocation | −0.1887 | 0 |
| Allocation | 0 | −0.0337 |
| (all other terms) | 0 | 0 |

The Level 2 numbers change, as expected: correcting the input quadrature and the
cross-validation moves the fit statistics and coefficients. The qualitative
message is unchanged and now honestly quantified — strain 1 recovers the true
mechanism, while strain 2 remains structurally ambiguous (a good predictive fit,
in-sample and held-out, with the wrong term). Levels 1, 3, and 4 are unchanged.

## Stage 4 — Non-finite inputs and simulator contract (findings 6, 7)

Files: `communityRhs.m`, `simulateControlledModel.m`, `simulateCommunity.m`,
`testInverseLadderCaseStudy.m`.

What changed:
- `communityRhs`: clamp genuine out-of-range values without masking non-finite
  inputs. Negative states and out-of-range controls are still clipped, but a NaN
  or Inf is left in place so it propagates and can be detected, instead of being
  silently replaced by 0 (finding 6).
- `simulateControlledModel`: validate that the initial state, time grid, and
  controls are finite (`mustBeFinite`), and reject a non-finite integration
  result rather than flooring it to a plausible value (finding 6).
- `simulateCommunity`: validate finite inputs, and evaluate the ODE solution at
  exactly the requested sample times via `deval`, honoring the
  one-row-per-sample-time contract even for a two-element request (finding 7).
- Added regression tests `testNonFiniteInputsAreRejected` and
  `testSimulateCommunityTwoTimeContract`.

Verification (MATLAB R2026a Update 1): Code Analyzer 0 findings; unit tests
**11/11**.

| Case | Baseline | After Stage 4 |
|---|---|---|
| F6 NaN time / NaN control | returned all-finite floored states | rejected with `MATLAB:validators:mustBeFinite` |
| F6 non-finite integration result | floored to 1e-10 | rejected with `InverseLadder:NonFiniteState` |
| F7 two requested times | 28×5 (adaptive mesh) | **2×5** (contract honored) |
| Default workflow (L1–L4) | — | unchanged (L1 0.00572112, L3 0.0157222/verified, L4 verified); simulator-agreement test still passes |
