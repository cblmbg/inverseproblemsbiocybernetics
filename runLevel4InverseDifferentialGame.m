function result = runLevel4InverseDifferentialGame(cfg, parameters)
%RUNLEVEL4INVERSEDIFFERENTIALGAME Infer objectives of two microbial players.

timeGrid = cfg.control.timeGrid;
numberOfIntervals = numel(timeGrid) - 1;
numberOfExperiments = size(cfg.control.initialStates, 1);
observations = cell(numberOfExperiments, 1);
demonstrationVerified = false(numberOfExperiments, 1);
numberOfFeatures = size(cfg.level4.trueWeights, 1);
optimalityMatrices = {zeros(0, numberOfFeatures), zeros(0, numberOfFeatures)};

for experimentIndex = 1:numberOfExperiments
    initialState = cfg.control.initialStates(experimentIndex, :)';
    observations{experimentIndex} = solveOpenLoopNash(parameters, ...
        initialState, timeGrid, cfg.level4.trueWeights, cfg);
    demonstrationVerified(experimentIndex) = observations{experimentIndex}.converged;
    % Do not let an uncertified equilibrium enter the inverse problem.
    if ~demonstrationVerified(experimentIndex)
        continue
    end
    controls = observations{experimentIndex}.controls;

    for player = 1:2
        controlIndices = (1:numberOfIntervals)' + ...
            (player - 1)*numberOfIntervals;
        playerControls = controls(:, player);
        % Use only genuinely interior controls; rows at an active bound do not
        % satisfy an unconstrained stationarity condition. Interior rows are
        % pooled across demonstrations and their combined rank determines
        % identifiability below.
        interior = playerControls > cfg.control.lowerBound + ...
            cfg.inverse.activeBoundTolerance & ...
            playerControls < cfg.control.upperBound - ...
            cfg.inverse.activeBoundTolerance;
        variableIndices = controlIndices(interior);

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
result.identifiable = [inverseDiagnostics{1}.locallyIdentifiable, ...
    inverseDiagnostics{2}.locallyIdentifiable];
result.interiorRowCount = [inverseDiagnostics{1}.numberOfEquations, ...
    inverseDiagnostics{2}.numberOfEquations];
if ~all(result.identifiable)
    warning("runLevel4InverseDifferentialGame:notIdentifiable", ...
        "One or more players provide insufficient interior information to " + ...
        "identify a normalized objective; the reported weights fall back to " + ...
        "the regularized prior and are not identified by the data.");
end
if allEquilibriaVerified
    result.status = "verified";
else
    result.status = "unverified";
    warning("runLevel4InverseDifferentialGame:unverified", ...
        "One or more Nash solves were not certified; the inferred " + ...
        "objectives and reproduction errors are reported as unverified.");
end
end
