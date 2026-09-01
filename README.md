# Inverse Ladder Microbial Community Case Study

This repository contains a reproducible MATLAB implementation of the four-level
inverse-problem hierarchy described in the accompanying manuscript,
*A Hierarchical Framework for Inverse Problems in Biological Cybernetics*. The
goal is to illustrate all four levels of the inverse-problem ladder with a
single biological system, together with a complete MATLAB implementation.

The biological system is a synthetic two-strain microbial consortium that
competes for a shared substrate and reciprocally exchanges essential
metabolites.

## Requirements

The implementation was developed for MATLAB R2026a and directly requires:

- Optimization Toolbox (`lsqnonlin`, `lsqlin`, `fmincon`)
- Statistics and Machine Learning Toolbox (`lasso`)
- Signal Processing Toolbox (`sgolayfilt`)
- Symbolic Math Toolbox (required by the STRIKE-GOLDD toolbox)

Adaptive integration uses base-MATLAB `ode15s`. No other toolboxes are
required; in particular the Global Optimization Toolbox and Control System
Toolbox are **not** used by this implementation.

## Repository

The primary, authoritative repository is on GitHub. A mirror is kept on the
CSIC GitLab instance and updated manually when needed:

```text
GitHub (primary):  https://github.com/cblmbg/inverseproblemsbiocybernetics.git
GitLab (mirror):   https://git.csic.es/xeon4/inverseproblemsbiocybernetics.git
```

## Biological case study

Both strains consume a shared substrate and reciprocally secrete metabolites
that support the partner's growth. The dynamic state contains the two
biomasses, the shared substrate, and the two exchanged metabolites:

```text
x(t) = [X1(t), X2(t), S(t), M1(t), M2(t)]^T.
```

Each strain also has an allocation variable `u_i(t)`, representing the
effective fraction of metabolic resources allocated to secretion rather than
instantaneous growth. This common model supports four progressively more
interpretive inverse problems:

1. **Level 1 — parameter estimation:** estimate six kinetic parameters from
   noisy dynamic data while treating the allocation schedules as known
   experimental inputs. 
2. **Level 2 — model discovery:** infer sparse per-capita growth laws from
   observations and known allocation schedules.
3. **Level 3 — inverse optimal control:** treat allocation as endogenous and
   infer a centralized community-level objective that is compatible with the
   observed behavior.
4. **Level 4 — inverse differential game:** treat each strain as an independent
   player and infer two strain-specific objectives from an open-loop Nash
   equilibrium.

The report distinguishes carefully between exogenous allocation signals at
Levels 1–2 and endogenous decisions at Levels 3–4. Exogenous actuation is not
mathematically mandatory for Levels 1–2, but it can improve excitation and
identifiability. The laboratory interpretation is an engineered consortium in
which pathway activity is driven by calibrated inducer or optogenetic signals.
A measured, naturally occurring allocation trajectory could also be used,
provided its measurement uncertainty and possible state dependence are handled
explicitly.

## MATLAB implementation

The top-level entry point is:

```matlab
results = runInverseLadderCaseStudy;
```

The implementation includes:

- the community ODE model and simulation utilities;
- structural local identifiability and observability analysis with the STRIKE-GOLDD toolbox;
- synthetic calibration experiments with rich allocation perturbations;
- constrained kinetic-parameter estimation;
- sparse model discovery using smoothing, window-integrated growth,
  cross-validated LASSO, and coefficient thresholding;
- a centralized forward optimal-control solver;
- inverse recovery of simplex-normalized community objective weights;
- cold-start forward validation of the inferred community objective, using the
  uniform default allocation rather than the demonstrated controls;
- an open-loop Nash solver based on damped iterative best response;
- inverse recovery of player-specific objective weights;
- cold-start forward validation of the inferred player objectives, again using
  the uniform default allocation rather than the demonstrated controls;
- plotting, saved result files, and automated tests.

Two numerical integration modes are provided:

- `ode15s` for robust adaptive simulation of the continuous ODE model;
- fixed-step fourth-order Runge–Kutta for repeated optimization evaluations,
  where deterministic discretization and predictable computational cost are
  useful.

The model-discovery method is related to weak SINDy because it avoids direct
pointwise differentiation and instead uses an integrated growth relation. It is
best described as a restricted weak-form sparse regression method: it uses fixed
integration windows rather than the general family of smooth test functions used
by full weak SINDy.

The Level 3 implementation is not the full bilevel inverse optimal-control
formulation proposed by Tsiantis, Balsa-Canto, and Banga (2018). It assumes that
the kinetic model and endogenous demonstrations are already known, replaces the
inner optimal-control problem by first-order stationarity conditions, and solves
a constrained linear least-squares problem. Forward re-optimization is then used
for validation. The report explains the computational advantage and the weaker
guarantees of this stationarity-based approach.

## Run the complete case study

```matlab
results = runInverseLadderCaseStudy;
```

This command:

1. analyses the structural local identifiability and observability of several model variants;
2. generates noisy synthetic experiments;
3. estimates six kinetic parameters;
4. discovers a sparse biomass growth law;
5. infers a centralized community objective using inverse stationarity;
6. infers strain-specific objectives from an open-loop Nash equilibrium;
7. performs forward validation and creates a summary figure.

The run saves `inverse_ladder_results.mat` and `inverse_ladder_summary.png` in
this folder. To suppress files and graphics:

```matlab
results = runInverseLadderCaseStudy( ...
    "MakePlots", false, "SaveResults", false);
```

