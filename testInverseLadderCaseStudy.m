function tests = testInverseLadderCaseStudy
%TESTINVERSELADDERCASESTUDY Unit tests for the inverse-ladder implementation.
tests = functiontests(localfunctions);
end

function testDynamicsAreFinite(testCase)
cfg = defaultInverseLadderConfig();
derivative = communityRhs(0, cfg.defaultInitialState, [0.3; 0.4], ...
    cfg.trueParameters);
verifySize(testCase, derivative, [5, 1]);
verifyTrue(testCase, all(isfinite(derivative)));
end

function testFixedStepSimulationIsNonnegative(testCase)
cfg = defaultInverseLadderConfig();
timeGrid = linspace(0, 4, 5);
controls = 0.35 * ones(numel(timeGrid)-1, 2);
states = simulateControlledModel(cfg.trueParameters, ...
    cfg.defaultInitialState, timeGrid, controls, 4);
verifySize(testCase, states, [numel(timeGrid), 5]);
verifyGreaterThanOrEqual(testCase, min(states, [], "all"), 0);
end

function testOdeAndRk4SimulatorsAgree(testCase)
cfg = defaultInverseLadderConfig();
timeGrid = linspace(0, 6, 13);
intervalControls = 0.35 * ones(numel(timeGrid)-1, 2);
sampleControls = [intervalControls; intervalControls(end, :)];
odeStates = simulateCommunity(cfg.trueParameters, cfg.defaultInitialState, ...
    timeGrid, timeGrid, sampleControls);
rkStates = simulateControlledModel(cfg.trueParameters, ...
    cfg.defaultInitialState, timeGrid, intervalControls, 8);
verifyLessThan(testCase, rms(odeStates-rkStates, "all"), 2e-3);
end

function testSimplexWeightInference(testCase)
cfg = defaultInverseLadderConfig();
trueWeights = [0.50; 0.25; 0.15; 0.10];
rng(8, "twister");
matrix = randn(30, 4);
projection = eye(4) - trueWeights*trueWeights'/(trueWeights'*trueWeights);
matrix = matrix * projection;
result = inferSimplexWeights(matrix, cfg);
verifyEqual(testCase, sum(result.weights), 1, "AbsTol", 1e-8);
verifyGreaterThanOrEqual(testCase, min(result.weights), -1e-10);
verifyLessThan(testCase, norm(result.weights-trueWeights), 1e-4);
end

function testNashCertificateRejectsSmallDamping(testCase)
% Finding 1: a very small damping factor makes the damped-iterate change tiny
% without solving the game. The repaired certificate must not report such a run
% as a converged (verified) equilibrium.
cfg = defaultInverseLadderConfig();
cfg.level4.damping = 0.001;
solution = solveOpenLoopNash(cfg.trueParameters, cfg.defaultInitialState, ...
    cfg.control.timeGrid, cfg.level4.trueWeights, cfg);
verifyFalse(testCase, solution.converged);
verifyEqual(testCase, solution.status, "unverified");
verifyGreaterThan(testCase, max(solution.unilateralImprovement), ...
    cfg.level4.unilateralImprovementTolerance);
end

function testFailedPlannerSolvesAreUnverified(testCase)
% Finding 3: with a zero iteration budget the planner cannot solve, so the
% demonstrations and validations are not optimal. The level must report an
% unverified status and must not return misleadingly small reproduction errors.
cfg = defaultInverseLadderConfig();
cfg.optimization.maximumIterations = 0;
warningState = warning("off", "runLevel3InverseOptimalControl:unverified");
cleanup = onCleanup(@() warning(warningState));
result = runLevel3InverseOptimalControl(cfg, cfg.trueParameters);
verifyEqual(testCase, result.status, "unverified");
verifyTrue(testCase, all(isnan(result.controlRmse)));
verifyTrue(testCase, all(~result.demonstrationSuccess));
end
