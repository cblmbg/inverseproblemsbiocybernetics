%% "example3_1".m
% PDE Model definition
clc; clear;
% Parameters and States(in terms of independent variables)
syms s(t,x) yE(t,x) yI(t,x) %states
syms beta kI muS epsilon kE delta muE muI %parameters

% States and Observes states
states = {s yE yI};
observed_vars = {yE yI};
observation_eq = {};
% Parameters
params = {beta kI muS epsilon kE delta muE muI};

% PDE equations
s_t = diff(s,t);
s_x = diff(s,x);
yE_t = diff(yE,t);
yE_x = diff(yE,x);
yI_t = diff(yI,t);
yI_x = diff(yI,x);

s_t = -s_x -beta*s*yI/kI - muS*s;
yE_t = -yE_x + (1-epsilon)*beta*s*yI*kE/kI - (delta+muE)* yE;
yI_t = -yI_x + epsilon*beta*s*yI + delta*yE*kI/kE - muI*yI ;

eq = {s_t; yE_t; yI_t};

%optional equations
syms u_muS u_muE
opt_eq = {u_muS - u_muE ==0};

% save (Modelname.mat)
save('example3_1.mat', 'states', 'observed_vars', 'params', 'eq','observation_eq','opt_eq');
