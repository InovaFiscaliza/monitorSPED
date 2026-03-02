classdef dockECDExport_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        GridLayout            matlab.ui.container.GridLayout
        btnOK                 matlab.ui.control.Button
        Tree                  matlab.ui.container.CheckBoxTree
        GeneralAspects        matlab.ui.container.TreeNode
        x0000                 matlab.ui.container.TreeNode
        xI030                 matlab.ui.container.TreeNode
        x9900                 matlab.ui.container.TreeNode
        AccountBook           matlab.ui.container.TreeNode
        xI050_I051_I052       matlab.ui.container.TreeNode
        AccountDescription    matlab.ui.container.TreeNode
        AccountSummary        matlab.ui.container.TreeNode
        xI200_I250            matlab.ui.container.TreeNode
        SummaryGeneral        matlab.ui.container.TreeNode
        SummaryResults        matlab.ui.container.TreeNode
        ApuracaoGeral         matlab.ui.container.TreeNode
        ApuracaoInterconexao  matlab.ui.container.TreeNode
        RTFFiles              matlab.ui.container.TreeNode
        eFiscalizaLabel       matlab.ui.control.Label
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
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, callingApp, context, index)
            
            try
                appEngine.boot(app, app.Role, mainApp, callingApp)

                app.inputArgs = struct('context', context, 'index', index);    
                expand(app.Tree, 'all')
                
            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME), 'CloseFcn', @(~,~)closeFcn(app));
            end
            
        end

        % Close request function: UIFigure
        function closeFcn(app, event)
            
            delete(app)
            
        end

        % Button pushed function: btnOK
        function btnOKButtonPushed(app, event)
            
            if isempty(app.Tree.CheckedNodes)
                app.btnOK.Enable = "off";
                return
            end

            context = app.inputArgs.context;
            index = app.inputArgs.index;

            tableIdFields = {app.Tree.CheckedNodes.Tag};
            tableIdFields(cellfun(@(x) isempty(x), tableIdFields)) = [];
            tableIdFields = [sort(tableIdFields(startsWith(tableIdFields, 'x'))), sort(tableIdFields(startsWith(tableIdFields, 'm')))];

            ipcMainMatlabCallsHandler(app.mainApp, app, 'onExportECD', context, index, tableIdFields)

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
                app.UIFigure.Position = [92 92 460 419];
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
            app.GridLayout.ColumnWidth = {'1x', 90};
            app.GridLayout.RowHeight = {17, '1x', 1, 22};
            app.GridLayout.RowSpacing = 5;
            app.GridLayout.Padding = [20 20 20 20];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create eFiscalizaLabel
            app.eFiscalizaLabel = uilabel(app.GridLayout);
            app.eFiscalizaLabel.VerticalAlignment = 'bottom';
            app.eFiscalizaLabel.FontSize = 10;
            app.eFiscalizaLabel.Layout.Row = 1;
            app.eFiscalizaLabel.Layout.Column = 1;
            app.eFiscalizaLabel.Text = 'INFORMAÇÃO A EXPORTAR';

            % Create Tree
            app.Tree = uitree(app.GridLayout, 'checkbox');
            app.Tree.FontSize = 11;
            app.Tree.Layout.Row = 2;
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

            % Create xI050_I051_I052
            app.xI050_I051_I052 = uitreenode(app.AccountBook);
            app.xI050_I051_I052.Tag = 'xI050_I051_I052';
            app.xI050_I051_I052.Text = 'I050_I051_I052';

            % Create AccountDescription
            app.AccountDescription = uitreenode(app.AccountBook);
            app.AccountDescription.Tag = 'x_CONTAS_DESCRICAO';
            app.AccountDescription.Text = 'Descrição completa';

            % Create AccountSummary
            app.AccountSummary = uitreenode(app.Tree);
            app.AccountSummary.Text = 'Balancetes e tabela de apuração';

            % Create xI200_I250
            app.xI200_I250 = uitreenode(app.AccountSummary);
            app.xI200_I250.Tag = 'xI200_I250';
            app.xI200_I250.Text = 'I200_I250';

            % Create SummaryGeneral
            app.SummaryGeneral = uitreenode(app.AccountSummary);
            app.SummaryGeneral.Tag = 'x_BALANCETE_GERAL';
            app.SummaryGeneral.Text = 'Balancete Geral';

            % Create SummaryResults
            app.SummaryResults = uitreenode(app.AccountSummary);
            app.SummaryResults.Tag = 'x_BALANCETE_RESULTADO';
            app.SummaryResults.Text = 'Balancete Resultado';

            % Create ApuracaoGeral
            app.ApuracaoGeral = uitreenode(app.AccountSummary);
            app.ApuracaoGeral.Tag = 'x_APURACAO_GERAL';
            app.ApuracaoGeral.Text = 'Apuração Geral';

            % Create ApuracaoInterconexao
            app.ApuracaoInterconexao = uitreenode(app.AccountSummary);
            app.ApuracaoInterconexao.Tag = 'x_APURACAO_INTERCONEXAO';
            app.ApuracaoInterconexao.Text = 'Apuração Interconexão';

            % Create RTFFiles
            app.RTFFiles = uitreenode(app.Tree);
            app.RTFFiles.Tag = 'xJ800|xJ801';
            app.RTFFiles.Text = 'Arquivos anexos .rtf (J800 e J801)';

            % Assign Checked Nodes
            app.Tree.CheckedNodes = [app.x0000, app.xI030, app.x9900, app.AccountDescription, app.GeneralAspects];
            % Assign Checked Nodes
            app.Tree.CheckedNodesChangedFcn = createCallbackFcn(app, @TreeCheckedNodesChanged, true);

            % Create btnOK
            app.btnOK = uibutton(app.GridLayout, 'push');
            app.btnOK.ButtonPushedFcn = createCallbackFcn(app, @btnOKButtonPushed, true);
            app.btnOK.Tag = 'OK';
            app.btnOK.IconAlignment = 'right';
            app.btnOK.BackgroundColor = [0.9804 0.9804 0.9804];
            app.btnOK.Layout.Row = 4;
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
