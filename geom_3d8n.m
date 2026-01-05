function [B, JCB] = geom_3d8n(ENC, xi, eta, zeta)
% GEOM_3D8N 计算C3D8单元的几何矩阵(应变-位移矩阵B与雅可比矩阵JCB)
%
% 输入:
%   ENC : 8x3 矩阵，单元节点坐标 [x, y, z]
%   xi, eta, zeta : 局部自然坐标 (-1 到 1)
% 输出:
%   B   : 6x24 应变-位移矩阵
%   JCB : 3x3 雅可比矩阵

    % 1. 获取形函数对局部坐标的导数
    % 调用外部函数 shape_3d8n，DSHP大小为 3x8
    [~, DSHP] = shape_3d8n(xi, eta, zeta);

    % 2. 计算雅可比矩阵 (Jacobian Matrix)
    % JCB = DSHP * ENC
    JCB = DSHP * ENC;

    % 3. 计算对全局坐标(x,y,z)的导数
    % 计算雅可比矩阵的逆
    IJCB = inv(JCB);
    % 变换导数: DSHPG = inv(J) * DSHP (结果行顺序对应 d/dx, d/dy, d/dz)
    DSHPG = IJCB * DSHP;

    % 4. 组装 B 矩阵 (6x24)
    % 应变分量顺序: [eps_x, eps_y, eps_z, gam_xy, gam_yz, gam_zx]'
    B = zeros(6, 24);

    for i = 1:8
        % 提取当前节点 i 的全局导数
        dN_dx = DSHPG(1, i);
        dN_dy = DSHPG(2, i);
        dN_dz = DSHPG(3, i);
        
        % 确定当前节点对应的列索引 (对应的位移分量 u, v, w)
        c1 = 3*i - 2; 
        c2 = 3*i - 1; 
        c3 = 3*i;
        
        % 填充 B 矩阵
        % 行 1-3: 正应变 (eps_x, eps_y, eps_z)
        B(1, c1) = dN_dx;
        B(2, c2) = dN_dy;
        B(3, c3) = dN_dz;
        
        % 行 4: 剪应变 gam_xy = du/dy + dv/dx
        B(4, c1) = dN_dy;
        B(4, c2) = dN_dx;
        
        % 行 5: 剪应变 gam_yz = dv/dz + dw/dy
        B(5, c2) = dN_dz;
        B(5, c3) = dN_dy;
        
        % 行 6: 剪应变 gam_zx = dw/dx + du/dz
        B(6, c1) = dN_dz;
        B(6, c3) = dN_dx;
    end
end