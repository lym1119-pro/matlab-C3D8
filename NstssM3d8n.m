function [Nstrain, Nstress] = NstssM3d8n(Nxyz, Enod, Emat, Ndsp)
% 计算C3D8单元的节点应变和应力（采用节点平均法）
% 输入:
%   Nxyz - 节点坐标 [节点ID, x, y, z]
%   Enod - 单元连接关系 [单元ID, 节点1...节点8]
%   Emat - 材料属性 [单元ID, 弹性模量, 泊松比]
%   Ndsp - 节点位移 [节点ID, u, v, w]
% 输出:
%   Nstrain/Nstress - 结果数组 [节点ID, ex, ey, ez, exy, eyz, ezx]

m = size(Enod, 1);   % 单元数量
n = size(Nxyz, 1);   % 节点数量

% 初始化输出数组
% 格式: [节点ID, 6个分量, 计数器]
% 分量顺序: xx, yy, zz, xy, yz, zx
Nstrain = zeros(n, 8); 
Nstress = zeros(n, 8);
Nstrain(:, 1) = 1:n;
Nstress(:, 1) = 1:n;

% 标准C3D8顺序的8个节点局部坐标
% 1-4: 底面 (-z), 5-8: 顶面 (+z)
node_local_coords = [
    -1, -1, -1;  % 节点 1
     1, -1, -1;  % 节点 2
     1,  1, -1;  % 节点 3
    -1,  1, -1;  % 节点 4
    -1, -1,  1;  % 节点 5
     1, -1,  1;  % 节点 6
     1,  1,  1;  % 节点 7
    -1,  1,  1   % 节点 8
];

for i = 1:m
    % 1. 获取当前单元的材料属性
    E = Emat(i, 2);
    mu = Emat(i, 3);
    
    % 3D弹性矩阵 (各向同性)
    factor = E / ((1 + mu) * (1 - 2 * mu));
    c1 = 1 - mu;
    c2 = mu;
    c3 = (1 - 2 * mu) / 2;
    
    D = factor * [c1, c2, c2, 0,  0,  0;
                  c2, c1, c2, 0,  0,  0;
                  c2, c2, c1, 0,  0,  0;
                  0,  0,  0,  c3, 0,  0;
                  0,  0,  0,  0,  c3, 0;
                  0,  0,  0,  0,  0,  c3];
              
    % 2. 提取单元节点ID和坐标
    node_ids = Enod(i, 2:9); 
    ENC = Nxyz(node_ids, 2:4); 
    
    % 3. 提取单元节点位移
    % 构造位移向量 U (24x1)
    U = zeros(24, 1);
    for k = 1:8
        nid = node_ids(k);
        U(3*k-2) = Ndsp(nid, 2); % u分量
        U(3*k-1) = Ndsp(nid, 3); % v分量
        U(3*k)   = Ndsp(nid, 4); % w分量
    end
    
    % 4. 遍历单元内的每个节点计算应力/应变 (直接节点计算)
    for j = 1:8
        current_node_id = node_ids(j);
        
        % 获取当前节点的局部坐标
        xi   = node_local_coords(j, 1);
        eta  = node_local_coords(j, 2);
        zeta = node_local_coords(j, 3);
        
        % 计算该位置的应变-位移矩阵 B
        % 调用之前定义的 geom_3d8n 函数
        [B, ~] = geom_3d8n(ENC, xi, eta, zeta);
        
        % 计算应变 (6x1) 和 应力 (6x1)
        strain = B * U;
        stress = D * strain;
        
        % 累加结果 (第2-7列存储6个分量)
        Nstrain(current_node_id, 2:7) = Nstrain(current_node_id, 2:7) + strain';
        Nstress(current_node_id, 2:7) = Nstress(current_node_id, 2:7) + stress';
        
        % 计数器加1 (第8列)，记录有多少个单元共享该节点
        Nstrain(current_node_id, 8) = Nstrain(current_node_id, 8) + 1;
        Nstress(current_node_id, 8) = Nstress(current_node_id, 8) + 1;
    end
end

% 5. 结果平均 (节点平均法)
% 将累加值除以共享该节点的单元数量
for k = 2:7
    Nstrain(:, k) = Nstrain(:, k) ./ Nstrain(:, 8);
    Nstress(:, k) = Nstress(:, k) ./ Nstress(:, 8);
end

% 6. 清理: 移除计数器列
Nstrain(:, 8) = [];
Nstress(:, 8) = [];
end