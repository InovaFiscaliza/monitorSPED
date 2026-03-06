classdef winECD_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        GridLayout              matlab.ui.container.GridLayout
        DockModule              matlab.ui.container.GridLayout
        dockModule_Close        matlab.ui.control.Image
        dockModule_Undock       matlab.ui.control.Image
        Toolbar                 matlab.ui.container.GridLayout
        tool_UploadFinalFile    matlab.ui.control.Image
        tool_GenerateReport     matlab.ui.control.Image
        tool_OpenPopupProject   matlab.ui.control.Image
        tool_CompanyInfo        matlab.ui.control.Label
        tool_Separator2         matlab.ui.control.Image
        tool_DeleteAnnotation   matlab.ui.control.Image
        tool_AutoFill           matlab.ui.control.Image
        tool_AccountButton      matlab.ui.control.Image
        tool_Separator1         matlab.ui.control.Image
        tool_OpenPopupIcmsRate  matlab.ui.control.Image
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
        SubTabGroup             matlab.ui.container.TabGroup
        SubTab1                 matlab.ui.container.Tab
        SubGrid1                matlab.ui.container.GridLayout
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
        SubTab2                 matlab.ui.container.Tab
        SubGrid2                matlab.ui.container.GridLayout
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
        FilterButton            matlab.ui.control.Button
        Tab2Separator1          matlab.ui.control.Image
        SheetOnFocus            matlab.ui.control.Lamp
        SheetHeight_Second      matlab.ui.control.Spinner
        SheetView_Second        matlab.ui.control.DropDown
        SheetHeight_First       matlab.ui.control.Spinner
        SheetView_First         matlab.ui.control.DropDown
        SheetViewStatus         matlab.ui.control.StateButton
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        Role = 'secondaryApp'
        Context = 'ECD'
    end


    properties (Access = public)
        %-----------------------------------------------------------------%
        Container
        isDocked = false
        mainApp
        jsBackDoor
        progressDialog
        popupContainer
    end


    properties (Access = private)
        %-----------------------------------------------------------------%
        projectData
        ecdObj
    end


    methods (Access = public)
        %-----------------------------------------------------------------%
        function ipcSecondaryJSEventsHandler(app, event)
            try
                switch event.HTMLEventName
                    case 'renderer'
                        appEngine.activate(app, app.Role)

                    otherwise
                        ipcMainJSEventsHandler(app.mainApp, event)
                end

            catch ME
                ui.Dialog(app.UIFigure, 'error', ME.message);
            end
        end

        %-----------------------------------------------------------------%
        function ipcSecondaryMatlabCallsHandler(app, callingApp, eventName, varargin)
            try
                switch class(callingApp)
                    case {'winMonitorSPED', 'winMonitorSPED_exported'}
                        switch eventName
                            case {'FileListChanged:Add', ...
                                  'FileListChanged:Del', ...
                                  'FileListChanged:Merge', ...
                                  'FileListChanged:ProjectLoad'}
                                initializeAppProperties(app)
                                applyInitialLayout(app, 'keepIfPossible')

                            % auxApp.winConfig >> winMonitorSPED >> auxApp.winECD
                            case {'onICMSTaxChanged', 'onPISTaxChanged', 'onCOFINSTaxChanged'}
                                forceUpdateTable(app)

                            % auxApp.dockECDAccount >> winMonitorSPED >> auxApp.winECD
                            case 'onAccountEdited'
                                forceUpdateTable(app)

                            case 'onAccountSelectionChanged'
                                accountName = varargin{1};
                                
                                for uiTable = [app.UITable1, app.UITable2]
                                    if ~isempty(uiTable.Data) && ismember('COD_CTA', uiTable.Data.Properties.VariableNames)
                                        [~, accountNameIdx] = ismember(accountName, uiTable.Data.COD_CTA);
                                        if accountNameIdx
                                            columnWidth = width(uiTable.Data);
                                            uiTable.Selection = [accountNameIdx * ones(columnWidth, 1), (1:columnWidth)'];

                                            if ~isequal(uiTable.Selection, uiTable.UserData.Selection)
                                                [tableCountText, tableSelectedAccount] = relatedTableComponents(app, uiTable);
                                                updateTableFootnote(app, uiTable, tableCountText, tableSelectedAccount)
                                            end
                                        end
                                    end
                                end
                                
                            % auxApp.dockECDExport >> winMonitorSPED >> auxApp.winECD
                            case 'onExportECD'
                                exportFiles(app, varargin{:})

                            % auxApp.dockECDFilter >> winMonitorSPED >> auxApp.winECD
                            case 'onFilterChanged'
                                tableId = varargin{1};
                                if strcmp(app.SheetList.Value, tableId)
                                    SheetViewFirstValueChanged(app, struct('Source', app.SheetList))
                                end

                                if strcmp(app.SheetView_Second.Value, tableId)
                                    SheetViewSecondValueChanged(app)
                                end

                            case 'onTableReadRequired'
                                [selectedECD, fileIndex] = getSelectedECD(app);
                                tableId = varargin{1};

                                requestVisibilityChange(app.progressDialog, 'visible', 'unlocked')

                                checkIfTableRead(app, selectedECD, fileIndex, {tableId})

                                requestVisibilityChange(app.progressDialog, 'hidden', 'unlocked')

                            % auxApp.dockReportLib >> winMonitorSPED >> auxApp.winECD
                            case {'onProjectRestart',        ...
                                  'onProjectLoad',           ...
                                  'onTableCellEdited'}
                                % ...

                            case {'onReportGenerate', 'onFinalReportFileChanged'}
                                selectedECD = getSelectedECD(app);
                                updateToolbar(app, selectedECD)

                            case 'onFetchIssueDetails'
                                system   = varargin{1};
                                issue    = varargin{2};
                                details  = varargin{3};
                                msgError = varargin{4};

                                if ~isempty(msgError)
                                    error(msgError)
                                end

                                msg = util.HtmlTextGenerator.issueDetails(system, issue, details);
                                ui.Dialog(app.UIFigure, 'info', msg);

                            otherwise
                                error('UnexpectedCall')
                        end
    
                    otherwise
                        error('UnexpectedCaller')
                end

            catch ME
                ui.Dialog(app.UIFigure, 'error', ME.message);
            end
        end
        
        %-------------------------------------------------------------------------%
        function applyJSCustomizations(app, tabIndex)
            if app.SubTabGroup.UserData.isTabInitialized(tabIndex)
                return
            end
            app.SubTabGroup.UserData.isTabInitialized(tabIndex) = true;
            
            appName = class(app);
            switch tabIndex
                case 1
                    elToModify = {
                        app.UITable1;
                        app.UITable2;
                        app.tool_OpenPopupIcmsRate;
                        app.tool_AccountButton;
                        app.tool_AutoFill;
                        app.tool_DeleteAnnotation;
                        app.tool_OpenPopupProject;
                        app.tool_GenerateReport;
                        app.tool_UploadFinalFile;
                        app.dockModule_Undock;
                        app.dockModule_Close
                    };
                    ui.CustomizationBase.getElementsDataTag(elToModify);

                    try
                        sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', { ...
                            struct('appName', appName, 'dataTag', app.tool_OpenPopupIcmsRate.UserData.id,'tooltip', struct('defaultPosition', 'top',    'textContent', 'Edita a alíquota global de referência do ICMS')), ...
                            struct('appName', appName, 'dataTag', app.tool_AccountButton.UserData.id,    'tooltip', struct('defaultPosition', 'top',    'textContent', 'Edita, em formulário, informações das contas movimentadas')), ...
                            struct('appName', appName, 'dataTag', app.tool_AutoFill.UserData.id,         'tooltip', struct('defaultPosition', 'top',    'textContent', 'Sugere anotação das contas movimentadas')), ...
                            struct('appName', appName, 'dataTag', app.tool_DeleteAnnotation.UserData.id, 'tooltip', struct('defaultPosition', 'top',    'textContent', 'Exclui anotação das contas selecionadas')), ...
                            struct('appName', appName, 'dataTag', app.tool_OpenPopupProject.UserData.id, 'tooltip', struct('defaultPosition', 'top',    'textContent', 'Edita informações do projeto<br>(fiscalizada, arquivo de backup etc)')), ...
                            struct('appName', appName, 'dataTag', app.tool_GenerateReport.UserData.id,   'tooltip', struct('defaultPosition', 'top',    'textContent', 'Gera relatório')), ...
                            struct('appName', appName, 'dataTag', app.tool_UploadFinalFile.UserData.id,  'tooltip', struct('defaultPosition', 'top',    'textContent', 'Upload relatório')), ...
                            struct('appName', appName, 'dataTag', app.dockModule_Undock.UserData.id,     'tooltip', struct('defaultPosition', 'bottom', 'textContent', 'Reabre módulo em outra janela')), ...
                            struct('appName', appName, 'dataTag', app.dockModule_Close.UserData.id,      'tooltip', struct('defaultPosition', 'bottom', 'textContent', 'Fecha módulo')) ...
                        });
                    catch
                    end

                case 2
                    elToModify = {
                        app.SheetOnFocus;
                        app.StyleDelete;
                        app.StyleRefresh
                    };
                    ui.CustomizationBase.getElementsDataTag(elToModify);

                    try
                        sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', { ...
                            struct('appName', appName, 'dataTag', app.SheetOnFocus.UserData.id,          'tooltip', struct('defaultPosition', 'top',    'textContent', 'Tabela ativa')), ...
                            struct('appName', appName, 'dataTag', app.StyleDelete.UserData.id,           'tooltip', struct('defaultPosition', 'top',    'textContent', 'Remove o estilo aplicado às células selecionadas da tabela ativa')), ...
                            struct('appName', appName, 'dataTag', app.StyleRefresh.UserData.id,          'tooltip', struct('defaultPosition', 'top',    'textContent', 'Remove o estilo aplicado à tabela ativa')) ...
                        });
                    catch
                    end

                    applyInitialLayout(app, 'keepCurrent')
                    app.FontFamily.Items = [{''}; listfonts];
            end
        end

        %-----------------------------------------------------------------%
        function initializeAppProperties(app)
            app.projectData = app.mainApp.projectData;
            app.ecdObj      = app.mainApp.ecdObj;
        end

        %-----------------------------------------------------------------%
        function initializeUIComponents(app)
            if ~strcmp(app.mainApp.executionMode, 'webApp')
                app.dockModule_Undock.Enable = 1;
            end

            % Tabelas:
            app.UITable1.RowName = 'numbered';
            app.UITable2.RowName = 'numbered';
            
            restartTableSelectionControl(app, app.UITable1, app.UITable1_CountText)
            restartTableSelectionControl(app, app.UITable2, app.UITable2_CountText)

            app.UITable1.UserData.TableId = '';
            app.UITable2.UserData.TableId = '';
        end

        %-----------------------------------------------------------------%
        function applyInitialLayout(app, selectionMode)
            arguments
                app
                selectionMode {mustBeMember(selectionMode, {'fromMainApp', 'keepIfPossible', 'keepCurrent'})} = 'fromMainApp'
            end

            nonEmptyECDObject = ~isempty(app.ecdObj);

            renderedElements  = {
                app.ExportButton;
                app.MemoryUsageButton;
                app.LogButton
            };

            if app.SubTabGroup.UserData.isTabInitialized(2)
                renderedElements = [renderedElements; {
                    app.FilterButton;
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
                        fileIndex = ipcMainMatlabCallsHandler(app.mainApp, app, 'getSelectedFileIndex');
                        companyIndex = find(cellfun(@(x) ismember(fileIndex, x), app.CompanyNameList.UserData.values), 1);
                        app.CompanyNameList.Value = app.CompanyNameList.Items{companyIndex};
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
                    restartTable(app, app.UITable1, app.UITable1_AccountInfo, app.UITable1_CountText, app.UITable1_FilterText, app.UITable1_FilterIcon)
                end

                if ~isempty(app.UITable2.Data)
                    restartTable(app, app.UITable2, app.UITable2_AccountInfo, app.UITable2_CountText, app.UITable2_FilterText, app.UITable2_FilterIcon)
                end
            end

            selectedECD = getSelectedECD(app);
            updateToolbar(app, selectedECD)
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function companyIndexes = getSelectedFileIdxsByCompany(app)
            companyId      = extractBefore(app.CompanyNameList.Value, ' -');
            companyIndexes = cell2mat(app.CompanyNameList.UserData(companyId));
        end

        %-----------------------------------------------------------------%
        function [selectedECD, fileIndex] = getSelectedECD(app)
            if isempty(app.ecdObj)
                selectedECD = [];
                fileIndex   = [];

            else
                companyIndexes  = getSelectedFileIdxsByCompany(app);
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
        function tableId = getSelectedTableId(app, hTable)
            switch hTable
                case app.UITable1
                    tableId = app.SheetList.Value;
                case app.UITable2
                    tableId = app.SheetView_Second.Value;
            end
        end

        %-----------------------------------------------------------------%
        function updateTimePeriodList(app, fileIndex)
            companyIndexes = getSelectedFileIdxsByCompany(app);
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
            selectedECD = getSelectedECD(app);
            ordinaryIds = getTableIds(selectedECD);

            % Algumas das tabelas customizadas existirão apenas se registros 
            % ordinários estiverem presentes na escrituração. Por exemplo,
            % "I200_I250" existe apenas se o registro "I200" existe.
            customIds = app.mainApp.General.context.ECD.customTables.expected;
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
            sheetsSorted = [sheetsSorted(startsWith(sheetsSorted, '_')); sheetsSorted(~startsWith(sheetsSorted, '_'))];

            selection1 = app.SheetList.Value;
            if isempty(selection1) || ~ismember(selection1, sheetsSorted) || ~isfield(selectedECD.Table, ['x' selection1])
                selection1 = '0000';
            end            
            set(app.SheetList, 'Items', sheetsSorted, 'Value', selection1)

            % Atualiza dropdowns apenas se a Tab2 já estiver sido renderizada, 
            % evitando erros no console de tentativa de atualização de um 
            % componente incompleto.
            if app.SubTabGroup.UserData.isTabInitialized(2)
                selection2 = app.SheetView_Second.Value;
                if isempty(selection2) || ~ismember(selection2, sheetsSorted) || ~isfield(selectedECD.Table, ['x' selection2])
                    selection2 = '0000';
                end

                set(app.SheetView_First,  'Items', sheetsSorted, 'Value', selection1)
                set(app.SheetView_Second, 'Items', sheetsSorted, 'Value', selection2)
            end
        end

        %-----------------------------------------------------------------%
        function updateTable(app, hTable, hTableAccountInfo, hTableCountText, hTableFilterText, hTableFilterIcon, tableId)
            requestVisibilityChange(app.progressDialog, 'visible', 'unlocked')

            [selectedECD, fileIndex] = getSelectedECD(app);            
            checkIfTableRead(app, selectedECD, fileIndex, {tableId})
            tableIdData = selectedECD.Table.(['x' tableId]);
            
            % Filtra os dados, caso aplicável.
            [filterIndex, filterStatus] = checkTableCustomFilter(app, selectedECD, tableId, 'active');

            if filterStatus
                filterObj = selectedECD.GUI.tableView(filterIndex).filter;
                displayDataIdxs = find(run(filterObj, 'filterRules', tableIdData));                
                filterIconTooltip = strjoin(getFilterList(filterObj, ['ECD.x' tableId], 'on'), '\n');
            else
                displayDataIdxs = (1:height(tableIdData))';                
                filterIconTooltip = '';
            end

            % Ordena os dados, caso aplicável.
            displayDataIdxs = checkTableCustomSort(app, selectedECD, tableId, displayDataIdxs);

            % Número total de linhas da tabela e número de linhas visíveis.
            numRows = height(tableIdData);
            numVisibleRows = numel(displayDataIdxs);

            % Inclusão da coluna "CTA", caso habilitado.
            if app.mainApp.General.context.ECD.accountDescriptionScope
                variableNames = tableIdData.Properties.VariableNames;
                variableToAdd = 'CTA';
                if ismember('COD_CTA', variableNames) && ~ismember(variableToAdd, variableNames)
                    tableIdData = addAccountDescription(selectedECD, tableIdData, variableNames, variableToAdd);
                end
            end

            % Configuração básica das colunas:
            % - largura padrão em modo automático;
            % - nomes das colunas retirados da própria tabela; e
            % - colunas editáveis identificadas pelo marcador (✎) no nome
            columnWidth = 'auto';
            columnNames = tableIdData.Properties.VariableNames;
            columnEditable = contains(columnNames, '✎');

            % Definição dos rótulos das linhas, orientado à seguinte ordem
            % de priorização:
            % (1) RowNames definidos explicitamente na table;
            % (2) Numeração automática quando todas as linhas estão visíveis;
            % (3) Índices reais das linhas quando apenas um subconjunto é exibido
            %     (neste caso, força largura uniforme das colunas)
            if ~isempty(tableIdData.Properties.RowNames)
                rowNames = tableIdData.Properties.RowNames;
            else
                columnWidth = '1x';
                rowNames = cellstr(string(displayDataIdxs));
            end

            % Verifica se a tabela suporta formatação customizável das suas
            % colunas, obtendo-se especificação de cada coluna. Caso todos os 
            % formatos sejam vazios, a configuração do parâmetro "ColumnFormat"
            % é inócua. Em sendo válido, deve-se converter os dados tabulares
            % (originalmente no formato "table") para "cell array".
            columnFormat = {};
            if ui.Table.hasCustomizableColumnFormat(tableIdData)
                columnFormat = model.ECDBase.getFieldSpecification(columnNames, 'Format');
                if isempty(columnFormat) || all(cellfun(@isempty, columnFormat))
                    columnFormat = {};
                end
            end

            if ~isempty(columnFormat)
                tableIdData = table2cell(tableIdData);
            end

            columnOptionalArgs = {};
            if ~isequal(hTable.UserData.TableId, tableId)
                columnOptionalArgs = {'ColumnWidth', columnWidth, 'ColumnName', columnNames, 'ColumnEditable', columnEditable};
            end

            if ~isequal(hTable.ColumnFormat, columnFormat)
                columnOptionalArgs = [columnOptionalArgs, {'ColumnFormat', columnFormat}];
            end
            
            % Aplicação final das propriedades na uitable
            if ~isequal(hTable.UserData.TableId, tableId)
                set(hTable, 'RowName', rowNames, 'Data', tableIdData(displayDataIdxs, :), columnOptionalArgs{:})
            else
                hTable.Data = tableIdData(displayDataIdxs, :);
                hTable.RowName = rowNames;
            end
            pause(.250) % drawnow
            hTable.UserData.TableId = tableId;
            hTable.UserData.visibleRows = displayDataIdxs;

            % Atualiza elementos que suportam a tabela...
            restartTableSelectionControl(app, hTable, hTableAccountInfo, hTableCountText)
            updateTableFootnote(app, hTable, hTableCountText, hTableAccountInfo)

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

            requestVisibilityChange(app.progressDialog, 'hidden', 'unlocked')
        end

        %-----------------------------------------------------------------%
        function updateTableFootnote(app, clickedTable, tableCountText, tableSelectedAccount)
            clickedTable.UserData.Selection = clickedTable.Selection;

            if isempty(clickedTable.Selection)
                tableCountText.Text       = ' CONTAGEM: 0';
                tableSelectedAccount.Text = '';                    
            else
                selectedColumnIdxs = unique(clickedTable.Selection(:, 2))';
                isNumeric = true;
                for columnIdx = selectedColumnIdxs
                    if ~isnumeric(clickedTable.Data{1, columnIdx})
                        isNumeric = false;
                        break;
                    end
                end

                cellsCount = height(clickedTable.Selection);
                if isNumeric
                    switch clickedTable.UserData.SelectionType
                        case 'column'
                            if istable(clickedTable.Data)
                                referenceData = double(clickedTable.Data.(selectedColumnIdxs));
                            else
                                referenceData = double(cell2mat(clickedTable.Data(:, selectedColumnIdxs)));
                            end

                            cellsSum      = sum(referenceData, 'all');
                            cellsAverage  = mean(referenceData, 'all');

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
                [~, accountColumnIdx] = ismember('COD_CTA', clickedTable.ColumnName);
                if isscalar(selectedRows) && accountColumnIdx
                    selectedECD = getSelectedECD(app);

                    selectedAccount = clickedTable.Data{selectedRows, accountColumnIdx};
                    selectedAccountIndex = find(strcmp(selectedECD.Table.x_CONTAS_DESCRICAO.("COD_CTA"), selectedAccount), 1);
        
                    if ~isempty(selectedAccountIndex)
                        selectedAccountDescription = sprintf('COD_CTA %s\n%s', char(selectedAccount), selectedECD.Table.x_CONTAS_DESCRICAO.("DESCRIÇÃO"){selectedAccountIndex});
                    end
                end                    
                tableSelectedAccount.Text = selectedAccountDescription;
            end
        end

        %-----------------------------------------------------------------%
        function updateToolbar(app, selectedECD)
            % A tabela "x_CONTAS_ANOTACAO" é composta pelas contas analíticas
            % de resultado que compõem "_BALANCETE_RESULTADO". Por essa razão, 
            % caso essa tabela não seja vazia, infere-se que é possível
            % classificar as contas, gerar relatório etc.

            % Por outro lado, caso não tenha sido registrado fato contábil,
            % essa tabela será vazia.

            nonEmptyECDObject                 = ~isempty(selectedECD);
            hasSpecificNonEmptyTable          = nonEmptyECDObject && isfield(selectedECD.Table, 'x_CONTAS_ANOTACAO') && ~isempty(selectedECD.Table.x_CONTAS_ANOTACAO);            
            reportFinalVersionGenerated       = ~isempty(app.projectData.modules.(app.Context).generatedFiles.lastHTMLDocFullPath);

            tableIdView = {app.SheetList.Value};
            if ~isempty(app.SheetView_Second.Value)
                tableIdView{end+1} = app.SheetView_Second.Value;
            end

            app.tool_OpenPopupIcmsRate.Enable = nonEmptyECDObject;
            app.tool_AccountButton.Enable     = hasSpecificNonEmptyTable;
            app.tool_AutoFill.Enable          = hasSpecificNonEmptyTable && ismember('_CONTAS_ANOTACAO', tableIdView);
            app.tool_DeleteAnnotation.Enable  = hasSpecificNonEmptyTable && ismember('_CONTAS_ANOTACAO', tableIdView);
            app.tool_Separator2.Visible       = nonEmptyECDObject;
            app.tool_GenerateReport.Enable    = nonEmptyECDObject && isfield(selectedECD.Table, 'x_CONTAS_ANOTACAO');
            app.tool_UploadFinalFile.Enable   = reportFinalVersionGenerated;
        end

        %-----------------------------------------------------------------%
        function restartTable(app, hTable, hTableAccountInfo, hTableCountText, hTableFilter, hTableFilterIcon)
            set(hTable, 'ColumnWidth', 'auto', ...
                        'ColumnName', {}, ...
                        'ColumnEditable', false, ...
                        'Data', [])
            
            hTableAccountInfo.Text = '';
            hTableCountText.Text   = ' CONTAGEM : 0';
            hTableFilter.Text      = '0 DE 0 ';
            set(hTableFilterIcon, 'ImageSource', 'FilterGray_18.png', 'Tooltip', '')
        end

        %-----------------------------------------------------------------%
        function restartTableSelectionControl(app, hTable, hTableAccountInfo, hTableCountText)
            hTable.Selection = [];
            
            % ().UserData.id armazenará o "data-tag" do componente, caso haja
            % alguma customização em curso.
            hTable.UserData.Selection = [];
            hTable.UserData.SelectionType = 'none';

            if hTable == app.UITable2 && app.SubTabGroup.UserData.isTabInitialized(2)
                hTableAccountInfo.Text = '';
                hTableCountText.Text   = ' CONTAGEM: 0';
            end
        end

        %-----------------------------------------------------------------%
        function forceUpdateTable(app)
            refTable    = struct('handle', app.UITable1, 'controller', app.SheetList);
            refTable(2) = struct('handle', app.UITable2, 'controller', app.SheetView_Second);

            for ii = 1:numel(refTable)
                tableHandle = refTable(ii).handle;
                controller  = refTable(ii).controller;
                tableId     = controller.Value;
                
                if ismember(tableId, {'_CONTAS_ANOTACAO', '_APURACAO_GERAL', '_APURACAO_INTERCONEXAO'})
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
                ipcMainMatlabCallsHandler(app.mainApp, app, 'onAccountingDataUpdated', fileIndex);
            end

            updateFinanceFacts(app, selectedECD)
            updateToolbar(app, selectedECD)
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
        function visibleRows = checkTableCustomSort(app, selectedECD, tableId, visibleRows)
            [~, displayIdx] = ismember(tableId, {selectedECD.GUI.tableView.id});

            if displayIdx && isfield(selectedECD.GUI.tableView(displayIdx), 'sort') && ~isempty(selectedECD.GUI.tableView(displayIdx).sort)
                dataIdxs = selectedECD.GUI.tableView(displayIdx).sort.dataIdxs;

                if numel(visibleRows) == numel(dataIdxs) && all(ismember(visibleRows, dataIdxs))
                    visibleRows = dataIdxs;
                end
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
        function applyDefaultBackgroundToUiColorPicker(app, evtSource)
            switch evtSource
                case app.FontBackground
                    app.FontBackground.Value = [1 0 0.0118];
                case app.FontColor
                    app.FontColor.Value = [0 0 0.0118];
            end
        end

        %-----------------------------------------------------------------%
        function exportFiles(app, fileIndex, rawTableIdFields)
            selectedECD     = app.ecdObj(fileIndex);

            defaultBaseName =  appEngine.util.DefaultFileName(app.mainApp.General.fileFolder.userPath, 'monitorSPED');
            excelTempName   = [appEngine.util.DefaultFileName(app.mainApp.General.fileFolder.tempPath, 'monitorSPED') '.xlsx'];
            rtfTempFiles    = {};

            requestVisibilityChange(app.progressDialog, 'visible', 'unlocked')

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
                
                fileFullPath = ui.Dialog(app.UIFigure, 'uiputfile', '', nameFormatMap, defaultBaseName);
                if isempty(fileFullPath)
                    error('Operação cancelada pelo usuário.')
                end

                if isscalar(outputfiles)
                    copyfile(outputfiles{1}, fileFullPath, 'f')

                    if ~strcmp(app.mainApp.executionMode, 'webApp')
                        appEngine.util.OperationSystem('openFile', fileFullPath)
                    end
                else
                    zip(fileFullPath, outputfiles)
                end
            catch ME
                msgError{end+1} = ME.message;
            end

            requestVisibilityChange(app.progressDialog, 'hidden', 'unlocked')

            % WARNING MESSAGE
            if ~isempty(msgError)
                msgError = strjoin(msgError, '<br><br>');
                ui.Dialog(app.UIFigure, 'warning', msgError);
            end
        end

        %-----------------------------------------------------------------%
        function reportDispatchOperation(app, eventName, varargin)
            arguments
                app
                eventName {mustBeMember(eventName, {'onReportGenerate', 'onUploadArtifacts'})}
            end

            arguments (Repeating)
                varargin
            end

            if isempty(app.mainApp.eFiscalizaObj) || ~isvalid(app.mainApp.eFiscalizaObj)
                dialogBox    = struct('id', 'login',    'label', 'Usuário: ', 'type', 'text');
                dialogBox(2) = struct('id', 'password', 'label', 'Senha: ',   'type', 'password');

                customFormData = struct('UUID', eventName, 'Fields', dialogBox, 'Context', app.Context);
                if ~isempty(varargin)
                    customFormData.Varargin = varargin;
                end

                sendEventToHTMLSource(app.jsBackDoor, 'customForm', customFormData)

            else
                ipcMainMatlabCallsHandler(app.mainApp, app, eventName, app.Context, varargin{:})
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp)
            
            try
                appEngine.boot(app, app.Role, mainApp)
            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME), 'CloseFcn', @(~,~)closeFcn(app));
            end

        end

        % Close request function: UIFigure
        function closeFcn(app, event)

            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcn', app.Context)
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

        % Selection change function: SubTabGroup
        function SubTabGroupSelectionChanged(app, event)
            
            [~, tabIndex] = ismember(app.SubTabGroup.SelectedTab, app.SubTabGroup.Children);
            applyJSCustomizations(app, tabIndex)

        end

        % Callback function: ExportButton, FilterButton, MemoryUsageButton,
        % 
        % ...and 1 other component
        function onPopupModuleRequest(app, event)
            
            context = app.Context;
            [~, fileIndex] = getSelectedECD(app);

            switch event.Source
                case app.ExportButton
                    ipcMainMatlabOpenPopupApp(app.mainApp, app, 'ECDExport', context, fileIndex)

                case app.MemoryUsageButton
                    ipcMainMatlabOpenPopupApp(app.mainApp, app, 'ECDMemoryUsage', context, fileIndex)

                case app.FilterButton
                    tableIdList     = app.SheetList.Items;
                    selectedTableId = app.SheetList.Value;
        
                    ipcMainMatlabOpenPopupApp(app.mainApp, app, 'ECDFilter', context, fileIndex, tableIdList, selectedTableId)

                case app.tool_AccountButton
                    clickedTable = onFocusTable(app);
                    [~, accountColumnIdx] = ismember('COD_CTA', clickedTable.ColumnName);

                    if ~isempty(clickedTable.Selection) && isscalar(unique(clickedTable.Selection(:,1))) && accountColumnIdx
                        selectedRow = unique(clickedTable.Selection(:,1));
                        accountName = clickedTable.Data{selectedRow, accountColumnIdx};
                    else
                        accountName = '';
                    end
                    
                    ipcMainMatlabOpenPopupApp(app.mainApp, app, 'ECDAccount', context, fileIndex, accountName)
            end

        end

        % Image clicked function: tool_AutoFill
        function Toolbar_AutoFillImageClicked(app, event)
            
            selectedECD = getSelectedECD(app);
            if ~isfield(selectedECD.Table, 'x_CONTAS_ANOTACAO')
                return
            end

            update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'autoFill', app.mainApp.General)
            forceUpdateTable(app)

        end

        % Image clicked function: tool_DeleteAnnotation
        function Toolbar_DeleteAnnotationImageClicked(app, event)
            
            clickedTable = onFocusTable(app);
            selectedECD = getSelectedECD(app);

            if (isequal(clickedTable, app.UITable1) && isequal(app.SheetList.Value,        '_CONTAS_ANOTACAO')) || ...
               (isequal(clickedTable, app.UITable2) && isequal(app.SheetView_Second.Value, '_CONTAS_ANOTACAO'))
                d = getRowIndexMapping(app, 'guiToModel', clickedTable);

                userCellSelection = clickedTable.Selection;
                if ~isempty(userCellSelection)
                    rowIndexes = d(unique(userCellSelection(:, 1)));
                    update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'deleteAnnotation', app.mainApp.General, rowIndexes)
                    forceUpdateTable(app)
                end
            end

        end

        % Image clicked function: tool_OpenPopupIcmsRate, 
        % ...and 1 other component
        function Toolbar_OpenPopupAppImageClicked(app, event)
            
            switch event.Source
                case app.tool_OpenPopupIcmsRate
                    [~, fileIndex] = getSelectedECD(app);
                    ipcMainMatlabOpenPopupApp(app.mainApp, app, 'IcmsRate', app.Context, fileIndex)

                case app.tool_OpenPopupProject
                    ipcMainMatlabOpenPopupApp(app.mainApp, app, 'ReportLib', app.Context, app.ecdObj)
            end

        end

        % Image clicked function: tool_GenerateReport
        function Toolbar_ReportImageClicked(app, event)
            
            context = app.Context;
            if ~validateReportRequirements(app.projectData, context, 'reportModel')
                ui.Dialog(app.UIFigure, 'warning', 'Pendente escolha do modelo de relatório.');
                return
            end
            
            [~, fileIndex] = getSelectedECD(app);

            if ~isempty(fileIndex)
                % <VALIDAÇÕES>
                issue = app.projectData.modules.(context).ui.issue;
                reportVersion = app.projectData.modules.(context).ui.reportVersion;
    
                msgWarning = {};
                [auditorValidationStatus, auditorValidationMessage] = validateReportGenerationRequirements(app.ecdObj(fileIndex));
                if ~auditorValidationStatus
                    msgWarning{end+1} = auditorValidationMessage;
                end

                if ~validateReportRequirements(app.projectData, context, 'issue')
                    msgWarning{end+1} = sprintf('• O número da inspeção "%.0f" é inválido.', issue);
                end
    
                if ~validateReportRequirements(app.projectData, context, 'unit')
                    msgWarning{end+1} = '• Unidade geradora do documento precisa ser selecionada.';
                end
    
                if isempty(msgWarning)
                    switch reportVersion
                        case 'Definitiva'
                            msgQuestion = sprintf('Confirma que se trata de monitoração relacionada à Atividade de Inspeção nº %.0f?', issue);
                            userSelection = ui.Dialog(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 1, 2);
                            if userSelection == "Não"
                                return
                            end
                            
                        case 'Preliminar'
                            % ...
                    end
    
                else
                    switch reportVersion
                        case 'Definitiva'
                            msgInfo = sprintf([ ...
                                    'Foi(ram) identificado(s) a(s) pendência(s):<br>%s' ...
                                    '<br><br>' ...
                                    '<b>Essa(s) pendência(s) precisa(m) ser resolvida(s) ' ...
                                    'antes de ser gerada a versão "Definitiva" do relatório</b>.' ...
                                ], strjoin(msgWarning, '<br>') ...
                            );
                            ui.Dialog(app.UIFigure, 'warning', msgInfo);
                            return
    
                        case 'Preliminar'
                            msgQuestion = sprintf([ ...
                                    'Foi(ram) identificado(s) a(s) pendência(s):<br>%s' ...
                                    '<br><br>' ...
                                    '<b>Continuar mesmo assim?</b>' ...
                                ], strjoin(msgWarning, '<br>') ...
                            );
                            selection = ui.Dialog(app.UIFigure, "uiconfirm", msgQuestion, {'Sim', 'Não'}, 1, 2);
                            if strcmp(selection, 'Não')
                                return
                            end
                    end
                end
                % </VALIDAÇÕES>
    
                % <PROCESSO>
                reportDispatchOperation(app, 'onReportGenerate', fileIndex)
                % </PROCESSO>
            end
            
        end

        % Image clicked function: tool_UploadFinalFile
        function Toolbar_UploadFinalFileImageClicked(app, event)
            
            % <VALIDAÇÕES>
            context = app.Context;            
            system = app.projectData.modules.(context).ui.system;
            issue = app.projectData.modules.(context).ui.issue;
            generatedHtmlFilePath = getGeneratedDocumentFileName(app.projectData, '.html', context);

            msg = '';
            if isempty(generatedHtmlFilePath)
                msg = 'A versão definitiva do relatório ainda não foi gerada.';
            elseif ~isfile(generatedHtmlFilePath)
                msg = sprintf('O arquivo "%s" não foi encontrado.', generatedHtmlFilePath);
            elseif ~isfolder(app.mainApp.General.fileFolder.DataHub_POST)
                msg = 'Pendente mapear pasta do Sharepoint';
            elseif ~validateReportRequirements(app.projectData, context, 'issue')
                msg = sprintf('O número da inspeção "%.0f" é inválido.', issue);
            elseif ~validateReportRequirements(app.projectData, context, 'unit')
                msg = 'Unidade geradora do documento precisa ser selecionada.';
            elseif isempty(system)
                msg = 'Ambiente do eFiscaliza precisa ser selecionado.';
            end

            if ~isempty(msg)
                ui.Dialog(app.UIFigure, 'warning', msg);
                return
            end

            selectedECD = getSelectedECD(app);

            storedReportHash  = app.projectData.modules.(context).generatedFiles.id;
            currentReportHash = model.ProjectBase.computeReportAnalysisResultsHash(selectedECD);

            if ~isequal(storedReportHash, currentReportHash)
                [~, generatedHtmlFileName, generatedHtmlFileExt] = fileparts(generatedHtmlFilePath);
                msgQuestion = sprintf([ ...
                    'O relatório indicado a seguir foi gerado com base em ' ...
                    'um conjunto específico de arquivos e anotações.<br>%s<br><br>' ...
                    '<i>Hash</i> no momento da geração:<br>' ...
                    '%s<br><br>' ...
                    '<i>Hash</i> atual (após alterações):<br>' ...
                    '%s<br><br>' ...
                    'Isso indica que um arquivo diferente foi selecionado ' ...
                    'ou que alguma anotação foi modificada desde a geração ' ...
                    'do relatório.<br><br>' ...
                    '<b>Deseja continuar com o <i>upload</i> mesmo assim?</b>' ...
                ], [generatedHtmlFileName, generatedHtmlFileExt], textFormatGUI.cellstr2Bullets(strsplit(storedReportHash, ' - ')), textFormatGUI.cellstr2Bullets(strsplit(currentReportHash, ' - ')));
                userSelection = ui.Dialog(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 2, 2);

                if strcmp(userSelection, 'Não')
                    return
                end
            end

            uploadedFiles = getUploadedFiles(app.projectData, context, system, issue);
            if ~isempty(uploadedFiles)
                uploadedStatus = extractAfter({uploadedFiles.status}, 'Documento cadastrado no SEI sob o nº ');

                if isscalar(uploadedStatus)
                    uploadedStatus = uploadedStatus{1};
                else                    
                    uploadedStatus = strjoin([{strjoin(uploadedStatus(1:end-1), ', ')}, uploadedStatus(end)], ' e ');
                end

                msgQuestion = sprintf([ ...
                    'Já foi realizado <i>upload</i> para o SEI de relatório relacionado ' ...
                    'à Atividade de Inspeção nº %d - SEI nº %s.<br><br>' ...
                    'Deseja realizar um novo <i>upload</i> para o SEI?' ...
                ], issue, uploadedStatus);
                userSelection = ui.Dialog(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 2, 2);

                if strcmp(userSelection, 'Não')
                    return
                end
            end
            % </VALIDAÇÕES>

            % <PROCESSO>
            reportDispatchOperation(app, 'onUploadArtifacts')
            % </PROCESSO>

        end

        % Value changed function: CompanyNameList
        function CompanyNameListValueChanged(app, event)

            updateTimePeriodList(app, [])
            TimePeriodListValueChanged(app)

        end

        % Value changed function: TimePeriodList
        function TimePeriodListValueChanged(app, event)
            
            requestVisibilityChange(app.progressDialog, 'visible', 'locked')
            
            selectedECD = getSelectedECD(app);

            app.tool_CompanyInfo.Text = sprintf('<font style="font-size: 11px; font-weight: bold;">%s</font> CNPJ %s (%s) \n%s ', ...
                upper(selectedECD.CompanyName), selectedECD.CompanyId, selectedECD.State, strjoin(string(selectedECD.Period), ' a '));
            
            updateSheetList(app)
            SheetViewFirstValueChanged(app, struct('Source', app.SheetList))
            SheetViewSecondValueChanged(app)

            requestVisibilityChange(app.progressDialog, 'hidden', 'locked')
            
        end

        % Value changed function: SheetList, SheetView_First
        function SheetViewFirstValueChanged(app, event)
            
            switch event.Source
                case app.SheetList
                    if app.SubTabGroup.UserData.isTabInitialized(2)
                        app.SheetView_First.Value = app.SheetList.Value;
                    end
                case app.SheetView_First
                    app.SheetList.Value = app.SheetView_First.Value;
            end

            updateTable(app, app.UITable1, app.UITable1_AccountInfo, app.UITable1_CountText, app.UITable1_FilterText, app.UITable1_FilterIcon, app.SheetList.Value)

        end

        % Value changed function: SheetView_Second
        function SheetViewSecondValueChanged(app, event)
            
            if app.UITable2.Visible
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

                selectedECD = getSelectedECD(app);
                if ~isempty(selectedECD)
                    SheetViewSecondValueChanged(app)
                end
                
            else
                app.SheetView_Second.Enable  = "off";
                app.SheetHeight_First.Enable = 'off';
                
                app.SheetHeight_Second.Limits(1) = 0;
                set(app.SheetHeight_Second, 'Enable', 'off', 'Value', 0)

                app.UITable2.Visible = 'off';
                rowHeight = {0,0,0};
                
                restartTable(app, app.UITable2, app.UITable2_AccountInfo, app.UITable2_CountText, app.UITable2_FilterText, app.UITable2_FilterIcon)                

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

        % Button pushed function: LogButton
        function LogButtonPushed(app, event)
            
            selectedECD = getSelectedECD(app);

            htmlContent = util.HtmlTextGenerator.Warnings(selectedECD);
            ui.Dialog(app.UIFigure, 'info', htmlContent);

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

            clickedTable = event.Source;
            selectedECD = getSelectedECD(app);
            tableId = getSelectedTableId(app, clickedTable);
            
            rowIndex = event.Source.UserData.visibleRows(event.Indices(1));
            colName = clickedTable.ColumnName{event.Indices(2)};
            [~, colIndex] = ismember(colName, selectedECD.Table.(['x' tableId]).Properties.VariableNames);

            if colIndex
                if iscellstr(selectedECD.Table.(['x' tableId]){rowIndex, colIndex})
                    newData = {strtrim(newData)};
                end
    
                update(selectedECD, 'Table.x_CONTAS_ANOTACAO', 'valueChanged', app.mainApp.General, rowIndex, colIndex, colName, newData)
            end
            forceUpdateTable(app)

        end

        % Callback function: FontAlign1, FontAlign2, FontAlign3, 
        % ...and 6 other components
        function TableStyleChanged(app, event)

            evtSource = event.Source;
            clickedTable = onFocusTable(app);

            if isempty(clickedTable.Selection)
                applyDefaultBackgroundToUiColorPicker(app, evtSource)
                return
            end

            selectedECD = getSelectedECD(app);
            tableId = getSelectedTableId(app, clickedTable);

            styleIndex = checkTableCustomStyle(app, selectedECD, tableId);
            if isempty(styleIndex)
                styleIndex = numel(selectedECD.GUI.tableView)+1;
            end
            
            % Estilo novo:
            switch evtSource
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
                    switch evtSource
                        case app.FontAlign1; fieldValue = {'left'};
                        case app.FontAlign2; fieldValue = {'center'};
                        case app.FontAlign3; fieldValue = {'right'};
                    end

                case app.FontBackground
                    fieldName  = 'BackgroundColor';
                    fieldValue = {event.Value};
                    applyDefaultBackgroundToUiColorPicker(app, event.Source)

                case app.FontColor
                    fieldName  = 'FontColor';
                    fieldValue = {event.Value};
                    applyDefaultBackgroundToUiColorPicker(app, event.Source)

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
            else
                s = uistyle();
            end

            if ~isempty(s.(fieldName))
                previousValue = s.(fieldName);
                if isequal({previousValue}, fieldValue)
                    return
                end

                removeStyle(clickedTable, previousStyleIndex)
                previouValueIndex = find(cellfun(@(x) isequal(x, previousValue), fieldValue));
                s.(fieldName) = fieldValue{setdiff(1:numel(fieldValue), previouValueIndex)};
            else
                s.(fieldName) = fieldValue{1};
            end

            if evtSource == app.FontIcon
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

        % Display data changed function: UITable1, UITable2
        function TableDisplayDataChanged(app, event)
            
            displayDataIdxs = str2double(event.DisplayRowName);
            if any(isnan(displayDataIdxs))
                return
            end

            clickedTable = event.Source;            
            selectedECD = getSelectedECD(app);            
            tableId = getSelectedTableId(app, clickedTable);
            
            columnName = event.InteractionVariable;
            initialDataIdxs = (1:height(selectedECD.Table.(['x' tableId])))';

            if ~isequal(initialDataIdxs, displayDataIdxs)
                update(selectedECD, 'GUI.TableView.Sort', 'applySort', tableId, columnName, displayDataIdxs)
            else
                update(selectedECD, 'GUI.TableView.Sort', 'clearSort', tableId)
            end
            
        end

        % Image clicked function: StyleDelete, StyleRefresh
        function TableStyleDeleteOrRefresh(app, event)
            
            clickedTable = onFocusTable(app);
            selectedECD = getSelectedECD(app);
            tableId = getSelectedTableId(app, clickedTable);

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
    
                    hTableName  = ui.CustomizationBase.getPropertyName(hTable, app.Context);
                    customEvent = struct('auxAppTag',     app.Context,        ...
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
                ui.Dialog(app.UIFigure, 'error', ME.message);
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

            % Create SubTabGroup
            app.SubTabGroup = uitabgroup(app.GridLayout);
            app.SubTabGroup.AutoResizeChildren = 'off';
            app.SubTabGroup.SelectionChangedFcn = createCallbackFcn(app, @SubTabGroupSelectionChanged, true);
            app.SubTabGroup.Layout.Row = [3 4];
            app.SubTabGroup.Layout.Column = [2 7];

            % Create SubTab1
            app.SubTab1 = uitab(app.SubTabGroup);
            app.SubTab1.AutoResizeChildren = 'off';
            app.SubTab1.Title = 'ASPECTOS GERAIS';
            app.SubTab1.BackgroundColor = 'none';

            % Create SubGrid1
            app.SubGrid1 = uigridlayout(app.SubTab1);
            app.SubGrid1.ColumnWidth = {90, 220, 60, 220, 3, 44, 3, 44, 44, 3, '1x'};
            app.SubGrid1.RowHeight = {22, 22};
            app.SubGrid1.RowSpacing = 5;
            app.SubGrid1.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create CompanyNameListLabel
            app.CompanyNameListLabel = uilabel(app.SubGrid1);
            app.CompanyNameListLabel.FontSize = 10;
            app.CompanyNameListLabel.FontColor = [0.149 0.149 0.149];
            app.CompanyNameListLabel.Layout.Row = 1;
            app.CompanyNameListLabel.Layout.Column = 1;
            app.CompanyNameListLabel.Text = 'EMPRESA:';

            % Create CompanyNameList
            app.CompanyNameList = uidropdown(app.SubGrid1);
            app.CompanyNameList.Items = {};
            app.CompanyNameList.ValueChangedFcn = createCallbackFcn(app, @CompanyNameListValueChanged, true);
            app.CompanyNameList.FontSize = 11;
            app.CompanyNameList.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.CompanyNameList.BackgroundColor = [1 1 1];
            app.CompanyNameList.Layout.Row = 1;
            app.CompanyNameList.Layout.Column = [2 4];
            app.CompanyNameList.Value = {};

            % Create TimePeriodListLabel
            app.TimePeriodListLabel = uilabel(app.SubGrid1);
            app.TimePeriodListLabel.FontSize = 10;
            app.TimePeriodListLabel.FontColor = [0.149 0.149 0.149];
            app.TimePeriodListLabel.Layout.Row = 2;
            app.TimePeriodListLabel.Layout.Column = 1;
            app.TimePeriodListLabel.Text = 'PERÍODO FISCAL:';

            % Create TimePeriodList
            app.TimePeriodList = uidropdown(app.SubGrid1);
            app.TimePeriodList.Items = {};
            app.TimePeriodList.ValueChangedFcn = createCallbackFcn(app, @TimePeriodListValueChanged, true);
            app.TimePeriodList.FontSize = 11;
            app.TimePeriodList.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.TimePeriodList.BackgroundColor = [1 1 1];
            app.TimePeriodList.Layout.Row = 2;
            app.TimePeriodList.Layout.Column = 2;
            app.TimePeriodList.Value = {};

            % Create SheetListLabel
            app.SheetListLabel = uilabel(app.SubGrid1);
            app.SheetListLabel.HorizontalAlignment = 'right';
            app.SheetListLabel.FontSize = 10;
            app.SheetListLabel.FontColor = [0.149 0.149 0.149];
            app.SheetListLabel.Layout.Row = 2;
            app.SheetListLabel.Layout.Column = 3;
            app.SheetListLabel.Text = 'REGISTRO:';

            % Create SheetList
            app.SheetList = uidropdown(app.SubGrid1);
            app.SheetList.Items = {};
            app.SheetList.ValueChangedFcn = createCallbackFcn(app, @SheetViewFirstValueChanged, true);
            app.SheetList.FontSize = 11;
            app.SheetList.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.SheetList.BackgroundColor = [1 1 1];
            app.SheetList.Layout.Row = 2;
            app.SheetList.Layout.Column = 4;
            app.SheetList.Value = {};

            % Create Tab1Separator1
            app.Tab1Separator1 = uiimage(app.SubGrid1);
            app.Tab1Separator1.Enable = 'off';
            app.Tab1Separator1.Layout.Row = [1 2];
            app.Tab1Separator1.Layout.Column = 5;
            app.Tab1Separator1.ImageSource = 'LineV.svg';

            % Create ExportButton
            app.ExportButton = uibutton(app.SubGrid1, 'push');
            app.ExportButton.ButtonPushedFcn = createCallbackFcn(app, @onPopupModuleRequest, true);
            app.ExportButton.Icon = 'Export_24.png';
            app.ExportButton.IconAlignment = 'top';
            app.ExportButton.BackgroundColor = [0.9608 0.9608 0.9608];
            app.ExportButton.FontSize = 10;
            app.ExportButton.Enable = 'off';
            app.ExportButton.Layout.Row = [1 2];
            app.ExportButton.Layout.Column = 6;
            app.ExportButton.Text = 'Exporta';

            % Create Tab1Separator2
            app.Tab1Separator2 = uiimage(app.SubGrid1);
            app.Tab1Separator2.Enable = 'off';
            app.Tab1Separator2.Layout.Row = [1 2];
            app.Tab1Separator2.Layout.Column = 7;
            app.Tab1Separator2.ImageSource = 'LineV.svg';

            % Create MemoryUsageButton
            app.MemoryUsageButton = uibutton(app.SubGrid1, 'push');
            app.MemoryUsageButton.ButtonPushedFcn = createCallbackFcn(app, @onPopupModuleRequest, true);
            app.MemoryUsageButton.Icon = 'pool_60_percent.png';
            app.MemoryUsageButton.IconAlignment = 'top';
            app.MemoryUsageButton.BackgroundColor = [0.9608 0.9608 0.9608];
            app.MemoryUsageButton.FontSize = 10;
            app.MemoryUsageButton.Enable = 'off';
            app.MemoryUsageButton.Layout.Row = [1 2];
            app.MemoryUsageButton.Layout.Column = 8;
            app.MemoryUsageButton.Text = 'Em uso';

            % Create LogButton
            app.LogButton = uibutton(app.SubGrid1, 'push');
            app.LogButton.ButtonPushedFcn = createCallbackFcn(app, @LogButtonPushed, true);
            app.LogButton.Icon = 'LOG_24.png';
            app.LogButton.IconAlignment = 'top';
            app.LogButton.FontSize = 10;
            app.LogButton.Enable = 'off';
            app.LogButton.Layout.Row = [1 2];
            app.LogButton.Layout.Column = 9;
            app.LogButton.Text = 'Análise';

            % Create Tab1Separator3
            app.Tab1Separator3 = uiimage(app.SubGrid1);
            app.Tab1Separator3.Enable = 'off';
            app.Tab1Separator3.Layout.Row = [1 2];
            app.Tab1Separator3.Layout.Column = 10;
            app.Tab1Separator3.ImageSource = 'LineV.svg';

            % Create FinanceFacts
            app.FinanceFacts = uilabel(app.SubGrid1);
            app.FinanceFacts.FontSize = 11;
            app.FinanceFacts.Layout.Row = [1 2];
            app.FinanceFacts.Layout.Column = 11;
            app.FinanceFacts.Interpreter = 'html';
            app.FinanceFacts.Text = '⚠️ Pendente leitura de informação contábil';

            % Create SubTab2
            app.SubTab2 = uitab(app.SubTabGroup);
            app.SubTab2.AutoResizeChildren = 'off';
            app.SubTab2.Title = 'LAYOUT';
            app.SubTab2.BackgroundColor = 'none';

            % Create SubGrid2
            app.SubGrid2 = uigridlayout(app.SubTab2);
            app.SubGrid2.ColumnWidth = {44, 220, 40, 10, 3, 44, 3, 90, 90, 3, 22, 22, 22, 22, 22, 44, 44, 3, 90, '1x', 18, 18};
            app.SubGrid2.RowHeight = {22, 22};
            app.SubGrid2.RowSpacing = 5;
            app.SubGrid2.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create SheetViewStatus
            app.SheetViewStatus = uibutton(app.SubGrid2, 'state');
            app.SheetViewStatus.ValueChangedFcn = createCallbackFcn(app, @SheetViewStatusValueChanged, true);
            app.SheetViewStatus.Icon = 'split_top_bottom_24.png';
            app.SheetViewStatus.IconAlignment = 'top';
            app.SheetViewStatus.Text = 'Tela';
            app.SheetViewStatus.BackgroundColor = [0.9608 0.9608 0.9608];
            app.SheetViewStatus.FontSize = 10;
            app.SheetViewStatus.Layout.Row = [1 2];
            app.SheetViewStatus.Layout.Column = 1;

            % Create SheetView_First
            app.SheetView_First = uidropdown(app.SubGrid2);
            app.SheetView_First.Items = {};
            app.SheetView_First.ValueChangedFcn = createCallbackFcn(app, @SheetViewFirstValueChanged, true);
            app.SheetView_First.FontSize = 11;
            app.SheetView_First.BackgroundColor = [1 1 1];
            app.SheetView_First.Layout.Row = 1;
            app.SheetView_First.Layout.Column = 2;
            app.SheetView_First.Value = {};

            % Create SheetHeight_First
            app.SheetHeight_First = uispinner(app.SubGrid2);
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
            app.SheetView_Second = uidropdown(app.SubGrid2);
            app.SheetView_Second.Items = {};
            app.SheetView_Second.ValueChangedFcn = createCallbackFcn(app, @SheetViewSecondValueChanged, true);
            app.SheetView_Second.Enable = 'off';
            app.SheetView_Second.FontSize = 11;
            app.SheetView_Second.BackgroundColor = [1 1 1];
            app.SheetView_Second.Layout.Row = 2;
            app.SheetView_Second.Layout.Column = 2;
            app.SheetView_Second.Value = {};

            % Create SheetHeight_Second
            app.SheetHeight_Second = uispinner(app.SubGrid2);
            app.SheetHeight_Second.Limits = [0 5];
            app.SheetHeight_Second.RoundFractionalValues = 'on';
            app.SheetHeight_Second.ValueDisplayFormat = '%d';
            app.SheetHeight_Second.ValueChangedFcn = createCallbackFcn(app, @SheetViewHeightValueChanged, true);
            app.SheetHeight_Second.FontSize = 11;
            app.SheetHeight_Second.Enable = 'off';
            app.SheetHeight_Second.Layout.Row = 2;
            app.SheetHeight_Second.Layout.Column = 3;

            % Create SheetOnFocus
            app.SheetOnFocus = uilamp(app.SubGrid2);
            app.SheetOnFocus.Layout.Row = 1;
            app.SheetOnFocus.Layout.Column = 4;
            app.SheetOnFocus.Color = [0.7098 0.8706 1];

            % Create Tab2Separator1
            app.Tab2Separator1 = uiimage(app.SubGrid2);
            app.Tab2Separator1.Enable = 'off';
            app.Tab2Separator1.Layout.Row = [1 2];
            app.Tab2Separator1.Layout.Column = 5;
            app.Tab2Separator1.ImageSource = 'LineV.svg';

            % Create FilterButton
            app.FilterButton = uibutton(app.SubGrid2, 'push');
            app.FilterButton.ButtonPushedFcn = createCallbackFcn(app, @onPopupModuleRequest, true);
            app.FilterButton.Icon = 'Filter_24.png';
            app.FilterButton.IconAlignment = 'top';
            app.FilterButton.FontSize = 10;
            app.FilterButton.Enable = 'off';
            app.FilterButton.Layout.Row = [1 2];
            app.FilterButton.Layout.Column = 6;
            app.FilterButton.Text = 'Filtro';

            % Create Tab2Separator2
            app.Tab2Separator2 = uiimage(app.SubGrid2);
            app.Tab2Separator2.Enable = 'off';
            app.Tab2Separator2.Layout.Row = [1 2];
            app.Tab2Separator2.Layout.Column = 7;
            app.Tab2Separator2.ImageSource = 'LineV.svg';

            % Create RowHeight
            app.RowHeight = uispinner(app.SubGrid2);
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
            app.RowHeightLabel = uilabel(app.SubGrid2);
            app.RowHeightLabel.HorizontalAlignment = 'center';
            app.RowHeightLabel.WordWrap = 'on';
            app.RowHeightLabel.FontSize = 10;
            app.RowHeightLabel.Layout.Row = 2;
            app.RowHeightLabel.Layout.Column = 8;
            app.RowHeightLabel.Text = {'ALTURA LINHA'; '(offset)'};

            % Create ColumnWidth
            app.ColumnWidth = uidropdown(app.SubGrid2);
            app.ColumnWidth.Items = {'', 'auto', 'fit', '1x'};
            app.ColumnWidth.ValueChangedFcn = createCallbackFcn(app, @TableColumnWidthChanged, true);
            app.ColumnWidth.Enable = 'off';
            app.ColumnWidth.FontSize = 11;
            app.ColumnWidth.BackgroundColor = [1 1 1];
            app.ColumnWidth.Layout.Row = 1;
            app.ColumnWidth.Layout.Column = 9;
            app.ColumnWidth.Value = '';

            % Create ColumnWidthLabel
            app.ColumnWidthLabel = uilabel(app.SubGrid2);
            app.ColumnWidthLabel.HorizontalAlignment = 'center';
            app.ColumnWidthLabel.WordWrap = 'on';
            app.ColumnWidthLabel.FontSize = 10;
            app.ColumnWidthLabel.Layout.Row = 2;
            app.ColumnWidthLabel.Layout.Column = 9;
            app.ColumnWidthLabel.Text = {'LARGURA'; 'COLUNA'};

            % Create Tab2Separator3
            app.Tab2Separator3 = uiimage(app.SubGrid2);
            app.Tab2Separator3.Enable = 'off';
            app.Tab2Separator3.Layout.Row = [1 2];
            app.Tab2Separator3.Layout.Column = 10;
            app.Tab2Separator3.ImageSource = 'LineV.svg';

            % Create FontFamily
            app.FontFamily = uidropdown(app.SubGrid2);
            app.FontFamily.Items = {};
            app.FontFamily.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontFamily.Enable = 'off';
            app.FontFamily.FontSize = 11;
            app.FontFamily.BackgroundColor = [1 1 1];
            app.FontFamily.Layout.Row = 1;
            app.FontFamily.Layout.Column = [11 17];
            app.FontFamily.Value = {};

            % Create FontWeight
            app.FontWeight = uibutton(app.SubGrid2, 'push');
            app.FontWeight.ButtonPushedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontWeight.BackgroundColor = [0.9804 0.9804 0.9804];
            app.FontWeight.FontName = 'Century';
            app.FontWeight.FontWeight = 'bold';
            app.FontWeight.Enable = 'off';
            app.FontWeight.Layout.Row = 2;
            app.FontWeight.Layout.Column = 11;
            app.FontWeight.Text = 'B';

            % Create FontStyle
            app.FontStyle = uibutton(app.SubGrid2, 'push');
            app.FontStyle.ButtonPushedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontStyle.BackgroundColor = [0.9804 0.9804 0.9804];
            app.FontStyle.FontName = 'Century';
            app.FontStyle.FontAngle = 'italic';
            app.FontStyle.Enable = 'off';
            app.FontStyle.Layout.Row = 2;
            app.FontStyle.Layout.Column = 12;
            app.FontStyle.Text = 'I ';

            % Create FontAlign1
            app.FontAlign1 = uiimage(app.SubGrid2);
            app.FontAlign1.ScaleMethod = 'none';
            app.FontAlign1.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign1.Enable = 'off';
            app.FontAlign1.Layout.Row = 2;
            app.FontAlign1.Layout.Column = 13;
            app.FontAlign1.ImageSource = 'aligned-left-16px.png';

            % Create FontAlign2
            app.FontAlign2 = uiimage(app.SubGrid2);
            app.FontAlign2.ScaleMethod = 'none';
            app.FontAlign2.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign2.Enable = 'off';
            app.FontAlign2.Layout.Row = 2;
            app.FontAlign2.Layout.Column = 14;
            app.FontAlign2.ImageSource = 'aligned-center-16px.png';

            % Create FontAlign3
            app.FontAlign3 = uiimage(app.SubGrid2);
            app.FontAlign3.ScaleMethod = 'none';
            app.FontAlign3.ImageClickedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontAlign3.Enable = 'off';
            app.FontAlign3.Layout.Row = 2;
            app.FontAlign3.Layout.Column = 15;
            app.FontAlign3.ImageSource = 'aligned-right-16px.png';

            % Create FontBackground
            app.FontBackground = uicolorpicker(app.SubGrid2);
            app.FontBackground.Value = [1 0 0.0118];
            app.FontBackground.Icon = 'fill';
            app.FontBackground.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontBackground.Enable = 'off';
            app.FontBackground.Layout.Row = 2;
            app.FontBackground.Layout.Column = 16;
            app.FontBackground.BackgroundColor = [1 1 1];

            % Create FontColor
            app.FontColor = uicolorpicker(app.SubGrid2);
            app.FontColor.Value = [0 0 0.0118];
            app.FontColor.Icon = 'text';
            app.FontColor.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontColor.Enable = 'off';
            app.FontColor.Layout.Row = 2;
            app.FontColor.Layout.Column = 17;
            app.FontColor.BackgroundColor = [1 1 1];

            % Create Tab2Separator4
            app.Tab2Separator4 = uiimage(app.SubGrid2);
            app.Tab2Separator4.Enable = 'off';
            app.Tab2Separator4.Layout.Row = [1 2];
            app.Tab2Separator4.Layout.Column = 18;
            app.Tab2Separator4.ImageSource = 'LineV.svg';

            % Create FontIcon
            app.FontIcon = uidropdown(app.SubGrid2);
            app.FontIcon.Items = {'', 'question', 'info', 'success', 'warning', 'error', 'none'};
            app.FontIcon.ValueChangedFcn = createCallbackFcn(app, @TableStyleChanged, true);
            app.FontIcon.Enable = 'off';
            app.FontIcon.FontSize = 11;
            app.FontIcon.BackgroundColor = [1 1 1];
            app.FontIcon.Layout.Row = 1;
            app.FontIcon.Layout.Column = 19;
            app.FontIcon.Value = '';

            % Create FontIconLabel
            app.FontIconLabel = uilabel(app.SubGrid2);
            app.FontIconLabel.HorizontalAlignment = 'center';
            app.FontIconLabel.WordWrap = 'on';
            app.FontIconLabel.FontSize = 10;
            app.FontIconLabel.Layout.Row = 2;
            app.FontIconLabel.Layout.Column = 19;
            app.FontIconLabel.Text = 'ÍCONE';

            % Create StyleDelete
            app.StyleDelete = uiimage(app.SubGrid2);
            app.StyleDelete.ScaleMethod = 'none';
            app.StyleDelete.ImageClickedFcn = createCallbackFcn(app, @TableStyleDeleteOrRefresh, true);
            app.StyleDelete.Enable = 'off';
            app.StyleDelete.Layout.Row = 2;
            app.StyleDelete.Layout.Column = 21;
            app.StyleDelete.ImageSource = 'clear_all_outputs_16-3d3c482971dfdb6852db717989f585fa.png';

            % Create StyleRefresh
            app.StyleRefresh = uiimage(app.SubGrid2);
            app.StyleRefresh.ScaleMethod = 'none';
            app.StyleRefresh.ImageClickedFcn = createCallbackFcn(app, @TableStyleDeleteOrRefresh, true);
            app.StyleRefresh.Enable = 'off';
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
            app.UITable1.DisplayDataChangedFcn = createCallbackFcn(app, @TableDisplayDataChanged, true);
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
            app.UITable2.DisplayDataChangedFcn = createCallbackFcn(app, @TableDisplayDataChanged, true);
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
            app.Toolbar.ColumnWidth = {22, 5, 22, 22, 22, 5, '1x', 22, 22, 22};
            app.Toolbar.RowHeight = {4, 17, 2};
            app.Toolbar.ColumnSpacing = 5;
            app.Toolbar.RowSpacing = 0;
            app.Toolbar.Padding = [10 5 10 5];
            app.Toolbar.Layout.Row = 14;
            app.Toolbar.Layout.Column = [1 9];
            app.Toolbar.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create tool_OpenPopupIcmsRate
            app.tool_OpenPopupIcmsRate = uiimage(app.Toolbar);
            app.tool_OpenPopupIcmsRate.ScaleMethod = 'none';
            app.tool_OpenPopupIcmsRate.ImageClickedFcn = createCallbackFcn(app, @Toolbar_OpenPopupAppImageClicked, true);
            app.tool_OpenPopupIcmsRate.Enable = 'off';
            app.tool_OpenPopupIcmsRate.Layout.Row = [1 3];
            app.tool_OpenPopupIcmsRate.Layout.Column = 1;
            app.tool_OpenPopupIcmsRate.ImageSource = 'percentage-20px.svg';

            % Create tool_Separator1
            app.tool_Separator1 = uiimage(app.Toolbar);
            app.tool_Separator1.ScaleMethod = 'none';
            app.tool_Separator1.Enable = 'off';
            app.tool_Separator1.Layout.Row = [1 3];
            app.tool_Separator1.Layout.Column = 2;
            app.tool_Separator1.ImageSource = 'LineV.svg';

            % Create tool_AccountButton
            app.tool_AccountButton = uiimage(app.Toolbar);
            app.tool_AccountButton.ScaleMethod = 'none';
            app.tool_AccountButton.ImageClickedFcn = createCallbackFcn(app, @onPopupModuleRequest, true);
            app.tool_AccountButton.Enable = 'off';
            app.tool_AccountButton.Layout.Row = [1 3];
            app.tool_AccountButton.Layout.Column = 3;
            app.tool_AccountButton.ImageSource = 'Variable_edit_16.png';

            % Create tool_AutoFill
            app.tool_AutoFill = uiimage(app.Toolbar);
            app.tool_AutoFill.ScaleMethod = 'fill';
            app.tool_AutoFill.ImageClickedFcn = createCallbackFcn(app, @Toolbar_AutoFillImageClicked, true);
            app.tool_AutoFill.Enable = 'off';
            app.tool_AutoFill.Layout.Row = [1 3];
            app.tool_AutoFill.Layout.Column = 4;
            app.tool_AutoFill.ImageSource = 'AutoFill_36Blue.png';

            % Create tool_DeleteAnnotation
            app.tool_DeleteAnnotation = uiimage(app.Toolbar);
            app.tool_DeleteAnnotation.ScaleMethod = 'fill';
            app.tool_DeleteAnnotation.ImageClickedFcn = createCallbackFcn(app, @Toolbar_DeleteAnnotationImageClicked, true);
            app.tool_DeleteAnnotation.Enable = 'off';
            app.tool_DeleteAnnotation.Layout.Row = [1 3];
            app.tool_DeleteAnnotation.Layout.Column = 5;
            app.tool_DeleteAnnotation.ImageSource = 'delete-annotation-36px.png';

            % Create tool_Separator2
            app.tool_Separator2 = uiimage(app.Toolbar);
            app.tool_Separator2.ScaleMethod = 'none';
            app.tool_Separator2.Enable = 'off';
            app.tool_Separator2.Visible = 'off';
            app.tool_Separator2.Layout.Row = [1 3];
            app.tool_Separator2.Layout.Column = 6;
            app.tool_Separator2.ImageSource = 'LineV.svg';

            % Create tool_CompanyInfo
            app.tool_CompanyInfo = uilabel(app.Toolbar);
            app.tool_CompanyInfo.VerticalAlignment = 'top';
            app.tool_CompanyInfo.WordWrap = 'on';
            app.tool_CompanyInfo.FontSize = 9;
            app.tool_CompanyInfo.FontColor = [0.149 0.149 0.149];
            app.tool_CompanyInfo.Layout.Row = [1 3];
            app.tool_CompanyInfo.Layout.Column = 7;
            app.tool_CompanyInfo.Interpreter = 'html';
            app.tool_CompanyInfo.Text = '';

            % Create tool_OpenPopupProject
            app.tool_OpenPopupProject = uiimage(app.Toolbar);
            app.tool_OpenPopupProject.ScaleMethod = 'none';
            app.tool_OpenPopupProject.ImageClickedFcn = createCallbackFcn(app, @Toolbar_OpenPopupAppImageClicked, true);
            app.tool_OpenPopupProject.Layout.Row = [1 3];
            app.tool_OpenPopupProject.Layout.Column = 8;
            app.tool_OpenPopupProject.ImageSource = 'organization-20px-black.svg';

            % Create tool_GenerateReport
            app.tool_GenerateReport = uiimage(app.Toolbar);
            app.tool_GenerateReport.ScaleMethod = 'none';
            app.tool_GenerateReport.ImageClickedFcn = createCallbackFcn(app, @Toolbar_ReportImageClicked, true);
            app.tool_GenerateReport.Enable = 'off';
            app.tool_GenerateReport.Layout.Row = [1 3];
            app.tool_GenerateReport.Layout.Column = 9;
            app.tool_GenerateReport.ImageSource = 'Publish_HTML_16.png';

            % Create tool_UploadFinalFile
            app.tool_UploadFinalFile = uiimage(app.Toolbar);
            app.tool_UploadFinalFile.ScaleMethod = 'none';
            app.tool_UploadFinalFile.ImageClickedFcn = createCallbackFcn(app, @Toolbar_UploadFinalFileImageClicked, true);
            app.tool_UploadFinalFile.Enable = 'off';
            app.tool_UploadFinalFile.Layout.Row = [1 3];
            app.tool_UploadFinalFile.Layout.Column = 10;
            app.tool_UploadFinalFile.ImageSource = 'up-20px.png';

            % Create DockModule
            app.DockModule = uigridlayout(app.GridLayout);
            app.DockModule.RowHeight = {'1x'};
            app.DockModule.ColumnSpacing = 2;
            app.DockModule.Padding = [5 2 5 2];
            app.DockModule.Visible = 'off';
            app.DockModule.Layout.Row = [2 3];
            app.DockModule.Layout.Column = [6 8];
            app.DockModule.BackgroundColor = [0.2 0.2 0.2];

            % Create dockModule_Undock
            app.dockModule_Undock = uiimage(app.DockModule);
            app.dockModule_Undock.ScaleMethod = 'none';
            app.dockModule_Undock.ImageClickedFcn = createCallbackFcn(app, @DockModuleGroup_ButtonPushed, true);
            app.dockModule_Undock.Enable = 'off';
            app.dockModule_Undock.Layout.Row = 1;
            app.dockModule_Undock.Layout.Column = 1;
            app.dockModule_Undock.ImageSource = 'Undock_18White.png';

            % Create dockModule_Close
            app.dockModule_Close = uiimage(app.DockModule);
            app.dockModule_Close.ScaleMethod = 'none';
            app.dockModule_Close.ImageClickedFcn = createCallbackFcn(app, @DockModuleGroup_ButtonPushed, true);
            app.dockModule_Close.Layout.Row = 1;
            app.dockModule_Close.Layout.Column = 2;
            app.dockModule_Close.ImageSource = 'Delete_12SVG_white.svg';

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
