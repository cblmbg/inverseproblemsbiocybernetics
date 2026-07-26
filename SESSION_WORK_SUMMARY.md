# Session work summary

## Objective

This session developed a reproducible case study to accompany the manuscript
*A Hierarchical Framework for Inverse Problems in Biological Cybernetics*. The
goal was to illustrate all four levels of the inverse-problem ladder with one
biological system and to provide a complete MATLAB implementation and technical
report.

## Biological case study

The selected system is a synthetic two-strain microbial consortium. Both
strains consume a shared substrate and reciprocally secrete metabolites that
support the partner's growth. The dynamic state contains the two biomasses, the
shared substrate, and the two exchanged metabolites:

\[
x(t)=[X_1(t),X_2(t),S(t),M_1(t),M_2(t)]^{\mathsf T}.
\]

Each strain also has an allocation variable \(u_i(t)\), representing the
effective fraction of metabolic resources allocated to secretion rather than
instantaneous growth. This common model supports four progressively more
interpretive inverse problems:

1. **Level 1 -- parameter estimation:** estimate six kinetic parameters from
   noisy dynamic data while treating the allocation schedules as known
   experimental inputs.
2. **Level 2 -- model discovery:** infer sparse per-capita growth laws from
   observations and known allocation schedules.
3. **Level 3 -- inverse optimal control:** treat allocation as endogenous and
   infer a centralized community-level objective that is compatible with the
   observed behavior.
4. **Level 4 -- inverse differential game:** treat each strain as an
   independent player and infer two strain-specific objectives from an
   open-loop Nash equilibrium.

The report distinguishes carefully between exogenous allocation signals at
Levels 1--2 and endogenous decisions at Levels 3--4. Exogenous actuation is not
mathematically mandatory for Levels 1--2, but it can improve excitation and
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
- fixed-step fourth-order Runge--Kutta for repeated optimization evaluations,
  where deterministic discretization and predictable computational cost are
  useful.

The model-discovery method is related to weak SINDy because it avoids direct
pointwise differentiation and instead uses an integrated growth relation. It
is best described as a restricted weak-form sparse regression method: it uses
fixed integration windows rather than the general family of smooth test
functions used by full weak SINDy.

The Level 3 implementation is not the full bilevel inverse optimal-control
formulation proposed by Tsiantis, Balsa-Canto, and Banga (2018). It assumes that
the kinetic model and endogenous demonstrations are already known, replaces
the inner optimal-control problem by first-order stationarity conditions, and
solves a constrained linear least-squares problem. Forward re-optimization is
then used for validation. The report explains the computational advantage and
the weaker guarantees of this stationarity-based approach.

## Verification and results

The full workflow was executed in MATLAB and produces:

- `inverse_ladder_results.mat`;
- `inverse_ladder_summary.png`;
- detailed figures for Levels 1, 3, and 4.

The synthetic study showed that:

- the kinetic parameters can be accurately calibrated under informative
  perturbations;
- sparse discovery reproduces the observed growth dynamics but exposes a
  structural ambiguity for one strain;
- the centralized inverse-optimal-control formulation recovers an objective
  that reproduces the observed controls and states from an independent
  cold-start forward solve;
- the inverse-game formulation recovers player-specific objectives and
  reproduces the equilibrium behavior.

The automated MATLAB tests cover model dimensions and finiteness,
non-negativity, agreement between the two integration modes, and recovery of a
known simplex-normalized objective.

Subsequent numerical audits corrected several potentially misleading
validation details:

- Level 1 now uses two truth-independent initial guesses. Six additional random
  starts were also checked and converged to the same optimum, showing that the
  estimate is not an artifact of an oracle initialization.
- The realized calibration allocation ranges are reported from the actual data:
  \(u_1\in[0.130,0.730]\) and \(u_2\in[0.150,0.730]\). The nominal clamp limits
  are never reached.
- Level 3 forward validation is cold-started from \(u_1=u_2=0.35\). The two
  validation solves require 46 and 44 iterations. Their exact control RMSEs are
  \(4.4732\times10^{-5}\) and \(1.3230\times10^{-5}\), and their state RMSEs are
  \(5.1600\times10^{-5}\) and \(1.9610\times10^{-5}\). The report rounds these
  to two significant figures so harmless last-digit changes do not make the
  table stale.
- The Level 3 nullspace-separation ratio is 635.3 and is reported robustly as
  approximately \(6\times10^2\).
- Level 4 demonstration and cold-start validation solves both satisfy the
  primary \(3\times10^{-3}\) best-response tolerance after 16 of the 20 allowed
  iterations; they do not depend on the unilateral-improvement fallback.
