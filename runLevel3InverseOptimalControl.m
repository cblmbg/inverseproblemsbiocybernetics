function result = runLevel3InverseOptimalControl(cfg, parameters)
%RUNLEVEL3INVERSEOPTIMALCONTROL Infer a centralized community objective.

timeGrid = cfg.control.timeGrid;
numberOfExperiments = size(cfg.control.initialStates, 1);
observations = cell(numberOfExperiments, 1);
demonstrationSuccess = false(numberOfExperiments, 1);
optimalityMatrix = zeros(0, numel(cfg.level3.trueWeights));

for experimentIndex = 1:numberOfExperiments
    initialState = cfg.control.initialStates(experimentIndex, :)';
    observations{experimentIndex} = solveCommunityPlanner(parameters, ...
        initialState, timeGrid, cfg.level3.trueWeights, cfg);
    demonstrationSuccess(experimentIndex) = observations{experimentIndex}.success;
    % Do not let a failed demonstration enter the inverse problem: a non-optimal
    % control profile is not a valid stationarity constraint.
    if ~demonstrationSuccess(experimentIndex)
        continue
    end
    controls = observations{experimentIndex}.controls;

    % Use only genuinely interior controls. Rows at an active bound do not
    % satisfy an unconstrained stationarity condition (a bound multiplier
    % balances the gradient), so including them would misrepresent the KKT
    % system. Interior rows are pooled across demonstrations and their
    % combined rank determines identifiability below.
    interior = controls(:) > cfg.control.lowerBound + ...
        cfg.inverse.activeBoundTolerance & ...
        controls(:) < cfg.control.upperBound - ...
        cfg.inverse.activeBoundTolerance;
    variableIndices = find(interior);

    featureFunction = @(states, candidateControls) ...
        communityCostFeatures(timeGrid, states, candidateControls, parameters);
    jacobian = finiteDifferenceFeatureJacobian(parameters, initialState, ...
        timeGrid, controls, variableIndices, featureFunction, cfg);
    optimalityMatrix = [optimalityMatrix; jacobian]; %#ok<AGROW>
end

inverseResult = inferSimplexWeights(optimalityMatrix, cfg);
validation = cell(numberOfExperiments, 1);
validationSuccess = false(numberOfExperiments, 1);
controlError = nan(numberOfExperiments, 1);
stateError = nan(numberOfExperiments, 1);

for experimentIndex = 1:numberOfExperiments
    initialState = cfg.control.initialStates(experimentIndex, :)';
    % Cold-start validation from the configured default guess. Reusing the
    % demonstrated controls here would make trajectory reproduction a
    % warm-start consistency check rather than an independent forward solve.
    validation{experimentIndex} = solveCommunityPlanner(parameters, ...
        initialState, timeGrid, inverseResult.weights, cfg);
    validationSuccess(experimentIndex) = validation{experimentIndex}.success;
    % Report reproduction errors only when both the demonstration and the
    % validation solve succeeded; a failed solve can otherwise return a
    % misleadingly small error (for example an unchanged initial guess).
    if demonstrationSuccess(experimentIndex) && validationSuccess(experimentIndex)
        controlError(experimentIndex) = rms( ...
            validation{experimentIndex}.controls - ...
            observations{experimentIndex}.controls, "all");
        stateError(experimentIndex) = rms( ...
            validation{experimentIndex}.states - ...
            observations{experimentIndex}.states, "all");
    end
end

allSolvesSucceeded = all(demonstrationSuccess) && all(validationSuccess);
result.trueWeights = cfg.level3.trueWeights;
result.inferredWeights = inverseResult.weights;
result.weightError = norm(result.inferredWeights - result.trueWeights);
result.observations = observations;
result.validation = validation;
result.controlRmse = controlError;
result.stateRmse = stateError;
result.optimalityMatrix = optimalityMatrix;
result.inverseDiagnostics = inverseResult;
result.featureNames = cfg.level3.featureNames;
result.demonstrationSuccess = demonstrationSuccess;
result.validationSuccess = validationSuccess;
result.identifiable = inverseResult.locallyIdentifiable;
result.interiorRowCount = inverseResult.numberOfEquations;
if ~result.identifiable
    warning("runLevel3InverseOptimalControl:notIdentifiable", ...
        "Demonstrations provide insufficient interior information " + ...
        "(rank %d for %d weights); the reported weights fall back to the " + ...
        "regularized prior and are not identified by the data.", ...
        inverseResult.matrixRank, numel(result.trueWeights));
end
if allSolvesSucceeded
    result.status = "verified";
else
    result.status = "unverified";
    warning("runLevel3InverseOptimalControl:unverified", ...
        "One or more planner solves did not succeed; the inferred " + ...
        "objective and reproduction errors are reported as unverified.");
end
end
