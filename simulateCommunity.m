function states = simulateCommunity(parameters, initialState, sampleTimes, controlTimes, controls)
%SIMULATECOMMUNITY Simulate the community with interpolated controls.
%
%   STATES = SIMULATECOMMUNITY(P, X0, T, TU, U) uses ODE15S and returns one
%   row per requested sample time.

arguments
    parameters (1,1) struct
    initialState (5,1) double
    sampleTimes (1,:) double
    controlTimes (1,:) double
    controls (:,2) double
end

if size(controls, 1) ~= numel(controlTimes)
    error("InverseLadder:ControlSize", ...
        "The control array must have one row per control time.");
end
if any(diff(sampleTimes) <= 0) || any(diff(controlTimes) <= 0)
    error("InverseLadder:IncreasingTimes", ...
        "Sample and control times must be strictly increasing.");
end

rhs = @(t, x) communityRhs(t, x, interpolateControl(t), parameters);
options = odeset("RelTol", 1e-7, "AbsTol", 1e-9, "NonNegative", 1:5);
[~, states] = ode15s(rhs, sampleTimes, initialState, options);

    function u = interpolateControl(t)
        u = interp1(controlTimes, controls, t, "linear", "extrap")';
        u = min(max(u, 0), 1);
    end
end
