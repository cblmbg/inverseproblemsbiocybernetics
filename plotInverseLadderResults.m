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
% Fit of the discovered sparse growth law to the data: window-integrated
% per-capita growth, predicted versus observed. Both strains fall close to the
% 1:1 line (a good fit); the discussion notes that strain 2 nonetheless recovers
% a different growth law than the true model.
hold on;
strainColors = lines(2);
observed = results.level2.observedGrowth;
predicted = results.level2.predictedGrowth;
scatterHandles = gobjects(1, 2);
legendText = strings(1, 2);
for strain = 1:2
    scatterHandles(strain) = scatter(observed{strain}, predicted{strain}, 14, ...
        strainColors(strain, :), "filled", "MarkerFaceAlpha", 0.5);
    legendText(strain) = sprintf("Strain %d (R^2 = %.2f)", strain, ...
        results.level2.fitR2(strain));
end
allValues = [observed{1}; observed{2}; predicted{1}; predicted{2}];
limits = [min(allValues), max(allValues)];
plot(limits, limits, "k--");
axis([limits, limits]);
xlabel("Observed per-capita growth (h^{-1})");
ylabel("Predicted");
title("Level 2: growth-law fit");
legend(scatterHandles, legendText, "Location", "southeast");
grid on;
hold off;

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
% Color encodes true vs inferred (blue/orange, matching Levels 1 and 3);
% opacity encodes the player (solid = Player 1, translucent = Player 2).
trueColor = [0 0.4470 0.7410];          % blue   = true
inferredColor = [0.8500 0.3250 0.0980]; % orange = inferred
playerLabels = ["P1 true", "P1 inferred", "P2 true", "P2 inferred"];
level4Weights = [results.level4.trueWeights(:, 1), ...
    results.level4.inferredWeights(:, 1), ...
    results.level4.trueWeights(:, 2), ...
    results.level4.inferredWeights(:, 2)];
barHandles = bar(level4Weights);
faceColors = {trueColor, inferredColor, trueColor, inferredColor};
faceAlphas = [1, 1, 0.4, 0.4];
for seriesIndex = 1:numel(barHandles)
    barHandles(seriesIndex).FaceColor = faceColors{seriesIndex};
    barHandles(seriesIndex).FaceAlpha = faceAlphas(seriesIndex);
    barHandles(seriesIndex).EdgeColor = [0.25 0.25 0.25];
    barHandles(seriesIndex).LineWidth = 0.4;
end
xticks(1:numel(results.level4.featureNames));
xticklabels(results.level4.featureNames);
xtickangle(30);
ylabel("Normalized weight");
title("Level 4: player-specific objectives");
legend(playerLabels, "Location", "best");
grid on;
end
