function result = inferSimplexWeights(optimalityMatrix, cfg)
%INFERSIMPLEXWEIGHTS Infer nonnegative normalized weights from stationarity.

numberOfFeatures = size(optimalityMatrix, 2);
regularization = cfg.inverse.regularization;
augmentedMatrix = [optimalityMatrix; sqrt(regularization)*eye(numberOfFeatures)];
augmentedTarget = [zeros(size(optimalityMatrix, 1), 1); ...
    sqrt(regularization)*ones(numberOfFeatures, 1)/numberOfFeatures];

options = optimoptions("lsqlin", "Display", "off");
[weights, residualNorm, residual, exitFlag, output] = lsqlin( ...
    augmentedMatrix, augmentedTarget, [], [], ...
    ones(1, numberOfFeatures), 1, zeros(numberOfFeatures, 1), ...
    ones(numberOfFeatures, 1), [], options);

numberOfEquations = size(optimalityMatrix, 1);
matrixRank = rank(optimalityMatrix);
nullity = numberOfFeatures - matrixRank;

% Singular spectrum padded to the number of features. For a wide matrix (fewer
% stationarity rows than features) svd returns only min(m, n) values; the
% remaining directions are structurally null and are represented here as zeros,
% so the separation diagnostic reflects genuine underdetermination instead of
% being reported as infinite for, say, a one-row matrix.
if numberOfEquations == 0
    economySingularValues = zeros(0, 1);
else
    economySingularValues = svd(optimalityMatrix, "econ");
end
fullSingularValues = zeros(numberOfFeatures, 1);
fullSingularValues(1:numel(economySingularValues)) = economySingularValues;
ascendingSpectrum = sort(fullSingularValues, "ascend");
nullspaceSeparation = ascendingSpectrum(2) / max(ascendingSpectrum(1), eps);

% A normalized objective direction is locally identifiable when the stationarity
% rows leave a one-dimensional homogeneous null space that the simplex
% normalization pins down, i.e. rank at least numberOfFeatures - 1 (three
% independent rows suffice for four normalized weights). Bound-active
% demonstrations that contribute no interior rows fail this test and are
% reported as unidentifiable rather than being fit through bound rows.
locallyIdentifiable = matrixRank >= numberOfFeatures - 1;

result.weights = weights;
result.residualNorm = residualNorm;
result.residual = residual;
result.exitFlag = exitFlag;
result.output = output;
result.singularValues = economySingularValues;
result.fullSingularValues = fullSingularValues;
result.nullspaceSeparation = nullspaceSeparation;
result.matrixRank = matrixRank;
result.nullity = nullity;
result.numberOfEquations = numberOfEquations;
result.locallyIdentifiable = locallyIdentifiable;
end
