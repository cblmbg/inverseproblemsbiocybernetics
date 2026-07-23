% Inverse Ladder Microbial Community Case Study
%
% Main workflow
%   runInverseLadderCaseStudy          - Execute all four levels.
%   defaultInverseLadderConfig         - Return parameters and settings.
%
% Model and simulation
%   communityRhs                       - Cross-feeding ODE right-hand side.
%   simulateCommunity                  - ODE15S simulation for data fitting.
%   simulateControlledModel            - Fixed-step RK4 simulation.
%
% Inverse-problem levels
%   runLevel1ParameterEstimation       - Calibrate kinetic parameters.
%   runLevel2ModelDiscovery            - Sparse growth-law discovery.
%   runLevel3InverseOptimalControl     - Infer a centralized objective.
%   runLevel4InverseDifferentialGame   - Infer two Nash-player objectives.
%
% Validation
%   testInverseLadderCaseStudy         - MATLAB unit tests.
