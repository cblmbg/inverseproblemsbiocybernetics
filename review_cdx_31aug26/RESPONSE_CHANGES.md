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

## Stage 1 — Solver-success gating and Nash certificate

_Pending._

## Stage 2 — Bound handling and identifiability diagnostics

_Pending._

## Stage 3 — Level 2 quadrature, folds, and support metric (results regenerated)

_Pending._

## Stage 4 — Non-finite inputs and simulator contract

_Pending._
