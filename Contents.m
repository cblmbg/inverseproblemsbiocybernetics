% Inverse Ladder Microbial Community Case Study
%
% Main workflow
%   runInverseLadderCaseStudy          - Execute the full four-level case study.
%   defaultInverseLadderConfig         - Parameters, experiments, and settings.
%
% Structural (a-priori) identifiability
%   runLevel1aprioriIdentifiability    - Full-state structural analysis used by Level 1.
%   runStructuralIdentifiabilityComparison
%                                      - Compare all three observation scenarios.
%   runStrikeGolddAnalyses             - Protected shared STRIKE-GOLDD runner.
%
% Model and simulation
%   communityRhs                       - Cross-feeding community ODE right-hand side.
%   simulateCommunity                  - Adaptive ode15s simulation (interpolated controls).
%   simulateControlledModel            - Fixed-step RK4 simulation (piecewise-constant controls).
%   validateModelParameters            - Reject non-finite kinetic parameter fields.
%   generateCalibrationData            - Generate noisy, persistently excited experiments.
%
% Inverse-problem levels
%   runLevel1ParameterEstimation       - Calibrate six kinetic parameters (Level 1).
%   runLevel2ModelDiscovery            - Sparse growth-law discovery (Level 2).
%   runLevel3InverseOptimalControl     - Infer a centralized objective (Level 3).
%   runLevel4InverseDifferentialGame   - Infer two Nash-player objectives (Level 4).
%
% Objective inference and forward solvers
%   communityCostFeatures              - Centralized objective candidate kernels.
%   playerCostFeatures                 - Player objective candidate kernels.
%   finiteDifferenceFeatureJacobian    - Finite-difference feature gradients.
%   inferSimplexWeights                - Recover simplex weights with bound-aware KKT constraints.
%   solveCommunityPlanner              - Centralized forward optimal-control solver.
%   solveOpenLoopNash                  - Damped best-response open-loop Nash solver.
%
% Plotting and validation
%   plotInverseLadderResults           - Four-panel summary figure.
%   generateReportFigures              - Detailed Level 1/3/4 figures from saved results.
%   testInverseLadderCaseStudy         - MATLAB unit tests.
%   kktBoundHandlingTest               - Bound-aware inverse-KKT unit tests.
%   structuralIdentifiabilityTest      - Shared structural-runner API tests.
%
% Bundled toolbox
%   strike-goldd-master                - STRIKE-GOLDD structural-identifiability
%                                        toolbox used by the structural-analysis functions.
