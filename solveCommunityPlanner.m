function solution = solveCommunityPlanner(parameters, initialState, timeGrid, ...
    weights, cfg, initialControls)
%SOLVECOMMUNITYPLANNER Solve the centralized finite-horizon control problem.

numberOfIntervals = numel(timeGrid) - 1;
if nargin < 6 || isempty(initialControls)
    initialControls = cfg.control.initialGuess * ones(numberOfIntervals, 2);
end

lowerBounds = cfg.control.lowerBound * ones(2*numberOfIntervals, 1);
upperBounds = cfg.control.upperBound * ones(2*numberOfIntervals, 1);
options = optimoptions("fmincon", ...
    "Algorithm", "sqp", ...
    "Display", cfg.optimization.display, ...
    "MaxIterations", cfg.optimization.maximumIterations, ...
    "MaxFunctionEvaluations", cfg.optimization.maximumFunctionEvaluations, ...
    "OptimalityTolerance", 1e-6, ...
    "StepTolerance", 1e-8);

initialVector = initialControls(:);
[optimalVector, objectiveValue, exitFlag, output] = fmincon( ...
    @objective, initialVector, [], [], [], [], lowerBounds, upperBounds, ...
    [], options);

controls = reshape(optimalVector, numberOfIntervals, 2);
states = simulateControlledModel(parameters, initialState, timeGrid, controls, ...
    cfg.control.integrationSubsteps);

solution.controls = controls;
solution.states = states;
solution.features = communityCostFeatures(timeGrid, states, controls, parameters);
solution.objectiveValue = objectiveValue;
solution.exitFlag = exitFlag;
solution.output = output;
% Accept a solve only on a positive exit flag with finite outputs; a
% non-positive flag means fmincon stopped without a certified local optimum
% (for example when the iteration budget is exhausted), so the returned
% controls must not be interpreted as an optimal demonstration.
solution.success = exitFlag > 0 && all(isfinite(controls), "all") && ...
    all(isfinite(states), "all");

    function value = objective(controlVector)
        candidateControls = reshape(controlVector, numberOfIntervals, 2);
        candidateStates = simulateControlledModel(parameters, initialState, ...
            timeGrid, candidateControls, cfg.control.integrationSubsteps);
        features = communityCostFeatures(timeGrid, candidateStates, ...
            candidateControls, parameters);
        value = weights(:)' * features;
    end
end
