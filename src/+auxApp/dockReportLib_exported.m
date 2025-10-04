classdef dockReportLib_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        GridLayout            matlab.ui.container.GridLayout
        Document              matlab.ui.container.GridLayout
        eFiscalizaLabel       matlab.ui.control.Label
        eFiscalizaPanel       matlab.ui.container.Panel
        eFiscalizaGrid        matlab.ui.container.GridLayout
        reportIssue           matlab.ui.control.NumericEditField
        reportIssueLabel      matlab.ui.control.Label
        reportUnit            matlab.ui.control.DropDown
        reportUnitLabel       matlab.ui.control.Label
        reportSystem          matlab.ui.control.DropDown
        reportSystemLabel     matlab.ui.control.Label
        reportLabel           matlab.ui.control.Label
        reportPanel           matlab.ui.container.Panel
        reportGrid            matlab.ui.container.GridLayout
        reportVersion         matlab.ui.control.DropDown
        reportVersionLabel    matlab.ui.control.Label
        reportModelName       matlab.ui.control.DropDown
        reportModelNameLabel  matlab.ui.control.Label
        btnOK                 matlab.ui.control.Button
        btnClose              matlab.ui.control.Image
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        Container
        isDocked = true

        mainApp
        projectData
        inputArgs
    end
    
    
    methods (Access = private)
        %-----------------------------------------------------------------%
        function updatePanel(app, context)
            % Inicialização do projectData:
            if isempty(app.projectData.modules.(context).ui.system) && ~isequal(app.projectData.modules.(context).ui.system, app.mainApp.General.Report.system)
                app.projectData.modules.(context).ui.system = app.mainApp.General.Report.system;
            end
            
            if isempty(app.projectData.modules.(context).ui.unit)   && ~isequal(app.projectData.modules.(context).ui.unit,   app.mainApp.General.Report.unit)
                app.projectData.modules.(context).ui.unit   = app.mainApp.General.Report.unit;
            end

            % Atualiza painel:
            if ~isdeployed()
                app.reportSystem.Items = {'eFiscaliza', 'eFiscaliza TS', 'eFiscaliza HM', 'eFiscaliza DS'};
            end
            app.reportSystem.Value     = app.projectData.modules.(context).ui.system;

            set(app.reportUnit, 'Items', app.mainApp.General.eFiscaliza.defaultValues.unit, ...
                                'Value', app.projectData.modules.(context).ui.unit)
            app.reportIssue.Value      = app.projectData.modules.(context).ui.issue;
            
            set(app.reportModelName, 'Items', app.projectData.modules.(context).ui.templates, ...
                                     'Value', app.projectData.modules.(context).ui.reportModel)
            app.reportVersion.Value    = app.projectData.modules.(context).ui.reportVersion;

            % Estado do botão:
            app.btnOK.Enable = ~isempty(app.reportUnit.Value)                               && ... % unit
                               (app.reportIssue.Value > 0) && ~isinf(app.reportIssue.Value) && ... % issue
                               ~isempty(app.reportModelName.Value);                                % reportModel

            if app.btnOK.Enable
                focus(app.btnOK)
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, context, indexes)
            
            app.mainApp     = mainApp;
            app.projectData = app.mainApp.projectData;            
            app.inputArgs   = struct('context', context, 'indexes', indexes);

            updatePanel(app, context)
            
        end

        % Callback function: UIFigure, btnClose
        function closeFcn(app, event)
            
            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcn', context)

            delete(app)
            
        end

        % Value changed function: reportIssue, reportModelName, 
        % ...and 3 other components
        function checkValues(app, event)

            context = app.inputArgs.context;

            switch event.Source
                case app.reportSystem;    fieldName = 'system';
                case app.reportUnit;      fieldName = 'unit';
                case app.reportIssue;     fieldName = 'issue';
                case app.reportModelName; fieldName = 'reportModel';
                case app.reportVersion;   fieldName = 'reportVersion';
            end
            updateUiInfo(app.projectData, context, fieldName, event.Value)
            updatePanel(app, context)
            
        end

        % Button pushed function: btnOK
        function btnOKButtonPushed(app, event)
            
            context = app.inputArgs.context;
            indexes = app.inputArgs.indexes;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'reportUserConfirmation', context, indexes)
            closeFcn(app)

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
                app.UIFigure.Position = [100 100 460 308];
                app.UIFigure.Name = 'monitorSPED';
                app.UIFigure.Icon = 'icon_48.png';
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
            app.Document.RowHeight = {17, 100, 22, 70, 1, 22};
            app.Document.RowSpacing = 5;
            app.Document.Layout.Row = 2;
            app.Document.Layout.Column = [1 2];
            app.Document.BackgroundColor = [1 1 1];

            % Create btnOK
            app.btnOK = uibutton(app.Document, 'push');
            app.btnOK.ButtonPushedFcn = createCallbackFcn(app, @btnOKButtonPushed, true);
            app.btnOK.Tag = 'OK';
            app.btnOK.IconAlignment = 'right';
            app.btnOK.BackgroundColor = [0.9804 0.9804 0.9804];
            app.btnOK.Enable = 'off';
            app.btnOK.Layout.Row = 6;
            app.btnOK.Layout.Column = 2;
            app.btnOK.Text = 'OK';

            % Create reportPanel
            app.reportPanel = uipanel(app.Document);
            app.reportPanel.BackgroundColor = [1 1 1];
            app.reportPanel.Layout.Row = 4;
            app.reportPanel.Layout.Column = [1 2];

            % Create reportGrid
            app.reportGrid = uigridlayout(app.reportPanel);
            app.reportGrid.ColumnWidth = {'1x', 150};
            app.reportGrid.RowHeight = {22, 22};
            app.reportGrid.RowSpacing = 5;
            app.reportGrid.BackgroundColor = [1 1 1];

            % Create reportModelNameLabel
            app.reportModelNameLabel = uilabel(app.reportGrid);
            app.reportModelNameLabel.FontSize = 11;
            app.reportModelNameLabel.Layout.Row = 1;
            app.reportModelNameLabel.Layout.Column = 1;
            app.reportModelNameLabel.Text = 'Modelo (.json):';

            % Create reportModelName
            app.reportModelName = uidropdown(app.reportGrid);
            app.reportModelName.Items = {''};
            app.reportModelName.ValueChangedFcn = createCallbackFcn(app, @checkValues, true);
            app.reportModelName.FontSize = 11;
            app.reportModelName.BackgroundColor = [1 1 1];
            app.reportModelName.Layout.Row = 1;
            app.reportModelName.Layout.Column = 2;
            app.reportModelName.Value = '';

            % Create reportVersionLabel
            app.reportVersionLabel = uilabel(app.reportGrid);
            app.reportVersionLabel.WordWrap = 'on';
            app.reportVersionLabel.FontSize = 11;
            app.reportVersionLabel.Layout.Row = 2;
            app.reportVersionLabel.Layout.Column = 1;
            app.reportVersionLabel.Text = 'Versão do relatório:';

            % Create reportVersion
            app.reportVersion = uidropdown(app.reportGrid);
            app.reportVersion.Items = {'Preliminar', 'Definitiva'};
            app.reportVersion.ValueChangedFcn = createCallbackFcn(app, @checkValues, true);
            app.reportVersion.FontSize = 11;
            app.reportVersion.BackgroundColor = [1 1 1];
            app.reportVersion.Layout.Row = 2;
            app.reportVersion.Layout.Column = 2;
            app.reportVersion.Value = 'Preliminar';

            % Create reportLabel
            app.reportLabel = uilabel(app.Document);
            app.reportLabel.VerticalAlignment = 'bottom';
            app.reportLabel.FontSize = 10;
            app.reportLabel.Layout.Row = 3;
            app.reportLabel.Layout.Column = 1;
            app.reportLabel.Text = 'RELATÓRIO';

            % Create eFiscalizaPanel
            app.eFiscalizaPanel = uipanel(app.Document);
            app.eFiscalizaPanel.Layout.Row = 2;
            app.eFiscalizaPanel.Layout.Column = [1 2];

            % Create eFiscalizaGrid
            app.eFiscalizaGrid = uigridlayout(app.eFiscalizaPanel);
            app.eFiscalizaGrid.ColumnWidth = {'1x', 150};
            app.eFiscalizaGrid.RowHeight = {22, 22, 22};
            app.eFiscalizaGrid.RowSpacing = 5;
            app.eFiscalizaGrid.BackgroundColor = [1 1 1];

            % Create reportSystemLabel
            app.reportSystemLabel = uilabel(app.eFiscalizaGrid);
            app.reportSystemLabel.FontSize = 11;
            app.reportSystemLabel.Layout.Row = 1;
            app.reportSystemLabel.Layout.Column = 1;
            app.reportSystemLabel.Text = 'Ambiente do sistema de gestão à fiscalização:';

            % Create reportSystem
            app.reportSystem = uidropdown(app.eFiscalizaGrid);
            app.reportSystem.Items = {'eFiscaliza', 'eFiscaliza TS'};
            app.reportSystem.ValueChangedFcn = createCallbackFcn(app, @checkValues, true);
            app.reportSystem.FontSize = 11;
            app.reportSystem.BackgroundColor = [1 1 1];
            app.reportSystem.Layout.Row = 1;
            app.reportSystem.Layout.Column = 2;
            app.reportSystem.Value = 'eFiscaliza';

            % Create reportUnitLabel
            app.reportUnitLabel = uilabel(app.eFiscalizaGrid);
            app.reportUnitLabel.FontSize = 11;
            app.reportUnitLabel.Layout.Row = 2;
            app.reportUnitLabel.Layout.Column = 1;
            app.reportUnitLabel.Text = 'Unidade responsável pela fiscalização:';

            % Create reportUnit
            app.reportUnit = uidropdown(app.eFiscalizaGrid);
            app.reportUnit.Items = {};
            app.reportUnit.ValueChangedFcn = createCallbackFcn(app, @checkValues, true);
            app.reportUnit.FontSize = 11;
            app.reportUnit.BackgroundColor = [1 1 1];
            app.reportUnit.Layout.Row = 2;
            app.reportUnit.Layout.Column = 2;
            app.reportUnit.Value = {};

            % Create reportIssueLabel
            app.reportIssueLabel = uilabel(app.eFiscalizaGrid);
            app.reportIssueLabel.FontSize = 11;
            app.reportIssueLabel.Layout.Row = 3;
            app.reportIssueLabel.Layout.Column = 1;
            app.reportIssueLabel.Text = 'Atividade de inspeção (# ID):';

            % Create reportIssue
            app.reportIssue = uieditfield(app.eFiscalizaGrid, 'numeric');
            app.reportIssue.Limits = [-1 Inf];
            app.reportIssue.RoundFractionalValues = 'on';
            app.reportIssue.ValueDisplayFormat = '%d';
            app.reportIssue.ValueChangedFcn = createCallbackFcn(app, @checkValues, true);
            app.reportIssue.FontSize = 11;
            app.reportIssue.FontColor = [0.149 0.149 0.149];
            app.reportIssue.Layout.Row = 3;
            app.reportIssue.Layout.Column = 2;
            app.reportIssue.Value = -1;

            % Create eFiscalizaLabel
            app.eFiscalizaLabel = uilabel(app.Document);
            app.eFiscalizaLabel.VerticalAlignment = 'bottom';
            app.eFiscalizaLabel.FontSize = 10;
            app.eFiscalizaLabel.Layout.Row = 1;
            app.eFiscalizaLabel.Layout.Column = 1;
            app.eFiscalizaLabel.Text = 'eFISCALIZA';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = dockReportLib_exported(Container, varargin)

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