Step 1 runs the STRIKE-GOLDD structural analyses and is by far the slowest part
of the workflow (several minutes). It is performed by
`runLevel1aprioriIdentifiability`, which restores the caller's session state
(working directory, path, warnings, and global variables) on return. With
`SaveResults` false this stage is non-mutating: it leaves the toolbox's results
folder exactly as found and writes no persistent files.

## Tests

```matlab
runtests("testInverseLadderCaseStudy.m")
```

The tests verify model dimensions and finiteness, nonnegative simulation,
agreement between the `ode15s` and RK4 simulations, and constrained recovery of
a known simplex-normalized objective, together with regression tests for the
solver-success and Nash-feasibility certificates, the objective-identifiability
diagnostics, non-finite input handling, and the Level 2 support and
cross-validation metrics. The last MATLAB verification reported 18 of 18 unit
tests passing and no MATLAB Code Analyzer findings.

## Results summary

The full workflow was executed in MATLAB and produces `inverse_ladder_results.mat`
and `inverse_ladder_summary.png`, a four-panel summary covering all four levels
(the Level 1 parameter estimates, the Level 2 discovered-coefficient heat map,
and the Level 3 and Level 4 objective weights). The synthetic study showed that:

- the kinetic parameters can be accurately calibrated under informative
  perturbations;
- sparse discovery reproduces the observed growth dynamics but exposes a
  structural ambiguity for one strain (a high predictive fit does not guarantee
  recovery of the correct mechanism);
- the centralized inverse-optimal-control formulation recovers an objective that
  reproduces the observed controls and states from an independent cold-start
  forward solve;
- the inverse-game formulation recovers player-specific objectives and
  reproduces the equilibrium behavior.

Selected numerical diagnostics (full tables are given in the accompanying
manuscript):

- Level 1 uses two truth-independent initial guesses; additional random starts
  converge to the same optimum, so the estimate is not an artifact of an oracle
  initialization. The realized calibration allocation ranges are
  `u1 ∈ [0.130, 0.730]` and `u2 ∈ [0.150, 0.730]`; the nominal clamp limits are
  never reached.
- Level 2 selects a sparse growth law by leave-one-experiment-out
  cross-validation. The in-sample integrated-growth R² is about 0.96 and 0.94
  for the two strains, and the held-out prediction R² about 0.94 and 0.96.
  Strain 1 recovers the true Monod terms, while strain 2 selects a spurious
  allocation term, so exact support recovery is not achieved — a good predictive
  fit with the wrong mechanism.
- Level 3 forward validation is cold-started from `u1 = u2 = 0.35`. The two
  validation solves reproduce the demonstrations with control and state RMSEs of
  order `10^-5`, and the inverse-stationarity spectral gap (nullspace-separation
  ratio ≈ 6×10^2) supports a locally identifiable normalized objective.
- Level 4 demonstration and cold-start validation solves satisfy the
  `3×10^-3` best-response tolerance within the 20-iteration cap. Certification
  now *requires* the unilateral-deviation check (each player re-optimized
  against the same final joint profile) together with successful, feasible
  solves; the damped-iterate change is retained only as a diagnostic and is no
  longer sufficient on its own. Cold-start validation gives mean control and
  state RMSEs of about `1.4×10^-3` and `2.4×10^-3`.

The upper-level demonstrations use two initial states and a 16 h horizon divided
into eight 2 h control intervals. These are distinct from the three calibration
experiments used at Levels 1 and 2.

## Identifiability and observability

The accompanying manuscript analyses the identifiability of the case study
explicitly. For a given observation function `y(t) = g(x(t), u(t), θ)`, local
identifiability is
related to the rank and conditioning of the stacked parameter-sensitivity
matrix; the same construction, with the parameter vector augmented by the
states, also assesses observability of the unmeasured states.

- **Structural identifiability.** If all five states can be measured, the 16
  model parameters are structurally locally identifiable. It suffices to measure
  the substrate `S`, the sum of the strains `X1 + X2`, and the sum of
  metabolites `M1 + M2`; measuring only a single strain instead of the sum makes
  some parameters unidentifiable (the structural identifiability limit). To stay
  well away from this limit, the case study assumes full-state measurement and
  focuses on six of the parameters. These structural results are reproduced in
  code by `runLevel1aprioriIdentifiability`, which runs the STRIKE-GOLDD toolbox
  on the three observation configurations at the start of the workflow.
- **Practical identifiability.** With the baseline noise level (0.5% of the
  maximum state scale) the RMS relative parameter error is about 0.57%.
  Increasing the Gaussian noise to 5%, 10%, and 20% raises the error to roughly
  7.5%, 17%, and 35% respectively, with the allocation cost `c2` most affected —
  illustrating how the noise level sets a practical identifiability limit.

At the upper levels, objective recovery is generally non-unique. The right
singular vectors of the inverse-stationarity matrix represent directions in
objective-weight space, and the associated singular values measure how strongly
those directions violate the observed stationarity conditions. An isolated
near-zero value supports a locally identifiable normalized objective direction,
whereas several comparable small values would indicate practical
non-identifiability. The reported spectral gap is a local diagnostic, not a
global proof of identifiability.

## Technical report and manuscript

The technical report and the accompanying manuscript are maintained separately
and are not tracked in this repository, which now holds the MATLAB
implementation only. That report documents the model definition, parameter
units, algorithms, pseudocode for every level, tables of results, validation
figures, an expanded discussion of structural and practical identifiability and
observability, and limitations.

## Interpretation

Level 3 treats the consortium as a centralized planner. Level 4 treats each
strain as an independent player. Both levels use normalized candidate cost
kernels, inverse first-order optimality conditions, and forward validation. The
implementation intentionally exposes rank diagnostics and prediction errors
because objective recovery is generally non-unique.
