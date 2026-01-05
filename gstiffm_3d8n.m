function GK = gstiffm_3d8n(NXYZ, ELEM, EMAT)
% GSTIFFM_3D8N 组装三维8节点六面体单元的全局刚度矩阵
% 本函数基于输入网格信息，采用选择性减缩积分(SRI)方案计算各单元刚度，
% 并通过稀疏矩阵三元组方式高效组装全局刚度矩阵。
%
% 输入参数:
%   NXYZ : 节点坐标矩阵 [NodeID, x, y, z]
%   ELEM : 单元连接矩阵 [ElemID, Node1, ..., Node8]
%   EMAT : 材料属性矩阵 [ElemID, E, v]
% 输出参数:
%   GK   : 全局刚度矩阵 (稀疏矩阵格式)

    % ==========================================
    % 1. 初始化与内存预分配
    % ==========================================
    n_nodes = size(NXYZ, 1);
    n_elem  = size(ELEM, 1);
    total_dof = n_nodes * 3;
    
    % 每个 C3D8 单元刚度矩阵包含 24x24 = 576 个元素
    nz_per_elem = 24 * 24; 
    total_nz = n_elem * nz_per_elem; 
    
    % 预分配稀疏矩阵三元组内存 (坐标格式)
    I_idx = zeros(total_nz, 1); % 行索引
    J_idx = zeros(total_nz, 1); % 列索引
    V_val = zeros(total_nz, 1); % 数值
    
    current_ptr = 1; % 数据填充指针
    
    % ==========================================
    % 2. 循环计算单元刚度并构建索引
    % ==========================================
    for i = 1:n_elem
        % --- A. 准备材料参数 ---
        E = EMAT(i, 2); 
        v = EMAT(i, 3);
        
        % 构建各向同性线弹性本构矩阵 D
        factor = E / ((1+v) * (1-2*v));
        c1 = 1 - v;
        c2 = v;
        c3 = (1 - 2*v) / 2;
        
        D = factor * [c1, c2, c2, 0,  0,  0;
                      c2, c1, c2, 0,  0,  0;
                      c2, c2, c1, 0,  0,  0;
                      0,  0,  0,  c3, 0,  0;
                      0,  0,  0,  0,  c3, 0;
                      0,  0,  0,  0,  0,  c3];
        
        % --- B. 提取单元几何信息 ---
        % 获取单元节点编号
        node_indices = ELEM(i, 2:9);      
        % 获取节点坐标 (假设行号对应 NodeID)
        ENC = NXYZ(node_indices, 2:4);    
        
        % --- C. 计算单元刚度 ---
        % 调用单元刚度函数，使用 'SRI' (选择性减缩积分) 模式
        EK = 0.005*estiffm_3d8n(ENC, D, 'Full')+estiffm_3d8n(ENC, D, 'Reduced'); 
        
        % --- D. 构建稀疏索引 (三元组) ---
        % 计算该单元 8 个节点对应的 24 个全局自由度索引
        elem_dofs = zeros(1, 24);
        for k = 1:8
            nid = node_indices(k); 
            % 自由度映射: [u, v, w] -> [3*nid-2, 3*nid-1, 3*nid]
            start_idx = (nid - 1) * 3 + 1;
            elem_dofs(3*k-2 : 3*k) = start_idx : start_idx+2;
        end
        
        % 生成局部刚度矩阵对应的全局行列索引网格
        [cols, rows] = meshgrid(elem_dofs, elem_dofs);
        
        % 将数据填充至三元组大数组
        end_ptr = current_ptr + nz_per_elem - 1;
        
        I_idx(current_ptr : end_ptr) = rows(:); 
        J_idx(current_ptr : end_ptr) = cols(:); 
        V_val(current_ptr : end_ptr) = EK(:);   
        
        current_ptr = end_ptr + 1;
    end
    
    % ==========================================
    % 3. 组装全局稀疏矩阵
    % ==========================================
    % 利用 sparse 函数自动累加重复坐标处的刚度值
    GK = sparse(I_idx, J_idx, V_val, total_dof, total_dof);
    
end