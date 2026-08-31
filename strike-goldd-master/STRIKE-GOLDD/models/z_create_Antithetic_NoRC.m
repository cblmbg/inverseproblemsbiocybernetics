%--------------------------------------------------------------------------
% 
%--------------------------------------------------------------------------
clear all;

% 6 states:
syms M1 M2 C1 C2 P1 P2
x = [M1 M2 C1 C2 P1 P2].';

% parameters:
syms CNm vm1 vm2 dm ...
     CNc vc1 vc2 dc Kc1 Kc2 Qc1 Qc2 Qbc1 Qbc2...
     n...
     vp1 vp2 Qp1 Qp2 dp
p = [CNm vm1 vm2 dm ...
     CNc vc1 vc2 dc Kc1 Kc2 Qc1 Qc2 Qbc1 Qbc2...
     n...
     vp1 vp2 Qp1 Qp2 dp].';

% outputs:
h = [M1 M2 C1 C2 P1 P2].';

% input 
syms u1 u2
u = [u1 u2];
w = [];

% aux expressions:
Rc1 = P1^n/(P1^n+Kc1);
Rc2 = P2^n/(P2^n+Kc2);

% dynamic equations:
f = [CNm*vm1*u1-dm*M1;
     CNm*vm2*u2-dm*M2;
     CNc*vc1*(Rc1/Qc1+1/Qbc1)-dc*C1;
     CNc*vc2*(Rc2/Qc2+1/Qbc2)-dc*C2;
     vp1*M1/Qp1-dp*P1;
     vp2*M2/Qp2-dp*P2
];

% initial conditions:
ics  = [];   

% which initial conditions are known:
known_ics = [0,0,0,0,0,0]; 

save('Anti_NoRC_hx','x','p','u','w','h','f','ics','known_ics');

u = u1;
save('Anti_NoRC_hx_u1','x','p','u','w','h','f','ics','known_ics');

u = u2;
save('Anti_NoRC_hx_u2','x','p','u','w','h','f','ics','known_ics');

h = [M1 M2 P1 P2].';
save('Anti_NoRC_hMP','x','p','u','w','h','f','ics','known_ics');

h = [M1 M2].';
save('Anti_NoRC_hM','x','p','u','w','h','f','ics','known_ics');

h = [P1 P2].';
save('Anti_NoRC_hP','x','p','u','w','h','f','ics','known_ics');

