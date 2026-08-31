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
