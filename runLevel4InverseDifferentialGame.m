function result = runLevel4InverseDifferentialGame(cfg, parameters)
%RUNLEVEL4INVERSEDIFFERENTIALGAME Infer objectives of two microbial players.

timeGrid = cfg.control.timeGrid;
numberOfIntervals = numel(timeGrid) - 1;
numberOfExperiments = size(cfg.control.initialStates, 1);
observations = cell(numberOfExperiments, 1);
demonstrationVerified = false(numberOfExperiments, 1);
optimalityMatrices = {[], []};

for experimentIndex = 1:numberOfExperiments
    initialState = cfg.control.initialStates(experimentIndex, :)';
    observations{experimentIndex} = solveOpenLoopNash(parameters, ...
        initialState, timeGrid, cfg.level4.trueWeights, cfg);
    demonstrationVerified(experimentIndex) = observations{experimentIndex}.converged;
    controls = observations{experimentIndex}.controls;

    for player = 1:2
        controlIndices = (1:numberOfIntervals)' + ...
            (player - 1)*numberOfIntervals;
        playerControls = controls(:, player);
        interior = playerControls > cfg.control.lowerBound + ...
            cfg.inverse.activeBoundTolerance & ...
            playerControls < cfg.control.upperBound - ...
            cfg.inverse.activeBoundTolerance;
        variableIndices = controlIndices(interior);
        if numel(variableIndices) < 4
            variableIndices = controlIndices;
        end

        featureFunction = @(states, candidateControls) ...
            playerCostFeatures(player, timeGrid, states, candidateControls);
        jacobian = finiteDifferenceFeatureJacobian(parameters, initialState, ...
            timeGrid, controls, variableIndices, featureFunction, cfg);
        optimalityMatrices{player} = [optimalityMatrices{player}; jacobian];
    end
end

inverseDiagnostics = cell(1, 2);
inferredWeights = zeros(4, 2);
for player = 1:2
    inverseDiagnostics{player} = inferSimplexWeights( ...
        optimalityMatrices{player}, cfg);
    inferredWeights(:, player) = inverseDiagnostics{player}.weights;
end

validation = cell(numberOfExperiments, 1);
validationVerified = false(numberOfExperiments, 1);
controlError = nan(numberOfExperiments, 1);
stateError = nan(numberOfExperiments, 1);
for experimentIndex = 1:numberOfExperiments
    initialState = cfg.control.initialStates(experimentIndex, :)';
    % Cold-start validation from the configured default guess. Reusing the
    % demonstrated controls here would reduce the check to a local
    % warm-start consistency sweep rather than an independent Nash solve.
    validation{experimentIndex} = solveOpenLoopNash(parameters, initialState, ...
        timeGrid, inferredWeights, cfg);
    validationVerified(experimentIndex) = validation{experimentIndex}.converged;
    % Report reproduction errors only when both the demonstration and the
    % validation solve certify an approximate equilibrium; otherwise the
    % compared controls are not certified equilibrium behaviors.
    if demonstrationVerified(experimentIndex) && validationVerified(experimentIndex)
        controlError(experimentIndex) = rms( ...
            validation{experimentIndex}.controls - ...
            observations{experimentIndex}.controls, "all");
        stateError(experimentIndex) = rms( ...
            validation{experimentIndex}.states - ...
            observations{experimentIndex}.states, "all");
    end
end

allEquilibriaVerified = all(demonstrationVerified) && all(validationVerified);
result.trueWeights = cfg.level4.trueWeights;
result.inferredWeights = inferredWeights;
result.weightError = vecnorm(inferredWeights - cfg.level4.trueWeights);
result.observations = observations;
result.validation = validation;
result.controlRmse = controlError;
result.stateRmse = stateError;
result.optimalityMatrices = optimalityMatrices;
result.inverseDiagnostics = inverseDiagnostics;
result.featureNames = cfg.level4.featureNames;
result.demonstrationVerified = demonstrationVerified;
result.validationVerified = validationVerified;
if allEquilibriaVerified
    result.status = "verified";
else
    result.status = "unverified";
    warning("runLevel4InverseDifferentialGame:unverified", ...
        "One or more Nash solves were not certified; the inferred " + ...
        "objectives and reproduction errors are reported as unverified.");
end
end
