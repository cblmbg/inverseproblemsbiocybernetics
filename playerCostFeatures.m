function features = playerCostFeatures(player, timeGrid, states, controls)
%PLAYERCOSTFEATURES Candidate objective kernels for one microbial player.

arguments
    player (1,1) double {mustBeMember(player,[1 2])}
    timeGrid (1,:) double
    states (:,5) double
    controls (:,2) double
end

partner = 3 - player;
producedMetaboliteColumn = 3 + player;
receivedMetaboliteColumn = 3 + partner;
intervalStates = 0.5 * (states(1:end-1, :) + states(2:end, :));
intervalLengths = diff(timeGrid(:));
duration = timeGrid(end) - timeGrid(1);

ownBiomass = intervalStates(:, player);
partnerBiomass = intervalStates(:, partner);
receivedMetabolite = intervalStates(:, receivedMetaboliteColumn);
producedMetabolite = intervalStates(:, producedMetaboliteColumn);

biomassScale = 2.0;
receivedTarget = 0.35;
producedMetaboliteRegularization = 1e-5;
features = zeros(4, 1);
features(1) = -sum(intervalLengths .* ownBiomass) / duration / biomassScale;
features(2) = sum(intervalLengths .* controls(:, player).^2) / duration;
features(3) = sum(intervalLengths .* ...
    (receivedTarget ./ (receivedTarget + receivedMetabolite))) / duration;
features(4) = -sum(intervalLengths .* partnerBiomass) / duration / biomassScale;

% A tiny smooth term removes flat directions when produced metabolite is
% very high. It is part of the regularized allocation-effort kernel.
features(2) = features(2) + producedMetaboliteRegularization * ...
    sum(intervalLengths .* producedMetabolite.^2) / duration;
end
