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
