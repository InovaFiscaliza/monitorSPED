classdef winECD_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        editionFontContainer          matlab.ui.container.Panel
        GridLayout                    matlab.ui.container.GridLayout
        EXIBIDASTODASAS22LINHASLabel  matlab.ui.control.Label
        Image5                        matlab.ui.control.Image
        Label                         matlab.ui.control.Label
        Image6                        matlab.ui.control.Image
        TabGroup                      matlab.ui.container.TabGroup
        ASPECTOSGERAISTab             matlab.ui.container.Tab
        GridLayout3                   matlab.ui.container.GridLayout
        Hyperlink                     matlab.ui.control.Hyperlink
        TreeDropDown_2                matlab.ui.control.DropDown
        FichaLabel                    matlab.ui.control.Label
        PerodofiscalLabel             matlab.ui.control.Label
        TreeDropDown                  matlab.ui.control.DropDown
        EmpresaLabel                  matlab.ui.control.Label
        ArquivodedadosDropDown        matlab.ui.control.DropDown
        LAYOUTTab                     matlab.ui.container.Tab
        GridLayout_2                  matlab.ui.container.GridLayout
        Image_6                       matlab.ui.control.Image
        Image_5                       matlab.ui.control.Image
        Image_4                       matlab.ui.control.Image
        ColorPicker_2                 matlab.ui.control.ColorPicker
        ColorPicker                   matlab.ui.control.ColorPicker
        DropDown_5                    matlab.ui.control.DropDown
        DropDown_4                    matlab.ui.control.DropDown
        Image_3                       matlab.ui.control.Image
        Image_2                       matlab.ui.control.Image
        Image                         matlab.ui.control.Image
        FILTRAGEMTab                  matlab.ui.container.Tab
        GridLayout4                   matlab.ui.container.GridLayout
        filter_SecondaryTextList_2    matlab.ui.control.DropDown
        filter_SecondaryTextList      matlab.ui.control.DropDown
        EditField_2                   matlab.ui.control.EditField
        EditField                     matlab.ui.control.EditField
        DropDown_10                   matlab.ui.control.DropDown
        DropDown_9                    matlab.ui.control.DropDown
        DropDown_8                    matlab.ui.control.DropDown
        DropDown_7                    matlab.ui.control.DropDown
        CheckBox                      matlab.ui.control.CheckBox
        DropDown_6                    matlab.ui.control.DropDown
        Image4_3                      matlab.ui.control.Image
        TABELACUSTOMIZADATab          matlab.ui.container.Tab
        UITable                       matlab.ui.control.Table
        UITable2                      matlab.ui.control.Table
        toolGrid                      matlab.ui.container.GridLayout
        NOMEDAEMPRESAMetadadosOutrascoisasLabel_2  matlab.ui.control.Label
        tool_tableNRowsIcon           matlab.ui.control.Image
        tool_ExportButton             matlab.ui.control.Image
        tool_Separator                matlab.ui.control.Image
        tool_RFLinkButton             matlab.ui.control.Image
        filter_ContextMenu            matlab.ui.container.ContextMenu
        filter_delButton              matlab.ui.container.Menu
        filter_delAllButton           matlab.ui.container.Menu
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
                            pause(1)
                            app.editionFontContainer.UserData.id = struct(app.editionFontContainer).Controller.ViewModel.Id;

                            sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', {        ...
                                struct('appName',    appName,                                      ...
                                       'dataTag',    app.editionFontContainer.UserData.id,         ...
                                       'generation', 0,                                            ...
                                       'style',      struct('borderRadius', '5px',                 ...
                                                            'boxShadow', '0 2px 5px 1px #a6a6a6')) ...
                            });

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

            app.UITable.RowName = 'numbered';
            app.UITable.UserData = struct('Selection', [], 'SelectionType', 'none');

            % app.Image3.UserData = false;
            % app.DropDown.Items = listfonts;
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

        % Callback function: Hyperlink, tool_RFLinkButton
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

        % Callback function
        function Image3Clicked2(app, event)
            pause(1)
        end

        % Clicked callback: UITable, UITable2
        function UIFigureWindowButtonDown(app, event)
            
            clickedRow  = event.InteractionInformation.DisplayRow;
            clickedCol  = event.InteractionInformation.DisplayColumn;

            if isempty(clickedRow) && isempty(clickedCol) 
                if ~isempty(app.UITable.Selection)
                    app.UITable.UserData.SelectionType = 'none';
                    
                    app.UITable.Selection = [];
                    drawnow                    
                end

            elseif isempty(clickedCol)
                app.UITable.UserData.SelectionType = 'row';

            elseif isempty(clickedRow)
                app.UITable.UserData.SelectionType = 'column';

            else
                app.UITable.UserData.SelectionType = 'cell';            
            end
            

            if ~isequal(app.UITable.Selection, app.UITable.UserData.Selection)
                app.UITable.UserData.Selection = app.UITable.Selection;

                if isempty(app.UITable.Selection)
                    app.Label.Text = '  CONTAGEM: 0';

                else
                    selectedCols = unique(app.UITable.Selection(:, 2));
                    selectedColsNames = app.UITable.Data.Properties.VariableNames(selectedCols);
    
                    isNumeric = true;
                    for ii = 1:numel(selectedColsNames)
                        if ~isnumeric(app.UITable.Data.(selectedColsNames{ii}))
                            isNumeric = false;
                            break;
                        end
                    end
    
                    cellsCount = height(app.UITable.Selection);
                    if isNumeric
                        switch app.UITable.UserData.SelectionType
                            case 'column'
                                cellsSum = sum(double(app.UITable.Data{:, selectedCols}), 'all');
                                cellsAverage = mean(double(app.UITable.Data{:, selectedCols}), 'all');
    
                            otherwise
                                cellsSum = 0;
                                for kk = 1:cellsCount
                                    cellsSum = cellsSum + double(app.UITable.Data{app.UITable.Selection(kk, 1), app.UITable.Selection(kk, 2)});
                                end
                                cellsAverage = cellsSum/cellsCount;
                        end
    
                        app.Label.Text = sprintf('  CONTAGEM: %d     SOMA: %.2f     MÉDIA: %.2f', cellsCount, cellsSum, cellsAverage);
                    else
                        app.Label.Text = sprintf('  CONTAGEM: %d', cellsCount);
                    end
                end
            end





            % switch event.Source
            %     case app.UIFigure
            %         clickedObject = struct(event).HitObject;
            % 
            %         switch clickedObject
            %             case app.Image3
            %                 app.Image3.UserData = ~app.Image3.UserData;
            % 
            %                 if app.Image3.UserData
            %                     imgWidth  = 260;
            %                     imgHeight = 70;
            %                     imgXPos   = app.Image3.Parent.Position(1) + app.Image3.Position(1) - imgWidth + 18 - 1;
            %                     imgYPos   = app.Image3.Parent.Position(2) + app.Image3.Position(2) - imgHeight - 3;
            % 
            %                     app.editionFontContainer.Position = [imgXPos imgYPos imgWidth imgHeight];
            %                     app.editionFontContainer.Visible  = true;
            % 
            %                 else
            %                     if app.editionFontContainer.Visible
            %                         app.editionFontContainer.Visible = false;
            %                     end
            %                 end
            % 
            %             otherwise
            %                 if clickedObject == app.editionFontContainer
            %                     return
            %                 elseif clickedObject.Parent == app.GridLayout_2
            %                     return
            %                 end
            % 
            %                 if app.Image3.UserData
            %                     app.Image3.UserData = false;
            % 
            %                     if app.editionFontContainer.Visible
            %                         app.editionFontContainer.Visible = false;
            %                     end
            %                 end
            %         end
            % 
            %     otherwise
            %         if app.Image3.UserData
            %             app.Image3.UserData = false;
            % 
            %             if app.editionFontContainer.Visible
            %                 app.editionFontContainer.Visible = false;
            %             end
            %         end
            % end

        end

        % Callback function
        function UIFigureSizeChanged(app, event)

            % if app.Image3.UserData
            %     app.Image3.UserData = false;
            % 
            %     if app.editionFontContainer.Visible
            %         app.editionFontContainer.Visible = false;
            %     end
            % end
            
        end

        % Cell selection callback: UITable
        function UITableCellSelection(app, event)

            
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
            app.GridLayout.ColumnWidth = {5, 18, 320, 5, 90, 5, 5, 5, '1x', 5, 5, 5, 330, 18, 5};
            app.GridLayout.RowHeight = {7, 84, 10, '0.4x', 2, 18, 10, 160, 5, 34};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create toolGrid
            app.toolGrid = uigridlayout(app.GridLayout);
            app.toolGrid.ColumnWidth = {22, 22, 5, 22, '1x'};
            app.toolGrid.RowHeight = {4, 17, 2};
            app.toolGrid.ColumnSpacing = 5;
            app.toolGrid.RowSpacing = 0;
            app.toolGrid.Padding = [2 5 5 5];
            app.toolGrid.Layout.Row = 10;
            app.toolGrid.Layout.Column = [1 15];
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
            app.tool_Separator.ScaleMethod = 'none';
            app.tool_Separator.Enable = 'off';
            app.tool_Separator.Layout.Row = [1 3];
            app.tool_Separator.Layout.Column = 3;
            app.tool_Separator.VerticalAlignment = 'bottom';
            app.tool_Separator.ImageSource = 'LineV.svg';

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

            % Create NOMEDAEMPRESAMetadadosOutrascoisasLabel_2
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2 = uilabel(app.toolGrid);
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.HorizontalAlignment = 'right';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.VerticalAlignment = 'top';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.WordWrap = 'on';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.FontSize = 9;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.FontColor = [0.149 0.149 0.149];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Layout.Row = [1 3];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Layout.Column = 5;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Interpreter = 'html';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Text = {'<font style="font-size: 11px; font-weight: bold;">NOME DA EMPRESA</font> CNPJ 10.101.101/0001-02 '; '01/01/2023 - 31/12/2023 '};

            % Create UITable2
            app.UITable2 = uitable(app.GridLayout);
            app.UITable2.BackgroundColor = [1 1 1;0.9412 0.9412 0.9412];
            app.UITable2.ColumnName = {'TABELA APURAÇÃO'};
            app.UITable2.RowName = {};
            app.UITable2.ClickedFcn = createCallbackFcn(app, @UIFigureWindowButtonDown, true);
            app.UITable2.ForegroundColor = [0.149 0.149 0.149];
            app.UITable2.Layout.Row = 8;
            app.UITable2.Layout.Column = [2 14];
            app.UITable2.FontSize = 10.5;

            % Create UITable
            app.UITable = uitable(app.GridLayout);
            app.UITable.ColumnName = '';
            app.UITable.ColumnSortable = true;
            app.UITable.CellSelectionCallback = createCallbackFcn(app, @UITableCellSelection, true);
            app.UITable.ClickedFcn = createCallbackFcn(app, @UIFigureWindowButtonDown, true);
            app.UITable.ForegroundColor = [0.149 0.149 0.149];
            app.UITable.Layout.Row = 4;
            app.UITable.Layout.Column = [2 14];
            app.UITable.FontSize = 10.5;

            % Create TabGroup
            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.AutoResizeChildren = 'off';
            app.TabGroup.Layout.Row = 2;
            app.TabGroup.Layout.Column = [2 14];

            % Create ASPECTOSGERAISTab
            app.ASPECTOSGERAISTab = uitab(app.TabGroup);
            app.ASPECTOSGERAISTab.AutoResizeChildren = 'off';
            app.ASPECTOSGERAISTab.Title = 'ℹ ASPECTOS GERAIS';
            app.ASPECTOSGERAISTab.BackgroundColor = 'none';

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.ASPECTOSGERAISTab);
            app.GridLayout3.ColumnWidth = {90, 220, 70, 110, '1x', 110};
            app.GridLayout3.RowHeight = {22, 22};
            app.GridLayout3.RowSpacing = 5;
            app.GridLayout3.Padding = [5 5 5 6];
            app.GridLayout3.BackgroundColor = [0.9608 0.9608 0.9608];

            % Create ArquivodedadosDropDown
            app.ArquivodedadosDropDown = uidropdown(app.GridLayout3);
            app.ArquivodedadosDropDown.Items = {};
            app.ArquivodedadosDropDown.ValueChangedFcn = createCallbackFcn(app, @ArquivodedadosDropDownValueChanged, true);
            app.ArquivodedadosDropDown.FontSize = 11;
            app.ArquivodedadosDropDown.FontColor = [0.149 0.149 0.149];
            app.ArquivodedadosDropDown.BackgroundColor = [1 1 1];
            app.ArquivodedadosDropDown.Layout.Row = 1;
            app.ArquivodedadosDropDown.Layout.Column = [2 4];
            app.ArquivodedadosDropDown.Value = {};

            % Create EmpresaLabel
            app.EmpresaLabel = uilabel(app.GridLayout3);
            app.EmpresaLabel.FontSize = 11;
            app.EmpresaLabel.FontColor = [0.149 0.149 0.149];
            app.EmpresaLabel.Layout.Row = 1;
            app.EmpresaLabel.Layout.Column = 1;
            app.EmpresaLabel.Text = 'Empresa:';

            % Create TreeDropDown
            app.TreeDropDown = uidropdown(app.GridLayout3);
            app.TreeDropDown.Items = {};
            app.TreeDropDown.ValueChangedFcn = createCallbackFcn(app, @TreeSelectionChanged, true);
            app.TreeDropDown.FontSize = 11;
            app.TreeDropDown.FontColor = [0.149 0.149 0.149];
            app.TreeDropDown.BackgroundColor = [1 1 1];
            app.TreeDropDown.Layout.Row = 2;
            app.TreeDropDown.Layout.Column = 4;
            app.TreeDropDown.Value = {};

            % Create PerodofiscalLabel
            app.PerodofiscalLabel = uilabel(app.GridLayout3);
            app.PerodofiscalLabel.FontSize = 11;
            app.PerodofiscalLabel.FontColor = [0.149 0.149 0.149];
            app.PerodofiscalLabel.Layout.Row = 2;
            app.PerodofiscalLabel.Layout.Column = 1;
            app.PerodofiscalLabel.Text = 'Período fiscal:';

            % Create FichaLabel
            app.FichaLabel = uilabel(app.GridLayout3);
            app.FichaLabel.FontSize = 11;
            app.FichaLabel.FontColor = [0.149 0.149 0.149];
            app.FichaLabel.Layout.Row = 2;
            app.FichaLabel.Layout.Column = 3;
            app.FichaLabel.Text = 'Ficha:';

            % Create TreeDropDown_2
            app.TreeDropDown_2 = uidropdown(app.GridLayout3);
            app.TreeDropDown_2.Items = {};
            app.TreeDropDown_2.FontSize = 11;
            app.TreeDropDown_2.FontColor = [0.149 0.149 0.149];
            app.TreeDropDown_2.BackgroundColor = [1 1 1];
            app.TreeDropDown_2.Layout.Row = 2;
            app.TreeDropDown_2.Layout.Column = 2;
            app.TreeDropDown_2.Value = {};

            % Create Hyperlink
            app.Hyperlink = uihyperlink(app.GridLayout3);
            app.Hyperlink.HyperlinkClickedFcn = createCallbackFcn(app, @LerfichasButtonPushed, true);
            app.Hyperlink.VisitedColor = [1 0 0];
            app.Hyperlink.HorizontalAlignment = 'right';
            app.Hyperlink.VerticalAlignment = 'bottom';
            app.Hyperlink.FontSize = 10;
            app.Hyperlink.FontColor = [1 0 0];
            app.Hyperlink.Layout.Row = 2;
            app.Hyperlink.Layout.Column = 6;
            app.Hyperlink.Text = ' Ler todas as fichas ';

            % Create LAYOUTTab
            app.LAYOUTTab = uitab(app.TabGroup);
            app.LAYOUTTab.AutoResizeChildren = 'off';
            app.LAYOUTTab.Title = '✎ LAYOUT';
            app.LAYOUTTab.BackgroundColor = 'none';

            % Create GridLayout_2
            app.GridLayout_2 = uigridlayout(app.LAYOUTTab);
            app.GridLayout_2.ColumnWidth = {22, 22, 22, 22, 22, 22, 36, 36, 3, '1x'};
            app.GridLayout_2.RowHeight = {22, 22};
            app.GridLayout_2.RowSpacing = 5;
            app.GridLayout_2.Padding = [5 5 5 6];
            app.GridLayout_2.BackgroundColor = [0.9608 0.9608 0.9608];

            % Create Image
            app.Image = uiimage(app.GridLayout_2);
            app.Image.ScaleMethod = 'none';
            app.Image.BackgroundColor = [0.9412 0.9412 0.9412];
            app.Image.Tooltip = {'Negrito'};
            app.Image.Layout.Row = 2;
            app.Image.Layout.Column = 1;
            app.Image.ImageSource = '_Bold.png';

            % Create Image_2
            app.Image_2 = uiimage(app.GridLayout_2);
            app.Image_2.ScaleMethod = 'none';
            app.Image_2.BackgroundColor = [0.9412 0.9412 0.9412];
            app.Image_2.Tooltip = {'Itálico'};
            app.Image_2.Layout.Row = 2;
            app.Image_2.Layout.Column = 2;
            app.Image_2.ImageSource = '_Italic.png';

            % Create Image_3
            app.Image_3 = uiimage(app.GridLayout_2);
            app.Image_3.ScaleMethod = 'none';
            app.Image_3.BackgroundColor = [0.9412 0.9412 0.9412];
            app.Image_3.Tooltip = {'Sublinhado'};
            app.Image_3.Layout.Row = 2;
            app.Image_3.Layout.Column = 3;
            app.Image_3.ImageSource = '_Underline.png';

            % Create DropDown_4
            app.DropDown_4 = uidropdown(app.GridLayout_2);
            app.DropDown_4.Items = {};
            app.DropDown_4.Tooltip = {'Fonte'};
            app.DropDown_4.FontSize = 11;
            app.DropDown_4.BackgroundColor = [1 1 1];
            app.DropDown_4.Layout.Row = 1;
            app.DropDown_4.Layout.Column = [1 6];
            app.DropDown_4.Value = {};

            % Create DropDown_5
            app.DropDown_5 = uidropdown(app.GridLayout_2);
            app.DropDown_5.Items = {'10', '11', '12', '13', '14'};
            app.DropDown_5.Tooltip = {'Tamanho da fonte'};
            app.DropDown_5.FontSize = 11;
            app.DropDown_5.BackgroundColor = [1 1 1];
            app.DropDown_5.Layout.Row = 1;
            app.DropDown_5.Layout.Column = [7 8];
            app.DropDown_5.Value = '10';

            % Create ColorPicker
            app.ColorPicker = uicolorpicker(app.GridLayout_2);
            app.ColorPicker.Icon = '_Background.png';
            app.ColorPicker.Layout.Row = 2;
            app.ColorPicker.Layout.Column = 7;
            app.ColorPicker.BackgroundColor = [1 1 1];

            % Create ColorPicker_2
            app.ColorPicker_2 = uicolorpicker(app.GridLayout_2);
            app.ColorPicker_2.Icon = '_Color.png';
            app.ColorPicker_2.Layout.Row = 2;
            app.ColorPicker_2.Layout.Column = 8;
            app.ColorPicker_2.BackgroundColor = [1 1 1];

            % Create Image_4
            app.Image_4 = uiimage(app.GridLayout_2);
            app.Image_4.ScaleMethod = 'none';
            app.Image_4.Tooltip = {'Sublinhado'};
            app.Image_4.Layout.Row = 2;
            app.Image_4.Layout.Column = 4;
            app.Image_4.ImageSource = 'left-align-18.png';

            % Create Image_5
            app.Image_5 = uiimage(app.GridLayout_2);
            app.Image_5.ScaleMethod = 'none';
            app.Image_5.Tooltip = {'Sublinhado'};
            app.Image_5.Layout.Row = 2;
            app.Image_5.Layout.Column = 5;
            app.Image_5.ImageSource = 'center-align-18.png';

            % Create Image_6
            app.Image_6 = uiimage(app.GridLayout_2);
            app.Image_6.ScaleMethod = 'none';
            app.Image_6.Tooltip = {'Sublinhado'};
            app.Image_6.Layout.Row = 2;
            app.Image_6.Layout.Column = 6;
            app.Image_6.ImageSource = 'right-align-18.png';

            % Create FILTRAGEMTab
            app.FILTRAGEMTab = uitab(app.TabGroup);
            app.FILTRAGEMTab.AutoResizeChildren = 'off';
            app.FILTRAGEMTab.Title = '⤯ FILTRAGEM';
            app.FILTRAGEMTab.BackgroundColor = 'none';

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.FILTRAGEMTab);
            app.GridLayout4.ColumnWidth = {14, 40, 206, 40, 270, 3, '1x'};
            app.GridLayout4.RowHeight = {22, 22};
            app.GridLayout4.RowSpacing = 5;
            app.GridLayout4.Padding = [5 5 5 6];
            app.GridLayout4.BackgroundColor = [0.9608 0.9608 0.9608];

            % Create Image4_3
            app.Image4_3 = uiimage(app.GridLayout4);
            app.Image4_3.Enable = 'off';
            app.Image4_3.Layout.Row = [1 2];
            app.Image4_3.Layout.Column = 6;
            app.Image4_3.ImageSource = 'LineV.svg';

            % Create DropDown_6
            app.DropDown_6 = uidropdown(app.GridLayout4);
            app.DropDown_6.Items = {'Coluna 1'};
            app.DropDown_6.FontSize = 11;
            app.DropDown_6.BackgroundColor = [1 1 1];
            app.DropDown_6.Layout.Row = 1;
            app.DropDown_6.Layout.Column = [1 3];
            app.DropDown_6.Value = 'Coluna 1';

            % Create CheckBox
            app.CheckBox = uicheckbox(app.GridLayout4);
            app.CheckBox.Text = '';
            app.CheckBox.Layout.Row = 2;
            app.CheckBox.Layout.Column = 1;

            % Create DropDown_7
            app.DropDown_7 = uidropdown(app.GridLayout4);
            app.DropDown_7.Items = {'&', '||'};
            app.DropDown_7.Enable = 'off';
            app.DropDown_7.FontSize = 11;
            app.DropDown_7.BackgroundColor = [1 1 1];
            app.DropDown_7.Layout.Row = 2;
            app.DropDown_7.Layout.Column = 2;
            app.DropDown_7.Value = '&';

            % Create DropDown_8
            app.DropDown_8 = uidropdown(app.GridLayout4);
            app.DropDown_8.Items = {'Coluna 2'};
            app.DropDown_8.Enable = 'off';
            app.DropDown_8.FontSize = 11;
            app.DropDown_8.BackgroundColor = [1 1 1];
            app.DropDown_8.Layout.Row = 2;
            app.DropDown_8.Layout.Column = 3;
            app.DropDown_8.Value = 'Coluna 2';

            % Create DropDown_9
            app.DropDown_9 = uidropdown(app.GridLayout4);
            app.DropDown_9.Items = {'=', '≈', '≠', '⊃', '⊅', '<', '≤', '>', '≥'};
            app.DropDown_9.FontSize = 11;
            app.DropDown_9.BackgroundColor = [1 1 1];
            app.DropDown_9.Layout.Row = 1;
            app.DropDown_9.Layout.Column = 4;
            app.DropDown_9.Value = '=';

            % Create DropDown_10
            app.DropDown_10 = uidropdown(app.GridLayout4);
            app.DropDown_10.Items = {'=', '≈', '≠', '⊃', '⊅', '<', '≤', '>', '≥'};
            app.DropDown_10.Enable = 'off';
            app.DropDown_10.FontSize = 11;
            app.DropDown_10.BackgroundColor = [1 1 1];
            app.DropDown_10.Layout.Row = 2;
            app.DropDown_10.Layout.Column = 4;
            app.DropDown_10.Value = '=';

            % Create EditField
            app.EditField = uieditfield(app.GridLayout4, 'text');
            app.EditField.FontSize = 11;
            app.EditField.Layout.Row = 1;
            app.EditField.Layout.Column = 5;

            % Create EditField_2
            app.EditField_2 = uieditfield(app.GridLayout4, 'text');
            app.EditField_2.FontSize = 11;
            app.EditField_2.Enable = 'off';
            app.EditField_2.Layout.Row = 2;
            app.EditField_2.Layout.Column = 5;

            % Create filter_SecondaryTextList
            app.filter_SecondaryTextList = uidropdown(app.GridLayout4);
            app.filter_SecondaryTextList.Items = {};
            app.filter_SecondaryTextList.Visible = 'off';
            app.filter_SecondaryTextList.FontSize = 11;
            app.filter_SecondaryTextList.BackgroundColor = [1 1 1];
            app.filter_SecondaryTextList.Layout.Row = 1;
            app.filter_SecondaryTextList.Layout.Column = 5;
            app.filter_SecondaryTextList.Value = {};

            % Create filter_SecondaryTextList_2
            app.filter_SecondaryTextList_2 = uidropdown(app.GridLayout4);
            app.filter_SecondaryTextList_2.Items = {};
            app.filter_SecondaryTextList_2.Enable = 'off';
            app.filter_SecondaryTextList_2.FontSize = 11;
            app.filter_SecondaryTextList_2.BackgroundColor = [1 1 1];
            app.filter_SecondaryTextList_2.Layout.Row = 2;
            app.filter_SecondaryTextList_2.Layout.Column = 5;
            app.filter_SecondaryTextList_2.Value = {};

            % Create TABELACUSTOMIZADATab
            app.TABELACUSTOMIZADATab = uitab(app.TabGroup);
            app.TABELACUSTOMIZADATab.Title = '⌗ TABELA CUSTOMIZADA';

            % Create Image6
            app.Image6 = uiimage(app.GridLayout);
            app.Image6.ScaleMethod = 'none';
            app.Image6.Layout.Row = 6;
            app.Image6.Layout.Column = 2;
            app.Image6.ImageSource = 'selectColumn.png';

            % Create Label
            app.Label = uilabel(app.GridLayout);
            app.Label.FontSize = 10;
            app.Label.FontColor = [0.502 0.502 0.502];
            app.Label.Layout.Row = 6;
            app.Label.Layout.Column = [3 9];
            app.Label.Text = '';

            % Create Image5
            app.Image5 = uiimage(app.GridLayout);
            app.Image5.ScaleMethod = 'none';
            app.Image5.Enable = 'off';
            app.Image5.Layout.Row = 6;
            app.Image5.Layout.Column = 14;
            app.Image5.ImageSource = 'Filter_18.png';

            % Create EXIBIDASTODASAS22LINHASLabel
            app.EXIBIDASTODASAS22LINHASLabel = uilabel(app.GridLayout);
            app.EXIBIDASTODASAS22LINHASLabel.HorizontalAlignment = 'right';
            app.EXIBIDASTODASAS22LINHASLabel.FontSize = 10;
            app.EXIBIDASTODASAS22LINHASLabel.FontColor = [0.502 0.502 0.502];
            app.EXIBIDASTODASAS22LINHASLabel.Layout.Row = 6;
            app.EXIBIDASTODASAS22LINHASLabel.Layout.Column = 13;
            app.EXIBIDASTODASAS22LINHASLabel.Text = 'EXIBIDAS TODAS AS 22 LINHAS  ';

            % Create editionFontContainer
            app.editionFontContainer = uipanel(app.UIFigure);
            app.editionFontContainer.AutoResizeChildren = 'off';
            app.editionFontContainer.BorderType = 'none';
            app.editionFontContainer.Visible = 'off';
            app.editionFontContainer.Position = [1260 4 260 70];

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
