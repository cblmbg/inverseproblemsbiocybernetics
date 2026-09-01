function figureHandle = plotInverseLadderResults(results)
%PLOTINVERSELADDERRESULTS Plot a compact four-level diagnostic summary.

figureHandle = figure("Color", "w", "Name", "Inverse Ladder Case Study");
layout = tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");
title(layout, "Four-level inverse ladder for a microbial consortium");

nexttile;
bar([results.level1.trueVector, results.level1.estimatedVector]);
xticks(1:numel(results.level1.parameterNames));
xticklabels(results.level1.parameterNames);
xtickangle(35);
ylabel("Parameter value");
title("Level 1: parameter estimation");
legend("True", "Estimated", "Location", "best");
grid on;

nexttile;
barh(results.level2.coefficients);
yticks(1:numel(results.level2.libraryNames));
yticklabels(results.level2.libraryNames);
set(gca, "YDir", "reverse");
xlabel("Coefficient");
title("Level 2: sparse discovered coefficients");
legend("Strain 1", "Strain 2", "Location", "southeast");
grid on;

nexttile;
bar([results.level3.trueWeights, results.level3.inferredWeights]);
xticks(1:numel(results.level3.featureNames));
xticklabels(results.level3.featureNames);
xtickangle(30);
ylabel("Normalized weight");
title("Level 3: centralized objective");
legend("True", "Inferred", "Location", "best");
grid on;

nexttile;
playerLabels = ["P1 true", "P1 inferred", "P2 true", "P2 inferred"];
bar([results.level4.trueWeights(:, 1), ...
    results.level4.inferredWeights(:, 1), ...
    results.level4.trueWeights(:, 2), ...
    results.level4.inferredWeights(:, 2)]);
xticks(1:numel(results.level4.featureNames));
xticklabels(results.level4.featureNames);
xtickangle(30);
ylabel("Normalized weight");
title("Level 4: player-specific objectives");
legend(playerLabels, "Location", "best");
grid on;
end
