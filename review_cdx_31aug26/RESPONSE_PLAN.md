# Response plan to code review `code_review.md` (31 August 2026)

This document describes how each finding in `code_review.md` will be addressed.
Work is carried out on branch `fix/review-cdx-31aug26`, one reviewable commit
per stage. The reviewed commit was `62ee2e6`; this response is developed on top
of `272b83e` (the commit that added the review folder).

## Guiding principles

- **Reproducibility is not validity.** The published numbers reproduce under the
  existing implementation, but the Level 2 quadrature and cross-validation
  defects sit inside the *default* workflow. Correcting them can change
  coefficients, selected terms, and fit statistics; those changes are expected
  and are recorded explicitly rather than suppressed.
- **The historical results are preserved.** The pre-change state is frozen in git
  at `272b83e` (including `inverse_ladder_results.mat`, `inverse_ladder_summary.png`,
  and `review_cdx_31aug26/review_evidence.mat`). A fresh baseline diagnostics
  struct is stored in `review_cdx_31aug26/RESPONSE_BASELINE.mat`. Regenerated
  results are written to new files and diffed against this reference.
- **Verification after every stage.** Each stage reruns (a) the standard workflow
  baseline and (b) the specific failure reproductions it targets, through
  `reproduce_review` / `matlab -batch`. Every changed coefficient, weight,
  convergence outcome, and error metric is logged in `RESPONSE_CHANGES.md`.
- **Regression tests.** Each fix adds a test to `testInverseLadderCaseStudy.m`
  (or a new test file) that would have caught the defect.

## Global acceptance criteria (applied to every stage)

1. **Solver success requires more than a positive exit flag.** A solve is accepted
   only if its exit flag is positive **and** its outputs are finite **and** the
   constraints are feasible within tolerance **and** the relevant optimality
   diagnostic passes. If a final unilateral re-optimization fails, the
   equilibrium is reported as `unverified`; a small *computed* improvement is
   never interpreted as evidence of convergence.
2. **The Nash certificate is a local, numerical check.** Successful local
   best-response searches support an *approximate* equilibrium claim only; they
   do not establish global Nash optimality. Reported fields and console messages
   state this scope.
3. **Model selection is separated from final validation.** Grouped folds repair
   the overlap leakage, but the data used to select the LASSO penalty remain
   selection data. Independent-prediction claims use additional untouched
   experiments (or an outer validation procedure), not the selection folds.

## Approved implementation decisions

- **Bound handling (finding 2):** ship *interior-row pooling with rank /
  identifiability reporting* first; add the full bound-gradient (KKT)
  inequalities as a follow-up.
- **Independent prediction (finding 5):** add one or two extra held-out
  calibration experiments rather than an outer CV over the existing data.
- **Scope of this PR:** Stages 1–4 (code fixes). Stage 5 (manuscript reassessment:
  numerical refinement and propagation of kinetic-parameter error) is a follow-up.

---

## Baseline reference (captured Stage 0)

Environment: MATLAB 26.1.0.3234472 (R2026a) Update 1. Code Analyzer: 0 findings.
Unit tests: 4/4 passed. Saved to `RESPONSE_BASELINE.mat`.

| Quantity | Baseline |
|---|---:|
| Level 1 RMS relative parameter error | 0.00572112 |
| Level 2 in-sample integrated-growth R² (strain 1 / 2) | 0.949728 / 0.945828 |
| Level 3 objective weight error | 0.0157222 |
| Level 3 mean control RMSE | 2.89809e-05 |
| Level 4 player weight errors | 0.0100154 / 0.00107388 |
| Level 4 mean control RMSE | 0.00136474 |

All nine defects reproduce at baseline (F1 false convergence under small damping;
F2 wrong inference for bound-active demonstrations; F3 failed solves used as
demonstrations/validation; F4 quadrature residual 0.0042/0.0030 vs 0.0006/0.0005
ZOH-consistent; F5 100% fold leakage; F6 NaN inputs accepted; F7 28×5 for two
requested times; F8 `supportRecovered=1` with 1 false positive at zero noise;
F9 infinite separation for a one-row matrix).

---

## Stage-by-stage fixes

### Stage 1 — Solver-success gating and Nash certificate (findings 3, 1)

Files: `solveOpenLoopNash.m`, `solveCommunityPlanner.m`,
`runLevel3InverseOptimalControl.m`, `runLevel4InverseDifferentialGame.m`,
`runInverseLadderCaseStudy.m`.

- Capture the `fmincon` exit flags currently discarded at
  `solveOpenLoopNash.m:28` and `:53` and the planner exit flags; add finiteness
  and feasibility checks (criterion 1).
- Replace the damped-iterate stopping test as the *certificate*: the equilibrium
  claim is gated on the **unilateral-deviation check** (each player re-optimized
  against the same final joint control profile). The undamped best-response
  residual is retained as a reported diagnostic, not a gate, so a small damping
  factor can no longer self-certify convergence (fixes F1).
