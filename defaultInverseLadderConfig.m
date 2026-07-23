function cfg = defaultInverseLadderConfig()
%DEFAULTINVERSELADDERCONFIG Configuration for the inverse-ladder case study.
%
% The model represents two microbial strains that compete for a shared
% substrate and reciprocally exchange essential metabolites. Each strain
% controls the fraction of its metabolic resources allocated to secretion.

cfg.randomSeed = 42;

parameters.dilutionRate = 0.05;
parameters.substrateInlet = 10.0;
parameters.maximumGrowthRate = [0.55; 0.50];
parameters.substrateHalfSaturation = [0.80; 1.00];
parameters.metaboliteHalfSaturation = [0.12; 0.10];
parameters.allocationCost = [0.35; 0.30];
parameters.secretionRate = [0.55; 0.50];
parameters.substrateYield = [0.65; 0.60];
parameters.metaboliteYield = [8.0; 8.0];
cfg.trueParameters = parameters;

cfg.defaultInitialState = [0.15; 0.12; 6.0; 0.02; 0.02];
cfg.stateNames = ["Strain 1"; "Strain 2"; "Substrate"; ...
    "Metabolite 1"; "Metabolite 2"];
cfg.controlNames = ["Allocation by strain 1"; "Allocation by strain 2"];

cfg.calibration.finalTime = 24;
cfg.calibration.observationTimes = linspace(0, 24, 49);
cfg.calibration.relativeNoise = 0.005;
cfg.calibration.numberOfStarts = 2;
cfg.calibration.initialStates = [ ...
    0.15, 0.12, 6.0, 0.02, 0.02; ...
    0.28, 0.07, 8.0, 0.04, 0.01; ...
    0.06, 0.25, 4.5, 0.01, 0.05];

cfg.control.timeGrid = linspace(0, 16, 9);
cfg.control.integrationSubsteps = 4;
cfg.control.lowerBound = 0.02;
cfg.control.upperBound = 0.95;
cfg.control.initialGuess = 0.35;
cfg.control.initialStates = [ ...
    0.15, 0.12, 6.0, 0.02, 0.02; ...
    0.26, 0.08, 8.0, 0.04, 0.01];

cfg.level3.trueWeights = [0.62; 0.14; 0.14; 0.10];
cfg.level3.featureNames = ["Total biomass"; "Control effort"; ...
    "Residual substrate"; "Community imbalance"];

cfg.level4.trueWeights = [ ...
    0.58, 0.62; ...
    0.22, 0.25; ...
    0.05, 0.05; ...
    0.15, 0.08];
cfg.level4.featureNames = ["Own biomass"; "Control effort"; ...
    "Received-metabolite deficit"; "Partner biomass"];
cfg.level4.maximumBestResponseIterations = 12;
cfg.level4.bestResponseTolerance = 3e-3;
cfg.level4.damping = 0.65;

cfg.inverse.finiteDifferenceStep = 2e-4;
cfg.inverse.activeBoundTolerance = 5e-3;
cfg.inverse.regularization = 1e-8;

cfg.optimization.display = "off";
cfg.optimization.maximumIterations = 100;
cfg.optimization.maximumFunctionEvaluations = 8000;
end