- Level 4 cold-start validation gives control RMSEs
  \(1.5640\times10^{-3}\) and \(1.1655\times10^{-3}\), with mean
  \(1.3647\times10^{-3}\), and state RMSEs \(2.5089\times10^{-3}\) and
  \(2.2195\times10^{-3}\), with mean \(2.3642\times10^{-3}\).

The upper-level demonstrations use two initial states and a 16 h horizon
divided into eight 2 h control intervals. These are distinct from the three
calibration experiments used at Levels 1 and 2.

## Technical report

The report is stored in:

```text
report/inverse_ladder_case_study_report.tex
report/inverse_ladder_case_study_report.pdf
```

It contains the model definition, parameter units, algorithms, compact
pseudocode for every level, tables of results, validation figures, discussion
of identifiability, and limitations.

The report was polished during the session to:

- assign consistent units to all parameters;
- explain why two integrators are used;
- clarify the experimental meaning of prescribed allocation controls;
- distinguish exogenous inputs from endogenous behavior;
- explain when endogenous trajectories may suffice at Levels 1--2;
- relate the Level 2 procedure to weak SINDy;
- distinguish the Level 3 implementation from full bilevel inverse optimal
  control;
- cite all six bibliography entries in the text;
- replace a numerical, performance-oriented abstract with a clearer scientific
  summary;
- explain what the singular values of the inverse stationarity matrix
  represent;
- disclose the actual Level 4 iteration cap, primary convergence test, and
  unilateral-deviation certificate;
- document the Level 4 saturating metabolite-deficit feature
  \(0.35/(0.35+M_{\mathrm{received}})\) and the small conditioning
  regularizer added to the allocation-effort feature;
- state the upper-level horizon, control discretization, and number of
  demonstrations;
- remove the unused Global Optimization Toolbox requirement from the README;
- add a TikZ overview showing how the same biological system supports all four
  levels;
- make both Level 3 and Level 4 forward validations explicitly cold-started;
- update Level 3 numerical diagnostics using stable significant-figure
  reporting;
- enlarge the four-panel Level 3 figure to full text width and place it after
  its singular-value interpretation for legibility and narrative continuity.

For the singular-value interpretation, the report now explains that the right
singular vectors represent directions in objective-weight space and that the
associated singular values measure how strongly those directions violate the
observed stationarity conditions. An isolated near-zero value supports a
locally identifiable normalized objective direction, while several comparable
small values would indicate practical non-identifiability. The reported
spectral gap is presented as a local diagnostic rather than a global proof of
identifiability.

The current report has 20 pages. It was compiled repeatedly with `pdflatex`,
checked for undefined citations and references and for layout warnings, and
visually inspected after the substantive revisions.

The final MATLAB verification reported four of four unit tests passing and no
MATLAB Code Analyzer findings. The canonical PDF was also rendered page by page
after the Level 3 and Level 4 revisions; the final LaTeX log contains no
undefined references, overfull boxes, underfull boxes, or other LaTeX warnings.

To regenerate the figures and compile the report:

```matlab
generateReportFigures
```

```text
pdflatex inverse_ladder_case_study_report.tex
pdflatex inverse_ladder_case_study_report.tex
```

The LaTeX commands should be run from the `report` directory.

## GitLab publication

The repository remote is:

```text
https://git.csic.es/xeon4/inverseproblemsbiocybernetics.git
```

The work was pushed to the `main` branch in the following commits:

- `2db4201` -- `Add four-level inverse problems case study`
- `b0545cd` -- `Polish inverse ladder case study report`
- `c159d2b` -- `Cold-start Level 3 forward validation`
- `4248066` -- `Correct Level 1 initialization and input ranges`
- `1bad39a` -- `Strengthen Level 4 convergence and documentation`
- `a1edeb0` -- `Add inverse ladder TikZ overview to report`
- `aaec1f1` -- `Cold-start Level 4 forward validation`
- `09a9d9f` -- `Refresh Level 3 diagnostics and figure`

At the end of the session, `main`, `origin/main`, and `origin/HEAD` all pointed
to commit `09a9d9f5028f22718d8df867235ff2ce0d2a9d90` before this summary update.

Three historical intermediate report PDFs remain local and untracked:

```text
report/inverse_ladder_case_study_report_allocation_controls.pdf
report/inverse_ladder_case_study_report_integrators.pdf
report/inverse_ladder_case_study_report_with_units.pdf
```

They were deliberately excluded from the GitLab commits; the canonical report
is `report/inverse_ladder_case_study_report.pdf`.
