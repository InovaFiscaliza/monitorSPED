classdef winECD_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        GridLayout                  matlab.ui.container.GridLayout
        Image5_2                    matlab.ui.control.Image
        DE0Label_2                  matlab.ui.control.Label
        CONTAGEM0Label_2            matlab.ui.control.Label
        Image6_2                    matlab.ui.control.Image
        DE0Label                    matlab.ui.control.Label
        Image5                      matlab.ui.control.Image
        CONTAGEM0Label              matlab.ui.control.Label
        Image6                      matlab.ui.control.Image
        TabGroup                    matlab.ui.container.TabGroup
        ASPECTOSGERAISTab           matlab.ui.container.Tab
        GridLayout3                 matlab.ui.container.GridLayout
        ReadAllSheets               matlab.ui.control.Hyperlink
        SheetList                   matlab.ui.control.DropDown
        SheetListLabel              matlab.ui.control.Label
        TimePeriodList              matlab.ui.control.DropDown
        TimePeriodListLabel         matlab.ui.control.Label
        CompanyNameList             matlab.ui.control.DropDown
        CompanyNameListLabel        matlab.ui.control.Label
        LAYOUTTab                   matlab.ui.container.Tab
        GridLayout_2                matlab.ui.container.GridLayout
        FontColor                   matlab.ui.control.ColorPicker
        FontBackground              matlab.ui.control.ColorPicker
        FontAlign3                  matlab.ui.control.Image
        FontAlign2                  matlab.ui.control.Image
        FontAlign1                  matlab.ui.control.Image
        FontUnderline               matlab.ui.control.Button
        FontStyle                   matlab.ui.control.Button
        FontWeight                  matlab.ui.control.Button
        FontSize                    matlab.ui.control.DropDown
        FontFamilyList              matlab.ui.control.DropDown
        Separator                   matlab.ui.control.Image
        SheetHeight_Second          matlab.ui.control.Spinner
        SheetView_Second            matlab.ui.control.DropDown
        SheetHeight_First           matlab.ui.control.Spinner
        SheetView_First             matlab.ui.control.DropDown
        SheetViewStatus             matlab.ui.control.StateButton
        FILTRAGEMTab                matlab.ui.container.Tab
        GridLayout4                 matlab.ui.container.GridLayout
        filter_SecondaryTextList_2  matlab.ui.control.DropDown
        filter_SecondaryTextList    matlab.ui.control.DropDown
        EditField_2                 matlab.ui.control.EditField
        EditField                   matlab.ui.control.EditField
        DropDown_10                 matlab.ui.control.DropDown
        DropDown_9                  matlab.ui.control.DropDown
        DropDown_8                  matlab.ui.control.DropDown
        DropDown_7                  matlab.ui.control.DropDown
        CheckBox                    matlab.ui.control.CheckBox
        DropDown_6                  matlab.ui.control.DropDown
        Image4_3                    matlab.ui.control.Image
        TABELACUSTOMIZADATab        matlab.ui.container.Tab
        UITable                     matlab.ui.control.Table
        UITable2                    matlab.ui.control.Table
        toolGrid                    matlab.ui.container.GridLayout
        NOMEDAEMPRESAMetadadosOutrascoisasLabel_2  matlab.ui.control.Label
        tool_tableNRowsIcon         matlab.ui.control.Image
        tool_ExportButton           matlab.ui.control.Image
        tool_Separator              matlab.ui.control.Image
        filter_ContextMenu          matlab.ui.container.ContextMenu
        filter_delButton            matlab.ui.container.Menu
        filter_delAllButton         matlab.ui.container.Menu
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
            if ~isempty(app.ecdObj)
                idsList = {app.ecdObj.CompanyId};                
                [ids, idsFirstIndexes] = unique(idsList, 'stable');
                idsNames = {app.ecdObj(idsFirstIndexes).CompanyName};

                mappingIds = dictionary();
                for ii = 1:numel(ids)
                    idIndexes = find(strcmp(idsList, ids{ii}));
                    [~, idSortedIndexes] = sort(arrayfun(@(x) x.Period(1), app.ecdObj(idIndexes)));

                    mappingIds = mappingIds.insert(string(idsNames{ii}), {idIndexes(idSortedIndexes)});
                end

                % Empresas:
                app.CompanyNameList.Items = sort(idsNames);
                app.CompanyNameList.UserData = mappingIds;

                % A seleção buscará respeitar aquilo que estiver selecionado 
                % em winMonitorSPED.mlapp.
                fileIndex = 1;
                if ~isempty(app.mainApp.file_Tree.SelectedNodes)
                    fileIndex = unique([app.mainApp.file_Tree.SelectedNodes.NodeData], 'stable');
                    fileIndex = fileIndex(1);
                end

                app.CompanyNameList.Value = app.ecdObj(fileIndex).CompanyName;
                app.TimePeriodList.Items  = {periodInformation(app, fileIndex)};
                CompanyNameListValueChanged(app)
            end

            app.UITable.RowName = 'numbered';
            app.UITable.UserData = struct('Selection', [], 'SelectionType', 'none');

            % app.Image3.UserData = false;
            % app.DropDown.Items = listfonts;
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function companyIndexes = selectedFileIndexByCompany(app)
            companyIndexes = cell2mat(app.CompanyNameList.UserData(app.CompanyNameList.Value));
        end

        %-----------------------------------------------------------------%
        function fileIndex = selectedFileIndex(app)
            companyIndexes = selectedFileIndexByCompany(app);
            fileIndex      = companyIndexes(strcmp(app.TimePeriodList.Items, app.TimePeriodList.Value));
        end

        %-----------------------------------------------------------------%
        function updateSheetList(app)
            fileIndex      = selectedFileIndex(app);
            selectedECD    = app.ecdObj(fileIndex);

            sheetsNames    = fieldnames(selectedECD.Table);
            nonemptySheets = sheetsNames(cellfun(@(x) ~isempty(selectedECD.Table.(x)), sheetsNames));

            app.SheetList.Items = extractAfter(sort(nonemptySheets), 'x');
        end

        %-----------------------------------------------------------------%
        function info = periodInformation(app, fileIndex)
            info = char(strjoin(string(app.ecdObj(fileIndex).Period), ' a '));
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

        % Value changed function: CompanyNameList
        function CompanyNameListValueChanged(app, event)

            companyIndexes = selectedFileIndexByCompany(app);

            periodList = {};
            for fileIndex = companyIndexes
                periodList{end+1} = periodInformation(app, fileIndex);
            end

            app.TimePeriodList.Items = periodList;
            TimePeriodListValueChanged(app)

        end

        % Value changed function: TimePeriodList
        function TimePeriodListValueChanged(app, event)
            
            fileIndex   = selectedFileIndex(app);
            selectedECD = app.ecdObj(fileIndex);

            updateSheetList(app)
            app.SheetList.Value = app.SheetList.Items{1};
            SheetListValueChanged(app)

            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Text = sprintf('<font style="font-size: 11px; font-weight: bold;">%s</font> CNPJ %s \n%s ', ...
                selectedECD.CompanyName, selectedECD.CompanyId, strjoin(string(selectedECD.Period), ' a '));
            
        end

        % Value changed function: SheetList
        function SheetListValueChanged(app, event)
            
            fileIndex   = selectedFileIndex(app);
            selectedECD = app.ecdObj(fileIndex);
            
            app.UITable.Data = selectedECD.Table.(['x' app.SheetList.Value]);
            app.UITable.ColumnName = app.UITable.Data.Properties.VariableNames;

            if height(app.UITable.Data) > 1
                numberOfRowsText = sprintf('%d DE %d REGISTROS ', height(app.UITable.Data), height(app.UITable.Data)); % PENDENTE FILTRAGEM
            else
                numberOfRowsText = sprintf('%d DE %d REGISTRO ',  height(app.UITable.Data), height(app.UITable.Data)); % PENDENTE FILTRAGEM
            end
            app.DE0Label.Text = numberOfRowsText;

        end

        % Callback function: ReadAllSheets
        function ReadAllSheetsButtonPushed(app, event)
            
            app.progressDialog.Visible = 'visible';

            try
                fileIndex   = selectedFileIndex(app);
                selectedECD = app.ecdObj(fileIndex);

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

                updateSheetList(app)
                ipcMainMatlabCallsHandler(app.mainApp, app, 'updateTreeView', fileIndex)

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
                    app.CONTAGEM0Label.Text = '  CONTAGEM: 0';

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
    
                        app.CONTAGEM0Label.Text = sprintf('  CONTAGEM: %d     SOMA: %.2f     MÉDIA: %.2f', cellsCount, cellsSum, cellsAverage);
                    else
                        app.CONTAGEM0Label.Text = sprintf('  CONTAGEM: %d', cellsCount);
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

        % Value changed function: SheetViewStatus
        function SheetViewStatusValueChanged(app, event)
            
            if app.SheetViewStatus.Value
                app.SheetView_Second.Enable = "on";
                app.SheetHeight_First.Enable     = 'on';

                app.SheetHeight_Second.Limits(1) = 1;
                set(app.SheetHeight_Second, 'Enable', 'on', 'Value', app.SheetHeight_First.Value)
                
                app.UITable2.Visible   = 'on';
                
                rowHeight = {10,2,18};
                
            else
                app.SheetView_Second.Enable = "off";
                app.SheetHeight_First.Enable     = 'off';
                
                app.SheetHeight_Second.Limits(1) = 0;
                set(app.SheetHeight_Second, 'Enable', 'off', 'Value', 0)

                app.UITable2.Visible   = 'off';                
                
                rowHeight = {0,0,0};
            end

            SpinnerValueChanged(app, struct('Source', app.SheetHeight_First))
            app.GridLayout.RowHeight([7,9,10]) = rowHeight;
            
        end

        % Value changed function: SheetHeight_First, SheetHeight_Second
        function SpinnerValueChanged(app, event)
            
            app.GridLayout.RowHeight([4,8]) = {sprintf('%dx', app.SheetHeight_First.Value), sprintf('%dx', app.SheetHeight_Second.Value)};

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
            app.GridLayout.RowHeight = {7, 84, 10, '1x', 2, 18, 0, 0, 0, 0, 5, 34};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create toolGrid
            app.toolGrid = uigridlayout(app.GridLayout);
            app.toolGrid.ColumnWidth = {22, 5, 22, '1x'};
            app.toolGrid.RowHeight = {4, 17, 2};
            app.toolGrid.ColumnSpacing = 5;
            app.toolGrid.RowSpacing = 0;
            app.toolGrid.Padding = [2 5 5 5];
            app.toolGrid.Layout.Row = 12;
            app.toolGrid.Layout.Column = [1 15];
            app.toolGrid.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create tool_Separator
            app.tool_Separator = uiimage(app.toolGrid);
            app.tool_Separator.ScaleMethod = 'none';
            app.tool_Separator.Enable = 'off';
            app.tool_Separator.Layout.Row = [1 3];
            app.tool_Separator.Layout.Column = 2;
            app.tool_Separator.VerticalAlignment = 'bottom';
            app.tool_Separator.ImageSource = 'LineV.svg';

            % Create tool_ExportButton
            app.tool_ExportButton = uiimage(app.toolGrid);
            app.tool_ExportButton.ScaleMethod = 'none';
            app.tool_ExportButton.Enable = 'off';
            app.tool_ExportButton.Layout.Row = 2;
            app.tool_ExportButton.Layout.Column = 3;
            app.tool_ExportButton.ImageSource = 'Export_16.png';

            % Create tool_tableNRowsIcon
            app.tool_tableNRowsIcon = uiimage(app.toolGrid);
            app.tool_tableNRowsIcon.ScaleMethod = 'none';
            app.tool_tableNRowsIcon.Enable = 'off';
            app.tool_tableNRowsIcon.Layout.Row = 2;
            app.tool_tableNRowsIcon.Layout.Column = 1;
            app.tool_tableNRowsIcon.ImageSource = 'Filter_18.png';

            % Create NOMEDAEMPRESAMetadadosOutrascoisasLabel_2
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2 = uilabel(app.toolGrid);
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.HorizontalAlignment = 'right';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.VerticalAlignment = 'top';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.WordWrap = 'on';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.FontSize = 9;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.FontColor = [0.149 0.149 0.149];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Layout.Row = [1 3];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Layout.Column = 4;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Interpreter = 'html';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Text = {'<font style="font-size: 11px; font-weight: bold;">NOME DA EMPRESA</font> CNPJ 10.101.101/0001-02 '; '01/01/2023 - 31/12/2023 '};

            % Create UITable2
            app.UITable2 = uitable(app.GridLayout);
            app.UITable2.BackgroundColor = [1 1 1;0.9412 0.9412 0.9412];
            app.UITable2.ColumnName = '';
            app.UITable2.RowName = {};
            app.UITable2.ColumnSortable = true;
            app.UITable2.ClickedFcn = createCallbackFcn(app, @UIFigureWindowButtonDown, true);
            app.UITable2.ForegroundColor = [0.149 0.149 0.149];
            app.UITable2.Visible = 'off';
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
            app.GridLayout3.ColumnWidth = {90, 230, 46, 229, '1x', 110};
            app.GridLayout3.RowHeight = {22, 22};
            app.GridLayout3.RowSpacing = 5;
            app.GridLayout3.Padding = [5 5 5 6];
            app.GridLayout3.BackgroundColor = [0.9608 0.9608 0.9608];

            % Create CompanyNameListLabel
            app.CompanyNameListLabel = uilabel(app.GridLayout3);
            app.CompanyNameListLabel.FontSize = 11;
            app.CompanyNameListLabel.FontColor = [0.149 0.149 0.149];
            app.CompanyNameListLabel.Layout.Row = 1;
            app.CompanyNameListLabel.Layout.Column = 1;
            app.CompanyNameListLabel.Text = 'Empresa:';

            % Create CompanyNameList
            app.CompanyNameList = uidropdown(app.GridLayout3);
            app.CompanyNameList.Items = {};
            app.CompanyNameList.ValueChangedFcn = createCallbackFcn(app, @CompanyNameListValueChanged, true);
            app.CompanyNameList.FontSize = 11;
            app.CompanyNameList.FontColor = [0.149 0.149 0.149];
            app.CompanyNameList.BackgroundColor = [1 1 1];
            app.CompanyNameList.Layout.Row = 1;
            app.CompanyNameList.Layout.Column = [2 4];
            app.CompanyNameList.Value = {};

            % Create TimePeriodListLabel
            app.TimePeriodListLabel = uilabel(app.GridLayout3);
            app.TimePeriodListLabel.FontSize = 11;
            app.TimePeriodListLabel.FontColor = [0.149 0.149 0.149];
            app.TimePeriodListLabel.Layout.Row = 2;
            app.TimePeriodListLabel.Layout.Column = 1;
            app.TimePeriodListLabel.Text = 'Período fiscal:';

            % Create TimePeriodList
            app.TimePeriodList = uidropdown(app.GridLayout3);
            app.TimePeriodList.Items = {};
            app.TimePeriodList.ValueChangedFcn = createCallbackFcn(app, @TimePeriodListValueChanged, true);
            app.TimePeriodList.FontSize = 11;
            app.TimePeriodList.FontColor = [0.149 0.149 0.149];
            app.TimePeriodList.BackgroundColor = [1 1 1];
            app.TimePeriodList.Layout.Row = 2;
            app.TimePeriodList.Layout.Column = 2;
            app.TimePeriodList.Value = {};

            % Create SheetListLabel
            app.SheetListLabel = uilabel(app.GridLayout3);
            app.SheetListLabel.HorizontalAlignment = 'right';
            app.SheetListLabel.FontSize = 11;
            app.SheetListLabel.FontColor = [0.149 0.149 0.149];
            app.SheetListLabel.Layout.Row = 2;
            app.SheetListLabel.Layout.Column = 3;
            app.SheetListLabel.Text = 'Ficha:';

            % Create SheetList
            app.SheetList = uidropdown(app.GridLayout3);
            app.SheetList.Items = {};
            app.SheetList.ValueChangedFcn = createCallbackFcn(app, @SheetListValueChanged, true);
            app.SheetList.FontSize = 11;
            app.SheetList.FontColor = [0.149 0.149 0.149];
            app.SheetList.BackgroundColor = [1 1 1];
            app.SheetList.Layout.Row = 2;
            app.SheetList.Layout.Column = 4;
            app.SheetList.Value = {};

            % Create ReadAllSheets
            app.ReadAllSheets = uihyperlink(app.GridLayout3);
            app.ReadAllSheets.HyperlinkClickedFcn = createCallbackFcn(app, @ReadAllSheetsButtonPushed, true);
            app.ReadAllSheets.VisitedColor = [1 0 0];
            app.ReadAllSheets.HorizontalAlignment = 'right';
            app.ReadAllSheets.VerticalAlignment = 'bottom';
            app.ReadAllSheets.FontSize = 10;
            app.ReadAllSheets.FontColor = [1 0 0];
            app.ReadAllSheets.Layout.Row = 2;
            app.ReadAllSheets.Layout.Column = 6;
            app.ReadAllSheets.Text = ' Ler todas as fichas ';

            % Create LAYOUTTab
            app.LAYOUTTab = uitab(app.TabGroup);
            app.LAYOUTTab.AutoResizeChildren = 'off';
            app.LAYOUTTab.Title = '✎ LAYOUT';
            app.LAYOUTTab.BackgroundColor = 'none';

            % Create GridLayout_2
            app.GridLayout_2 = uigridlayout(app.LAYOUTTab);
            app.GridLayout_2.ColumnWidth = {44, 226, 40, 3, 22, 22, 22, 22, 22, 22, 35, 35, 3, '1x'};
            app.GridLayout_2.RowHeight = {22, 22};
            app.GridLayout_2.RowSpacing = 5;
            app.GridLayout_2.Padding = [5 5 5 6];
            app.GridLayout_2.BackgroundColor = [0.9608 0.9608 0.9608];

            % Create SheetViewStatus
            app.SheetViewStatus = uibutton(app.GridLayout_2, 'state');
            app.SheetViewStatus.ValueChangedFcn = createCallbackFcn(app, @SheetViewStatusValueChanged, true);
            app.SheetViewStatus.Icon = 'split_top_bottom_ts_24-a602190eb092f2373c13f20ec5875137.png';
            app.SheetViewStatus.IconAlignment = 'top';
            app.SheetViewStatus.Text = 'Fichas';
            app.SheetViewStatus.BackgroundColor = [0.9608 0.9608 0.9608];
            app.SheetViewStatus.FontSize = 11;
            app.SheetViewStatus.Layout.Row = [1 2];
            app.SheetViewStatus.Layout.Column = 1;

            % Create SheetView_First
            app.SheetView_First = uidropdown(app.GridLayout_2);
            app.SheetView_First.Items = {};
            app.SheetView_First.FontSize = 11;
            app.SheetView_First.BackgroundColor = [1 1 1];
            app.SheetView_First.Layout.Row = 1;
            app.SheetView_First.Layout.Column = 2;
            app.SheetView_First.Value = {};

            % Create SheetHeight_First
            app.SheetHeight_First = uispinner(app.GridLayout_2);
            app.SheetHeight_First.Limits = [1 5];
            app.SheetHeight_First.RoundFractionalValues = 'on';
            app.SheetHeight_First.ValueDisplayFormat = '%d';
            app.SheetHeight_First.ValueChangedFcn = createCallbackFcn(app, @SpinnerValueChanged, true);
            app.SheetHeight_First.FontSize = 11;
            app.SheetHeight_First.Enable = 'off';
            app.SheetHeight_First.Layout.Row = 1;
            app.SheetHeight_First.Layout.Column = 3;
            app.SheetHeight_First.Value = 1;

            % Create SheetView_Second
            app.SheetView_Second = uidropdown(app.GridLayout_2);
            app.SheetView_Second.Items = {};
            app.SheetView_Second.Enable = 'off';
            app.SheetView_Second.FontSize = 11;
            app.SheetView_Second.BackgroundColor = [1 1 1];
            app.SheetView_Second.Layout.Row = 2;
            app.SheetView_Second.Layout.Column = 2;
            app.SheetView_Second.Value = {};

            % Create SheetHeight_Second
            app.SheetHeight_Second = uispinner(app.GridLayout_2);
            app.SheetHeight_Second.Limits = [0 5];
            app.SheetHeight_Second.RoundFractionalValues = 'on';
            app.SheetHeight_Second.ValueDisplayFormat = '%d';
            app.SheetHeight_Second.ValueChangedFcn = createCallbackFcn(app, @SpinnerValueChanged, true);
            app.SheetHeight_Second.FontSize = 11;
            app.SheetHeight_Second.Enable = 'off';
            app.SheetHeight_Second.Layout.Row = 2;
            app.SheetHeight_Second.Layout.Column = 3;

            % Create Separator
            app.Separator = uiimage(app.GridLayout_2);
            app.Separator.Enable = 'off';
            app.Separator.Layout.Row = [1 2];
            app.Separator.Layout.Column = 4;
            app.Separator.ImageSource = 'LineV.svg';

            % Create FontFamilyList
            app.FontFamilyList = uidropdown(app.GridLayout_2);
            app.FontFamilyList.Items = {};
            app.FontFamilyList.Tooltip = {'Fonte'};
            app.FontFamilyList.FontSize = 11;
            app.FontFamilyList.BackgroundColor = [1 1 1];
            app.FontFamilyList.Layout.Row = 1;
            app.FontFamilyList.Layout.Column = [5 10];
            app.FontFamilyList.Value = {};

            % Create FontSize
            app.FontSize = uidropdown(app.GridLayout_2);
            app.FontSize.Items = {'10', '11', '12', '13', '14'};
            app.FontSize.Tooltip = {'Tamanho da fonte'};
            app.FontSize.FontSize = 11;
            app.FontSize.BackgroundColor = [1 1 1];
            app.FontSize.Layout.Row = 1;
            app.FontSize.Layout.Column = [11 12];
            app.FontSize.Value = '10';

            % Create FontWeight
            app.FontWeight = uibutton(app.GridLayout_2, 'push');
            app.FontWeight.BackgroundColor = [1 1 1];
            app.FontWeight.FontName = 'Century';
            app.FontWeight.FontWeight = 'bold';
            app.FontWeight.Layout.Row = 2;
            app.FontWeight.Layout.Column = 5;
            app.FontWeight.Text = 'B';

            % Create FontStyle
            app.FontStyle = uibutton(app.GridLayout_2, 'push');
            app.FontStyle.BackgroundColor = [1 1 1];
            app.FontStyle.FontName = 'Century';
            app.FontStyle.FontAngle = 'italic';
            app.FontStyle.Layout.Row = 2;
            app.FontStyle.Layout.Column = 6;
            app.FontStyle.Text = 'I ';

            % Create FontUnderline
            app.FontUnderline = uibutton(app.GridLayout_2, 'push');
            app.FontUnderline.BackgroundColor = [1 1 1];
            app.FontUnderline.FontName = 'Century';
            app.FontUnderline.Layout.Row = 2;
            app.FontUnderline.Layout.Column = 7;
            app.FontUnderline.Text = 'U̲';

            % Create FontAlign1
            app.FontAlign1 = uiimage(app.GridLayout_2);
            app.FontAlign1.ScaleMethod = 'none';
            app.FontAlign1.Tooltip = {'Sublinhado'};
            app.FontAlign1.Layout.Row = 2;
            app.FontAlign1.Layout.Column = 8;
            app.FontAlign1.ImageSource = 'AlignedLeft_16-7f46662cd6fd7221119660e14bdcea56.png';

            % Create FontAlign2
            app.FontAlign2 = uiimage(app.GridLayout_2);
            app.FontAlign2.ScaleMethod = 'none';
            app.FontAlign2.Tooltip = {'Sublinhado'};
            app.FontAlign2.Layout.Row = 2;
            app.FontAlign2.Layout.Column = 9;
            app.FontAlign2.ImageSource = 'AlignedCenter_16-b91485db227234029c43b7823c09ebff.png';

            % Create FontAlign3
            app.FontAlign3 = uiimage(app.GridLayout_2);
            app.FontAlign3.ScaleMethod = 'none';
            app.FontAlign3.Tooltip = {'Sublinhado'};
            app.FontAlign3.Layout.Row = 2;
            app.FontAlign3.Layout.Column = 10;
            app.FontAlign3.ImageSource = 'AlignedRight_16-7827788943408c9bac98181b7ad0efb5.png';

            % Create FontBackground
            app.FontBackground = uicolorpicker(app.GridLayout_2);
            app.FontBackground.Icon = '_Background.png';
            app.FontBackground.Layout.Row = 2;
            app.FontBackground.Layout.Column = 11;
            app.FontBackground.BackgroundColor = [1 1 1];

            % Create FontColor
            app.FontColor = uicolorpicker(app.GridLayout_2);
            app.FontColor.Icon = '_Color.png';
            app.FontColor.Layout.Row = 2;
            app.FontColor.Layout.Column = 12;
            app.FontColor.BackgroundColor = [1 1 1];

            % Create FILTRAGEMTab
            app.FILTRAGEMTab = uitab(app.TabGroup);
            app.FILTRAGEMTab.AutoResizeChildren = 'off';
            app.FILTRAGEMTab.Title = '⤯ FILTRAGEM';
            app.FILTRAGEMTab.BackgroundColor = 'none';

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.FILTRAGEMTab);
            app.GridLayout4.ColumnWidth = {14, 40, 206, 40, 285, 3, '1x'};
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

            % Create CONTAGEM0Label
            app.CONTAGEM0Label = uilabel(app.GridLayout);
            app.CONTAGEM0Label.FontSize = 10;
            app.CONTAGEM0Label.FontColor = [0.502 0.502 0.502];
            app.CONTAGEM0Label.Layout.Row = 6;
            app.CONTAGEM0Label.Layout.Column = [3 9];
            app.CONTAGEM0Label.Text = ' CONTAGEM : 0';

            % Create Image5
            app.Image5 = uiimage(app.GridLayout);
            app.Image5.ScaleMethod = 'none';
            app.Image5.Enable = 'off';
            app.Image5.Layout.Row = 6;
            app.Image5.Layout.Column = 14;
            app.Image5.ImageSource = 'Filter_18.png';

            % Create DE0Label
            app.DE0Label = uilabel(app.GridLayout);
            app.DE0Label.HorizontalAlignment = 'right';
            app.DE0Label.FontSize = 10;
            app.DE0Label.FontColor = [0.502 0.502 0.502];
            app.DE0Label.Layout.Row = 6;
            app.DE0Label.Layout.Column = 13;
            app.DE0Label.Text = '0 DE 0 ';

            % Create Image6_2
            app.Image6_2 = uiimage(app.GridLayout);
            app.Image6_2.ScaleMethod = 'none';
            app.Image6_2.Layout.Row = 10;
            app.Image6_2.Layout.Column = 2;
            app.Image6_2.ImageSource = 'selectColumn.png';

            % Create CONTAGEM0Label_2
            app.CONTAGEM0Label_2 = uilabel(app.GridLayout);
            app.CONTAGEM0Label_2.FontSize = 10;
            app.CONTAGEM0Label_2.FontColor = [0.502 0.502 0.502];
            app.CONTAGEM0Label_2.Layout.Row = 10;
            app.CONTAGEM0Label_2.Layout.Column = [3 9];
            app.CONTAGEM0Label_2.Text = ' CONTAGEM: 0';

            % Create DE0Label_2
            app.DE0Label_2 = uilabel(app.GridLayout);
            app.DE0Label_2.HorizontalAlignment = 'right';
            app.DE0Label_2.FontSize = 10;
            app.DE0Label_2.FontColor = [0.502 0.502 0.502];
            app.DE0Label_2.Layout.Row = 10;
            app.DE0Label_2.Layout.Column = [10 13];
            app.DE0Label_2.Text = '0 DE 0';

            % Create Image5_2
            app.Image5_2 = uiimage(app.GridLayout);
            app.Image5_2.ScaleMethod = 'none';
            app.Image5_2.Enable = 'off';
            app.Image5_2.Layout.Row = 10;
            app.Image5_2.Layout.Column = [14 15];
            app.Image5_2.ImageSource = 'Filter_18.png';

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
