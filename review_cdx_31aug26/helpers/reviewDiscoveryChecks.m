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
