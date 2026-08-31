% - Ex4 Linear model with damping
clear;

% 6 states
syms x1 x2 x3 x4 x5 x6
x = [x1; x2; x3; x4; x5; x6];

% 1 output
h = x2;

% 1 input
syms u1;
u = u1;
w = [];

% 9 unknown parameters 
syms th1 th2 th3 th4 th5 th6 th7 th8 th9
p =[th1 th2 th3 th4 th5 th6 th7 th8 th9].';

% dynamic equations
f = [x4;
    x5;
    x6;
    (-th1*x1+th2*(x2-x1)-th4*x4+th5*(x5-x4)+u1)/th7;
    (-th2*(x2-x1)+th3*(x3-x2)-th5*(x5-x4)+th6*(x6-x5))/th8;
    (-th3*(x3-x2)-th6*(x6-x5))/th9];

% initial conditions
ics  = []; 
known_ics = [0,0,0,0,0,0];

save('Ex4_lin_damping','x','p','h','u','w','f','ics','known_ics');
