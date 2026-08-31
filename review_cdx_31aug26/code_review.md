# MATLAB code review — 31 August 2026

Reviewed commit: `62ee2e679c8bee7d83cf61899fbdd0d46bbf76df`.

The standard synthetic case runs successfully. The review found nine reproducible correctness defects, principally in convergence certification, treatment of constrained optima, input validation, and Level 2 diagnostics. The P1 defects below were reproduced with specified configuration changes; they are not a claim that the default demonstrations fail. The Level 2 quadrature and validation issues are present in the standard workflow.

No repository source files or its existing MAT/PNG outputs were changed. Diagnostic files are separate from the package.

## Verification performed

- Executed MATLAB R2026a Update 1, version 26.1.0.3234472.
- Inspected all 19 MATLAB files and ran Code Analyzer across them: zero findings.
- Ran all four supplied unit tests: four passed.
- Ran the full workflow with `MakePlots=false, SaveResults=false`; initial measured runtime was 25.993 seconds.
- Checked required products: MATLAB, Optimization Toolbox, Signal Processing Toolbox, and Statistics and Machine Learning Toolbox.
- Examined planner exit flags, first-order optimality, active bounds, Nash stopping conditions and unilateral deviations.
- Repeated default unilateral best responses from five additional starting points per player per experiment.
- Compared RK4 with independent, tightly toleranced ode15s solves restarted at every piecewise-constant control boundary, and refined RK4 through 4, 8, 16 and 64 substeps.
- Probed bound-only optimal controls, deliberately exhausted optimization budgets, small damping, underdetermined stationarity matrices, NaN inputs, two observation times, zero-noise discovery, and overlapping cross-validation windows.

Baseline results reproduced:

| Quantity | Observed |
|---|---:|
| Level 1 RMS relative parameter error | 0.00572 (0.572%) |
| Level 2 in-sample integrated-growth R², strains 1 / 2 | 0.950 / 0.946 |
| Level 3 objective weight error | 0.0157 |
| Level 3 mean control RMSE | 2.90e-5 |
| Level 4 player weight errors | 0.0100 / 0.00107 |
| Level 4 mean control RMSE | 0.00136 |

All default Level 3 demonstration and validation exit flags were positive. All default Level 4 runs passed both the update and unilateral-improvement checks. Additional best-response starts did not reveal improvements exceeding 4.39e-7, below the configured 1e-4 threshold. This is numerical evidence for these cases, not a global-equilibrium proof.

## Findings, ordered by priority

P1 means a high-impact defect that can silently invalidate an inference or convergence claim under supported parameter choices. P2 means a correctness or validation defect that should be addressed before extending the study or relying on the relevant diagnostic. No P0 failure was found.

### 1. P1 — Small damping can falsely certify Nash convergence

