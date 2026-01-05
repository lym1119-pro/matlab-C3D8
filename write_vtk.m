function write_vtk(filename, Nxy, Enod, Ndsp, Nstrs, Neps)
    % WRITE_VTK 导出 VTK 文件 (包含位移、全部分量应力/应变及 VonMises)
    % 输入:
    %   filename - 保存路径 (.vtk)
    %   Nxy      - 节点坐标 [ID, x, y, z]
    %   Enod     - 单元连接 [ID, n1...n8]
    %   Ndsp     - 位移结果 [ID, u, v, w]
    %   Nstrs    - 应力结果 [ID, sx, sy, sz, sxy, syz, szx]
    %   Neps     - 应变结果 [ID, ex, ey, ez, exy, eyz, ezx]
 
    % 打开文件 (使用 'fid' 作为文件标识符，避免与文件名变量混淆)
    fid = fopen(filename, 'w');
    if fid == -1
        error('无法打开文件写入: %s', filename);
    end

    % 自动获取节点数和单元数
    N = size(Nxy, 1);
    n = size(Enod, 1);

    % --- Header ---
    fprintf(fid, '# vtk DataFile Version 3.1\n');
    fprintf(fid, '3D FEA Result C3D8\n'); 
    fprintf(fid, 'ASCII\n');
    fprintf(fid, 'DATASET UNSTRUCTURED_GRID\n');
    fprintf(fid, '\n');

    % --- 1. 输出节点坐标 (POINTS) ---
    fprintf(fid, 'POINTS         %d  DOUBLE\n', N);
    for i = 1:N
        fprintf(fid, '%12.8f       %12.8f       %12.8f\n', Nxy(i, 2:4));
    end
    fprintf(fid, '\n');

    % --- 2. 输出单元连接关系 (CELLS) ---
    fprintf(fid, 'CELLS           %d        %d\n', n, 9*n);
    for i = 1:n
        % MATLAB 索引 1-based 转 VTK 0-based，故减 1
        fprintf(fid, '8 %d %d %d %d %d %d %d %d\n', Enod(i, 2:9) - 1);
    end
    fprintf(fid, '\n');

    % --- 3. 输出单元类型 (CELL_TYPES) ---
    fprintf(fid, 'CELL_TYPES          %d\n', n);
    for i = 1:n
        fprintf(fid, '%d\n', 12); % 12 = Hexahedron
    end
    fprintf(fid, '\n');

    % --- 4. 输出节点位移 (VECTORS) ---
    fprintf(fid, 'POINT_DATA          %d\n', N);
    
    if ~isempty(Ndsp)
        fprintf(fid, 'VECTORS displacement DOUBLE\n');
        for i = 1:N
            fprintf(fid, '%12.8f       %12.8f       %12.8f\n', Ndsp(i, 2:4));
        end
        fprintf(fid, '\n');
    end

    % ==========================================================
    %                  输出应力 (Stress)
    % ==========================================================
    if ~isempty(Nstrs)
        % --- Stress XX ---
        fprintf(fid, 'SCALARS Stress_XX DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Nstrs(i, 2)); end
        
        % --- Stress YY ---
        fprintf(fid, 'SCALARS Stress_YY DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Nstrs(i, 3)); end
        
        % --- Stress ZZ ---
        fprintf(fid, 'SCALARS Stress_ZZ DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Nstrs(i, 4)); end
        
        % --- Stress XY ---
        fprintf(fid, 'SCALARS Stress_XY DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Nstrs(i, 5)); end
        
        % --- Stress YZ ---
        fprintf(fid, 'SCALARS Stress_YZ DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Nstrs(i, 6)); end
        
        % --- Stress ZX ---
        fprintf(fid, 'SCALARS Stress_ZX DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Nstrs(i, 7)); end
        
        % --- 3D Von Mises Stress ---
        fprintf(fid, 'SCALARS Stress_VonMises DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N
            sx = Nstrs(i,2); sy = Nstrs(i,3); sz = Nstrs(i,4);
            sxy = Nstrs(i,5); syz = Nstrs(i,6); szx = Nstrs(i,7);
            
            % 3D Von Mises 公式
            term1 = (sx - sy)^2 + (sy - sz)^2 + (sz - sx)^2;
            term2 = 6 * (sxy^2 + syz^2 + szx^2);
            vm = sqrt(0.5 * (term1 + term2));
            
            fprintf(fid, '%12.8f\n', vm);
        end
    end

    % ==========================================================
    %                  输出应变 (Strain)
    % ==========================================================
    if ~isempty(Neps)
        % --- Strain XX ---
        fprintf(fid, 'SCALARS Strain_XX DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Neps(i, 2)); end
        
        % --- Strain YY ---
        fprintf(fid, 'SCALARS Strain_YY DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Neps(i, 3)); end
        
        % --- Strain ZZ ---
        fprintf(fid, 'SCALARS Strain_ZZ DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Neps(i, 4)); end
        
        % --- Strain XY ---
        fprintf(fid, 'SCALARS Strain_XY DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Neps(i, 5)); end
        
        % --- Strain YZ ---
        fprintf(fid, 'SCALARS Strain_YZ DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Neps(i, 6)); end
        
        % --- Strain ZX ---
        fprintf(fid, 'SCALARS Strain_ZX DOUBLE 1\n'); 
        fprintf(fid, 'LOOKUP_TABLE default\n');
        for i = 1:N, fprintf(fid, '%12.8f\n', Neps(i, 7)); end
    end

    % 关闭文件
    fclose(fid);
end