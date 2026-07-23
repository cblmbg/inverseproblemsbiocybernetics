function experiments = generateCalibrationData(cfg)
%GENERATECALIBRATIONDATA Create noisy, persistently excited time-series data.

rng(cfg.randomSeed, "twister");
times = cfg.calibration.observationTimes;
finalTime = cfg.calibration.finalTime;
experiments = repmat(struct( ...
    "times", [], "initialState", [], "controls", [], ...
    "states", [], "noiseFreeStates", []), ...
    size(cfg.calibration.initialStates, 1), 1);

for experimentIndex = 1:numel(experiments)
    phase = 0.8 * (experimentIndex - 1);
    firstControl = 0.17 + 0.52*(mod(times + 1.5*phase, 8) < 4) + ...
        0.04*sin(2*pi*times/finalTime + phase);
    secondControl = 0.19 + 0.50*(mod(times + 2.0*phase, 10) < 5) + ...
        0.04*cos(2*pi*times/finalTime - phase);
    controls = min(max([firstControl(:), secondControl(:)], 0.08), 0.82);

    initialState = cfg.calibration.initialStates(experimentIndex, :)';
    noiseFreeStates = simulateControlledModel(cfg.trueParameters, initialState, ...
        times, controls(1:end-1, :), 4);

    stateScale = max(noiseFreeStates, [], 1);
    noise = cfg.calibration.relativeNoise * randn(size(noiseFreeStates)) .* ...
        max(stateScale, 0.05);
    measuredStates = max(noiseFreeStates + noise, 1e-8);

    experiments(experimentIndex).times = times;
    experiments(experimentIndex).initialState = initialState;
    experiments(experimentIndex).controls = controls;
    experiments(experimentIndex).states = measuredStates;
    experiments(experimentIndex).noiseFreeStates = noiseFreeStates;
end
end
