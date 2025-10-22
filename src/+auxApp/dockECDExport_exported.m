classdef dockECDExport_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        GridLayout          matlab.ui.container.GridLayout
        Document            matlab.ui.container.GridLayout
        btnOK               matlab.ui.control.Button
        Tree                matlab.ui.container.CheckBoxTree
        GeneralAspects      matlab.ui.container.TreeNode
        x0000               matlab.ui.container.TreeNode
        xI030               matlab.ui.container.TreeNode
        x9900               matlab.ui.container.TreeNode
        AccountBook         matlab.ui.container.TreeNode
        xI050               matlab.ui.container.TreeNode
        AccountDescription  matlab.ui.container.TreeNode
        AccountSummary      matlab.ui.container.TreeNode
        xI200_I250          matlab.ui.container.TreeNode
        SummaryGeneral      matlab.ui.container.TreeNode
        SummaryResults      matlab.ui.container.TreeNode
        RTFFiles            matlab.ui.container.TreeNode
        eFiscalizaLabel     matlab.ui.control.Label
        btnClose            matlab.ui.control.Image
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        Container
        isDocked = true

        mainApp
        projectData
        inputArgs
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, context, indexes)
            
            app.mainApp     = mainApp;
            app.projectData = app.mainApp.projectData;            
            app.inputArgs   = struct('context', context, 'indexes', indexes);

            expand(app.Tree, 'all')
            
        end

        % Callback function: UIFigure, btnClose
        function closeFcn(app, event)
            
            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcn', context)

            delete(app)
            
        end

        % Button pushed function: btnOK
        function btnOKButtonPushed(app, event)
            
            if isempty(app.Tree.CheckedNodes)
                app.btnOK.Enable = "off";
                return
            end

            context = app.inputArgs.context;
            indexes = app.inputArgs.indexes;

            tableIdFields = {app.Tree.CheckedNodes.Tag};
            tableIdFields(cellfun(@(x) isempty(x), tableIdFields)) = [];
            tableIdFields = [sort(tableIdFields(startsWith(tableIdFields, 'x'))), sort(tableIdFields(startsWith(tableIdFields, 'm')))];

            ipcMainMatlabCallsHandler(app.mainApp, app, 'exportECD', context, indexes, tableIdFields)

        end

        % Callback function: Tree
        function TreeCheckedNodesChanged(app, event)
            
            app.btnOK.Enable = ~isempty(app.Tree.CheckedNodes);
            
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
                app.UIFigure.Position = [92 92 460 404];
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
            app.Document.ColumnWidth = {'1x', 90};
            app.Document.RowHeight = {17, '1x', 22, 70, 1, 22};
            app.Document.RowSpacing = 5;
            app.Document.Layout.Row = 2;
            app.Document.Layout.Column = [1 2];
            app.Document.BackgroundColor = [1 1 1];

            % Create eFiscalizaLabel
            app.eFiscalizaLabel = uilabel(app.Document);
            app.eFiscalizaLabel.VerticalAlignment = 'bottom';
            app.eFiscalizaLabel.FontSize = 10;
            app.eFiscalizaLabel.Layout.Row = 1;
            app.eFiscalizaLabel.Layout.Column = 1;
            app.eFiscalizaLabel.Text = 'INFORMAÇÃO A EXPORTAR';

            % Create Tree
            app.Tree = uitree(app.Document, 'checkbox');
            app.Tree.FontSize = 11;
            app.Tree.Layout.Row = [2 4];
            app.Tree.Layout.Column = [1 2];

            % Create GeneralAspects
            app.GeneralAspects = uitreenode(app.Tree);
            app.GeneralAspects.Text = 'Aspectos gerais';

            % Create x0000
            app.x0000 = uitreenode(app.GeneralAspects);
            app.x0000.Tag = 'x0000';
            app.x0000.Text = '0000';

            % Create xI030
            app.xI030 = uitreenode(app.GeneralAspects);
            app.xI030.Tag = 'xI030';
            app.xI030.Text = 'I030';

            % Create x9900
            app.x9900 = uitreenode(app.GeneralAspects);
            app.x9900.Tag = 'x9900';
            app.x9900.Text = '9900';

            % Create AccountBook
            app.AccountBook = uitreenode(app.Tree);
            app.AccountBook.Text = 'Plano de contas';

            % Create xI050
            app.xI050 = uitreenode(app.AccountBook);
            app.xI050.Tag = 'xI050';
            app.xI050.Text = 'I050';

            % Create AccountDescription
            app.AccountDescription = uitreenode(app.AccountBook);
            app.AccountDescription.Tag = 'mCONTAS_DESCRICAO';
            app.AccountDescription.Text = 'Descrição completa';

            % Create AccountSummary
            app.AccountSummary = uitreenode(app.Tree);
            app.AccountSummary.Text = 'Balancetes';

            % Create xI200_I250
            app.xI200_I250 = uitreenode(app.AccountSummary);
            app.xI200_I250.Tag = 'mI200_I250';
            app.xI200_I250.Text = 'I200-I250';

            % Create SummaryGeneral
            app.SummaryGeneral = uitreenode(app.AccountSummary);
            app.SummaryGeneral.Tag = 'mBALANCETE_GERAL';
            app.SummaryGeneral.Text = 'Geral';

            % Create SummaryResults
            app.SummaryResults = uitreenode(app.AccountSummary);
            app.SummaryResults.Tag = 'mBALANCETE_RESULTADO';
            app.SummaryResults.Text = 'Resultados';

            % Create RTFFiles
            app.RTFFiles = uitreenode(app.Tree);
            app.RTFFiles.Tag = 'xJ800|xJ801';
            app.RTFFiles.Text = 'Arquivos anexos .rtf (J800 e J801)';

            % Assign Checked Nodes
            app.Tree.CheckedNodes = [app.x0000, app.xI030, app.xI050, app.AccountDescription, app.SummaryResults, app.AccountBook];
            % Assign Checked Nodes
            app.Tree.CheckedNodesChangedFcn = createCallbackFcn(app, @TreeCheckedNodesChanged, true);

            % Create btnOK
            app.btnOK = uibutton(app.Document, 'push');
            app.btnOK.ButtonPushedFcn = createCallbackFcn(app, @btnOKButtonPushed, true);
            app.btnOK.Tag = 'OK';
            app.btnOK.IconAlignment = 'right';
            app.btnOK.BackgroundColor = [0.9804 0.9804 0.9804];
            app.btnOK.Layout.Row = 6;
            app.btnOK.Layout.Column = 2;
            app.btnOK.Text = 'OK';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = dockECDExport_exported(Container, varargin)

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
