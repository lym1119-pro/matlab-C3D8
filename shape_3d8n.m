function [SHP,DSHP] = shape_3d8n(xi,eta,zeta)
% C3D8单元（8节点六面体）形函数及其导数计算
% 输入:
%   xi, eta, zeta - 局部自然坐标 (范围 -1 到 1)
% 输出:
%   SHP  - 形函数向量 (1x8)
%   DSHP - 形函数对局部坐标的导数矩阵 (3x8)

% 定义辅助变量 (1 +/- 坐标值)，简化后续计算
rp = 1 + xi;   rm = 1 - xi;
sp = 1 + eta;  sm = 1 - eta;
tp = 1 + zeta; tm = 1 - zeta;

% 计算形函数 (N1 到 N8)
% 系数为 1/8
SHP = zeros(1,8);
SHP(1) = 0.125 * rm * sm * tm; % 节点 1 (-1, -1, -1)
SHP(2) = 0.125 * rp * sm * tm; % 节点 2 (+1, -1, -1)
SHP(3) = 0.125 * rp * sp * tm; % 节点 3 (+1, +1, -1)
SHP(4) = 0.125 * rm * sp * tm; % 节点 4 (-1, +1, -1)
SHP(5) = 0.125 * rm * sm * tp; % 节点 5 (-1, -1, +1)
SHP(6) = 0.125 * rp * sm * tp; % 节点 6 (+1, -1, +1)
SHP(7) = 0.125 * rp * sp * tp; % 节点 7 (+1, +1, +1)
SHP(8) = 0.125 * rm * sp * tp; % 节点 8 (-1, +1, +1)

% 计算形函数导数矩阵
% DSHP(1,:) -> d(Ni)/d(xi)
% DSHP(2,:) -> d(Ni)/d(eta)
% DSHP(3,:) -> d(Ni)/d(zeta)
DSHP = zeros(3,8);

% ----------------------------
% 对 xi 的偏导数
DSHP(1,1) = -0.125 * sm * tm;
DSHP(1,2) =  0.125 * sm * tm;
DSHP(1,3) =  0.125 * sp * tm;
DSHP(1,4) = -0.125 * sp * tm;
DSHP(1,5) = -0.125 * sm * tp;
DSHP(1,6) =  0.125 * sm * tp;
DSHP(1,7) =  0.125 * sp * tp;
DSHP(1,8) = -0.125 * sp * tp;

% ----------------------------
% 对 eta 的偏导数
DSHP(2,1) = -0.125 * rm * tm;
DSHP(2,2) = -0.125 * rp * tm;
DSHP(2,3) =  0.125 * rp * tm;
DSHP(2,4) =  0.125 * rm * tm;
DSHP(2,5) = -0.125 * rm * tp;
DSHP(2,6) = -0.125 * rp * tp;
DSHP(2,7) =  0.125 * rp * tp;
DSHP(2,8) =  0.125 * rm * tp;

% ----------------------------
% 对 zeta 的偏导数
DSHP(3,1) = -0.125 * rm * sm;
DSHP(3,2) = -0.125 * rp * sm;
DSHP(3,3) = -0.125 * rp * sp;
DSHP(3,4) = -0.125 * rm * sp;
DSHP(3,5) =  0.125 * rm * sm;
DSHP(3,6) =  0.125 * rp * sm;
DSHP(3,7) =  0.125 * rp * sp;
DSHP(3,8) =  0.125 * rm * sp;
end