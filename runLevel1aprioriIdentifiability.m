function runLevel1aprioriIdentifiability()
%RUNLEVEL1APRIORIIDENTIFIABILITY Analyse the structural identifiability and
% observability of the system for several configurations.

% add the identifiability analysis toolbox (STRIKE-GOLDD) to the path:
addpath(genpath('strike-goldd-master'))

% Move to the STRIKE-GOLDD directory:
mainpath = pwd;
strikepath = strcat(mainpath,filesep,'strike-goldd-master',filesep,'STRIKE-GOLDD');
cd(strikepath)

% First analysis: all states measured (y=[X1, X2, S, M1, M2]), all parameters unknown
STRIKE_GOLDD("options_SIA1.m")

% Second analysis: y = [X1+X2, S, M1+M2], all parameters unknown
STRIKE_GOLDD("options_SIA2.m")

% Third analysis: y = [X1, S, M1+M2], all parameters unknown
STRIKE_GOLDD("options_SIA3.m")

% Go back to the initial folder:
cd(mainpath)

end