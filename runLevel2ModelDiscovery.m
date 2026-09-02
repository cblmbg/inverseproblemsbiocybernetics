function result = runLevel2ModelDiscovery(cfg, experiments, estimatedParameters)
%RUNLEVEL2MODELDISCOVERY Discover the biomass growth-law structure.
%
% The candidate library includes mechanistically motivated Monod terms and
% phenomenological gLV/environmental alternatives. Sparse regression is applied
% to the window-integrated per-capita growth rate. Three consistency choices
% follow the 31 August 2026 review:
%
%   * the zero-order-held allocation inputs are integrated with a left-held
%     convention, consistent with how the calibration data were generated,
%     rather than trapezoidally averaging across control switches;
%   * the LASSO penalty is selected by leave-one-experiment-out cross-validation
%     so that overlapping windows never straddle a train/validation split, and
%     per-experiment smoothing does not leak between folds;
%   * generalization is assessed on separate held-out experiments, distinct from
%     the fitting data used to select the penalty.
%
% Algorithm outline (mirrors the Level 2 pseudocode in the accompanying
% manuscript, "Level 2: model discovery"):
%   1. for each strain, build window-integrated per-capita growth and
%      averaged library rows from smoothed states and left-held controls;
%   2. with at least two experiment groups, select the LASSO penalty by
%      leave-one-experiment-out cross-validation; otherwise use a fixed
%      fallback, then threshold small coefficients;
%   3. report in-sample and held-out fit and compare the selected support with
%      the expected support.

libraryNames = ["Monod cross-feeding"; "Monod x allocation"; ...
    "Strain 1 abundance"; "Strain 2 abundance"; "Substrate"; ...
    "Received metabolite"; "Allocation"];
numberOfFeatures = numel(libraryNames);
expectedSupport = [true; true; false; false; false; false; false];

coefficients = zeros(numberOfFeatures, 2);
intercepts = zeros(1, 2);
selected = false(numberOfFeatures, 2);
fitR2 = zeros(1, 2);
holdoutR2 = nan(1, 2);
holdoutRmse = nan(1, 2);
sampleCount = zeros(1, 2);
holdoutSampleCount = zeros(1, 2);
selectedLambda = zeros(1, 2);
crossValidated = false(1, 2);
observedGrowth = cell(1, 2);
predictedGrowth = cell(1, 2);

holdoutExperiments = generateHoldoutExperiments(cfg);

for strain = 1:2
    [designMatrix, response, groups] = assembleDesign(experiments, strain, ...
        estimatedParameters, cfg);

    % Leave-one-experiment-out penalty selection (no window overlap across
    % folds), then refit on all fitting data at the selected penalty.
    [beta, intercept, lambdaStar, wasCrossValidated] = fitGroupedLasso( ...
        designMatrix, response, groups);
    crossValidated(strain) = wasCrossValidated;
    beta(abs(beta) < cfg.level2.coefficientThreshold * max(abs(beta))) = 0;

    prediction = intercept + designMatrix * beta;
    coefficients(:, strain) = beta;
    intercepts(strain) = intercept;
    selected(:, strain) = beta ~= 0;
    fitR2(strain) = rSquared(response, prediction);
    sampleCount(strain) = numel(response);
    selectedLambda(strain) = lambdaStar;
    observedGrowth{strain} = response;
    predictedGrowth{strain} = prediction;

    % Independent-prediction assessment on untouched held-out experiments.
    [holdoutMatrix, holdoutResponse] = assembleDesign(holdoutExperiments, ...
        strain, estimatedParameters, cfg);
    holdoutSampleCount(strain) = numel(holdoutResponse);
    if ~isempty(holdoutResponse)
        holdoutPrediction = intercept + holdoutMatrix * beta;
        holdoutRmse(strain) = sqrt(mean((holdoutResponse - holdoutPrediction).^2));
        holdoutR2(strain) = rSquared(holdoutResponse, holdoutPrediction);
    end
end

% Support diagnostics compare the complete selected mask with the expected
% support, distinguishing missed true terms from false positives instead of
% only checking that the two true terms appear.
falsePositiveCount = sum(selected(~expectedSupport, :), 1);
missedCount = sum(~selected(expectedSupport, :), 1);
trueTermsRecovered = all(selected(expectedSupport, :), 1);
exactSupportRecovered = trueTermsRecovered & (falsePositiveCount == 0);

result.libraryNames = libraryNames;
result.coefficients = coefficients;
result.intercepts = intercepts;
result.selected = selected;
result.fitR2 = fitR2;
result.inSampleR2 = fitR2;
result.holdoutR2 = holdoutR2;
result.holdoutRmse = holdoutRmse;
result.sampleCount = sampleCount;
result.holdoutSampleCount = holdoutSampleCount;
result.selectedLambda = selectedLambda;
result.crossValidated = crossValidated;
result.observedGrowth = observedGrowth;
result.predictedGrowth = predictedGrowth;
result.expectedSupport = expectedSupport;
result.trueTermsRecovered = trueTermsRecovered;
result.falsePositiveCount = falsePositiveCount;
result.missedCount = missedCount;
result.exactSupportRecovered = exactSupportRecovered;
% supportRecovered now means exact recovery of the true support for both
% strains: every true term selected and no false positive.
result.supportRecovered = all(exactSupportRecovered);
end

