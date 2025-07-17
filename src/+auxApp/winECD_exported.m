classdef winECD_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        GridLayout                     matlab.ui.container.GridLayout
        ArquivodedadosDropDownLabel_2  matlab.ui.control.Label
        TreeDropDown                   matlab.ui.control.DropDown
        NOMEDAEMPRESAMetadadosOutrascoisasLabel  matlab.ui.control.Label
        Image2_2                       matlab.ui.control.Image
        GridLayout_2                   matlab.ui.container.GridLayout
        DropDown_3                     matlab.ui.control.DropDown
        Image_6                        matlab.ui.control.Image
        Image_5                        matlab.ui.control.Image
        Image_4                        matlab.ui.control.Image
        ColorPicker_2                  matlab.ui.control.ColorPicker
        ColorPicker                    matlab.ui.control.ColorPicker
        DropDown_2                     matlab.ui.control.DropDown
        DropDown                       matlab.ui.control.DropDown
        Image_3                        matlab.ui.control.Image
        Image_2                        matlab.ui.control.Image
        Image                          matlab.ui.control.Image
        Image2                         matlab.ui.control.Image
        ArquivodedadosDropDown         matlab.ui.control.DropDown
        ArquivodedadosDropDownLabel    matlab.ui.control.Label
        toolGrid                       matlab.ui.container.GridLayout
        tool_tableNRowsIcon            matlab.ui.control.Image
        tool_ExportButton              matlab.ui.control.Image
        tool_Separator                 matlab.ui.control.Image
        tool_RFLinkButton              matlab.ui.control.Image
        UITable                        matlab.ui.control.Table
        filter_ContextMenu             matlab.ui.container.ContextMenu
        filter_delButton               matlab.ui.container.Menu
        filter_delAllButton            matlab.ui.container.Menu
    end

    
    properties (Access = public)
        %-----------------------------------------------------------------%
        Container
        isDocked = false

        mainApp
        General
        rootFolder

        % A função do timer é executada uma única vez após a renderização
        % da figura, lendo arquivos de configuração, iniciando modo de operação
        % paralelo etc. A ideia é deixar o MATLAB focar apenas na criação dos 
        % componentes essenciais da GUI (especificados em "createComponents"), 
        % mostrando a GUI para o usuário o mais rápido possível.
        timerObj
        jsBackDoor

        % Janela de progresso já criada no DOM. Dessa forma, controla-se 
        % apenas a sua visibilidade - e tornando desnecessário criá-la a
        % cada chamada (usando uiprogressdlg, por exemplo).
        progressDialog

        %-----------------------------------------------------------------%
        % ESPECIFICIDADES AUXAPP.ECD
        %-----------------------------------------------------------------%
        ecdObj
    end


    methods
        function ipcSecundaryJSEventsHandler(app, event)
            try
                switch event.HTMLEventName
                    case 'renderer'
                        startup_Controller(app)
                    case 'auxApp.winRFDataHub.filter_Tree'
                        filter_delFilter(app, struct('Source', app.filter_delButton))
                    otherwise
                        error('UnexpectedEvent')
                end

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', ME.message);
            end
        end
    end

    
    methods (Access = private)
        %-----------------------------------------------------------------%
        % INICIALIZAÇÃO
        %-----------------------------------------------------------------%
        function jsBackDoor_Initialization(app)
            app.jsBackDoor = uihtml(app.UIFigure, "HTMLSource",           appUtil.jsBackDoorHTMLSource(),                 ...
                                                  "HTMLEventReceivedFcn", @(~, evt)ipcSecundaryJSEventsHandler(app, evt), ...
                                                  "Visible",              "off");
        end

        %-------------------------------------------------------------------------%
        function jsBackDoor_Customizations(app, tabIndex)
            persistent customizationStatus
            if isempty(customizationStatus)
                customizationStatus = [false, false];
            end

            switch tabIndex
                case 0 % STARTUP
                    if app.isDocked
                        app.progressDialog = app.mainApp.progressDialog;
                    else
                        sendEventToHTMLSource(app.jsBackDoor, 'startup', app.mainApp.executionMode);
                        app.progressDialog = ccTools.ProgressDialog(app.jsBackDoor);                        
                    end
                    customizationStatus = [false, false];

                otherwise
                    if customizationStatus(tabIndex)
                        return
                    end

                    appName = class(app);

                    customizationStatus(tabIndex) = true;
                    switch tabIndex
                        case 1 % ECD
                            % ...

                        case 2 % CONFIGURAÇÕES GERAIS
                            % ...
                    end
            end
        end

        %-----------------------------------------------------------------%
        function startup_timerCreation(app)
            app.timerObj = timer("ExecutionMode", "fixedSpacing", ...
                                 "StartDelay",    1.5,            ...
                                 "Period",        .1,             ...
                                 "TimerFcn",      @(~,~)app.startup_timerFcn);
            start(app.timerObj)
        end

        %-----------------------------------------------------------------%
        function startup_timerFcn(app)
            if ccTools.fcn.UIFigureRenderStatus(app.UIFigure)
                stop(app.timerObj)
                delete(app.timerObj)
                
                jsBackDoor_Initialization(app)
            end
        end

        %-----------------------------------------------------------------%
        function startup_Controller(app)
            drawnow
            jsBackDoor_Customizations(app, 0)
            jsBackDoor_Customizations(app, 1)

            app.progressDialog.Visible = 'visible';
            
            startup_AppProperties(app)
            startup_GUIComponents(app)

            app.progressDialog.Visible = 'hidden';
        end

        %-----------------------------------------------------------------%
        function startup_AppProperties(app)            
            % ...
        end

        %-----------------------------------------------------------------%
        function startup_GUIComponents(app)
            % Dropdown com nomes dos arquivos:
            if ~isempty(app.ecdObj)
                app.ArquivodedadosDropDown.Items = {app.ecdObj.FileName};
                app.tool_RFLinkButton.Enable = 1;
                ArquivodedadosDropDownValueChanged(app)
            end

            app.DropDown.Items = listfonts;
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function TreeBuilding(app)
            if ~isempty(app.TreeDropDown.Items)
                app.TreeDropDown.Items = {};
            end

            idxData = find(strcmp(app.ArquivodedadosDropDown.Items, app.ArquivodedadosDropDown.Value), 1);
            selectedECD = app.ecdObj(idxData);

            Fichas = sort(fieldnames(selectedECD.Table));
            for ii = 1:numel(Fichas)
                fichaNome = Fichas{ii};

                if ~isempty(selectedECD.Table.(fichaNome))
                    app.TreeDropDown.Items{end+1} = fichaNome(2:end);
                end
            end

            if~isempty(app.TreeDropDown.Items)
                TreeSelectionChanged(app)
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, filterTable, rfDataHubAnnotation)
            
            app.mainApp       = mainApp;
            app.General       = mainApp.General;
            app.rootFolder    = mainApp.rootFolder;
            app.ecdObj        = mainApp.ecdObj;
    
            % Em sendo executado como módulo do appAnalise, o app pode
            % estar em modo DOCK ou UNDOCK, o que é definido em configuração
            % no próprio appAnalise.
            if app.isDocked
                app.GridLayout.Padding(4) = 19;
                app.jsBackDoor = mainApp.jsBackDoor;
                startup_Controller(app)
            else
                appUtil.winPosition(app.UIFigure)
                startup_timerCreation(app)
            end

        end

        % Close request function: UIFigure
        function closeFcn(app, event)

            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcn')
            delete(app)
            
        end

        % Value changed function: ArquivodedadosDropDown
        function ArquivodedadosDropDownValueChanged(app, event)
            
            TreeBuilding(app)

        end

        % Value changed function: TreeDropDown
        function TreeSelectionChanged(app, event)
            
            idxData = find(strcmp(app.ArquivodedadosDropDown.Items, app.ArquivodedadosDropDown.Value), 1);
            selectedECD = app.ecdObj(idxData);

            fichaNome = ['x' app.TreeDropDown.Value];
            
            app.UITable.Data = selectedECD.Table.(fichaNome);
            app.UITable.ColumnName = app.UITable.Data.Properties.VariableNames;

        end

        % Image clicked function: tool_RFLinkButton
        function LerfichasButtonPushed(app, event)
            
            app.progressDialog.Visible = 'visible';

            try
                idxData = find(strcmp(app.ArquivodedadosDropDown.Items, app.ArquivodedadosDropDown.Value), 1);
                selectedECD = app.ecdObj(idxData);

                parseTableAndAddToCache(selectedECD, {'0000', '0007', '0020', '0035', '0150', '0180', '0990', 'C001', 'C040', 'C050', 'C051', 'C052', 'C150', 'C155', ...
                                                      'C600', 'C650', 'C990', 'I001', 'I010', 'I001', 'I012', 'I015', 'I020', 'I030', 'I050', 'I051', 'I052', 'I053', ...
                                                      'I075', 'I100', 'I150', 'I155', 'I157', 'I200', 'I250', 'I300', 'I310', 'I350', 'I355', 'I500', 'I510', 'I550', ...
                                                      'I555', 'I990', 'J001', 'J005', 'J100', 'J150', 'J210', 'J215', 'J900', 'J930', 'J932', 'J935', 'J990', 'K001', ...
                                                      'K030', 'K100', 'K110', 'K115', 'K200', 'K210', 'K300', 'K310', 'K315', 'K990', '9001', '9900', '9990', '9999'});

                selectedECD.Table.xI200_I250           = parseSplitLineOthers(selectedECD, {'I250' 'I200'});
                selectedECD.Table.xJ005_J100           = parseSplitLineOthers(selectedECD, {'J100' 'J005'});
                selectedECD.Table.xJ005_J150           = parseSplitLineOthers(selectedECD, {'J150' 'J005'});        
                selectedECD.Table.xI050_I051_I052      = parseSplitLineOthers(selectedECD, {'I050' 'I051' 'I052'});
                selectedECD.Table.xC050_C051_C052      = parseSplitLineOthers(selectedECD, {'C050' 'C051' 'C052'});
                selectedECD.Table.xI150_I155_I350_I355 = parseSplitLine(selectedECD, {'I150' 'I155' 'I350' 'I355'});

                if ~isempty(selectedECD.Table.xI150_I155_I350_I355)
                    selectedECD.Table.xTabelaDinamica  = tableDinamica_I150_I155_I350_I355(selectedECD, selectedECD.Table.xI150_I155_I350_I355, selectedECD.Table.xI200_I250);
                    selectedECD.Table.xBalancete       = Balancete(selectedECD, selectedECD.Table.xTabelaDinamica, selectedECD.Table.xI050_I051_I052, selectedECD.Table.xJ005_J150);
                end

                TreeBuilding(app)

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', ME.message);
            end

            app.progressDialog.Visible = 'hidden';

        end

        % Callback function
        function tool_InteractionImageClicked(app, event)
            
            switch event.Source
                case app.tool_ControlPanelVisibility
                    if app.GridLayout.ColumnWidth{2}
                        app.tool_ControlPanelVisibility.ImageSource = 'ArrowRight_32.png';
                        app.GridLayout.ColumnWidth(2:3) = {0,0};
                    else
                        app.tool_ControlPanelVisibility.ImageSource = 'ArrowLeft_32.png';
                        app.GridLayout.ColumnWidth(2:3) = {325,10};
                    end

                otherwise
                    % ...
            end

        end

        % Value changed function: DropDown_3
        function Image3Clicked(app, event)
            
            app.UITable.SelectionType = app.DropDown_3.Value;

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
                app.UIFigure.Position = [100 100 1244 660];
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
            app.GridLayout.ColumnWidth = {5, 320, 5, 90, 5, 5, 5, '1x', 5, 5, 5, 330, 5};
            app.GridLayout.RowHeight = {5, 22, 5, 22, 5, '0.4x', 5, 34};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create UITable
            app.UITable = uitable(app.GridLayout);
            app.UITable.ColumnName = '';
            app.UITable.ColumnRearrangeable = 'on';
            app.UITable.RowName = {};
            app.UITable.ColumnSortable = true;
            app.UITable.ColumnEditable = true;
            app.UITable.ForegroundColor = [0.149 0.149 0.149];
            app.UITable.Layout.Row = 6;
            app.UITable.Layout.Column = [2 12];
            app.UITable.FontSize = 10.5;

            % Create toolGrid
            app.toolGrid = uigridlayout(app.GridLayout);
            app.toolGrid.ColumnWidth = {22, 22, 5, 22, '1x'};
            app.toolGrid.RowHeight = {4, 17, 2};
            app.toolGrid.ColumnSpacing = 5;
            app.toolGrid.RowSpacing = 0;
            app.toolGrid.Padding = [2 5 5 5];
            app.toolGrid.Layout.Row = 8;
            app.toolGrid.Layout.Column = [1 13];
            app.toolGrid.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create tool_RFLinkButton
            app.tool_RFLinkButton = uiimage(app.toolGrid);
            app.tool_RFLinkButton.ScaleMethod = 'none';
            app.tool_RFLinkButton.ImageClickedFcn = createCallbackFcn(app, @LerfichasButtonPushed, true);
            app.tool_RFLinkButton.Enable = 'off';
            app.tool_RFLinkButton.Tooltip = {'Perfil de terreno entre registro selecionado (TX) '; 'e estação de referência (RX)'};
            app.tool_RFLinkButton.Layout.Row = 2;
            app.tool_RFLinkButton.Layout.Column = 1;
            app.tool_RFLinkButton.VerticalAlignment = 'top';
            app.tool_RFLinkButton.ImageSource = 'Publish_HTML_16.png';

            % Create tool_Separator
            app.tool_Separator = uiimage(app.toolGrid);
            app.tool_Separator.Enable = 'off';
            app.tool_Separator.Layout.Row = [1 3];
            app.tool_Separator.Layout.Column = 3;
            app.tool_Separator.VerticalAlignment = 'bottom';
            app.tool_Separator.ImageSource = 'LineV.png';

            % Create tool_ExportButton
            app.tool_ExportButton = uiimage(app.toolGrid);
            app.tool_ExportButton.ScaleMethod = 'none';
            app.tool_ExportButton.Enable = 'off';
            app.tool_ExportButton.Layout.Row = 2;
            app.tool_ExportButton.Layout.Column = 4;
            app.tool_ExportButton.ImageSource = 'Export_16.png';

            % Create tool_tableNRowsIcon
            app.tool_tableNRowsIcon = uiimage(app.toolGrid);
            app.tool_tableNRowsIcon.ScaleMethod = 'none';
            app.tool_tableNRowsIcon.Enable = 'off';
            app.tool_tableNRowsIcon.Layout.Row = 2;
            app.tool_tableNRowsIcon.Layout.Column = 2;
            app.tool_tableNRowsIcon.ImageSource = 'Filter_18.png';

            % Create ArquivodedadosDropDownLabel
            app.ArquivodedadosDropDownLabel = uilabel(app.GridLayout);
            app.ArquivodedadosDropDownLabel.VerticalAlignment = 'bottom';
            app.ArquivodedadosDropDownLabel.Layout.Row = 2;
            app.ArquivodedadosDropDownLabel.Layout.Column = 2;
            app.ArquivodedadosDropDownLabel.Text = 'Arquivo de dados:';

            % Create ArquivodedadosDropDown
            app.ArquivodedadosDropDown = uidropdown(app.GridLayout);
            app.ArquivodedadosDropDown.Items = {};
            app.ArquivodedadosDropDown.ValueChangedFcn = createCallbackFcn(app, @ArquivodedadosDropDownValueChanged, true);
            app.ArquivodedadosDropDown.BackgroundColor = [1 1 1];
            app.ArquivodedadosDropDown.Layout.Row = 4;
            app.ArquivodedadosDropDown.Layout.Column = 2;
            app.ArquivodedadosDropDown.Value = {};

            % Create Image2
            app.Image2 = uiimage(app.GridLayout);
            app.Image2.Enable = 'off';
            app.Image2.Layout.Row = [2 4];
            app.Image2.Layout.Column = 10;
            app.Image2.ImageSource = 'LineV.svg';

            % Create GridLayout_2
            app.GridLayout_2 = uigridlayout(app.GridLayout);
            app.GridLayout_2.ColumnWidth = {'1x', 22, 22, 22, 22, 22, 22, 36, 36};
            app.GridLayout_2.RowHeight = {22, 22};
            app.GridLayout_2.ColumnSpacing = 5;
            app.GridLayout_2.RowSpacing = 5;
            app.GridLayout_2.Padding = [0 0 0 0];
            app.GridLayout_2.Layout.Row = [2 4];
            app.GridLayout_2.Layout.Column = 12;
            app.GridLayout_2.BackgroundColor = [1 1 1];

            % Create Image
            app.Image = uiimage(app.GridLayout_2);
            app.Image.ScaleMethod = 'none';
            app.Image.Tooltip = {'Negrito'};
            app.Image.Layout.Row = 2;
            app.Image.Layout.Column = 2;
            app.Image.ImageSource = '_Bold.png';

            % Create Image_2
            app.Image_2 = uiimage(app.GridLayout_2);
            app.Image_2.ScaleMethod = 'none';
            app.Image_2.Tooltip = {'Itálico'};
            app.Image_2.Layout.Row = 2;
            app.Image_2.Layout.Column = 3;
            app.Image_2.ImageSource = '_Italic.png';

            % Create Image_3
            app.Image_3 = uiimage(app.GridLayout_2);
            app.Image_3.ScaleMethod = 'none';
            app.Image_3.Tooltip = {'Sublinhado'};
            app.Image_3.Layout.Row = 2;
            app.Image_3.Layout.Column = 4;
            app.Image_3.ImageSource = '_Underline.png';

            % Create DropDown
            app.DropDown = uidropdown(app.GridLayout_2);
            app.DropDown.Items = {};
            app.DropDown.Tooltip = {'Fonte'};
            app.DropDown.FontSize = 11;
            app.DropDown.BackgroundColor = [1 1 1];
            app.DropDown.Layout.Row = 1;
            app.DropDown.Layout.Column = [1 7];
            app.DropDown.Value = {};

            % Create DropDown_2
            app.DropDown_2 = uidropdown(app.GridLayout_2);
            app.DropDown_2.Items = {'10', '11', '12', '13', '14'};
            app.DropDown_2.Tooltip = {'Tamanho da fonte'};
            app.DropDown_2.FontSize = 11;
            app.DropDown_2.BackgroundColor = [1 1 1];
            app.DropDown_2.Layout.Row = 1;
            app.DropDown_2.Layout.Column = [8 9];
            app.DropDown_2.Value = '11';

            % Create ColorPicker
            app.ColorPicker = uicolorpicker(app.GridLayout_2);
            app.ColorPicker.Icon = '_Background.png';
            app.ColorPicker.Layout.Row = 2;
            app.ColorPicker.Layout.Column = 8;

            % Create ColorPicker_2
            app.ColorPicker_2 = uicolorpicker(app.GridLayout_2);
            app.ColorPicker_2.Icon = '_Color.png';
            app.ColorPicker_2.Layout.Row = 2;
            app.ColorPicker_2.Layout.Column = 9;

            % Create Image_4
            app.Image_4 = uiimage(app.GridLayout_2);
            app.Image_4.ScaleMethod = 'none';
            app.Image_4.Tooltip = {'Sublinhado'};
            app.Image_4.Layout.Row = 2;
            app.Image_4.Layout.Column = 5;
            app.Image_4.ImageSource = '_AlignLeft.png';

            % Create Image_5
            app.Image_5 = uiimage(app.GridLayout_2);
            app.Image_5.ScaleMethod = 'none';
            app.Image_5.Tooltip = {'Sublinhado'};
            app.Image_5.Layout.Row = 2;
            app.Image_5.Layout.Column = 6;
            app.Image_5.ImageSource = 'AlignCenter.png';

            % Create Image_6
            app.Image_6 = uiimage(app.GridLayout_2);
            app.Image_6.ScaleMethod = 'none';
            app.Image_6.Tooltip = {'Sublinhado'};
            app.Image_6.Layout.Row = 2;
            app.Image_6.Layout.Column = 7;
            app.Image_6.ImageSource = 'AlignRight.png';

            % Create DropDown_3
            app.DropDown_3 = uidropdown(app.GridLayout_2);
            app.DropDown_3.Items = {'cell', 'row', 'column'};
            app.DropDown_3.ValueChangedFcn = createCallbackFcn(app, @Image3Clicked, true);
            app.DropDown_3.BackgroundColor = [1 1 1];
            app.DropDown_3.Layout.Row = 2;
            app.DropDown_3.Layout.Column = 1;
            app.DropDown_3.Value = 'cell';

            % Create Image2_2
            app.Image2_2 = uiimage(app.GridLayout);
            app.Image2_2.Enable = 'off';
            app.Image2_2.Layout.Row = [2 4];
            app.Image2_2.Layout.Column = 6;
            app.Image2_2.ImageSource = 'LineV.svg';

            % Create NOMEDAEMPRESAMetadadosOutrascoisasLabel
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel = uilabel(app.GridLayout);
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.VerticalAlignment = 'top';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.WordWrap = 'on';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.FontSize = 11;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.FontColor = [0.149 0.149 0.149];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.Layout.Row = [2 4];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.Layout.Column = 8;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.Interpreter = 'html';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel.Text = {'<font style="font-size: 14px; font-weight: bold;">NOME DA EMPRESA</font>'; 'Place holder, place holder, place holder, place holder, place holder, place holder, place holder, place holder, place holder, place holder'};

            % Create TreeDropDown
            app.TreeDropDown = uidropdown(app.GridLayout);
            app.TreeDropDown.Items = {};
            app.TreeDropDown.ValueChangedFcn = createCallbackFcn(app, @TreeSelectionChanged, true);
            app.TreeDropDown.BackgroundColor = [1 1 1];
            app.TreeDropDown.Layout.Row = 4;
            app.TreeDropDown.Layout.Column = 4;
            app.TreeDropDown.Value = {};

            % Create ArquivodedadosDropDownLabel_2
            app.ArquivodedadosDropDownLabel_2 = uilabel(app.GridLayout);
            app.ArquivodedadosDropDownLabel_2.VerticalAlignment = 'bottom';
            app.ArquivodedadosDropDownLabel_2.Layout.Row = 2;
            app.ArquivodedadosDropDownLabel_2.Layout.Column = 4;
            app.ArquivodedadosDropDownLabel_2.Text = 'Ficha:';

            % Create filter_ContextMenu
            app.filter_ContextMenu = uicontextmenu(app.UIFigure);

            % Create filter_delButton
            app.filter_delButton = uimenu(app.filter_ContextMenu);
            app.filter_delButton.Text = 'Excluir';

            % Create filter_delAllButton
            app.filter_delAllButton = uimenu(app.filter_ContextMenu);
            app.filter_delAllButton.Text = 'Excluir todos';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = winECD_exported(Container, varargin)

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
