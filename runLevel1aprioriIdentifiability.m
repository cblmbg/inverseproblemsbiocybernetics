function runLevel1aprioriIdentifiability(saveResults)
%RUNLEVEL1APRIORIIDENTIFIABILITY Structural identifiability and observability.
%
%   RUNLEVEL1APRIORIIDENTIFIABILITY() runs the STRIKE-GOLDD toolbox on three
%   observation configurations of the community model.
%
%   RUNLEVEL1APRIORIIDENTIFIABILITY(SAVERESULTS) makes the run non-mutating
%   when SAVERESULTS is false (default true): the toolbox's results folder is
%   snapshotted beforehand and restored to its exact pre-run contents
%   afterwards, so no new files persist and no existing (for example same-day)
%   result file is left overwritten.
%
%   The caller's session state -- working directory, search path, warning
%   state, and global variables -- and, when not saving, the results folder are
%   restored on any exit, including after an error inside the toolbox. Restore
%   runs through onCleanup because STRIKE-GOLDD changes directory, alters
%   warnings, runs `clearvars -global` (which would otherwise erase the
%   caller's unrelated global variables), and writes result files and
%   `current_options.m` into its own folder.

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

% When not saving, snapshot the results folder so the run leaves it exactly as
% found (existing contents preserved, new files removed). The finalizer runs
% through onCleanup so it also executes if the toolbox errors part-way, and it
% always removes a leftover current_options.m (a transient toolbox artifact).
resultsDirectory = fullfile(strikeDirectory, "results");
optionsFile = fullfile(strikeDirectory, "current_options.m");
if saveResults
    resultsBackup = "";
else
    resultsBackup = backupResults(resultsDirectory);
end
outputGuard = onCleanup(@() finalizeOutputs(saveResults, resultsDirectory, ...
    resultsBackup, optionsFile));

addpath(genpath(strikeRoot));
cd(strikeDirectory);

optionFiles = ["options_SIA1.m"; "options_SIA2.m"; "options_SIA3.m"];
for index = 1:numel(optionFiles)
    STRIKE_GOLDD(optionFiles(index));
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

function backupPath = backupResults(resultsDirectory)
%BACKUPRESULTS Copy the results folder to a temporary location for later
% restoration. Returns "" if the folder does not exist yet.
if isfolder(resultsDirectory)
    backupPath = string(tempname);
    copyfile(resultsDirectory, backupPath);
else
    backupPath = "";
end
end

function finalizeOutputs(saveResults, resultsDirectory, resultsBackup, optionsFile)
%FINALIZEOUTPUTS Restore the results folder (when not saving) and remove the
% transient current_options.m. Safe to call after a partial/failed run.
if ~saveResults
    % Reset the results folder to its pre-run state: remove anything the
    % toolbox wrote, then reinstate any files it overwrote or removed.
    if isfolder(resultsDirectory)
        rmdir(resultsDirectory, "s");
    end
    if strlength(resultsBackup) > 0 && isfolder(resultsBackup)
        copyfile(resultsBackup, resultsDirectory);
    end
end
if strlength(resultsBackup) > 0 && isfolder(resultsBackup)
    rmdir(resultsBackup, "s");
end
% current_options.m is a transient artifact the toolbox removes only on a
% successful run; remove it if it was left behind.
if isfile(optionsFile)
    delete(optionsFile);
end
end
