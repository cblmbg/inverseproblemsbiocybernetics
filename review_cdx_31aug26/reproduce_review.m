function audit = reproduce_review(repoPath)
%REPRODUCE_REVIEW Re-run the 31 August 2026 review without modifying the package.
%
%   AUDIT = REPRODUCE_REVIEW() uses the repository containing this folder.
%   AUDIT = REPRODUCE_REVIEW(REPOPATH) uses a different checkout.
%   MATLAB R2026a and Optimization, Statistics and Machine Learning, and
%   Signal Processing Toolboxes are required. Expected runtime: about 1 minute.
%   Existing unit tests run as supplied. The remaining checks are diagnostic
%   experiments: they display current behavior, including expected defects.
%   This function does not save, export, or change any repository files.

arguments
    repoPath (1,1) string = string(fileparts(fileparts(mfilename('fullpath'))))
end
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
originalRng = rng;
restoreRng = onCleanup(@() rng(originalRng)); %#ok<NASGU>
addpath(repoPath);
fprintf('MATLAB %s\n',version);
files = dir(fullfile(repoPath,'*.m'));
audit.analyzerFindingCount = 0;
for k = 1:numel(files)
    issues = checkcode(fullfile(files(k).folder,files(k).name),'-struct');
    audit.analyzerFindingCount = audit.analyzerFindingCount+numel(issues);
end
fprintf('Code Analyzer: %d files, %d findings\n',numel(files),audit.analyzerFindingCount);
audit.unitTests = runtests(fullfile(repoPath,'testInverseLadderCaseStudy.m'));
audit.baseline = runInverseLadderCaseStudy('MakePlots',false,'SaveResults',false);
cfg = audit.baseline.configuration;
p = audit.baseline.level1.estimatedParameters;

slowCfg = cfg;
slowCfg.level4.damping = .001;
audit.slowNash = solveOpenLoopNash(p,cfg.defaultInitialState,cfg.control.timeGrid,cfg.level4.trueWeights,slowCfg);
s = audit.slowNash;
fprintf('F1 slow damping: converged=%d, iterations=%d, update=%g, improvements=%s\n',s.converged,s.iterations,s.bestResponseGap,mat2str(s.unilateralImprovement,8));

