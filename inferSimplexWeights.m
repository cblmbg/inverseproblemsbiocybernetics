function result = inferSimplexWeights(equalityMatrix, cfg, options)
%INFERSIMPLEXWEIGHTS Infer simplex weights from equality and bound KKT rows.
%
%   RESULT = INFERSIMPLEXWEIGHTS(AEQ, CFG) fits nonnegative weights that sum
%   to one using the interior-control stationarity equations AEQ*w = 0.
%
%   RESULT = INFERSIMPLEXWEIGHTS(AEQ, CFG, LowerBoundMatrix=ALO,
%   UpperBoundMatrix=AHI) additionally imposes the reduced-gradient KKT
%   conditions ALO*w >= 0 and AHI*w <= 0, with the configured scale-aware
%   finite-difference tolerance.

arguments
    equalityMatrix (:,:) double {mustBeFinite}
    cfg (1,1) struct
    options.LowerBoundMatrix (:,:) double {mustBeFinite} = zeros(0, 0)
    options.UpperBoundMatrix (:,:) double {mustBeFinite} = zeros(0, 0)
end

numberOfFeatures = size(equalityMatrix, 2);
lowerBoundMatrix = validateKktMatrix(options.LowerBoundMatrix, ...
    numberOfFeatures, "LowerBoundMatrix");
upperBoundMatrix = validateKktMatrix(options.UpperBoundMatrix, ...
    numberOfFeatures, "UpperBoundMatrix");

regularization = cfg.inverse.regularization;
augmentedMatrix = [equalityMatrix; sqrt(regularization)*eye(numberOfFeatures)];
augmentedTarget = [zeros(size(equalityMatrix, 1), 1); ...
    sqrt(regularization)*ones(numberOfFeatures, 1)/numberOfFeatures];

[inequalityMatrix, inequalityTarget, normalizedLowerMatrix, ...
    normalizedUpperMatrix] = buildKktInequalities(lowerBoundMatrix, ...
    upperBoundMatrix, cfg);
normalizationMatrix = ones(1, numberOfFeatures);
normalizationTarget = 1;
lowerWeights = zeros(numberOfFeatures, 1);
upperWeights = ones(numberOfFeatures, 1);
optionsLsqlin = optimoptions("lsqlin", "Display", "off");
[weights, residualNorm, residual, exitFlag, output] = lsqlin( ...
    augmentedMatrix, augmentedTarget, inequalityMatrix, inequalityTarget, ...
    normalizationMatrix, normalizationTarget, lowerWeights, upperWeights, ...
    [], optionsLsqlin);

% Solve the same constrained least-squares problem without the prior. This
% data-only problem, not the strictly convex regularized fit above, defines
% identification. A zero objective row keeps lsqlin well-formed when there are
% no interior equations.
dataMatrix = equalityMatrix;
dataTarget = zeros(size(equalityMatrix, 1), 1);
if isempty(dataMatrix)
    dataMatrix = zeros(1, numberOfFeatures);
    dataTarget = 0;
end
dataOptions = optimoptions(optionsLsqlin, "OptimalityTolerance", 1e-12, ...
    "StepTolerance", 1e-12, "ConstraintTolerance", 1e-12);
[dataWeights, dataResidualNorm, ~, dataExitFlag, dataOutput] = lsqlin( ...
    dataMatrix, dataTarget, inequalityMatrix, inequalityTarget, ...
    normalizationMatrix, normalizationTarget, lowerWeights, upperWeights, ...
    [], dataOptions);

numberOfEquations = size(equalityMatrix, 1);
matrixRank = rank(equalityMatrix);
nullity = numberOfFeatures - matrixRank;

% Singular spectrum padded to the number of features. For a wide matrix (fewer
% stationarity rows than features) svd returns only min(m, n) values; the
% remaining directions are structurally null and are represented here as zeros.
if numberOfEquations == 0
    economySingularValues = zeros(0, 1);
else
    economySingularValues = svd(equalityMatrix, "econ");
