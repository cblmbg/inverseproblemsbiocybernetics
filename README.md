# Inverse Ladder Microbial Community Case Study

This folder contains a reproducible MATLAB implementation of the four-level
inverse-problem hierarchy described in the accompanying manuscript. The
biological system is a two-strain microbial consortium that competes for a
shared substrate and reciprocally exchanges essential metabolites.

## Requirements

The implementation was developed for MATLAB R2026a and uses:

- Optimization Toolbox
- Global Optimization Toolbox
- Statistics and Machine Learning Toolbox
- Signal Processing Toolbox

## Run the complete case study

```matlab
results = runInverseLadderCaseStudy;
```

This command:

1. generates noisy synthetic experiments;
2. estimates six kinetic parameters;
3. discovers a sparse biomass growth law;
4. infers a centralized community objective using inverse stationarity;
5. infers strain-specific objectives from an open-loop Nash equilibrium;
6. performs forward validation and creates a summary figure.

The run saves `inverse_ladder_results.mat` and
`inverse_ladder_summary.png` in this folder. To suppress files and graphics:

```matlab
results = runInverseLadderCaseStudy( ...
    "MakePlots", false, "SaveResults", false);
```

## Interpretation

Level 3 treats the consortium as a centralized planner. Level 4 treats each
strain as an independent player. Both levels use normalized candidate cost
kernels, inverse first-order optimality conditions, and forward validation.
The implementation intentionally exposes rank diagnostics and prediction
errors because objective recovery is generally non-unique.

## Tests

```matlab
runtests("testInverseLadderCaseStudy.m")
```

The tests verify model dimensions and finiteness, nonnegative simulation,
agreement between ODE15S and RK4 simulations, and constrained recovery of a
known simplex-normalized objective.
