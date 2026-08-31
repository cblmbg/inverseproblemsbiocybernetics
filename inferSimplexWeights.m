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

% Conservative local-identifiability flag. Full column rank of the stacked
% system [A; 1'] is *sufficient* for a unique minimizer on the affine
% normalization plane, so it rules out the parallel-to-normalization
% non-uniqueness that a rank(A) test alone misses. It is *not necessary* on the
% nonnegative simplex: active nonnegativity constraints can make a boundary
% solution unique even when [A; 1'] is rank deficient, so this flag can be a
% (safe) false negative at the boundary. Uniqueness supplied only by the
% regularizer is likewise not data identification. A full active-set uniqueness
% test is left as a separate diagnostic.
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