end
fullSingularValues = zeros(numberOfFeatures, 1);
fullSingularValues(1:numel(economySingularValues)) = economySingularValues;
ascendingSpectrum = sort(fullSingularValues, "ascend");
if numberOfFeatures >= 2
    nullspaceSeparation = ascendingSpectrum(2) / ...
        max(ascendingSpectrum(1), eps);
else
    nullspaceSeparation = inf;
end

% Retain the equality-only augmented rank as a diagnostic. Bound inequalities
% can identify a boundary solution even when this rank is deficient, so the
% definitive conservative flag below uses the complete data-only minimizer set.
normalizedRank = rank([equalityMatrix; normalizationMatrix]);
[weightRanges, rangeExitFlags] = dataOnlyWeightRanges(equalityMatrix, ...
    dataWeights, dataExitFlag, inequalityMatrix, inequalityTarget, cfg);
weightRangeWidths = weightRanges(:, 2) - weightRanges(:, 1);
rangeProblemsSucceeded = all(rangeExitFlags > 0, "all") && ...
    all(isfinite(weightRangeWidths), "all");
if rangeProblemsSucceeded
    maximumWeightRange = max(weightRangeWidths, [], "all");
else
    maximumWeightRange = inf;
end
dataIdentifiable = dataExitFlag > 0 && rangeProblemsSucceeded && ...
    maximumWeightRange <= cfg.inverse.weightRangeTolerance;

[equalityResidual, lowerViolation, upperViolation, kktResidual] = ...
    kktResiduals(weights, equalityMatrix, normalizedLowerMatrix, ...
    normalizedUpperMatrix, cfg.inverse.kktScaleFloor);
kktCompatible = exitFlag > 0 && isfinite(kktResidual) && ...
    kktResidual <= cfg.inverse.kktGradientTolerance + ...
    cfg.inverse.kktCompatibilityTolerance;
locallyIdentifiable = dataIdentifiable && kktCompatible;

result.weights = weights;
result.residualNorm = residualNorm;
result.residual = residual;
result.exitFlag = exitFlag;
result.output = output;
result.dataWeights = dataWeights;
result.dataResidualNorm = dataResidualNorm;
result.dataExitFlag = dataExitFlag;
result.dataOutput = dataOutput;
result.singularValues = economySingularValues;
result.fullSingularValues = fullSingularValues;
result.nullspaceSeparation = nullspaceSeparation;
result.matrixRank = matrixRank;
result.nullity = nullity;
result.normalizedRank = normalizedRank;
result.numberOfEquations = numberOfEquations;
result.interiorRowCount = numberOfEquations;
result.lowerActiveRowCount = size(lowerBoundMatrix, 1);
result.upperActiveRowCount = size(upperBoundMatrix, 1);
result.equalityResidual = equalityResidual;
result.lowerViolation = lowerViolation;
result.upperViolation = upperViolation;
result.kktResidual = kktResidual;
result.kktCompatible = kktCompatible;
result.weightRanges = weightRanges;
result.weightRangeWidths = weightRangeWidths;
result.maximumWeightRange = maximumWeightRange;
result.rangeExitFlags = rangeExitFlags;
result.dataIdentifiable = dataIdentifiable;
result.locallyIdentifiable = locallyIdentifiable;
end

function matrix = validateKktMatrix(matrix, numberOfFeatures, argumentName)
%VALIDATEKKTMATRIX Give an empty KKT group the expected number of columns.
if isempty(matrix)
    matrix = zeros(0, numberOfFeatures);
elseif size(matrix, 2) ~= numberOfFeatures
    error("InverseLadder:KktMatrixSize", ...
        "%s must have %d columns, one per candidate feature.", ...
        argumentName, numberOfFeatures);
end
end

function [matrix, target, normalizedLower, normalizedUpper] = ...
    buildKktInequalities(lowerMatrix, upperMatrix, cfg)
%BUILDKKTINEQUALITIES Convert bound-gradient signs to lsqlin form C*w <= d.
normalizedLower = normalizeRows(lowerMatrix, cfg.inverse.kktScaleFloor);
normalizedUpper = normalizeRows(upperMatrix, cfg.inverse.kktScaleFloor);
matrix = [-normalizedLower; normalizedUpper];
target = cfg.inverse.kktGradientTolerance * ones(size(matrix, 1), 1);
end

