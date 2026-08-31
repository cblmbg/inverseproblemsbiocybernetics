%% "example3_6".m
% PDE Model definition
clc; clear;

% Parameters and States(in terms of independent variables)
syms r(t,x) g(t,x)
syms D1 D2 k1 k2

% States and Observes states
states = {r g};
observed_vars = {};
observation_eq = {r+g};
% Parameters
params = {D1 D2 k1 k2};

% PDE equations
g_xx = diff(g,x,2);
r_xx = diff(r,x,2);

r_t = D1 * r_xx - k1*r + 2*k2*g;
g_t = D2 * g_xx + k1*r - k2*g;

eq = {r_t; g_t};

%optional equations
opt_eq = {};

% save (Modelname.mat)
save('example3_6.mat', 'states', 'observed_vars', 'params', 'eq','observation_eq',"opt_eq");
