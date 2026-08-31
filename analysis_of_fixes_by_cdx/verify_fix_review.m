function audit = verify_fix_review(repoPath)
%VERIFY_FIX_REVIEW Independent probes for fix/review-cdx-31aug26 at 4b670b1.
%
%   AUDIT = VERIFY_FIX_REVIEW(REPOPATH) runs the supplied tests, the default
%   workflow without file/figure output, and the remaining-defect probes.
%   Requires MATLAB R2026a and the three toolboxes used by the case study.
%   This is a diagnostic runner, not a suite that treats current defects as
%   correct behavior. Exceptions from probes are recorded, allowing it to
%   continue when future fixes reject invalid inputs.
%   No repository files are modified; path and RNG state are restored.

arguments
    repoPath (1,1) string
end
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
originalRng = rng;
restoreRng = onCleanup(@() rng(originalRng)); %#ok<NASGU>
addpath(repoPath);
fprintf('MATLAB %s\n', version);
audit.source = which('runInverseLadderCaseStudy');
fprintf('Source: %s\n', audit.source);
audit.tests = runtests(fullfile(repoPath, 'testInverseLadderCaseStudy.m'));
fprintf('Supplied tests: passed=%d, failed=%d\n', ...
    nnz([audit.tests.Passed]), nnz([audit.tests.Failed]));
audit.baseline = runInverseLadderCaseStudy('MakePlots', false, 'SaveResults', false);
cfg = audit.baseline.configuration;
p = audit.baseline.level1.estimatedParameters;

% R1: a valid damping factor mixes a feasible best response with an infeasible
% starting guess. A final deviation gap of zero does not certify feasibility.
feasibilityCfg = cfg;
feasibilityCfg.control.initialGuess = 0;
effortWeights = [0 0; 1 1; 0 0; 0 0];
audit.feasibility = capture(@() solveOpenLoopNash(p, cfg.defaultInitialState, ...
    cfg.control.timeGrid, effortWeights, feasibilityCfg));
if isempty(audit.feasibility.errorId)
    s = audit.feasibility.value;
    audit.feasibility.lowerBoundViolation = max(cfg.control.lowerBound-s.controls, [], 'all');
    fprintf('R1: status=%s, lower-bound violation=%g, improvements=%s, finalFlags=%s\n', ...
        s.status, audit.feasibility.lowerBoundViolation, ...
        mat2str(s.unilateralImprovement, 9), mat2str(s.finalExitFlags));
else
    fprintf('R1: rejected (%s)\n', audit.feasibility.errorId);
end

% R2: normalization is dependent on A's first row. Two distinct feasible
% weights give identical predictions, yet rank(A)=features-1.
A = [1 1 1 1; 1 -1 0 0; 0 0 1 -1];
w1 = [.1; .1; .4; .4];
w2 = [.4; .4; .1; .1];
audit.identifiability = capture(@() inferSimplexWeights(A, cfg));
audit.identifiability.matrix = A;
audit.identifiability.weights1 = w1;
audit.identifiability.weights2 = w2;
audit.identifiability.normalizedRank = rank([A; ones(1, 4)]);
audit.identifiability.predictionDifference = norm(A*(w1-w2));
if isempty(audit.identifiability.errorId)
    s = audit.identifiability.value;
    fprintf('R2: identifiable=%d, rankA=%d, normalizedRank=%d, predictionDelta=%g\n', ...
        s.locallyIdentifiable, rank(A), audit.identifiability.normalizedRank, ...
        audit.identifiability.predictionDifference);
else
    fprintf('R2: rejected (%s)\n', audit.identifiability.errorId);
end

% R3: the simulators validate state/control arrays but not parameter fields.
badParameters = p;
badParameters.allocationCost(1) = NaN;
audit.nanParameterRk4 = capture(@() simulateControlledModel(badParameters, ...
    cfg.defaultInitialState, [0 1 2], .35*ones(2, 2), 4));
audit.nanParameterAdaptive = capture(@() simulateCommunity(badParameters, ...
    cfg.defaultInitialState, [0 1 2], [0 1 2], .35*ones(3, 2)));
audit.infiniteRhsControl = capture(@() communityRhs(0, ...
    cfg.defaultInitialState, [Inf; .35], p));
if isempty(audit.nanParameterRk4.errorId)
    fprintf('R3 RK4: NaN parameter accepted; all finite=%d\n', ...
        all(isfinite(audit.nanParameterRk4.value), 'all'));
else
    fprintf('R3 RK4: rejected (%s)\n', audit.nanParameterRk4.errorId);
end
if isempty(audit.nanParameterAdaptive.errorId)
    fprintf('R3 adaptive: NaN parameter accepted; all finite=%d\n', ...
        all(isfinite(audit.nanParameterAdaptive.value), 'all'));
else
    fprintf('R3 adaptive: rejected (%s)\n', audit.nanParameterAdaptive.errorId);
end

% R4: invalid demonstrations are flagged, but still enter the inverse matrix.
failedCfg = cfg;
failedCfg.optimization.maximumIterations = 0;
audit.failedDemonstrations = capture(@() runLevel3InverseOptimalControl(failedCfg, p));
if isempty(audit.failedDemonstrations.errorId)
    s = audit.failedDemonstrations.value;
    fprintf('R4: status=%s, demonstrationSuccess=%s, inverse rows=%d, identifiable=%d\n', ...
        s.status, mat2str(s.demonstrationSuccess'), s.interiorRowCount, s.identifiable);
else
    fprintf('R4: rejected (%s)\n', audit.failedDemonstrations.errorId);
end

% R5: a one-experiment dataset has no leave-one-experiment-out training fold.
audit.oneExperiment = capture(@() runLevel2ModelDiscovery(cfg, ...
    audit.baseline.calibrationExperiments(1), p));
if isempty(audit.oneExperiment.errorId)
    s = audit.oneExperiment.value;
    fprintf('R5: no usable grouped CV fold; returned lambda=%s, fitR2=%s\n', ...
        mat2str(s.selectedLambda, 9), mat2str(s.fitR2, 9));
else
    fprintf('R5: rejected (%s)\n', audit.oneExperiment.errorId);
end

% R6: the original helper handled one objective feature; the new spectrum
% indexing accesses element 2 unconditionally.
audit.oneFeature = capture(@() inferSimplexWeights(zeros(3, 1), cfg));
if isempty(audit.oneFeature.errorId)
    fprintf('R6: one-feature weights=%s\n', mat2str(audit.oneFeature.value.weights));
else
    fprintf('R6: failed (%s): %s\n', audit.oneFeature.errorId, audit.oneFeature.errorMessage);
end
end

function result = capture(operation)
%CAPTURE Keep diagnostic experiments independent without modifying the source.
result = struct('value', [], 'errorId', '', 'errorMessage', '');
try
    result.value = operation();
catch exception
    result.errorId = exception.identifier;
    result.errorMessage = exception.message;
end
end
