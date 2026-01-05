function [Nodes, Elements, Forces, BoundaryConditions] = read_inp(filename)
% ABAQUS_INP_EXTRACTOR
% 功能说明：
% 解析 Abaqus INP 文件，支持带有 *SYSTEM 坐标变换的扁平化文件格式。
%
% 输出：
% Nodes:              节点坐标矩阵 [ID, x, y, z] (全局坐标)
% Elements:           单元拓扑矩阵 [ID, Node1, Node2, ...]
% Forces:             外力矩阵 [ElemID, NodeID, DOF, Value] 
% BoundaryConditions: 边界条件矩阵 [NodeID, DOF, Value]
%
% 主要功能模块：
% 1. 自动解析 *SYSTEM 并实时转换节点坐标 (Local -> Global)。
% 2. 读取单元、集合(NSET/ELSET)、表面(SURFACE)。
% 3. 解析 Boundary Conditions (支持数值型和类型型如 ENCASTRE)。
% 4. 计算 Forces：包含 CLOAD 点力和 DSLOAD 面压力(自动积分转换为等效节点力)。

    fid = fopen(filename, 'r');
    if fid == -1, error('Cannot open file %s', filename); end
    
    % --- 0. 快速读取 ---
    raw_data = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
    all_lines = raw_data{1};
    fclose(fid);
    
    % --- 1. 初始化全局容器 ---
    GlobalNodes = [];
    GlobalElems = [];
    
    % 集合存储 (Key = SET_NAME, Value = IDs)
    nsets = containers.Map('KeyType','char','ValueType','any');
    elsets = containers.Map('KeyType','char','ValueType','any');
    surf_map = containers.Map('KeyType','char','ValueType','any');
    
    % 原始数据暂存
    bcs_raw = {}; 
    cloads_raw = {}; 
    dsloads_raw = {}; 
    
    % 坐标变换状态机 (默认: 原点[0,0,0], 无旋转)
    current_origin = [0, 0, 0];
    current_rot = eye(3);
    
    idx = 1;
    num_lines = length(all_lines);
    
    %% === 第一阶段：线性扫描与解析 ===
    while idx <= num_lines
        line = strtrim(all_lines{idx});
        
        % 跳过注释和空行
        if isempty(line) || strncmp(line, '**', 2)
            idx = idx + 1; continue;
        end
        
        if strncmp(line, '*', 1)
            Keyword = upper(line);
            
            % --- A. 处理坐标系 (*SYSTEM) ---
            if contains(Keyword, '*SYSTEM')
                [blk, next_idx] = read_data_block(all_lines, idx + 1);
                vals = parse_csv_matrix(blk);
                if ~isempty(vals)
                    % 格式: Origin(x,y,z), X_Axis_Point(x,y,z)
                    p1 = vals(1, 1:3); 
                    p2 = vals(1, 4:6);
                    current_origin = p1; % 更新原点平移
                end
                idx = next_idx; continue;
            end
            
            % --- B. 读取节点 (*NODE) ---
            if contains(Keyword, '*NODE') && ~contains(Keyword, 'OUTPUT')
                [blk, next_idx] = read_data_block(all_lines, idx + 1);
                local_data = parse_csv_matrix(blk);
                
                if ~isempty(local_data)
                    [r, c] = size(local_data);
                    coords_local = zeros(r, 3);
                    if c >= 4, coords_local = local_data(:, 2:4);
                    elseif c == 3, coords_local(:, 1:2) = local_data(:, 2:3); end
                    
                    % 核心：执行坐标变换 Global = Origin + Local * Rot
                    coords_global = current_origin + coords_local * current_rot;
                    
                    GlobalNodes = [GlobalNodes; local_data(:,1), coords_global];
                end
                idx = next_idx; continue;
            end
            
            % --- C. 读取单元 (*ELEMENT) ---
            if contains(Keyword, '*ELEMENT') && ~contains(Keyword, 'OUTPUT')
                [blk, next_idx] = read_data_block(all_lines, idx + 1);
                elems = parse_csv_matrix(blk);
                
                % 动态扩展矩阵列数 (处理混合单元类型)
                if ~isempty(GlobalElems)
                    max_cols = max(size(GlobalElems, 2), size(elems, 2));
                    GlobalElems = pad_matrix(GlobalElems, max_cols);
                    elems = pad_matrix(elems, max_cols);
                end
                GlobalElems = [GlobalElems; elems];
                idx = next_idx; continue;
            end
            
            % --- D. 读取集合 (NSET/ELSET) ---
            if contains(Keyword, '*NSET')
                name = extract_param(line, 'NSET'); is_gen = contains(Keyword, 'GENERATE');
                [blk, next_idx] = read_data_block(all_lines, idx + 1);
                if ~isempty(name), nsets(upper(name)) = parse_ids(blk, is_gen); end
                idx = next_idx; continue;
            end
            if contains(Keyword, '*ELSET')
                name = extract_param(line, 'ELSET'); is_gen = contains(Keyword, 'GENERATE');
                [blk, next_idx] = read_data_block(all_lines, idx + 1);
                if ~isempty(name), elsets(upper(name)) = parse_ids(blk, is_gen); end
                idx = next_idx; continue;
            end
            
            % --- E. 读取表面 (*SURFACE) ---
            if contains(Keyword, '*SURFACE')
                name = extract_param(line, 'NAME');
                [blk, next_idx] = read_data_block(all_lines, idx + 1);
                if ~isempty(name)
                    % 解析 Surface 定义 {Elset, FaceID}
                    s_def = [];
                    for i = 1:length(blk)
                        p = split_line(blk{i});
                        if length(p) >= 2, s_def = [s_def; p(1), p(2)]; end
                    end
                    surf_map(upper(name)) = s_def;
                end
                idx = next_idx; continue;
            end
            
            % --- F. 暂存 BC 和 Loads ---
            if contains(Keyword, '*BOUNDARY')
                [blk, next_idx] = read_data_block(all_lines, idx+1); 
                bcs_raw = [bcs_raw; blk(:)]; idx=next_idx; continue;
            end
            if contains(Keyword, '*CLOAD')
                [blk, next_idx] = read_data_block(all_lines, idx+1); 
                cloads_raw = [cloads_raw; blk(:)]; idx=next_idx; continue;
            end
            if contains(Keyword, '*DSLOAD')
                [blk, next_idx] = read_data_block(all_lines, idx+1); 
                dsloads_raw = [dsloads_raw; blk(:)]; idx=next_idx; continue;
            end
        end
        idx = idx + 1;
    end
    
    Nodes = GlobalNodes;
    Elements = GlobalElems;
    
    %% === 第二阶段：构建索引与后处理 ===
    
    % 构建 ID -> Row 索引加速查找
    if ~isempty(Nodes)
        max_nid = max(Nodes(:,1));
        map_nid = sparse(Nodes(:,1), 1, 1:size(Nodes,1), max_nid, 1);
    else, map_nid = []; end
    
    if ~isempty(Elements)
        max_eid = max(Elements(:,1));
        map_eid = sparse(Elements(:,1), 1, 1:size(Elements,1), max_eid, 1);
    else, map_eid = []; end
    
    % --- 1. 解析 Boundary Conditions ---
    BoundaryConditions = [];
    for i = 1:length(bcs_raw)
        parts = split_line(bcs_raw{i});
        if isempty(parts), continue; end
        
        ids = resolve_ids(upper(parts{1}), nsets);
        val = 0.0; dofs = [];
        
        if length(parts) >= 2
            p2 = upper(parts{2});
            if ~isnan(str2double(p2)) % 格式: ID, start_dof, end_dof, val
                st = str2double(p2); ed = st;
                if length(parts)==3
                    p3 = str2double(parts{3});
                    if ~isnan(p3) && (p3>=st && p3<=6) && mod(p3,1)==0, ed=p3; else, val=p3; end
                elseif length(parts)>=4
                    ed = str2double(parts{3}); val = str2double(parts{4});
                end
                dofs = st:ed;
            else % 格式: ID, TYPE (e.g. ENCASTRE)
               switch p2
                    % 对称/反对称约束
                    case 'XSYMM',    dofs = [1, 5, 6]; % U1=R2=R3=0
                    case 'YSYMM',    dofs = [2, 4, 6]; % U2=R1=R3=0
                    case 'ZSYMM',    dofs = [3, 4, 5]; % U3=R1=R2=0
                    case 'XASYMM',   dofs = [2, 3, 4]; % U2=U3=R1=0
                    case 'YASYMM',   dofs = [1, 3, 5]; % U1=U3=R2=0
                    case 'ZASYMM',   dofs = [1, 2, 6]; % U1=U2=R3=0 
                    case 'PINNED',   dofs = 1:3;       % U1=U2=U3=0
                    case 'ENCASTRE', dofs = 1:6;       % All fixed
                end
            end
        end
        for n = ids(:)', for d = dofs, BoundaryConditions = [BoundaryConditions; n, d, val]; end; end
    end
    if ~isempty(BoundaryConditions), BoundaryConditions = unique(BoundaryConditions, 'rows'); end
    
    % --- 2. 计算 Forces (CLOAD + DSLOAD) ---
    Forces = [];
    
    % 2.1 CLOAD (直接读取)
    for i = 1:length(cloads_raw)
        p = split_line(cloads_raw{i});
        if length(p)<3, continue; end
        ids = resolve_ids(upper(p{1}), nsets);
        dof = str2double(p{2}); mag = str2double(p{3});
        for n = ids(:)', Forces = [Forces; 0, n, dof, mag]; end
    end
    
    % 2.2 DSLOAD (压力 -> 节点力)
    for i = 1:length(dsloads_raw)
        p = split_line(dsloads_raw{i});
        if length(p) < 3, continue; end
        
        surf_name = upper(p{1}); 
        press_mag = str2double(p{3});
        
        if isKey(surf_map, surf_name)
            faces = surf_map(surf_name); % {Elset, FaceID}
            [rows, ~] = size(faces);
            
            for k = 1:rows
                eids = resolve_ids(upper(faces{k,1}), elsets);
                face_id = upper(faces{k,2});
                
                for eid = eids(:)'
                    if eid > length(map_eid) || map_eid(eid)==0, continue; end
                    elem_topo = Elements(map_eid(eid), :);
                    
                    % 获取该面的节点ID
                    fnodes = get_face_nodes_topo(elem_topo, face_id);
                    if length(fnodes) < 2, continue; end
                    
                    % 获取节点坐标
                    fcoords = [];
                    for ni = 1:length(fnodes)
                        if fnodes(ni) <= length(map_nid) && map_nid(fnodes(ni)) > 0
                            fcoords = [fcoords; Nodes(map_nid(fnodes(ni)), 2:4)];
                        end
                    end
                    if size(fcoords, 1) < 2, continue; end
                    
                    % 几何计算
                    [area, normal] = calc_face_geometry(fcoords);
                    
                    % 分配力 (P正值指向内 -> 力 = -P * A * n)
                    total_force = -press_mag * area * normal;
                    node_force = total_force / length(fnodes);
                    
                    for ni = fnodes
                        for d = 1:3
                            if abs(node_force(d)) > 1e-9
                                Forces = [Forces; eid, ni, d, node_force(d)];
                            end
                        end
                    end
                end
            end
        end
    end
