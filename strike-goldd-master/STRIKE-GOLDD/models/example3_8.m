%% "example3_8".m
% PDE Model definition
clc; clear;

% Parameters and States(in terms of independent variables)
syms z(t,x) c(t,x) %states
syms D B1 B2 %parameters

% States and Observes states
states = {z c};
observed_vars = {z};
observation_eq = {};
% Parameters
params = {D B1 B2};

% PDE equations
z_t = diff(z,t);
c_t = diff(c,t);
c_xx = diff(c,x,2);
z_xx = diff(z,x,2);
z_t = D * z_xx - D * c_xx;
c_t = B2 * z - (B1+B2)* c;

eq = {z_t;c_t};

%optional equations
opt_eq = {};

% save (Modelname.mat)
save('example3_8.mat', 'states', 'observed_vars', 'params', 'eq','observation_eq',"opt_eq");
