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
% Findings 3 and R4: with a zero iteration budget the planner cannot solve, so
% the demonstrations are not optimal. The level must report an unverified
% status, must not return misleadingly small reproduction errors, and must not
% let the failed demonstrations enter the inverse problem.
cfg = defaultInverseLadderConfig();
cfg.optimization.maximumIterations = 0;
warningState = warning;
warning("off", "runLevel3InverseOptimalControl:unverified");
warning("off", "runLevel3InverseOptimalControl:notIdentifiable");
cleanup = onCleanup(@() warning(warningState));
result = runLevel3InverseOptimalControl(cfg, cfg.trueParameters);
verifyEqual(testCase, result.status, "unverified");
verifyTrue(testCase, all(isnan(result.controlRmse)));
verifyTrue(testCase, all(~result.demonstrationSuccess));
verifyEqual(testCase, result.interiorRowCount, 0);
verifyFalse(testCase, result.identifiable);
end

function testBoundActiveDemonstrationNotIdentifiable(testCase)
% Finding 2: when the demonstrations sit on an active control bound (here a
% pure control-effort objective drives every control to the lower bound), no
% interior stationarity rows exist. The level must report the objective as not
% identifiable rather than fitting the true weights through bound rows.
cfg = defaultInverseLadderConfig();
cfg.level3.trueWeights = [0; 1; 0; 0];
warningState = warning("off", "runLevel3InverseOptimalControl:notIdentifiable");
cleanup = onCleanup(@() warning(warningState));
result = runLevel3InverseOptimalControl(cfg, cfg.trueParameters);
verifyFalse(testCase, result.identifiable);
verifyEqual(testCase, result.interiorRowCount, 0);
end

function testUnderdeterminedSeparationIsFinite(testCase)
% Finding 9: a single stationarity row over four weights leaves a
% three-dimensional null space. The separation diagnostic must be finite (the
% wide matrix is underdetermined, not perfectly separated) and the objective
% must be reported as not identifiable.
cfg = defaultInverseLadderConfig();
result = inferSimplexWeights([1 -1 0 0], cfg);
verifyTrue(testCase, isfinite(result.nullspaceSeparation));
verifyFalse(testCase, result.locallyIdentifiable);
verifyEqual(testCase, result.nullity, 3);
verifyEqual(testCase, result.matrixRank, 1);
end

function testLevel2SupportMetricIsExact(testCase)
% Finding 8: supportRecovered must mean exact recovery of the true support
% (both true terms present and zero false positives), not merely that the two
% true terms appear. Also checks that a held-out prediction metric is produced.
cfg = defaultInverseLadderConfig();
cfg.calibration.relativeNoise = 0;
data = generateCalibrationData(cfg);
result = runLevel2ModelDiscovery(cfg, data, cfg.trueParameters);
verifyEqual(testCase, result.supportRecovered, ...
    all(result.trueTermsRecovered) && all(result.falsePositiveCount == 0));
if any(result.falsePositiveCount > 0)
    verifyFalse(testCase, result.supportRecovered);
end
verifyEqual(testCase, numel(result.holdoutR2), 2);
verifyTrue(testCase, all(result.holdoutSampleCount > 0));
end

function testNonFiniteInputsAreRejected(testCase)
% Finding 6: non-finite times, controls, or states must be rejected rather than
% silently clipped to plausible values.
cfg = defaultInverseLadderConfig();
p = cfg.trueParameters;
x0 = cfg.defaultInitialState;
verifyError(testCase, ...
    @() simulateControlledModel(p, x0, [0 NaN 2], 0.35*ones(2, 2), 4), ...
    "MATLAB:validators:mustBeFinite");
verifyError(testCase, ...
    @() simulateControlledModel(p, x0, [0 1 2], [NaN 0.35; 0.35 0.35], 4), ...
    "MATLAB:validators:mustBeFinite");
end

function testSimulateCommunityTwoTimeContract(testCase)
% Finding 7: with two requested sample times the adaptive simulator must return
% one row per requested time, not its internal adaptive mesh.
cfg = defaultInverseLadderConfig();
states = simulateCommunity(cfg.trueParameters, cfg.defaultInitialState, ...
    [0 1], [0 1], 0.35*ones(2, 2));
verifySize(testCase, states, [2, 5]);
end

