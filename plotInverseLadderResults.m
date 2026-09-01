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
% Show recovery accuracy for the terms in the generating growth law, whose
% analytic library coefficients are mu_max (Monod cross-feeding) and
% -mu_max .* allocation cost (Monod-by-allocation); all other candidates are
% zero, so a relative error is only defined for these two terms. A missed term
% (strain 2 does not recover the interaction) therefore appears as -100%.
trueParameters = results.configuration.trueParameters;
libraryNames = results.level2.libraryNames;
trueCoefficients = zeros(size(results.level2.coefficients));
trueCoefficients(libraryNames == "Monod cross-feeding", :) = ...
    trueParameters.maximumGrowthRate';
trueCoefficients(libraryNames == "Monod x allocation", :) = ...
    (-trueParameters.maximumGrowthRate .* trueParameters.allocationCost)';
trueTerm = any(trueCoefficients ~= 0, 2);
relativeError = 100 * (results.level2.coefficients(trueTerm, :) - ...
    trueCoefficients(trueTerm, :)) ./ trueCoefficients(trueTerm, :);
bar(relativeError);
xticks(1:nnz(trueTerm));
xticklabels(libraryNames(trueTerm));
xtickangle(10);
ylabel("Relative error (%)");
title("Level 2: growth-law coefficient recovery");
legend("Strain 1", "Strain 2", "Location", "best");
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
