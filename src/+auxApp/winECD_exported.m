classdef winECD_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        GridLayout                  matlab.ui.container.GridLayout
        toolGrid                    matlab.ui.container.GridLayout
        NOMEDAEMPRESAMetadadosOutrascoisasLabel_2  matlab.ui.control.Label
        tool_ExportButton           matlab.ui.control.Image
        UITable2_FilterText         matlab.ui.control.Label
        UITable2_CountText          matlab.ui.control.Label
        UITable2_CountIcon          matlab.ui.control.Image
        UITable2                    matlab.ui.control.Table
        UITable1_FilterText         matlab.ui.control.Label
        UITable1_CountText          matlab.ui.control.Label
        UITable1_CountIcon          matlab.ui.control.Image
        UITable1                    matlab.ui.control.Table
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
        FontStyle                   matlab.ui.control.Button
        FontWeight                  matlab.ui.control.Button
        FontFamily                  matlab.ui.control.DropDown
        Separator2                  matlab.ui.control.Image
        RowHeightOffsetLabel        matlab.ui.control.Label
        RowHeightOffset             matlab.ui.control.Spinner
        Separator1                  matlab.ui.control.Image
        SheetOnFocus                matlab.ui.control.Lamp
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
        GridLayout5                 matlab.ui.container.GridLayout
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

                    case 'getCssPropertyValue'
                        if ~isempty(event.HTMLEventData.componentName)
                            if ~isprop(app, 'isDocked') % mainApp (app container)
                                auxAppTag = event.HTMLEventData.auxAppTag;
                                if ~isempty(auxAppTag)
                                    hAuxApp   = auxAppHandle(app, auxAppTag);
                                    objHandle = hAuxApp.(componentName);
                                else
                                    objHandle = eval(['app.' event.HTMLEventData.componentName]);
                                end
                            else
                                objHandle = eval(['app.' event.HTMLEventData.componentName]);
                            end
                            
                            cssProp  = event.HTMLEventData.propertyName;
                            cssValue = event.HTMLEventData.propertyValue;
    
                            if ~isprop(objHandle, 'StyleObservations')
                                objHandle.addprop('StyleObservations');
                            end
                            objHandle.StyleObservations.(cssProp) = cssValue;
                        end

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
                customizationStatus = [false, false, false, false];
            end

            switch tabIndex
                case 0 % STARTUP
                    if app.isDocked
                        app.progressDialog = app.mainApp.progressDialog;
                    else
                        sendEventToHTMLSource(app.jsBackDoor, 'startup', app.mainApp.executionMode);
                        app.progressDialog = ccTools.ProgressDialog(app.jsBackDoor);                        
                    end
                    customizationStatus = [false, false, false, false];

                otherwise
                    if customizationStatus(tabIndex)
                        return
                    end

                    customizationStatus(tabIndex) = true;
                    switch tabIndex
                        case 1
                            elToModify = {app.UITable1, app.UITable2};
                            ui.CustomizationBase.getElementsDataTag(elToModify);

                        otherwise
                            % Customização de componentes constantes nas outras abas, 
                            % os quais são renderizados completamente apenas após a 
                            % abertura da aba.
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
            % Tabelas:
            app.UITable1.RowName  = 'numbered';
            app.UITable2.RowName = 'numbered';
            restartTableSelectionControl(app, app.UITable1, app.UITable1_CountText)
            restartTableSelectionControl(app, app.UITable2, app.UITable2_CountText)

            % Seleção inicial:
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
            sheetsList     = extractAfter(sort(nonemptySheets), 'x');

            app.SheetList.Items        = sheetsList;
            app.SheetView_First.Items  = sheetsList;
            app.SheetView_Second.Items = sheetsList;
        end

        %-----------------------------------------------------------------%
        function updateTable(app, hTable, hTableCountText, hTableFilterText, sheetId)
            fileIndex   = selectedFileIndex(app);
            selectedECD = app.ecdObj(fileIndex);

            hTable.Data = selectedECD.Table.(['x' sheetId]);
            hTable.ColumnName = hTable.Data.Properties.VariableNames;
            restartTableSelectionControl(app, hTable, hTableCountText)

            if height(hTable.Data) > 1
                numberOfRowsText = sprintf('%d DE %d REGISTROS ', height(hTable.Data), height(hTable.Data)); % PENDENTE FILTRAGEM
            else
                numberOfRowsText = sprintf('%d DE %d REGISTRO ',  height(hTable.Data), height(hTable.Data)); % PENDENTE FILTRAGEM
            end
            hTableFilterText.Text = numberOfRowsText;
        end

        %-----------------------------------------------------------------%
        function restartTableSelectionControl(app, hTable, hTableCountText)
            hTable.Selection = [];
            
            % ().UserData.id armazenará o "data-tag" do componente, caso haja
            % alguma customização em curso.
            hTable.UserData.Selection = [];
            hTable.UserData.SelectionType = 'none';

            hTableCountText.Text = '  CONTAGEM: 0';
        end

        %-----------------------------------------------------------------%
        function info = periodInformation(app, fileIndex)
            info = char(strjoin(string(app.ecdObj(fileIndex).Period), ' a '));
        end

        %-----------------------------------------------------------------%
        function [hTable, hTableName] = onFocusTable(app)
            if app.SheetOnFocus.Layout.Row == 1
                hTable     = app.UITable1;
                hTableName = 'app.UITable1';
            else
                hTable     = app.UITable2;
                hTableName = 'app.UITable2';
            end
        end

        %-----------------------------------------------------------------%
        function waitForPropertyCreation(app, objHandle, propertyName)
            tWaitFor = tic;
            while toc(tWaitFor) < 2
                if isprop(objHandle, propertyName)
                    toc
                    break
                end
                pause(.010)
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
            app.SheetList.Value        = app.SheetList.Items{1};
            app.SheetView_First.Value  = app.SheetView_First.Items{1};
            SheetListValueChanged(app, struct('Source', app.SheetList))
            SheetView_SecondValueChanged(app)

            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Text = sprintf('<font style="font-size: 11px; font-weight: bold;">%s</font> CNPJ %s \n%s ', ...
                selectedECD.CompanyName, selectedECD.CompanyId, strjoin(string(selectedECD.Period), ' a '));
            
        end

        % Value changed function: SheetList, SheetView_First
        function SheetListValueChanged(app, event)
            
            switch event.Source
                case app.SheetList
                    app.SheetView_First.Value = app.SheetList.Value;
                case app.SheetView_First
                    app.SheetList.Value = app.SheetView_First.Value;
            end

            updateTable(app, app.UITable1, app.UITable1_CountText, app.UITable1_FilterText, app.SheetList.Value)

        end

        % Value changed function: SheetView_Second
        function SheetView_SecondValueChanged(app, event)
            
            updateTable(app, app.UITable2, app.UITable2_CountText, app.UITable2_FilterText, app.SheetView_Second.Value)
            
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

        % Clicked callback: UITable1, UITable2
        function TableClicked(app, event)
            
            clickedTable = event.Source;
            clickedRow = event.InteractionInformation.DisplayRow;
            clickedCol = event.InteractionInformation.DisplayColumn;

            switch clickedTable
                case app.UITable1
                    tableCountText  = app.UITable1_CountText;
                    lampPositionRow = 1;
                case app.UITable2
                    tableCountText  = app.UITable2_CountText;
                    lampPositionRow = 2;
            end            

            % Altera tabela em evidência (uilamp), além de definir o tipo
            % de seleção (no caso de clique fora da região de células,
            % limpa-se a seleção prévia):
            if app.SheetOnFocus.Layout.Row ~= lampPositionRow
                if ~isempty(clickedRow) || ~isempty(clickedCol)
                    app.SheetOnFocus.Layout.Row = lampPositionRow;
                end
            end

            if isempty(clickedRow) && isempty(clickedCol) 
                if ~isempty(clickedTable.Selection)
                    clickedTable.UserData.SelectionType = 'none';                    
                    clickedTable.Selection = [];
                    drawnow                    
                end
            elseif isempty(clickedCol)
                clickedTable.UserData.SelectionType = 'row';
            elseif isempty(clickedRow)
                clickedTable.UserData.SelectionType = 'column';
            else
                clickedTable.UserData.SelectionType = 'cell';            
            end

            % Atualização do rodapé da tabela:
            if ~isequal(clickedTable.Selection, clickedTable.UserData.Selection)
                clickedTable.UserData.Selection = clickedTable.Selection;

                if isempty(clickedTable.Selection)
                    tableCountText.Text = '  CONTAGEM: 0';

                else
                    selectedCols = unique(clickedTable.Selection(:, 2));
                    selectedColsNames = clickedTable.Data.Properties.VariableNames(selectedCols);
    
                    isNumeric = true;
                    for ii = 1:numel(selectedColsNames)
                        if ~isnumeric(clickedTable.Data.(selectedColsNames{ii}))
                            isNumeric = false;
                            break;
                        end
                    end
    
                    cellsCount = height(clickedTable.Selection);
                    if isNumeric
                        switch clickedTable.UserData.SelectionType
                            case 'column'
                                cellsSum = sum(double(clickedTable.Data{:, selectedCols}), 'all');
                                cellsAverage = mean(double(clickedTable.Data{:, selectedCols}), 'all');
    
                            otherwise
                                cellsSum = 0;
                                for kk = 1:cellsCount
                                    cellsSum = cellsSum + double(clickedTable.Data{clickedTable.Selection(kk, 1), clickedTable.Selection(kk, 2)});
                                end
                                cellsAverage = cellsSum/cellsCount;
                        end
    
                        tableCountText.Text = sprintf('  CONTAGEM: %d     SOMA: %.2f     MÉDIA: %.2f', cellsCount, cellsSum, cellsAverage);
                    else
                        tableCountText.Text = sprintf('  CONTAGEM: %d', cellsCount);
                    end
                end
            end

        end

        % Callback function: FontAlign1, FontAlign2, FontAlign3, 
        % ...and 5 other components
        function TableStyleChanged(app, event)
            
            switch event.Source
                case app.FontFamily
                    fieldName  = 'FontName';
                    fieldValue = {app.FontFamily.Value};

                case app.FontWeight
                    fieldName  = 'FontWeight';
                    fieldValue = {'bold', 'normal'};

                case app.FontStyle
                    fieldName  = 'FontAngle';
                    fieldValue = {'italic', 'normal'};

                case app.FontAlign1
                    fieldName  = 'HorizontalAlignment';
                    fieldValue = {'left'};    % 'left' | 'center' | 'right'

                case app.FontAlign2
                    fieldName  = 'HorizontalAlignment';
                    fieldValue = {'center'};

                case app.FontAlign3
                    fieldName  = 'HorizontalAlignment';
                    fieldValue = {'right'};

                case app.FontBackground
                    fieldName  = 'BackgroundColor';
                    fieldValue = {event.Value};
                    app.FontBackground.Value = [1 1 1];

                case app.FontColor
                    fieldName  = 'FontColor';
                    fieldValue = {event.Value};
                    app.FontColor.Value = [0.149 0.149 0.149];
            end

            clickedTable = onFocusTable(app);
            if isempty(clickedTable.Selection)
                return
            end

            % Verifica se já existe estilo aplicado às células selecionadas:
            styleIndex = find(cellfun(@(x) isequal(clickedTable.Selection, x), clickedTable.StyleConfigurations.TargetIndex));
            if ~isempty(styleIndex)
                styleIndex = styleIndex(end);
                s = clickedTable.StyleConfigurations.Style(styleIndex);
            else
                s = uistyle();
            end

            if ~isempty(s.(fieldName))
                previousValue = s.(fieldName);
                previouValueIndex = find(cellfun(@(x) isequal(x, previousValue), fieldValue));
                s.(fieldName) = fieldValue{setdiff(1:numel(fieldValue), previouValueIndex)};

            else
                s.(fieldName) = fieldValue{1};
            end

            s

            addStyle(clickedTable, s, "cell", clickedTable.Selection)
            
        end

        % Value changed function: SheetViewStatus
        function SheetViewStatusValueChanged(app, event)
            
            if app.SheetViewStatus.Value
                app.SheetView_Second.Enable  = "on";
                app.SheetHeight_First.Enable = 'on';

                app.SheetHeight_Second.Limits(1) = 1;
                set(app.SheetHeight_Second, 'Enable', 'on', 'Value', app.SheetHeight_First.Value)
                
                app.UITable2.Visible = 'on';
                rowHeight = {10,2,18};
                
            else
                app.SheetView_Second.Enable  = "off";
                app.SheetHeight_First.Enable = 'off';
                
                app.SheetHeight_Second.Limits(1) = 0;
                set(app.SheetHeight_Second, 'Enable', 'off', 'Value', 0)

                app.UITable2.Visible = 'off';
                rowHeight = {0,0,0};

                if app.SheetOnFocus.Layout.Row ~= 1
                    app.SheetOnFocus.Layout.Row = 1;
                end
            end

            SpinnerValueChanged(app, struct('Source', app.SheetHeight_First))
            app.GridLayout.RowHeight([7,9,10]) = rowHeight;
            
        end

        % Value changed function: SheetHeight_First, SheetHeight_Second
        function SpinnerValueChanged(app, event)
            
            app.GridLayout.RowHeight([4,8]) = {sprintf('%dx', app.SheetHeight_First.Value), sprintf('%dx', app.SheetHeight_Second.Value)};

        end

        % Value changed function: RowHeightOffset
        function AumentaralturadalinhaButtonPushed(app, event)

            % ToDo:
            % Inserir comando pra forçar a renderização.

            hTable = onFocusTable(app);
            propertyName = 'height';

            try
                if ~isempty(hTable.Data) &&                            ...
                  (~isprop(hTable, 'StyleObservations')             || ...
                   ~isfield(hTable.StyleObservations, propertyName) || ...
                    isempty(hTable.StyleObservations.(propertyName)))
    
                    hTableName  = ui.CustomizationBase.getPropertyName(hTable, 'ECD');
                    customEvent = struct('auxAppTag',     'ECD',              ...
                                         'componentName', hTableName,         ...
                                         'dataTag',       hTable.UserData.id, ...
                                         'childClass',    'mw-table-row',     ...
                                         'propertyName',  propertyName);

                    sendEventToHTMLSource(app.jsBackDoor, 'getCssPropertyValue', customEvent);
                    waitForPropertyCreation(app, hTable, propertyName)
                end
                
                if app.RowHeightOffset.Value
                    defaultProp   = regexp(hTable.StyleObservations.height, '(?<height>\d+[.]?\d*)px', 'names');
                    defaultHeight = str2double(defaultProp.height);

                    sendEventToHTMLSource(app.jsBackDoor, 'changeTableRowHeight', defaultHeight + app.RowHeightOffset.Value);
                else
                    sendEventToHTMLSource(app.jsBackDoor, 'changeTableRowHeight', 'default');
                end

                % A simples troca do foco do elemento força a sua renderização,
                % evitando uso de manipulações diretas em JavaScript.
                pause(.100)
                if app.SheetViewStatus.Value && ~isequal(hTable, app.UITable2)
                    focus(hTable)
                    pause(.100)
                end
                focus(hTable)

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', ME.message);
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
            app.GridLayout.ColumnWidth = {5, 18, 320, 5, 90, 5, 5, 5, '1x', 5, 5, 5, 330, 5};
            app.GridLayout.RowHeight = {7, 94, 10, '1x', 2, 18, 0, 0, 0, 0, 5, 34};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.AutoResizeChildren = 'off';
            app.TabGroup.Layout.Row = 2;
            app.TabGroup.Layout.Column = [2 13];

            % Create ASPECTOSGERAISTab
            app.ASPECTOSGERAISTab = uitab(app.TabGroup);
            app.ASPECTOSGERAISTab.AutoResizeChildren = 'off';
            app.ASPECTOSGERAISTab.Title = 'ℹ ASPECTOS GERAIS';
            app.ASPECTOSGERAISTab.BackgroundColor = 'none';

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.ASPECTOSGERAISTab);
            app.GridLayout3.ColumnWidth = {90, 230, 46, 229, '1x', 130};
            app.GridLayout3.RowHeight = {22, 22};
            app.GridLayout3.RowSpacing = 5;
            app.GridLayout3.BackgroundColor = [0.9608 0.9608 0.9608];

            % Create CompanyNameListLabel
            app.CompanyNameListLabel = uilabel(app.GridLayout3);
            app.CompanyNameListLabel.FontSize = 10;
            app.CompanyNameListLabel.FontColor = [0.149 0.149 0.149];
            app.CompanyNameListLabel.Layout.Row = 1;
            app.CompanyNameListLabel.Layout.Column = 1;
            app.CompanyNameListLabel.Text = 'EMPRESA:';

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
            app.TimePeriodListLabel.FontSize = 10;
            app.TimePeriodListLabel.FontColor = [0.149 0.149 0.149];
            app.TimePeriodListLabel.Layout.Row = 2;
            app.TimePeriodListLabel.Layout.Column = 1;
            app.TimePeriodListLabel.Text = 'PERÍODO FISCAL:';

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
            app.SheetListLabel.FontSize = 10;
            app.SheetListLabel.FontColor = [0.149 0.149 0.149];
            app.SheetListLabel.Layout.Row = 2;
            app.SheetListLabel.Layout.Column = 3;
            app.SheetListLabel.Text = 'FICHA:';

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
            app.ReadAllSheets.Text = ' LER TODAS AS FICHAS ';

            % Create LAYOUTTab
            app.LAYOUTTab = uitab(app.TabGroup);
            app.LAYOUTTab.AutoResizeChildren = 'off';
            app.LAYOUTTab.Title = '✎ LAYOUT';
            app.LAYOUTTab.BackgroundColor = 'none';

            % Create GridLayout_2
            app.GridLayout_2 = uigridlayout(app.LAYOUTTab);
            app.GridLayout_2.ColumnWidth = {44, 226, 40, 10, 3, 90, 3, 22, 22, 22, 22, 22, 44, 44};
            app.GridLayout_2.RowHeight = {22, 22};
            app.GridLayout_2.RowSpacing = 5;
            app.GridLayout_2.BackgroundColor = [0.9608 0.9608 0.9608];

            % Create SheetViewStatus
            app.SheetViewStatus = uibutton(app.GridLayout_2, 'state');
            app.SheetViewStatus.ValueChangedFcn = createCallbackFcn(app, @SheetViewStatusValueChanged, true);
            app.SheetViewStatus.Icon = 'split_top_bottom_ts_24-a602190eb092f2373c13f20ec5875137.png';
            app.SheetViewStatus.IconAlignment = 'top';
            app.SheetViewStatus.Text = 'TELA';
            app.SheetViewStatus.BackgroundColor = [0.9608 0.9608 0.9608];
            app.SheetViewStatus.FontSize = 10;
            app.SheetViewStatus.Layout.Row = [1 2];
            app.SheetViewStatus.Layout.Column = 1;

            % Create SheetView_First
            app.SheetView_First = uidropdown(app.GridLayout_2);
            app.SheetView_First.Items = {};
            app.SheetView_First.ValueChangedFcn = createCallbackFcn(app, @SheetListValueChanged, true);
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
            app.SheetView_Second.ValueChangedFcn = createCallbackFcn(app, @SheetView_SecondValueChanged, true);
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

            % Create SheetOnFocus
            app.SheetOnFocus = uilamp(app.GridLayout_2);
            app.SheetOnFocus.Tooltip = {'Tabela em evidência'};
            app.SheetOnFocus.Layout.Row = 1;
            app.SheetOnFocus.Layout.Column = 4;
            app.SheetOnFocus.Color = [0.7059 0.8706 1];

            % Create Separator1
            app.Separator1 = uiimage(app.GridLayout_2);
            app.Separator1.Enable = 'off';
            app.Separator1.Layout.Row = [1 2];
            app.Separator1.Layout.Column = 5;
            app.Separator1.ImageSource = 'LineV.svg';

            % Create RowHeightOffset
            app.RowHeightOffset = uispinner(app.GridLayout_2);
            app.RowHeightOffset.Step = 5;
            app.RowHeightOffset.Limits = [0 50];
            app.RowHeightOffset.RoundFractionalValues = 'on';
            app.RowHeightOffset.ValueDisplayFormat = '%d';
            app.RowHeightOffset.ValueChangedFcn = createCallbackFcn(app, @AumentaralturadalinhaButtonPushed, true);
            app.RowHeightOffset.FontSize = 11;
            app.RowHeightOffset.Layout.Row = 1;
            app.RowHeightOffset.Layout.Column = 6;

            % Create RowHeightOffsetLabel
            app.RowHeightOffsetLabel = uilabel(app.GridLayout_2);
            app.RowHeightOffsetLabel.HorizontalAlignment = 'center';
            app.RowHeightOffsetLabel.WordWrap = 'on';
            app.RowHeightOffsetLabel.FontSize = 10;
            app.RowHeightOffsetLabel.Layout.Row = 2;
            app.RowHeightOffsetLabel.Layout.Column = 6;
            app.RowHeightOffsetLabel.Text = {'ALTURA LINHA'; '(offset)'};

            % Create Separator2
            app.Separator2 = uiimage(app.GridLayout_2);
            app.Separator2.Enable = 'off';
            app.Separator2.Layout.Row = [1 2];
            app.Separator2.Layout.Column = 7;
            app.Separator2.ImageSource = 'LineV.svg';

            % Create FontFamily
            app.FontFamily = uidropdown(app.GridLayout_2);
            app.FontFamily.Items = {};
            app.FontFamily.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontFamily.Tooltip = {'Fonte'};
            app.FontFamily.FontSize = 11;
            app.FontFamily.BackgroundColor = [1 1 1];
            app.FontFamily.Layout.Row = 1;
            app.FontFamily.Layout.Column = [8 14];
            app.FontFamily.Value = {};

            % Create FontWeight
            app.FontWeight = uibutton(app.GridLayout_2, 'push');
            app.FontWeight.ButtonPushedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontWeight.BackgroundColor = [1 1 1];
            app.FontWeight.FontName = 'Century';
            app.FontWeight.FontWeight = 'bold';
            app.FontWeight.Layout.Row = 2;
            app.FontWeight.Layout.Column = 8;
            app.FontWeight.Text = 'B';

            % Create FontStyle
            app.FontStyle = uibutton(app.GridLayout_2, 'push');
            app.FontStyle.ButtonPushedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontStyle.BackgroundColor = [1 1 1];
            app.FontStyle.FontName = 'Century';
            app.FontStyle.FontAngle = 'italic';
            app.FontStyle.Layout.Row = 2;
            app.FontStyle.Layout.Column = 9;
            app.FontStyle.Text = 'I ';

            % Create FontAlign1
            app.FontAlign1 = uiimage(app.GridLayout_2);
            app.FontAlign1.ScaleMethod = 'none';
            app.FontAlign1.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign1.Tooltip = {'Sublinhado'};
            app.FontAlign1.Layout.Row = 2;
            app.FontAlign1.Layout.Column = 10;
            app.FontAlign1.ImageSource = 'AlignedLeft_16-7f46662cd6fd7221119660e14bdcea56.png';

            % Create FontAlign2
            app.FontAlign2 = uiimage(app.GridLayout_2);
            app.FontAlign2.ScaleMethod = 'none';
            app.FontAlign2.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign2.Tooltip = {'Sublinhado'};
            app.FontAlign2.Layout.Row = 2;
            app.FontAlign2.Layout.Column = 11;
            app.FontAlign2.ImageSource = 'AlignedCenter_16-b91485db227234029c43b7823c09ebff.png';

            % Create FontAlign3
            app.FontAlign3 = uiimage(app.GridLayout_2);
            app.FontAlign3.ScaleMethod = 'none';
            app.FontAlign3.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign3.Tooltip = {'Sublinhado'};
            app.FontAlign3.Layout.Row = 2;
            app.FontAlign3.Layout.Column = 12;
            app.FontAlign3.ImageSource = 'AlignedRight_16-7827788943408c9bac98181b7ad0efb5.png';

            % Create FontBackground
            app.FontBackground = uicolorpicker(app.GridLayout_2);
            app.FontBackground.Value = [1 1 1];
            app.FontBackground.Icon = '_Background.png';
            app.FontBackground.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontBackground.Layout.Row = 2;
            app.FontBackground.Layout.Column = 13;
            app.FontBackground.BackgroundColor = [1 1 1];

            % Create FontColor
            app.FontColor = uicolorpicker(app.GridLayout_2);
            app.FontColor.Value = [0.149 0.149 0.149];
            app.FontColor.Icon = '_Color.png';
            app.FontColor.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontColor.Layout.Row = 2;
            app.FontColor.Layout.Column = 14;
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

            % Create GridLayout5
            app.GridLayout5 = uigridlayout(app.TABELACUSTOMIZADATab);
            app.GridLayout5.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout5.BackgroundColor = [0.9608 0.9608 0.9608];

            % Create UITable1
            app.UITable1 = uitable(app.GridLayout);
            app.UITable1.BackgroundColor = [1 1 1;0.9412 0.9412 0.9412];
            app.UITable1.ColumnName = '';
            app.UITable1.ColumnSortable = true;
            app.UITable1.ClickedFcn = createCallbackFcn(app, @TableClicked, true);
            app.UITable1.ForegroundColor = [0.149 0.149 0.149];
            app.UITable1.Layout.Row = 4;
            app.UITable1.Layout.Column = [2 13];
            app.UITable1.FontSize = 10.5;

            % Create UITable1_CountIcon
            app.UITable1_CountIcon = uiimage(app.GridLayout);
            app.UITable1_CountIcon.ScaleMethod = 'none';
            app.UITable1_CountIcon.Layout.Row = 6;
            app.UITable1_CountIcon.Layout.Column = 2;
            app.UITable1_CountIcon.ImageSource = 'selectColumn.png';

            % Create UITable1_CountText
            app.UITable1_CountText = uilabel(app.GridLayout);
            app.UITable1_CountText.FontSize = 10;
            app.UITable1_CountText.FontColor = [0.502 0.502 0.502];
            app.UITable1_CountText.Layout.Row = 6;
            app.UITable1_CountText.Layout.Column = [3 9];
            app.UITable1_CountText.Text = ' CONTAGEM : 0';

            % Create UITable1_FilterText
            app.UITable1_FilterText = uilabel(app.GridLayout);
            app.UITable1_FilterText.HorizontalAlignment = 'right';
            app.UITable1_FilterText.FontSize = 10;
            app.UITable1_FilterText.FontColor = [0.502 0.502 0.502];
            app.UITable1_FilterText.Layout.Row = 6;
            app.UITable1_FilterText.Layout.Column = 13;
            app.UITable1_FilterText.Text = '0 DE 0 ';

            % Create UITable2
            app.UITable2 = uitable(app.GridLayout);
            app.UITable2.BackgroundColor = [1 1 1;0.9412 0.9412 0.9412];
            app.UITable2.ColumnName = '';
            app.UITable2.RowName = {};
            app.UITable2.ColumnSortable = true;
            app.UITable2.ClickedFcn = createCallbackFcn(app, @TableClicked, true);
            app.UITable2.ForegroundColor = [0.149 0.149 0.149];
            app.UITable2.Visible = 'off';
            app.UITable2.Layout.Row = 8;
            app.UITable2.Layout.Column = [2 13];
            app.UITable2.FontSize = 10.5;

            % Create UITable2_CountIcon
            app.UITable2_CountIcon = uiimage(app.GridLayout);
            app.UITable2_CountIcon.ScaleMethod = 'none';
            app.UITable2_CountIcon.Layout.Row = 10;
            app.UITable2_CountIcon.Layout.Column = 2;
            app.UITable2_CountIcon.ImageSource = 'selectColumn.png';

            % Create UITable2_CountText
            app.UITable2_CountText = uilabel(app.GridLayout);
            app.UITable2_CountText.FontSize = 10;
            app.UITable2_CountText.FontColor = [0.502 0.502 0.502];
            app.UITable2_CountText.Layout.Row = 10;
            app.UITable2_CountText.Layout.Column = [3 9];
            app.UITable2_CountText.Text = ' CONTAGEM: 0';

            % Create UITable2_FilterText
            app.UITable2_FilterText = uilabel(app.GridLayout);
            app.UITable2_FilterText.HorizontalAlignment = 'right';
            app.UITable2_FilterText.FontSize = 10;
            app.UITable2_FilterText.FontColor = [0.502 0.502 0.502];
            app.UITable2_FilterText.Layout.Row = 10;
            app.UITable2_FilterText.Layout.Column = [10 13];
            app.UITable2_FilterText.Text = '0 DE 0';

            % Create toolGrid
            app.toolGrid = uigridlayout(app.GridLayout);
            app.toolGrid.ColumnWidth = {22, '1x'};
            app.toolGrid.RowHeight = {4, 17, 2};
            app.toolGrid.ColumnSpacing = 5;
            app.toolGrid.RowSpacing = 0;
            app.toolGrid.Padding = [5 5 5 5];
            app.toolGrid.Layout.Row = 12;
            app.toolGrid.Layout.Column = [1 14];
            app.toolGrid.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create tool_ExportButton
            app.tool_ExportButton = uiimage(app.toolGrid);
            app.tool_ExportButton.ScaleMethod = 'none';
            app.tool_ExportButton.Enable = 'off';
            app.tool_ExportButton.Layout.Row = 2;
            app.tool_ExportButton.Layout.Column = 1;
            app.tool_ExportButton.ImageSource = 'Export_16.png';

            % Create NOMEDAEMPRESAMetadadosOutrascoisasLabel_2
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2 = uilabel(app.toolGrid);
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.HorizontalAlignment = 'right';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.VerticalAlignment = 'top';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.WordWrap = 'on';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.FontSize = 9;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.FontColor = [0.149 0.149 0.149];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Layout.Row = [1 3];
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Layout.Column = 2;
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Interpreter = 'html';
            app.NOMEDAEMPRESAMetadadosOutrascoisasLabel_2.Text = {'<font style="font-size: 11px; font-weight: bold;">NOME DA EMPRESA</font> CNPJ 10.101.101/0001-02 '; '01/01/2023 - 31/12/2023 '};

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
