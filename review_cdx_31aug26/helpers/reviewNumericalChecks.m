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