function [designMatrix, response, groups] = assembleDesign(experiments, ...
    strain, parameters, cfg)
%ASSEMBLEDESIGN Window-integrated growth design rows for one strain.
windowLength = cfg.level2.windowLength;
designMatrix = [];
response = [];
groups = [];
for experimentIndex = 1:numel(experiments)
    data = experiments(experimentIndex);
    times = data.times(:);
    frameLength = nineOrLess(size(data.states, 1));
    smoothedStates = sgolayfilt(data.states, 3, frameLength);
    substrate = max(smoothedStates(:, 3), 0);
    if strain == 1
        receivedMetabolite = max(smoothedStates(:, 5), 0);
    else
        receivedMetabolite = max(smoothedStates(:, 4), 0);
    end
    monodTerm = substrate ./ ...
        (parameters.substrateHalfSaturation(strain) + substrate) .* ...
        receivedMetabolite ./ ...
        (parameters.metaboliteHalfSaturation(strain) + receivedMetabolite);
    allocation = data.controls(:, strain);
    strain1 = smoothedStates(:, 1);
    strain2 = smoothedStates(:, 2);

    for firstIndex = 2:numel(times)-windowLength-1
        lastIndex = firstIndex + windowLength;
        if min(smoothedStates([firstIndex, lastIndex], strain)) <= 0.02
            continue
        end
        window = firstIndex:lastIndex;
        windowTimes = times(window);
        duration = windowTimes(end) - windowTimes(1);
        stepLengths = diff(windowTimes);
        leftHeldAllocation = allocation(window(1:end-1));
        midMonod = 0.5 * (monodTerm(window(1:end-1)) + monodTerm(window(2:end)));

        % Continuous state-derived candidates use trapezoidal integration; the
        % allocation-dependent candidates use the left-held zero-order input,
        % matching the piecewise-constant control that generated the data.
        row = [ trapz(windowTimes, monodTerm(window)), ...
            sum(stepLengths .* midMonod .* leftHeldAllocation), ...
            trapz(windowTimes, strain1(window)), ...
            trapz(windowTimes, strain2(window)), ...
            trapz(windowTimes, substrate(window)), ...
            trapz(windowTimes, receivedMetabolite(window)), ...
            sum(stepLengths .* leftHeldAllocation) ] / duration;

        growth = (log(smoothedStates(lastIndex, strain)) - ...
            log(smoothedStates(firstIndex, strain))) / duration;

        designMatrix = [designMatrix; row]; %#ok<AGROW>
        response = [response; growth]; %#ok<AGROW>
        groups = [groups; experimentIndex]; %#ok<AGROW>
    end
end
end

function [beta, intercept, lambdaStar, crossValidated] = fitGroupedLasso( ...
    designMatrix, response, groups)
%FITGROUPEDLASSO Select the LASSO penalty by leave-one-experiment-out CV.
[~, pathInfo] = lasso(designMatrix, response, "Standardize", true);
lambdas = pathInfo.Lambda;
uniqueGroups = unique(groups);
if numel(uniqueGroups) < 2
    % Leave-one-experiment-out cross-validation needs at least two groups. With
    % only one, fall back to a fixed mid-path penalty and report that no fold
    % ran, rather than presenting an uncross-validated penalty as selected.
    crossValidated = false;
    lambdaStar = lambdas(max(1, round(numel(lambdas) / 2)));
    warning("runLevel2ModelDiscovery:noCrossValidation", ...
        "Fewer than two experiment groups are available; the LASSO penalty " + ...
        "was set to a fixed fallback value rather than cross-validated.");
else
    crossValidated = true;
    squaredError = zeros(1, numel(lambdas));
    validationCount = 0;
    for groupIndex = uniqueGroups(:)'
        trainRows = groups ~= groupIndex;
        testRows = groups == groupIndex;
        [trainBeta, trainInfo] = lasso(designMatrix(trainRows, :), ...
            response(trainRows), "Lambda", lambdas, "Standardize", true);
        prediction = trainInfo.Intercept + designMatrix(testRows, :) * trainBeta;
        squaredError = squaredError + ...
            sum((prediction - response(testRows)).^2, 1);
        validationCount = validationCount + sum(testRows);
    end
    crossValidatedMse = squaredError / validationCount;
    [~, bestLambdaIndex] = min(crossValidatedMse);
    lambdaStar = lambdas(bestLambdaIndex);
end
[beta, refitInfo] = lasso(designMatrix, response, "Lambda", lambdaStar, ...
    "Standardize", true);
intercept = refitInfo.Intercept;
end

function holdoutExperiments = generateHoldoutExperiments(cfg)
%GENERATEHOLDOUTEXPERIMENTS Independent experiments for prediction assessment.
holdoutConfig = cfg;
holdoutConfig.calibration.initialStates = cfg.level2.holdoutInitialStates;
holdoutConfig.randomSeed = cfg.level2.holdoutSeed;
rngState = rng;
restoreRng = onCleanup(@() rng(rngState));
holdoutExperiments = generateCalibrationData(holdoutConfig);
end

function value = rSquared(response, prediction)
value = 1 - sum((response - prediction).^2) / ...
    sum((response - mean(response)).^2);
end

function frameLength = nineOrLess(numberOfRows)
frameLength = min(9, numberOfRows);
if mod(frameLength, 2) == 0
    frameLength = frameLength - 1;
end
frameLength = max(frameLength, 5);
end
