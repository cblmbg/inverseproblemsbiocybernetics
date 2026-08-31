%--------------------------------------------------------------------------
% File that creates the ladder paper model. 
%--------------------------------------------------------------------------
clear all;

syms X1 X2 S M1 M2 ...
     u1 u2 ...
     mu1max mu2max ks1 ks2 km1 km2 c1 c2 alpha1 alpha2 ys1 ys2 ym1 ym2 D sin
 
% states: 
x    = [X1 X2 S M1 M2].'; 

% outputs:
h    = x;    

% inputs:
u    = [u1 u2];

% parameters:
p    = [mu1max mu2max ks1 ks2 km1 km2 c1 c2 alpha1 alpha2 ys1 ys2 ym1 ym2 D sin].'; 

% aux expressions:
mu1 = mu1max*(S/(ks1+S))*(M2/(km1+M2))*(1-c1*u1);
mu2 = mu2max*(S/(ks2+S))*(M1/(km2+M1))*(1-c2*u2);

% dynamic equations:
f    = [(mu1-D)*X1;
        (mu2-D)*X2;
        D*(sin-S)-mu1*X1/ys1-mu2*X2/ys2;
        alpha1*u1*X1-mu2*X2/ym2-D*M1;
        alpha2*u2*X2-mu1*X1/ym1-D*M2]; 
    
% initial conditions:    
ics  = [];  

% which initial conditions are known:
known_ics = [0,0,0,0,0,0];

save('ladder_hx_pall','x','h','u','p','f','ics','known_ics');

p    = [mu1max mu2max c1 c2 alpha1 alpha2].'; 
save('ladder_hx_p6','x','h','u','p','f','ics','known_ics');

p    = [mu1max mu2max ks1 ks2 km1 km2 c1 c2 alpha1 alpha2 ys1 ys2 ym1 ym2 D sin].'; 
h    = [X1+X2, S, M1, M2].';
save('ladder_hxsumSM_pall','x','h','u','p','f','ics','known_ics');

h    = [X1+X2,S,M1+M2].';
save('ladder_hxsumSMsum_pall','x','h','u','p','f','ics','known_ics');

h    = [X1,S,M1+M2].';
save('ladder_hx1SMsum_pall','x','h','u','p','f','ics','known_ics');