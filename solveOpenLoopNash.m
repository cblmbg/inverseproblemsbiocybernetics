function solution = solveOpenLoopNash(parameters, initialState, timeGrid, ...
    playerWeights, cfg, initialControls)
%SOLVEOPENLOOPNASH Compute a two-player Nash equilibrium by best responses.
%
%   The returned CONVERGED flag and STATUS certify only a local, numerical
%   approximate open-loop equilibrium; they do not establish a global Nash
%   equilibrium. Certification requires the unilateral best-response check to
%   pass AND every certifying optimization to succeed with finite outputs. A
%   small damped-iterate change alone is not sufficient, because reducing the
%   damping shrinks that change regardless of how far a best response lies.

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

bestResponseToleranceSatisfied = false;
bestResponseGap = inf;
innerSolvesSucceeded = true;
for iteration = 1:cfg.level4.maximumBestResponseIterations
    previousControls = controls;
    for player = 1:2
        opponentControls = controls;
        [bestResponse, ~, innerExitFlag] = fmincon(@playerObjective, ...
            controls(:, player), [], [], [], [], lowerBounds, upperBounds, ...
            [], options);
        innerSolvesSucceeded = innerSolvesSucceeded && ...
            innerExitFlag > 0 && all(isfinite(bestResponse));
        controls(:, player) = cfg.level4.damping * bestResponse + ...
            (1 - cfg.level4.damping) * controls(:, player);
    end

    bestResponseGap = norm(controls - previousControls, inf);
    if bestResponseGap < cfg.level4.bestResponseTolerance
        bestResponseToleranceSatisfied = true;
        break
    end
end

states = simulateControlledModel(parameters, initialState, timeGrid, controls, ...
    cfg.control.integrationSubsteps);
playerFeatures = zeros(4, 2);
playerObjectives = zeros(1, 2);
unilateralImprovement = zeros(1, 2);
finalExitFlags = zeros(1, 2);

for player = 1:2
    playerFeatures(:, player) = playerCostFeatures(player, timeGrid, ...
        states, controls);
    playerObjectives(player) = playerWeights(:, player)' * ...
        playerFeatures(:, player);
    fixedControls = controls;
    [~, bestResponseValue, finalExitFlag] = fmincon(@finalPlayerObjective, ...
        controls(:, player), [], [], [], [], lowerBounds, upperBounds, [], options);
    finalExitFlags(player) = finalExitFlag;
    unilateralImprovement(player) = max(0, ...
        playerObjectives(player) - bestResponseValue);
end

% Certify only an approximate, local equilibrium. The damped-iterate change
% (bestResponseGap) is retained as a diagnostic, not a certificate: a small
% damping factor makes it tiny regardless of the true best-response distance.
% The equilibrium is certified only when the unilateral-deviation check passes
% AND the certifying re-optimizations succeeded with finite outputs; otherwise a
% seemingly small improvement may simply reflect a failed inner solve.
finiteOutputs = all(isfinite(controls), "all") && all(isfinite(states), "all");
finalSolvesSucceeded = all(finalExitFlags > 0);
solverSuccess = finalSolvesSucceeded && finiteOutputs;
unilateralImprovementToleranceSatisfied = max(unilateralImprovement) < ...
    cfg.level4.unilateralImprovementTolerance;
verified = unilateralImprovementToleranceSatisfied && solverSuccess;

solution.controls = controls;
solution.states = states;
solution.features = playerFeatures;
solution.objectiveValues = playerObjectives;
solution.converged = verified;
if verified
    solution.status = "verified";
else
    solution.status = "unverified";
end
solution.iterations = iteration;
solution.bestResponseGap = bestResponseGap;
solution.bestResponseToleranceSatisfied = bestResponseToleranceSatisfied;
solution.unilateralImprovement = unilateralImprovement;
solution.unilateralImprovementToleranceSatisfied = ...
    unilateralImprovementToleranceSatisfied;
solution.solverSuccess = solverSuccess;
solution.finalExitFlags = finalExitFlags;
solution.innerSolvesSucceeded = innerSolvesSucceeded;

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
