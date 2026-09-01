function runLevel1aprioriIdentifiability(saveResults)
%RUNLEVEL1APRIORIIDENTIFIABILITY Full-state structural identifiability check.
%
%   RUNLEVEL1APRIORIIDENTIFIABILITY() runs the STRIKE-GOLDD configuration
%   with all five community states observed. This is the observation setting
%   used by the subsequent parameter-estimation stage.
%
%   RUNLEVEL1APRIORIIDENTIFIABILITY(SAVERESULTS) controls whether the
%   generated STRIKE-GOLDD result is archived (default true) or discarded.
%   Caller session state and pre-existing results are preserved in both cases.
%
%   See also RUNSTRUCTURALIDENTIFIABILITYCOMPARISON, which runs all three
%   observation scenarios discussed in the manuscript.

arguments
    saveResults (1,1) logical = true
end

runStrikeGolddAnalyses("options_SIA1.m", saveResults);
end
