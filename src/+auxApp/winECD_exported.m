classdef winECD_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        GridLayout                  matlab.ui.container.GridLayout
        dockModuleGrid              matlab.ui.container.GridLayout
        dockModule_Undock           matlab.ui.control.Image
        dockModule_Close            matlab.ui.control.Image
        toolGrid                    matlab.ui.container.GridLayout
        Image5                      matlab.ui.control.Image
        file_ReportRFB              matlab.ui.control.Image
        tool_CompanyInfo            matlab.ui.control.Label
        UITable2_AccountInfo        matlab.ui.control.Label
        UITable2_FilterText         matlab.ui.control.Label
        UITable2_CountText          matlab.ui.control.Label
        UITable2_CountIcon          matlab.ui.control.Image
        UITable2                    matlab.ui.control.Table
        UITable1_AccountInfo        matlab.ui.control.Label
        UITable1_FilterText         matlab.ui.control.Label
        UITable1_CountText          matlab.ui.control.Label
        UITable1_CountIcon          matlab.ui.control.Image
        UITable1                    matlab.ui.control.Table
        TabGroup                    matlab.ui.container.TabGroup
        Tab1                        matlab.ui.container.Tab
        GridLayout3                 matlab.ui.container.GridLayout
        tool_ReadAllTables_2        matlab.ui.control.Image
        Image4                      matlab.ui.control.Image
        Separator1_3                matlab.ui.control.Image
        SheetViewStatus_3           matlab.ui.control.Button
        tool_OpenRTFFiles           matlab.ui.control.Image
        Separator1_2                matlab.ui.control.Image
        SheetList                   matlab.ui.control.DropDown
        SheetListLabel              matlab.ui.control.Label
        TimePeriodList              matlab.ui.control.DropDown
        TimePeriodListLabel         matlab.ui.control.Label
        CompanyNameList             matlab.ui.control.DropDown
        CompanyNameListLabel        matlab.ui.control.Label
        Tab2                        matlab.ui.container.Tab
        GridLayout_2                matlab.ui.container.GridLayout
        Image6                      matlab.ui.control.Image
        Separator2_2                matlab.ui.control.Image
        ColumnWidthLabel_2          matlab.ui.control.Label
        FontIcon                    matlab.ui.control.DropDown
        FontColor                   matlab.ui.control.ColorPicker
        FontBackground              matlab.ui.control.ColorPicker
        FontAlign3                  matlab.ui.control.Image
        FontAlign2                  matlab.ui.control.Image
        FontAlign1                  matlab.ui.control.Image
        FontStyle                   matlab.ui.control.Button
        FontWeight                  matlab.ui.control.Button
        FontFamily                  matlab.ui.control.DropDown
        Separator2                  matlab.ui.control.Image
        ColumnWidthLabel            matlab.ui.control.Label
        ColumnWidth                 matlab.ui.control.DropDown
        RowHeightLabel              matlab.ui.control.Label
        RowHeight                   matlab.ui.control.Spinner
        Separator1                  matlab.ui.control.Image
        SheetOnFocus                matlab.ui.control.Lamp
        SheetHeight_Second          matlab.ui.control.Spinner
        SheetView_Second            matlab.ui.control.DropDown
        SheetHeight_First           matlab.ui.control.Spinner
        SheetView_First             matlab.ui.control.DropDown
        SheetViewStatus             matlab.ui.control.StateButton
        Tab3                        matlab.ui.container.Tab
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
        Tab4                        matlab.ui.container.Tab
        GridLayout5                 matlab.ui.container.GridLayout
    end

    
    properties (Access = public)
        %-----------------------------------------------------------------%
        Container
        isDocked = false

        mainApp

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
        popupContainer

        %-----------------------------------------------------------------%
        % ESPECIFICIDADES AUXAPP.ECD
        %-----------------------------------------------------------------%
        projectData
        ecdObj
    end


    methods
        %-----------------------------------------------------------------%
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

        %-----------------------------------------------------------------%
        function varargout = ipcMainMatlabCallsHandler(app, callingApp, operationType, varargin)
            varargout = {};

            try
                switch class(callingApp)
                    case {'winMonitorSPED', 'winMonitorSPED_exported'}
                        switch operationType
                            case 'closeFcn'
                                app.popupContainer.Parent.Visible = 0;

                            otherwise
                                error('UnexpectedCall')
                        end
    
                    otherwise
                        error('UnexpectedCall')
                end

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', getReport(ME));            
            end

            % Caso um app auxiliar esteja em modo DOCK, o progressDialog do
            % app auxiliar coincide com o do appAnalise. Força-se, portanto, 
            % a condição abaixo para evitar possível bloqueio da tela.
            app.progressDialog.Visible = 'hidden';
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
                            % Grid botões "dock":
                            if app.isDocked
                                elToModify = {app.dockModuleGrid};
                                elDataTag  = ui.CustomizationBase.getElementsDataTag(elToModify);
                                if ~isempty(elDataTag)
                                    appName = class(app);                    
                                    sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', { ...
                                        struct('appName', appName, 'dataTag', elDataTag{1}, 'style', struct('transition', 'opacity 2s ease', 'opacity', '0.5')) ...
                                    });
                                end
                            end

                            % Outros elementos:
                            hTableList = {app.UITable1, app.UITable2};
                            ui.CustomizationBase.getElementsDataTag(hTableList);

                        case 2
                            app.FontFamily.Items = [{''}; listfonts];

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
            if ~strcmp(app.mainApp.executionMode, 'webApp')
                app.dockModule_Undock.Enable = 1;
            end

            % Tabelas:
            app.UITable1.RowName  = 'numbered';
            app.UITable2.RowName = 'numbered';
            restartTableSelectionControl(app, app.UITable1, app.UITable1_CountText)
            restartTableSelectionControl(app, app.UITable2, app.UITable2_CountText)

            % Seleção inicial:
            if ~isempty(app.ecdObj)
                idsList = {app.ecdObj.CompanyId};
                [ids, ~, idsIndexes] = unique(idsList);

                idsNames = {};
                mappingIds = dictionary();
                
                for ii = 1:numel(ids)
                    idIndexes = find(ii == idsIndexes);
                    [~, idSortedIndexes] = sort(arrayfun(@(x) x.Period(2), app.ecdObj(idIndexes)));

                    % Nome empresa que aparecerá no dropdown (idêntico à
                    % forma da uitree, no winMonitorSPED.mlapp)
                    idsNames{end+1} = util.HtmlTextGenerator.generateTextId(app.ecdObj(idIndexes(1)), 'company-oriented');
                    mappingIds = mappingIds.insert(string(ids{ii}), {idIndexes(idSortedIndexes)});
                end

                % Empresas:
                app.CompanyNameList.Items = idsNames;
                app.CompanyNameList.UserData = mappingIds;

                % A seleção buscará respeitar aquilo que estiver selecionado 
                % em winMonitorSPED.mlapp.
                fileIndex = 1;
                if ~isempty(app.mainApp.file_Tree.SelectedNodes)
                    fileIndex = unique([app.mainApp.file_Tree.SelectedNodes.NodeData], 'stable');
                    fileIndex = fileIndex(1);
                end
                selectedCompanyIndex = find(cellfun(@(x) ismember(fileIndex, x), app.CompanyNameList.UserData.values), 1);
                app.CompanyNameList.Value = app.CompanyNameList.Items{selectedCompanyIndex};
                
                updateTimePeriodList(app, fileIndex)
                TimePeriodListValueChanged(app)
            end

            % app.Image3.UserData = false;
            % app.DropDown.Items = listfonts;
        end

        %-----------------------------------------------------------------%
        function menu_LayoutPopupApp(app, auxiliarApp, varargin)
            arguments
                app
                auxiliarApp char {mustBeMember(auxiliarApp, {'ReportLib'})}
            end

            arguments (Repeating)
                varargin 
            end

            % Inicialmente ajusta as dimensões do container.
            switch auxiliarApp
                case 'ReportLib'
                    screenWidth  = 460;
                    screenHeight = 308;
            end

            ui.PopUpContainer(app, class.Constants.appName, screenWidth, screenHeight)

            % Executa o app auxiliar.
            inputArguments = [{app}, varargin];
            
            if app.mainApp.General.operationMode.Debug
                eval(sprintf('auxApp.dock%s(inputArguments{:})', auxiliarApp))
            else
                eval(sprintf('auxApp.dock%s_exported(app.popupContainer, inputArguments{:})', auxiliarApp))
                app.popupContainer.Parent.Visible = 1;
            end            
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function companyIndexes = selectedFileIndexByCompany(app)
            companyId      = extractBefore(app.CompanyNameList.Value, ' -');
            companyIndexes = cell2mat(app.CompanyNameList.UserData(companyId));
        end

        %-----------------------------------------------------------------%
        function fileIndex = selectedFileIndex(app)
            companyIndexes  = selectedFileIndexByCompany(app);
             [~, companySortedIndexes] = sort(arrayfun(@(x) x.Period(2), app.ecdObj(companyIndexes)));
             companyIndexes = companyIndexes(companySortedIndexes);

            if isnumeric(app.TimePeriodList.Value)
                fileIndex = companyIndexes(app.TimePeriodList.Value);
            else
                fileIndex = companyIndexes(strcmp(app.TimePeriodList.Items, app.TimePeriodList.Value));
            end

            if ~isscalar(fileIndex)
                fileIndex  = fileIndex(1);
            end
        end

        %-----------------------------------------------------------------%
        function updateTimePeriodList(app, fileIndex)
            companyIndexes = selectedFileIndexByCompany(app);
            [~, companySortedIndexes] = sort(arrayfun(@(x) x.Period(2), app.ecdObj(companyIndexes)));
            
            companyIndexes = companyIndexes(companySortedIndexes);
            if isempty(fileIndex)
                selectedPeriodIndex = 1;
            else
                [~, selectedPeriodIndex] = ismember(fileIndex, companyIndexes);
            end

            periodList = {};
            for ii = 1:numel(companyIndexes)
                idx = companyIndexes(ii);
                periodList{end+1} = util.HtmlTextGenerator.generateTextId(app.ecdObj(idx), 'period-oriented', true);
            end

            set(app.TimePeriodList, 'Items', periodList, 'ItemsData', 1:numel(periodList))
            app.TimePeriodList.Value = selectedPeriodIndex;
        end

        %-----------------------------------------------------------------%
        function updateSheetList(app)
            fileIndex    = selectedFileIndex(app);
            selectedECD  = app.ecdObj(fileIndex);

            [ordinaryIds, customIds] = getTableIds(selectedECD);
            sheetsSorted = [ordinaryIds; customIds];

            app.SheetList.Items        = sheetsSorted;
            app.SheetView_First.Items  = sheetsSorted;
            app.SheetView_Second.Items = sheetsSorted;
        end

        %-----------------------------------------------------------------%
        function updateTable(app, hTable, hTableAccountInfo, hTableCountText, hTableFilterText, tableId)
            fileIndex    = selectedFileIndex(app);
            selectedECD  = app.ecdObj(fileIndex);

            if ~startsWith(tableId, 'm')
                tableIdField = ['x' tableId];
                isTableRead(selectedECD, {tableId})
            else
                tableIdField = tableId;
            end            
            tableIdData = selectedECD.Table.(tableIdField);
            
            columnName  = tableIdData.Properties.VariableNames;
            columnEditable = contains(columnName, '✎');
            
            set(hTable, 'ColumnWidth', 'auto', ...
                        'ColumnName', columnName, ...
                        'ColumnEditable', columnEditable, ...
                        'Data', tableIdData)
            hTable.UserData.tableId = tableId;

            restartTableSelectionControl(app, hTable, hTableAccountInfo, hTableCountText)
            applyTableStyle(app, selectedECD, hTable, tableId)

            if height(hTable.Data) > 1
                numberOfRowsText = sprintf('%d DE %d LINHAS ', height(hTable.Data), height(hTable.Data)); % PENDENTE FILTRAGEM
            else
                numberOfRowsText = sprintf('%d DE %d LINHA ',  height(hTable.Data), height(hTable.Data)); % PENDENTE FILTRAGEM
            end
            hTableFilterText.Text = numberOfRowsText;
        end

        %-----------------------------------------------------------------%
        function restartTableSelectionControl(app, hTable, hTableAccountInfo, hTableCountText)
            hTable.Selection = [];
            
            % ().UserData.id armazenará o "data-tag" do componente, caso haja
            % alguma customização em curso.
            hTable.UserData.Selection = [];
            hTable.UserData.SelectionType = 'none';

            hTableAccountInfo.Text = '';
            hTableCountText.Text   = '  CONTAGEM: 0';
        end

        %-----------------------------------------------------------------%
        function applyTableStyle(app, selectedECD, hTable, tableId)
            if ~isempty(hTable.StyleConfigurations)
                removeStyle(hTable)
            end
            
            tableIdIndex = find(strcmp({selectedECD.GUI.tableView.id}, tableId), 1);
            if ~isempty(tableIdIndex)
                styleConfigTable = selectedECD.GUI.tableView(tableIdIndex).style;
                for ii = 1:height(styleConfigTable)
                    addStyle(hTable, styleConfigTable.Style(ii), styleConfigTable.Target(ii), styleConfigTable.TargetIndex{ii})
                end
            end
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
            
            app.mainApp     = mainApp;
            app.projectData = mainApp.projectData;
            app.ecdObj      = mainApp.ecdObj;

            if app.isDocked
                app.GridLayout.Padding(4)  = 30;
                app.dockModuleGrid.Visible = 1;
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

        % Image clicked function: dockModule_Close, dockModule_Undock
        function DockModuleGroup_ButtonPushed(app, event)
            
            [idx, auxAppTag, relatedButton] = getAppInfoFromHandle(app.mainApp.tabGroupController, app);

            switch event.Source
                case app.dockModule_Undock
                    appGeneral = app.mainApp.General;
                    appGeneral.operationMode.Dock = false;

                    inputArguments = ipcMainMatlabCallsHandler(app.mainApp, app, 'dockButtonPushed', auxAppTag);
                    app.mainApp.tabGroupController.Components.appHandle{idx} = [];
                    
                    openModule(app.mainApp.tabGroupController, relatedButton, false, appGeneral, inputArguments{:})
                    closeModule(app.mainApp.tabGroupController, auxAppTag, app.mainApp.General, 'undock')
                    
                    delete(app)

                case app.dockModule_Close
                    closeModule(app.mainApp.tabGroupController, auxAppTag, app.mainApp.General)
            end

        end

        % Image clicked function: Image4
        function Toolbar_LOGInfoImageClicked(app, event)
            
            fileIndex   = selectedFileIndex(app);
            selectedECD = app.ecdObj(fileIndex);

            htmlContent = util.HtmlTextGenerator.Warnings(selectedECD);
            appUtil.modalWindow(app.UIFigure, 'info', htmlContent);

        end

        % Image clicked function: file_ReportRFB
        function Toolbar_ReportImageClicked(app, event)
            
        end

        % Button pushed function: SheetViewStatus_3
        function Toolbar_ExportImageClicked(app, event)
            
            fileIndex   = selectedFileIndex(app);
            selectedECD = app.ecdObj(fileIndex);

            nameFormatMap = {'*.xlsx', 'Excel (*.xlsx)'};
            defaultName   = appUtil.DefaultFileName(app.mainApp.General.fileFolder.userPath, 'monitorSPED', -1);
            [fileFullPath, ~, ~, fileName] = appUtil.modalWindow(app.UIFigure, 'uiputfile', '', nameFormatMap, defaultName);
            if isempty(fileFullPath)
                return
            end

            app.progressDialog.Visible = 'visible';

            try
                tempName = fullfile(app.mainApp.General.fileFolder.userPath, [fileName '.xlsx']);
                tableIds = setdiff(fieldnames(selectedECD.Table), {'x0000'});
                
                writetable(selectedECD.Table.x0000, tempName, "Sheet", "0000", "WriteMode", "replacefile")
                for ii = 1:numel(tableIds)
                    tableId = tableIds{ii};                    
                    writetable(selectedECD.Table.(tableId), tempName, "Sheet", tableId(2:end), "WriteMode", "append")
                end

                copyfile(tempName, fileFullPath, 'f')

                if ~strcmp(app.mainApp.executionMode, 'webApp')
                    ccTools.fcn.OperationSystem('openFile', fileFullPath)
                end

            catch ME
                appUtil.modalWindow(app.UIFigure, 'warning', getReport(ME));
            end

            app.progressDialog.Visible = 'hidden';

        end

        % Image clicked function: tool_OpenRTFFiles
        function Toolbar_OpenRTFImageClicked(app, event)
            
            fileIndex   = selectedFileIndex(app);
            selectedECD = app.ecdObj(fileIndex);

            rtfFiles    = {};
            msgError    = {};

            rtfTableIds = {'J800', 'J801'};
            parseTableAndAddToCache(selectedECD, rtfTableIds)

            defaultName = appUtil.DefaultFileName(app.mainApp.General.fileFolder.userPath, 'monitorSPED');
            tempName    = appUtil.DefaultFileName(app.mainApp.General.fileFolder.tempPath, 'monitorSPED');
            fileCount   = 0;

            app.progressDialog.Visible = 'visible';
            
            for ii = 1:numel(rtfTableIds)
                rtfTableField = ['x' rtfTableIds{ii}];
        
                if isfield(selectedECD.Table, rtfTableField) && ~isempty(selectedECD.Table.(rtfTableField))
                    for jj = 1:height(selectedECD.Table.(rtfTableField))
                        fileCount = fileCount+1;
                        fileName  = sprintf('%s_%d.rtf', tempName, fileCount);
                        
                        try
                            util.recreateRTF(selectedECD.Table.(rtfTableField).('ARQ_RTF'){jj}, fileName)
                            rtfFiles{end+1} = fileName;

                        catch ME
                            msgError{end+1} = ME.message;
                        end
                    end
                end
            end

            app.progressDialog.Visible = 'hidden';

            if ~isempty(rtfFiles)
                appName = class.Constants.appName;

                if isscalar(rtfFiles) && ~strcmp(app.mainApp.executionMode, 'webApp')
                    nameFormat = {'*.rtf', [appName, ' (*.rtf)']};
                else
                    nameFormat = {'*.zip', [appName, ' (*.zip)']};
                end

                outputFile = appUtil.modalWindow(app.UIFigure, 'uiputfile', '', nameFormat, defaultName);
                if isempty(outputFile)
                    return
                end

                app.progressDialog.Visible = 'visible';

                if isscalar(rtfFiles) && ~strcmp(app.mainApp.executionMode, 'webApp')
                    copyfile(rtfFiles{1}, outputFile, 'f')
                else
                    zip(outputFile, rtfFiles)
                end

                if ~strcmp(app.mainApp.executionMode, 'webApp')
                    for kk = 1:numel(rtfFiles)
                        ccTools.fcn.OperationSystem('openFile', rtfFiles{kk})
                    end
                end

                app.progressDialog.Visible = 'hidden';
            else
                appUtil.modalWindow(app.UIFigure, 'info', sprintf('Escrituração não possui arquivo auxiliar no formato RTF.'));
            end
        
            if ~isempty(msgError)
                msgError = strjoin(msgError, '\n');
                appUtil.modalWindow(app.UIFigure, 'error', msgError);
            end

        end

        % Selection change function: TabGroup
        function TabGroupSelectionChanged(app, event)
            
            [~, tabIndex] = ismember(app.TabGroup.SelectedTab, app.TabGroup.Children);
            jsBackDoor_Customizations(app, tabIndex)

        end

        % Value changed function: CompanyNameList
        function CompanyNameListValueChanged(app, event)

            updateTimePeriodList(app, [])
            TimePeriodListValueChanged(app)

        end

        % Value changed function: TimePeriodList
        function TimePeriodListValueChanged(app, event)
            
            fileIndex   = selectedFileIndex(app);
            selectedECD = app.ecdObj(fileIndex);

            app.tool_CompanyInfo.Text = sprintf('<font style="font-size: 11px; font-weight: bold;">%s</font> CNPJ %s (%s) \n%s ', ...
                upper(selectedECD.CompanyName), selectedECD.CompanyId, selectedECD.State, strjoin(string(selectedECD.Period), ' a '));

            updateSheetList(app)
            SheetViewFirstValueChanged(app, struct('Source', app.SheetList))
            SheetViewSecondValueChanged(app)
            
        end

        % Value changed function: SheetList, SheetView_First
        function SheetViewFirstValueChanged(app, event)
            
            switch event.Source
                case app.SheetList
                    app.SheetView_First.Value = app.SheetList.Value;
                case app.SheetView_First
                    app.SheetList.Value = app.SheetView_First.Value;
            end

            updateTable(app, app.UITable1, app.UITable1_AccountInfo, app.UITable1_CountText, app.UITable1_FilterText, app.SheetList.Value)

        end

        % Value changed function: SheetView_Second
        function SheetViewSecondValueChanged(app, event)
            
            updateTable(app, app.UITable2, app.UITable2_AccountInfo, app.UITable2_CountText, app.UITable2_FilterText, app.SheetView_Second.Value)
            
        end

        % Value changed function: SheetViewStatus
        function SheetViewStatusValueChanged(app, event)
            
            if app.SheetViewStatus.Value
                app.SheetView_Second.Enable  = "on";
                app.SheetHeight_First.Enable = 'on';

                app.SheetHeight_Second.Limits(1) = 1;
                set(app.SheetHeight_Second, 'Enable', 'on', 'Value', app.SheetHeight_First.Value)
                
                app.UITable2.Visible = 'on';
                rowHeight = {10,2,22};
                
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

            SheetViewHeightValueChanged(app, struct('Source', app.SheetHeight_First))
            app.GridLayout.RowHeight([9,11,12]) = rowHeight;
            
        end

        % Value changed function: SheetHeight_First, SheetHeight_Second
        function SheetViewHeightValueChanged(app, event)
            
            app.GridLayout.RowHeight([6,10]) = {sprintf('%dx', app.SheetHeight_First.Value), sprintf('%dx', app.SheetHeight_Second.Value)};

        end

        % Callback function: UITable1, UITable1, UITable2, UITable2
        function TableClicked(app, event)
            
            clickedTable = event.Source;

            switch event.EventName
                case 'Clicked'
                    clickedRow = event.InteractionInformation.DisplayRow;
                    clickedCol = event.InteractionInformation.DisplayColumn;
                case 'KeyRelease'
                    if isempty(clickedTable.Selection)
                        clickedRow = [];
                        clickedCol = [];
                    else
                        clickedRow = clickedTable.Selection(:,1);
                        clickedCol = clickedTable.Selection(:,2);
                    end
            end

            switch clickedTable
                case app.UITable1
                    tableCountText       = app.UITable1_CountText;
                    tableSelectedAccount = app.UITable1_AccountInfo;
                    lampPositionRow      = 1;
                case app.UITable2
                    tableCountText       = app.UITable2_CountText;
                    tableSelectedAccount = app.UITable2_AccountInfo;
                    lampPositionRow      = 2;
            end

            % Altera tabela em evidência (uilamp), além de definir o tipo
            % de seleção (no caso de clique fora da região de células,
            % limpa-se a seleção prévia).
            if app.SheetOnFocus.Layout.Row ~= lampPositionRow
                app.SheetOnFocus.Layout.Row = lampPositionRow;
            end

            % Altera o tipo de seleção.
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

            % Altera informações no rodapé da tabela.
            if ~isequal(clickedTable.Selection, clickedTable.UserData.Selection)
                clickedTable.UserData.Selection = clickedTable.Selection;

                if isempty(clickedTable.Selection)
                    tableCountText.Text       = '  CONTAGEM: 0';
                    tableSelectedAccount.Text = '';                    
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

                    selectedRows = unique(clickedTable.Selection(:,1));
                    selectedAccountDescription = '';            
                    if isscalar(selectedRows) && ismember('COD_CTA', clickedTable.Data.Properties.VariableNames)
                        fileIndex   = selectedFileIndex(app);
                        selectedECD = app.ecdObj(fileIndex);
    
                        selectedAccount = clickedTable.Data.("COD_CTA"){selectedRows};
                        selectedAccountIndex = find(strcmp(selectedECD.Table.mDESCRICAO.("COD_CTA"), selectedAccount), 1);
            
                        if ~isempty(selectedAccountIndex)
                            selectedAccountDescription = sprintf('COD_CTA %s\n%s', selectedAccount, selectedECD.Table.mDESCRICAO.("DESCRIÇÃO"){selectedAccountIndex});
                        end
                    end                    
                    tableSelectedAccount.Text = selectedAccountDescription;
                end
            end

        end

        % Callback function: FontAlign1, FontAlign2, FontAlign3, 
        % ...and 6 other components
        function TableStyleChanged(app, event)
                        
            clickedTable = onFocusTable(app);
            if isempty(clickedTable.Selection)
                return
            end

            fileIndex   = selectedFileIndex(app);
            selectedECD = app.ecdObj(fileIndex);
            
            switch clickedTable
                case app.UITable1; tableId = app.SheetView_First.Value;
                case app.UITable2; tableId = app.SheetView_Second.Value;
            end

            % Lista atual de estilos:
            renderedTableIDStyleIndex = find(strcmp({selectedECD.GUI.tableView.id}, tableId), 1);
            if isempty(renderedTableIDStyleIndex)
                renderedTableIDStyleIndex = numel(selectedECD.GUI.tableView)+1;
            end
            
            % Estilo novo:
            switch event.Source
                case app.FontFamily
                    fieldName  = 'FontName';
                    fieldValue = {app.FontFamily.Value};
                    app.FontFamily.Value = '';

                case app.FontWeight
                    fieldName  = 'FontWeight';
                    fieldValue = {'bold', 'normal'};

                case app.FontStyle
                    fieldName  = 'FontAngle';
                    fieldValue = {'italic', 'normal'};

                case {app.FontAlign1, app.FontAlign2, app.FontAlign3}
                    fieldName  = 'HorizontalAlignment';
                    switch event.Source
                        case app.FontAlign1; fieldValue = {'left'};
                        case app.FontAlign2; fieldValue = {'center'};
                        case app.FontAlign3; fieldValue = {'right'};
                    end

                case app.FontBackground
                    fieldName  = 'BackgroundColor';
                    fieldValue = {event.Value};
                    app.FontBackground.Value = [1 0 0.0118];

                case app.FontColor
                    fieldName  = 'FontColor';
                    fieldValue = {event.Value};
                    app.FontColor.Value = [0 0 0.0118];

                case app.FontIcon
                    fieldName  = 'Icon';
                    fieldValue = {event.Value};
                    app.FontIcon.Value = '';
            end

            % Verifica se já existe estilo aplicado às células selecionadas:
            styleIndex = find(cellfun(@(x) isequal(clickedTable.Selection, x), clickedTable.StyleConfigurations.TargetIndex));
            if ~isempty(styleIndex)
                styleIndex = styleIndex(end);
                s = clickedTable.StyleConfigurations.Style(styleIndex);                
                removeStyle(clickedTable, styleIndex)
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

            addStyle(clickedTable, s, "cell", clickedTable.Selection)
            if strcmp(app.SheetView_First.Value, app.SheetView_Second.Value)
                otherTable = setdiff([app.UITable1, app.UITable2], clickedTable);
                addStyle(otherTable, s, "cell", clickedTable.Selection)
            end

            selectedECD.GUI.tableView(renderedTableIDStyleIndex).id = tableId;
            selectedECD.GUI.tableView(renderedTableIDStyleIndex).style = clickedTable.StyleConfigurations;
            
        end

        % Value changed function: RowHeight
        function TableRowHeightChanged(app, event)

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
                
                if app.RowHeight.Value
                    defaultProp   = regexp(hTable.StyleObservations.height, '(?<height>\d+[.]?\d*)px', 'names');
                    defaultHeight = str2double(defaultProp.height);

                    sendEventToHTMLSource(app.jsBackDoor, 'changeTableRowHeight', defaultHeight + app.RowHeight.Value);
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

        % Value changed function: ColumnWidth
        function ColumnWidthValueChanged(app, event)
            
            if ~isempty(app.ColumnWidth.Value)
                hTable = onFocusTable(app);

                if isequal(hTable.ColumnWidth, app.ColumnWidth.Value)
                    widthOptions = setdiff(app.ColumnWidth.Items, {'', app.ColumnWidth.Value});
                    hTable.ColumnWidth = widthOptions{1};
                    drawnow
                end

                hTable.ColumnWidth = app.ColumnWidth.Value;
                app.ColumnWidth.Value = '';
            end
            
        end

        % Image clicked function: Image6
        function Image6Clicked(app, event)
            
            clickedTable = onFocusTable(app);
            if isempty(clickedTable.Selection)
                return
            end

            fileIndex   = selectedFileIndex(app);
            selectedECD = app.ecdObj(fileIndex);
            
            switch clickedTable
                case app.UITable1; tableId = app.SheetView_First.Value;
                case app.UITable2; tableId = app.SheetView_Second.Value;
            end

            % Lista atual de estilos:
            renderedTableIDStyleIndex = find(strcmp({selectedECD.GUI.tableView.id}, tableId), 1);
            if ~isempty(renderedTableIDStyleIndex)
                styleIndex = find(cellfun(@(x) isequal(clickedTable.Selection, x), clickedTable.StyleConfigurations.TargetIndex));

                if ~isempty(styleIndex)             
                    removeStyle(clickedTable, styleIndex)

                    if strcmp(app.SheetView_First.Value, app.SheetView_Second.Value)
                        otherTable = setdiff([app.UITable1, app.UITable2], clickedTable);
                        removeStyle(otherTable, styleIndex)
                    end
        
                    selectedECD.GUI.tableView(renderedTableIDStyleIndex).id = tableId;
                    selectedECD.GUI.tableView(renderedTableIDStyleIndex).style = clickedTable.StyleConfigurations;
                end
            end

        end

        % Image clicked function: tool_ReadAllTables_2
        function CreateMergedTablesImageClicked(app, event)
            
            app.progressDialog.Visible = 'visible';

            try
                fileIndex   = selectedFileIndex(app);
                selectedECD = app.ecdObj(fileIndex);

                parseTableAndAddToCache(selectedECD, {'I050_I051_I052', 'I200_I250', 'C050_C051_C052'})
            
                % Registros de fatos contáveis, além do balancete mensal e, por fim, do
                % balancete das contas de resultados.
                model.TableGenerator.SummaryByAccount(selectedECD);
                model.TableGenerator.SummaryByAccountType(selectedECD, selectedECD.Table.mAccountSummary, '04');

                TimePeriodListValueChanged(app)

            catch ME
                appUtil.modalWindow(app.UIFigure, 'error', ME.message);
            end

            app.progressDialog.Visible = 'hidden';

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
            app.GridLayout.ColumnWidth = {10, 18, 320, '1x', 300, 48, 8, 2};
            app.GridLayout.RowHeight = {2, 8, 24, 70, 10, '1x', 2, 22, 0, 0, 2, 0, 10, 34};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.AutoResizeChildren = 'off';
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
            app.TabGroup.Layout.Row = [3 4];
            app.TabGroup.Layout.Column = [2 6];

            % Create Tab1
            app.Tab1 = uitab(app.TabGroup);
            app.Tab1.AutoResizeChildren = 'off';
            app.Tab1.Title = 'ASPECTOS GERAIS';
            app.Tab1.BackgroundColor = 'none';

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.Tab1);
            app.GridLayout3.ColumnWidth = {90, 230, 60, 229, 3, 20, 170, 3, 44, 44, 44};
            app.GridLayout3.RowHeight = {22, 22};
            app.GridLayout3.RowSpacing = 5;
            app.GridLayout3.BackgroundColor = [0.9804 0.9804 0.9804];

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
            app.CompanyNameList.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
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
            app.TimePeriodList.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
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
            app.SheetListLabel.Text = 'REGISTRO:';

            % Create SheetList
            app.SheetList = uidropdown(app.GridLayout3);
            app.SheetList.Items = {};
            app.SheetList.ValueChangedFcn = createCallbackFcn(app, @SheetViewFirstValueChanged, true);
            app.SheetList.FontSize = 11;
            app.SheetList.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.SheetList.BackgroundColor = [1 1 1];
            app.SheetList.Layout.Row = 2;
            app.SheetList.Layout.Column = 4;
            app.SheetList.Value = {};

            % Create Separator1_2
            app.Separator1_2 = uiimage(app.GridLayout3);
            app.Separator1_2.Enable = 'off';
            app.Separator1_2.Layout.Row = [1 2];
            app.Separator1_2.Layout.Column = 5;
            app.Separator1_2.ImageSource = 'LineV.svg';

            % Create tool_OpenRTFFiles
            app.tool_OpenRTFFiles = uiimage(app.GridLayout3);
            app.tool_OpenRTFFiles.ScaleMethod = 'none';
            app.tool_OpenRTFFiles.ImageClickedFcn = createCallbackFcn(app, @Toolbar_OpenRTFImageClicked, true);
            app.tool_OpenRTFFiles.Tooltip = {'Abre/Salva arquivos .rtf'; '(Registros J800 e J801)'};
            app.tool_OpenRTFFiles.Layout.Row = [1 2];
            app.tool_OpenRTFFiles.Layout.Column = 9;
            app.tool_OpenRTFFiles.ImageSource = 'Publish_PDF_16.png';

            % Create SheetViewStatus_3
            app.SheetViewStatus_3 = uibutton(app.GridLayout3, 'push');
            app.SheetViewStatus_3.ButtonPushedFcn = createCallbackFcn(app, @Toolbar_ExportImageClicked, true);
            app.SheetViewStatus_3.Icon = 'Export_24.png';
            app.SheetViewStatus_3.IconAlignment = 'top';
            app.SheetViewStatus_3.BackgroundColor = [0.9608 0.9608 0.9608];
            app.SheetViewStatus_3.FontSize = 10;
            app.SheetViewStatus_3.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.SheetViewStatus_3.Layout.Row = [1 2];
            app.SheetViewStatus_3.Layout.Column = 10;
            app.SheetViewStatus_3.Text = 'EXCEL';

            % Create Separator1_3
            app.Separator1_3 = uiimage(app.GridLayout3);
            app.Separator1_3.Enable = 'off';
            app.Separator1_3.Layout.Row = [1 2];
            app.Separator1_3.Layout.Column = 8;
            app.Separator1_3.ImageSource = 'LineV.svg';

            % Create Image4
            app.Image4 = uiimage(app.GridLayout3);
            app.Image4.ScaleMethod = 'none';
            app.Image4.ImageClickedFcn = createCallbackFcn(app, @Toolbar_LOGInfoImageClicked, true);
            app.Image4.Layout.Row = [1 2];
            app.Image4.Layout.Column = 11;
            app.Image4.ImageSource = 'LOG_32.png';

            % Create tool_ReadAllTables_2
            app.tool_ReadAllTables_2 = uiimage(app.GridLayout3);
            app.tool_ReadAllTables_2.ScaleMethod = 'none';
            app.tool_ReadAllTables_2.ImageClickedFcn = createCallbackFcn(app, @CreateMergedTablesImageClicked, true);
            app.tool_ReadAllTables_2.Tooltip = {'Cria registros mesclados'; '(inclusive Balancete)'};
            app.tool_ReadAllTables_2.Layout.Row = 2;
            app.tool_ReadAllTables_2.Layout.Column = 6;
            app.tool_ReadAllTables_2.ImageSource = 'run_all_tests_16.png';

            % Create Tab2
            app.Tab2 = uitab(app.TabGroup);
            app.Tab2.AutoResizeChildren = 'off';
            app.Tab2.Title = 'LAYOUT';
            app.Tab2.BackgroundColor = 'none';

            % Create GridLayout_2
            app.GridLayout_2 = uigridlayout(app.Tab2);
            app.GridLayout_2.ColumnWidth = {44, 226, 40, 10, 3, 90, 90, 3, 22, 22, 22, 22, 22, 44, 44, 3, 90, '1x', 16};
            app.GridLayout_2.RowHeight = {22, 22};
            app.GridLayout_2.RowSpacing = 5;
            app.GridLayout_2.BackgroundColor = [0.9804 0.9804 0.9804];

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
            app.SheetView_First.ValueChangedFcn = createCallbackFcn(app, @SheetViewFirstValueChanged, true);
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
            app.SheetHeight_First.ValueChangedFcn = createCallbackFcn(app, @SheetViewHeightValueChanged, true);
            app.SheetHeight_First.FontSize = 11;
            app.SheetHeight_First.Enable = 'off';
            app.SheetHeight_First.Layout.Row = 1;
            app.SheetHeight_First.Layout.Column = 3;
            app.SheetHeight_First.Value = 1;

            % Create SheetView_Second
            app.SheetView_Second = uidropdown(app.GridLayout_2);
            app.SheetView_Second.Items = {};
            app.SheetView_Second.ValueChangedFcn = createCallbackFcn(app, @SheetViewSecondValueChanged, true);
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
            app.SheetHeight_Second.ValueChangedFcn = createCallbackFcn(app, @SheetViewHeightValueChanged, true);
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

            % Create RowHeight
            app.RowHeight = uispinner(app.GridLayout_2);
            app.RowHeight.Step = 5;
            app.RowHeight.Limits = [0 50];
            app.RowHeight.RoundFractionalValues = 'on';
            app.RowHeight.ValueDisplayFormat = '%d';
            app.RowHeight.ValueChangedFcn = createCallbackFcn(app, @TableRowHeightChanged, true);
            app.RowHeight.FontSize = 11;
            app.RowHeight.Layout.Row = 1;
            app.RowHeight.Layout.Column = 6;

            % Create RowHeightLabel
            app.RowHeightLabel = uilabel(app.GridLayout_2);
            app.RowHeightLabel.HorizontalAlignment = 'center';
            app.RowHeightLabel.WordWrap = 'on';
            app.RowHeightLabel.FontSize = 10;
            app.RowHeightLabel.Layout.Row = 2;
            app.RowHeightLabel.Layout.Column = 6;
            app.RowHeightLabel.Text = {'ALTURA LINHA'; '(offset)'};

            % Create ColumnWidth
            app.ColumnWidth = uidropdown(app.GridLayout_2);
            app.ColumnWidth.Items = {'', 'auto', 'fit', '1x'};
            app.ColumnWidth.ValueChangedFcn = createCallbackFcn(app, @ColumnWidthValueChanged, true);
            app.ColumnWidth.FontSize = 11;
            app.ColumnWidth.BackgroundColor = [1 1 1];
            app.ColumnWidth.Layout.Row = 1;
            app.ColumnWidth.Layout.Column = 7;
            app.ColumnWidth.Value = '';

            % Create ColumnWidthLabel
            app.ColumnWidthLabel = uilabel(app.GridLayout_2);
            app.ColumnWidthLabel.HorizontalAlignment = 'center';
            app.ColumnWidthLabel.WordWrap = 'on';
            app.ColumnWidthLabel.FontSize = 10;
            app.ColumnWidthLabel.Layout.Row = 2;
            app.ColumnWidthLabel.Layout.Column = 7;
            app.ColumnWidthLabel.Text = {'LARGURA'; 'COLUNA'};

            % Create Separator2
            app.Separator2 = uiimage(app.GridLayout_2);
            app.Separator2.Enable = 'off';
            app.Separator2.Layout.Row = [1 2];
            app.Separator2.Layout.Column = 8;
            app.Separator2.ImageSource = 'LineV.svg';

            % Create FontFamily
            app.FontFamily = uidropdown(app.GridLayout_2);
            app.FontFamily.Items = {};
            app.FontFamily.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontFamily.Tooltip = {'Fonte'};
            app.FontFamily.FontSize = 11;
            app.FontFamily.BackgroundColor = [1 1 1];
            app.FontFamily.Layout.Row = 1;
            app.FontFamily.Layout.Column = [9 15];
            app.FontFamily.Value = {};

            % Create FontWeight
            app.FontWeight = uibutton(app.GridLayout_2, 'push');
            app.FontWeight.ButtonPushedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontWeight.BackgroundColor = [0.9804 0.9804 0.9804];
            app.FontWeight.FontName = 'Century';
            app.FontWeight.FontWeight = 'bold';
            app.FontWeight.Layout.Row = 2;
            app.FontWeight.Layout.Column = 9;
            app.FontWeight.Text = 'B';

            % Create FontStyle
            app.FontStyle = uibutton(app.GridLayout_2, 'push');
            app.FontStyle.ButtonPushedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontStyle.BackgroundColor = [0.9804 0.9804 0.9804];
            app.FontStyle.FontName = 'Century';
            app.FontStyle.FontAngle = 'italic';
            app.FontStyle.Layout.Row = 2;
            app.FontStyle.Layout.Column = 10;
            app.FontStyle.Text = 'I ';

            % Create FontAlign1
            app.FontAlign1 = uiimage(app.GridLayout_2);
            app.FontAlign1.ScaleMethod = 'none';
            app.FontAlign1.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign1.Tooltip = {'Sublinhado'};
            app.FontAlign1.Layout.Row = 2;
            app.FontAlign1.Layout.Column = 11;
            app.FontAlign1.ImageSource = 'AlignedLeft_16-7f46662cd6fd7221119660e14bdcea56.png';

            % Create FontAlign2
            app.FontAlign2 = uiimage(app.GridLayout_2);
            app.FontAlign2.ScaleMethod = 'none';
            app.FontAlign2.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign2.Tooltip = {'Sublinhado'};
            app.FontAlign2.Layout.Row = 2;
            app.FontAlign2.Layout.Column = 12;
            app.FontAlign2.ImageSource = 'AlignedCenter_16-b91485db227234029c43b7823c09ebff.png';

            % Create FontAlign3
            app.FontAlign3 = uiimage(app.GridLayout_2);
            app.FontAlign3.ScaleMethod = 'none';
            app.FontAlign3.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign3.Tooltip = {'Sublinhado'};
            app.FontAlign3.Layout.Row = 2;
            app.FontAlign3.Layout.Column = 13;
            app.FontAlign3.ImageSource = 'AlignedRight_16-7827788943408c9bac98181b7ad0efb5.png';

            % Create FontBackground
            app.FontBackground = uicolorpicker(app.GridLayout_2);
            app.FontBackground.Value = [1 0 0.0118];
            app.FontBackground.Icon = 'fill';
            app.FontBackground.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontBackground.Layout.Row = 2;
            app.FontBackground.Layout.Column = 14;
            app.FontBackground.BackgroundColor = [1 1 1];

            % Create FontColor
            app.FontColor = uicolorpicker(app.GridLayout_2);
            app.FontColor.Value = [0 0 0.0118];
            app.FontColor.Icon = 'text';
            app.FontColor.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontColor.Layout.Row = 2;
            app.FontColor.Layout.Column = 15;
            app.FontColor.BackgroundColor = [1 1 1];

            % Create FontIcon
            app.FontIcon = uidropdown(app.GridLayout_2);
            app.FontIcon.Items = {'', 'question', 'info', 'success', 'warning', 'error', 'none'};
            app.FontIcon.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontIcon.FontSize = 11;
            app.FontIcon.BackgroundColor = [1 1 1];
            app.FontIcon.Layout.Row = 1;
            app.FontIcon.Layout.Column = 17;
            app.FontIcon.Value = '';

            % Create ColumnWidthLabel_2
            app.ColumnWidthLabel_2 = uilabel(app.GridLayout_2);
            app.ColumnWidthLabel_2.HorizontalAlignment = 'center';
            app.ColumnWidthLabel_2.WordWrap = 'on';
            app.ColumnWidthLabel_2.FontSize = 10;
            app.ColumnWidthLabel_2.Layout.Row = 2;
            app.ColumnWidthLabel_2.Layout.Column = 17;
            app.ColumnWidthLabel_2.Text = 'ÍCONE';

            % Create Separator2_2
            app.Separator2_2 = uiimage(app.GridLayout_2);
            app.Separator2_2.Enable = 'off';
            app.Separator2_2.Layout.Row = [1 2];
            app.Separator2_2.Layout.Column = 16;
            app.Separator2_2.ImageSource = 'LineV.svg';

            % Create Image6
            app.Image6 = uiimage(app.GridLayout_2);
            app.Image6.ImageClickedFcn = createCallbackFcn(app, @Image6Clicked, true);
            app.Image6.Tooltip = {'Apaga estilos aplicados à tabela'};
            app.Image6.Layout.Row = 2;
            app.Image6.Layout.Column = 19;
            app.Image6.ImageSource = 'delete.svg';

            % Create Tab3
            app.Tab3 = uitab(app.TabGroup);
            app.Tab3.AutoResizeChildren = 'off';
            app.Tab3.Title = 'FILTRAGEM';
            app.Tab3.BackgroundColor = 'none';

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.Tab3);
            app.GridLayout4.ColumnWidth = {14, 40, 206, 40, 285, 3, '1x'};
            app.GridLayout4.RowHeight = {22, 22};
            app.GridLayout4.RowSpacing = 5;
            app.GridLayout4.BackgroundColor = [0.9804 0.9804 0.9804];

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

            % Create Tab4
            app.Tab4 = uitab(app.TabGroup);
            app.Tab4.AutoResizeChildren = 'off';
            app.Tab4.Title = 'TABELA CUSTOMIZADA';
            app.Tab4.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];

            % Create GridLayout5
            app.GridLayout5 = uigridlayout(app.Tab4);
            app.GridLayout5.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout5.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create UITable1
            app.UITable1 = uitable(app.GridLayout);
            app.UITable1.BackgroundColor = [1 1 1;0.9412 0.9412 0.9412];
            app.UITable1.ColumnName = '';
            app.UITable1.ColumnSortable = true;
            app.UITable1.ClickedFcn = createCallbackFcn(app, @TableClicked, true);
            app.UITable1.ForegroundColor = [0.149 0.149 0.149];
            app.UITable1.KeyReleaseFcn = createCallbackFcn(app, @TableClicked, true);
            app.UITable1.Layout.Row = 6;
            app.UITable1.Layout.Column = [2 6];
            app.UITable1.FontSize = 10.5;

            % Create UITable1_CountIcon
            app.UITable1_CountIcon = uiimage(app.GridLayout);
            app.UITable1_CountIcon.ScaleMethod = 'none';
            app.UITable1_CountIcon.Layout.Row = 8;
            app.UITable1_CountIcon.Layout.Column = 2;
            app.UITable1_CountIcon.ImageSource = 'selectColumn.png';

            % Create UITable1_CountText
            app.UITable1_CountText = uilabel(app.GridLayout);
            app.UITable1_CountText.FontSize = 10;
            app.UITable1_CountText.FontColor = [0.502 0.502 0.502];
            app.UITable1_CountText.Layout.Row = 8;
            app.UITable1_CountText.Layout.Column = 3;
            app.UITable1_CountText.Text = ' CONTAGEM : 0';

            % Create UITable1_FilterText
            app.UITable1_FilterText = uilabel(app.GridLayout);
            app.UITable1_FilterText.HorizontalAlignment = 'right';
            app.UITable1_FilterText.FontSize = 10;
            app.UITable1_FilterText.FontColor = [0.502 0.502 0.502];
            app.UITable1_FilterText.Layout.Row = 8;
            app.UITable1_FilterText.Layout.Column = [5 6];
            app.UITable1_FilterText.Text = '0 DE 0 ';

            % Create UITable1_AccountInfo
            app.UITable1_AccountInfo = uilabel(app.GridLayout);
            app.UITable1_AccountInfo.HorizontalAlignment = 'center';
            app.UITable1_AccountInfo.FontSize = 10;
            app.UITable1_AccountInfo.FontColor = [0.502 0.502 0.502];
            app.UITable1_AccountInfo.Layout.Row = 8;
            app.UITable1_AccountInfo.Layout.Column = [2 6];
            app.UITable1_AccountInfo.Text = '';

            % Create UITable2
            app.UITable2 = uitable(app.GridLayout);
            app.UITable2.BackgroundColor = [1 1 1;0.9412 0.9412 0.9412];
            app.UITable2.ColumnName = '';
            app.UITable2.RowName = {};
            app.UITable2.ColumnSortable = true;
            app.UITable2.ClickedFcn = createCallbackFcn(app, @TableClicked, true);
            app.UITable2.ForegroundColor = [0.149 0.149 0.149];
            app.UITable2.Visible = 'off';
            app.UITable2.KeyReleaseFcn = createCallbackFcn(app, @TableClicked, true);
            app.UITable2.Layout.Row = 10;
            app.UITable2.Layout.Column = [2 6];
            app.UITable2.FontSize = 10.5;

            % Create UITable2_CountIcon
            app.UITable2_CountIcon = uiimage(app.GridLayout);
            app.UITable2_CountIcon.ScaleMethod = 'none';
            app.UITable2_CountIcon.Layout.Row = 12;
            app.UITable2_CountIcon.Layout.Column = 2;
            app.UITable2_CountIcon.ImageSource = 'selectColumn.png';

            % Create UITable2_CountText
            app.UITable2_CountText = uilabel(app.GridLayout);
            app.UITable2_CountText.FontSize = 10;
            app.UITable2_CountText.FontColor = [0.502 0.502 0.502];
            app.UITable2_CountText.Layout.Row = 12;
            app.UITable2_CountText.Layout.Column = 3;
            app.UITable2_CountText.Text = ' CONTAGEM: 0';

            % Create UITable2_FilterText
            app.UITable2_FilterText = uilabel(app.GridLayout);
            app.UITable2_FilterText.HorizontalAlignment = 'right';
            app.UITable2_FilterText.FontSize = 10;
            app.UITable2_FilterText.FontColor = [0.502 0.502 0.502];
            app.UITable2_FilterText.Layout.Row = 12;
            app.UITable2_FilterText.Layout.Column = [5 6];
            app.UITable2_FilterText.Text = '0 DE 0';

            % Create UITable2_AccountInfo
            app.UITable2_AccountInfo = uilabel(app.GridLayout);
            app.UITable2_AccountInfo.HorizontalAlignment = 'center';
            app.UITable2_AccountInfo.FontSize = 10;
            app.UITable2_AccountInfo.FontColor = [0.502 0.502 0.502];
            app.UITable2_AccountInfo.Layout.Row = 12;
            app.UITable2_AccountInfo.Layout.Column = [2 6];
            app.UITable2_AccountInfo.Text = '';

            % Create toolGrid
            app.toolGrid = uigridlayout(app.GridLayout);
            app.toolGrid.ColumnWidth = {'1x', 22, 22};
            app.toolGrid.RowHeight = {4, 17, 2};
            app.toolGrid.ColumnSpacing = 5;
            app.toolGrid.RowSpacing = 0;
            app.toolGrid.Padding = [10 5 10 5];
            app.toolGrid.Layout.Row = 14;
            app.toolGrid.Layout.Column = [1 8];
            app.toolGrid.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create tool_CompanyInfo
            app.tool_CompanyInfo = uilabel(app.toolGrid);
            app.tool_CompanyInfo.VerticalAlignment = 'top';
            app.tool_CompanyInfo.WordWrap = 'on';
            app.tool_CompanyInfo.FontSize = 9;
            app.tool_CompanyInfo.FontColor = [0.149 0.149 0.149];
            app.tool_CompanyInfo.Layout.Row = [1 3];
            app.tool_CompanyInfo.Layout.Column = 1;
            app.tool_CompanyInfo.Interpreter = 'html';
            app.tool_CompanyInfo.Text = {'<font style="font-size: 11px; font-weight: bold;">NOME DA EMPRESA</font> CNPJ 10.101.101/0001-02 '; '01/01/2023 - 31/12/2023 '};

            % Create file_ReportRFB
            app.file_ReportRFB = uiimage(app.toolGrid);
            app.file_ReportRFB.ScaleMethod = 'none';
            app.file_ReportRFB.ImageClickedFcn = createCallbackFcn(app, @Toolbar_ReportImageClicked, true);
            app.file_ReportRFB.Tooltip = {'Gera relatório análise'};
            app.file_ReportRFB.Layout.Row = 2;
            app.file_ReportRFB.Layout.Column = 2;
            app.file_ReportRFB.ImageSource = 'Publish_HTML_16.png';

            % Create Image5
            app.Image5 = uiimage(app.toolGrid);
            app.Image5.Layout.Row = 2;
            app.Image5.Layout.Column = 3;
            app.Image5.ImageSource = 'Up_24.png';

            % Create dockModuleGrid
            app.dockModuleGrid = uigridlayout(app.GridLayout);
            app.dockModuleGrid.RowHeight = {'1x'};
            app.dockModuleGrid.ColumnSpacing = 2;
            app.dockModuleGrid.Padding = [5 2 5 2];
            app.dockModuleGrid.Layout.Row = [2 3];
            app.dockModuleGrid.Layout.Column = [6 7];
            app.dockModuleGrid.BackgroundColor = [0.2 0.2 0.2];

            % Create dockModule_Close
            app.dockModule_Close = uiimage(app.dockModuleGrid);
            app.dockModule_Close.ScaleMethod = 'none';
            app.dockModule_Close.ImageClickedFcn = createCallbackFcn(app, @DockModuleGroup_ButtonPushed, true);
            app.dockModule_Close.Tag = 'DRIVETEST';
            app.dockModule_Close.Tooltip = {'Fecha módulo'};
            app.dockModule_Close.Layout.Row = 1;
            app.dockModule_Close.Layout.Column = 2;
            app.dockModule_Close.ImageSource = 'Delete_12SVG_white.svg';

            % Create dockModule_Undock
            app.dockModule_Undock = uiimage(app.dockModuleGrid);
            app.dockModule_Undock.ScaleMethod = 'none';
            app.dockModule_Undock.ImageClickedFcn = createCallbackFcn(app, @DockModuleGroup_ButtonPushed, true);
            app.dockModule_Undock.Tag = 'DRIVETEST';
            app.dockModule_Undock.Enable = 'off';
            app.dockModule_Undock.Tooltip = {'Reabre módulo em outra janela'};
            app.dockModule_Undock.Layout.Row = 1;
            app.dockModule_Undock.Layout.Column = 1;
            app.dockModule_Undock.ImageSource = 'Undock_18White.png';

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
