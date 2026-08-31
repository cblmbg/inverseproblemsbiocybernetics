%% "example3_3".m
% PDE Model definition
clc; clear;

% Parameters and States(in terms of independent variables)
syms q(t,x) v(t,x) %states
syms d1 d2 a1 a2 b1 b2 c1 c2 %parameters

% States and Observes states
states = {q v};
observed_vars = {q v};
observation_eq = {};
% Parameters
params = {d1 d2 a1 a2 b1 b2 c1 c2};

% PDE equations
q_t = diff(q,t);
v_t = diff(v,t);
q_xx = diff(q,x,2);
v_xx = diff(v,x,2);
q_t = d1*q_xx + q*(a1 - b1*q - c1*v);
v_t = d2*v_xx + v*(a2 - b2*q - c2*v);

eq = {q_t;v_t};

%optional equations
opt_eq = {};

% save (Modelname.mat)
save('example3_3.mat', 'states', 'observed_vars', 'params', 'eq','observation_eq','opt_eq');
