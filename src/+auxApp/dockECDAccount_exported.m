classdef dockECDAccount_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                  matlab.ui.Figure
        GridLayout                matlab.ui.container.GridLayout
        AccountAnnualTotal        matlab.ui.control.Label
        NextSelection             matlab.ui.control.Image
        PreviousSelection         matlab.ui.control.Image
        MonthlyBalanceChartPanel  matlab.ui.container.Panel
        AuditorComment            matlab.ui.control.TextArea
        AuditorCommentLabel       matlab.ui.control.Label
        IcmsMonthsPanel           matlab.ui.container.Panel
        IcmsMonthsGrid            matlab.ui.container.GridLayout
        icmsMonth12               matlab.ui.control.Spinner
        icmsMonth12Label          matlab.ui.control.Label
        icmsMonth11               matlab.ui.control.Spinner
        icmsMonth11Label          matlab.ui.control.Label
        icmsMonth10               matlab.ui.control.Spinner
        icmsMonth10Label          matlab.ui.control.Label
        icmsMonth9                matlab.ui.control.Spinner
        icmsMonth9Label           matlab.ui.control.Label
        icmsMonth8                matlab.ui.control.Spinner
        icmsMonth8Label           matlab.ui.control.Label
        icmsMonth7                matlab.ui.control.Spinner
        icmsMonth7Label           matlab.ui.control.Label
        icmsMonth6                matlab.ui.control.Spinner
        icmsMonth6Label           matlab.ui.control.Label
        icmsMonth5                matlab.ui.control.Spinner
        icmsMonth5Label           matlab.ui.control.Label
        icmsMonth4                matlab.ui.control.Spinner
        icmsMonth4Label           matlab.ui.control.Label
        icmsMonth3                matlab.ui.control.Spinner
        icmsMonth3Label           matlab.ui.control.Label
        icmsMonth2                matlab.ui.control.Spinner
        icmsMonth2Label           matlab.ui.control.Label
        icmsMonth1                matlab.ui.control.Spinner
        icmsMonth1Label           matlab.ui.control.Label
        IcmsRateMode              matlab.ui.control.DropDown
        IcmsRateModeLabel         matlab.ui.control.Label
        Interconnection           matlab.ui.control.DropDown
        InterconnectionLabel      matlab.ui.control.Label
        AccountTaxCategory        matlab.ui.control.DropDown
        AccountTaxCategoryLabel   matlab.ui.control.Label
        SelfDeclaration           matlab.ui.control.DropDown
        SelfDeclarationLabel      matlab.ui.control.Label
        AccountInfo               matlab.ui.control.Label
        AccountList               matlab.ui.control.DropDown
        AccountListLabel          matlab.ui.control.Label
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
                app.AccountInfo
            };
            ui.CustomizationBase.getElementsDataTag(elToModify);
    
            try
                ui.TextView.startup(app.jsBackDoor, app.AccountInfo, class.Constants.appName);
            catch
            end
        end

        %-----------------------------------------------------------------%
        function accountName = startupLayout(app, index, accountName)
            % Cria o eixo geográfico:
            app.UIAxes = plot.axesCreationController(app.MonthlyBalanceChartPanel);

            % Atualiza lista de contas de resultado:
            app.AccountList.Items = app.mainApp.ecdObj(index).Table.x_CONTAS_ANOTACAO.("COD_CTA");
            if ismember(accountName, app.AccountList.Items)
                app.AccountList.Value = accountName;
            else
                accountName = app.AccountList.Value;
            end

            % Tipos de conta:
            app.SelfDeclaration.Items = app.mainApp.General.context.ECD.selfDeclarationOptions;
            app.AccountTaxCategory.Items = app.mainApp.General.context.ECD.accountOptions;
            app.Interconnection.Items = app.mainApp.General.context.ECD.interconnectionOptions;
        end

        %-----------------------------------------------------------------%
        function updateLayout(app, index, accountName)
            selectedECD  = app.mainApp.ecdObj(index);
            [accountTable, index, htmlContent] = util.HtmlTextGenerator.AccountInfo(selectedECD, accountName, app.mainApp.General);
            
            % Árvore de descrição da conta:
            % app.AccountInfo.Text = htmlContent;
            ui.TextView.setLabelInnerHTMLBypassingText(app.jsBackDoor, app.AccountInfo, htmlContent)
            
            % Valores iniciais dos campos passíveis de anotação:
            app.SelfDeclaration.Value = char(accountTable.('Declarado?  ✎')(index));
            app.AccountTaxCategory.Value = char(accountTable.('Apurado?  ✎')(index));
            app.Interconnection.Value = char(accountTable.('Interconexão?  ✎')(index));
            app.AuditorComment.Value = accountTable.('Observação  ✎'){index};

            switch accountTable.('Alíquota ICMS'){index}
                case '-'
                    app.currentAccount = struct('mode', 'n/a', 'rate', 0, 'index', index);
                    icmsModeItems = {'n/a'};
                otherwise
                    app.currentAccount = jsondecode(accountTable.('Alíquota ICMS'){index});
                    app.currentAccount.index = index;
                    icmsModeItems = {'auto', 'manual'};
            end
            set(app.IcmsRateMode, 'Items', icmsModeItems, 'Value', app.currentAccount.mode)

            updateRatePanelStatus(app, strcmp(app.currentAccount.mode, 'manual'))
            updateRatePanelValue(app, app.currentAccount.rate)

            % Plot:
            yLimit = max(abs(accountTable{index, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}})) * 1.1;
            if yLimit == 0
                yLimit = 1;
            end
            app.UIAxes.YLim = [-yLimit, yLimit];            
            app.AccountAnnualTotal.Text = sprintf('Saldo anual:\nR$ %.2f', accountTable{index, 'TOTAL'});

            cla(app.UIAxes)
            plotHandle = bar(app.UIAxes, accountTable{index, {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'}}, 'FaceColor', '#ffff12', 'LineStyle', 'none');
            plot.datatip.Template(plotHandle, "Value")
            drawnow
        end

        %-----------------------------------------------------------------%
        function rateJsonInfo = createRateJsonInfo(app)
            fileIndex    = app.inputArgs.index;
            selectedECD  = app.mainApp.ecdObj(fileIndex);

            switch app.IcmsRateMode.Value
                case 'auto'
                    rateList = selectedECD.GUI.icmsRate.current.rate;

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
                'mode', app.IcmsRateMode.Value, ...
                'rate', rateList ...
            );
        end

        %-----------------------------------------------------------------%
        function updateRatePanelStatus(app, status)
            hSpinners = findobj(app.IcmsMonthsGrid.Children, 'Type', 'uispinner');
            set(hSpinners, 'Enable', status)
        end

        %-----------------------------------------------------------------%
        function updateRatePanelValue(app, value)
            value = 100*value;
            
            if isscalar(value)
                hSpinners = findobj(app.IcmsMonthsGrid.Children, 'Type', 'uispinner');
                set(hSpinners, 'Value', value)
            else
                for ii = 1:numel(value)
                    hSpinner = findobj(app.IcmsMonthsGrid.Children, 'Type', 'uispinner', 'Tag', num2str(ii));
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

        % Close request function: UIFigure
        function closeFcn(app, event)
            
            delete(app)
            
        end

        % Value changed function: AccountList
        function AccountListValueChanged(app, event)
            
            fileIndex    = app.inputArgs.index;
            updateLayout(app, fileIndex, app.AccountList.Value)
            
        end

        % Value changed function: AccountTaxCategory, AuditorComment, 
        % ...and 15 other components
        function parameterValueChanged(app, event)
            
            fileIndex    = app.inputArgs.index;
            selectedECD  = app.mainApp.ecdObj(fileIndex);
            accountIndex = app.currentAccount.index;
            generalSettings = app.mainApp.General;

            switch event.Source
                case app.SelfDeclaration
                    update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'valueChanged:Declarado?', generalSettings, accountIndex, app.SelfDeclaration.Value)

                case app.AccountTaxCategory
                    update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'valueChanged:Apurado?', generalSettings, accountIndex, app.AccountTaxCategory.Value)

                case app.Interconnection
                    update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'valueChanged:Interconexão?', generalSettings, accountIndex, app.Interconnection.Value)
                
                case app.IcmsRateMode
                    updateRatePanelStatus(app, strcmp(app.IcmsRateMode.Value, 'manual'))

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

                case app.AuditorComment
                    newFreeNote = textFormatGUI.cellstr2TextField(app.AuditorComment.Value);
                    update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'valueChanged:Observação', generalSettings, accountIndex, newFreeNote)
            end

            updateLayout(app, fileIndex, app.AccountList.Value)

            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'onAccountEdited', context)
            
        end

        % Image clicked function: NextSelection, PreviousSelection
        function arrowButtonClicked(app, event)
            
            [~, currentAccountIndex] = ismember(app.AccountList.Value, app.AccountList.Items);
            maxAccountIndex = numel(app.AccountList.Items);

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

            app.AccountList.Value = app.AccountList.Items{newAccountIndex};
            
            ipcMainMatlabCallsHandler(app.mainApp, app, 'onAccountSelectionChanged', app.inputArgs.context, app.AccountList.Value)
            AccountListValueChanged(app, event)

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
                app.UIFigure.Position = [92 92 794 580];
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
            app.GridLayout.ColumnWidth = {22, 22, 46, 120, 110, 110, 264};
            app.GridLayout.RowHeight = {17, 22, '1x', 22, 22, 108, 22, 44, 1, 22};
            app.GridLayout.RowSpacing = 5;
            app.GridLayout.Padding = [20 20 20 20];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create AccountListLabel
            app.AccountListLabel = uilabel(app.GridLayout);
            app.AccountListLabel.VerticalAlignment = 'bottom';
            app.AccountListLabel.FontSize = 11;
            app.AccountListLabel.Layout.Row = 1;
            app.AccountListLabel.Layout.Column = [1 3];
            app.AccountListLabel.Text = 'Conta:';

            % Create AccountList
            app.AccountList = uidropdown(app.GridLayout);
            app.AccountList.Items = {};
            app.AccountList.ValueChangedFcn = createCallbackFcn(app, @AccountListValueChanged, true);
            app.AccountList.FontSize = 11;
            app.AccountList.BackgroundColor = [1 1 1];
            app.AccountList.Layout.Row = 2;
            app.AccountList.Layout.Column = [1 7];
            app.AccountList.Value = {};

            % Create AccountInfo
            app.AccountInfo = uilabel(app.GridLayout);
            app.AccountInfo.VerticalAlignment = 'top';
            app.AccountInfo.WordWrap = 'on';
            app.AccountInfo.FontSize = 11;
            app.AccountInfo.Layout.Row = 3;
            app.AccountInfo.Layout.Column = [1 7];
            app.AccountInfo.Interpreter = 'html';
            app.AccountInfo.Text = '';

            % Create SelfDeclarationLabel
            app.SelfDeclarationLabel = uilabel(app.GridLayout);
            app.SelfDeclarationLabel.VerticalAlignment = 'bottom';
            app.SelfDeclarationLabel.FontSize = 11;
            app.SelfDeclarationLabel.Layout.Row = 4;
            app.SelfDeclarationLabel.Layout.Column = [1 3];
            app.SelfDeclarationLabel.Text = 'Declarado? ✎';

            % Create SelfDeclaration
            app.SelfDeclaration = uidropdown(app.GridLayout);
            app.SelfDeclaration.Items = {'-', 'Não', 'Sim-parcial', 'Sim-total'};
            app.SelfDeclaration.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.SelfDeclaration.FontSize = 11;
            app.SelfDeclaration.BackgroundColor = [1 1 1];
            app.SelfDeclaration.Layout.Row = 5;
            app.SelfDeclaration.Layout.Column = [1 3];
            app.SelfDeclaration.Value = '-';

            % Create AccountTaxCategoryLabel
            app.AccountTaxCategoryLabel = uilabel(app.GridLayout);
            app.AccountTaxCategoryLabel.VerticalAlignment = 'bottom';
            app.AccountTaxCategoryLabel.FontSize = 11;
            app.AccountTaxCategoryLabel.Layout.Row = 4;
            app.AccountTaxCategoryLabel.Layout.Column = 4;
            app.AccountTaxCategoryLabel.Text = 'Apurado? ✎';

            % Create AccountTaxCategory
            app.AccountTaxCategory = uidropdown(app.GridLayout);
            app.AccountTaxCategory.Items = {'-', 'Não', 'Sim', 'ICMS Telecom', 'PIS Telecom', 'COFINS Telecom'};
            app.AccountTaxCategory.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.AccountTaxCategory.FontSize = 11;
            app.AccountTaxCategory.BackgroundColor = [1 1 1];
            app.AccountTaxCategory.Layout.Row = 5;
            app.AccountTaxCategory.Layout.Column = 4;
            app.AccountTaxCategory.Value = '-';

            % Create InterconnectionLabel
            app.InterconnectionLabel = uilabel(app.GridLayout);
            app.InterconnectionLabel.VerticalAlignment = 'bottom';
            app.InterconnectionLabel.FontSize = 11;
            app.InterconnectionLabel.Layout.Row = 4;
            app.InterconnectionLabel.Layout.Column = 5;
            app.InterconnectionLabel.Text = 'Interconexão? ✎';

            % Create Interconnection
            app.Interconnection = uidropdown(app.GridLayout);
            app.Interconnection.Items = {'-', 'Não', 'ITX', 'EILD'};
            app.Interconnection.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.Interconnection.FontSize = 11;
            app.Interconnection.BackgroundColor = [1 1 1];
            app.Interconnection.Layout.Row = 5;
            app.Interconnection.Layout.Column = 5;
            app.Interconnection.Value = '-';

            % Create IcmsRateModeLabel
            app.IcmsRateModeLabel = uilabel(app.GridLayout);
            app.IcmsRateModeLabel.VerticalAlignment = 'bottom';
            app.IcmsRateModeLabel.FontSize = 11;
            app.IcmsRateModeLabel.Layout.Row = 4;
            app.IcmsRateModeLabel.Layout.Column = 6;
            app.IcmsRateModeLabel.Text = 'Alíquota ICMS ✎';

            % Create IcmsRateMode
            app.IcmsRateMode = uidropdown(app.GridLayout);
            app.IcmsRateMode.Items = {'auto', 'manual'};
            app.IcmsRateMode.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.IcmsRateMode.FontSize = 11;
            app.IcmsRateMode.BackgroundColor = [1 1 1];
            app.IcmsRateMode.Layout.Row = 5;
            app.IcmsRateMode.Layout.Column = 6;
            app.IcmsRateMode.Value = 'auto';

            % Create IcmsMonthsPanel
            app.IcmsMonthsPanel = uipanel(app.GridLayout);
            app.IcmsMonthsPanel.Layout.Row = 6;
            app.IcmsMonthsPanel.Layout.Column = [1 6];

            % Create IcmsMonthsGrid
            app.IcmsMonthsGrid = uigridlayout(app.IcmsMonthsPanel);
            app.IcmsMonthsGrid.ColumnWidth = {24, '1x', 24, '1x', 24, '1x', 24, '1x'};
            app.IcmsMonthsGrid.RowHeight = {22, 22, 22};
            app.IcmsMonthsGrid.BackgroundColor = [1 1 1];

            % Create icmsMonth1Label
            app.icmsMonth1Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth1Label.FontSize = 10;
            app.icmsMonth1Label.Layout.Row = 1;
            app.icmsMonth1Label.Layout.Column = [1 2];
            app.icmsMonth1Label.Text = 'JAN:';

            % Create icmsMonth1
            app.icmsMonth1 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth2Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth2Label.FontSize = 10;
            app.icmsMonth2Label.Layout.Row = 2;
            app.icmsMonth2Label.Layout.Column = [1 2];
            app.icmsMonth2Label.Text = 'FEV:';

            % Create icmsMonth2
            app.icmsMonth2 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth3Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth3Label.FontSize = 10;
            app.icmsMonth3Label.Layout.Row = 3;
            app.icmsMonth3Label.Layout.Column = [1 2];
            app.icmsMonth3Label.Text = 'MAR:';

            % Create icmsMonth3
            app.icmsMonth3 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth4Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth4Label.FontSize = 10;
            app.icmsMonth4Label.Layout.Row = 1;
            app.icmsMonth4Label.Layout.Column = [3 4];
            app.icmsMonth4Label.Text = 'ABR:';

            % Create icmsMonth4
            app.icmsMonth4 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth5Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth5Label.FontSize = 10;
            app.icmsMonth5Label.Layout.Row = 2;
            app.icmsMonth5Label.Layout.Column = [3 4];
            app.icmsMonth5Label.Text = 'MAI:';

            % Create icmsMonth5
            app.icmsMonth5 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth6Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth6Label.FontSize = 10;
            app.icmsMonth6Label.Layout.Row = 3;
            app.icmsMonth6Label.Layout.Column = [3 4];
            app.icmsMonth6Label.Text = 'JUN:';

            % Create icmsMonth6
            app.icmsMonth6 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth7Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth7Label.FontSize = 10;
            app.icmsMonth7Label.Layout.Row = 1;
            app.icmsMonth7Label.Layout.Column = [5 6];
            app.icmsMonth7Label.Text = 'JUL:';

            % Create icmsMonth7
            app.icmsMonth7 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth8Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth8Label.FontSize = 10;
            app.icmsMonth8Label.Layout.Row = 2;
            app.icmsMonth8Label.Layout.Column = [5 6];
            app.icmsMonth8Label.Text = 'AGO:';

            % Create icmsMonth8
            app.icmsMonth8 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth9Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth9Label.FontSize = 10;
            app.icmsMonth9Label.Layout.Row = 3;
            app.icmsMonth9Label.Layout.Column = [5 6];
            app.icmsMonth9Label.Text = 'SET:';

            % Create icmsMonth9
            app.icmsMonth9 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth10Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth10Label.FontSize = 10;
            app.icmsMonth10Label.Layout.Row = 1;
            app.icmsMonth10Label.Layout.Column = [7 8];
            app.icmsMonth10Label.Text = 'OUT:';

            % Create icmsMonth10
            app.icmsMonth10 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth11Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth11Label.FontSize = 10;
            app.icmsMonth11Label.Layout.Row = 2;
            app.icmsMonth11Label.Layout.Column = [7 8];
            app.icmsMonth11Label.Text = 'NOV:';

            % Create icmsMonth11
            app.icmsMonth11 = uispinner(app.IcmsMonthsGrid);
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
            app.icmsMonth12Label = uilabel(app.IcmsMonthsGrid);
            app.icmsMonth12Label.FontSize = 10;
            app.icmsMonth12Label.Layout.Row = 3;
            app.icmsMonth12Label.Layout.Column = [7 8];
            app.icmsMonth12Label.Text = 'DEZ:';

            % Create icmsMonth12
            app.icmsMonth12 = uispinner(app.IcmsMonthsGrid);
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

            % Create AuditorCommentLabel
            app.AuditorCommentLabel = uilabel(app.GridLayout);
            app.AuditorCommentLabel.VerticalAlignment = 'bottom';
            app.AuditorCommentLabel.FontSize = 11;
            app.AuditorCommentLabel.Layout.Row = 7;
            app.AuditorCommentLabel.Layout.Column = [1 3];
            app.AuditorCommentLabel.Text = 'Observação ✎';

            % Create AuditorComment
            app.AuditorComment = uitextarea(app.GridLayout);
            app.AuditorComment.ValueChangedFcn = createCallbackFcn(app, @parameterValueChanged, true);
            app.AuditorComment.FontSize = 11;
            app.AuditorComment.Layout.Row = 8;
            app.AuditorComment.Layout.Column = [1 6];

            % Create MonthlyBalanceChartPanel
            app.MonthlyBalanceChartPanel = uipanel(app.GridLayout);
            app.MonthlyBalanceChartPanel.AutoResizeChildren = 'off';
            app.MonthlyBalanceChartPanel.BorderType = 'none';
            app.MonthlyBalanceChartPanel.BackgroundColor = [0 0 0];
            app.MonthlyBalanceChartPanel.Layout.Row = [5 8];
            app.MonthlyBalanceChartPanel.Layout.Column = 7;

            % Create PreviousSelection
            app.PreviousSelection = uiimage(app.GridLayout);
            app.PreviousSelection.ImageClickedFcn = createCallbackFcn(app, @arrowButtonClicked, true);
            app.PreviousSelection.Tooltip = {'Navega para a conta anterior'};
            app.PreviousSelection.Layout.Row = 10;
            app.PreviousSelection.Layout.Column = 1;
            app.PreviousSelection.ImageSource = 'Previous_32.png';

            % Create NextSelection
            app.NextSelection = uiimage(app.GridLayout);
            app.NextSelection.ImageClickedFcn = createCallbackFcn(app, @arrowButtonClicked, true);
            app.NextSelection.Tooltip = {'Navega para a conta posterior'};
            app.NextSelection.Layout.Row = 10;
            app.NextSelection.Layout.Column = 2;
            app.NextSelection.ImageSource = 'After_32.png';

            % Create AccountAnnualTotal
            app.AccountAnnualTotal = uilabel(app.GridLayout);
            app.AccountAnnualTotal.VerticalAlignment = 'top';
            app.AccountAnnualTotal.FontSize = 11;
            app.AccountAnnualTotal.Layout.Row = [9 10];
            app.AccountAnnualTotal.Layout.Column = 7;
            app.AccountAnnualTotal.Text = '';

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
