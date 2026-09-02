function result = runLevel4InverseDifferentialGame(cfg, parameters)
%RUNLEVEL4INVERSEDIFFERENTIALGAME Infer objectives of two microbial players.
%
% Algorithm outline (mirrors the Level 4 pseudocode in the accompanying
% manuscript, "Forward and inverse algorithms"):
%   1. solve configured open-loop Nash demonstrations with damped best
%      response, certify unilateral deviations, and retain only certified
%      profiles;
%   2. for each player and retained profile, finite-difference own-control
%      features and classify rows as interior (gradient equality) or
%      bound-active (one-sided KKT);
%   3. recover each player's simplex weights with inferSimplexWeights;
%   4. cold-start Nash validation from the configured initial control (0.35 in
%      the supplied configuration) and check unilateral deviations.

timeGrid = cfg.control.timeGrid;
numberOfIntervals = numel(timeGrid) - 1;
numberOfExperiments = size(cfg.control.initialStates, 1);
observations = cell(numberOfExperiments, 1);
demonstrationVerified = false(numberOfExperiments, 1);
numberOfFeatures = size(cfg.level4.trueWeights, 1);
optimalityMatrices = {zeros(0, numberOfFeatures), zeros(0, numberOfFeatures)};
lowerBoundMatrices = {zeros(0, numberOfFeatures), zeros(0, numberOfFeatures)};
upperBoundMatrices = {zeros(0, numberOfFeatures), zeros(0, numberOfFeatures)};

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
        % Classify every unilateral reduced-gradient row. Interior controls
        % impose equality stationarity; active bounds contribute KKT signs.
        lowerActive = playerControls <= cfg.control.lowerBound + ...
            cfg.inverse.activeBoundTolerance;
        upperActive = playerControls >= cfg.control.upperBound - ...
            cfg.inverse.activeBoundTolerance;
        interior = ~lowerActive & ~upperActive;
        variableIndices = controlIndices;

        featureFunction = @(states, candidateControls) ...
            playerCostFeatures(player, timeGrid, states, candidateControls);
        jacobian = finiteDifferenceFeatureJacobian(parameters, initialState, ...
            timeGrid, controls, variableIndices, featureFunction, cfg);
        optimalityMatrices{player} = [optimalityMatrices{player}; ...
            jacobian(interior, :)];
        lowerBoundMatrices{player} = [lowerBoundMatrices{player}; ...
            jacobian(lowerActive, :)];
        upperBoundMatrices{player} = [upperBoundMatrices{player}; ...
            jacobian(upperActive, :)];
    end
end

inverseDiagnostics = cell(1, 2);
inferredWeights = zeros(4, 2);
inverseSucceeded = false(1, 2);
for player = 1:2
    inverseDiagnostics{player} = inferSimplexWeights( ...
        optimalityMatrices{player}, cfg, ...
        LowerBoundMatrix=lowerBoundMatrices{player}, ...
        UpperBoundMatrix=upperBoundMatrices{player});
    weights = inverseDiagnostics{player}.weights;
    inverseSucceeded(player) = inverseDiagnostics{player}.exitFlag > 0 && ...
        numel(weights) == numberOfFeatures && all(isfinite(weights));
    if inverseSucceeded(player)
        inferredWeights(:, player) = weights;
    else
        inferredWeights(:, player) = nan(numberOfFeatures, 1);
    end
end

validation = cell(numberOfExperiments, 1);
validationVerified = false(numberOfExperiments, 1);
controlError = nan(numberOfExperiments, 1);
stateError = nan(numberOfExperiments, 1);
for experimentIndex = 1:numberOfExperiments
    if ~all(inverseSucceeded)
        continue
    end
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

allChecksVerified = all(demonstrationVerified) && all(validationVerified) && ...
    all(inverseSucceeded) && all([inverseDiagnostics{1}.kktCompatible, ...
    inverseDiagnostics{2}.kktCompatible]);
result.trueWeights = cfg.level4.trueWeights;
result.inferredWeights = inferredWeights;
result.weightError = vecnorm(inferredWeights - cfg.level4.trueWeights);
result.observations = observations;
result.validation = validation;
result.controlRmse = controlError;
result.stateRmse = stateError;
result.optimalityMatrices = optimalityMatrices;
result.lowerBoundMatrices = lowerBoundMatrices;
result.upperBoundMatrices = upperBoundMatrices;
result.inverseDiagnostics = inverseDiagnostics;
result.featureNames = cfg.level4.featureNames;
result.demonstrationVerified = demonstrationVerified;
result.validationVerified = validationVerified;
result.identifiable = [inverseDiagnostics{1}.locallyIdentifiable, ...
    inverseDiagnostics{2}.locallyIdentifiable];
result.kktCompatible = [inverseDiagnostics{1}.kktCompatible, ...
    inverseDiagnostics{2}.kktCompatible];
result.interiorRowCount = [inverseDiagnostics{1}.interiorRowCount, ...
    inverseDiagnostics{2}.interiorRowCount];
result.lowerActiveRowCount = [inverseDiagnostics{1}.lowerActiveRowCount, ...
    inverseDiagnostics{2}.lowerActiveRowCount];
result.upperActiveRowCount = [inverseDiagnostics{1}.upperActiveRowCount, ...
    inverseDiagnostics{2}.upperActiveRowCount];
if ~all(result.identifiable)
    warning("runLevel4InverseDifferentialGame:notIdentifiable", ...
        "One or more players do not uniquely identify a KKT-compatible " + ...
        "normalized objective; the reported point estimate may depend on " + ...
        "the regularized prior.");
end
if allChecksVerified
    result.status = "verified";
else
    result.status = "unverified";
    warning("runLevel4InverseDifferentialGame:unverified", ...
        "One or more Nash solves or inverse-KKT checks were not certified; " + ...
        "the inferred objectives and reproduction errors are unverified.");
end
end
