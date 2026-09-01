% Inverse Ladder Microbial Community Case Study
%
% Main workflow
%   runInverseLadderCaseStudy          - Execute the full four-level case study.
%   defaultInverseLadderConfig         - Parameters, experiments, and settings.
%
% Structural (a-priori) identifiability
%   runLevel1aprioriIdentifiability    - Structural identifiability and
%                                        observability via STRIKE-GOLDD.
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
%   testInverseLadderCaseStudy         - MATLAB unit tests.
%   kktBoundHandlingTest               - Bound-aware inverse-KKT unit tests.
%
% Bundled toolbox
%   strike-goldd-master                - STRIKE-GOLDD structural-identifiability
%                                        toolbox used by runLevel1aprioriIdentifiability.