Location: [solveOpenLoopNash.m:30](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/solveOpenLoopNash.m#L30), [solveOpenLoopNash.m:58](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/solveOpenLoopNash.m#L58).

The stopping quantity measures the *damped change between iterates*. Making the damping small automatically makes this quantity small, even when a player's best response is far away. The final Boolean uses OR, so the small-update condition overrides a failed unilateral-improvement check.

Reproduction: change only `cfg.level4.damping=0.001`, and solve the default first experiment with the calibrated model and true player weights.

Observed: `converged=true` after one iteration; update gap 0.00104065, below 0.003. The two unilateral objective improvements are 0.0793999 and 0.0727929, approximately 794 and 728 times the permitted 0.0001.

The convergence certificate should require a successful unilateral optimality check; a small damped update alone is insufficient. Because fmincon provides local solves, the certificate should also state its local numerical scope.

### 2. P1 — Bound-active controls are incorrectly treated as interior stationary controls

Locations: [runLevel3InverseOptimalControl.m:21](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runLevel3InverseOptimalControl.m#L21) and [runLevel4InverseDifferentialGame.m:25](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runLevel4InverseDifferentialGame.m#L25).

Both routines first exclude controls near active bounds, but restore *all* controls whenever fewer than four interior controls remain. The restored rows are then constrained towards zero gradients. At a constrained optimum, a lower-bound derivative may be positive and an upper-bound derivative negative; neither must be zero. The fallback can therefore reject the true objective even for an exactly solved, noiseless demonstration.

Reproduction: set `cfg.level3.trueWeights=[0;1;0;0]`, so the planner minimizes only quadratic control effort. Both demonstration solvers converge with every control exactly 0.02.

Observed: the true weights have a nonzero stationarity residual, 0.0142128. Inference returns approximately `[0,0.942477,0.0575228,0]`, weight error 0.0813497, and mean forward control RMSE 0.00476334. It incorrectly adds a residual-substrate preference.

The inverse formulation needs the appropriate bound-gradient inequalities/KKT conditions, or must use only interior rows and report inadequate information. Having few interior rows does not justify applying unconstrained stationarity to bound rows.

### 3. P1 — Failed forward solves are still used as demonstrations and validation

Locations: [runLevel3InverseOptimalControl.m:12](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runLevel3InverseOptimalControl.m#L12), [runLevel4InverseDifferentialGame.m:12](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runLevel4InverseDifferentialGame.m#L12), [runInverseLadderCaseStudy.m:25](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runInverseLadderCaseStudy.m#L25). Best-response fmincon status outputs are also discarded at [solveOpenLoopNash.m:28](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/solveOpenLoopNash.m#L28) and [solveOpenLoopNash.m:53](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/solveOpenLoopNash.m#L53).

The pipeline does not reject unsuccessful optimization before interpreting controls as optimal/equilibrium behavior. Re-optimization also does not gate reported errors on solver success. Solver status is sometimes stored, but downstream routines and the top-level success message do not enforce it.

Reproduction A: set `cfg.optimization.maximumIterations=0` and run Level 3. Both the demonstration and validation retain the initial guess. The result has planner exit flag 0, mean control RMSE exactly 0, and weight error approximately 0.8066. Thus “perfect reproduction” can result from two failed solves.

Reproduction B: set `cfg.level4.maximumBestResponseIterations=1` and run Level 4. Both demonstrations and both validations have `converged=false`, yet weights and ordinary validation metrics are returned.

This issue is distinct from finding 1: even an accurate failure flag is ineffective if the pipeline ignores it. Numerical success and finite outputs must be checked before inference and before interpreting validation errors.

### 4. P2 — Integrated model discovery uses the wrong input convention at control switches

Location: [runLevel2ModelDiscovery.m:41](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runLevel2ModelDiscovery.m#L41) and [runLevel2ModelDiscovery.m:53](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runLevel2ModelDiscovery.m#L53). Data generation uses zero-order-held controls at [generateCalibrationData.m:21](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/generateCalibrationData.m#L21).

Calibration trajectories are generated with a constant control on each observation interval. Level 2 evaluates candidates at grid nodes and applies trapezoidal quadrature, including to `Monod*allocation` and `allocation`. This averages the pre-switch and post-switch controls over an interval where the simulated input was constant. The input immediately at a window's right endpoint incorrectly receives a nonzero integration weight.

To isolate this from LASSO and smoothing, I evaluated the true growth equation using the noise-free states and true coefficients. Original integrated-growth residual RMS values were 0.004190 and 0.002960 h^-1. Keeping the left-held input on each interval while trapezoidally averaging only the continuous Monod factor reduced them to 0.000568 and 0.000474 h^-1 — improvements of about 7.4x and 6.2x.

The remaining error includes state/quadrature discretization. The experiment does not prove that changing input quadrature alone will recover the correct sparse model. It does establish a systematic discretization inconsistency that can affect coefficient and support selection.

### 5. P2 — Cross-validation splits overlapping windows and does not measure independent prediction

Location: [runLevel2ModelDiscovery.m:45](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runLevel2ModelDiscovery.m#L45) and [runLevel2ModelDiscovery.m:62](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runLevel2ModelDiscovery.m#L62).

Adjacent regression rows share four of their five time points. The code then randomly partitions those rows into five folds. Consequently, training and validation features/responses reuse the same underlying measurements. Savitzky-Golay smoothing over the full experiment adds another source of shared information.

For a reproducible equivalent five-fold partition (`rng(314)`), 100% of validation windows in both strains shared raw time points with at least one training window. Furthermore, the reported `fitR2` is evaluated on the complete fitted design matrix; it is an in-sample integrated-growth statistic, not held-out trajectory prediction.

Use independent experiments, or appropriately separated temporal blocks with preprocessing done inside the training partition, when assessing predictive/generalization performance. The present R² values can describe fit, but cannot substantiate independent prediction or structural identifiability.

### 6. P2 — Nonfinite inputs can silently become apparently valid trajectories

Locations: [simulateControlledModel.m:7](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/simulateControlledModel.m#L7), [simulateControlledModel.m:16](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/simulateControlledModel.m#L16), [simulateControlledModel.m:43](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/simulateControlledModel.m#L43), and [communityRhs.m:7](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/communityRhs.m#L7).

Arguments accept nonfinite doubles. The monotonicity test does not reject NaN time differences, and the numerical clipping operations mask missing values in this MATLAB version.

Reproduction: `simulateControlledModel(p,x0,[0 NaN 2],0.35*ones(2,2),4)`.

Observed: all returned values are finite, with the terminal state equal to `[1e-10,1e-10,1e-10,1e-10,1e-10]`. A NaN allocation also produces finite states. Passing a NaN biomass directly to `communityRhs` gives a finite derivative as the NaN is effectively replaced by zero.

This can hide malformed data or upstream numerical failures. Validate finite states, times, controls, and relevant parameter fields before clipping; reject nonfinite integration results rather than replacing them with plausible floors.

### 7. P2 — Adaptive simulation violates its output-size contract for two requested times

Location: [simulateCommunity.m:26](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/simulateCommunity.m#L26).

The function promises one output row per requested sample time. With a two-element tspan, ode15s instead returns its adaptive output mesh; the wrapper forwards all these rows.

Reproduction: `simulateCommunity(p,x0,[0 1],[0 1],0.35*ones(2,2))`.

Observed: a 28-by-5 result for two requested times, rather than 2-by-5. The current simulator-comparison test uses 13 sample times and misses this branch.

Explicit evaluation of the ODE solution at the requested sample times is needed to honor the wrapper's contract.

### 8. P2 — “Support recovered” can be true while the model contains spurious terms

Location: [runLevel2ModelDiscovery.m:85](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runLevel2ModelDiscovery.m#L85).

`supportRecovered` checks only that the first two library entries are selected. It ignores all five entries that should be absent; `expectedSupport` is not used in the comparison.

Reproduction: generate zero-noise calibration data and call Level 2 with the true parameters. Both correct terms are selected, but strain 2 additionally selects the standalone allocation term with coefficient approximately -0.0161000.

Observed: `supportRecovered=true` with one false-positive term.

Exact support recovery should compare the complete selected mask with the expected mask. If the desired metric is only recovery of the true terms, it should be named accordingly and accompanied by false-positive counts. Coefficient signs and coefficient accuracy are separate diagnostics.

### 9. P2 — Underdetermined objectives can receive an infinite separation diagnostic

Location: [inferSimplexWeights.m:16](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/inferSimplexWeights.m#L16).

The singular-value vector for a wide matrix does not include all its null directions. Additionally, zero or one returned singular values trigger `nullspaceSeparation=Inf`, including cases with insufficient information.

Reproduction: `inferSimplexWeights([1 -1 0 0],cfg)`.

Observed: rank 1, four weights, weights `[0.25,0.25,0.25,0.25]`, and infinite separation. The constraints only require `w1=w2` and normalization, leaving two degrees of freedom in the simplex. The uniform answer is selected by regularization, not identified by the observations.

Rank, nullity and the normalized feasible set must be considered explicitly. An informative gap cannot be reported as infinite merely because the matrix has one row. The default matrices have sufficient rows; this finding applies when demonstrations or usable derivative rows are reduced.

## Additional scientific and numerical limitations

These are separate from the nine reproduced implementation defects above.

### The workflow does not test propagation of kinetic-model uncertainty

[runInverseLadderCaseStudy.m:36](https://github.com/cblmbg/inverseproblemsbiocybernetics/blob/62ee2e679c8bee7d83cf61899fbdd0d46bbf76df/runInverseLadderCaseStudy.m#L36) passes the estimated parameters to both upper-level routines. Each routine generates its synthetic demonstrations with those same parameters and uses them again for inference and forward validation. The experiment is therefore internally consistent by construction; the mismatch between estimated and true kinetics is not challenged at Levels 3 and 4.

This is a valid conditional demonstration, but it cannot establish robustness of inferred objectives to Level 1 estimation error. Such a study needs demonstrations generated with the ground-truth system and inverse calculations using the estimated model, preferably with independent/noisy observations.

### Reproduction accuracy is not the same as continuous-model numerical accuracy

The default RK4 uses four substeps per two-hour upper-level control interval. Independent ode15s integration, restarted at every control switch, gave the following Level 3 state differences:

| Experiment | RK4 4-substep RMS | RK4 4-substep maximum absolute error | RK4 64-substep RMS |
|---|---:|---:|---:|
| 1 | 4.114e-4 | 2.481e-3 | 6.647e-9 |
| 2 | 8.018e-4 | 4.880e-3 | 9.280e-9 |

These errors exceed the reported Level 3 state reproduction errors, which are approximately 5.2e-5 and 2.0e-5. This does not invalidate agreement between two runs of the discrete implementation. It limits claims about accuracy against the continuous ODE and motivates checking inferred weights/objectives under both state-integration and objective-quadrature refinement.

The current simulator unit test is less demanding than the upper-level use case: it uses 0.5-hour output intervals, eight RK4 substeps, constant controls and a six-hour horizon.

### The two simulation interfaces represent different control signals

`simulateCommunity` linearly interpolates sampled controls; `simulateControlledModel` holds each interval's control constant. This is documented in their comments, so it is not itself counted as a bug. They cannot be interchanged merely to change ODE solvers.

On the three default calibration experiments, the RMS difference between linear-input and zero-order-held simulations was approximately 0.0427, 0.0516 and 0.0402. The existing constant-control test cannot reveal this distinction.

### Numerical best-response searches do not certify global Nash equilibria

Every unilateral optimization uses local SQP. Five additional starts per player/experiment supported the default solutions, but finite multistart searches do not establish global best responses or uniqueness. Reports should describe the resulting equilibrium evidence as numerical and local unless stronger guarantees are supplied.

### Lower-priority robustness observations

- Configuration fields lack domain checks: zero/negative iteration counts, no calibration starts, empty experiments, insufficient observation counts and invalid time horizons are not handled consistently.
- Level 2 assumes equally spaced observations for its Savitzky-Golay smoothing, while its interface does not enforce this. It also ignores its configuration argument and depends on the current global RNG state for LASSO folds.
- RK4 flooring injects a positive population into an exactly absent strain. With initial strain-1 biomass zero, the two-hour output was 1.11e-10 instead of exactly zero. The magnitude is tiny here, but exact extinction is an invariant of the stated ODE.
- Nonnegativity tests alone cannot assess integration accuracy because every RK4 step clips states to positive values.
- The console labels Level 2's statistic “derivative-fit R²”; its response is actually a window-averaged per-capita growth rate.

## Correction to the earlier preliminary review

The README is valid UTF-8. The apparent corrupted characters in the earlier review were caused by reading it with PowerShell's default encoding, not by corruption in the repository. That earlier finding is withdrawn. The README's three toolbox dependencies agree with MATLAB dependency analysis.

## Reproduce and inspect the evidence

In this output directory, run:

```matlab
audit = reproduce_review;
```

Or supply a different checkout:

```matlab
audit = reproduce_review("C:/path/to/inverseproblemsbiocybernetics");
```

The runner restores MATLAB's search path and RNG state, disables the package's saving/plotting, and returns the diagnostics in a struct. It intentionally displays the defective behavior rather than treating those behaviors as passing regression tests.

Companion files:

- `reproduce_review.m`: standalone MATLAB reproduction code, including numerical-reference and discovery helpers.
- `review_execution_log.txt`: captured MATLAB summary of the delivered runner's returned diagnostics.
- `review_evidence.mat`: baseline results, supplied test results and diagnostic experiment outputs.

A review does not exhaust all possible parameter combinations or establish global optimality. The findings distinguish directly reproduced errors, static control-flow evidence and broader validation limitations.
