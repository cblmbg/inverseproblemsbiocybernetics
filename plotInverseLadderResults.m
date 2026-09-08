function figureHandle = plotInverseLadderResults(results)
%PLOTINVERSELADDERRESULTS Plot a compact four-level diagnostic summary.

figureHandle = figure("Color", "w", "Name", "Inverse Ladder Case Study");
layout = tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");
title(layout, "Four-level inverse ladder for a microbial consortium");

nexttile(layout, 1);
bar([results.level1.trueVector, results.level1.estimatedVector]);
xticks(1:numel(results.level1.parameterNames));
xticklabels(results.level1.parameterNames);
xtickangle(35);
ylabel("Parameter value");
title("Level 1: parameter estimation");
legend("True", "Estimated", "Location", "best");
grid on;

% ---- Level 2: discovered growth-law coefficients versus ground truth --------
% The generating law mu_i = mu_max,i * q_i * (1 - c_i u_i), minus the dilution D
% in the per-capita growth response, implies true coefficients mu_max,i on q_i,
% -mu_max,i*c_i on q_i*u_i, -D on the intercept, and zero elsewhere. Only the
% terms active in the true or discovered model are shown. Color encodes true
% versus discovered (blue/orange, as in the other panels); opacity encodes the
% strain (solid: strain 1; translucent: strain 2). The dominant Monod term is
% drawn on its own scale (left) so the much smaller intercept, interaction, and
% allocation coefficients remain legible on an expanded scale (right). Strain 2
% illustrates the structural indistinguishability discussed in the text: the
% true q_2*u_2 term is dropped and a spurious u_2 term is selected instead.
libraryNames = results.level2.libraryNames;
qIndex = find(libraryNames == "Monod cross-feeding", 1);
quIndex = find(libraryNames == "Monod x allocation", 1);
uIndex = find(libraryNames == "Allocation", 1);
mu = results.configuration.trueParameters.maximumGrowthRate(:)';
allocationCost = results.configuration.trueParameters.allocationCost(:)';
dilution = results.configuration.trueParameters.dilutionRate;
% Rows, in plotting order: Monod q_i, intercept, interaction q_i*u_i,
% direct allocation u_i. Monod is first so it can be isolated on the left axis.
trueCoefficients = [ mu(1), mu(2); ...
    -dilution, -dilution; ...
    -mu(1)*allocationCost(1), -mu(2)*allocationCost(2); ...
    0, 0 ];
discoveredCoefficients = [ ...
    results.level2.coefficients(qIndex, 1), results.level2.coefficients(qIndex, 2); ...
    results.level2.intercepts(1), results.level2.intercepts(2); ...
    results.level2.coefficients(quIndex, 1), results.level2.coefficients(quIndex, 2); ...
    results.level2.coefficients(uIndex, 1), results.level2.coefficients(uIndex, 2) ];
level2Weights = [trueCoefficients(:, 1), discoveredCoefficients(:, 1), ...
    trueCoefficients(:, 2), discoveredCoefficients(:, 2)];
termLabels = ["Monod q_i", "Intercept", "Interaction q_iu_i", "Allocation u_i"];

% Nested split axis inside tile 2 of the outer layout.
level2Layout = tiledlayout(layout, 1, 3, "TileSpacing", "compact", ...
    "Padding", "none");
level2Layout.Layout.Tile = 2;
level2Layout.Layout.TileSpan = [1 1];
title(level2Layout, "Level 2: growth-law coefficients");

axMonod = nexttile(level2Layout, 1);
drawLevel2Bars(axMonod, level2Weights);
xlim(axMonod, [0.5 1.5]);
ylim(axMonod, [0 0.6]);
xticks(axMonod, 1);
xticklabels(axMonod, termLabels(1));
ylabel(axMonod, "Coefficient");
grid(axMonod, "on");

axSmall = nexttile(level2Layout, 2, [1 2]);
barHandles = drawLevel2Bars(axSmall, level2Weights);
xlim(axSmall, [1.5 4.5]);
ylim(axSmall, [-0.22 0.06]);
xticks(axSmall, 2:4);
xticklabels(axSmall, termLabels(2:4));
xtickangle(axSmall, 15);
yline(axSmall, 0, "Color", [0.5 0.5 0.5], "LineWidth", 0.4);
grid(axSmall, "on");
legend(axSmall, barHandles, ["S1 true", "S1 discovered", ...
    "S2 true", "S2 discovered"], "Location", "southeast");

nexttile(layout, 3);
bar([results.level3.trueWeights, results.level3.inferredWeights]);
xticks(1:numel(results.level3.featureNames));
xticklabels(results.level3.featureNames);
xtickangle(30);
ylabel("Normalized weight");
title("Level 3: centralized objective");
legend("True", "Inferred", "Location", "best");
grid on;

nexttile(layout, 4);
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

function barHandles = drawLevel2Bars(ax, level2Weights)
%DRAWLEVEL2BARS Draw the true/discovered growth-law coefficient bars.
%   Color encodes true (blue) versus discovered (orange); opacity encodes the
%   strain (solid strain 1, translucent strain 2). The same bars are drawn on
%   the two split axes; each axis then crops to its own term range and scale.
trueColor = [0 0.4470 0.7410];
discoveredColor = [0.8500 0.3250 0.0980];
barHandles = bar(ax, level2Weights);
faceColors = {trueColor, discoveredColor, trueColor, discoveredColor};
faceAlphas = [1, 1, 0.4, 0.4];
for seriesIndex = 1:numel(barHandles)
    barHandles(seriesIndex).FaceColor = faceColors{seriesIndex};
    barHandles(seriesIndex).FaceAlpha = faceAlphas(seriesIndex);
    barHandles(seriesIndex).EdgeColor = [0.25 0.25 0.25];
    barHandles(seriesIndex).LineWidth = 0.4;
end
% Mark exact zeros with a small baseline glyph so every series occupies its
% slot: a coefficient that is zero (a term absent from the model) then reads as
% a deliberate value rather than a missing bar. This makes the dropped true
% term and the correctly excluded terms explicit alongside the nonzero bars.
hold(ax, "on");
[numberOfTerms, numberOfSeries] = size(level2Weights);
for seriesIndex = 1:numberOfSeries
    xPositions = barHandles(seriesIndex).XEndPoints;
    for termIndex = 1:numberOfTerms
        if abs(level2Weights(termIndex, seriesIndex)) < 1e-9
            plot(ax, xPositions(termIndex), 0, "o", "MarkerSize", 3.5, ...
                "MarkerEdgeColor", [0.45 0.45 0.45], "MarkerFaceColor", "w", ...
                "LineWidth", 0.5, "HandleVisibility", "off");
        end
    end
end
hold(ax, "off");
end
