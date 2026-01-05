function [u,iter,res_norms] = conjugate_gradient(A, F, tol, maxIter)
%% 使用共轭梯度法求解 A * u = F
% A - 系数矩阵
% F - 右端向量
% tol - 收敛容差
% maxIter - 最大迭代次数

% 初始化解向量
u = zeros(size(F));
r = F - A * u;  % 初始残差
p = r;  % 初始方向向量
rsold = r' * r;  % 初始残差范数
    res_norms = zeros(maxIter, 1);
    res_norms(1) = sqrt(rsold);
    
for iter = 1:maxIter
    Ap = A * p;
    alpha = rsold / (p' * Ap);
    u = u + alpha * p;  % 更新解
    r = r - alpha * Ap;  % 更新残差
    rsnew = r' * r;  % 新的残差范数
    res_norms(iter+1) = sqrt(rsnew);
    % 检查收敛性
    if sqrt(rsnew) < tol
        res_norms = res_norms(1:iter+1);
        break;
    end

    p = r + (rsnew / rsold) * p;  % 更新方向向量
    rsold = rsnew;
end