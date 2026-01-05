function [Ndsp, Rfoc] = SolveS3d8n(KS, SP, cons, tol, maxIter)
    % 求解C3D8结构位移（CG算法 + 大数法处理边界）
    % 输入:
    %   KS - 全局刚度矩阵 (稀疏矩阵)
    %   SP - 全局载荷向量
    %   cons - 约束矩阵 [节点号, 方向, 强制位移值]
    %   tol, maxIter - CG算法的收敛容差和最大迭代步数
    % 输出:
    %   Ndsp - 节点位移矩阵 [节点ID, u, v, w]
    %   Rfoc - 支反力矩阵 [节点ID, 方向, 反力值]
    
    % 备份矩阵以保护原始数据
    KS_mod = KS;
    SP_mod = SP;
    
    % --- 1. 引入边界条件 (大数法) ---
    % 计算罚因子：取主对角线最大值的大倍数，保持矩阵正定性
    penalty_factor = 1.0e9 * max(abs(diag(KS))); 
    
    nc = size(cons, 1);
    for i = 1:nc
        node_idx = cons(i, 1); % 节点
        dir = cons(i, 2);      % 方向
        val = cons(i, 3);      % 强制位移值 
        
        % 计算全局自由度索引
        if dir == 1
            dof = 3 * node_idx - 2;
        elseif dir == 2
            dof = 3 * node_idx - 1;
        elseif dir == 3
            dof = 3 * node_idx;
        else
            error('Invalid direction');
        end
        
        % 应用大数法修改刚度矩阵对角线和载荷向量
        KS_mod(dof, dof) = KS_mod(dof, dof) + penalty_factor;
        SP_mod(dof) = SP_mod(dof) + penalty_factor * val;
    end
    
    % --- 2. 调用共轭梯度法 (CG) 求解 ---
    fprintf('启动 CG 求解器 (Tol=%e, MaxIter=%d)...\n', tol, maxIter);
    start_time = tic;
    
    [U_sol, iter_done, res_history] = conjugate_gradient(KS_mod, SP_mod, tol, maxIter);
    
    solve_time = toc(start_time);
    fprintf('CG 求解完成: 耗时 %.4fs, 迭代步数 %d, 最终残差 %e\n', ...
        solve_time, iter_done, res_history(end));

    % --- 3. 结果重组 ---
    % 将一维解向量 U_sol 转换为 [NodeID, u, v, w] 格式
    total_dof = length(U_sol);
    num_nodes = total_dof / 3;
    Ndsp = zeros(num_nodes, 4);
    
    for i = 1:num_nodes
        Ndsp(i, 1) = i;
        Ndsp(i, 2) = U_sol(3*i - 2); % u
        Ndsp(i, 3) = U_sol(3*i - 1); % v
        Ndsp(i, 4) = U_sol(3*i);     % w
    end
    
    % --- 4. 计算支反力 ---
    % 公式: R = K_original * U - F_original
    Rfoc = zeros(nc, 3);
    if nargout > 1
        Full_Reaction = KS * U_sol - SP; % 计算全局不平衡力
        for i = 1:nc
            node_idx = cons(i, 1);
            dir = cons(i, 2);
            
            % 确定DOF
            if dir == 1, dof = 3*node_idx-2;
            elseif dir == 2, dof = 3*node_idx-1;
            else, dof = 3*node_idx; end
            
            Rfoc(i, 1) = node_idx;
            Rfoc(i, 2) = dir;
            Rfoc(i, 3) = Full_Reaction(dof); % 提取受约束处的反力
        end
    end
end