function normalized = normalizeRows(matrix, scaleFloor)
%NORMALIZEROWS Scale gradient rows without changing their signs.
if isempty(matrix)
    normalized = matrix;
    return
end
scales = max(vecnorm(matrix, 2, 2), scaleFloor);
normalized = matrix ./ scales;
end

function [ranges, exitFlags] = dataOnlyWeightRanges(equalityMatrix, ...
    dataWeights, dataExitFlag, inequalityMatrix, inequalityTarget, cfg)
%DATAONLYWEIGHTRANGES Bound each weight over all unregularized QP minimizers.
numberOfFeatures = size(equalityMatrix, 2);
ranges = nan(numberOfFeatures, 2);
exitFlags = nan(numberOfFeatures, 2);
if dataExitFlag <= 0 || numel(dataWeights) ~= numberOfFeatures
    return
end

% For a convex least-squares objective, all minimizers have the same A*w.
% An orthonormal row-space basis removes redundant equations and characterizes
% that minimizer set with linear equalities suitable for robust LP range checks.
matrixRank = rank(equalityMatrix);
if matrixRank > 0
    [~, ~, rightVectors] = svd(equalityMatrix, "econ");
    rowBasis = rightVectors(:, 1:matrixRank)';
else
    rowBasis = zeros(0, numberOfFeatures);
end
linearEqualityMatrix = [ones(1, numberOfFeatures); rowBasis];
linearEqualityTarget = [1; rowBasis*dataWeights];
lowerWeights = zeros(numberOfFeatures, 1);
upperWeights = ones(numberOfFeatures, 1);
optionsLinprog = optimoptions("linprog", "Display", "off");

for featureIndex = 1:numberOfFeatures
    objective = zeros(numberOfFeatures, 1);
    objective(featureIndex) = 1;
    [~, minimumValue, minimumExitFlag] = linprog(objective, ...
        inequalityMatrix, inequalityTarget, linearEqualityMatrix, ...
        linearEqualityTarget, lowerWeights, upperWeights, optionsLinprog);
    [~, negativeMaximum, maximumExitFlag] = linprog(-objective, ...
        inequalityMatrix, inequalityTarget, linearEqualityMatrix, ...
        linearEqualityTarget, lowerWeights, upperWeights, optionsLinprog);
    ranges(featureIndex, :) = [minimumValue, -negativeMaximum];
    exitFlags(featureIndex, :) = [minimumExitFlag, maximumExitFlag];
end

% Remove harmless solver-scale negative widths before the configured
% uniqueness comparison; materially negative widths remain visible as failure.
smallNegative = ranges(:, 2) < ranges(:, 1) & ...
    ranges(:, 1) - ranges(:, 2) <= cfg.inverse.weightRangeTolerance;
ranges(smallNegative, 2) = ranges(smallNegative, 1);
end

function [equalityResidual, lowerViolation, upperViolation, combined] = ...
    kktResiduals(weights, equalityMatrix, normalizedLower, ...
    normalizedUpper, scaleFloor)
%KKTRESIDUALS Return normalized equality and bound-sign residuals.
if numel(weights) ~= size(equalityMatrix, 2) || any(~isfinite(weights))
    equalityResidual = inf;
    lowerViolation = inf;
    upperViolation = inf;
    combined = inf;
    return
end
normalizedEquality = normalizeRows(equalityMatrix, scaleFloor);
equalityResidual = maximumOrZero(abs(normalizedEquality*weights));
lowerViolation = maximumOrZero(max(0, -normalizedLower*weights));
upperViolation = maximumOrZero(max(0, normalizedUpper*weights));
combined = max([equalityResidual, lowerViolation, upperViolation]);
end

function value = maximumOrZero(values)
%MAXIMUMORZERO Maximum of a possibly empty residual vector.
if isempty(values)
    value = 0;
else
    value = max(values, [], "all");
end
end
