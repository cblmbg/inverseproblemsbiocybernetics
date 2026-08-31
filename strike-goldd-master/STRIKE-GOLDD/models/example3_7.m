%% "example3_7".m
% PDE Model definition
clc; clear;

% Parameters and States(in terms of independent variables)
syms q(t,x) v(t,x) %states
syms D1 D2 alpha1 alpha2 p1 p2 p3 p4 p5 p6 %parameters

% States and Observes states
states = {q v};
observed_vars = {};
observation_eq = {q+v};
% Parameters
params = {D1 D2 alpha1 alpha2 p1 p2 p3 p4 p5 p6};

% PDE equations
q_t = diff(q,t);
q_x = diff(q,x);
v_t = diff(v,t);
v_x = diff(v,x);
q_xx = diff(q,x,2);
v_xx = diff(v,x,2);
q_t = D1 * q_xx + alpha1 * q_x + p1 * q + p2 * v + p3;
v_t = D2 * v_xx + alpha2 * v_x + p4 * q + p5 * v + p6;

eq = {q_t;v_t};

%optional equations
opt_eq = {};

% save (Modelname.mat)
save('example3_7.mat', 'states', 'observed_vars', 'params', 'eq','observation_eq',"opt_eq");
