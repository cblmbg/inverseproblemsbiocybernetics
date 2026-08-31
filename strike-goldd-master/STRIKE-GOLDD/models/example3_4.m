%% "example3_4".m
% PDE Model definition
clc; clear;

% Parameters and States(in terms of independent variables)
syms q(t,x) v(t,x) w(t,x) %states
syms r1 r2 r3 k1 k2 d1 d2 d3 d4 a12 a21  %parameters

% States and Observes states
states = {q v w};
observed_vars = {q v w};
observation_eq = {};
% Parameters
params = {r1 r2 r3 k1 k2 d1 d2 d3 d4 a12 a21};

% PDE equations
q_t = diff(q,t);
v_t = diff(v,t);
w_t = diff(w,t);
v_x = diff(v,x);

w_xx = diff(w,x,2);

q_t = r1*q*(1- q/k1 -a12*v/k2) -d1*w*q;
v_t = r2*v*(1- v/k2 - a21*q/k1)+ d2*diff(((1-q)*v_x),x);
w_t = d4*w_xx + r3*v - d3*w;
eq = {q_t;v_t;w_t};

%optional equations
opt_eq = {};

% save (Modelname.mat)
save('example3_4.mat', 'states', 'observed_vars', 'params', 'eq','observation_eq','opt_eq');
