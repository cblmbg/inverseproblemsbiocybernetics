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
if numberOfFeatures >= 2
    nullspaceSeparation = ascendingSpectrum(2) / max(ascendingSpectrum(1), eps);
else
    % A single-feature simplex has the unique weight 1; there is no competing
    % direction from which to separate.
    nullspaceSeparation = inf;
end

% A normalized objective direction is locally identifiable only if the
% constrained least-squares problem on the simplex has a unique minimizer, which
% holds iff the stacked system [A; 1'] has full column rank. Testing rank(A)
% alone is not sufficient: if the identified direction is parallel to the
% normalization constraint, normalization adds no independent information and a
% continuum of feasible weights fits the data equally well.
normalizedRank = rank([optimalityMatrix; ones(1, numberOfFeatures)]);
locallyIdentifiable = normalizedRank == numberOfFeatures;

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
result.normalizedRank = normalizedRank;
result.numberOfEquations = numberOfEquations;
result.locallyIdentifiable = locallyIdentifiable;
end
