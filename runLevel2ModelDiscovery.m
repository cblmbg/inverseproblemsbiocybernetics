function result = runLevel2ModelDiscovery(~, experiments, estimatedParameters)
%RUNLEVEL2MODELDISCOVERY Discover the biomass growth-law structure.
%
% The candidate library includes mechanistically motivated Monod terms and
% phenomenological gLV/environmental alternatives. LASSO is applied to the
% per-capita growth rate estimated from smoothed trajectories.

libraryNames = ["Monod cross-feeding"; "Monod x allocation"; ...
    "Strain 1 abundance"; "Strain 2 abundance"; "Substrate"; ...
    "Received metabolite"; "Allocation"];

coefficients = zeros(numel(libraryNames), 2);
intercepts = zeros(1, 2);
selected = false(numel(libraryNames), 2);
fitR2 = zeros(1, 2);
sampleCount = zeros(1, 2);

for strain = 1:2
    designMatrix = [];
    response = [];
    for experimentIndex = 1:numel(experiments)
        experiment = experiments(experimentIndex);
        times = experiment.times(:);
        states = experiment.states;
        controls = experiment.controls;

        frameLength = min( nineOrLess(size(states, 1)), size(states, 1));
        smoothedStates = sgolayfilt(states, 3, frameLength);
        substrate = max(smoothedStates(:, 3), 0);
        if strain == 1
            receivedMetabolite = max(smoothedStates(:, 5), 0);
        else
            receivedMetabolite = max(smoothedStates(:, 4), 0);
        end
        monodTerm = substrate ./ ...
            (estimatedParameters.substrateHalfSaturation(strain) + substrate) .* ...
            receivedMetabolite ./ ...
            (estimatedParameters.metaboliteHalfSaturation(strain) + ...
            receivedMetabolite);

        candidateMatrix = [monodTerm, monodTerm .* controls(:, strain), ...
            smoothedStates(:, 1), smoothedStates(:, 2), substrate, ...
            receivedMetabolite, controls(:, strain)];

        windowLength = 4;
        for firstIndex = 2:numel(times)-windowLength-1
            lastIndex = firstIndex + windowLength;
            if min(smoothedStates([firstIndex,lastIndex], strain)) <= 0.02
                continue
            end
            windowTimes = times(firstIndex:lastIndex);
            duration = windowTimes(end) - windowTimes(1);
            averageCandidates = trapz(windowTimes, ...
                candidateMatrix(firstIndex:lastIndex, :), 1) / duration;
            averageGrowth = (log(smoothedStates(lastIndex, strain)) - ...
                log(smoothedStates(firstIndex, strain))) / duration;
            designMatrix = [designMatrix; averageCandidates]; %#ok<AGROW>
            response = [response; averageGrowth]; %#ok<AGROW>
        end
    end

    [betaPath, fitInfo] = lasso(designMatrix, response, ...
        "CV", 5, "Standardize", true);
    sparseIndex = fitInfo.IndexMinMSE;
    beta = betaPath(:, sparseIndex);
    intercept = fitInfo.Intercept(sparseIndex);
    threshold = 0.03 * max(abs(beta));
    beta(abs(beta) < threshold) = 0;

    prediction = intercept + designMatrix * beta;
    coefficients(:, strain) = beta;
    intercepts(strain) = intercept;
    selected(:, strain) = beta ~= 0;
    fitR2(strain) = 1 - sum((response - prediction).^2) / ...
        sum((response - mean(response)).^2);
    sampleCount(strain) = numel(response);
end

result.libraryNames = libraryNames;
result.coefficients = coefficients;
result.intercepts = intercepts;
result.selected = selected;
result.fitR2 = fitR2;
result.sampleCount = sampleCount;
result.expectedSupport = [true; true; false; false; false; false; false];
result.supportRecovered = all(selected(1:2, :), "all");
end

function frameLength = nineOrLess(numberOfRows)
frameLength = min(9, numberOfRows);
if mod(frameLength, 2) == 0
    frameLength = frameLength - 1;
end
frameLength = max(frameLength, 5);
end
