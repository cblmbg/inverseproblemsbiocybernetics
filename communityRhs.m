function dx = communityRhs(~, x, u, parameters)
%COMMUNITYRHS Right-hand side of the cross-feeding community model.
%
%   DX = COMMUNITYRHS(T, X, U, PARAMETERS) evaluates the five-state model.
%   U contains the metabolic allocation controls of the two strains.

% Clamp genuine out-of-range values without masking non-finite inputs: a NaN
% or Inf is left in place so it propagates and is detected by the caller,
% rather than being silently replaced by a plausible value.
x = x(:);
x(x < 0) = 0;
u = u(:);
u(u < 0) = 0;
u(u > 1) = 1;

biomass = x(1:2);
substrate = x(3);
metabolites = x(4:5);
receivedMetabolite = [metabolites(2); metabolites(1)];

substrateSaturation = substrate ./ ...
    (parameters.substrateHalfSaturation + substrate);
metaboliteSaturation = receivedMetabolite ./ ...
    (parameters.metaboliteHalfSaturation + receivedMetabolite);

unburdenedGrowth = parameters.maximumGrowthRate .* ...
    substrateSaturation .* metaboliteSaturation;
allocationFactor = max(0.05, 1 - parameters.allocationCost .* u);
growthRate = unburdenedGrowth .* allocationFactor;

dx = zeros(5, 1);
dx(1:2) = (growthRate - parameters.dilutionRate) .* biomass;
dx(3) = parameters.dilutionRate * ...
    (parameters.substrateInlet - substrate) - ...
    sum(growthRate .* biomass ./ parameters.substrateYield);

dx(4) = parameters.secretionRate(1) * u(1) * biomass(1) - ...
    growthRate(2) * biomass(2) / parameters.metaboliteYield(2) - ...
    parameters.dilutionRate * metabolites(1);
dx(5) = parameters.secretionRate(2) * u(2) * biomass(2) - ...
    growthRate(1) * biomass(1) / parameters.metaboliteYield(1) - ...
    parameters.dilutionRate * metabolites(2);
end
