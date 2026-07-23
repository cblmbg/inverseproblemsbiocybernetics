function jacobian = finiteDifferenceFeatureJacobian(parameters, initialState, ...
    timeGrid, controls, variableIndices, featureFunction, cfg)
%FINITEDIFFERENCEFEATUREJACOBIAN Differentiate cost kernels with respect to controls.

baseVector = controls(:);
baseStates = simulateControlledModel(parameters, initialState, timeGrid, ...
    controls, cfg.control.integrationSubsteps);
baseFeatures = featureFunction(baseStates, controls);
numberOfFeatures = numel(baseFeatures);
jacobian = zeros(numel(variableIndices), numberOfFeatures);
step = cfg.inverse.finiteDifferenceStep;

for row = 1:numel(variableIndices)
    variableIndex = variableIndices(row);
    plusVector = baseVector;
    minusVector = baseVector;
    plusVector(variableIndex) = min(cfg.control.upperBound, ...
        baseVector(variableIndex) + step);
    minusVector(variableIndex) = max(cfg.control.lowerBound, ...
        baseVector(variableIndex) - step);

    plusControls = reshape(plusVector, size(controls));
    minusControls = reshape(minusVector, size(controls));
    plusStates = simulateControlledModel(parameters, initialState, timeGrid, ...
        plusControls, cfg.control.integrationSubsteps);
    minusStates = simulateControlledModel(parameters, initialState, timeGrid, ...
        minusControls, cfg.control.integrationSubsteps);
    plusFeatures = featureFunction(plusStates, plusControls);
    minusFeatures = featureFunction(minusStates, minusControls);

    denominator = plusVector(variableIndex) - minusVector(variableIndex);
    jacobian(row, :) = ((plusFeatures - minusFeatures) / denominator)';
end
end
