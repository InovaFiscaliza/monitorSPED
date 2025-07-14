classdef winECD_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                     matlab.ui.Figure
        GridLayout                   matlab.ui.container.GridLayout
        selecaoLinha                 matlab.ui.control.Image
        selecaoColuna                matlab.ui.control.Image
        selecaoCelula                matlab.ui.control.Image
        tableInfoMetadata            matlab.ui.control.Label
        toolGrid                     matlab.ui.container.GridLayout
        tool_tableNRowsIcon          matlab.ui.control.Image
        tool_tableNRows              matlab.ui.control.Label
        tool_ExportButton            matlab.ui.control.Image
        tool_Separator               matlab.ui.control.Image
        tool_PDFButton               matlab.ui.control.Image
        tool_RFLinkButton            matlab.ui.control.Image
        tool_TableVisibility         matlab.ui.control.Image
        tool_ControlPanelVisibility  matlab.ui.control.Image
        UITable                      matlab.ui.control.Table
        panelGrid                    matlab.ui.container.GridLayout
        menu_MainGrid                matlab.ui.container.GridLayout
        menu_Button3Grid             matlab.ui.container.GridLayout
        menu_Button3Icon             matlab.ui.control.Image
        menu_Button3Label            matlab.ui.control.Label
        menu_Button2Grid             matlab.ui.container.GridLayout
        menu_Button2Icon             matlab.ui.control.Image
        menu_Button2Label            matlab.ui.control.Label
        menu_Button1Grid             matlab.ui.container.GridLayout
        menu_Button1Icon             matlab.ui.control.Image
        menu_Button1Label            matlab.ui.control.Label
        menuUnderline                matlab.ui.control.Image
        ControlTabGroup              matlab.ui.container.TabGroup
        Tab_1                        matlab.ui.container.Tab
        Tab1_Grid                    matlab.ui.container.GridLayout
        ArquivoDropDown              matlab.ui.control.DropDown
        ArquivoDropDownLabel         matlab.ui.control.Label
        Tree                         matlab.ui.container.Tree
        LerfichasButton              matlab.ui.control.Button
        filter_ContextMenu           matlab.ui.container.ContextMenu
        filter_delButton             matlab.ui.container.Menu
        filter_delAllButton          matlab.ui.container.Menu
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
                app.ArquivoDropDown.Items = {app.ecdObj.FileName};
                app.LerfichasButton.Enable = 1;
                app.selecaoCelula.Enable = 1;
                ArquivoDropDownValueChanged(app)
            end
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function TreeBuilding(app)
            if ~isempty(app.Tree.Children)
                delete(app.Tree.Children)
            end

            idxData = find(strcmp(app.ArquivoDropDown.Items, app.ArquivoDropDown.Value), 1);
            selectedECD = app.ecdObj(idxData);

            Fichas = sort(fieldnames(selectedECD.Table));
            for ii = 1:numel(Fichas)
                fichaNome = Fichas{ii};

                if ~isempty(selectedECD.Table.(fichaNome))
                    uitreenode(app.Tree, 'Text', fichaNome(2:end), 'NodeData', ii);
                end
            end

            if ~isempty(app.Tree.Children)
                app.Tree.SelectedNodes = app.Tree.Children(1);
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

        % Value changed function: ArquivoDropDown
        function ArquivoDropDownValueChanged(app, event)
            
            TreeBuilding(app)

        end

        % Selection changed function: Tree
        function TreeSelectionChanged(app, event)
            
            idxData = find(strcmp(app.ArquivoDropDown.Items, app.ArquivoDropDown.Value), 1);
            selectedECD = app.ecdObj(idxData);

            fichaNome = ['x' app.Tree.SelectedNodes.Text];
            
            app.UITable.Data = selectedECD.Table.(fichaNome);
            app.UITable.ColumnName = app.UITable.Data.Properties.VariableNames;

        end

        % Button pushed function: LerfichasButton
        function LerfichasButtonPushed(app, event)
            
            app.progressDialog.Visible = 'visible';

            try
                idxData = find(strcmp(app.ArquivoDropDown.Items, app.ArquivoDropDown.Value), 1);
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

        % Image clicked function: tool_ControlPanelVisibility
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

        % Image clicked function: selecaoCelula, selecaoColuna, 
        % ...and 1 other component
        function Image3Clicked(app, event)
            
            switch event.Source
                case app.selecaoLinha
                    app.UITable.SelectionType = "row";

                case app.selecaoColuna
                    app.UITable.SelectionType = "column";

                case app.selecaoCelula
                    app.UITable.SelectionType = "cell";
            end

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
            app.GridLayout.ColumnWidth = {5, 320, 10, '1x', 22, 22, 22, 5};
            app.GridLayout.RowHeight = {5, 63, 16, 10, '0.4x', 5, 34};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create panelGrid
            app.panelGrid = uigridlayout(app.GridLayout);
            app.panelGrid.ColumnWidth = {'1x'};
            app.panelGrid.RowHeight = {26, 5, '1x'};
            app.panelGrid.RowSpacing = 0;
            app.panelGrid.Padding = [0 0 0 0];
            app.panelGrid.Layout.Row = [2 5];
            app.panelGrid.Layout.Column = 2;
            app.panelGrid.BackgroundColor = [1 1 1];

            % Create ControlTabGroup
            app.ControlTabGroup = uitabgroup(app.panelGrid);
            app.ControlTabGroup.AutoResizeChildren = 'off';
            app.ControlTabGroup.Layout.Row = [1 3];
            app.ControlTabGroup.Layout.Column = 1;

            % Create Tab_1
            app.Tab_1 = uitab(app.ControlTabGroup);

            % Create Tab1_Grid
            app.Tab1_Grid = uigridlayout(app.Tab_1);
            app.Tab1_Grid.ColumnWidth = {90, '1x'};
            app.Tab1_Grid.RowHeight = {36, 59, '1x'};
            app.Tab1_Grid.ColumnSpacing = 5;
            app.Tab1_Grid.RowSpacing = 5;
            app.Tab1_Grid.Padding = [0 0 0 8];
            app.Tab1_Grid.BackgroundColor = [1 1 1];

            % Create LerfichasButton
            app.LerfichasButton = uibutton(app.Tab1_Grid, 'push');
            app.LerfichasButton.ButtonPushedFcn = createCallbackFcn(app, @LerfichasButtonPushed, true);
            app.LerfichasButton.WordWrap = 'on';
            app.LerfichasButton.Enable = 'off';
            app.LerfichasButton.Layout.Row = 2;
            app.LerfichasButton.Layout.Column = [1 2];
            app.LerfichasButton.Text = 'Ler fichas';

            % Create Tree
            app.Tree = uitree(app.Tab1_Grid);
            app.Tree.SelectionChangedFcn = createCallbackFcn(app, @TreeSelectionChanged, true);
            app.Tree.Layout.Row = 3;
            app.Tree.Layout.Column = [1 2];

            % Create ArquivoDropDownLabel
            app.ArquivoDropDownLabel = uilabel(app.Tab1_Grid);
            app.ArquivoDropDownLabel.Layout.Row = 1;
            app.ArquivoDropDownLabel.Layout.Column = 1;
            app.ArquivoDropDownLabel.Text = 'Arquivo:';

            % Create ArquivoDropDown
            app.ArquivoDropDown = uidropdown(app.Tab1_Grid);
            app.ArquivoDropDown.Items = {};
            app.ArquivoDropDown.ValueChangedFcn = createCallbackFcn(app, @ArquivoDropDownValueChanged, true);
            app.ArquivoDropDown.Layout.Row = 1;
            app.ArquivoDropDown.Layout.Column = 2;
            app.ArquivoDropDown.Value = {};

            % Create menu_MainGrid
            app.menu_MainGrid = uigridlayout(app.panelGrid);
            app.menu_MainGrid.ColumnWidth = {'1x', 22, 22};
            app.menu_MainGrid.RowHeight = {'1x', 3};
            app.menu_MainGrid.ColumnSpacing = 2;
            app.menu_MainGrid.RowSpacing = 0;
            app.menu_MainGrid.Padding = [0 0 0 0];
            app.menu_MainGrid.Layout.Row = 1;
            app.menu_MainGrid.Layout.Column = 1;
            app.menu_MainGrid.BackgroundColor = [1 1 1];

            % Create menuUnderline
            app.menuUnderline = uiimage(app.menu_MainGrid);
            app.menuUnderline.ScaleMethod = 'none';
            app.menuUnderline.Layout.Row = 2;
            app.menuUnderline.Layout.Column = 1;
            app.menuUnderline.ImageSource = 'LineH.svg';

            % Create menu_Button1Grid
            app.menu_Button1Grid = uigridlayout(app.menu_MainGrid);
            app.menu_Button1Grid.ColumnWidth = {18, '1x'};
            app.menu_Button1Grid.RowHeight = {'1x'};
            app.menu_Button1Grid.ColumnSpacing = 3;
            app.menu_Button1Grid.Padding = [2 0 0 0];
            app.menu_Button1Grid.Layout.Row = 1;
            app.menu_Button1Grid.Layout.Column = 1;
            app.menu_Button1Grid.BackgroundColor = [0.749 0.749 0.749];

            % Create menu_Button1Label
            app.menu_Button1Label = uilabel(app.menu_Button1Grid);
            app.menu_Button1Label.FontSize = 11;
            app.menu_Button1Label.Layout.Row = 1;
            app.menu_Button1Label.Layout.Column = 2;
            app.menu_Button1Label.Text = 'ECD';

            % Create menu_Button1Icon
            app.menu_Button1Icon = uiimage(app.menu_Button1Grid);
            app.menu_Button1Icon.ScaleMethod = 'none';
            app.menu_Button1Icon.Tag = '1';
            app.menu_Button1Icon.Layout.Row = 1;
            app.menu_Button1Icon.Layout.Column = [1 2];
            app.menu_Button1Icon.HorizontalAlignment = 'left';
            app.menu_Button1Icon.ImageSource = 'mosaic_18Gray.png';

            % Create menu_Button2Grid
            app.menu_Button2Grid = uigridlayout(app.menu_MainGrid);
            app.menu_Button2Grid.ColumnWidth = {18, 0};
            app.menu_Button2Grid.RowHeight = {'1x'};
            app.menu_Button2Grid.ColumnSpacing = 3;
            app.menu_Button2Grid.Padding = [2 0 0 0];
            app.menu_Button2Grid.Layout.Row = 1;
            app.menu_Button2Grid.Layout.Column = 2;
            app.menu_Button2Grid.BackgroundColor = [0.749 0.749 0.749];

            % Create menu_Button2Label
            app.menu_Button2Label = uilabel(app.menu_Button2Grid);
            app.menu_Button2Label.FontSize = 11;
            app.menu_Button2Label.Layout.Row = 1;
            app.menu_Button2Label.Layout.Column = 2;
            app.menu_Button2Label.Text = 'FILTRAGEM';

            % Create menu_Button2Icon
            app.menu_Button2Icon = uiimage(app.menu_Button2Grid);
            app.menu_Button2Icon.ScaleMethod = 'none';
            app.menu_Button2Icon.Tag = '2';
            app.menu_Button2Icon.Layout.Row = 1;
            app.menu_Button2Icon.Layout.Column = [1 2];
            app.menu_Button2Icon.HorizontalAlignment = 'left';
            app.menu_Button2Icon.ImageSource = 'Filter_18.png';

            % Create menu_Button3Grid
            app.menu_Button3Grid = uigridlayout(app.menu_MainGrid);
            app.menu_Button3Grid.ColumnWidth = {18, 0};
            app.menu_Button3Grid.RowHeight = {'1x'};
            app.menu_Button3Grid.ColumnSpacing = 3;
            app.menu_Button3Grid.Padding = [2 0 0 0];
            app.menu_Button3Grid.Layout.Row = 1;
            app.menu_Button3Grid.Layout.Column = 3;
            app.menu_Button3Grid.BackgroundColor = [0.749 0.749 0.749];

            % Create menu_Button3Label
            app.menu_Button3Label = uilabel(app.menu_Button3Grid);
            app.menu_Button3Label.FontSize = 11;
            app.menu_Button3Label.Layout.Row = 1;
            app.menu_Button3Label.Layout.Column = 2;
            app.menu_Button3Label.Text = 'CONFIGURAÇÕES GERAIS';

            % Create menu_Button3Icon
            app.menu_Button3Icon = uiimage(app.menu_Button3Grid);
            app.menu_Button3Icon.ScaleMethod = 'none';
            app.menu_Button3Icon.Tag = '3';
            app.menu_Button3Icon.Layout.Row = 1;
            app.menu_Button3Icon.Layout.Column = [1 2];
            app.menu_Button3Icon.HorizontalAlignment = 'left';
            app.menu_Button3Icon.ImageSource = 'Settings_18.png';

            % Create UITable
            app.UITable = uitable(app.GridLayout);
            app.UITable.ColumnName = '';
            app.UITable.ColumnRearrangeable = 'on';
            app.UITable.RowName = {};
            app.UITable.ColumnSortable = true;
            app.UITable.ColumnEditable = true;
            app.UITable.ForegroundColor = [0.149 0.149 0.149];
            app.UITable.Layout.Row = 5;
            app.UITable.Layout.Column = [4 7];
            app.UITable.FontSize = 10.5;

            % Create toolGrid
            app.toolGrid = uigridlayout(app.GridLayout);
            app.toolGrid.ColumnWidth = {22, 22, 22, 22, 5, 22, '1x', 18};
            app.toolGrid.RowHeight = {4, 17, 2};
            app.toolGrid.ColumnSpacing = 5;
            app.toolGrid.RowSpacing = 0;
            app.toolGrid.Padding = [0 5 5 5];
            app.toolGrid.Layout.Row = 7;
            app.toolGrid.Layout.Column = [1 8];
            app.toolGrid.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create tool_ControlPanelVisibility
            app.tool_ControlPanelVisibility = uiimage(app.toolGrid);
            app.tool_ControlPanelVisibility.ImageClickedFcn = createCallbackFcn(app, @tool_InteractionImageClicked, true);
            app.tool_ControlPanelVisibility.Layout.Row = 2;
            app.tool_ControlPanelVisibility.Layout.Column = 1;
            app.tool_ControlPanelVisibility.ImageSource = 'ArrowLeft_32.png';

            % Create tool_TableVisibility
            app.tool_TableVisibility = uiimage(app.toolGrid);
            app.tool_TableVisibility.ScaleMethod = 'none';
            app.tool_TableVisibility.Tooltip = {'Visibilidade da tabela'};
            app.tool_TableVisibility.Layout.Row = 2;
            app.tool_TableVisibility.Layout.Column = 2;
            app.tool_TableVisibility.ImageSource = 'View_16.png';

            % Create tool_RFLinkButton
            app.tool_RFLinkButton = uiimage(app.toolGrid);
            app.tool_RFLinkButton.ScaleMethod = 'none';
            app.tool_RFLinkButton.Tooltip = {'Perfil de terreno entre registro selecionado (TX) '; 'e estação de referência (RX)'};
            app.tool_RFLinkButton.Layout.Row = 2;
            app.tool_RFLinkButton.Layout.Column = 3;
            app.tool_RFLinkButton.VerticalAlignment = 'top';
            app.tool_RFLinkButton.ImageSource = 'Publish_HTML_16.png';

            % Create tool_PDFButton
            app.tool_PDFButton = uiimage(app.toolGrid);
            app.tool_PDFButton.ScaleMethod = 'none';
            app.tool_PDFButton.Tooltip = {'Documento relacionado ao registro selecionado'; '(limitado à radiodifusão)'};
            app.tool_PDFButton.Layout.Row = 2;
            app.tool_PDFButton.Layout.Column = 4;
            app.tool_PDFButton.VerticalAlignment = 'top';
            app.tool_PDFButton.ImageSource = 'Publish_PDF_16.png';

            % Create tool_Separator
            app.tool_Separator = uiimage(app.toolGrid);
            app.tool_Separator.Enable = 'off';
            app.tool_Separator.Layout.Row = [1 3];
            app.tool_Separator.Layout.Column = 5;
            app.tool_Separator.VerticalAlignment = 'bottom';
            app.tool_Separator.ImageSource = 'LineV.png';

            % Create tool_ExportButton
            app.tool_ExportButton = uiimage(app.toolGrid);
            app.tool_ExportButton.ScaleMethod = 'none';
            app.tool_ExportButton.Layout.Row = 2;
            app.tool_ExportButton.Layout.Column = 6;
            app.tool_ExportButton.ImageSource = 'Export_16.png';

            % Create tool_tableNRows
            app.tool_tableNRows = uilabel(app.toolGrid);
            app.tool_tableNRows.HorizontalAlignment = 'right';
            app.tool_tableNRows.FontSize = 10;
            app.tool_tableNRows.FontColor = [0.6 0.6 0.6];
            app.tool_tableNRows.Layout.Row = [1 3];
            app.tool_tableNRows.Layout.Column = 7;
            app.tool_tableNRows.Text = '';

            % Create tool_tableNRowsIcon
            app.tool_tableNRowsIcon = uiimage(app.toolGrid);
            app.tool_tableNRowsIcon.ScaleMethod = 'none';
            app.tool_tableNRowsIcon.Enable = 'off';
            app.tool_tableNRowsIcon.Layout.Row = 2;
            app.tool_tableNRowsIcon.Layout.Column = 8;
            app.tool_tableNRowsIcon.ImageSource = 'Filter_18.png';

            % Create tableInfoMetadata
            app.tableInfoMetadata = uilabel(app.GridLayout);
            app.tableInfoMetadata.VerticalAlignment = 'top';
            app.tableInfoMetadata.WordWrap = 'on';
            app.tableInfoMetadata.FontSize = 14;
            app.tableInfoMetadata.Layout.Row = 2;
            app.tableInfoMetadata.Layout.Column = [4 7];
            app.tableInfoMetadata.Interpreter = 'html';
            app.tableInfoMetadata.Text = {'Exibindo emissões relacionadas aos fluxos espectrais'; '<p style="color: #808080; font-size:10px; text-align: justify; margin-right: 2px;">A célula "Frequência (MHz)" apresentará <font style="color: red;">ÍCONE DE EDIÇÃO</font> toda vez que alterada a classificação da emissão. Além disso, a célula "Frequência canal (MHz)" apresentará <font style="color: red;">ÍCONE VERMELHO</font> toda vez que o nº da estação for igual a -1, o que ocorre quando a situação da emissão é "Licenciada UTE", "Não licenciada" ou "Não passível de licenciamento", ou quando essa informação não consta na base de dados.</p>'};

            % Create selecaoCelula
            app.selecaoCelula = uiimage(app.GridLayout);
            app.selecaoCelula.ScaleMethod = 'none';
            app.selecaoCelula.ImageClickedFcn = createCallbackFcn(app, @Image3Clicked, true);
            app.selecaoCelula.Layout.Row = [3 4];
            app.selecaoCelula.Layout.Column = 7;
            app.selecaoCelula.ImageSource = 'Dots_18.png';

            % Create selecaoColuna
            app.selecaoColuna = uiimage(app.GridLayout);
            app.selecaoColuna.ScaleMethod = 'none';
            app.selecaoColuna.ImageClickedFcn = createCallbackFcn(app, @Image3Clicked, true);
            app.selecaoColuna.Layout.Row = [3 4];
            app.selecaoColuna.Layout.Column = 6;
            app.selecaoColuna.ImageSource = 'Filter_18.png';

            % Create selecaoLinha
            app.selecaoLinha = uiimage(app.GridLayout);
            app.selecaoLinha.ScaleMethod = 'none';
            app.selecaoLinha.ImageClickedFcn = createCallbackFcn(app, @Image3Clicked, true);
            app.selecaoLinha.Layout.Row = [3 4];
            app.selecaoLinha.Layout.Column = 5;
            app.selecaoLinha.ImageSource = 'error.svg';

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
