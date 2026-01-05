classdef FEA_GUI < matlab.apps.AppBase
    % =====================================================================
    % FEA Solver Pro - 最终优化版 (UI Enhanced)
    % 含：Abaqus交互、ParaView联动、详细耗时统计、HTML彩色日志
    % 更新：加大按钮尺寸，增加可视化图标
    % =====================================================================
    
    % ---------------------------------------------------------------------
    % 1. UI 组件属性
    % ---------------------------------------------------------------------
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        
        % 菜单
        MenuFile             matlab.ui.container.Menu
        MenuSettings         matlab.ui.container.Menu
        MenuReset            matlab.ui.container.Menu
        
        % 布局容器
        MainLayout           matlab.ui.container.GridLayout
        SidebarPanel         matlab.ui.container.Panel
        SidebarGrid          matlab.ui.container.GridLayout
        
        % 左侧各模块
        BrandPanel           matlab.ui.container.Panel
        BrandLabel           matlab.ui.control.Label
        
        % 1. 导入
        PanelImport          matlab.ui.container.Panel
        LblTitle1            matlab.ui.control.Label
        GridImport           matlab.ui.container.GridLayout
        BtnLoad              matlab.ui.control.Button
        BtnAbaqusBuild       matlab.ui.control.Button
        LblFile              matlab.ui.control.Label
        PanelStats           matlab.ui.container.Panel
        GridStats            matlab.ui.container.GridLayout
        LblNodes             matlab.ui.control.Label
        LblElems             matlab.ui.control.Label
        
        % 2. 材料
        PanelMat             matlab.ui.container.Panel
        LblTitle2            matlab.ui.control.Label
        GridMat              matlab.ui.container.GridLayout
        LblE                 matlab.ui.control.Label
        EditE                matlab.ui.control.NumericEditField
        LblNu                matlab.ui.control.Label
        EditNu               matlab.ui.control.NumericEditField
        
        % 3. 求解
        PanelSolve           matlab.ui.container.Panel
        LblTitle3            matlab.ui.control.Label
        GridSolve            matlab.ui.container.GridLayout
        StatusLamp           matlab.ui.control.Lamp
        StatusText           matlab.ui.control.Label
        ProgBar              matlab.ui.control.LinearGauge
        BtnRun               matlab.ui.control.Button
        
        % 4. 结果
        PanelExport          matlab.ui.container.Panel
        LblTitle4            matlab.ui.control.Label
        GridExport           matlab.ui.container.GridLayout
        BtnExport            matlab.ui.control.Button
        BtnParaView          matlab.ui.control.Button
        
        % 右侧工作区
        WorkPanel            matlab.ui.container.Panel
        WorkGrid             matlab.ui.container.GridLayout
        ViewContainer        matlab.ui.container.Panel
        ViewLayout           matlab.ui.container.GridLayout
        ToolbarPanel         matlab.ui.container.Panel
        ToolbarGrid          matlab.ui.container.GridLayout
        BtnViewFit           matlab.ui.control.Button
        BtnShowMesh          matlab.ui.control.Button
        BtnTrans             matlab.ui.control.Button
        BtnSnap              matlab.ui.control.Button
        UIAxes               matlab.ui.control.UIAxes
        LogPanel             matlab.ui.container.Panel
        LogGrid              matlab.ui.container.GridLayout
        LogHeader            matlab.ui.control.Label
        LogText              matlab.ui.control.HTML % 使用 HTML 显示彩色日志
    end
    
    % ---------------------------------------------------------------------
    % 2. 数据与配置
    % ---------------------------------------------------------------------
    properties (Access = private)
        % 核心数据
        NXYZ = []; Enod = []; EP = []; Cons = [];
        Ndsp = []; Nstrs = []; Neps = [];
        IsLoaded = false; BoundaryFaces = []; NumElems = 0;
        
        % 路径配置
        ParaViewPath = ''; 
        AbaqusPath = '';
        
        % 状态机
        IsAbaqusPending = false; 
        PendingInpPath = '';
        
        % 交互状态
        IsRotating = false; IsPanning = false; LastMousePos = [0, 0];
        CurrentLang = 'CN'; CurrentTheme = 'Light'; 
        ShowMeshLines = true; IsTransparent = false; Colors;
    end
    
    % ---------------------------------------------------------------------
    % 3. 业务逻辑 (Controller)
    % ---------------------------------------------------------------------
    methods (Access = private)
        
        % === 初始化 ===
        function startupFcn(app)
            app.CurrentLang = 'CN';
            app.CurrentTheme = 'Light';
            
            % 读取配置
            app.ParaViewPath = getpref('FEA_GUI', 'PVPath', '');
            app.AbaqusPath = getpref('FEA_GUI', 'AbqPath', '');
            
            app.updateLanguage(); 
            app.setTheme('Light');
            
            % 初始化日志头
            app.LogText.HTMLSource = '<div style="font-family:''Segoe UI'',sans-serif; font-size:12px; color:#888; padding:5px;">系统就绪.</div>';
            app.log('欢迎使用 FEA Solver Pro', 'info'); 
        end
        
        % === 智能彩色日志系统 ===
        function log(app, msg, type, timeCost)
            if nargin < 3, type = 'info'; end
            if nargin < 4, timeCost = -1; end
            if ~isvalid(app), return; end
            
            % 颜色定义
            switch type
                case 'info',    color = '#3498db'; icon = '🔵'; % 蓝
                case 'success', color = '#27ae60'; icon = '🟢'; % 绿
                case 'warn',    color = '#e67e22'; icon = '🟠'; % 橙
                case 'error',   color = '#c0392b'; icon = '🔴'; % 红
                otherwise,      color = '#2c3e50'; icon = '⚫';
            end
            
            if strcmp(app.CurrentTheme, 'Dark')
                 if strcmp(type, 'info') || strcmp(type, 'normal'), color = '#ecf0f1'; end
            end
            
            t = datestr(now, 'HH:MM:SS');
            
            % 耗时显示 HTML
            timeStr = '';
            if timeCost >= 0
                timeStr = sprintf('<span style="float:right; color:#888; font-size:11px;">⏱️ <b>%.3f s</b></span>', timeCost);
            end
            
            % 构造新消息行
            newRow = sprintf([...
                '<div style="border-bottom:1px solid #eee; padding: 4px 0;">', ...
                '  <span style="color:#999; font-size:11px; margin-right:5px;">[%s]</span>', ...
                '  <span style="margin-right:5px;">%s</span>', ...
                '  <span style="color:%s; font-weight:500;">%s</span>', ...
                '  %s', ...
                '</div>'], t, icon, color, msg, timeStr);
            
            app.LogText.HTMLSource = [newRow, app.LogText.HTMLSource];
        end
        
        function logError(app, ME)
            app.log(['错误: ' ME.message], 'error');
            app.setBusy(false, 'Error');
            app.StatusLamp.Color = 'red';
            uialert(app.UIFigure, ME.message, '系统错误');
        end
        
        % === 1. 文件加载 ===
        function loadInpFile(app, fullPath)
            [~, name, ext] = fileparts(fullPath);
            fileName = [name, ext];
            
            app.setBusy(true, '正在解析网格...'); drawnow;
            tStart = tic;
            
            try
                app.log(['开始加载: ' fileName], 'info');
                
                % 读取 (需确保 read_inp 在路径中)
                if exist('read_inp', 'file')
                    [app.NXYZ, app.Enod, app.EP, app.Cons] = read_inp(fullPath);
                else
                    error('未找到 read_inp 函数，请检查路径。');
                end
                
                % 数据更新
                app.NumElems = size(app.Enod, 1);
                app.IsLoaded = true;
                app.LblFile.Text = fileName;
                app.updateStatLabels(); 
                
                % 渲染
                app.BoundaryFaces = app.extractSkin(app.Enod(:, 2:9));
                app.renderScene();
                
                dt = toc(tStart);
                app.log(sprintf('加载完成 (节点:%d, 单元:%d)', size(app.NXYZ,1), app.NumElems), 'success', dt);
                
                app.setBusy(false, '就绪');
                app.BtnRun.Enable = 'on';
                app.StatusLamp.Color = 'green';
                
                % 重置结果
                app.Ndsp = []; 
                app.BtnExport.Enable = 'off'; 
                app.BtnParaView.Enable = 'off';
                
            catch ME
                app.logError(ME); 
                app.LblFile.Text = '加载失败';
            end
        end
        
        function onBtnLoad(app, ~)
            [file, path] = uigetfile('*.inp', '选择 INP 文件');
            if isequal(file, 0), return; end
            app.loadInpFile(fullfile(path, file));
        end

        % === 2. Abaqus 交互 ===
        function onOpenAbaqusBuilder(app, ~)
            % [状态 2] 用户点“完成并导入”
            if app.IsAbaqusPending
                if exist(app.PendingInpPath, 'file')
                    app.log('检测到新模型，开始导入...', 'success');
                    app.loadInpFile(app.PendingInpPath);
                    % 恢复界面
                    app.IsAbaqusPending = false;
                    app.BtnAbaqusBuild.Text = '🛠️ Abaqus 建模';
                    app.BtnAbaqusBuild.FontColor = [0 0 0];
                    app.BtnLoad.Enable = 'on';
                else
                    uialert(app.UIFigure, ['未找到: ' app.PendingInpPath '\n请在 Abaqus 中确认已生成 INP 文件。'], '文件缺失');
                end
                return;
            end
            
            % [状态 1] 启动 Abaqus
            if isempty(app.AbaqusPath) || ~exist(app.AbaqusPath, 'file')
                uialert(app.UIFigure, '首次使用请定位 abaqus.bat', '配置');
                [file, path] = uigetfile({'*.bat;*.exe', 'Abaqus Command'}, '定位 Abaqus');
                if isequal(file, 0), return; end
                app.AbaqusPath = fullfile(path, file);
                setpref('FEA_GUI', 'AbqPath', app.AbaqusPath);
            end
            
            [file, path] = uiputfile('*.inp', '设定新模型保存位置');
            if isequal(file, 0), return; end
            
            app.PendingInpPath = fullfile(path, file);
            [~, jobName, ~] = fileparts(file);
            
            app.log('正在启动 Abaqus CAE...', 'warn');
            try
                cmd = sprintf('cd /d "%s" && "%s" cae &', path, app.AbaqusPath);
                system(cmd);
                
                % 切换界面状态
                app.IsAbaqusPending = true;
                app.BtnAbaqusBuild.Text = '📥 完成并导入';
                app.BtnAbaqusBuild.FontColor = [0.8 0 0];
                app.BtnLoad.Enable = 'off';
                
                app.log(sprintf('请在 Abaqus 创建 Job: "%s" 并 Write Input。', jobName), 'warn');
            catch ME
                app.logError(ME);
            end
        end
        
        function onResetPaths(app, type)
            if strcmp(type, 'Abaqus')
                app.AbaqusPath = ''; if ispref('FEA_GUI', 'AbqPath'), rmpref('FEA_GUI', 'AbqPath'); end
                app.log('Abaqus 路径已重置', 'info');
            elseif strcmp(type, 'ParaView')
                app.ParaViewPath = ''; if ispref('FEA_GUI', 'PVPath'), rmpref('FEA_GUI', 'PVPath'); end
                app.log('ParaView 路径已重置', 'info');
            end
        end

        % === 3. 求解计算 ===
        function onBtnRun(app, ~)
            if ~app.IsLoaded, return; end
            app.lockUI(true);
            app.setBusy(true, '正在求解...');
            app.StatusLamp.Color = 'blue'; 
            app.ProgBar.Value = 0;
            
            tTotalStart = tic;
            
            try
                app.log('>>> 求解流程启动', 'info');
                
                % [阶段 1] 准备数据
                E = app.EditE.Value; nu = app.EditNu.Value;
                Emat = [app.Enod(:,1), repmat([E, nu], app.NumElems, 1)];
                app.ProgBar.Value = 5; drawnow;
                
                % [阶段 2] 刚度矩阵
                app.log('正在组装全局刚度矩阵 (K)...', 'warn');
                tK = tic;
                % 需确保 gstiffm_3d8n 在路径中
                if ~exist('gstiffm_3d8n', 'file'), error('缺少 gstiffm_3d8n 函数'); end
                GK = gstiffm_3d8n(app.NXYZ, app.Enod, Emat);
                dtK = toc(tK);
                
                kInfo = whos('GK');
                memMB = kInfo.bytes / 1024 / 1024;
                app.log(sprintf('K矩阵组装完成 (内存: %.1f MB)', memMB), 'success', dtK);
                app.ProgBar.Value = 40; drawnow;
                
                % [阶段 3] 载荷
                SP = zeros(3*size(app.NXYZ,1), 1);
                if exist('SloadA3d8n', 'file'), SP = SloadA3d8n(app.EP, size(app.NXYZ,1)); end
                
                % [阶段 4] 求解
                app.log('正在求解线性方程组...', 'warn');
                tS = tic;
                if ~exist('SolveS3d8n', 'file'), error('缺少 SolveS3d8n 函数'); end
                [app.Ndsp, ~] = SolveS3d8n(GK, SP, app.Cons, 1e-6, 5000);
                dtS = toc(tS);
                
                maxDisp = max(abs(app.Ndsp(:, 2:4)), [], 'all');
                app.log(sprintf('方程收敛 (最大位移: %.2e)', maxDisp), 'success', dtS);
                app.ProgBar.Value = 80; drawnow;
                
                % [阶段 5] 后处理
                app.log('正在恢复单元应力...', 'warn');
                tP = tic;
                if ~exist('NstssM3d8n', 'file'), error('缺少 NstssM3d8n 函数'); end
                [app.Neps, app.Nstrs] = NstssM3d8n(app.NXYZ, app.Enod, Emat, app.Ndsp);
                dtP = toc(tP);
                app.log('应力计算完成', 'success', dtP);
                
                % 完成
                app.ProgBar.Value = 100;
                app.setBusy(false, '计算完成');
                app.StatusLamp.Color = 'green';
                
                app.BtnExport.Enable = 'on';
                app.BtnParaView.Enable = 'on';
                
                totalTime = toc(tTotalStart);
                app.log('<<< 分析结束', 'info', totalTime);
                
            catch ME
                app.logError(ME); 
            end
            app.lockUI(false);
        end
        
        % === 4. 导出与可视化 ===
        function onOpenParaView(app, ~)
            if ~app.IsLoaded || isempty(app.Ndsp), return; end
            if isempty(app.ParaViewPath) || ~exist(app.ParaViewPath, 'file')
                uialert(app.UIFigure, '请先配置 ParaView', '配置');
                [file, path] = uigetfile('*.exe', 'ParaView.exe');
                if isequal(file, 0), return; end
                app.ParaViewPath = fullfile(path, file);
                setpref('FEA_GUI', 'PVPath', app.ParaViewPath);
            end
            
            app.setBusy(true, '启动 ParaView...');
            try
                if ~exist('write_vtk', 'file'), error('缺少 write_vtk 函数'); end
                tempVtk = fullfile(tempdir, 'fea_res.vtk');
                write_vtk(tempVtk, app.NXYZ, app.Enod, app.Ndsp, app.Nstrs, app.Neps);
                cmd = sprintf('"%s" "%s" &', app.ParaViewPath, tempVtk);
                system(cmd);
                app.log('已发送至 ParaView', 'success');
            catch ME
                app.logError(ME);
            end
            app.setBusy(false, '就绪');
        end
        
        function onBtnExport(app, ~)
            [file, path] = uiputfile('*.vtk', '保存结果');
            if isequal(file, 0), return; end
            try
                if ~exist('write_vtk', 'file'), error('缺少 write_vtk 函数'); end
                write_vtk(fullfile(path, file), app.NXYZ, app.Enod, app.Ndsp, app.Nstrs, app.Neps);
                app.log(['文件已保存: ' file], 'success');
            catch ME
                app.logError(ME);
            end
        end

        % === UI 辅助 ===
        function setBusy(app, isBusy, txt)
            app.StatusText.Text = txt; 
            app.UIFigure.Pointer = ifelse(isBusy, 'watch', 'arrow');
        end
        function lockUI(app, locked)
            st = matlab.lang.OnOffSwitchState(~locked);
            if ~app.IsAbaqusPending, app.BtnLoad.Enable = st; end
            app.BtnAbaqusBuild.Enable = st; app.BtnRun.Enable = st;
        end
        function faces = extractSkin(~, elems)
            idx = [1 2 3 4; 5 8 7 6; 1 5 6 2; 2 6 7 3; 3 7 8 4; 4 8 5 1];
            allf = zeros(size(elems,1)*6, 4);
            for i=1:6, allf((i-1)*size(elems,1)+1:i*size(elems,1), :) = elems(:, idx(i,:)); end
            [~,~,ix] = unique(sort(allf,2), 'rows');
            cnt = accumarray(ix, 1); faces = allf(cnt(ix)==1, :);
        end
        
        % === 3D 渲染控制 ===
        function onViewFit(app, ~), if ~isempty(app.NXYZ), app.autoFitView(); end, end
        function onToggleMesh(app, ~), app.ShowMeshLines = ~app.ShowMeshLines; app.renderScene(); end
        function onToggleTrans(app, ~), app.IsTransparent = ~app.IsTransparent; app.renderScene(); end
        function onSnapShot(app, ~)
            [file, path] = uiputfile('*.png', '保存截图');
            if ~isequal(file, 0), exportapp(app.UIFigure, fullfile(path, file)); end
        end
        
        function renderScene(app)
            if ~isvalid(app), return; end 
            ax = app.UIAxes; cla(ax); axis(ax, 'off');
            if isempty(app.BoundaryFaces), return; end
            
            nodes = app.NXYZ(:, 2:4);
            alpha = ifelse(app.IsTransparent, 0.4, 1.0);
            eColor = ifelse(app.ShowMeshLines, [0.3 0.3 0.3], 'none');
            if strcmp(app.CurrentTheme, 'Dark'), eColor = [0.7 0.7 0.7]; end
            if ~app.ShowMeshLines, eColor='none'; end
            
            patch(ax, 'Vertices', nodes, 'Faces', app.BoundaryFaces, ...
                'FaceColor', [0.3 0.6 0.85], 'EdgeColor', eColor, ...
                'FaceAlpha', alpha, 'FaceLighting', 'gouraud');
            axis(ax, 'equal', 'vis3d'); app.autoFitView();
        end
        function autoFitView(app)
            app.UIAxes.CameraTarget = mean(app.NXYZ(:, 2:4), 1);
            view(app.UIAxes, 3); camzoom(app.UIAxes, 1.0); axis(app.UIAxes, 'tight');
            delete(findall(app.UIAxes, 'Type', 'light'));
            light(app.UIAxes, 'Position', [1 1 2]); light(app.UIAxes, 'Position', [-1 -1 -1]);
        end
        
        % === 鼠标交互 ===
        function onMouseDown(app, ~)
            p = app.UIFigure.CurrentPoint;
            if p(1)>280 && p(2)>230
                if strcmp(app.UIFigure.SelectionType, 'normal'), app.IsRotating=true; else, app.IsPanning=true; end
                app.LastMousePos = p;
            end
        end
        function onMouseMove(app, ~)
            if (~app.IsRotating && ~app.IsPanning), return; end
            curr = app.UIFigure.CurrentPoint; delta = curr - app.LastMousePos; app.LastMousePos = curr;
            if app.IsRotating, camorbit(app.UIAxes, -delta(1)*0.5, -delta(2)*0.5, 'camera');
            elseif app.IsPanning, camdolly(app.UIAxes, -delta(1)*1.5, -delta(2)*1.5, 0, 'movetarget', 'pixels'); end
        end
        function onMouseUp(app, ~), app.IsRotating=false; app.IsPanning=false; end
        function onScroll(app, e)
             p = app.UIFigure.CurrentPoint;
             if p(1)>280 && p(2)>230, camzoom(app.UIAxes, 1 + e.VerticalScrollCount*0.1); end
        end
        
        % === 样式与多语言 ===
        function setLang(app, lang), app.CurrentLang=lang; app.updateLanguage(); end
        function updateLanguage(app)
            isCN = strcmp(app.CurrentLang, 'CN');
            app.LblTitle1.Text = ifelse(isCN, '1. 模型导入', '1. Import');
            app.BtnLoad.Text = ifelse(isCN, '📂 载入文件', 'Open INP');
            if app.IsAbaqusPending
                app.BtnAbaqusBuild.Text = ifelse(isCN, '📥 完成并导入', 'Finish & Import');
            else
                app.BtnAbaqusBuild.Text = ifelse(isCN, '🛠️ Abaqus 建模', 'Build in Abaqus');
            end
            app.BtnRun.Text = ifelse(isCN, '▶ 提交计算', 'Run Solver');
            app.updateStatLabels();
        end
        function updateStatLabels(app)
            n=size(app.NXYZ,1); e=app.NumElems;
            app.LblNodes.Text=['节点: ' num2str(n)]; app.LblElems.Text=['单元: ' num2str(e)];
        end
        function setTheme(app, theme)
            app.CurrentTheme=theme;
            isDark = strcmp(theme, 'Dark');
            if isDark, c.Bg=[0.12 0.12 0.13]; c.Panel=[0.16 0.17 0.18]; c.Text=[0.9 0.9 0.9];
            else, c.Bg=[0.96 0.96 0.96]; c.Panel=[1 1 1]; c.Text=[0.1 0.1 0.1]; end
            c.Accent=[0 0.45 0.74]; c.View=ifelse(isDark,[0.08 0.08 0.09],[0.9 0.92 0.95]);
            app.Colors=c;
            
            app.UIFigure.Color=c.Bg; app.SidebarPanel.BackgroundColor=c.Panel;
            app.WorkPanel.BackgroundColor=c.Bg; app.ViewContainer.BackgroundColor=c.View;
            app.UIAxes.BackgroundColor=c.View;
            app.UIAxes.XColor=c.Text; app.UIAxes.YColor=c.Text; app.UIAxes.ZColor=c.Text;
            app.LogPanel.BackgroundColor=c.Panel; 
            
            app.applyThemeRecursive(app.UIFigure, c);
            if app.IsAbaqusPending, app.BtnAbaqusBuild.FontColor=[0.8 0 0];
            else, app.BtnAbaqusBuild.FontColor=ifelse(isDark,[1 0.4 0.4],[0 0 0]); end
        end
        
        function applyThemeRecursive(app, comp, c)
             if ~isvalid(comp), return; end
             type = class(comp);
             if contains(type, 'Label'), comp.FontColor=c.Text;
             elseif contains(type, 'Panel') && ~strcmp(comp.Tag, 'SidebarRoot'), comp.BackgroundColor=c.Panel;
             elseif contains(type, 'EditField'), comp.FontColor=c.Text; comp.BackgroundColor=c.Panel;
             end
             if isprop(comp, 'Children')
                 for i=1:length(comp.Children), app.applyThemeRecursive(comp.Children(i), c); end
             end
        end
    end
    
    % ---------------------------------------------------------------------
    % 4. 界面布局 (已优化：高度调整与图标添加)
    % ---------------------------------------------------------------------
    methods (Access = public)
        function app = FEA_GUI
            app.UIFigure = uifigure('Name', 'FEA Solver Pro', 'Position', [100 100 1150 750]);
            app.UIFigure.WindowButtonDownFcn=@(s,e)app.onMouseDown(e);
            app.UIFigure.WindowButtonUpFcn=@(s,e)app.onMouseUp(e);
            app.UIFigure.WindowButtonMotionFcn=@(s,e)app.onMouseMove(e);
            app.UIFigure.WindowScrollWheelFcn=@(s,e)app.onScroll(e);
            
            % Menus
            app.MenuFile = uimenu(app.UIFigure, 'Text', '文件');
            uimenu(app.MenuFile, 'Text', '打开 INP...', 'MenuSelectedFcn', @(s,e)app.onBtnLoad(e));
            uimenu(app.MenuFile, 'Text', 'Abaqus 建模...', 'MenuSelectedFcn', @(s,e)app.onOpenAbaqusBuilder(e));
            app.MenuSettings = uimenu(app.UIFigure, 'Text', '设置');
            app.MenuReset = uimenu(app.MenuSettings, 'Text', '重置路径 (Reset)');
            uimenu(app.MenuReset, 'Text', '重置 Abaqus 路径', 'MenuSelectedFcn', @(~,~)app.onResetPaths('Abaqus'));
            uimenu(app.MenuReset, 'Text', '重置 ParaView 路径', 'MenuSelectedFcn', @(~,~)app.onResetPaths('ParaView'));
            
            % Grid
            app.MainLayout = uigridlayout(app.UIFigure, [1 2]);
            app.MainLayout.ColumnWidth = {280, '1x'}; app.MainLayout.Padding = [5 5 5 5];
            
            % Left Sidebar
            app.SidebarPanel = uipanel(app.MainLayout, 'Tag', 'SidebarRoot');
            app.SidebarGrid = uigridlayout(app.SidebarPanel, [5 1]);
            app.SidebarGrid.RowHeight = {50, 160, 110, 170, 80};
            app.SidebarGrid.Padding = [0 0 0 0]; app.SidebarGrid.RowSpacing = 5;
            
            app.BrandPanel = uipanel(app.SidebarGrid);
            app.BrandLabel = uilabel(app.BrandPanel, 'Text', 'FEA Solver', 'FontSize', 16, 'FontWeight', 'bold', 'Position', [15 15 200 25]);
            
            % 1. Import (修改：行高增加到 55)
            app.PanelImport = app.createGroup(app.SidebarGrid, 2);
            app.LblTitle1 = app.createTitle(app.PanelImport, '1. 模型导入');
            app.GridImport = uigridlayout(app.PanelImport, [4 1]); 
            % [调整] 按钮高度由 35 增加到 55
            app.GridImport.RowHeight = {25, 55, 25, '1x'};
            subGrid = uigridlayout(app.GridImport, [1 2]); 
            subGrid.Padding=[0 0 0 0]; subGrid.ColumnSpacing = 8;
            
            % [调整] 增加图标和字号
            app.BtnLoad = uibutton(subGrid, 'Text', '📂 载入文件', 'FontSize', 14, 'FontWeight', 'bold', 'ButtonPushedFcn', @(s,e)app.onBtnLoad(e));
            app.BtnAbaqusBuild = uibutton(subGrid, 'Text', '🛠️ Abaqus 建模', 'FontSize', 14, 'FontWeight', 'bold', 'ButtonPushedFcn', @(s,e)app.onOpenAbaqusBuilder(e));
            
            app.LblFile = uilabel(app.GridImport, 'Text', '未选择文件', 'FontColor', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');
            app.PanelStats = uipanel(app.GridImport, 'BorderType', 'none');
            app.GridStats = uigridlayout(app.PanelStats, [1 2]); app.GridStats.Padding=[0 0 0 0];
            app.LblNodes = uilabel(app.GridStats, 'Text', '-'); app.LblElems = uilabel(app.GridStats, 'Text', '-');
            
            % 2. Material
            app.PanelMat = app.createGroup(app.SidebarGrid, 3);
            app.LblTitle2 = app.createTitle(app.PanelMat, '2. 材料参数');
            app.GridMat = uigridlayout(app.PanelMat, [2 2]); app.GridMat.Padding=[10 25 10 10];
            app.LblE = uilabel(app.GridMat, 'Text', 'E:'); app.EditE = uieditfield(app.GridMat, 'numeric', 'Value', 70000);
            app.LblNu = uilabel(app.GridMat, 'Text', 'v:'); app.EditNu = uieditfield(app.GridMat, 'numeric', 'Value', 0.3);
            
            % 3. Solve
            app.PanelSolve = app.createGroup(app.SidebarGrid, 4);
            app.LblTitle3 = app.createTitle(app.PanelSolve, '3. 求解控制');
            app.GridSolve = uigridlayout(app.PanelSolve, [3 1]); app.GridSolve.Padding=[10 25 10 10];
            sGrid = uigridlayout(app.GridSolve, [1 2]); sGrid.ColumnWidth={20,'1x'}; sGrid.Padding=[0 0 0 0];
            app.StatusLamp = uilamp(sGrid); app.StatusText = uilabel(sGrid, 'Text', 'Idle', 'FontWeight', 'bold');
            app.ProgBar = uigauge(app.GridSolve, 'linear');
            app.BtnRun = uibutton(app.GridSolve, 'Text', '▶ 提交计算', 'FontSize', 14, 'FontWeight', 'bold', 'Enable', 'off', 'ButtonPushedFcn', @(s,e)app.onBtnRun(e));
            
            % 4. Export (修改：增加图标和字号)
            app.PanelExport = app.createGroup(app.SidebarGrid, 5);
            app.LblTitle4 = app.createTitle(app.PanelExport, '4. 结果处理');
            app.GridExport = uigridlayout(app.PanelExport, [1 2]); app.GridExport.Padding=[10 25 10 10];
            app.GridExport.ColumnSpacing = 10;
            
            app.BtnExport = uibutton(app.GridExport, 'Text', '💾 导出 VTK', 'FontSize', 14, 'FontWeight', 'bold', 'Enable', 'off', 'ButtonPushedFcn', @(s,e)app.onBtnExport(e));
            app.BtnParaView = uibutton(app.GridExport, 'Text', '🚀 ParaView', 'FontSize', 14, 'FontWeight', 'bold', 'Enable', 'off', 'ButtonPushedFcn', @(s,e)app.onOpenParaView(e));
            
            % Right Workspace
            app.WorkPanel = uipanel(app.MainLayout, 'BorderType', 'none');
            app.WorkGrid = uigridlayout(app.WorkPanel, [2 1]); app.WorkGrid.RowHeight={'1x', 220}; app.WorkGrid.Padding=[0 0 0 0]; app.WorkGrid.RowSpacing=5;
            
            app.ViewContainer = uipanel(app.WorkGrid, 'BorderType', 'line', 'BorderColor', [0.6 0.6 0.6]);
            app.ViewLayout = uigridlayout(app.ViewContainer, [2 1]); 
            % [调整] 工具栏高度由 30 增加到 40
            app.ViewLayout.RowHeight={40, '1x'}; 
            app.ViewLayout.Padding=[0 0 0 0]; app.ViewLayout.RowSpacing=0;
            
            app.ToolbarPanel = uipanel(app.ViewLayout, 'BorderType', 'none');
            app.ToolbarGrid = uigridlayout(app.ToolbarPanel, [1 6]);
            app.ToolbarGrid.ColumnWidth={100, 100, 100, 100, '1x', 110}; app.ToolbarGrid.Padding=[2 2 2 2];
            
            % [调整] 工具栏增加图标
            app.BtnViewFit = uibutton(app.ToolbarGrid, 'Text', '👀 复位视图', 'FontWeight', 'bold', 'ButtonPushedFcn', @(s,e)app.onViewFit(e));
            app.BtnShowMesh = uibutton(app.ToolbarGrid, 'Text', '🕸️ 显示网格', 'FontWeight', 'bold', 'ButtonPushedFcn', @(s,e)app.onToggleMesh(e));
            app.BtnTrans = uibutton(app.ToolbarGrid, 'Text', '🧊 透明模式', 'FontWeight', 'bold', 'ButtonPushedFcn', @(s,e)app.onToggleTrans(e));
            app.BtnSnap = uibutton(app.ToolbarGrid, 'Text', '📷 保存截图', 'FontWeight', 'bold', 'ButtonPushedFcn', @(s,e)app.onSnapShot(e));
            
            app.UIAxes = uiaxes(app.ViewLayout, 'BackgroundColor', [0.1 0.15 0.2], 'Interactions', []);
            app.UIAxes.Box='on';
            
            app.LogPanel = uipanel(app.WorkGrid);
            app.LogGrid = uigridlayout(app.LogPanel, [2 1]); app.LogGrid.RowHeight={25,'1x'}; app.LogGrid.Padding=[0 0 0 0]; app.LogGrid.RowSpacing=0;
            app.LogHeader = uilabel(app.LogGrid, 'Text', ' 运行日志');
            app.LogText = uihtml(app.LogGrid);
            
            app.startupFcn();
        end
        
        function p = createGroup(~, parent, row), p = uipanel(parent); p.Layout.Row = row; end
        function l = createTitle(~, parent, text)
            l = uilabel(parent, 'Text', text, 'Position', [10 parent.Position(4)-20 200 15], 'FontWeight', 'bold', 'FontColor', [0 0.45 0.75]);
            uipanel(parent, 'Position', [0 parent.Position(4)-22 1000 1], 'BackgroundColor', [0.85 0.85 0.85], 'BorderType', 'none');
        end
    end
end
function out = ifelse(c, t, f), if c, out=t; else, out=f; end; end