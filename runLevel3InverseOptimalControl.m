function result = runLevel3InverseOptimalControl(cfg, parameters)
%RUNLEVEL3INVERSEOPTIMALCONTROL Infer a centralized community objective.

timeGrid = cfg.control.timeGrid;
numberOfIntervals = numel(timeGrid) - 1;
numberOfExperiments = size(cfg.control.initialStates, 1);
observations = cell(numberOfExperiments, 1);
optimalityMatrix = [];

for experimentIndex = 1:numberOfExperiments
    initialState = cfg.control.initialStates(experimentIndex, :)';
    observations{experimentIndex} = solveCommunityPlanner(parameters, ...
        initialState, timeGrid, cfg.level3.trueWeights, cfg);
    controls = observations{experimentIndex}.controls;

    interior = controls(:) > cfg.control.lowerBound + ...
        cfg.inverse.activeBoundTolerance & ...
        controls(:) < cfg.control.upperBound - ...
        cfg.inverse.activeBoundTolerance;
    variableIndices = find(interior);
    if numel(variableIndices) < 4
        variableIndices = (1:2*numberOfIntervals)';
    end

    featureFunction = @(states, candidateControls) ...
        communityCostFeatures(timeGrid, states, candidateControls, parameters);
    jacobian = finiteDifferenceFeatureJacobian(parameters, initialState, ...
        timeGrid, controls, variableIndices, featureFunction, cfg);
    optimalityMatrix = [optimalityMatrix; jacobian]; %#ok<AGROW>
end

inverseResult = inferSimplexWeights(optimalityMatrix, cfg);
validation = cell(numberOfExperiments, 1);
controlError = zeros(numberOfExperiments, 1);
stateError = zeros(numberOfExperiments, 1);

for experimentIndex = 1:numberOfExperiments
    initialState = cfg.control.initialStates(experimentIndex, :)';
    % Cold-start validation from the configured default guess. Reusing the
    % demonstrated controls here would make trajectory reproduction a
    % warm-start consistency check rather than an independent forward solve.
    validation{experimentIndex} = solveCommunityPlanner(parameters, ...
        initialState, timeGrid, inverseResult.weights, cfg);
    controlError(experimentIndex) = rms( ...
        validation{experimentIndex}.controls - ...
        observations{experimentIndex}.controls, "all");
    stateError(experimentIndex) = rms( ...
        validation{experimentIndex}.states - ...
        observations{experimentIndex}.states, "all");
end

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
end