boundCfg = cfg;
boundCfg.level3.trueWeights = [0;1;0;0];
audit.boundCase = runLevel3InverseOptimalControl(boundCfg,p);
fprintf('F2 active bounds: weights=%s, error=%g, control RMSE=%g\n',mat2str(audit.boundCase.inferredWeights',8),audit.boundCase.weightError,mean(audit.boundCase.controlRmse));
fprintf('F2 nonzero residual of true optimum=%g\n',norm(audit.boundCase.optimalityMatrix*audit.boundCase.trueWeights));

failedCfg = cfg;
failedCfg.optimization.maximumIterations = 0;
audit.failedPlanner = runLevel3InverseOptimalControl(failedCfg,p);
fprintf('F3 failed planner: exit=%d, RMSE=%g, weight error=%g\n',audit.failedPlanner.observations{1}.exitFlag,mean(audit.failedPlanner.controlRmse),audit.failedPlanner.weightError);
failedCfg = cfg;
failedCfg.level4.maximumBestResponseIterations = 1;
audit.failedGame = runLevel4InverseDifferentialGame(failedCfg,p);
fprintf('F3 failed game: demo convergence=%d,%d; validation convergence=%d,%d\n',audit.failedGame.observations{1}.converged,audit.failedGame.observations{2}.converged,audit.failedGame.validation{1}.converged,audit.failedGame.validation{2}.converged);

audit.numerics = reviewNumericalChecks(audit.baseline);
audit.discovery = reviewDiscoveryChecks(audit.baseline);
audit.multistartDeviations = reviewBestResponses(audit.baseline);

audit.invalidTimeStates = simulateControlledModel(p,cfg.defaultInitialState,[0 NaN 2],.35*ones(2,2),4);
audit.invalidControlStates = simulateControlledModel(p,cfg.defaultInitialState,[0 1 2],[NaN .35;.35 .35],4);
fprintf('F6 NaN time: all finite=%d terminal=%s; NaN control: all finite=%d\n',all(isfinite(audit.invalidTimeStates),'all'),mat2str(audit.invalidTimeStates(end,:),5),all(isfinite(audit.invalidControlStates),'all'));

audit.twoTimeStates = simulateCommunity(p,cfg.defaultInitialState,[0 1],[0 1],.35*ones(2,2));
fprintf('F7 two requested times: returned size=%s\n',mat2str(size(audit.twoTimeStates)));

audit.underdetermined = inferSimplexWeights([1 -1 0 0],cfg);
fprintf('F9 one row, four weights: rank=%d, separation=%g, weights=%s\n',audit.underdetermined.matrixRank,audit.underdetermined.nullspaceSeparation,mat2str(audit.underdetermined.weights',5));
end

function audit = reviewNumericalChecks(results)
%REVIEWNUMERICALCHECKS Independent numerical probes, without editing the package.
cfg = results.configuration;
p = results.level1.estimatedParameters;
grid = cfg.control.timeGrid;
audit.refinement = [];
for level = [3 4]
    entry = results.(sprintf('level%d',level));
    for experiment = 1:2
        x0 = cfg.control.initialStates(experiment,:)';
        u = entry.observations{experiment}.controls;
        reference = intervalOde(p,x0,grid,u);
        for substeps = [4 8 16 64]
            x = simulateControlledModel(p,x0,grid,u,substeps);
            row = [level experiment substeps rms(x-reference,'all') max(abs(x-reference),[],'all')];
            audit.refinement = [audit.refinement; row]; %#ok<AGROW>
        end
    end
end
fprintf('ODE REFERENCE: level experiment substeps RMS maxabs\n');
disp(audit.refinement);

% Identical admissible controls, at corners and with switches.
cases = {0.02*ones(8,2),0.95*ones(8,2),repmat([0.02 0.95],8,1), ...
    repmat([0.95 0.02],8,1),repmat([0.02 0.95;0.95 0.02],4,1)};
audit.corners = zeros(numel(cases),3);
for k = 1:numel(cases)
    reference = intervalOde(p,cfg.defaultInitialState,grid,cases{k});
    coarse = simulateControlledModel(p,cfg.defaultInitialState,grid,cases{k},4);
    audit.corners(k,:) = [k rms(coarse-reference,'all') max(abs(coarse-reference),[],'all')];
end
fprintf('ADMISSIBLE CONTROL CORNERS: case RMS maxabs\n');
disp(audit.corners);

% Adaptive simulator uses a different control interpolation convention.
audit.controlInterpolation = zeros(3,3);
for e = 1:3
    data = results.calibrationExperiments(e);
    piecewise = intervalOde(cfg.trueParameters,data.initialState,data.times,data.controls(1:end-1,:));
    linear = simulateCommunity(cfg.trueParameters,data.initialState,data.times,data.times,data.controls);
    rk = data.noiseFreeStates;
    audit.controlInterpolation(e,:) = [e rms(linear-piecewise,'all') rms(rk-piecewise,'all')];
end
fprintf('CALIBRATION: experiment linear-vs-ZOH RMS RK4-vs-ZOH RMS\n');
disp(audit.controlInterpolation);

% No smoothing or observation noise: isolate integrated input quadrature.
audit.windowQuadrature = zeros(2,3);
for strain = 1:2
    errOriginal = [];
    errZoh = [];
    for e = 1:3
        data = results.calibrationExperiments(e);
        x = data.noiseFreeStates;
        t = data.times(:);
        u = data.controls(:,strain);
        m = x(:,3)./(cfg.trueParameters.substrateHalfSaturation(strain)+x(:,3)) .* ...
            x(:,6-strain)./(cfg.trueParameters.metaboliteHalfSaturation(strain)+x(:,6-strain));
        for first = 2:numel(t)-5
            last = first+4;
            duration = t(last)-t(first);
            mu = cfg.trueParameters.maximumGrowthRate(strain);
            cost = cfg.trueParameters.allocationCost(strain);
            target = (log(x(last,strain))-log(x(first,strain)))/duration;
            original = mu*trapz(t(first:last),m(first:last).*(1-cost*u(first:last)))/duration-cfg.trueParameters.dilutionRate;
            consistent = mu*sum(diff(t(first:last)).*0.5.*(m(first:last-1)+m(first+1:last)).*(1-cost*u(first:last-1)))/duration-cfg.trueParameters.dilutionRate;
            errOriginal(end+1,1) = original-target; %#ok<AGROW>
            errZoh(end+1,1) = consistent-target; %#ok<AGROW>
        end
    end
    audit.windowQuadrature(strain,:) = [strain rms(errOriginal) rms(errZoh)];
end
fprintf('NOISE-FREE GROWTH: strain original-quadrature RMS ZOH-consistent RMS\n');
disp(audit.windowQuadrature);
end

function states = intervalOde(p,x0,t,u)
states = zeros(numel(t),5);
states(1,:) = x0(:)';
opts = odeset('RelTol',1e-10,'AbsTol',1e-12,'NonNegative',1:5);
for k = 1:numel(t)-1
    [~,x] = ode15s(@(tt,xx) communityRhs(tt,xx,u(k,:)',p),t(k:k+1),states(k,:)',opts);
    states(k+1,:) = x(end,:);
end
end

function audit = reviewDiscoveryChecks(results)
%REVIEWDISCOVERYCHECKS Measure leakage and alternative input quadrature.
cfg = results.configuration;
p = results.level1.estimatedParameters;
audit = struct();
for strain = 1:2
    [X,y,groups,firsts] = design(results.calibrationExperiments,p,strain,false);
    [Z,~,~,~] = design(results.calibrationExperiments,p,strain,true);
    rng(314,'twister');
    folds = cvpartition(size(X,1),'KFold',5);
    contaminated = false(size(y));
    for fold = 1:5
        tr = find(training(folds,fold));
        te = find(test(folds,fold));
        for j = te'
            contaminated(j) = any(groups(tr)==groups(j) & abs(firsts(tr)-firsts(j))<=4);
        end
    end
    [b,info] = lasso(X,y,'CV',folds,'Standardize',true);
    randomBeta = b(:,info.IndexMinMSE);
    [bz,iz] = lasso(Z,y,'CV',folds,'Standardize',true);
    zohBeta = bz(:,iz.IndexMinMSE);
    randomBeta(abs(randomBeta)<.03*max(abs(randomBeta)))=0;
    zohBeta(abs(zohBeta)<.03*max(abs(zohBeta)))=0;
    entry.fractionTestWindowsSharingSamples = mean(contaminated);
    entry.randomFoldCVmse = info.MSE(info.IndexMinMSE);
    entry.randomBeta = randomBeta;
    entry.zohBeta = zohBeta;
    entry.sampleCounts = accumarray(groups,1);
    fprintf('DISCOVERY STRAIN %d leakage %.1f%%; beta original=%s; beta ZOH=%s\n',strain,100*mean(contaminated),mat2str(randomBeta',5),mat2str(zohBeta',5));
    audit.(sprintf('strain%d',strain)) = entry;
end

% Exact ground-truth model and no observation noise, exercising original API.
noiseFreeCfg = cfg;
noiseFreeCfg.calibration.relativeNoise = 0;
noiseFreeData = generateCalibrationData(noiseFreeCfg);
noiseFree = runLevel2ModelDiscovery(noiseFreeCfg,noiseFreeData,cfg.trueParameters);
fprintf('NOISE-FREE ORIGINAL LEVEL2 COEFFICIENTS\n');
disp(noiseFree.coefficients);
fprintf('supportRecovered=%d falsePositives=%d\n',noiseFree.supportRecovered,nnz(noiseFree.selected(3:end,:)));
audit.noiseFree = noiseFree;
end

function [X,y,groups,firsts] = design(experiments,p,strain,useZoh)
X=[]; y=[]; groups=[]; firsts=[];
for e=1:numel(experiments)
    data=experiments(e);
    t=data.times(:);
    x=sgolayfilt(data.states,3,9);
    S=max(x(:,3),0); M=max(x(:,6-strain),0); u=data.controls(:,strain);
    m=S./(p.substrateHalfSaturation(strain)+S).*M./(p.metaboliteHalfSaturation(strain)+M);
    candidates=[m m.*u x(:,1) x(:,2) S M u];
    for first=2:numel(t)-5
        last=first+4;
        if min(x([first,last],strain))<=.02
            continue
        end
        duration=t(last)-t(first);
        row=trapz(t(first:last),candidates(first:last,:),1)/duration;
        if useZoh
            dt=diff(t(first:last));
            row(2)=sum(dt.*.5.*(m(first:last-1)+m(first+1:last)).*u(first:last-1))/duration;
            row(7)=sum(dt.*u(first:last-1))/duration;
        end
        X(end+1,:)=row; %#ok<AGROW>
        y(end+1,1)=(log(x(last,strain))-log(x(first,strain)))/duration; %#ok<AGROW>
        groups(end+1,1)=e; %#ok<AGROW>
        firsts(end+1,1)=first; %#ok<AGROW>
    end
end
end

function gaps = reviewBestResponses(results)
%REVIEWBESTRESPONSES Try additional starts for default unilateral deviations.
cfg=results.configuration;
p=results.level1.estimatedParameters;
opts=optimoptions('fmincon','Display','off','Algorithm','sqp', ...
    'MaxIterations',150,'MaxFunctionEvaluations',8000,'OptimalityTolerance',1e-8);
gaps=zeros(2,2);
rng(419,'twister');
for e=1:2
    s=results.level4.observations{e};
    x0=cfg.control.initialStates(e,:)';
    for player=1:2
        weights=cfg.level4.trueWeights(:,player);
        f=@(v) playerObjective(v,player,s.controls,p,x0,cfg,weights);
        best=inf;
        for start=1:5
            if start==1
                u=cfg.control.lowerBound*ones(8,1);
            elseif start==2
                u=cfg.control.upperBound*ones(8,1);
            else
                u=cfg.control.lowerBound+(cfg.control.upperBound-cfg.control.lowerBound)*rand(8,1);
            end
            [~,value]=fmincon(f,u,[],[],[],[],cfg.control.lowerBound*ones(8,1),cfg.control.upperBound*ones(8,1),[],opts);
            best=min(best,value);
        end
        gaps(e,player)=max(0,s.objectiveValues(player)-best);
    end
end
fprintf('DEFAULT NASH MULTISTART DEVIATIONS\n');
disp(gaps);
end

function f=playerObjective(v,player,controls,p,x0,cfg,weights)
controls(:,player)=v;
states=simulateControlledModel(p,x0,cfg.control.timeGrid,controls,cfg.control.integrationSubsteps);
features=playerCostFeatures(player,cfg.control.timeGrid,states,controls);
f=weights'*features;
end
