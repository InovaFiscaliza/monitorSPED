classdef winECD_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        GridLayout              matlab.ui.container.GridLayout
        DockModule              matlab.ui.container.GridLayout
        dockModule_Undock       matlab.ui.control.Image
        dockModule_Close        matlab.ui.control.Image
        Toolbar                 matlab.ui.container.GridLayout
        tool_UploadFinalFile    matlab.ui.control.Image
        tool_GenerateReport     matlab.ui.control.Image
        tool_Separator2         matlab.ui.control.Image
        tool_SaveProject        matlab.ui.control.Image
        tool_Separator1         matlab.ui.control.Image
        tool_AutoFill           matlab.ui.control.Image
        tool_AccountEdition     matlab.ui.control.Image
        tool_CompanyInfo        matlab.ui.control.Label
        UITable2_AccountInfo    matlab.ui.control.Label
        UITable2_FilterIcon     matlab.ui.control.Image
        UITable2_FilterText     matlab.ui.control.Label
        UITable2_CountText      matlab.ui.control.Label
        UITable2_CountIcon      matlab.ui.control.Image
        UITable2                matlab.ui.control.Table
        UITable1_AccountInfo    matlab.ui.control.Label
        UITable1_FilterIcon     matlab.ui.control.Image
        UITable1_FilterText     matlab.ui.control.Label
        UITable1_CountText      matlab.ui.control.Label
        UITable1_CountIcon      matlab.ui.control.Image
        UITable1                matlab.ui.control.Table
        TabGroup                matlab.ui.container.TabGroup
        Tab1                    matlab.ui.container.Tab
        Tab1Grid                matlab.ui.container.GridLayout
        FinanceFacts            matlab.ui.control.Label
        Tab1Separator3          matlab.ui.control.Image
        LogButton               matlab.ui.control.Button
        MemoryUsageButton       matlab.ui.control.Button
        Tab1Separator2          matlab.ui.control.Image
        ExportButton            matlab.ui.control.Button
        Tab1Separator1          matlab.ui.control.Image
        SheetList               matlab.ui.control.DropDown
        SheetListLabel          matlab.ui.control.Label
        TimePeriodList          matlab.ui.control.DropDown
        TimePeriodListLabel     matlab.ui.control.Label
        CompanyNameList         matlab.ui.control.DropDown
        CompanyNameListLabel    matlab.ui.control.Label
        Tab2                    matlab.ui.container.Tab
        Tab2Grid                matlab.ui.container.GridLayout
        StyleRefresh            matlab.ui.control.Image
        StyleDelete             matlab.ui.control.Image
        FontIconLabel           matlab.ui.control.Label
        FontIcon                matlab.ui.control.DropDown
        Tab2Separator4          matlab.ui.control.Image
        FontColor               matlab.ui.control.ColorPicker
        FontBackground          matlab.ui.control.ColorPicker
        FontAlign3              matlab.ui.control.Image
        FontAlign2              matlab.ui.control.Image
        FontAlign1              matlab.ui.control.Image
        FontStyle               matlab.ui.control.Button
        FontWeight              matlab.ui.control.Button
        FontFamily              matlab.ui.control.DropDown
        Tab2Separator3          matlab.ui.control.Image
        ColumnWidthLabel        matlab.ui.control.Label
        ColumnWidth             matlab.ui.control.DropDown
        RowHeightLabel          matlab.ui.control.Label
        RowHeight               matlab.ui.control.Spinner
        Tab2Separator2          matlab.ui.control.Image
        OpenFilterModuleButton  matlab.ui.control.Button
        Tab2Separator1          matlab.ui.control.Image
        SheetOnFocus            matlab.ui.control.Lamp
        SheetHeight_Second      matlab.ui.control.Spinner
        SheetView_Second        matlab.ui.control.DropDown
        SheetHeight_First       matlab.ui.control.Spinner
        SheetView_First         matlab.ui.control.DropDown
        SheetViewStatus         matlab.ui.control.StateButton
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

                    case 'customForm'
                        ipcMainJSEventsHandler(app.mainApp, event)

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
        function ipcSecundaryMatlabCallsHandler(app, callingApp, operationType, varargin)
            try
                switch class(callingApp)
                    case {'winMonitorSPED', 'winMonitorSPED_exported'}
                        switch operationType
                            case {'FileListChanged:Add', ...
                                  'FileListChanged:Del', ...
                                  'FileListChanged:Merge'}
                                startup_AppProperties(app)
                                startup_InitialLayout(app, 'keepIfPossible')

                            case 'closeFcnCallFromDockModule'
                                app.popupContainer.Parent.Visible = 0;

                            case 'exportECD'
                                app.popupContainer.Parent.Visible = 0;
                                exportFiles(app, varargin{:})

                            case 'accountEdited'
                                forceUpdateTable(app)

                            case 'changeFilter'
                                tableId = varargin{1};
                                if strcmp(app.SheetList.Value, tableId)
                                    SheetViewFirstValueChanged(app, struct('Source', app.SheetList))
                                end

                                if strcmp(app.SheetView_Second.Value, tableId)
                                    SheetViewSecondValueChanged(app)
                                end

                            case 'tableNotRead'
                                [selectedECD, fileIndex] = selectedECDObject(app);
                                tableId = varargin{1};
                    
                                app.progressDialog.Visible = 'visible';                    
                                checkIfTableRead(app, selectedECD, fileIndex, {tableId})
                                app.progressDialog.Visible = 'hidden';

                            case 'freeMemory'
                                fileIndex = varargin{1};
                                tableIdList = varargin{2};
                                update(app.ecdObj(fileIndex), 'Table.NonEssentialFiles', 'freeMemory', tableIdList)
                                ipcMainMatlabCallsHandler(app.mainApp, app, 'updateTreeView', fileIndex);

                            case 'generateFinalReport'
                                selectedECD = selectedECDObject(app);
                                updateToolbar(app, selectedECD)

                            otherwise
                                error('UnexpectedCall')
                        end
    
                    otherwise
                        error('UnexpectedCaller')
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
                            appName = class(app);

                            % Grid botões "dock":
                            if app.isDocked
                                elToModify = {app.DockModule};
                                elDataTag  = ui.CustomizationBase.getElementsDataTag(elToModify);
                                if ~isempty(elDataTag)
                                    sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', { ...
                                        struct('appName', appName, 'dataTag', elDataTag{1}, 'style', struct('transition', 'opacity 2s ease', 'opacity', '0.5')) ...
                                    });
                                end
                            end

                            % Outros elementos:
                            hTableList = {app.UITable1, app.UITable2};
                            ui.CustomizationBase.getElementsDataTag(hTableList);

                        case 2
                            app.Tab2.UserData.rendered = true;
                            startup_InitialLayout(app, 'keepCurrent')
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
            startup_InitialLayout(app, 'fromMainApp')

            app.progressDialog.Visible = 'hidden';
        end

        %-----------------------------------------------------------------%
        function startup_AppProperties(app)
            app.projectData = app.mainApp.projectData;
            app.ecdObj      = app.mainApp.ecdObj;
        end

        %-----------------------------------------------------------------%
        function startup_GUIComponents(app)
            if ~strcmp(app.mainApp.executionMode, 'webApp')
                app.dockModule_Undock.Enable = 1;
            end

            % TabGroup:
          % app.Tab1.UserData.rendered = true;
            app.Tab2.UserData.rendered = false;

            % Tabelas:
            app.UITable1.RowName = 'numbered';
            app.UITable2.RowName = 'numbered';
            restartTableSelectionControl(app, app.UITable1, app.UITable1_CountText)
            restartTableSelectionControl(app, app.UITable2, app.UITable2_CountText)
        end

        %-----------------------------------------------------------------%
        function startup_InitialLayout(app, selectionMode)
            arguments
                app
                selectionMode {mustBeMember(selectionMode, {'fromMainApp', 'keepIfPossible', 'keepCurrent'})}
            end

            nonEmptyECDObject = ~isempty(app.ecdObj);

            renderedElements  = {
                app.ExportButton;
                app.MemoryUsageButton;
                app.LogButton
            };

            if app.Tab2.UserData.rendered
                renderedElements = [renderedElements; {
                    app.OpenFilterModuleButton;
                    app.RowHeight;
                    app.ColumnWidth;
                    app.FontFamily;
                    app.FontWeight;
                    app.FontStyle;
                    app.FontAlign1;
                    app.FontAlign2;
                    app.FontAlign3;
                    app.FontBackground;
                    app.FontColor;
                    app.FontIcon;
                    app.StyleDelete;
                    app.StyleRefresh                    
                }];
            end
            
            cellfun(@(x) set(x, 'Enable', nonEmptyECDObject), renderedElements)

            if nonEmptyECDObject
                % Seleção inicial:
                initialCompanyName = app.CompanyNameList.Value;
                initialTimePeriod  = {};
                if ~isempty(app.TimePeriodList.Value)
                    initialTimePeriod = app.TimePeriodList.Items{app.TimePeriodList.Value};
                end

                % Atualiza lista:
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
                switch selectionMode
                    case 'fromMainApp'
                        fileIndex = 1;
                        if ~isempty(app.mainApp.file_Tree.SelectedNodes)
                            fileIndex = unique([app.mainApp.file_Tree.SelectedNodes.NodeData], 'stable');
                            fileIndex = fileIndex(1);
                        end
                        selectedCompanyIndex = find(cellfun(@(x) ismember(fileIndex, x), app.CompanyNameList.UserData.values), 1);
                        app.CompanyNameList.Value = app.CompanyNameList.Items{selectedCompanyIndex};                
                        updateTimePeriodList(app, fileIndex)
                        TimePeriodListValueChanged(app)

                    case 'keepIfPossible'
                        if ~isempty(app.CompanyNameList.Value) && (~isequal(initialCompanyName, app.CompanyNameList.Value) || ~isequal(initialTimePeriod, app.TimePeriodList.Value))
                            updateTimePeriodList(app, [])
                            [~, initialTimePeriodIndex] = ismember(initialTimePeriod, app.TimePeriodList.Items);
                            if initialTimePeriodIndex
                                app.TimePeriodList.Value = initialTimePeriodIndex;
                            end

                            TimePeriodListValueChanged(app)
                        end

                    case 'keepCurrent'
                        TimePeriodListValueChanged(app)
                end

            else
                cellfun(@(x) set(x, 'Items', {}), { ...
                    app.CompanyNameList, ...
                    app.TimePeriodList, ...
                    app.SheetList, ...
                    app.SheetView_First, ...
                    app.SheetView_Second ...
                })
                
                app.FinanceFacts.Text       = '⚠️ Pendente leitura de informação contábil';
                app.tool_CompanyInfo.Text   = '';

                if app.SheetViewStatus.Value
                    app.SheetViewStatus.Value = false;
                    SheetViewStatusValueChanged(app)
                end

                if ~isempty(app.UITable1.Data)
                    set(app.UITable1, 'ColumnWidth', 'auto', ...
                                      'ColumnName', {}, ...
                                      'ColumnEditable', false, ...
                                      'Data', [])
                    app.UITable1_CountText.Text  = ' CONTAGEM : 0';
                    app.UITable1_FilterText.Text = '0 DE 0 ';
                    set(app.UITable1_FilterIcon, 'ImageSource', 'FilterGray_18.png', 'Tooltip', '')
                end

                if ~isempty(app.UITable2.Data)
                    set(app.UITable2, 'ColumnWidth', 'auto', ...
                                      'ColumnName', {}, ...
                                      'ColumnEditable', false, ...
                                      'Data', [])
                    app.UITable2_CountText.Text  = ' CONTAGEM : 0';
                    app.UITable2_FilterText.Text = '0 DE 0 ';
                    set(app.UITable2_FilterIcon, 'ImageSource', 'FilterGray_18.png', 'Tooltip', '')
                end
            end

            selectedECD = selectedECDObject(app);
            updateToolbar(app, selectedECD)
        end

        %-----------------------------------------------------------------%
        function menu_LayoutPopupApp(app, auxiliarApp, varargin)
            arguments
                app
                auxiliarApp char {mustBeMember(auxiliarApp, {'ReportLib', 'ECDExport'})}
            end

            arguments (Repeating)
                varargin 
            end

            % Inicialmente ajusta as dimensões do container.
            switch auxiliarApp
                case 'ReportLib'
                    screenWidth  = 460;
                    screenHeight = 308;
                case 'ECDExport'
                    screenWidth  = 460;
                    screenHeight = 404;
            end

            ui.PopUpContainer(app, class.Constants.appName, screenWidth, screenHeight)

            % Executa o app auxiliar.
            inputArguments = [{app.mainApp}, varargin];
            
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
        function [selectedECD, fileIndex] = selectedECDObject(app)
            if isempty(app.ecdObj)
                selectedECD = [];
                fileIndex   = [];

            else
                companyIndexes  = selectedFileIndexByCompany(app);
                 [~, companySortedIndexes] = sort(arrayfun(@(x) x.Period(2), app.ecdObj(companyIndexes)));
                 companyIndexes = companyIndexes(companySortedIndexes);
    
                if isnumeric(app.TimePeriodList.Value)
                    fileIndex = companyIndexes(app.TimePeriodList.Value);
                else
                    fileIndex = companyIndexes(strcmp(app.TimePeriodList.Items, app.TimePeriodList.Value));
                end
    
                if ~isscalar(fileIndex)
                    fileIndex = fileIndex(1);
                end
    
                selectedECD = app.ecdObj(fileIndex);
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
            selectedECD = selectedECDObject(app);
            ordinaryIds = getTableIds(selectedECD);

            % Algumas das tabelas customizadas existirão apenas se registros 
            % ordinários estiverem presentes na escrituração. Por exemplo,
            % "I200_I250" existe apenas se o registro "I200" existe.
            customIds = app.mainApp.General.ECD.customTables.expected;
            notappplicableIds = {};
            if isfield(selectedECD.Table, 'x9900') && ~isempty(selectedECD.Table.x9900)
                for ii = 1:numel(customIds)
                    customId = customIds{ii};
                    if startsWith(customId, '_')
                        continue
                    end

                    mainMergedId = extractBefore(customId, '_');
                    mainMergedIdIndex = find(strcmp(selectedECD.Table.x9900.("REG_BLC"), mainMergedId));

                    if isempty(mainMergedIdIndex) || sum(selectedECD.Table.x9900.("QTD_REG_BLC")(mainMergedIdIndex)) <= 0
                        notappplicableIds{end+1} = customId;
                    end
                end
            end

            % Posteriormente, define-se a lista de registros, mantendo a 
            % seleção inicial, caso registro já parseado.
            sheetsSorted = sort([ordinaryIds; setdiff(customIds, notappplicableIds)]);

            selection1 = app.SheetList.Value;
            if isempty(selection1) || ~ismember(selection1, sheetsSorted) || ~isfield(selectedECD.Table, ['x' selection1])
                selection1 = sheetsSorted{1};
            end            
            set(app.SheetList, 'Items', sheetsSorted, 'Value', selection1)

            % Atualiza dropdowns apenas se a Tab2 já estiver sido renderizada, 
            % evitando erros no console de tentativa de atualização de um 
            % componente incompleto.
            if app.Tab2.UserData.rendered
                selection2 = app.SheetView_Second.Value;
                if isempty(selection2) || ~ismember(selection2, sheetsSorted) || ~isfield(selectedECD.Table, ['x' selection2])
                    selection2 = sheetsSorted{1};
                end

                set(app.SheetView_First,  'Items', sheetsSorted, 'Value', selection1)
                set(app.SheetView_Second, 'Items', sheetsSorted, 'Value', selection2)
            end
        end

        %-----------------------------------------------------------------%
        function updateToolbar(app, selectedECD)
            context = 'ECD';

            % A tabela "x_CONTAS_ANOTACAO" é composta pelas contas analíticas
            % de resultado que compõem "_BALANCETE_RESULTADO". Por essa razão, 
            % caso essa tabela não seja vazia, infere-se que é possível
            % classificar as contas, gerar relatório etc.

            % Por outro lado, caso não tenha sido registrado fato contábil,
            % essa tabela será vazia.

            nonEmptyECDObject               = ~isempty(selectedECD);
            hasSpecificNonEmptyTable        = nonEmptyECDObject && isfield(selectedECD.Table, 'x_CONTAS_ANOTACAO') && ~isempty(selectedECD.Table.x_CONTAS_ANOTACAO);
            
            reportFinalVersionGenerated     = ~isempty(app.projectData.modules.(context).generatedFiles.lastHTMLDocFullPath);
            reportFinalRelatedToSelectedObj = nonEmptyECDObject && isequal(selectedECD.Hash, app.projectData.modules.(context).generatedFiles.id);

            tableIdView = {app.SheetList.Value};
            if ~isempty(app.SheetView_Second.Value)
                tableIdView{end+1} = app.SheetView_Second.Value;
            end
            app.tool_AutoFill.Enable        = hasSpecificNonEmptyTable && ismember('_CONTAS_ANOTACAO', tableIdView);
            app.tool_AccountEdition.Enable  = hasSpecificNonEmptyTable;
            app.tool_SaveProject.Enable     = nonEmptyECDObject;
            app.tool_GenerateReport.Enable  = nonEmptyECDObject && isfield(selectedECD.Table, 'x_CONTAS_ANOTACAO');
            app.tool_UploadFinalFile.Enable = reportFinalVersionGenerated && reportFinalRelatedToSelectedObj;
        end

        %-----------------------------------------------------------------%
        function forceUpdateTable(app)
            refTable    = struct('handle', app.UITable1, 'controller', app.SheetList);
            refTable(2) = struct('handle', app.UITable2, 'controller', app.SheetView_Second);

            for ii = 1:numel(refTable)
                tableHandle = refTable(ii).handle;
                controller  = refTable(ii).controller;
                
                if ismember(controller.Value, {'_CONTAS_ANOTACAO', '_TABELA_APURACAO'})
                    initialSelection = tableHandle.Selection;
                    controller.ValueChangedFcn(controller, struct('Source', controller))

                    tableHandle.Selection = initialSelection;
                    [tableCountText, tableSelectedAccount] = relatedTableComponents(app, tableHandle);
                    updateTableFootnote(app, tableHandle, tableCountText, tableSelectedAccount)
                end
            end
        end

        %-----------------------------------------------------------------%
        function checkIfTableRead(app, selectedECD, fileIndex, tableIdList)
            if isTableRead(selectedECD, tableIdList, app.mainApp.General)
                ipcMainMatlabCallsHandler(app.mainApp, app, 'updateTreeView', fileIndex);
            end

            updateFinanceFacts(app, selectedECD)
            updateToolbar(app, selectedECD)
        end

        %-----------------------------------------------------------------%
        function updateTable(app, hTable, hTableAccountInfo, hTableCountText, hTableFilterText, hTableFilterIcon, tableId)
            [selectedECD, fileIndex] = selectedECDObject(app);

            % Evita que a janela de progresso seja apresentada quando
            % alterado algum parâmetro em outro módulo.
            if isAppVisible(app)
                app.progressDialog.Visible = 'visible';
            end

            checkIfTableRead(app, selectedECD, fileIndex, {tableId})

            tableIdField   = ['x' tableId];
            tableIdData    = selectedECD.Table.(tableIdField);
            
            % Filtra, caso aplicável.
            [filterIndex, filterStatus] = checkTableCustomFilter(app, selectedECD, tableId, 'active');

            if filterStatus
                filterObj   = selectedECD.GUI.tableView(filterIndex).filter;
                visibleRows = find(run(filterObj, 'filterRules', tableIdData));                
                filterIconTooltip = strjoin(getFilterList(filterObj, ['ECD.x' tableId], 'on'), '\n');
            else
                visibleRows = (1:height(tableIdData))';                
                filterIconTooltip = '';
            end
            
            numRows        = height(tableIdData);
            numVisibleRows = numel(visibleRows);

            % Renderiza...    
            columnWidth    = 'auto';
            columnNames    = tableIdData.Properties.VariableNames;
            columnEditable = contains(columnNames, '✎');

            if ~isempty(tableIdData.Properties.RowNames)
                rowNames = tableIdData.Properties.RowNames;
            elseif numVisibleRows == numRows
                rowNames = 'numbered';
            else
                columnWidth = '1x';
                rowNames = string(visibleRows);
            end
            
            set(hTable, 'ColumnWidth', columnWidth, ...
                        'ColumnName', columnNames, ...
                        'ColumnEditable', columnEditable, ...
                        'RowName', rowNames, ...
                        'Data', tableIdData(visibleRows, :))
            pause(.250) % drawnow
            hTable.UserData.TableId = tableId;
            hTable.UserData.visibleRows = visibleRows;

            % Atualiza elementos que suportam a tabela...
            restartTableSelectionControl(app, hTable, hTableAccountInfo, hTableCountText)
            numberOfRowsText = sprintf('%d DE %d LINHAS ', numVisibleRows, numRows);
            if numRows == 1
                numberOfRowsText = replace(numberOfRowsText, 'LINHAS', 'LINHA');                
            end
            set(hTableFilterText, 'Text', numberOfRowsText)

            if numVisibleRows == numRows
                if isempty(filterIconTooltip)
                    filterIconImageSource = 'FilterGray_18.png';
                else
                    filterIconImageSource = 'Filter_18.png';
                end
            else
                filterIconImageSource = 'FilterFilled_18.png';
            end
            set(hTableFilterIcon, 'ImageSource', filterIconImageSource, 'Tooltip', filterIconTooltip)

            % Aplica estilo, normalizando-o p/ contemplar uma eventual filtragem.
            applyTableStyle(app, selectedECD, hTable, tableId)

            % Ajusta-se largura das colunas...
            if strcmp(columnWidth, '1x')
                pause(1)
                hTable.ColumnWidth = 'auto';
            end

            app.progressDialog.Visible = 'hidden';
        end

        %-----------------------------------------------------------------%
        function updateTableFootnote(app, clickedTable, tableCountText, tableSelectedAccount)
            clickedTable.UserData.Selection = clickedTable.Selection;

            if isempty(clickedTable.Selection)
                tableCountText.Text       = ' CONTAGEM: 0';
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
                    tableCountText.Text = sprintf(' CONTAGEM: %d     SOMA: %.2f     MÉDIA: %.2f', cellsCount, cellsSum, cellsAverage);
                else
                    tableCountText.Text = sprintf(' CONTAGEM: %d', cellsCount);
                end

                selectedRows = unique(clickedTable.Selection(:,1));
                selectedAccountDescription = '';            
                if isscalar(selectedRows) && ismember('COD_CTA', clickedTable.Data.Properties.VariableNames)
                    selectedECD = selectedECDObject(app);

                    selectedAccount = clickedTable.Data.("COD_CTA"){selectedRows};
                    selectedAccountIndex = find(strcmp(selectedECD.Table.x_CONTAS_DESCRICAO.("COD_CTA"), selectedAccount), 1);
        
                    if ~isempty(selectedAccountIndex)
                        selectedAccountDescription = sprintf('COD_CTA %s\n%s', selectedAccount, selectedECD.Table.x_CONTAS_DESCRICAO.("DESCRIÇÃO"){selectedAccountIndex});
                    end
                end                    
                tableSelectedAccount.Text = selectedAccountDescription;
            end
        end

        %-----------------------------------------------------------------%
        function restartTableSelectionControl(app, hTable, hTableAccountInfo, hTableCountText)
            hTable.Selection = [];
            
            % ().UserData.id armazenará o "data-tag" do componente, caso haja
            % alguma customização em curso.
            hTable.UserData.Selection = [];
            hTable.UserData.SelectionType = 'none';

            if hTable == app.UITable2 && app.Tab2.UserData.rendered
                hTableAccountInfo.Text = '';
                hTableCountText.Text   = ' CONTAGEM: 0';
            end
        end

        %-----------------------------------------------------------------%
        function d = getRowIndexMapping(app, direction, hTable)
            arguments
                app
                direction char {mustBeMember(direction, {'guiToModel', 'modelToGui'})}
                hTable
            end

            switch direction
                case 'guiToModel'
                    d = dictionary((1:height(hTable.Data))', hTable.UserData.visibleRows);
                case 'modelToGui'
                    d = dictionary(hTable.UserData.visibleRows, (1:height(hTable.Data))');                    
            end
        end

        %-----------------------------------------------------------------%
        function [index, status] = checkTableCustomStyle(app, selectedECD, tableId)
            index  = find(strcmp({selectedECD.GUI.tableView.id}, tableId), 1);
            status = ~isempty(index) && ~isempty(selectedECD.GUI.tableView(index).style);
        end

        %-----------------------------------------------------------------%
        function [index, status] = checkTableCustomFilter(app, selectedECD, tableId, statusType)
            arguments
                app
                selectedECD
                tableId
                statusType char {mustBeMember(statusType, {'basic', 'active'})}
            end

            index  = find(strcmp({selectedECD.GUI.tableView.id}, tableId), 1);
            status = ~isempty(index) && ~isempty(selectedECD.GUI.tableView(index).filter);
            if strcmp(statusType, 'active')
                status = status && ~isempty(selectedECD.GUI.tableView(index).filter.filterRules(selectedECD.GUI.tableView(index).filter.filterRules.Enable, :));
            end
        end

        %-----------------------------------------------------------------%
        function applyTableStyle(app, selectedECD, hTable, tableId)
            if ~isempty(hTable.StyleConfigurations)
                removeStyle(hTable)
            end

            [styleIndex, styleStatus] = checkTableCustomStyle(app, selectedECD, tableId);

            if styleStatus
                d = getRowIndexMapping(app, 'modelToGui', hTable);
                
                styleConfig = selectedECD.GUI.tableView(styleIndex).style;                
                for ii = 1:height(styleConfig)
                    targetIndexes = styleConfig.TargetIndex{ii};
                    targetVisibleIndexes = isKey(d, targetIndexes(:, 1));
                    
                    if any(targetVisibleIndexes)
                        targetIndexes = targetIndexes(targetVisibleIndexes, :);
                        targetIndexes(:, 1) = d(targetIndexes(:, 1));
                        addStyle(hTable, styleConfig.Style(ii), styleConfig.Target(ii), targetIndexes)
                    end
                end
            end
        end

        %-----------------------------------------------------------------%
        function updateFinanceFacts(app, selectedECD)
            if isfield(selectedECD.Table, 'x_BALANCETE_RESULTADO')
                periodResult = sum(selectedECD.Table.x_BALANCETE_RESULTADO.TOTAL);
                if periodResult < 0
                    periodResult = sprintf('&thinsp;∑&thinsp;  <font style="color:red;">R$ %.2f</font>', periodResult);
                else
                    periodResult = sprintf('&thinsp;∑&thinsp;  R$ %.2f', periodResult);
                end

                numAccounts = height(selectedECD.Table.x_BALANCETE_RESULTADO);
                switch numAccounts
                    case 0
                        numAccounts = '💵 <font style="color:red;">Nenhuma</font> conta movimentada';
                    case 1
                        numAccounts = '💵 Uma única conta movimentada';
                    otherwise
                        numAccounts = sprintf('💵 %d contas movimentadas', numAccounts);
                end

                balanceteInfo = sprintf('%s\n%s', periodResult, numAccounts);            
            else
                balanceteInfo = '⚠️ Balancete de resultado <font style="color:red;">pendente</font> de geração';
            end
            
            numAttachedFiles = sum(selectedECD.Table.x9900.('QTD_REG_BLC')(contains(selectedECD.Table.x9900.('REG_BLC'), {'J800', 'J801'})));
            switch numAttachedFiles
                case 0
                    numAttachedFiles = '🔗 Escrituração <font style="color:red;">não</font> possui arquivos .rtf';
                case 1
                    numAttachedFiles = '🔗 Escrituração possui um arquivo .rtf';
                otherwise
                    numAttachedFiles = sprintf('🔗 Escrituração possui %d arquivos .rtf', numAttachedFiles);
            end

            app.FinanceFacts.Text = sprintf('%s\n%s', balanceteInfo, numAttachedFiles);
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
        function [tableCountText, tableSelectedAccount, lampPositionRow] = relatedTableComponents(app, clickedTable)
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
        end

        %-----------------------------------------------------------------%
        function status = isAppVisible(app)
            status = ~app.isDocked || app.mainApp.menu_Button2.Value;
        end

        %-----------------------------------------------------------------%
        function exportFiles(app, fileIndex, rawTableIdFields)
            selectedECD     = app.ecdObj(fileIndex);

            defaultBaseName =  appUtil.DefaultFileName(app.mainApp.General.fileFolder.userPath, 'monitorSPED');
            excelTempName   = [appUtil.DefaultFileName(app.mainApp.General.fileFolder.tempPath, 'monitorSPED') '.xlsx'];
            rtfTempFiles    = {};

            app.progressDialog.Visible = 'visible';

            % Inicialmente, checa se todos os registros foram efetivamente
            % lidos.
            tableIds = cellfun(@(x) strsplit(x, '|'), rawTableIdFields, 'UniformOutput', false);
            tableIds = extractAfter(horzcat(tableIds{:}), 'x');
            checkIfTableRead(app, selectedECD, fileIndex, tableIds)

            % EXCEL
            msgError = {};
            try
                excelTableIdList = cellfun(@(x) strsplit(x, '|'), setdiff(rawTableIdFields, {'xJ800|xJ801'}, 'stable'), 'UniformOutput', false);                
                tableIdFields    = horzcat(excelTableIdList{:});
                
                if ~isempty(tableIdFields)
                    for ii = 1:numel(tableIdFields)
                        tableId = tableIdFields{ii};

                        tableData = selectedECD.Table.(tableId);
                        if ~isempty(tableData.Properties.RowNames)
                            tableData = [table(tableData.Properties.RowNames, 'VariableName', {'TIPO'}), tableData];
                        end

                        if ii == 1
                            writeMode = 'replacefile';
                        else
                            writeMode = 'append';
                        end
                        writetable(tableData, excelTempName, "Sheet", tableId(2:end), "WriteMode", writeMode)
                    end
                end
            catch ME
                msgError{end+1} = ME.message;
            end
               
            % RTF
            if ismember('xJ800|xJ801', rawTableIdFields)
                [rtfTempFiles, rtfMsgError] = util.exportRTF(selectedECD, app.mainApp.General);
                if ~isempty(rtfMsgError)
                    msgError{end+1} = rtfMsgError;
                end
            end

            % OUTPUTFILES
            try                
                outputfiles = [{excelTempName}, rtfTempFiles];
                outputfiles(~isfile(outputfiles)) = [];

                if isempty(outputfiles)
                    error('Nenhum arquivo para exportar.')
                end

                if isscalar(outputfiles)
                    [~, ~, fileExt] = fileparts(outputfiles{1});
                    nameFormatMap = {sprintf('*%s', fileExt), sprintf('(*%s)', fileExt)};
                else
                    nameFormatMap = {'*.zip', 'Zip (*.zip)'};
                end
                
                fileFullPath = appUtil.modalWindow(app.UIFigure, 'uiputfile', '', nameFormatMap, defaultBaseName);
                if isempty(fileFullPath)
                    return
                end

                if isscalar(outputfiles)
                    copyfile(outputfiles{1}, fileFullPath, 'f')

                    if ~strcmp(app.mainApp.executionMode, 'webApp')
                        ccTools.fcn.OperationSystem('openFile', fileFullPath)
                    end
                else
                    zip(fileFullPath, outputfiles)
                end
            catch ME
                msgError{end+1} = ME.message;
            end

            app.progressDialog.Visible = 'hidden';

            % WARNING MESSAGE
            if ~isempty(msgError)
                msgError = strjoin(msgError, '<br><br>');
                appUtil.modalWindow(app.UIFigure, 'warning', msgError);
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, filterTable, rfDataHubAnnotation)
            
            app.mainApp = mainApp;

            if app.isDocked
                app.GridLayout.Padding(4)  = 30;
                app.DockModule.Visible = 1;
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

        % Button pushed function: LogButton
        function Toolbar_LOGInfoImageClicked(app, event)
            
            selectedECD = selectedECDObject(app);

            htmlContent = util.HtmlTextGenerator.Warnings(selectedECD);
            appUtil.modalWindow(app.UIFigure, 'info', htmlContent);

        end

        % Image clicked function: tool_GenerateReport
        function Toolbar_ReportImageClicked(app, event)
            
            [~, fileIndex] = selectedECDObject(app);
            ipcMainMatlabOpenPopupApp(app.mainApp, app, 'ReportLib', 'ECD', fileIndex)
            
        end

        % Button pushed function: ExportButton
        function Toolbar_ExportExportExcelClicked(app, event)
            
            [~, fileIndex] = selectedECDObject(app);
            ipcMainMatlabOpenPopupApp(app.mainApp, app, 'ECDExport', 'ECD', fileIndex)

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
            
            selectedECD = selectedECDObject(app);

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
                    if app.Tab2.UserData.rendered
                        app.SheetView_First.Value = app.SheetList.Value;
                    end
                case app.SheetView_First
                    app.SheetList.Value = app.SheetView_First.Value;
            end

            updateTable(app, app.UITable1, app.UITable1_AccountInfo, app.UITable1_CountText, app.UITable1_FilterText, app.UITable1_FilterIcon, app.SheetList.Value)

        end

        % Value changed function: SheetView_Second
        function SheetViewSecondValueChanged(app, event)
            
            if app.Tab2.UserData.rendered
                updateTable(app, app.UITable2, app.UITable2_AccountInfo, app.UITable2_CountText, app.UITable2_FilterText, app.UITable2_FilterIcon, app.SheetView_Second.Value)
            end
            
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

            [tableCountText, tableSelectedAccount, lampPositionRow] = relatedTableComponents(app, clickedTable);

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
                updateTableFootnote(app, clickedTable, tableCountText, tableSelectedAccount)
            end

        end

        % Cell edit callback: UITable1, UITable2
        function TableCellEdit(app, event)
            
            % Para contornar BUG do dropdown, que dispara esse evento mesmo
            % quando não há alteração do valor. Além disso, evita alteração
            % do campo quando são apenas inseridos caracteres vazios (no
            % caso de um campo textual).
            previousData = event.PreviousData;
            newData      = event.NewData;
            if (iscategorical(newData) && isequal(previousData, newData)) || ...
               (ischar(newData)        && isequal(strtrim(previousData), strtrim(newData)))
                return
            end            

            % E agora sim analisa a edição da célula...
            rowIndex = event.Indices(1);
            colIndex = event.Indices(2);            

            columnNames = event.Source.Data.Properties.VariableNames;
            editedCellColumnName = columnNames{colIndex};

            selectedECD = selectedECDObject(app);
            
            % Para contornar regra de negócio esquisita do MATLAB, que possibilita
            % criação de nova categoria.
            if strcmp(editedCellColumnName, 'Apurado?  ✎') && ~ismember(newData, app.mainApp.General.ECD.accountOptions)
                forceUpdateTable(app)
                return
            end

            if iscell(selectedECD.Table.x_CONTAS_ANOTACAO{rowIndex, colIndex})
                newData = {strtrim(newData)};
            end

            update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'valueChanged', rowIndex, colIndex, editedCellColumnName, newData)
            forceUpdateTable(app)

        end

        % Callback function: FontAlign1, FontAlign2, FontAlign3, 
        % ...and 6 other components
        function TableStyleChanged(app, event)
                        
            clickedTable = onFocusTable(app);
            if isempty(clickedTable.Selection)
                return
            end

            switch clickedTable
                case app.UITable1; tableId = app.SheetList.Value;
                case app.UITable2; tableId = app.SheetView_Second.Value;
            end

            % Lista atual de estilos:
            selectedECD  = selectedECDObject(app);
            styleIndex = checkTableCustomStyle(app, selectedECD, tableId);
            if isempty(styleIndex)
                styleIndex = numel(selectedECD.GUI.tableView)+1;
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

                    % Ao invés de um simples fieldValue = {event.Value}, foi 
                    % necessário adicionar ao projeto as imagens .svg relacionadas
                    % a cada estado. Isto porque o MATLAB R2024a apresentou um 
                    % BUG, não renderizando esses ícones nos webapps.

                    % ToDo: abrir chamado na Mathworks e simplificar código, 
                    % após correção do BUG.

                    switch event.Value
                        case 'none'
                            fieldValue = {'none'};
                        otherwise
                            fieldValue = {sprintf('styleIcon_%s.svg', event.Value)};
                    end
                    app.FontIcon.Value = '';
            end

            % Verifica se já existe estilo aplicado às células selecionadas:
            previousStyleIndex = find(cellfun(@(x) isequal(clickedTable.Selection, x), clickedTable.StyleConfigurations.TargetIndex));
            if ~isempty(previousStyleIndex)
                previousStyleIndex = previousStyleIndex(end);
                s = clickedTable.StyleConfigurations.Style(previousStyleIndex);                
                removeStyle(clickedTable, previousStyleIndex)
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

            if event.Source == app.FontIcon
                s.("IconAlignment") = 'leftmargin';
            end

            addStyle(clickedTable, s, "cell", clickedTable.Selection)
            if strcmp(app.SheetList.Value, app.SheetView_Second.Value)
                otherTable = setdiff([app.UITable1, app.UITable2], clickedTable);
                addStyle(otherTable, s, "cell", clickedTable.Selection)
            end

            d = getRowIndexMapping(app, 'guiToModel', clickedTable);

            styleConfig = clickedTable.StyleConfigurations;
            for ii = 1:height(styleConfig)
                styleConfig.TargetIndex{ii}(:, 1) = d(styleConfig.TargetIndex{ii}(:, 1));
            end

            update(selectedECD, 'GUI.TableView.Style', 'addStyle', tableId, styleIndex, styleConfig)
            
        end

        % Image clicked function: StyleDelete, StyleRefresh
        function TableStyleDeleteOrRefresh(app, event)
            
            selectedECD  = selectedECDObject(app);            
            clickedTable = onFocusTable(app);
            switch clickedTable
                case app.UITable1
                    tableId = app.SheetList.Value;
                case app.UITable2
                    tableId = app.SheetView_Second.Value;
            end

            % Lista atual de estilos:
            [styleIndex, styleStatus] = checkTableCustomStyle(app, selectedECD, tableId);

            if styleStatus
                switch event.Source
                    case app.StyleDelete
                        if isempty(clickedTable.Selection)
                            return
                        end

                        d = getRowIndexMapping(app, 'guiToModel', clickedTable);

                        currentStyleTable = selectedECD.GUI.tableView(styleIndex).style;
                        userCellSelection = clickedTable.Selection;
                        userCellSelection(:, 1) = d(userCellSelection(:, 1));

                        rerenderizationFlag = false;

                        for ii = 1:height(userCellSelection)
                            cellSelection = userCellSelection(ii,:);

                            for jj = height(currentStyleTable):-1:1
                                [~, cellSelectionIndex] = ismember(cellSelection, currentStyleTable.TargetIndex{jj}, "rows");
                                
                                if cellSelectionIndex
                                    rerenderizationFlag = true;
                                    newTargetIndexes    = setdiff(currentStyleTable.TargetIndex{jj}, cellSelection, "rows");

                                    if isempty(newTargetIndexes)
                                        currentStyleTable(jj, :) = [];
                                    else
                                        currentStyleTable.TargetIndex{jj} = newTargetIndexes;
                                    end
                                end
                            end
                        end

                        if rerenderizationFlag
                            update(selectedECD, 'GUI.TableView.Style', 'removeSelectedCellStyle', styleIndex, currentStyleTable)
                            applyTableStyle(app, selectedECD, clickedTable, tableId)

                            if strcmp(app.SheetList.Value, app.SheetView_Second.Value)
                                otherTable = setdiff([app.UITable1, app.UITable2], clickedTable);
                                applyTableStyle(app, selectedECD, otherTable, tableId)
                            end
                        end

                    case app.StyleRefresh
                        removeStyle(clickedTable)
                        update(selectedECD, 'GUI.TableView.Style', 'removeTableStyle', styleIndex)

                        if strcmp(app.SheetList.Value, app.SheetView_Second.Value)
                            otherTable = setdiff([app.UITable1, app.UITable2], clickedTable);
                            removeStyle(otherTable)
                        end
                end
            end

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
                    matlab.waitfor(hTable, propertyName, @(propName) isprop(hTable, propName), .010, 2, 'propName')
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
        function TableColumnWidthChanged(app, event)
            
            if ~isempty(event.Source.Value)
                if isfield(event, 'TableHandle')
                    hTable = event.TableHandle;
                else
                    hTable = onFocusTable(app);
                end

                if isequal(hTable.ColumnWidth, event.Source.Value)
                    widthOptions = setdiff(event.Source.Items, {'', event.Source.Value});
                    hTable.ColumnWidth = widthOptions{1};
                    drawnow
                end

                hTable.ColumnWidth = event.Source.Value;
                app.ColumnWidth.Value = '';
            end
            
        end

        % Image clicked function: tool_AccountEdition
        function ExportButton_2Pushed(app, event)
            
            clickedTable = onFocusTable(app);
            
            if ~isempty(clickedTable.Selection) && isscalar(unique(clickedTable.Selection(:,1))) && ismember('COD_CTA', clickedTable.Data.Properties.VariableNames)
                selectedRow = unique(clickedTable.Selection(:,1));
                accountName = clickedTable.Data.('COD_CTA'){selectedRow};
            else
                accountName = '';
            end

            [~, fileIndex] = selectedECDObject(app);
            ipcMainMatlabOpenPopupApp(app.mainApp, app, 'ECDAccount', 'ECD', fileIndex, accountName)

        end

        % Image clicked function: tool_AutoFill
        function tool_AutoFillImageClicked(app, event)
            
            selectedECD = selectedECDObject(app);
            if ~isfield(selectedECD.Table, 'x_CONTAS_ANOTACAO')
                return
            end

            update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'autoFill')
            forceUpdateTable(app)

        end

        % Button pushed function: OpenFilterModuleButton
        function OpenFilterModuleButtonPushed(app, event)

            [~, fileIndex]  = selectedECDObject(app);
            tableIdList     = app.SheetList.Items;
            selectedTableId = app.SheetList.Value;

            ipcMainMatlabOpenPopupApp(app.mainApp, app, 'ECDFilter', 'ECD', fileIndex, tableIdList, selectedTableId)

        end

        % Image clicked function: tool_SaveProject
        function tool_SaveProjectImageClicked(app, event)
            
            context = 'ECD';
            dialogBox = struct('id', 'projectName', 'label', 'Nome do projeto:', 'type', 'text', 'defaultValue', app.projectData.name);            
            sendEventToHTMLSource(app.jsBackDoor, 'customForm', struct('UUID', 'onProjectSave', 'Fields', dialogBox, 'Context', context))

        end

        % Button pushed function: MemoryUsageButton
        function MemoryUsageButtonPushed(app, event)
            
            [~, fileIndex] = selectedECDObject(app);
            ipcMainMatlabOpenPopupApp(app.mainApp, app, 'ECDMemoryUsage', 'ECD', fileIndex)

        end

        % Image clicked function: tool_UploadFinalFile
        function tool_UploadFinalFileImageClicked(app, event)
            
            % <VALIDAÇÕES>
            context = 'ECD';
            lastHTMLDocFullPath = getGeneratedDocumentFileName(app.projectData, '.html', context);

            msg = '';
            if isempty(lastHTMLDocFullPath)
                msg = 'A versão definitiva do relatório ainda não foi gerada.';
            elseif ~isfile(lastHTMLDocFullPath)
                msg = sprintf('O arquivo "%s" não foi encontrado.', lastHTMLDocFullPath);
            elseif ~isfolder(app.mainApp.General.fileFolder.DataHub_POST)
                msg = 'Pendente mapear pasta do Sharepoint';
            elseif ~report_checkEFiscalizaIssueId(app.mainApp, app.projectData.modules.(context).ui.issue)
                msg = sprintf('O número da inspeção "%.0f" é inválido.', app.projectData.modules.(context).ui.issue);
            elseif isempty(app.projectData.modules.(context).ui.system)
                msg = 'Ambiente do eFiscaliza precisa ser selecionado.';
            elseif isempty(app.projectData.modules.(context).ui.unit)
                msg = 'Unidade geradora do documento precisa ser selecionada.';
            end

            if ~isempty(msg)
                appUtil.modalWindow(app.UIFigure, 'warning', msg);
                return
            end

            selectedECD   = selectedECDObject(app);
            uploadReports = ~strcmp({selectedECD.GUI.generatedFiles.status}, '');

            if any(uploadReports)
                uploadStatus = extractAfter({selectedECD.GUI.generatedFiles(uploadReports).status}, 'Documento cadastrado no SEI sob o nº ');

                if isscalar(uploadStatus)
                    uploadStatus = uploadStatus{1};
                else                    
                    uploadStatus = strjoin([{strjoin(uploadStatus(1:end-1), ', ')}, uploadStatus(end)], ' e ');
                end

                msgQuestion = sprintf([ ...
                    'Já foi realizado o <i>upload</i> para o SEI de relatório contendo ' ...
                    'análise relacionada a este conjunto de dados contábeis - ' ...
                    'SEI nº %s.\n\n' ...
                    'Deseja realizar um novo <i>upload</i> para o SEI?' ...
                ], uploadStatus);
                userSelection = appUtil.modalWindow(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 2, 2);

                if strcmp(userSelection, 'Não')
                    return
                end
            end
            % </VALIDAÇÕES>

            % <PROCESSO>
            if isempty(app.mainApp.eFiscalizaObj) || ~isvalid(app.mainApp.eFiscalizaObj)
                dialogBox    = struct('id', 'login',    'label', 'Usuário: ', 'type', 'text');
                dialogBox(2) = struct('id', 'password', 'label', 'Senha: ',   'type', 'password');
                sendEventToHTMLSource(app.jsBackDoor, 'customForm', struct('UUID', 'eFiscalizaSignInPage', 'Fields', dialogBox, 'Context', context))
            else
                report_uploadInfoController(app.mainApp, [], 'uploadDocument', context)
            end
            % </PROCESSO>

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
            app.GridLayout.ColumnWidth = {10, 18, 320, '1x', 290, 30, 18, 8, 2};
            app.GridLayout.RowHeight = {2, 8, 24, 70, 10, '1x', 2, 22, 0, 0, 0, 0, 10, 34};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.AutoResizeChildren = 'off';
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
            app.TabGroup.Layout.Row = [3 4];
            app.TabGroup.Layout.Column = [2 7];

            % Create Tab1
            app.Tab1 = uitab(app.TabGroup);
            app.Tab1.AutoResizeChildren = 'off';
            app.Tab1.Title = 'ASPECTOS GERAIS';
            app.Tab1.BackgroundColor = 'none';

            % Create Tab1Grid
            app.Tab1Grid = uigridlayout(app.Tab1);
            app.Tab1Grid.ColumnWidth = {90, 220, 60, 220, 3, 44, 3, 44, 44, 3, '1x'};
            app.Tab1Grid.RowHeight = {22, 22};
            app.Tab1Grid.RowSpacing = 5;
            app.Tab1Grid.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create CompanyNameListLabel
            app.CompanyNameListLabel = uilabel(app.Tab1Grid);
            app.CompanyNameListLabel.FontSize = 10;
            app.CompanyNameListLabel.FontColor = [0.149 0.149 0.149];
            app.CompanyNameListLabel.Layout.Row = 1;
            app.CompanyNameListLabel.Layout.Column = 1;
            app.CompanyNameListLabel.Text = 'EMPRESA:';

            % Create CompanyNameList
            app.CompanyNameList = uidropdown(app.Tab1Grid);
            app.CompanyNameList.Items = {};
            app.CompanyNameList.ValueChangedFcn = createCallbackFcn(app, @CompanyNameListValueChanged, true);
            app.CompanyNameList.FontSize = 11;
            app.CompanyNameList.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.CompanyNameList.BackgroundColor = [1 1 1];
            app.CompanyNameList.Layout.Row = 1;
            app.CompanyNameList.Layout.Column = [2 4];
            app.CompanyNameList.Value = {};

            % Create TimePeriodListLabel
            app.TimePeriodListLabel = uilabel(app.Tab1Grid);
            app.TimePeriodListLabel.FontSize = 10;
            app.TimePeriodListLabel.FontColor = [0.149 0.149 0.149];
            app.TimePeriodListLabel.Layout.Row = 2;
            app.TimePeriodListLabel.Layout.Column = 1;
            app.TimePeriodListLabel.Text = 'PERÍODO FISCAL:';

            % Create TimePeriodList
            app.TimePeriodList = uidropdown(app.Tab1Grid);
            app.TimePeriodList.Items = {};
            app.TimePeriodList.ValueChangedFcn = createCallbackFcn(app, @TimePeriodListValueChanged, true);
            app.TimePeriodList.FontSize = 11;
            app.TimePeriodList.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.TimePeriodList.BackgroundColor = [1 1 1];
            app.TimePeriodList.Layout.Row = 2;
            app.TimePeriodList.Layout.Column = 2;
            app.TimePeriodList.Value = {};

            % Create SheetListLabel
            app.SheetListLabel = uilabel(app.Tab1Grid);
            app.SheetListLabel.HorizontalAlignment = 'right';
            app.SheetListLabel.FontSize = 10;
            app.SheetListLabel.FontColor = [0.149 0.149 0.149];
            app.SheetListLabel.Layout.Row = 2;
            app.SheetListLabel.Layout.Column = 3;
            app.SheetListLabel.Text = 'REGISTRO:';

            % Create SheetList
            app.SheetList = uidropdown(app.Tab1Grid);
            app.SheetList.Items = {};
            app.SheetList.ValueChangedFcn = createCallbackFcn(app, @SheetViewFirstValueChanged, true);
            app.SheetList.FontSize = 11;
            app.SheetList.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.SheetList.BackgroundColor = [1 1 1];
            app.SheetList.Layout.Row = 2;
            app.SheetList.Layout.Column = 4;
            app.SheetList.Value = {};

            % Create Tab1Separator1
            app.Tab1Separator1 = uiimage(app.Tab1Grid);
            app.Tab1Separator1.Enable = 'off';
            app.Tab1Separator1.Layout.Row = [1 2];
            app.Tab1Separator1.Layout.Column = 5;
            app.Tab1Separator1.ImageSource = 'LineV.svg';

            % Create ExportButton
            app.ExportButton = uibutton(app.Tab1Grid, 'push');
            app.ExportButton.ButtonPushedFcn = createCallbackFcn(app, @Toolbar_ExportExportExcelClicked, true);
            app.ExportButton.Icon = 'Export_24.png';
            app.ExportButton.IconAlignment = 'top';
            app.ExportButton.BackgroundColor = [0.9608 0.9608 0.9608];
            app.ExportButton.FontSize = 10;
            app.ExportButton.Enable = 'off';
            app.ExportButton.Layout.Row = [1 2];
            app.ExportButton.Layout.Column = 6;
            app.ExportButton.Text = 'Exporta';

            % Create Tab1Separator2
            app.Tab1Separator2 = uiimage(app.Tab1Grid);
            app.Tab1Separator2.Enable = 'off';
            app.Tab1Separator2.Layout.Row = [1 2];
            app.Tab1Separator2.Layout.Column = 7;
            app.Tab1Separator2.ImageSource = 'LineV.svg';

            % Create MemoryUsageButton
            app.MemoryUsageButton = uibutton(app.Tab1Grid, 'push');
            app.MemoryUsageButton.ButtonPushedFcn = createCallbackFcn(app, @MemoryUsageButtonPushed, true);
            app.MemoryUsageButton.Icon = 'pool_60_percent.png';
            app.MemoryUsageButton.IconAlignment = 'top';
            app.MemoryUsageButton.BackgroundColor = [0.9608 0.9608 0.9608];
            app.MemoryUsageButton.FontSize = 10;
            app.MemoryUsageButton.Enable = 'off';
            app.MemoryUsageButton.Layout.Row = [1 2];
            app.MemoryUsageButton.Layout.Column = 8;
            app.MemoryUsageButton.Text = 'Em uso';

            % Create LogButton
            app.LogButton = uibutton(app.Tab1Grid, 'push');
            app.LogButton.ButtonPushedFcn = createCallbackFcn(app, @Toolbar_LOGInfoImageClicked, true);
            app.LogButton.Icon = 'LOG_24.png';
            app.LogButton.IconAlignment = 'top';
            app.LogButton.FontSize = 10;
            app.LogButton.Enable = 'off';
            app.LogButton.Layout.Row = [1 2];
            app.LogButton.Layout.Column = 9;
            app.LogButton.Text = 'Análise';

            % Create Tab1Separator3
            app.Tab1Separator3 = uiimage(app.Tab1Grid);
            app.Tab1Separator3.Enable = 'off';
            app.Tab1Separator3.Layout.Row = [1 2];
            app.Tab1Separator3.Layout.Column = 10;
            app.Tab1Separator3.ImageSource = 'LineV.svg';

            % Create FinanceFacts
            app.FinanceFacts = uilabel(app.Tab1Grid);
            app.FinanceFacts.FontSize = 11;
            app.FinanceFacts.Layout.Row = [1 2];
            app.FinanceFacts.Layout.Column = 11;
            app.FinanceFacts.Interpreter = 'html';
            app.FinanceFacts.Text = '⚠️ Pendente leitura de informação contábil';

            % Create Tab2
            app.Tab2 = uitab(app.TabGroup);
            app.Tab2.AutoResizeChildren = 'off';
            app.Tab2.Title = 'LAYOUT';
            app.Tab2.BackgroundColor = 'none';

            % Create Tab2Grid
            app.Tab2Grid = uigridlayout(app.Tab2);
            app.Tab2Grid.ColumnWidth = {44, 220, 40, 10, 3, 44, 3, 90, 90, 3, 22, 22, 22, 22, 22, 44, 44, 3, 90, '1x', 18, 18};
            app.Tab2Grid.RowHeight = {22, 22};
            app.Tab2Grid.RowSpacing = 5;
            app.Tab2Grid.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create SheetViewStatus
            app.SheetViewStatus = uibutton(app.Tab2Grid, 'state');
            app.SheetViewStatus.ValueChangedFcn = createCallbackFcn(app, @SheetViewStatusValueChanged, true);
            app.SheetViewStatus.Icon = 'split_top_bottom_24.png';
            app.SheetViewStatus.IconAlignment = 'top';
            app.SheetViewStatus.Text = 'Tela';
            app.SheetViewStatus.BackgroundColor = [0.9608 0.9608 0.9608];
            app.SheetViewStatus.FontSize = 10;
            app.SheetViewStatus.Layout.Row = [1 2];
            app.SheetViewStatus.Layout.Column = 1;

            % Create SheetView_First
            app.SheetView_First = uidropdown(app.Tab2Grid);
            app.SheetView_First.Items = {};
            app.SheetView_First.ValueChangedFcn = createCallbackFcn(app, @SheetViewFirstValueChanged, true);
            app.SheetView_First.FontSize = 11;
            app.SheetView_First.BackgroundColor = [1 1 1];
            app.SheetView_First.Layout.Row = 1;
            app.SheetView_First.Layout.Column = 2;
            app.SheetView_First.Value = {};

            % Create SheetHeight_First
            app.SheetHeight_First = uispinner(app.Tab2Grid);
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
            app.SheetView_Second = uidropdown(app.Tab2Grid);
            app.SheetView_Second.Items = {};
            app.SheetView_Second.ValueChangedFcn = createCallbackFcn(app, @SheetViewSecondValueChanged, true);
            app.SheetView_Second.Enable = 'off';
            app.SheetView_Second.FontSize = 11;
            app.SheetView_Second.BackgroundColor = [1 1 1];
            app.SheetView_Second.Layout.Row = 2;
            app.SheetView_Second.Layout.Column = 2;
            app.SheetView_Second.Value = {};

            % Create SheetHeight_Second
            app.SheetHeight_Second = uispinner(app.Tab2Grid);
            app.SheetHeight_Second.Limits = [0 5];
            app.SheetHeight_Second.RoundFractionalValues = 'on';
            app.SheetHeight_Second.ValueDisplayFormat = '%d';
            app.SheetHeight_Second.ValueChangedFcn = createCallbackFcn(app, @SheetViewHeightValueChanged, true);
            app.SheetHeight_Second.FontSize = 11;
            app.SheetHeight_Second.Enable = 'off';
            app.SheetHeight_Second.Layout.Row = 2;
            app.SheetHeight_Second.Layout.Column = 3;

            % Create SheetOnFocus
            app.SheetOnFocus = uilamp(app.Tab2Grid);
            app.SheetOnFocus.Tooltip = {'Tabela em evidência'};
            app.SheetOnFocus.Layout.Row = 1;
            app.SheetOnFocus.Layout.Column = 4;
            app.SheetOnFocus.Color = [0.7059 0.8706 1];

            % Create Tab2Separator1
            app.Tab2Separator1 = uiimage(app.Tab2Grid);
            app.Tab2Separator1.Enable = 'off';
            app.Tab2Separator1.Layout.Row = [1 2];
            app.Tab2Separator1.Layout.Column = 5;
            app.Tab2Separator1.ImageSource = 'LineV.svg';

            % Create OpenFilterModuleButton
            app.OpenFilterModuleButton = uibutton(app.Tab2Grid, 'push');
            app.OpenFilterModuleButton.ButtonPushedFcn = createCallbackFcn(app, @OpenFilterModuleButtonPushed, true);
            app.OpenFilterModuleButton.Icon = 'Filter_24.png';
            app.OpenFilterModuleButton.IconAlignment = 'top';
            app.OpenFilterModuleButton.FontSize = 10;
            app.OpenFilterModuleButton.Enable = 'off';
            app.OpenFilterModuleButton.Layout.Row = [1 2];
            app.OpenFilterModuleButton.Layout.Column = 6;
            app.OpenFilterModuleButton.Text = 'Filtro';

            % Create Tab2Separator2
            app.Tab2Separator2 = uiimage(app.Tab2Grid);
            app.Tab2Separator2.Enable = 'off';
            app.Tab2Separator2.Layout.Row = [1 2];
            app.Tab2Separator2.Layout.Column = 7;
            app.Tab2Separator2.ImageSource = 'LineV.svg';

            % Create RowHeight
            app.RowHeight = uispinner(app.Tab2Grid);
            app.RowHeight.Step = 5;
            app.RowHeight.Limits = [0 50];
            app.RowHeight.RoundFractionalValues = 'on';
            app.RowHeight.ValueDisplayFormat = '%d';
            app.RowHeight.ValueChangedFcn = createCallbackFcn(app, @TableRowHeightChanged, true);
            app.RowHeight.FontSize = 11;
            app.RowHeight.Enable = 'off';
            app.RowHeight.Layout.Row = 1;
            app.RowHeight.Layout.Column = 8;

            % Create RowHeightLabel
            app.RowHeightLabel = uilabel(app.Tab2Grid);
            app.RowHeightLabel.HorizontalAlignment = 'center';
            app.RowHeightLabel.WordWrap = 'on';
            app.RowHeightLabel.FontSize = 10;
            app.RowHeightLabel.Layout.Row = 2;
            app.RowHeightLabel.Layout.Column = 8;
            app.RowHeightLabel.Text = {'ALTURA LINHA'; '(offset)'};

            % Create ColumnWidth
            app.ColumnWidth = uidropdown(app.Tab2Grid);
            app.ColumnWidth.Items = {'', 'auto', 'fit', '1x'};
            app.ColumnWidth.ValueChangedFcn = createCallbackFcn(app, @TableColumnWidthChanged, true);
            app.ColumnWidth.Enable = 'off';
            app.ColumnWidth.FontSize = 11;
            app.ColumnWidth.BackgroundColor = [1 1 1];
            app.ColumnWidth.Layout.Row = 1;
            app.ColumnWidth.Layout.Column = 9;
            app.ColumnWidth.Value = '';

            % Create ColumnWidthLabel
            app.ColumnWidthLabel = uilabel(app.Tab2Grid);
            app.ColumnWidthLabel.HorizontalAlignment = 'center';
            app.ColumnWidthLabel.WordWrap = 'on';
            app.ColumnWidthLabel.FontSize = 10;
            app.ColumnWidthLabel.Layout.Row = 2;
            app.ColumnWidthLabel.Layout.Column = 9;
            app.ColumnWidthLabel.Text = {'LARGURA'; 'COLUNA'};

            % Create Tab2Separator3
            app.Tab2Separator3 = uiimage(app.Tab2Grid);
            app.Tab2Separator3.Enable = 'off';
            app.Tab2Separator3.Layout.Row = [1 2];
            app.Tab2Separator3.Layout.Column = 10;
            app.Tab2Separator3.ImageSource = 'LineV.svg';

            % Create FontFamily
            app.FontFamily = uidropdown(app.Tab2Grid);
            app.FontFamily.Items = {};
            app.FontFamily.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontFamily.Enable = 'off';
            app.FontFamily.Tooltip = {'Fonte'};
            app.FontFamily.FontSize = 11;
            app.FontFamily.BackgroundColor = [1 1 1];
            app.FontFamily.Layout.Row = 1;
            app.FontFamily.Layout.Column = [11 17];
            app.FontFamily.Value = {};

            % Create FontWeight
            app.FontWeight = uibutton(app.Tab2Grid, 'push');
            app.FontWeight.ButtonPushedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontWeight.BackgroundColor = [0.9804 0.9804 0.9804];
            app.FontWeight.FontName = 'Century';
            app.FontWeight.FontWeight = 'bold';
            app.FontWeight.Enable = 'off';
            app.FontWeight.Layout.Row = 2;
            app.FontWeight.Layout.Column = 11;
            app.FontWeight.Text = 'B';

            % Create FontStyle
            app.FontStyle = uibutton(app.Tab2Grid, 'push');
            app.FontStyle.ButtonPushedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontStyle.BackgroundColor = [0.9804 0.9804 0.9804];
            app.FontStyle.FontName = 'Century';
            app.FontStyle.FontAngle = 'italic';
            app.FontStyle.Enable = 'off';
            app.FontStyle.Layout.Row = 2;
            app.FontStyle.Layout.Column = 12;
            app.FontStyle.Text = 'I ';

            % Create FontAlign1
            app.FontAlign1 = uiimage(app.Tab2Grid);
            app.FontAlign1.ScaleMethod = 'none';
            app.FontAlign1.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign1.Enable = 'off';
            app.FontAlign1.Tooltip = {'Sublinhado'};
            app.FontAlign1.Layout.Row = 2;
            app.FontAlign1.Layout.Column = 13;
            app.FontAlign1.ImageSource = 'AlignedLeft_16-7f46662cd6fd7221119660e14bdcea56.png';

            % Create FontAlign2
            app.FontAlign2 = uiimage(app.Tab2Grid);
            app.FontAlign2.ScaleMethod = 'none';
            app.FontAlign2.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign2.Enable = 'off';
            app.FontAlign2.Tooltip = {'Sublinhado'};
            app.FontAlign2.Layout.Row = 2;
            app.FontAlign2.Layout.Column = 14;
            app.FontAlign2.ImageSource = 'AlignedCenter_16-b91485db227234029c43b7823c09ebff.png';

            % Create FontAlign3
            app.FontAlign3 = uiimage(app.Tab2Grid);
            app.FontAlign3.ScaleMethod = 'none';
            app.FontAlign3.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign3.Enable = 'off';
            app.FontAlign3.Tooltip = {'Sublinhado'};
            app.FontAlign3.Layout.Row = 2;
            app.FontAlign3.Layout.Column = 15;
            app.FontAlign3.ImageSource = 'AlignedRight_16-7827788943408c9bac98181b7ad0efb5.png';

            % Create FontBackground
            app.FontBackground = uicolorpicker(app.Tab2Grid);
            app.FontBackground.Value = [1 0 0.0118];
            app.FontBackground.Icon = 'fill';
            app.FontBackground.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontBackground.Enable = 'off';
            app.FontBackground.Layout.Row = 2;
            app.FontBackground.Layout.Column = 16;
            app.FontBackground.BackgroundColor = [1 1 1];

            % Create FontColor
            app.FontColor = uicolorpicker(app.Tab2Grid);
            app.FontColor.Value = [0 0 0.0118];
            app.FontColor.Icon = 'text';
            app.FontColor.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontColor.Enable = 'off';
            app.FontColor.Layout.Row = 2;
            app.FontColor.Layout.Column = 17;
            app.FontColor.BackgroundColor = [1 1 1];

            % Create Tab2Separator4
            app.Tab2Separator4 = uiimage(app.Tab2Grid);
            app.Tab2Separator4.Enable = 'off';
            app.Tab2Separator4.Layout.Row = [1 2];
            app.Tab2Separator4.Layout.Column = 18;
            app.Tab2Separator4.ImageSource = 'LineV.svg';

            % Create FontIcon
            app.FontIcon = uidropdown(app.Tab2Grid);
            app.FontIcon.Items = {'', 'question', 'info', 'success', 'warning', 'error', 'none'};
            app.FontIcon.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontIcon.Enable = 'off';
            app.FontIcon.FontSize = 11;
            app.FontIcon.BackgroundColor = [1 1 1];
            app.FontIcon.Layout.Row = 1;
            app.FontIcon.Layout.Column = 19;
            app.FontIcon.Value = '';

            % Create FontIconLabel
            app.FontIconLabel = uilabel(app.Tab2Grid);
            app.FontIconLabel.HorizontalAlignment = 'center';
            app.FontIconLabel.WordWrap = 'on';
            app.FontIconLabel.FontSize = 10;
            app.FontIconLabel.Layout.Row = 2;
            app.FontIconLabel.Layout.Column = 19;
            app.FontIconLabel.Text = 'ÍCONE';

            % Create StyleDelete
            app.StyleDelete = uiimage(app.Tab2Grid);
            app.StyleDelete.ScaleMethod = 'none';
            app.StyleDelete.ImageClickedFcn = createCallbackFcn(app, @TableStyleDeleteOrRefresh, true);
            app.StyleDelete.Enable = 'off';
            app.StyleDelete.Tooltip = {'Exclui estilo relacionado às células selecionadas'};
            app.StyleDelete.Layout.Row = 2;
            app.StyleDelete.Layout.Column = 21;
            app.StyleDelete.ImageSource = 'clear_all_outputs_16-3d3c482971dfdb6852db717989f585fa.png';

            % Create StyleRefresh
            app.StyleRefresh = uiimage(app.Tab2Grid);
            app.StyleRefresh.ScaleMethod = 'none';
            app.StyleRefresh.ImageClickedFcn = createCallbackFcn(app, @TableStyleDeleteOrRefresh, true);
            app.StyleRefresh.Enable = 'off';
            app.StyleRefresh.Tooltip = {'Retorna às configurações iniciais de estilo'};
            app.StyleRefresh.Layout.Row = 2;
            app.StyleRefresh.Layout.Column = 22;
            app.StyleRefresh.ImageSource = 'Refresh_18.png';

            % Create UITable1
            app.UITable1 = uitable(app.GridLayout);
            app.UITable1.BackgroundColor = [1 1 1;0.9412 0.9412 0.9412];
            app.UITable1.ColumnName = '';
            app.UITable1.ColumnSortable = true;
            app.UITable1.CellEditCallback = createCallbackFcn(app, @TableCellEdit, true);
            app.UITable1.ClickedFcn = createCallbackFcn(app, @TableClicked, true);
            app.UITable1.ForegroundColor = [0.149 0.149 0.149];
            app.UITable1.KeyReleaseFcn = createCallbackFcn(app, @TableClicked, true);
            app.UITable1.Layout.Row = 6;
            app.UITable1.Layout.Column = [2 7];
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
            app.UITable1_CountText.Layout.Row = 8;
            app.UITable1_CountText.Layout.Column = 3;
            app.UITable1_CountText.Text = ' CONTAGEM : 0';

            % Create UITable1_FilterText
            app.UITable1_FilterText = uilabel(app.GridLayout);
            app.UITable1_FilterText.HorizontalAlignment = 'right';
            app.UITable1_FilterText.FontSize = 10;
            app.UITable1_FilterText.Layout.Row = 8;
            app.UITable1_FilterText.Layout.Column = [5 6];
            app.UITable1_FilterText.Text = '0 DE 0 ';

            % Create UITable1_FilterIcon
            app.UITable1_FilterIcon = uiimage(app.GridLayout);
            app.UITable1_FilterIcon.ScaleMethod = 'none';
            app.UITable1_FilterIcon.Layout.Row = 8;
            app.UITable1_FilterIcon.Layout.Column = 7;
            app.UITable1_FilterIcon.ImageSource = 'Filter_18.png';

            % Create UITable1_AccountInfo
            app.UITable1_AccountInfo = uilabel(app.GridLayout);
            app.UITable1_AccountInfo.HorizontalAlignment = 'center';
            app.UITable1_AccountInfo.FontSize = 10;
            app.UITable1_AccountInfo.FontColor = [0.502 0.502 0.502];
            app.UITable1_AccountInfo.Layout.Row = 8;
            app.UITable1_AccountInfo.Layout.Column = [3 6];
            app.UITable1_AccountInfo.Text = '';

            % Create UITable2
            app.UITable2 = uitable(app.GridLayout);
            app.UITable2.BackgroundColor = [1 1 1;0.9412 0.9412 0.9412];
            app.UITable2.ColumnName = '';
            app.UITable2.RowName = {};
            app.UITable2.ColumnSortable = true;
            app.UITable2.CellEditCallback = createCallbackFcn(app, @TableCellEdit, true);
            app.UITable2.ClickedFcn = createCallbackFcn(app, @TableClicked, true);
            app.UITable2.ForegroundColor = [0.149 0.149 0.149];
            app.UITable2.Visible = 'off';
            app.UITable2.KeyReleaseFcn = createCallbackFcn(app, @TableClicked, true);
            app.UITable2.Layout.Row = 10;
            app.UITable2.Layout.Column = [2 7];
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
            app.UITable2_CountText.Layout.Row = 12;
            app.UITable2_CountText.Layout.Column = 3;
            app.UITable2_CountText.Text = ' CONTAGEM: 0';

            % Create UITable2_FilterText
            app.UITable2_FilterText = uilabel(app.GridLayout);
            app.UITable2_FilterText.HorizontalAlignment = 'right';
            app.UITable2_FilterText.FontSize = 10;
            app.UITable2_FilterText.Layout.Row = 12;
            app.UITable2_FilterText.Layout.Column = [5 6];
            app.UITable2_FilterText.Text = '0 DE 0 ';

            % Create UITable2_FilterIcon
            app.UITable2_FilterIcon = uiimage(app.GridLayout);
            app.UITable2_FilterIcon.ScaleMethod = 'none';
            app.UITable2_FilterIcon.Layout.Row = 12;
            app.UITable2_FilterIcon.Layout.Column = 7;
            app.UITable2_FilterIcon.ImageSource = 'Filter_18.png';

            % Create UITable2_AccountInfo
            app.UITable2_AccountInfo = uilabel(app.GridLayout);
            app.UITable2_AccountInfo.HorizontalAlignment = 'center';
            app.UITable2_AccountInfo.FontSize = 10;
            app.UITable2_AccountInfo.FontColor = [0.502 0.502 0.502];
            app.UITable2_AccountInfo.Layout.Row = 12;
            app.UITable2_AccountInfo.Layout.Column = [3 6];
            app.UITable2_AccountInfo.Text = '';

            % Create Toolbar
            app.Toolbar = uigridlayout(app.GridLayout);
            app.Toolbar.ColumnWidth = {'1x', 22, 22, 5, 22, 5, 22, 22};
            app.Toolbar.RowHeight = {4, 17, 2};
            app.Toolbar.ColumnSpacing = 5;
            app.Toolbar.RowSpacing = 0;
            app.Toolbar.Padding = [10 5 10 5];
            app.Toolbar.Layout.Row = 14;
            app.Toolbar.Layout.Column = [1 9];
            app.Toolbar.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create tool_CompanyInfo
            app.tool_CompanyInfo = uilabel(app.Toolbar);
            app.tool_CompanyInfo.VerticalAlignment = 'top';
            app.tool_CompanyInfo.WordWrap = 'on';
            app.tool_CompanyInfo.FontSize = 9;
            app.tool_CompanyInfo.FontColor = [0.149 0.149 0.149];
            app.tool_CompanyInfo.Layout.Row = [1 3];
            app.tool_CompanyInfo.Layout.Column = 1;
            app.tool_CompanyInfo.Interpreter = 'html';
            app.tool_CompanyInfo.Text = '';

            % Create tool_AccountEdition
            app.tool_AccountEdition = uiimage(app.Toolbar);
            app.tool_AccountEdition.ScaleMethod = 'none';
            app.tool_AccountEdition.ImageClickedFcn = createCallbackFcn(app, @ExportButton_2Pushed, true);
            app.tool_AccountEdition.Enable = 'off';
            app.tool_AccountEdition.Tooltip = {'Edita informações das contas movimentadas'};
            app.tool_AccountEdition.Layout.Row = 2;
            app.tool_AccountEdition.Layout.Column = 2;
            app.tool_AccountEdition.ImageSource = 'Variable_edit_16.png';

            % Create tool_AutoFill
            app.tool_AutoFill = uiimage(app.Toolbar);
            app.tool_AutoFill.ImageClickedFcn = createCallbackFcn(app, @tool_AutoFillImageClicked, true);
            app.tool_AutoFill.Enable = 'off';
            app.tool_AutoFill.Tooltip = {'Sugere anotação das contas movimentadas'};
            app.tool_AutoFill.Layout.Row = 2;
            app.tool_AutoFill.Layout.Column = 3;
            app.tool_AutoFill.ImageSource = 'AutoFill_36Blue.png';

            % Create tool_Separator1
            app.tool_Separator1 = uiimage(app.Toolbar);
            app.tool_Separator1.ScaleMethod = 'none';
            app.tool_Separator1.Enable = 'off';
            app.tool_Separator1.Layout.Row = [1 3];
            app.tool_Separator1.Layout.Column = 4;
            app.tool_Separator1.ImageSource = 'LineV.svg';

            % Create tool_SaveProject
            app.tool_SaveProject = uiimage(app.Toolbar);
            app.tool_SaveProject.ScaleMethod = 'none';
            app.tool_SaveProject.ImageClickedFcn = createCallbackFcn(app, @tool_SaveProjectImageClicked, true);
            app.tool_SaveProject.Enable = 'off';
            app.tool_SaveProject.Tooltip = {'Salva o projeto'};
            app.tool_SaveProject.Layout.Row = 2;
            app.tool_SaveProject.Layout.Column = 5;
            app.tool_SaveProject.ImageSource = 'Save_16.png';

            % Create tool_Separator2
            app.tool_Separator2 = uiimage(app.Toolbar);
            app.tool_Separator2.ScaleMethod = 'none';
            app.tool_Separator2.Enable = 'off';
            app.tool_Separator2.Layout.Row = [1 3];
            app.tool_Separator2.Layout.Column = 6;
            app.tool_Separator2.ImageSource = 'LineV.svg';

            % Create tool_GenerateReport
            app.tool_GenerateReport = uiimage(app.Toolbar);
            app.tool_GenerateReport.ScaleMethod = 'none';
            app.tool_GenerateReport.ImageClickedFcn = createCallbackFcn(app, @Toolbar_ReportImageClicked, true);
            app.tool_GenerateReport.Enable = 'off';
            app.tool_GenerateReport.Tooltip = {'Gera relatório análise'};
            app.tool_GenerateReport.Layout.Row = 2;
            app.tool_GenerateReport.Layout.Column = 7;
            app.tool_GenerateReport.ImageSource = 'Publish_HTML_16.png';

            % Create tool_UploadFinalFile
            app.tool_UploadFinalFile = uiimage(app.Toolbar);
            app.tool_UploadFinalFile.ImageClickedFcn = createCallbackFcn(app, @tool_UploadFinalFileImageClicked, true);
            app.tool_UploadFinalFile.Enable = 'off';
            app.tool_UploadFinalFile.Tooltip = {'Upload relatório'};
            app.tool_UploadFinalFile.Layout.Row = 2;
            app.tool_UploadFinalFile.Layout.Column = 8;
            app.tool_UploadFinalFile.ImageSource = 'Up_24.png';

            % Create DockModule
            app.DockModule = uigridlayout(app.GridLayout);
            app.DockModule.RowHeight = {'1x'};
            app.DockModule.ColumnSpacing = 2;
            app.DockModule.Padding = [5 2 5 2];
            app.DockModule.Visible = 'off';
            app.DockModule.Layout.Row = [2 3];
            app.DockModule.Layout.Column = [6 8];
            app.DockModule.BackgroundColor = [0.2 0.2 0.2];

            % Create dockModule_Close
            app.dockModule_Close = uiimage(app.DockModule);
            app.dockModule_Close.ScaleMethod = 'none';
            app.dockModule_Close.ImageClickedFcn = createCallbackFcn(app, @DockModuleGroup_ButtonPushed, true);
            app.dockModule_Close.Tag = 'DRIVETEST';
            app.dockModule_Close.Tooltip = {'Fecha módulo'};
            app.dockModule_Close.Layout.Row = 1;
            app.dockModule_Close.Layout.Column = 2;
            app.dockModule_Close.ImageSource = 'Delete_12SVG_white.svg';

            % Create dockModule_Undock
            app.dockModule_Undock = uiimage(app.DockModule);
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
