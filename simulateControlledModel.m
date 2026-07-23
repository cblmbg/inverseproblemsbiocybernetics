function states = simulateControlledModel(parameters, initialState, timeGrid, controls, substeps)
%SIMULATECONTROLLEDMODEL Integrate piecewise-constant controls using RK4.
%
% This fixed-step simulator is used inside optimization loops. CONTROLS has
% one row for each interval in TIMEGRID.

arguments
    parameters (1,1) struct
    initialState (5,1) double
    timeGrid (1,:) double
    controls (:,2) double
    substeps (1,1) double {mustBeInteger,mustBePositive} = 4
end

numberOfIntervals = numel(timeGrid) - 1;
if any(diff(timeGrid) <= 0)
    error("InverseLadder:IncreasingTimes", ...
        "TIMEGRID must be strictly increasing.");
end
if size(controls, 1) ~= numberOfIntervals
    error("InverseLadder:ControlIntervals", ...
        "CONTROLS must contain one row for each time interval.");
end

states = zeros(numel(timeGrid), 5);
states(1, :) = initialState(:)';
currentState = initialState(:);

for interval = 1:numberOfIntervals
    step = (timeGrid(interval + 1) - timeGrid(interval)) / substeps;
    control = controls(interval, :)';
    currentTime = timeGrid(interval);
    for substep = 1:substeps
        k1 = communityRhs(currentTime, currentState, control, parameters);
        k2 = communityRhs(currentTime + step / 2, ...
            currentState + step * k1 / 2, control, parameters);
        k3 = communityRhs(currentTime + step / 2, ...
            currentState + step * k2 / 2, control, parameters);
        k4 = communityRhs(currentTime + step, ...
            currentState + step * k3, control, parameters);
        currentState = currentState + step * ...
            (k1 + 2*k2 + 2*k3 + k4) / 6;
        currentState = max(currentState, 1e-10);
        currentTime = currentTime + step;
    end
    states(interval + 1, :) = currentState';
end
end
