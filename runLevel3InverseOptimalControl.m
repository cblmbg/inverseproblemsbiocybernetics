function result = runLevel3InverseOptimalControl(cfg, parameters)
%RUNLEVEL3INVERSEOPTIMALCONTROL Infer a centralized community objective.

timeGrid = cfg.control.timeGrid;
numberOfExperiments = size(cfg.control.initialStates, 1);
observations = cell(numberOfExperiments, 1);
demonstrationSuccess = false(numberOfExperiments, 1);
optimalityMatrix = zeros(0, numel(cfg.level3.trueWeights));
lowerBoundMatrix = zeros(0, numel(cfg.level3.trueWeights));
upperBoundMatrix = zeros(0, numel(cfg.level3.trueWeights));

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

    % Differentiate every control and classify the reduced-gradient row by its
    % box activity. Interior rows impose equality stationarity; lower and upper
    % rows impose the corresponding one-sided KKT signs.
    lowerActive = controls(:) <= cfg.control.lowerBound + ...
        cfg.inverse.activeBoundTolerance;
    upperActive = controls(:) >= cfg.control.upperBound - ...
        cfg.inverse.activeBoundTolerance;
    interior = ~lowerActive & ~upperActive;
    variableIndices = (1:numel(controls))';

    featureFunction = @(states, candidateControls) ...
        communityCostFeatures(timeGrid, states, candidateControls, parameters);
    jacobian = finiteDifferenceFeatureJacobian(parameters, initialState, ...
        timeGrid, controls, variableIndices, featureFunction, cfg);
    optimalityMatrix = [optimalityMatrix; jacobian(interior, :)]; %#ok<AGROW>
    lowerBoundMatrix = [lowerBoundMatrix; jacobian(lowerActive, :)]; %#ok<AGROW>
    upperBoundMatrix = [upperBoundMatrix; jacobian(upperActive, :)]; %#ok<AGROW>
end

inverseResult = inferSimplexWeights(optimalityMatrix, cfg, ...
    LowerBoundMatrix=lowerBoundMatrix, UpperBoundMatrix=upperBoundMatrix);
inverseSucceeded = inverseResult.exitFlag > 0 && ...
    numel(inverseResult.weights) == numel(cfg.level3.trueWeights) && ...
    all(isfinite(inverseResult.weights));
if inverseSucceeded
    inferredWeights = inverseResult.weights;
else
    inferredWeights = nan(size(cfg.level3.trueWeights));
end
validation = cell(numberOfExperiments, 1);
validationSuccess = false(numberOfExperiments, 1);
controlError = nan(numberOfExperiments, 1);
stateError = nan(numberOfExperiments, 1);

for experimentIndex = 1:numberOfExperiments
    if ~inverseSucceeded
        continue
    end
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

allChecksSucceeded = all(demonstrationSuccess) && all(validationSuccess) && ...
    inverseSucceeded && inverseResult.kktCompatible;
result.trueWeights = cfg.level3.trueWeights;
result.inferredWeights = inferredWeights;
result.weightError = norm(result.inferredWeights - result.trueWeights);
result.observations = observations;
result.validation = validation;
result.controlRmse = controlError;
result.stateRmse = stateError;
result.optimalityMatrix = optimalityMatrix;
result.lowerBoundMatrix = lowerBoundMatrix;
result.upperBoundMatrix = upperBoundMatrix;
result.inverseDiagnostics = inverseResult;
result.featureNames = cfg.level3.featureNames;
result.demonstrationSuccess = demonstrationSuccess;
result.validationSuccess = validationSuccess;
result.identifiable = inverseResult.locallyIdentifiable;
result.kktCompatible = inverseResult.kktCompatible;
result.interiorRowCount = inverseResult.interiorRowCount;
result.lowerActiveRowCount = inverseResult.lowerActiveRowCount;
result.upperActiveRowCount = inverseResult.upperActiveRowCount;
if ~result.identifiable
    warning("runLevel3InverseOptimalControl:notIdentifiable", ...
        "Demonstrations do not uniquely identify a KKT-compatible " + ...
        "normalized objective (maximum data-only weight range %.3g); " + ...
        "the reported point estimate depends on the regularized prior.", ...
        inverseResult.maximumWeightRange);
end
if allChecksSucceeded
    result.status = "verified";
else
    result.status = "unverified";
    warning("runLevel3InverseOptimalControl:unverified", ...
        "One or more planner solves or inverse-KKT checks did not succeed; " + ...
        "the inferred objective and reproduction errors are unverified.");
end
end
