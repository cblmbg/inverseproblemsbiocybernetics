function generateReportFigures()
%GENERATEREPORTFIGURES Create publication-quality figures for the report.

reportFolder = fileparts(mfilename("fullpath"));
caseStudyFolder = fileparts(reportFolder);
figureFolder = fullfile(reportFolder, "figures");
addpath(caseStudyFolder);

loaded = load(fullfile(caseStudyFolder, "inverse_ladder_results.mat"), ...
    "resultsToSave");
results = loaded.resultsToSave;

createCalibrationFigure(results, figureFolder);
createLevel3Figure(results, figureFolder);
createLevel4Figure(results, figureFolder);
copyfile(fullfile(caseStudyFolder, "inverse_ladder_summary.png"), ...
    fullfile(figureFolder, "inverse_ladder_summary.png"));
end

function createCalibrationFigure(results, figureFolder)
experiment = results.calibrationExperiments(1);
prediction = results.level1.predictions{1};
names = ["Strain 1", "Strain 2", "Substrate", ...
    "Metabolite 1", "Metabolite 2"];

figureHandle = figure("Color", "w", "Position", [100 100 1100 650]);
layout = tiledlayout(2, 3, "TileSpacing", "compact", "Padding", "compact");
title(layout, "Level 1 calibration: experiment 1");
for stateIndex = 1:5
    nexttile;
    plot(experiment.times, experiment.states(:, stateIndex), "o", ...
        "MarkerSize", 3.5, "Color", [0.15 0.45 0.75], ...
        "DisplayName", "Noisy data");
    hold on;
    plot(experiment.times, prediction(:, stateIndex), "-", ...
        "LineWidth", 1.6, "Color", [0.85 0.25 0.15], ...
        "DisplayName", "Fitted model");
    xlabel("Time");
    ylabel(names(stateIndex));
    grid on;
    if stateIndex == 1
        legend("Location", "best");
    end
end
nexttile;
stairs(experiment.times, experiment.controls(:, 1), "-", ...
    "LineWidth", 1.5, "DisplayName", "u_1");
hold on;
stairs(experiment.times, experiment.controls(:, 2), "-", ...
    "LineWidth", 1.5, "DisplayName", "u_2");
xlabel("Time");
ylabel("Allocation control");
ylim([0 1]);
grid on;
legend("Location", "best");

exportgraphics(figureHandle, ...
    fullfile(figureFolder, "level1_calibration.png"), "Resolution", 220);
close(figureHandle);
end

function createLevel3Figure(results, figureFolder)
timeGrid = results.configuration.control.timeGrid;
observed = results.level3.observations{1};
validated = results.level3.validation{1};

figureHandle = figure("Color", "w", "Position", [100 100 1100 650]);
layout = tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");
title(layout, "Level 3 inverse optimal control and forward validation");

nexttile;
stairs(timeGrid(1:end-1), observed.controls(:, 1), "-", ...
    "LineWidth", 1.6, "DisplayName", "Observed u_1");
hold on;
stairs(timeGrid(1:end-1), observed.controls(:, 2), "-", ...
    "LineWidth", 1.6, "DisplayName", "Observed u_2");
stairs(timeGrid(1:end-1), validated.controls(:, 1), "--", ...
    "LineWidth", 1.3, "DisplayName", "Validated u_1");
stairs(timeGrid(1:end-1), validated.controls(:, 2), "--", ...
    "LineWidth", 1.3, "DisplayName", "Validated u_2");
xlabel("Time");
ylabel("Allocation");
ylim([0 1]);
grid on;
legend("Location", "best");

nexttile;
plot(timeGrid, observed.states(:, 1:2), "-", "LineWidth", 1.6);
hold on;
plot(timeGrid, validated.states(:, 1:2), "--", "LineWidth", 1.3);
xlabel("Time");
ylabel("Biomass");
grid on;
legend("Observed X_1", "Observed X_2", ...
    "Validated X_1", "Validated X_2", "Location", "best");

nexttile;
bar([results.level3.trueWeights, results.level3.inferredWeights]);
xticks(1:4);
xticklabels(["Biomass", "Control", "Substrate", "Imbalance"]);
xtickangle(20);
ylabel("Normalized weight");
grid on;
legend("True", "Inferred", "Location", "best");

nexttile;
semilogy(results.level3.inverseDiagnostics.singularValues, "o-", ...
    "LineWidth", 1.5, "MarkerSize", 6);
xlabel("Singular-value index");
ylabel("Singular value");
title("Inverse stationarity matrix");
grid on;

exportgraphics(figureHandle, ...
    fullfile(figureFolder, "level3_ioc.png"), "Resolution", 220);
close(figureHandle);
end

function createLevel4Figure(results, figureFolder)
timeGrid = results.configuration.control.timeGrid;
observed = results.level4.observations{1};
validated = results.level4.validation{1};

figureHandle = figure("Color", "w", "Position", [100 100 1100 650]);
layout = tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");
title(layout, "Level 4 inverse differential game and Nash validation");

nexttile;
stairs(timeGrid(1:end-1), observed.controls(:, 1), "-", ...
    "LineWidth", 1.6, "DisplayName", "Observed u_1");
hold on;
stairs(timeGrid(1:end-1), observed.controls(:, 2), "-", ...
    "LineWidth", 1.6, "DisplayName", "Observed u_2");
stairs(timeGrid(1:end-1), validated.controls(:, 1), "--", ...
    "LineWidth", 1.3, "DisplayName", "Validated u_1");
stairs(timeGrid(1:end-1), validated.controls(:, 2), "--", ...
    "LineWidth", 1.3, "DisplayName", "Validated u_2");
xlabel("Time");
ylabel("Allocation");
ylim([0 1]);
grid on;
legend("Location", "best");

nexttile;
plot(timeGrid, observed.states(:, 1:2), "-", "LineWidth", 1.6);
hold on;
plot(timeGrid, validated.states(:, 1:2), "--", "LineWidth", 1.3);
xlabel("Time");
ylabel("Biomass");
grid on;
legend("Observed X_1", "Observed X_2", ...
    "Validated X_1", "Validated X_2", "Location", "best");

nexttile;
bar([results.level4.trueWeights(:, 1), ...
    results.level4.inferredWeights(:, 1), ...
    results.level4.trueWeights(:, 2), ...
    results.level4.inferredWeights(:, 2)]);
xticks(1:4);
xticklabels(["Own biomass", "Reg. effort", "Metabolite", "Partner"]);
xtickangle(20);
ylabel("Normalized weight");
grid on;
legend("P1 true", "P1 inferred", "P2 true", "P2 inferred", ...
    "Location", "best");

nexttile;
semilogy(results.level4.inverseDiagnostics{1}.singularValues, ...
    "o-", "LineWidth", 1.5, "DisplayName", "Player 1");
hold on;
semilogy(results.level4.inverseDiagnostics{2}.singularValues, ...
    "s-", "LineWidth", 1.5, "DisplayName", "Player 2");
xlabel("Singular-value index");
ylabel("Singular value");
title("Player stationarity matrices");
grid on;
legend("Location", "best");

exportgraphics(figureHandle, ...
    fullfile(figureFolder, "level4_idg.png"), "Resolution", 220);
close(figureHandle);
end
