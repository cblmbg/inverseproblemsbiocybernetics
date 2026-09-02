function result = runLevel1ParameterEstimation(cfg, experiments)
%RUNLEVEL1PARAMETERESTIMATION Estimate six kinetic parameters from data.
%
% Estimated quantities are the two maximum growth rates, two secretion
% rates, and two allocation-cost coefficients. Remaining parameters are
% treated as independently known.
%
% Algorithm outline (mirrors the Level 1 pseudocode in the accompanying
% manuscript, "Level 1: parameter estimation"):
%   1. from each truth-independent initial guess, solve a bound-constrained
%      weighted least-squares fit with lsqnonlin, simulating each candidate
%      parameter vector under the prescribed allocation schedules;
%   2. keep the estimate with the smallest sum of squared residuals.

lowerBounds = [0.20; 0.20; 0.20; 0.20; 0.05; 0.05];
upperBounds = [0.90; 0.90; 0.90; 0.90; 0.70; 0.70];
% Use a reproducible initialization that does not depend on ground truth.
initialVector = 0.5 * (lowerBounds + upperBounds);

stateScale = zeros(1, 5);
for experimentIndex = 1:numel(experiments)
    stateScale = max(stateScale, max(experiments(experimentIndex).states, [], 1));
end
stateScale = max(stateScale, 0.05);

options = optimoptions("lsqnonlin", ...
    "Display", cfg.optimization.display, ...
    "MaxIterations", 50, ...
    "MaxFunctionEvaluations", 2000, ...
    "FunctionTolerance", 1e-8, ...
    "StepTolerance", 1e-8);

bestVector = initialVector;
bestResidualNorm = inf;
exitFlag = NaN;
output = struct();
rng(cfg.randomSeed + 1, "twister");

for startIndex = 1:cfg.calibration.numberOfStarts
    if startIndex == 1
        startVector = initialVector;
    else
        fraction = rand(size(lowerBounds));
        startVector = lowerBounds + fraction .* (upperBounds - lowerBounds);
    end
    [candidateVector, residualNorm, ~, candidateExitFlag, candidateOutput] = ...
        lsqnonlin(@residuals, startVector, lowerBounds, upperBounds, options);
    if residualNorm < bestResidualNorm
        bestVector = candidateVector;
        bestResidualNorm = residualNorm;
        exitFlag = candidateExitFlag;
        output = candidateOutput;
    end
end

estimatedParameters = unpackParameters(bestVector, cfg.trueParameters);
predictions = cell(numel(experiments), 1);
for experimentIndex = 1:numel(experiments)
    experiment = experiments(experimentIndex);
    predictions{experimentIndex} = simulateControlledModel(estimatedParameters, ...
        experiment.initialState, experiment.times, ...
        experiment.controls(1:end-1, :), 4);
end

trueVector = packParameters(cfg.trueParameters);
result.estimatedParameters = estimatedParameters;
result.estimatedVector = bestVector;
result.trueVector = trueVector;
result.relativeParameterError = rms((bestVector - trueVector) ./ trueVector);
result.residualNorm = bestResidualNorm;
result.exitFlag = exitFlag;
result.output = output;
result.predictions = predictions;
result.parameterNames = ["muMax1"; "muMax2"; "alpha1"; ...
    "alpha2"; "cost1"; "cost2"];

    function residualVector = residuals(candidateVector)
        candidateParameters = unpackParameters(candidateVector, ...
            cfg.trueParameters);
        residualVector = [];
        for residualExperimentIndex = 1:numel(experiments)
            experiment = experiments(residualExperimentIndex);
            predictedStates = simulateControlledModel(candidateParameters, ...
                experiment.initialState, experiment.times, ...
                experiment.controls(1:end-1, :), 4);
            scaledResidual = (predictedStates - experiment.states) ./ stateScale;
            residualVector = [residualVector; scaledResidual(:)]; %#ok<AGROW>
        end
    end
end

function vector = packParameters(parameters)
vector = [parameters.maximumGrowthRate; parameters.secretionRate; ...
    parameters.allocationCost];
end

function parameters = unpackParameters(vector, template)
parameters = template;
parameters.maximumGrowthRate = vector(1:2);
parameters.secretionRate = vector(3:4);
parameters.allocationCost = vector(5:6);
end
