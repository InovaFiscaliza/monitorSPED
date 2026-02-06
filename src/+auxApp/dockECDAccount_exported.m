classdef dockECDAccount_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure           matlab.ui.Figure
        GridLayout         matlab.ui.container.GridLayout
        Document           matlab.ui.container.GridLayout
        accountInfo        matlab.ui.control.Label
        NextSelection      matlab.ui.control.Image
        PreviousSelection  matlab.ui.control.Image
        plotPanel          matlab.ui.container.Panel
        totalValue         matlab.ui.control.Label
        freenote           matlab.ui.control.TextArea
        freenoteLabel      matlab.ui.control.Label
        icmsMonthsPanel    matlab.ui.container.Panel
        icmsMonthsGrid     matlab.ui.container.GridLayout
        icmsMonth12        matlab.ui.control.Spinner
        icmsMonth12Label   matlab.ui.control.Label
        icmsMonth11        matlab.ui.control.Spinner
        icmsMonth11Label   matlab.ui.control.Label
        icmsMonth10        matlab.ui.control.Spinner
        icmsMonth10Label   matlab.ui.control.Label
        icmsMonth9         matlab.ui.control.Spinner
        icmsMonth9Label    matlab.ui.control.Label
        icmsMonth8         matlab.ui.control.Spinner
        icmsMonth8Label    matlab.ui.control.Label
        icmsMonth7         matlab.ui.control.Spinner
        icmsMonth7Label    matlab.ui.control.Label
        icmsMonth6         matlab.ui.control.Spinner
        icmsMonth6Label    matlab.ui.control.Label
        icmsMonth5         matlab.ui.control.Spinner
        icmsMonth5Label    matlab.ui.control.Label
        icmsMonth4         matlab.ui.control.Spinner
        icmsMonth4Label    matlab.ui.control.Label
        icmsMonth3         matlab.ui.control.Spinner
        icmsMonth3Label    matlab.ui.control.Label
        icmsMonth2         matlab.ui.control.Spinner
        icmsMonth2Label    matlab.ui.control.Label
        icmsMonth1         matlab.ui.control.Spinner
        icmsMonth1Label    matlab.ui.control.Label
        icmsType           matlab.ui.control.DropDown
        icmsTypeLabel      matlab.ui.control.Label
        taxType            matlab.ui.control.DropDown
        taxTypeLabel       matlab.ui.control.Label
        accountList        matlab.ui.control.DropDown
        accountListLabel   matlab.ui.control.Label
        btnClose           matlab.ui.control.Image
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
        jsBackDoor
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        inputArgs
        currentAccount
        UIAxes
    end
    

    methods (Access = private)
        %-----------------------------------------------------------------%
        function applyJSCustomizations(app)
            drawnow

            elToModify = {
                app.accountInfo
            };
            ui.CustomizationBase.getElementsDataTag(elToModify);
    
            try
                ui.TextView.startup(app.jsBackDoor, app.accountInfo, class.Constants.appName);
            catch
            end
        end

        %-----------------------------------------------------------------%
        function accountName = startupLayout(app, index, accountName)
            % Cria o eixo geográfico:
            app.UIAxes = plot.axesCreationController(app.plotPanel);

            % Atualiza lista de contas de resultado:
            app.accountList.Items = app.mainApp.ecdObj(index).Table.x_CONTAS_ANOTACAO.("COD_CTA");
            if ismember(accountName, app.accountList.Items)
                app.accountList.Value = accountName;
            else
                accountName = app.accountList.Value;
            end

            % Tipos de conta:
            app.taxType.Items = app.mainApp.General.context.ECD.accountOptions;
        end

        %-----------------------------------------------------------------%
        function updateLayout(app, index, accountName)
            selectedECD  = app.mainApp.ecdObj(index);
            [accountTable, index, htmlContent] = util.HtmlTextGenerator.AccountInfo(selectedECD, accountName, app.mainApp.General);
            
            % Árvore de descrição da conta:
            % app.accountInfo.Text = htmlContent;
            ui.TextView.setLabelInnerHTMLBypassingText(app.jsBackDoor, app.accountInfo, htmlContent)
            
            % Valores iniciais dos campos passíveis de anotação:
            app.taxType.Value  = char(accountTable.('Apurado?  ✎')(index));
            app.freenote.Value = accountTable.('Observação  ✎'){index};

            switch accountTable.('Alíquota ICMS'){index}
                case '-'
                    app.currentAccount = struct('type', 'n/a', 'rate', 0, 'index', index);
                    icmsTypeItems = {'n/a'};
                otherwise
                    app.currentAccount = jsondecode(accountTable.('Alíquota ICMS'){index});
                    app.currentAccount.index = index;
                    icmsTypeItems = {'auto', 'manual'};
            end
            set(app.icmsType, 'Items', icmsTypeItems, 'Value', app.currentAccount.type)

            updateRatePanelStatus(app, strcmp(app.currentAccount.type, 'manual'))
            updateRatePanelValue(app, app.currentAccount.rate)

            % Plot:
            yLimit = max(abs(accountTable{index, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}})) * 1.1;
            if yLimit == 0
                yLimit = 1;
            end
            app.UIAxes.YLim = [-yLimit, yLimit];            
            app.totalValue.Text = sprintf('R$ %.2f', accountTable{index, 'TOTAL'});

            cla(app.UIAxes)
            plotHandle = bar(app.UIAxes, accountTable{index, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}}, 'FaceColor', '#ffff12', 'LineStyle', 'none');
            plot.datatip.Template(plotHandle, "Value")
            drawnow
        end

        %-----------------------------------------------------------------%
        function rateJsonInfo = createRateJsonInfo(app)
            fileIndex    = app.inputArgs.index;
            selectedECD  = app.mainApp.ecdObj(fileIndex);

            switch app.icmsType.Value
                case 'auto'
                    rateList = selectedECD.GUI.icmsDefaultRate.rate;

                case 'manual'
                    rateList = round([ ...
                        app.icmsMonth1.Value, ...
                        app.icmsMonth2.Value, ...
                        app.icmsMonth3.Value, ...
                        app.icmsMonth4.Value, ...
                        app.icmsMonth5.Value, ...
                        app.icmsMonth6.Value, ...
                        app.icmsMonth7.Value, ...
                        app.icmsMonth8.Value, ...
                        app.icmsMonth9.Value, ...
                        app.icmsMonth10.Value, ...
                        app.icmsMonth11.Value, ...
                        app.icmsMonth12.Value ...
                    ] ./ 100, 3);
        
                    if isscalar(unique(rateList))
                        rateList = rateList(1);
                    end
            end

            rateJsonInfo = struct( ...
                'type', app.icmsType.Value, ...
                'rate', rateList ...
            );
        end

        %-----------------------------------------------------------------%
        function updateRatePanelStatus(app, status)
            hSpinners = findobj(app.icmsMonthsGrid.Children, 'Type', 'uispinner');
            set(hSpinners, 'Enable', status)
        end

        %-----------------------------------------------------------------%
        function updateRatePanelValue(app, value)
            value = 100*value;
            
            if isscalar(value)
                hSpinners = findobj(app.icmsMonthsGrid.Children, 'Type', 'uispinner');
                set(hSpinners, 'Value', value)
            else
                for ii = 1:numel(value)
                    hSpinner = findobj(app.icmsMonthsGrid.Children, 'Type', 'uispinner', 'Tag', num2str(ii));
                    set(hSpinner, 'Value', value(ii))
                end
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, callingApp, context, index, accountName)
            
            try
                appEngine.boot(app, app.Role, mainApp, callingApp)

                applyJSCustomizations(app)
                app.inputArgs = struct('context', context, 'index', index);
                accountName = startupLayout(app, index, accountName);
                updateLayout(app, index, accountName)
                
            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME), 'CloseFcn', @(~,~)closeFcn(app));
            end
            
        end

        % Callback function: UIFigure, btnClose
        function closeFcn(app, event)
            
            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcnCallFromPopupApp', context, 'auxApp.dockECDAccount')

            delete(app)
            
        end

        % Value changed function: accountList
        function accountListValueChanged(app, event)
            
            fileIndex    = app.inputArgs.index;
            updateLayout(app, fileIndex, app.accountList.Value)
            
        end

        % Value changed function: freenote, icmsMonth1, icmsMonth10, 
        % ...and 12 other components
        function parameterValueChanged(app, event)
            
            fileIndex    = app.inputArgs.index;
            selectedECD  = app.mainApp.ecdObj(fileIndex);
            accountIndex = app.currentAccount.index;
            generalSettings = app.mainApp.General;

            switch event.Source
                case app.taxType
                    update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'valueChanged:Apurado?', generalSettings, accountIndex, app.taxType.Value)
                
                case app.icmsType
                    updateRatePanelStatus(app, strcmp(app.icmsType.Value, 'manual'))

                    rateJsonInfo = createRateJsonInfo(app);
                    update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'valueChanged:Alíquota ICMS', generalSettings, accountIndex, jsonencode(rateJsonInfo))

                case {app.icmsMonth1, ...
                      app.icmsMonth2, ...
                      app.icmsMonth3, ...
                      app.icmsMonth4, ...
                      app.icmsMonth5, ...
                      app.icmsMonth6, ...
                      app.icmsMonth7, ...
                      app.icmsMonth8, ...
                      app.icmsMonth9, ...
                      app.icmsMonth10, ...
                      app.icmsMonth11, ...
                      app.icmsMonth12}

                    rateJsonInfo = createRateJsonInfo(app);
                    update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'valueChanged:Alíquota ICMS', generalSettings, accountIndex, jsonencode(rateJsonInfo))

                case app.freenote
                    newFreeNote = textFormatGUI.cellstr2TextField(app.freenote.Value);
                    update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'valueChanged:Observação', generalSettings, accountIndex, newFreeNote)
            end

            updateLayout(app, fileIndex, app.accountList.Value)

            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'onAccountEdited', context)
            
        end

        % Image clicked function: NextSelection, PreviousSelection
        function arrowButtonClicked(app, event)
            
            [~, currentAccountIndex] = ismember(app.accountList.Value, app.accountList.Items);
            maxAccountIndex = numel(app.accountList.Items);

            switch event.Source
                case app.PreviousSelection
                    newAccountIndex = currentAccountIndex - 1;
                case app.NextSelection
                    newAccountIndex = currentAccountIndex + 1;
            end

            if newAccountIndex < 1
                newAccountIndex = maxAccountIndex;
            elseif newAccountIndex > maxAccountIndex
                newAccountIndex = 1;
            end

            app.accountList.Value = app.accountList.Items{newAccountIndex};
            accountListValueChanged(app, event)

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
                app.UIFigure.Position = [92 92 720 580];
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
            app.Document.ColumnWidth = {22, 22, 144, 208, '1x'};
            app.Document.RowHeight = {17, 22, '1x', 22, 22, 108, 22, 44, 1, 22};
            app.Document.RowSpacing = 5;
            app.Document.Layout.Row = 2;
            app.Document.Layout.Column = [1 2];
            app.Document.BackgroundColor = [1 1 1];

            % Create accountListLabel
            app.accountListLabel = uilabel(app.Document);
            app.accountListLabel.VerticalAlignment = 'bottom';
            app.accountListLabel.FontSize = 11;
            app.accountListLabel.Layout.Row = 1;
            app.accountListLabel.Layout.Column = [1 3];
            app.accountListLabel.Text = 'Conta:';

            % Create accountList
            app.accountList = uidropdown(app.Document);
            app.accountList.Items = {};
            app.accountList.ValueChangedFcn = createCallbackFcn(app, @accountListValueChanged, true);
            app.accountList.FontSize = 11;
            app.accountList.BackgroundColor = [1 1 1];
            app.accountList.Layout.Row = 2;
            app.accountList.Layout.Column = [1 3];
            app.accountList.Value = {};

            % Create taxTypeLabel
            app.taxTypeLabel = uilabel(app.Document);
            app.taxTypeLabel.VerticalAlignment = 'bottom';
            app.taxTypeLabel.FontSize = 11;
            app.taxTypeLabel.Layout.Row = 4;
            app.taxTypeLabel.Layout.Column = [1 3];
            app.taxTypeLabel.Text = 'Apurado? ✎';

            % Create taxType
            app.taxType = uidropdown(app.Document);
            app.taxType.Items = {'-', 'Não', 'Sim', 'ICMS Telecom', 'PIS Telecom', 'COFINS Telecom'};
            app.taxType.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.taxType.FontSize = 11;
            app.taxType.BackgroundColor = [1 1 1];
            app.taxType.Layout.Row = 5;
            app.taxType.Layout.Column = [1 3];
            app.taxType.Value = '-';

            % Create icmsTypeLabel
            app.icmsTypeLabel = uilabel(app.Document);
            app.icmsTypeLabel.VerticalAlignment = 'bottom';
            app.icmsTypeLabel.FontSize = 11;
            app.icmsTypeLabel.Layout.Row = 4;
            app.icmsTypeLabel.Layout.Column = 4;
            app.icmsTypeLabel.Text = 'Alíquota ICMS ✎';

            % Create icmsType
            app.icmsType = uidropdown(app.Document);
            app.icmsType.Items = {'auto', 'manual'};
            app.icmsType.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsType.FontSize = 11;
            app.icmsType.BackgroundColor = [1 1 1];
            app.icmsType.Layout.Row = 5;
            app.icmsType.Layout.Column = 4;
            app.icmsType.Value = 'auto';

            % Create icmsMonthsPanel
            app.icmsMonthsPanel = uipanel(app.Document);
            app.icmsMonthsPanel.Layout.Row = 6;
            app.icmsMonthsPanel.Layout.Column = [1 4];

            % Create icmsMonthsGrid
            app.icmsMonthsGrid = uigridlayout(app.icmsMonthsPanel);
            app.icmsMonthsGrid.ColumnWidth = {24, '1x', 24, '1x', 24, '1x', 24, '1x'};
            app.icmsMonthsGrid.RowHeight = {22, 22, 22};
            app.icmsMonthsGrid.BackgroundColor = [1 1 1];

            % Create icmsMonth1Label
            app.icmsMonth1Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth1Label.FontSize = 10;
            app.icmsMonth1Label.Layout.Row = 1;
            app.icmsMonth1Label.Layout.Column = [1 2];
            app.icmsMonth1Label.Text = 'JAN:';

            % Create icmsMonth1
            app.icmsMonth1 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth1.Step = 0.5;
            app.icmsMonth1.Limits = [0 100];
            app.icmsMonth1.ValueDisplayFormat = '%.1f';
            app.icmsMonth1.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth1.Tag = '1';
            app.icmsMonth1.FontSize = 11;
            app.icmsMonth1.Enable = 'off';
            app.icmsMonth1.Layout.Row = 1;
            app.icmsMonth1.Layout.Column = 2;

            % Create icmsMonth2Label
            app.icmsMonth2Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth2Label.FontSize = 10;
            app.icmsMonth2Label.Layout.Row = 2;
            app.icmsMonth2Label.Layout.Column = [1 2];
            app.icmsMonth2Label.Text = 'FEV:';

            % Create icmsMonth2
            app.icmsMonth2 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth2.Step = 0.5;
            app.icmsMonth2.Limits = [0 100];
            app.icmsMonth2.ValueDisplayFormat = '%.1f';
            app.icmsMonth2.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth2.Tag = '2';
            app.icmsMonth2.FontSize = 11;
            app.icmsMonth2.Enable = 'off';
            app.icmsMonth2.Layout.Row = 2;
            app.icmsMonth2.Layout.Column = 2;

            % Create icmsMonth3Label
            app.icmsMonth3Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth3Label.FontSize = 10;
            app.icmsMonth3Label.Layout.Row = 3;
            app.icmsMonth3Label.Layout.Column = [1 2];
            app.icmsMonth3Label.Text = 'MAR:';

            % Create icmsMonth3
            app.icmsMonth3 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth3.Step = 0.5;
            app.icmsMonth3.Limits = [0 100];
            app.icmsMonth3.ValueDisplayFormat = '%.1f';
            app.icmsMonth3.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth3.Tag = '3';
            app.icmsMonth3.FontSize = 11;
            app.icmsMonth3.Enable = 'off';
            app.icmsMonth3.Layout.Row = 3;
            app.icmsMonth3.Layout.Column = 2;

            % Create icmsMonth4Label
            app.icmsMonth4Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth4Label.FontSize = 10;
            app.icmsMonth4Label.Layout.Row = 1;
            app.icmsMonth4Label.Layout.Column = [3 4];
            app.icmsMonth4Label.Text = 'ABR:';

            % Create icmsMonth4
            app.icmsMonth4 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth4.Step = 0.5;
            app.icmsMonth4.Limits = [0 100];
            app.icmsMonth4.ValueDisplayFormat = '%.1f';
            app.icmsMonth4.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth4.Tag = '4';
            app.icmsMonth4.FontSize = 11;
            app.icmsMonth4.Enable = 'off';
            app.icmsMonth4.Layout.Row = 1;
            app.icmsMonth4.Layout.Column = 4;

            % Create icmsMonth5Label
            app.icmsMonth5Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth5Label.FontSize = 10;
            app.icmsMonth5Label.Layout.Row = 2;
            app.icmsMonth5Label.Layout.Column = [3 4];
            app.icmsMonth5Label.Text = 'MAI:';

            % Create icmsMonth5
            app.icmsMonth5 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth5.Step = 0.5;
            app.icmsMonth5.Limits = [0 100];
            app.icmsMonth5.ValueDisplayFormat = '%.1f';
            app.icmsMonth5.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth5.Tag = '5';
            app.icmsMonth5.FontSize = 11;
            app.icmsMonth5.Enable = 'off';
            app.icmsMonth5.Layout.Row = 2;
            app.icmsMonth5.Layout.Column = 4;

            % Create icmsMonth6Label
            app.icmsMonth6Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth6Label.FontSize = 10;
            app.icmsMonth6Label.Layout.Row = 3;
            app.icmsMonth6Label.Layout.Column = [3 4];
            app.icmsMonth6Label.Text = 'JUN:';

            % Create icmsMonth6
            app.icmsMonth6 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth6.Step = 0.5;
            app.icmsMonth6.Limits = [0 100];
            app.icmsMonth6.ValueDisplayFormat = '%.1f';
            app.icmsMonth6.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth6.Tag = '6';
            app.icmsMonth6.FontSize = 11;
            app.icmsMonth6.Enable = 'off';
            app.icmsMonth6.Layout.Row = 3;
            app.icmsMonth6.Layout.Column = 4;

            % Create icmsMonth7Label
            app.icmsMonth7Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth7Label.FontSize = 10;
            app.icmsMonth7Label.Layout.Row = 1;
            app.icmsMonth7Label.Layout.Column = [5 6];
            app.icmsMonth7Label.Text = 'JUL:';

            % Create icmsMonth7
            app.icmsMonth7 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth7.Step = 0.5;
            app.icmsMonth7.Limits = [0 100];
            app.icmsMonth7.ValueDisplayFormat = '%.1f';
            app.icmsMonth7.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth7.Tag = '7';
            app.icmsMonth7.FontSize = 11;
            app.icmsMonth7.Enable = 'off';
            app.icmsMonth7.Layout.Row = 1;
            app.icmsMonth7.Layout.Column = 6;

            % Create icmsMonth8Label
            app.icmsMonth8Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth8Label.FontSize = 10;
            app.icmsMonth8Label.Layout.Row = 2;
            app.icmsMonth8Label.Layout.Column = [5 6];
            app.icmsMonth8Label.Text = 'AGO:';

            % Create icmsMonth8
            app.icmsMonth8 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth8.Step = 0.5;
            app.icmsMonth8.Limits = [0 100];
            app.icmsMonth8.ValueDisplayFormat = '%.1f';
            app.icmsMonth8.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth8.Tag = '8';
            app.icmsMonth8.FontSize = 11;
            app.icmsMonth8.Enable = 'off';
            app.icmsMonth8.Layout.Row = 2;
            app.icmsMonth8.Layout.Column = 6;

            % Create icmsMonth9Label
            app.icmsMonth9Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth9Label.FontSize = 10;
            app.icmsMonth9Label.Layout.Row = 3;
            app.icmsMonth9Label.Layout.Column = [5 6];
            app.icmsMonth9Label.Text = 'SET:';

            % Create icmsMonth9
            app.icmsMonth9 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth9.Step = 0.5;
            app.icmsMonth9.Limits = [0 100];
            app.icmsMonth9.ValueDisplayFormat = '%.1f';
            app.icmsMonth9.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth9.Tag = '9';
            app.icmsMonth9.FontSize = 11;
            app.icmsMonth9.Enable = 'off';
            app.icmsMonth9.Layout.Row = 3;
            app.icmsMonth9.Layout.Column = 6;

            % Create icmsMonth10Label
            app.icmsMonth10Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth10Label.FontSize = 10;
            app.icmsMonth10Label.Layout.Row = 1;
            app.icmsMonth10Label.Layout.Column = [7 8];
            app.icmsMonth10Label.Text = 'OUT:';

            % Create icmsMonth10
            app.icmsMonth10 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth10.Step = 0.5;
            app.icmsMonth10.Limits = [0 100];
            app.icmsMonth10.ValueDisplayFormat = '%.1f';
            app.icmsMonth10.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth10.Tag = '10';
            app.icmsMonth10.FontSize = 11;
            app.icmsMonth10.Enable = 'off';
            app.icmsMonth10.Layout.Row = 1;
            app.icmsMonth10.Layout.Column = 8;

            % Create icmsMonth11Label
            app.icmsMonth11Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth11Label.FontSize = 10;
            app.icmsMonth11Label.Layout.Row = 2;
            app.icmsMonth11Label.Layout.Column = [7 8];
            app.icmsMonth11Label.Text = 'NOV:';

            % Create icmsMonth11
            app.icmsMonth11 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth11.Step = 0.5;
            app.icmsMonth11.Limits = [0 100];
            app.icmsMonth11.ValueDisplayFormat = '%.1f';
            app.icmsMonth11.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth11.Tag = '11';
            app.icmsMonth11.FontSize = 11;
            app.icmsMonth11.Enable = 'off';
            app.icmsMonth11.Layout.Row = 2;
            app.icmsMonth11.Layout.Column = 8;

            % Create icmsMonth12Label
            app.icmsMonth12Label = uilabel(app.icmsMonthsGrid);
            app.icmsMonth12Label.FontSize = 10;
            app.icmsMonth12Label.Layout.Row = 3;
            app.icmsMonth12Label.Layout.Column = [7 8];
            app.icmsMonth12Label.Text = 'DEZ:';

            % Create icmsMonth12
            app.icmsMonth12 = uispinner(app.icmsMonthsGrid);
            app.icmsMonth12.Step = 0.5;
            app.icmsMonth12.Limits = [0 100];
            app.icmsMonth12.ValueDisplayFormat = '%.1f';
            app.icmsMonth12.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.icmsMonth12.Tag = '12';
            app.icmsMonth12.FontSize = 11;
            app.icmsMonth12.Enable = 'off';
            app.icmsMonth12.Layout.Row = 3;
            app.icmsMonth12.Layout.Column = 8;
            app.icmsMonth12.Value = 25.1;

            % Create freenoteLabel
            app.freenoteLabel = uilabel(app.Document);
            app.freenoteLabel.VerticalAlignment = 'bottom';
            app.freenoteLabel.FontSize = 11;
            app.freenoteLabel.Layout.Row = 7;
            app.freenoteLabel.Layout.Column = [1 3];
            app.freenoteLabel.Text = 'Observação ✎';

            % Create freenote
            app.freenote = uitextarea(app.Document);
            app.freenote.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.freenote.FontSize = 11;
            app.freenote.Layout.Row = 8;
            app.freenote.Layout.Column = [1 4];

            % Create totalValue
            app.totalValue = uilabel(app.Document);
            app.totalValue.HorizontalAlignment = 'right';
            app.totalValue.VerticalAlignment = 'top';
            app.totalValue.FontSize = 11;
            app.totalValue.FontWeight = 'bold';
            app.totalValue.Layout.Row = [9 10];
            app.totalValue.Layout.Column = 5;
            app.totalValue.Text = '';

            % Create plotPanel
            app.plotPanel = uipanel(app.Document);
            app.plotPanel.AutoResizeChildren = 'off';
            app.plotPanel.BorderType = 'none';
            app.plotPanel.BackgroundColor = [0 0 0];
            app.plotPanel.Layout.Row = [5 8];
            app.plotPanel.Layout.Column = 5;

            % Create PreviousSelection
            app.PreviousSelection = uiimage(app.Document);
            app.PreviousSelection.ImageClickedFcn = createCallbackFcn(app, @arrowButtonClicked, true);
            app.PreviousSelection.Tooltip = {'Navega para a conta anterior'};
            app.PreviousSelection.Layout.Row = 10;
            app.PreviousSelection.Layout.Column = 1;
            app.PreviousSelection.ImageSource = 'Previous_32.png';

            % Create NextSelection
            app.NextSelection = uiimage(app.Document);
            app.NextSelection.ImageClickedFcn = createCallbackFcn(app, @arrowButtonClicked, true);
            app.NextSelection.Tooltip = {'Navega para a conta posterior'};
            app.NextSelection.Layout.Row = 10;
            app.NextSelection.Layout.Column = 2;
            app.NextSelection.ImageSource = 'After_32.png';

            % Create accountInfo
            app.accountInfo = uilabel(app.Document);
            app.accountInfo.VerticalAlignment = 'top';
            app.accountInfo.WordWrap = 'on';
            app.accountInfo.FontSize = 11;
            app.accountInfo.Layout.Row = 3;
            app.accountInfo.Layout.Column = [1 5];
            app.accountInfo.Interpreter = 'html';
            app.accountInfo.Text = '';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = dockECDAccount_exported(Container, varargin)

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
