function EK = estiffm_3d8n(ENC, D, int_type)
% ESTIFFM_3D8N 计算三维8节点六面体单元(C3D8)的单元刚度矩阵
% 该函数根据输入的节点坐标、本构矩阵及指定的积分方案计算单元刚度矩阵。
% 核心算法支持选择性减缩积分(SRI)以缓解剪切自锁现象。
%
% 输入参数:
%   ENC      : 8x3 矩阵，单元节点坐标 [x, y, z]
%   D        : 6x6 本构矩阵 (应力-应变关系矩阵)
%   int_type : 字符串，指定数值积分方案
%              'Full'    - 完全积分 (正应变与剪切项均为 2x2x2)
%              'Reduced' - 减缩积分 (正应变与剪切项均为 1x1x1)
%              'SRI'     - 选择性减缩积分 (正应变 2x2x2, 剪切项 1x1x1)
%
% 输出参数:
%   EK       : 24x24 单元刚度矩阵
    % 初始化刚度矩阵
    EK = zeros(24, 24);

    % ==========================================
    % 1. 本构矩阵分离
    % 将本构矩阵 D 拆分为正应变部分 (Dn) 和剪切部分 (Ds)
    % 以便在 SRI 模式下对不同部分采用不同的积分阶次
    % ==========================================
    
    % D_norm: 提取正应力-正应变关系 (通常为左上 3x3)
    D_norm = zeros(6,6);
    D_norm(1:3, 1:3) = D(1:3, 1:3);
    % 保留正应力与剪应变之间的耦合项 (针对各向异性材料的通用性处理)
    D_norm(1:3, 4:6) = D(1:3, 4:6); 
    D_norm(4:6, 1:3) = D(4:6, 1:3);

    % D_shear: 提取剪应力-剪应变关系 (通常为右下 3x3)
    D_shear = zeros(6,6);
    D_shear(4:6, 4:6) = D(4:6, 4:6);
    
    % ==========================================
    % 2. 确定积分阶次
    % 根据输入的 int_type 设定正应变项和剪切项的高斯积分点数量
    % ==========================================
    switch int_type
        case 'SRI'
            % 选择性减缩积分：正应变项全积分，剪切项减缩积分
            order_norm = 2;
            order_shear = 1;
            
        case 'Full'
            % 完全积分：全部使用 2x2x2
            order_norm = 2;
            order_shear = 2;
            
        case 'Reduced'
            % 减缩积分：全部使用 1x1x1
            order_norm = 1;
            order_shear = 1;
            
        otherwise
            error('Unknown integration type. Use SRI, Full, or Reduced.');
    end
    
    % ==========================================
    % 3. 刚度矩阵计算与组装
    % 分别计算两部分的刚度贡献并叠加
    % ==========================================
    
    % 计算正应变部分的刚度贡献 (K_norm)
    K_norm = integrate_part(ENC, D_norm, order_norm);
    
    % 计算剪切应变部分的刚度贡献 (K_shear)
    K_shear = integrate_part(ENC, D_shear, order_shear);
    
    % 叠加得到最终单元刚度矩阵
    EK = K_norm + K_shear;
end

% ==========================================
% 内部辅助函数：指定阶次的刚度积分计算
% ==========================================
function K_part = integrate_part(ENC, D_part, order)
    K_part = zeros(24, 24);
    
    % 获取高斯点坐标和权重
    [g_points, weights] = gauspw(order); 
    n_pt = length(g_points);
    
    % 高斯积分循环 (x, y, z 方向)
    for i = 1:n_pt
        for j = 1:n_pt
            for k = 1:n_pt
                xi   = g_points(i);
                eta  = g_points(j);
                zeta = g_points(k);
                
                % 计算组合权重 W = wi * wj * wk
                W = weights(i) * weights(j) * weights(k);
                
                % 调用几何函数计算应变-位移矩阵 B 和雅可比矩阵 JCB
                % 依赖外部函数: geom_3d8n
                [B, JCB] = geom_3d8n(ENC, xi, eta, zeta);
                
                detJ = det(JCB);
                
                if detJ <= 0
                   warning('Negative Jacobian detected inside integration.');
                end
                
                % 累加刚度贡献: K = sum(B' * D * B * detJ * W)
                K_part = K_part + B' * D_part * B * detJ * W;
            end
        end
    end
end