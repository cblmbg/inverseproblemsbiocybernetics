function states = simulateCommunity(parameters, initialState, sampleTimes, controlTimes, controls)
%SIMULATECOMMUNITY Simulate the community with interpolated controls.
%
%   STATES = SIMULATECOMMUNITY(P, X0, T, TU, U) uses ODE15S and returns one
%   row per requested sample time.

arguments
    parameters (1,1) struct
    initialState (5,1) double {mustBeFinite}
    sampleTimes (1,:) double {mustBeFinite}
    controlTimes (1,:) double {mustBeFinite}
    controls (:,2) double {mustBeFinite}
end

validateModelParameters(parameters);
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
% Evaluate the solution at exactly the requested sample times. Passing the
% sample times directly to ode15s does not honor the one-row-per-sample-time
% contract when only two times are requested (the solver then returns its own
% adaptive mesh), so integrate once over the span and evaluate with deval.
solution = ode15s(rhs, [sampleTimes(1), sampleTimes(end)], initialState, options);
states = deval(solution, sampleTimes)';
if ~all(isfinite(states), "all")
    error("InverseLadder:NonFiniteState", ...
        "Integration produced a non-finite state.");
end

    function u = interpolateControl(t)
        u = interp1(controlTimes, controls, t, "linear", "extrap")';
        u = min(max(u, 0), 1);
    end
end
