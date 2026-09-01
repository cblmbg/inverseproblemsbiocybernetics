function results = runInverseLadderCaseStudy(options)
%RUNINVERSELADDERCASESTUDY Execute all four inverse-problem levels.
%
%   RESULTS = RUNINVERSELADDERCASESTUDY() generates synthetic microbial
%   community data, calibrates the mechanistic model, discovers its growth
%   structure, infers a centralized objective, and infers two player-specific
%   objectives from an open-loop Nash equilibrium.
%
%   RESULTS = RUNINVERSELADDERCASESTUDY("MakePlots", false) suppresses plots.

arguments
    options.MakePlots (1,1) logical = true
    options.SaveResults (1,1) logical = true
end

cfg = defaultInverseLadderConfig();
rng(cfg.randomSeed, "twister");

fprintf("Inverse ladder case study\n");
fprintf("=========================\n");

fprintf("Analysing structural identifiability and observability...\n");
runLevel1aprioriIdentifiability(options.SaveResults);

fprintf("Generating calibration experiments...\n");
experiments = generateCalibrationData(cfg);

fprintf("Level 1: estimating kinetic parameters...\n");
level1 = runLevel1ParameterEstimation(cfg, experiments);
fprintf("  relative parameter error: %.3g\n", level1.relativeParameterError);

fprintf("Level 2: discovering the biomass growth law...\n");
level2 = runLevel2ModelDiscovery(cfg, experiments, ...
    level1.estimatedParameters);
fprintf("  in-sample integrated-growth R^2: strain 1 %.3f, strain 2 %.3f\n", ...
    level2.fitR2(1), level2.fitR2(2));
fprintf("  held-out prediction R^2: strain 1 %.3f, strain 2 %.3f\n", ...
    level2.holdoutR2(1), level2.holdoutR2(2));
fprintf("  exact support recovered (both strains): %d\n", ...
    level2.supportRecovered);

fprintf("Level 3: inferring a centralized optimality principle...\n");
level3 = runLevel3InverseOptimalControl(cfg, level1.estimatedParameters);
fprintf("  status: %s\n", level3.status);
fprintf("  objective identifiable: %d\n", level3.identifiable);
fprintf("  objective-weight error: %.3g\n", level3.weightError);
fprintf("  forward control RMSE: %.3g\n", mean(level3.controlRmse));

fprintf("Level 4: inferring player-specific objectives...\n");
level4 = runLevel4InverseDifferentialGame(cfg, ...
    level1.estimatedParameters);
fprintf("  status: %s\n", level4.status);
fprintf("  objectives identifiable: %s\n", mat2str(level4.identifiable));
fprintf("  player weight errors: %.3g, %.3g\n", ...
    level4.weightError(1), level4.weightError(2));
fprintf("  forward Nash control RMSE: %.3g\n", mean(level4.controlRmse));

results.configuration = cfg;
results.calibrationExperiments = experiments;
results.level1 = level1;
results.level2 = level2;
results.level3 = level3;
results.level4 = level4;

if options.MakePlots
    results.figure = plotInverseLadderResults(results);
end

if options.SaveResults
    outputFolder = fileparts(mfilename("fullpath"));
    resultsToSave = results;
    if isfield(resultsToSave, "figure")
        resultsToSave = rmfield(resultsToSave, "figure");
    end
    save(fullfile(outputFolder, "inverse_ladder_results.mat"), ...
        "resultsToSave", "-v7.3");
    if options.MakePlots
        exportgraphics(results.figure, ...
            fullfile(outputFolder, "inverse_ladder_summary.png"), ...
            "Resolution", 180);
    end
end

fprintf("Case study complete.\n");
end
