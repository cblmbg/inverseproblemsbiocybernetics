function features = communityCostFeatures(timeGrid, states, controls, parameters)
%COMMUNITYCOSTFEATURES Candidate objectives for the centralized community.

intervalStates = 0.5 * (states(1:end-1, :) + states(2:end, :));
intervalLengths = diff(timeGrid(:));
totalBiomass = intervalStates(:, 1) + intervalStates(:, 2);
imbalance = intervalStates(:, 1) - intervalStates(:, 2);

biomassScale = 3.0;
features = zeros(4, 1);
features(1) = -sum(intervalLengths .* totalBiomass) / ...
    (timeGrid(end) - timeGrid(1)) / biomassScale;
features(2) = sum(intervalLengths .* sum(controls.^2, 2)) / ...
    (timeGrid(end) - timeGrid(1)) / 2;
features(3) = sum(intervalLengths .* intervalStates(:, 3)) / ...
    (timeGrid(end) - timeGrid(1)) / parameters.substrateInlet;
features(4) = sum(intervalLengths .* imbalance.^2) / ...
    (timeGrid(end) - timeGrid(1));
end
