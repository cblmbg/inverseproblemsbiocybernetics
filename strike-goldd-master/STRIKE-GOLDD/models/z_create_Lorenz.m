%--------------------------------------------------------------------------
% Lorenz model
%--------------------------------------------------------------------------
clear all;

% 3 states:
syms x1 x2 x3
x = [x1 x2 x3].';

% 3 parameters:
syms x4 x5 x6 
p = [x4 x5 x6].';

% 1 outputs:
h = [x1].';

% input 
u = [];
w = [];

% dynamic equations:
f = [x4*(x2-x1);
    x1*(x5-x3)-x2;
    x1*x2-x6*x3];

% initial conditions:
ics  = [];   

% which initial conditions are known:
known_ics = [0,0,0]; 

save('Lorenz','x','p','u','w','h','f','ics','known_ics');
h = x2;
save('Lorenz_x2','x','p','u','w','h','f','ics','known_ics');
h = x3;
save('Lorenz_x3','x','p','u','w','h','f','ics','known_ics');