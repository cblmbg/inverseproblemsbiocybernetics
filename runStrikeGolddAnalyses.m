function runStrikeGolddAnalyses(optionFiles, saveResults)
%RUNSTRIKEGOLDDANALYSES Execute protected STRIKE-GOLDD option files.
%
%   RUNSTRIKEGOLDDANALYSES(OPTIONFILES, SAVERESULTS) runs each named option
%   file from the bundled STRIKE-GOLDD installation while preserving the
%   caller's MATLAB session. SAVERESULTS controls whether generated results
%   are archived or discarded (default true).

arguments
    optionFiles (:,1) string
    saveResults (1,1) logical = true
end

if isempty(optionFiles) || any(strlength(optionFiles) == 0)
    error("InverseLadder:EmptyStrikeOptions", ...
        "At least one nonempty STRIKE-GOLDD option filename is required.");
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
missingOptions = optionFiles(~isfile(fullfile(strikeDirectory, optionFiles)));
if ~isempty(missingOptions)
    error("InverseLadder:MissingStrikeOptions", ...
        "STRIKE-GOLDD option files not found: %s.", join(missingOptions, ", "));
end

% Capture session state and restore it on any exit, including an error inside
% the toolbox.
originalDirectory = pwd;
originalPath = path;
originalWarningState = warning;
globalSnapshot = captureGlobalVariables();
sessionGuard = onCleanup(@() restoreSession(originalDirectory, originalPath, ...
    originalWarningState, globalSnapshot));

% Snapshot the results folder before the run. When not saving, it is restored
% verbatim (existing contents preserved, new files removed). When saving, this
% run's outputs are archived into a per-run timestamped subfolder so same-day
% runs do not overwrite one another, and any pre-existing result file the
% toolbox overwrote is restored from the snapshot. The finalizer runs through
% onCleanup so it also executes if the toolbox errors part-way, and it always
% removes a leftover current_options.m (a transient toolbox artifact).
resultsDirectory = fullfile(strikeDirectory, "results");
optionsFile = fullfile(strikeDirectory, "current_options.m");
resultsBackup = backupResults(resultsDirectory);
if saveResults
    runFolder = fullfile(resultsDirectory, ...
        "run_" + string(datetime("now"), "yyyyMMdd_HHmmss"));
else
    runFolder = "";
end
outputGuard = onCleanup(@() finalizeOutputs(saveResults, resultsDirectory, ...
    resultsBackup, runFolder, optionsFile));

addpath(genpath(strikeRoot));
cd(strikeDirectory);
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

function finalizeOutputs(saveResults, resultsDirectory, resultsBackup, ...
    runFolder, optionsFile)
%FINALIZEOUTPUTS Archive (when saving) or discard (when not) the toolbox
% outputs and remove the transient current_options.m. Safe after a failed run.
if saveResults
    archiveRunResults(resultsDirectory, resultsBackup, runFolder);
else
    restoreResults(resultsDirectory, resultsBackup);
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

function restoreResults(resultsDirectory, resultsBackup)
%RESTORERESULTS Reset the results folder to its pre-run contents.
if isfolder(resultsDirectory)
    rmdir(resultsDirectory, "s");
end
if strlength(resultsBackup) > 0 && isfolder(resultsBackup)
    copyfile(resultsBackup, resultsDirectory);
end
end

function archiveRunResults(resultsDirectory, resultsBackup, runFolder)
%ARCHIVERUNRESULTS Move this run's result files into a per-run subfolder and
% reinstate any pre-existing file that the toolbox overwrote.
hasBackup = strlength(resultsBackup) > 0 && isfolder(resultsBackup);
listing = dir(fullfile(resultsDirectory, "*.mat"));
for index = 1:numel(listing)
    name = listing(index).name;
    source = fullfile(resultsDirectory, name);
    backupFile = fullfile(resultsBackup, name);
    isNew = ~hasBackup || ~isfile(backupFile);
    if isNew || ~filesAreEqual(source, backupFile)
        if ~isfolder(runFolder)
            mkdir(runFolder);
        end
        movefile(source, fullfile(runFolder, name));
    end
end
if hasBackup
    backupListing = dir(fullfile(resultsBackup, "*.mat"));
    for index = 1:numel(backupListing)
        name = backupListing(index).name;
        destination = fullfile(resultsDirectory, name);
        if ~isfile(destination)
            copyfile(fullfile(resultsBackup, name), destination);
        end
    end
end
end

function tf = filesAreEqual(fileA, fileB)
%FILESAREEQUAL True if two files exist with identical byte contents.
infoA = dir(fileA);
infoB = dir(fileB);
if isempty(infoA) || isempty(infoB) || infoA.bytes ~= infoB.bytes
    tf = false;
    return
end
idA = fopen(fileA, "r");
bytesA = fread(idA);
fclose(idA);
idB = fopen(fileB, "r");
bytesB = fread(idB);
fclose(idB);
tf = isequal(bytesA, bytesB);
end
