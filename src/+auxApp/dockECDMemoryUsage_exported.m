classdef dockECDMemoryUsage_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure       matlab.ui.Figure
        GridLayout     matlab.ui.container.GridLayout
        Document       matlab.ui.container.GridLayout
        Tree           matlab.ui.container.Tree
        essentialNode  matlab.ui.container.TreeNode
        cacheNode      matlab.ui.container.TreeNode
        TreeLabel      matlab.ui.control.Label
        btnClose       matlab.ui.control.Image
        ContextMenu    matlab.ui.container.ContextMenu
        Delete         matlab.ui.container.Menu
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        Container
        isDocked = true

        mainApp
        callingApp
        inputArgs
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function TreeBuilding(app, index)
            if ~isempty(app.essentialNode.Children)
                delete(app.essentialNode.Children)
            end

            if ~isempty(app.cacheNode.Children)
                delete(app.cacheNode.Children)
            end

            tableIdList = sort(extractAfter(fieldnames(app.mainApp.ecdObj(index).Table), 'x'));

            for ii = 1:numel(tableIdList)
                tableId   = tableIdList{ii};
                tableData = app.mainApp.ecdObj(index).Table.(['x' tableId]);
                tableInfo = whos('tableData');

                if ismember(tableId, app.mainApp.General.ECD.cacheTables)
                    parentNode = app.essentialNode;
                else
                    parentNode = app.cacheNode;
                end

                uitreenode( ...
                    parentNode, ...
                    'Text', sprintf('%s - %s', tableId, textFormatGUI.bytes2human(tableInfo.bytes)), ...
                    'NodeData', tableId ...
                );
            end

            expand(app.Tree, 'all')
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, callingApp, context, index)
            
            app.mainApp    = mainApp;       
            app.callingApp = callingApp;
            app.inputArgs  = struct('context', context, 'index', index);

            TreeBuilding(app, index)
            
        end

        % Callback function: UIFigure, btnClose
        function closeFcn(app, event)
            
            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcn', context)

            delete(app)
            
        end

        % Menu selected function: Delete
        function DeleteSelected(app, event)
            
            selectedNodes = app.Tree.SelectedNodes;

            if ~isempty(selectedNodes)
                deletableTables = intersect(selectedNodes, app.cacheNode.Children);

                if ~isempty(deletableTables)
                    context = app.inputArgs.context;
                    index = app.inputArgs.index;
                    tableIdList = {deletableTables.NodeData};

                    ipcMainMatlabCallsHandler(app.mainApp, app, 'freeMemory', context, index, tableIdList)
                    TreeBuilding(app, index)
                end
            end

        end

        % Selection changed function: Tree
        function TreeSelectionChanged(app, event)
            
            app.Delete.Enable = ~isempty(app.Tree.SelectedNodes);
            
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
            app.TreeLabel.Text = 'TAMANHO DAS TABELAS';

            % Create Tree
            app.Tree = uitree(app.Document);
            app.Tree.Multiselect = 'on';
            app.Tree.SelectionChangedFcn = createCallbackFcn(app, @TreeSelectionChanged, true);
            app.Tree.FontSize = 11;
            app.Tree.Layout.Row = 2;
            app.Tree.Layout.Column = 1;

            % Create essentialNode
            app.essentialNode = uitreenode(app.Tree);
            app.essentialNode.Icon = 'Lock_18Gray.png';
            app.essentialNode.Text = 'ESSENCIAIS';

            % Create cacheNode
            app.cacheNode = uitreenode(app.Tree);
            app.cacheNode.Icon = 'Delete_32Red.png';
            app.cacheNode.Text = 'SOB DEMANDA (em cache)';

            % Create ContextMenu
            app.ContextMenu = uicontextmenu(app.UIFigure);
            app.ContextMenu.Tag = 'auxApp.dockECDMemoryUsage';

            % Create Delete
            app.Delete = uimenu(app.ContextMenu);
            app.Delete.MenuSelectedFcn = createCallbackFcn(app, @DeleteSelected, true);
            app.Delete.Enable = 'off';
            app.Delete.Text = '❌ Excluir';
            
            % Assign app.ContextMenu
            app.Tree.ContextMenu = app.ContextMenu;

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