end

%% === 辅助函数库 ===
function [blk, idx] = read_data_block(lines, idx)
    blk = {};
    while idx <= length(lines)
        l = strtrim(lines{idx});
        if strncmp(l, '*', 1) && ~strncmp(l, '**', 2), break; end
        if ~isempty(l) && ~strncmp(l, '**', 2), blk{end+1} = l; end
        idx = idx + 1;
    end
end

function vals = parse_csv_matrix(blk)
    if isempty(blk), vals=[]; return; end
    c = cellfun(@(x) sscanf(strrep(x,',',' '), '%f')', blk, 'UniformOutput', false);
    ml = max(cellfun(@length, c));
    vals = zeros(length(c), ml);
    for i=1:length(c), vals(i, 1:length(c{i})) = c{i}; end
end

function ids = parse_ids(blk, gen)
    raw = parse_csv_matrix(blk);
    if isempty(raw), ids=[]; return; end
    if gen
        ids = []; for i=1:size(raw,1), st=1; if size(raw,2)>=3, st=raw(i,3); end; ids=[ids, raw(i,1):st:raw(i,2)]; end
    else
        ids = raw(:)'; ids(ids==0)=[];
    end
end

function ids = resolve_ids(t, set_map)
    v = str2double(t);
    if ~isnan(v), ids = v;
    elseif isKey(set_map, t), ids = set_map(t);
    else, ids = []; end
end

function parts = split_line(line)
    parts = regexp(line, '[,\s]+', 'split');
    parts = parts(~cellfun('isempty', parts));
end

function val = extract_param(header, key)
    val = ''; parts = regexp(header, ',', 'split');
    for i=1:length(parts)
        item = strtrim(parts{i}); idx = strfind(item, '=');
        if ~isempty(idx) && strcmpi(strtrim(item(1:idx(1)-1)), key), val = strtrim(item(idx(1)+1:end)); return; end
    end
end

function M = pad_matrix(M, cols)
    [r, c] = size(M);
    if c < cols, M = [M, zeros(r, cols-c)]; end
end

% --- 几何计算 (支持 2D 边长与 3D 面积计算) ---
function [area, normal] = calc_face_geometry(coords)
    [n, ~] = size(coords);
    if n == 2 % 2D 单元的边
        edge = coords(2,:) - coords(1,:);
        len = norm(edge);
        area = len; % 2D 中长度即“面积”
        % 计算平面内法向 (切向 x Z轴)
        tangent = edge / (len + 1e-20);
        normal = cross(tangent, [0,0,1]); 
    elseif n >= 3 % 3D 单元的面
        if n==3, v1=coords(2,:)-coords(1,:); v2=coords(3,:)-coords(1,:);
        else, v1=coords(3,:)-coords(1,:); v2=coords(4,:)-coords(2,:); end
        cp = cross(v1, v2); vn = norm(cp);
        area = 0.5 * vn; normal = cp / (vn + 1e-20);
    else
        area=0; normal=[0,0,0];
    end
end

function nodes = get_face_nodes_topo(elem_row, face_str)
    topo = elem_row(2:end); topo(topo==0) = [];
    len = length(topo);
    idx = [];
    % 简单规则区分 2D/3D
    if len == 3 % Tri (2D CPS3)
        switch face_str, case 'S1', idx=[1,2]; case 'S2', idx=[2,3]; case 'S3', idx=[3,1]; end
    elseif len == 4 % Quad (2D CPS4) %暂时无法与四面体单元区分
        switch face_str, case 'S1', idx=[1,2]; case 'S2', idx=[2,3]; case 'S3', idx=[3,4]; case 'S4', idx=[4,1]; end
    elseif len >= 8 % Hex (3D)
        switch face_str
            case 'S1', idx=[1,4,3,2]; case 'S2', idx=[5,6,7,8];
            case 'S3', idx=[1,2,6,5]; case 'S4', idx=[2,3,7,6];
            case 'S5', idx=[3,4,8,7]; case 'S6', idx=[4,1,5,8];
        end
    end
    if ~isempty(idx), nodes = topo(idx); else, nodes = []; end
end