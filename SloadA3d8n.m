function SP = SloadA3d8n(EP, N)
% 计算C3D8单元的结构节点载荷向量
% 输入:
%   EP - 节点载荷矩阵 [单元ID, 节点ID, 方向, 数值]
%        方向说明: 1=x方向, 2=y方向, 3=z方向
%   N  - 结构的总节点数
% 输出:
%   SP - 结构全局载荷向量 (大小为 3*N x 1)

[n, ~] = size(EP);

% 初始化全局载荷向量
% 每个节点包含3个自由度 (x, y, z)
SP = zeros(3*N, 1);

for i = 1:n
    % 提取当前载荷项的信息
    nodeID = EP(i, 2);      % 节点编号
    direction = EP(i, 3);   % 载荷方向 (1, 2, 3)
    forceValue = EP(i, 4);  % 载荷大小
    
    % 计算全局自由度索引 (Global DOF Index)
    % 对应公式: 3 * (NodeID - 1) + Direction
    sn = 3 * nodeID + direction - 3;
    
    % 将载荷值累加到全局向量中
    SP(sn) = SP(sn) + forceValue;
end
end