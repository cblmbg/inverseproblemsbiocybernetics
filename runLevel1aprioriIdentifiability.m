function runLevel1aprioriIdentifiability(saveResults)
%RUNLEVEL1APRIORIIDENTIFIABILITY Structural identifiability and observability.
%
%   RUNLEVEL1APRIORIIDENTIFIABILITY() runs the STRIKE-GOLDD toolbox on three
%   observation configurations of the community model.
%
%   RUNLEVEL1APRIORIIDENTIFIABILITY(SAVERESULTS) additionally removes the
%   result files written by the toolbox when SAVERESULTS is false (default
%   true).
%
%   The caller's session state -- working directory, search path, warning
%   state, and global variables -- is restored on return, including after an
%   error inside the toolbox. This is necessary because STRIKE-GOLDD changes
%   directory, alters warnings, and runs `clearvars -global`, which would
%   otherwise erase the caller's unrelated global variables.

arguments
    saveResults (1,1) logical = true
end

% Resolve the toolbox relative to this file, not the caller's current folder,
% so the analysis works from any working directory.
thisDirectory = fileparts(mfilename("fullpath"));
strikeRoot = fullfile(thisDirectory, "strike-goldd-master");
strikeDirectory = fullfile(strikeRoot, "STRIKE-GOLDD");
if ~isfolder(strikeDirectory)
    error("InverseLadder:MissingStrikeGoldd", ...
        "STRIKE-GOLDD toolbox not found at %s.", strikeDirectory);
end

% Capture session state and restore it on any exit, including an error inside
% the toolbox.
originalDirectory = pwd;
originalPath = path;
originalWarningState = warning;
globalSnapshot = captureGlobalVariables();
sessionGuard = onCleanup(@() restoreSession(originalDirectory, originalPath, ...
    originalWarningState, globalSnapshot));

addpath(genpath(strikeRoot));
cd(strikeDirectory);

resultsDirectory = fullfile(strikeDirectory, "results");
existingResultFiles = resultFileSet(resultsDirectory);

optionFiles = ["options_SIA1.m"; "options_SIA2.m"; "options_SIA3.m"];
for index = 1:numel(optionFiles)
    STRIKE_GOLDD(optionFiles(index));
end

if ~saveResults
    removeNewResultFiles(resultsDirectory, existingResultFiles);
    leftoverOptions = fullfile(strikeDirectory, "current_options.m");
    if isfile(leftoverOptions)
        delete(leftoverOptions);
    end
end
end

function snapshot = captureGlobalVariables()
%CAPTUREGLOBALVARIABLES Record current global variable names and values.
names = who("global");
values = cell(size(names));
for index = 1:numel(names)
    values{index} = getGlobalValue(names{index});
end
snapshot = struct("names", {names}, "values", {values});
end

function value = getGlobalValue(name)
eval("global " + string(name) + ";");
value = eval(string(name));
end

function restoreSession(originalDirectory, originalPath, originalWarningState, ...
    globalSnapshot)
%RESTORESESSION Restore working directory, path, warnings, and globals.
if isfolder(originalDirectory)
    cd(originalDirectory);
end
path(originalPath);
warning(originalWarningState);
% Clear whatever globals the toolbox left behind, then reinstate the caller's.
clearvars -global
for index = 1:numel(globalSnapshot.names)
    setGlobalValue(globalSnapshot.names{index}, globalSnapshot.values{index});
end
end

function setGlobalValue(name, value) %#ok<INUSD>
eval("global " + string(name) + ";");
eval(string(name) + " = value;");
end

function files = resultFileSet(resultsDirectory)
%RESULTFILESET Names of the .mat result files currently in the results folder.
if isfolder(resultsDirectory)
    listing = dir(fullfile(resultsDirectory, "*.mat"));
    files = string({listing.name});
else
    files = strings(1, 0);
end
end

function removeNewResultFiles(resultsDirectory, existingResultFiles)
%REMOVENEWRESULTFILES Delete result files created during this run.
if ~isfolder(resultsDirectory)
    return
end
listing = dir(fullfile(resultsDirectory, "*.mat"));
for index = 1:numel(listing)
    name = string(listing(index).name);
    if ~ismember(name, existingResultFiles)
        delete(fullfile(resultsDirectory, listing(index).name));
    end
end
end