- Add a `status` field (`verified` / `unverified`). A failed inner or final
  re-optimization yields `unverified` (criterion 1); console/reported messages
  describe the certificate as local and numerical (criterion 2).
- Gate the pipeline: Levels 3 and 4 do not interpret controls as
  optimal/equilibrium behavior, and do not report validation RMSEs, unless the
  generating solves succeeded (fixes F3). The top-level summary reflects
  `unverified` honestly instead of printing success.
- Verification: rerun baseline (default L3/L4 metrics expected unchanged, now
  with explicit `verified` status); reproduce F1 (`damping=0.001` must report not
  converged), F3-A (`maximumIterations=0` must be flagged), F3-B
  (`maxBestResponseIterations=1` must be `unverified`).

### Stage 2 — Bound handling and identifiability diagnostics (findings 2, 9)

Files: `runLevel3InverseOptimalControl.m`, `runLevel4InverseDifferentialGame.m`,
`inferSimplexWeights.m`.

- Remove the "fewer than four interior controls ⇒ restore all rows" fallback.
  Pool the genuine interior stationarity rows across all demonstrations, then
  assess identifiability by rank and conditioning under the simplex
  normalization (three independent rows can identify four normalized weights).
  When information is insufficient, report it rather than applying unconstrained
  stationarity to bound-active rows (first-pass fix for F2).
- Follow-up (separate commit/PR): add the bound-gradient (KKT) inequalities so
  bound-active demonstrations contribute correct information.
- `inferSimplexWeights`: compute rank and nullity explicitly and account for the
  normalized feasible set; stop returning `nullspaceSeparation = Inf` merely
  because a wide matrix yields a single singular value (fixes F9).
- Verification: reproduce F2 (`trueWeights=[0;1;0;0]`, controls at 0.02 → must no
  longer return a spurious residual-substrate preference; either identify or
  report insufficient interior information) and F9
  (`inferSimplexWeights([1 -1 0 0],cfg)` → finite, honest separation and rank).
  Rerun baseline (default weights are interior ⇒ L3/L4 metrics expected stable).

### Stage 3 — Level 2 quadrature, folds, and support metric (findings 4, 5, 8)

File: `runLevel2ModelDiscovery.m` (and `generateCalibrationData.m` for the extra
held-out experiment).

- **Quadrature first (finding 4):** integrate the zero-order-held inputs
  consistently (left-held control on each interval) instead of trapezoidal
  averaging across switch endpoints. This changes the regression features, so it
  precedes model selection and validation.
- **Fold redesign (finding 5):** replace random cross-validation over overlapping
  windows with grouped/blocked folds, with smoothing and scaling performed
  inside each training partition to remove leakage.
- **Selection vs. validation (criterion 3):** grouped folds select the LASSO
  penalty; independent-prediction performance is measured on one or two untouched
  experiments. `fitR2` is reported as an in-sample integrated-growth statistic;
  a separate held-out metric carries any generalization claim.
- **Support metric (finding 8):** compare the full selected mask with
  `expectedSupport`, reporting missed terms and false positives separately;
  rename `supportRecovered` accordingly.
- **Regenerate** Level 2 results and record how coefficients, selected support,
  and fit statistics move relative to the baseline (changes are expected).
- Verification: reproduce F4 (residual-RMS reduction), F5 (fold independence), and
  F8 (zero-noise false positive now counted).

### Stage 4 — Non-finite inputs and simulator contract (findings 6, 7)

Files: `simulateControlledModel.m`, `communityRhs.m`, `simulateCommunity.m`.

- Validate finiteness of states, times, controls, and required parameter fields
  before clipping; reject non-finite integration results rather than replacing
  them with plausible floors (fixes F6).
- `simulateCommunity`: evaluate the ODE solution at the requested sample times so
  the output-size contract holds for a two-element `tspan`; strengthen the
  simulator-agreement test to cover the two-time branch and the upper-level
  regime (2 h intervals, interpolated vs. zero-order-held inputs) (fixes F7).
- Verification: reproduce F6 (NaN inputs rejected) and F7 (two requested times →
  two rows); full test suite still passes.

### Stage 5 — Manuscript reassessment (follow-up, not in this PR)

- Numerical refinement study (RK4 substeps 4→8→16→64) documenting the
  reproduction-vs-continuous-accuracy gap and a recommended default.
- Propagation of Level 1 estimation error: generate Level 3/4 demonstrations from
  the ground-truth system and perform inversion with the estimated model,
  preferably with independent/noisy observations.
- Restate upper-level results as local, numerical equilibrium evidence
  (criterion 2) and Level 2 R² as in-sample (criterion 3).

---

## Deliverables

- Branch `fix/review-cdx-31aug26` with staged commits and a pull request into
  `main`.
- Updated sources and new regression tests (the four existing tests must continue
  to pass).
- Regenerated Level 2 results in new files; the historical reference is left
  untouched.
- `RESPONSE_CHANGES.md`: numeric deltas per stage.
- This document (`RESPONSE_PLAN.md`): the finding-by-finding fix description.
