%--------------------------------------------------------------------------
% 
%--------------------------------------------------------------------------
clear all;

% 4 states:
syms x1 x2 x3 x4
x = [x1 x2 x3 x4].';

% 5 parameters:
syms k12 k13 k32 k24 k42 
p = [k12 k13 k32 k24 k42].';

% 1 outputs:
h = [x4].';

% input 
u = [];
w = [];

% dynamic equations:
f = [-(k12+k13)*x1;
    k12*x1+k32*x3+k24*x4-k42*x2;
    k13*x1-k32*x3;
    k42*x2-k24*x4];

% initial conditions:
ics  = [];   

% which initial conditions are known:
known_ics = [0,0,0,0]; 

save('ex4_MSSB2026','x','p','u','w','h','f','ics','known_ics');
h = [x1 x4];
save('ex4_MSSB2026_x1x4','x','p','u','w','h','f','ics','known_ics');
h = [x2 x4];
save('ex4_MSSB2026_x2x4','x','p','u','w','h','f','ics','known_ics');