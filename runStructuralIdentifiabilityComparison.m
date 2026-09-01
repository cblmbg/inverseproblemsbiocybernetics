function runStructuralIdentifiabilityComparison(saveResults)
%RUNSTRUCTURALIDENTIFIABILITYCOMPARISON Compare three observation scenarios.
%
%   RUNSTRUCTURALIDENTIFIABILITYCOMPARISON() runs the three STRIKE-GOLDD
%   configurations used to compare full-state observations, aggregated
%   observations, and measurement of a single strain with aggregate
%   metabolite information.
%
%   RUNSTRUCTURALIDENTIFIABILITYCOMPARISON(SAVERESULTS) controls whether the
%   generated STRIKE-GOLDD results are archived (default true) or discarded.
%   Caller session state and pre-existing results are preserved in both cases.

arguments
    saveResults (1,1) logical = true
end

optionFiles = ["options_SIA1.m"; "options_SIA2.m"; "options_SIA3.m"];
runStrikeGolddAnalyses(optionFiles, saveResults);
end
