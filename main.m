clear;clc;
[Nxy, Enod, EP, cons] = read_inp('Job-1.inp');
E = 70e3;   % 单位MPa
mu = 0.3; 
tol = 1e-6;      % 收敛容差
maxIter = 5000;  % 最大迭代步数
n = size(Enod,1);
for i = 1:n
    Emat(i,1:3) = [i, E, mu];
end
GK = gstiffm_3d8n(Nxy, Enod, Emat);
N = size(Nxy,1);
SP = SloadA3d8n(EP,N);
[Ndsp, Rfoc] = SolveS3d8n(GK, SP, cons,tol,maxIter);
[Neps,Nstrs] = NstssM3d8n(Nxy,Enod,Emat, Ndsp);
write_vtk('result.vtk', Nxy, Enod, Ndsp, Nstrs, Neps);