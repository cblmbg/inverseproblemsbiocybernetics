# Verification review of fix/review-cdx-31aug26

Reviewed commit: `4b670b184aa54086ee91669a69a3a453fa5a0719` (31 August 2026 review session).

## Assessment

The branch makes substantive improvements and reproduces its reported 11/11 passing unit tests and zero analyzer findings. The default Level 1, 3, and 4 metrics reproduce; the revised Level 2 metrics reproduce too.

I cannot endorse the statement that all nine findings are fully closed. Several exact original reproductions now behave correctly, but three material acceptance gaps remain: infeasible profiles can receive a verified Nash certificate, the new rank-based identifiability flag can be wrong under normalization, and nonfinite kinetic parameters can still be silently accepted. Failed demonstrations also still enter inference, and two new edge-case regressions are present.

This was a read-only code review in an isolated detached checkout. No fix-branch or main-branch source changes were made, no PR was created or merged, and nothing from this review was pushed. Full KKT treatment and Stage 5 manuscript work were explicitly deferred and are not being counted as missing work in this PR.

## What was independently verified

Environment: MATLAB 26.1.0.3234472 (R2026a) Update 1.

- Read RESPONSE.md, RESPONSE_CHANGES.md, RESPONSE_PLAN.md and the changed source files.
- Code Analyzer: 19 MATLAB source files, zero findings.
- Supplied tests: 11 passed, zero failed.
- Default workflow run with MakePlots=false and SaveResults=false.
- Original small-damping example: now unverified, maximum unilateral improvement 0.0793999.
- Original bound-only planner example: zero interior rows, identifiable=false, uniform prior weights.
- Original zero-iteration planner example: unverified, reproduction RMSEs NaN.
- Original one-iteration game example: unverified, reproduction RMSEs NaN.
- Original one-row/four-weight example: rank 1, nullity 3, finite separation 0, identifiable=false.
- Finite-input validators and two-time output contract pass the supplied regression tests.
- Reviewed the new left-held quadrature and full support-mask logic directly.
- Confirmed separate holdout initial states and random seed, and experiment-grouped model selection.

Reproduced headline metrics:

| Quantity | Verified result |
|---|---:|
| Level 1 RMS relative parameter error | 0.00572 |
| Level 2 in-sample integrated-growth R² | approximately 0.957 / 0.942 |
| Level 2 held-out integrated-growth R² | approximately 0.943 / 0.962 |
| Level 2 exact support recovery, both strains | false |
| Level 3 weight error | 0.0157 |
| Level 3 mean control RMSE | 2.90e-5 |
| Level 4 player weight errors | 0.0100 / 0.00107 |
| Level 4 mean control RMSE | 0.00136 |

## Remaining findings, ordered by priority

### R1. P1 — The Nash certificate still accepts infeasible joint profiles

