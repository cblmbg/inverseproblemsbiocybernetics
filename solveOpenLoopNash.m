function solution = solveOpenLoopNash(parameters, initialState, timeGrid, ...
    playerWeights, cfg, initialControls)
%SOLVEOPENLOOPNASH Compute a two-player Nash equilibrium by best responses.

numberOfIntervals = numel(timeGrid) - 1;
if nargin < 6 || isempty(initialControls)
    controls = cfg.control.initialGuess * ones(numberOfIntervals, 2);
else
    controls = initialControls;
end

lowerBounds = cfg.control.lowerBound * ones(numberOfIntervals, 1);
upperBounds = cfg.control.upperBound * ones(numberOfIntervals, 1);
options = optimoptions("fmincon", ...
    "Algorithm", "sqp", ...
    "Display", cfg.optimization.display, ...
    "MaxIterations", 70, ...
    "MaxFunctionEvaluations", 3500, ...
    "OptimalityTolerance", 2e-6, ...
    "StepTolerance", 1e-8);

converged = false;
bestResponseGap = inf;
for iteration = 1:cfg.level4.maximumBestResponseIterations
    previousControls = controls;
    for player = 1:2
        opponentControls = controls;
        [bestResponse, ~] = fmincon(@playerObjective, controls(:, player), ...
            [], [], [], [], lowerBounds, upperBounds, [], options);
        controls(:, player) = cfg.level4.damping * bestResponse + ...
            (1 - cfg.level4.damping) * controls(:, player);
    end

    bestResponseGap = norm(controls - previousControls, inf);
    if bestResponseGap < cfg.level4.bestResponseTolerance
        converged = true;
        break
    end
end

states = simulateControlledModel(parameters, initialState, timeGrid, controls, ...
    cfg.control.integrationSubsteps);
playerFeatures = zeros(4, 2);
playerObjectives = zeros(1, 2);
unilateralImprovement = zeros(1, 2);

for player = 1:2
    playerFeatures(:, player) = playerCostFeatures(player, timeGrid, ...
        states, controls);
    playerObjectives(player) = playerWeights(:, player)' * ...
        playerFeatures(:, player);
    fixedControls = controls;
    [~, bestResponseValue] = fmincon(@finalPlayerObjective, ...
        controls(:, player), [], [], [], [], lowerBounds, upperBounds, [], options);
    unilateralImprovement(player) = max(0, ...
        playerObjectives(player) - bestResponseValue);
end
converged = converged || max(unilateralImprovement) < 1e-4;

solution.controls = controls;
solution.states = states;
solution.features = playerFeatures;
solution.objectiveValues = playerObjectives;
solution.converged = converged;
solution.iterations = iteration;
solution.bestResponseGap = bestResponseGap;
solution.unilateralImprovement = unilateralImprovement;

    function value = playerObjective(candidatePlayerControl)
        candidateControls = opponentControls;
        candidateControls(:, player) = candidatePlayerControl;
        candidateStates = simulateControlledModel(parameters, initialState, ...
            timeGrid, candidateControls, cfg.control.integrationSubsteps);
        features = playerCostFeatures(player, timeGrid, candidateStates, ...
            candidateControls);
        value = playerWeights(:, player)' * features;
    end

    function value = finalPlayerObjective(candidatePlayerControl)
        candidateControls = fixedControls;
        candidateControls(:, player) = candidatePlayerControl;
        candidateStates = simulateControlledModel(parameters, initialState, ...
            timeGrid, candidateControls, cfg.control.integrationSubsteps);
        features = playerCostFeatures(player, timeGrid, candidateStates, ...
            candidateControls);
        value = playerWeights(:, player)' * features;
    end
end