function testNashCertificateRequiresFeasibility(testCase)
% R1: an infeasible initial guess must not be carried into the updates and
% certified. The returned profile must satisfy the control bounds.
cfg = defaultInverseLadderConfig();
cfg.control.initialGuess = 0;
weights = [0 0; 1 1; 0 0; 0 0];
solution = solveOpenLoopNash(cfg.trueParameters, cfg.defaultInitialState, ...
    cfg.control.timeGrid, weights, cfg);
verifyGreaterThanOrEqual(testCase, min(solution.controls(:)), ...
    cfg.control.lowerBound - 1e-6);
verifyTrue(testCase, solution.feasible);
end

function testIdentifiabilityRequiresNormalizationIndependence(testCase)
% R2: rank(A) = features-1 is not sufficient for identification when the
% identified direction is parallel to the normalization constraint.
cfg = defaultInverseLadderConfig();
matrix = [1 1 1 1; 1 -1 0 0; 0 0 1 -1];
result = inferSimplexWeights(matrix, cfg);
verifyEqual(testCase, result.matrixRank, 3);
verifyEqual(testCase, result.normalizedRank, 3);
verifyFalse(testCase, result.locallyIdentifiable);
end

function testNonFiniteParametersRejected(testCase)
% R3: a non-finite kinetic parameter must be rejected, not silently masked.
cfg = defaultInverseLadderConfig();
p = cfg.trueParameters;
p.allocationCost(1) = NaN;
verifyError(testCase, ...
    @() simulateControlledModel(p, cfg.defaultInitialState, [0 1 2], ...
    0.35*ones(2, 2), 4), "InverseLadder:NonFiniteParameter");
verifyError(testCase, ...
    @() simulateCommunity(p, cfg.defaultInitialState, [0 1 2], [0 1 2], ...
    0.35*ones(3, 2)), "InverseLadder:NonFiniteParameter");
end

function testLevel2SingleGroupNotCrossValidated(testCase)
% R5: leave-one-experiment-out selection needs at least two groups. With one
% experiment, the penalty must be reported as not cross-validated.
cfg = defaultInverseLadderConfig();
rng(cfg.randomSeed, "twister");
experiments = generateCalibrationData(cfg);
warningState = warning("off", "runLevel2ModelDiscovery:noCrossValidation");
cleanup = onCleanup(@() warning(warningState));
result = runLevel2ModelDiscovery(cfg, experiments(1), cfg.trueParameters);
verifyTrue(testCase, all(~result.crossValidated));
end

function testOneFeatureInverseProblem(testCase)
% R6: a one-feature simplex has the unique weight 1 and must not crash.
cfg = defaultInverseLadderConfig();
result = inferSimplexWeights(zeros(3, 1), cfg);
verifyEqual(testCase, result.weights, 1, "AbsTol", 1e-8);
verifyTrue(testCase, result.locallyIdentifiable);
end

function testNashRejectsNonFiniteStart(testCase)
% N1: a non-finite starting profile must be rejected, not silently projected
% onto a bound. Covers both the configured guess and an explicit warm start.
cfg = defaultInverseLadderConfig();
weights = [0 0; 1 1; 0 0; 0 0];
badCfg = cfg;
badCfg.control.initialGuess = NaN;
verifyError(testCase, ...
    @() solveOpenLoopNash(cfg.trueParameters, cfg.defaultInitialState, ...
    cfg.control.timeGrid, weights, badCfg), "InverseLadder:NonFiniteControls");
initialControls = 0.35 * ones(numel(cfg.control.timeGrid) - 1, 2);
initialControls(1, 1) = NaN;
verifyError(testCase, ...
    @() solveOpenLoopNash(cfg.trueParameters, cfg.defaultInitialState, ...
    cfg.control.timeGrid, weights, cfg, initialControls), ...
    "InverseLadder:NonFiniteControls");
end

function testIdentifiabilityFlagIsConservativeAtBoundary(testCase)
% N2: the augmented-rank flag is a conservative (sufficient, not necessary)
% criterion. A boundary-unique case (min (w2+w3)^2 on the simplex has the unique
% minimizer [1;0;0]) is reported as not identifiable; the flag must be false and
% must not error.
cfg = defaultInverseLadderConfig();
result = inferSimplexWeights([0 1 1], cfg);
verifyEqual(testCase, result.normalizedRank, 2);
verifyFalse(testCase, result.locallyIdentifiable);
end
