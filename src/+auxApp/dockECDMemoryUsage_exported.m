classdef dockECDMemoryUsage_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure    matlab.ui.Figure
        GridLayout  matlab.ui.container.GridLayout
        Document    matlab.ui.container.GridLayout
        UITable     matlab.ui.control.Table
        TreeLabel   matlab.ui.control.Label
        btnClose    matlab.ui.control.Image
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        Role = 'secondaryDockApp'
    end


    properties (Access = public)
        %-----------------------------------------------------------------%
        Container
        isDocked = true        
        mainApp
        callingApp
    end


    properties (Access = private)
        %-----------------------------------------------------------------%
        inputArgs
        appHandleNameInBase
    end


    methods
        %-----------------------------------------------------------------%
        function deleteSelectedTables(app)
            selectedRow = app.UITable.Selection;

            if ~isempty(selectedRow)
                tableId = app.UITable.Data.("REGISTRO"){selectedRow};
                
                if ~ismember(tableId, app.mainApp.General.context.ECD.cacheTables)
                    context = app.inputArgs.context;
                    index = app.inputArgs.index;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'onCacheCleanup', context, index, {tableId})

                    updateTable(app, index)
                end
            end
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function updateTable(app, index)
            t = table( ...
                'Size', [0, 3], ...
                'VariableNames', {'REGISTRO', 'TAMANHO', 'OPERAÇÃO'}, ...
                'VariableTypes', {'cell', 'cell', 'cell'} ...
            );

            tableIdList = sort(extractAfter(fieldnames(app.mainApp.ecdObj(index).Table), 'x'));

            for ii = 1:numel(tableIdList)
                tableId   = tableIdList{ii};
                tableData = app.mainApp.ecdObj(index).Table.(['x' tableId]);
                tableInfo = whos('tableData');

                if ismember(tableId, app.mainApp.General.context.ECD.cacheTables)
                    deletableRowsText = '🔒︎';
                else
                    deletableRowsText = sprintf('<a href="matlab:evalin(''base'', ''deleteSelectedTables(%s)'')">❌</a>', app.appHandleNameInBase);
                end

                t(end+1, :) = {tableId, textFormatGUI.bytes2human(tableInfo.bytes), deletableRowsText};
            end

            app.UITable.Data = t;
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, callingApp, context, index)
            
            try
                appEngine.boot(app, app.Role, mainApp, callingApp)

                app.inputArgs = struct('context', context, 'index', index);

                % Registra handle deste app no workspace "base", o que possibilita 
                % excluir registros de tabelas por meio de cliques na uitable.
                app.appHandleNameInBase = ui.Table.exportAppHandleToBaseWorkspace(app);

                % Customiza uitable, atualizando-se em seguida.
                addStyle(app.UITable, uistyle("Interpreter", "html"));
                addStyle(app.UITable, uistyle("HorizontalAlignment", "left"),   "column", 1);
                addStyle(app.UITable, uistyle("HorizontalAlignment", "right"),  "column", 2);
                addStyle(app.UITable, uistyle("HorizontalAlignment", "center"), "column", 3);
                
                updateTable(app, index)
                
            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME), 'CloseFcn', @(~,~)closeFcn(app));
            end
            
        end

        % Callback function: UIFigure, btnClose
        function closeFcn(app, event)
            
            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcnCallFromPopupApp', context, 'auxApp.dockECDMemoryUsage')
            ui.Table.deleteAppHandleFromBaseWorkspace(app.appHandleNameInBase)
            
            delete(app)
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app, Container)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            if isempty(Container)
                app.UIFigure = uifigure('Visible', 'off');
                app.UIFigure.AutoResizeChildren = 'off';
                app.UIFigure.Position = [92 92 460 580];
                app.UIFigure.Name = 'monitorSPED';
                app.UIFigure.Icon = 'icon_16.png';
                app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @closeFcn, true);

                app.Container = app.UIFigure;

            else
                if ~isempty(Container.Children)
                    delete(Container.Children)
                end

                app.UIFigure  = ancestor(Container, 'figure');
                app.Container = Container;
                if ~isprop(Container, 'RunningAppInstance')
                    addprop(app.Container, 'RunningAppInstance');
                end
                app.Container.RunningAppInstance = app;
                app.isDocked  = true;
            end

            % Create GridLayout
            app.GridLayout = uigridlayout(app.Container);
            app.GridLayout.ColumnWidth = {'1x', 30};
            app.GridLayout.RowHeight = {30, '1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [0.902 0.902 0.902];

            % Create btnClose
            app.btnClose = uiimage(app.GridLayout);
            app.btnClose.ScaleMethod = 'none';
            app.btnClose.ImageClickedFcn = createCallbackFcn(app, @closeFcn, true);
            app.btnClose.Tag = 'Close';
            app.btnClose.Layout.Row = 1;
            app.btnClose.Layout.Column = 2;
            app.btnClose.ImageSource = 'Delete_12SVG.svg';

            % Create Document
            app.Document = uigridlayout(app.GridLayout);
            app.Document.ColumnWidth = {'1x'};
            app.Document.RowHeight = {17, '1x'};
            app.Document.RowSpacing = 5;
            app.Document.Layout.Row = 2;
            app.Document.Layout.Column = [1 2];
            app.Document.BackgroundColor = [1 1 1];

            % Create TreeLabel
            app.TreeLabel = uilabel(app.Document);
            app.TreeLabel.VerticalAlignment = 'bottom';
            app.TreeLabel.FontSize = 10;
            app.TreeLabel.Layout.Row = 1;
            app.TreeLabel.Layout.Column = 1;
            app.TreeLabel.Text = 'ESPAÇO EM MEMÓRIA OCUPADO POR REGISTROS LIDOS OU CRIADOS';

            % Create UITable
            app.UITable = uitable(app.Document);
            app.UITable.ColumnName = {'REGISTRO'; ''; ''};
            app.UITable.ColumnWidth = {'1x', 110, 60};
            app.UITable.RowName = {};
            app.UITable.SelectionType = 'row';
            app.UITable.Multiselect = 'off';
            app.UITable.Layout.Row = 2;
            app.UITable.Layout.Column = 1;
            app.UITable.FontSize = 11;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = dockECDMemoryUsage_exported(Container, varargin)

            % Create UIFigure and components
            createComponents(app, Container)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            if app.isDocked
                delete(app.Container.Children)
            else
                delete(app.UIFigure)
            end
        end
    end
end