Locations: [solveOpenLoopNash.m:13](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/solveOpenLoopNash.m#L13), [solveOpenLoopNash.m:41](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/solveOpenLoopNash.m#L41), [solveOpenLoopNash.m:78](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/solveOpenLoopNash.m#L78).

The revised certificate requires positive final exit flags and finite current states/controls, but does not check the feasibility of the profile being certified. fmincon adjusts an infeasible starting guess during each best response; the damping step then mixes that feasible response with the unchanged, infeasible previous control.

Reproduction uses the default calibrated model, time grid and damping, with:

```matlab
cfg.control.initialGuess = 0;
weights = [0 0; 1 1; 0 0; 0 0];
s = solveOpenLoopNash(p, cfg.defaultInitialState, ...
    cfg.control.timeGrid, weights, cfg);
```

Observed:

- Every returned control is 0.019699875, below the lower bound of 0.02.
- Maximum bound violation: 0.000300125.
- Both final fmincon exit flags are 1.
- Both reported unilateral improvements are zero.
- status="verified" and converged=true.

This happens because the infeasible profile has less control effort than any feasible alternative. The current-versus-best-response objective difference is negative and is clipped to zero, so passing the deviation check cannot establish feasibility.

Project or reject the initial profile, preserve bounds during updates, and explicitly verify the final joint profile's constraints before certification. This is within the agreed solver-success acceptance criteria, not the deferred KKT work.

The related planner success test at [solveCommunityPlanner.m:35](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/solveCommunityPlanner.m#L35) also checks only positive exit status and finite states/controls. The agreed checks of relevant optimality diagnostics and feasibility have not been implemented. In the Nash solver, the final optimizer's output struct and returned control vector are discarded, so those checks cannot currently be performed. Suitable scale-aware tolerances should be used; positive exit flags alone are not a substitute.

### R2. P2 — Rank(A) ≥ n−1 does not establish identification under simplex normalization

Location: [inferSimplexWeights.m:35](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/inferSimplexWeights.m#L35).

The code counts independent stationarity rows but does not check whether normalization contributes an independent constraint, nor does it test the data's information on the simplex tangent space.

Counterexample:

```matlab
A = [1 1 1 1; 1 -1 0 0; 0 0 1 -1];
r = inferSimplexWeights(A, cfg);
w1 = [.1; .1; .4; .4];
w2 = [.4; .4; .1; .1];
```

Observed: rank(A)=3, but rank([A;ones(1,4)]) is also 3. Both w1 and w2 are strictly positive normalized weights and give identical A*w values. In fact the continuum [a;a;0.5-a;0.5-a], for 0≤a≤0.5, has the same data least-squares objective. The regularizer picks the uniform member of that continuum.

Nevertheless, locallyIdentifiable=true.

This example is also incompatible with exact zero stationarity, since A's first row equals the normalization row. That should be detected or reflected in diagnostics, not converted into a claim of identification. The least-squares fit itself remains nonunique before regularization.

For interior weights, inspect the data matrix restricted to directions with sum(delta_w)=0, or an equivalent augmented-rank test, together with conditioning and stationarity residuals. Boundary solutions require accounting for the feasible directions/nonnegative constraints. A uniqueness guarantee supplied solely by the regularizer is not data identification.

Padding the wide-matrix singular spectrum correctly fixes the original infinite-gap reproduction, but this new Boolean still overstates what the data identify.

### R3. P2 — Nonfinite kinetic parameters and direct RHS inputs remain silently masked

Locations: [simulateControlledModel.m:8](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/simulateControlledModel.m#L8), [simulateCommunity.m:8](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/simulateCommunity.m#L8), [communityRhs.m:10](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/communityRhs.m#L10), [communityRhs.m:28](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/communityRhs.m#L28).

State, time and control array validation is improved, but required fields of the parameters struct are unchecked. The unchanged allocation-factor max operation still replaces a NaN with the 0.05 floor.

Reproduction:

```matlab
p.allocationCost(1) = NaN;
x = simulateControlledModel(p, x0, [0 1 2], .35*ones(2,2), 4);
y = simulateCommunity(p, x0, [0 1 2], [0 1 2], .35*ones(3,2));
```

Observed: both simulators return finite trajectories without an error. The bad parameter has changed the model instead of being rejected.

The RHS comment that “a NaN or Inf is left in place” is also inaccurate: communityRhs(0,x0,[Inf;.35],p) gives the same finite derivative as the control [1;.35], because Inf is clipped to 1. Negative infinity in a state is likewise clipped by x(x<0)=0.

Validate all required kinetic fields and direct RHS inputs before saturating values. The original NaN time/control cases are fixed, but the broader nonfinite-input finding and explicit Stage 4 acceptance criterion are only partially addressed.

### R4. P2 — Failure flags mask RMSEs, but failed demonstrations still enter inference

Locations: [runLevel3InverseOptimalControl.m:14](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/runLevel3InverseOptimalControl.m#L14), [runLevel3InverseOptimalControl.m:30](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/runLevel3InverseOptimalControl.m#L30), [runLevel4InverseDifferentialGame.m:15](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/runLevel4InverseDifferentialGame.m#L15), [runLevel4InverseDifferentialGame.m:34](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/runLevel4InverseDifferentialGame.m#L34).

The demonstration-success flags are stored, but are not used to skip/reject the corresponding Jacobians. Every returned control profile is differentiated and pooled into the inverse matrix regardless of whether the generating optimization succeeded.

With cfg.optimization.maximumIterations=0, the Level 3 result has:

- demonstrationSuccess=[false false];
- 32 inverse stationarity rows assembled from those failures;
- inverse matrix rank 4 and identifiable=true;
- inferred weights approximately [0,0.436912,0.552460,0.010629];
- status="unverified" and NaN reproduction RMSEs.

The warning and NaN metrics are a real improvement: this is no longer an unqualified global success claim. However, this is reporting a failed inference, rather than gating inference as RESPONSE_PLAN.md specifies. With a mixture of successful and failed demonstrations, failed rows can influence the weights and thus the metrics of otherwise successful experiments.

Reject invalid demonstrations before forming the inverse problem, or explicitly opt into a partial-data policy and use only successful demonstrations. Assess information content on that valid subset. If no valid data remain, return an insufficient-data/unverified result instead of a data-identification claim.

### R5. P2 — One available experiment silently skips every validation fold

Location: [runLevel2ModelDiscovery.m:161](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/runLevel2ModelDiscovery.m#L161) through the selection at [runLevel2ModelDiscovery.m:173](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/runLevel2ModelDiscovery.m#L173).

Leave-one-experiment-out selection requires at least two usable experiment groups. With only one group, all folds are skipped, validationCount remains zero, and crossValidatedMse becomes an all-NaN vector. min then selects a grid endpoint and the routine returns an ordinary model with selectedLambda, without reporting that cross-validation never occurred.

Reproduction:

```matlab
r = runLevel2ModelDiscovery(cfg, baseline.calibrationExperiments(1), p);
```

Observed: selected penalties approximately [1.00968e-5,1.09905e-5] and in-sample R² approximately [0.97336,0.86512], despite zero usable grouped-validation folds.

This does not affect the default three-experiment run. It is a regression for reduced datasets, including cases where filtering leaves only one usable group for a strain. Require enough usable groups or expose a deliberate no-CV/fixed-penalty fallback. Do not present a penalty as cross-validated when no fold ran.

### R6. P3 — One-feature inverse problems now crash

Location: [inferSimplexWeights.m:32](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/4b670b184aa54086ee91669a69a3a453fa5a0719/inferSimplexWeights.m#L32).

The separation calculation unconditionally accesses ascendingSpectrum(2). Consequently:

```matlab
inferSimplexWeights(zeros(3,1), cfg)
```

now throws MATLAB:badsubscript. A one-feature simplex has the unique weight 1 and needs a defined special case. The original implementation handled a single returned singular value; this regression was introduced by the revised diagnostic. It is outside the default four-feature case and lower priority than the findings above.

## Closure assessment for the original nine findings

| Original finding | Assessment at 4b670b1 |
|---|---|
| 1 — small damping falsely certifies Nash | Exact reproduction fixed. Broader certificate acceptance still has R1. |
| 2 — bound rows treated as interior | Agreed first pass implemented: no fallback, pooled genuine interior rows, zero-row case flagged. Full KKT remains deferred. |
| 3 — failed solver results accepted | Partial: flags and NaN RMSEs added; feasibility/optimality acceptance and pre-inference gating remain incomplete (R1, R4). |
| 4 — wrong control quadrature | Corrected for the documented zero-order-held experiment inputs. |
| 5 — leaky folds and no independent validation data | Default grouped split and separate holdout experiments implemented. Reduced-data selection has new regression R5. |
| 6 — nonfinite inputs silently accepted | Time/state/control arrays guarded at simulator entry; parameter fields/direct RHS handling remain incomplete (R3). |
| 7 — two-time simulator contract | Fixed; two times return two rows. |
| 8 — support flag ignores false positives | Fixed by complete-mask metrics and false-positive/missed counts. |
| 9 — misleading underdetermined diagnostic | Original one-row gap fixed; normalized identifiability claim remains wrong in R2, with one-feature regression R6. |

## Documentation and interpretation corrections

- RESPONSE_CHANGES.md's Stage 3 table labels the default baseline supportRecovered as 1. It was false in the original default noisy run; the true-with-false-positive counterexample was the zero-noise experiment. Keep those two cases separate.
- The new holdout metrics assess integrated growth on separate experiments, conditional on measured/smoothed state features. They are not forward state-trajectory rollout metrics.
- Persistent selection of an incorrect library term with good fit supports a model-discovery ambiguity in these experiments. It does not by itself establish structural non-identifiability.
- The historical reproduce_review.m runner still contains the old NaN-input calls and will stop when the fixed simulator correctly rejects them. Keep it as a historical reproducer or provide a clearly separate fix-verification runner rather than implying it completes unchanged on the fixed code.

## Integration scope

At review time origin/main was 897e2a7 and had four additional commits beyond the shared 272b83e base, including STRIKE-GOLDD and a new runLevel1aprioriIdentifiability call in the top-level workflow.

A git merge-tree simulation reported a clean textual merge. No branch was merged. The MATLAB executions above test the fix branch itself, not the merged tree with the new structural-identifiability stage. Integration verification is still needed for that combined workflow. The “19 files / three toolboxes” statement here refers specifically to the fix checkout.

## Evidence and reproduction

The attached verify_fix_review.m diagnostic runner records the remaining counterexamples without editing the source. From a folder containing that runner:

```matlab
audit = verify_fix_review("C:/path/to/inverseproblemsbiocybernetics");
```

Use a checkout of commit 4b670b184aa54086ee91669a69a3a453fa5a0719 to reproduce this report. The runner restores path and RNG state and disables baseline file saving/plotting. Each probe records exceptions so that a future fix rejecting an invalid input does not stop all subsequent probes.

Companion files:

- verify_fix_review.m — standalone reproduction runner;
- fix_review_execution_log.txt — captured MATLAB execution;
- fix_review_evidence.mat — returned baseline, supplied-test and counterexample data.

Recommendation: address the remaining solver certificate, normalized-identifiability and nonfinite-parameter gaps before declaring the nine findings closed. The deferred KKT and Stage 5 work can remain separate.

