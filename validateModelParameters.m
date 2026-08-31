function validateModelParameters(parameters)
%VALIDATEMODELPARAMETERS Ensure the required kinetic parameter fields are finite.
%
%   Rejecting a non-finite parameter avoids silently changing the model: for
%   example a NaN allocation cost would otherwise be masked by the allocation
%   factor floor and produce a plausible-looking but meaningless trajectory.

requiredFields = ["dilutionRate", "substrateInlet", "maximumGrowthRate", ...
    "substrateHalfSaturation", "metaboliteHalfSaturation", "allocationCost", ...
    "secretionRate", "substrateYield", "metaboliteYield"];

for index = 1:numel(requiredFields)
    field = requiredFields(index);
    if ~isfield(parameters, field)
        error("InverseLadder:MissingParameter", ...
            "Parameter field '%s' is required.", field);
    end
    value = parameters.(field);
    if ~isnumeric(value) || ~all(isfinite(value(:)))
        error("InverseLadder:NonFiniteParameter", ...
            "Parameter field '%s' must be finite.", field);
    end
end
end
