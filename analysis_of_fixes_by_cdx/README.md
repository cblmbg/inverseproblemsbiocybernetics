# Independent assessment of the review fixes

Reviewed branch: `fix/review-cdx-31aug26` at commit [`4b670b1`](https://github.com/cblmbg/inverseproblemsbiocybernetics/commit/4b670b184aa54086ee91669a69a3a453fa5a0719).

I confirmed **11/11 supplied tests pass**, zero analyzer findings, and the reported default results. However, I would **not yet close all nine original findings**.

## Remaining issues, ordered by priority

1. **P1 — An infeasible Nash profile can still be marked “verified.”** With an initial control guess of zero and effort-only objectives, returned controls are **0.019699875**, below the **0.02** lower bound. Both final exit flags are positive and deviation gaps are zero, so the new certificate incorrectly accepts the profile. Feasibility must be checked explicitly.

2. **P2 — The new identifiability flag does not correctly account for normalization.** `rank(A) >= numberOfFeatures-1` is insufficient when the normalization equation is dependent on existing rows. I reproduced `locallyIdentifiable=true` for a continuum of normalized weights giving identical predictions. Regularization selects one answer; the data do not identify it.

3. **P2 — Nonfinite kinetic parameters remain silently accepted.** Setting `p.allocationCost(1)=NaN` still produces finite trajectories in **both simulators**. The remaining `max(0.05, …)` masks the invalid parameter. State/time/control validation is improved, but parameter validation is incomplete.

4. **P2 — Failed demonstrations still enter the inverse calculation.** With zero planner iterations, both demonstrations fail, yet their controls generate **32 stationarity rows** and the result reports `identifiable=true`. The new `unverified` status and NaN RMSEs are improvements, but invalid demonstrations should be excluded or rejected before inference.

5. **P2 — One-experiment discovery silently selects a penalty without cross-validation.** Every grouped fold is skipped, leaving zero validation samples and NaN validation errors. The routine nevertheless selects a penalty and returns ordinary results.

6. **P3 — One-feature weight inference now crashes.** `inferSimplexWeights(zeros(3,1),cfg)` indexes the nonexistent second singular value. This is a new, lower-priority regression.

The original small-damping, bound-only, failed-solve RMSE, and one-row diagnostic examples now behave substantially better. Full KKT can remain deferred; the issues above concern the implemented safeguards and first-pass diagnostics.

## Included files

- [Full verification review](fix_branch_review.md): detailed evidence, source locations, closure assessment for all nine original findings, and interpretation corrections.
- [Reproduction script](verify_fix_review.m): standalone MATLAB diagnostic runner.
- [Execution log](fix_review_execution_log.txt): captured MATLAB execution of the runner on the reviewed commit.

These three files are preserved from the review. The full report also mentions a local `fix_review_evidence.mat` artifact; that binary is not part of this three-file bundle. The runner returns the evidence in its `audit` output, which can be saved if needed.

## Reproduction

With MATLAB's current folder set to this directory in a checkout containing the reviewed implementation:

```matlab
audit = verify_fix_review(fileparts(pwd));
```

For an exact historical reproduction, point the runner at a separate checkout of commit `4b670b184aa54086ee91669a69a3a453fa5a0719`:

```matlab
audit = verify_fix_review("C:/path/to/reviewed-checkout");
```

The runner disables baseline file saving and plotting, restores path and RNG state, and records probe exceptions so a rejection of invalid inputs does not stop the subsequent probes. It is a diagnostic runner, not a regression suite that treats the defects as correct behavior.

## Integration and publication scope

At review time, `main` had advanced to `897e2a7` with STRIKE-GOLDD additions. A merge simulation was clean, but the combined workflow was not tested here. The results above concern the fix branch at the pinned commit, not a merged tree or later changes.

This publication adds only this assessment and the three review artifacts. No implementation files are changed, and no PR is opened or merged by this publication.
