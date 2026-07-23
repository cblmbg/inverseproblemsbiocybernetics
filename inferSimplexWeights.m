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

singularValues = svd(optimalityMatrix, "econ");
if numel(singularValues) > 1
    nullspaceSeparation = singularValues(end-1) / max(singularValues(end), eps);
else
    nullspaceSeparation = inf;
end

result.weights = weights;
result.residualNorm = residualNorm;
result.residual = residual;
result.exitFlag = exitFlag;
result.output = output;
result.singularValues = singularValues;
result.nullspaceSeparation = nullspaceSeparation;
result.matrixRank = rank(optimalityMatrix);
result.numberOfEquations = size(optimalityMatrix, 1);
end
