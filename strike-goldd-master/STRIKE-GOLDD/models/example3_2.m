%% "example3_2".m
% PDE Model definition
clc; clear;

% Parameters and States(in terms of independent variables)
syms q(t,x) v(t,x) %states
syms a b c %parameters

% States and Observes states
states = {q v};
observed_vars = {v};
observation_eq = {};
% Parameters
params = {a b c};

% PDE equations
q_t = diff(q,t);
q_x = diff(q,x);
v_t = diff(v,t);
q_xx = diff(q,x,2);
q_t = a * q_x + c * v^2;
v_t = b * q_xx;

eq = {q_t;v_t};

%optional equations
opt_eq = {}; 

% save (Modelname.mat)
save('example3_2.mat', 'states', 'observed_vars', 'params', 'eq','observation_eq',"opt_eq");
