%% "example3_5".m
% PDE Model definition
clc; clear;

% Parameters and States(in terms of independent variables)
syms q(t,x)  %states
syms delta  %parameters

% States and Observes states
states = {q };
observed_vars = {q};
observation_eq = {};
% Parameters
params = {delta};

% PDE equations
q_tt = diff(q,t,2);
q_xx = diff(q,x,2);
q_tt = delta^2 * q_xx;

eq = {q_tt};

%optional equations
opt_eq = {};

% save (Modelname.mat)
save('example3_5.mat', 'states', 'observed_vars', 'params', 'eq','observation_eq',"opt_eq");
