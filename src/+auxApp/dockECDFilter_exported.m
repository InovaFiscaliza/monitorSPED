classdef dockECDFilter_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        GridLayout              matlab.ui.container.GridLayout
        Document                matlab.ui.container.GridLayout
        SpecificationLabel      matlab.ui.control.Label
        SpecificationPanel      matlab.ui.container.Panel
        SpecificationGrid       matlab.ui.container.GridLayout
        columnFilterList        matlab.ui.container.CheckBoxTree
        columnFilterAdd         matlab.ui.control.Image
        value2_TextFree         matlab.ui.control.EditField
        value2_TextList         matlab.ui.control.DropDown
        value2_Numeric          matlab.ui.control.NumericEditField
        value2_Date             matlab.ui.control.DatePicker
        operation2_List         matlab.ui.control.DropDown
        operation2_LogicalGrid  matlab.ui.container.ButtonGroup
        operation2_LogicalOr    matlab.ui.control.RadioButton
        operation2_LogicalAnd   matlab.ui.control.RadioButton
        value1_TextFree         matlab.ui.control.EditField
        value1_TextList         matlab.ui.control.DropDown
        value1_Numeric          matlab.ui.control.NumericEditField
        value1_Date             matlab.ui.control.DatePicker
        operation1_List         matlab.ui.control.DropDown
        symbolicNameList        matlab.ui.control.DropDown
        TableIdList             matlab.ui.control.DropDown
        TableIdLabel            matlab.ui.control.Label
        btnClose                matlab.ui.control.Image
        ContextMenu             matlab.ui.container.ContextMenu
        ExcluirMenu             matlab.ui.container.Menu
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
    end


    properties (Access = private)
        %-----------------------------------------------------------------%
        inputArgs
        ecdObj
    end
    
    
    methods (Access = private)
        %-----------------------------------------------------------------%
        function updateForm(app, index, tableId)
            tableIdData    = app.ecdObj(index).Table.(['x' tableId]);

            % DROPDOWN "COLUNAS"
            columnRawNames = tableIdData.Properties.VariableNames;
            columnRawTypes = matlab.Compatibility.resolveTableVariableTypes(tableIdData);

            [columnNames, sortedIdxs] = textAnalysis.sort(columnRawNames);
            columnTypes   = columnRawTypes(sortedIdxs);
            
            pseudoClasses = tableFiltering.getPseudoClasses(columnTypes);
            symbolicNames = tableFiltering.mergedSymbolWithColumnNames(columnNames, columnTypes);
            
            % Atualiza componente dropdown com os nomes símbolicos das
            % colunas, além de armazenar em "UserData" detalhes sobre os
            % tipos de dados (nome, tipo e pseudo classe de cada coluna).
            app.symbolicNameList.Items = [{''}; symbolicNames'];
            
            app.symbolicNameList.UserData.columnNames   = columnNames;
            app.symbolicNameList.UserData.columnTypes   = columnTypes;
            app.symbolicNameList.UserData.pseudoClasses = pseudoClasses;

            updateTree(app, index, tableId)
        end

        %-----------------------------------------------------------------%
        function restartState(app)
            % O componente de INPUT do valor do filtro pode ser uidatepicker,
            % uieditfield (numeric/text) ou uidropdown, a depender da pseudo 
            % classe da coluna. Guarda-se um handle p/ o elemento ativo.
            app.operation1_List.UserData.inputHandle = [];
            app.operation2_List.UserData.inputHandle = [];
        end

        %-----------------------------------------------------------------%
        function updateTree(app, index, tableId)
            if ~isempty(app.columnFilterList.Children)
                delete(app.columnFilterList.Children)
            end

            selectedECD = app.ecdObj(index);
            [filterIndex, filterStatus] = findCustomTableFilter(app, selectedECD, tableId, 'basic');

            if filterStatus
                filterObj    = selectedECD.GUI.tableView(filterIndex).filter;
                filterList   = getFilterList(filterObj, ['ECD.x' tableId]);
                checkedNodes = [];

                for ii = 1:numel(filterList)
                    childNode = uitreenode(app.columnFilterList, 'Text', filterList{ii}, 'NodeData', ii);

                    if filterObj.filterRules.Enable(ii)
                        checkedNodes = [checkedNodes, childNode];
                    end
                end

                app.columnFilterList.CheckedNodes = checkedNodes;
            end
        end

        %-----------------------------------------------------------------%
        function [index, status] = findCustomTableFilter(app, selectedECD, tableId, statusType)
            arguments
                app
                selectedECD
                tableId
                statusType char {mustBeMember(statusType, {'basic', 'active'})}
            end

            index  = find(strcmp({selectedECD.GUI.tableView.id}, tableId), 1);
            status = ~isempty(index) && ~isempty(selectedECD.GUI.tableView(index).filter);

            if strcmp(statusType, 'active')
                status = status && any(selectedECD.GUI.tableView(index).filter.filterRules.Enable);
            end
        end

        %-----------------------------------------------------------------%
        function [columName, pseudoClass] = inspectColumnData(app)
            symbolicName = app.symbolicNameList.Value;
            [~, symbolicIndex] = ismember(symbolicName, app.symbolicNameList.Items);
            columnIndex = symbolicIndex-1;

            if columnIndex == 0
                columName   = '';
                pseudoClass = '';
            else
                columName   = app.symbolicNameList.UserData.columnNames{columnIndex};
                pseudoClass = app.symbolicNameList.UserData.pseudoClasses{columnIndex};
            end
        end

        %-----------------------------------------------------------------%
        function validateAndAddTableFilter(app)
            selectedECD  = app.ecdObj(app.inputArgs.index);
            tableId      = app.TableIdList.Value;
            
            [filterIndex, filterStatus] = findCustomTableFilter(app, selectedECD, tableId, 'basic');

            if isempty(filterIndex)
                filterIndex = numel(selectedECD.GUI.tableView) + 1;
            end

            if ~filterStatus
                update(selectedECD, 'GUI.TableView.Filter', 'createFilteringObject', tableId, filterIndex)
            end

            fieldName = app.symbolicNameList.Value;            
            operators = {app.operation1_List.Value};
            values    = {app.operation1_List.UserData.inputHandle.Value};
            connector = app.operation2_LogicalGrid.SelectedObject.Text;

            if ~isempty(app.operation2_List.Value) && (~strcmp(app.operation1_List.Value, app.operation2_List.Value) || ~isequal(app.operation1_List.UserData.inputHandle.Value, app.operation2_List.UserData.inputHandle.Value))
                operators = [operators, {app.operation2_List.Value}];
                values    = [values, {app.operation2_List.UserData.inputHandle.Value}];
            end

            addFilterRule(selectedECD.GUI.tableView(filterIndex).filter, fieldName, operators, values, connector)
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, callingApp, context, index, tableIdList, selectedTableId)
            
            try
                appEngine.boot(app, app.Role, mainApp, callingApp)

                app.inputArgs = struct('context', context, 'index', index);
                app.ecdObj = mainApp.ecdObj;

                set(app.TableIdList, 'Items', tableIdList, 'Value', selectedTableId)
                onTableIdValueChanged(app)

            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME), 'CloseFcn', @(~,~)closeFcn(app));
            end
            
        end

        % Callback function: UIFigure, btnClose
        function closeFcn(app, event)
            
            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcnCallFromPopupApp', context, 'auxApp.dockECDFilter')

            delete(app)
            
        end

        % Value changed function: TableIdList
        function onTableIdValueChanged(app, event)
            
            index = app.inputArgs.index;
            tableId = app.TableIdList.Value;

            if ~isfield(app.ecdObj(index).Table, ['x' tableId])
                context = app.inputArgs.context;
                ipcMainMatlabCallsHandler(app.mainApp, app, 'onTableReadRequired', context, tableId)
            end

            updateForm(app, index, tableId)
            onFilterColumnChanged(app)
            
        end

        % Value changed function: symbolicNameList
        function onFilterColumnChanged(app, event)

            restartState(app)

            [columnName, pseudoClass] = inspectColumnData(app);
            app.symbolicNameList.UserData.selected = struct('columnName', columnName, 'pseudoClass', pseudoClass);

            if isempty(pseudoClass)
                operations = {};
            else
                operations = tableFiltering.getFilterCapabilities(pseudoClass);
            end
            
            app.operation1_List.Items = operations;
            set(app.operation2_List, 'Items', [{''}, operations], 'Value', '')

            if ~isempty(operations)
                app.operation1_List.Value = app.operation1_List.Items{1};
                onFilterOperatorChanged(app, struct('Source', app.operation1_List))
                onFilterOperatorChanged(app, struct('Source', app.operation2_List))
            end

            app.columnFilterAdd.Enable = ~isempty(operations);
            
        end

        % Value changed function: operation1_List, operation2_List
        function onFilterOperatorChanged(app, event)

            switch event.Source
                case app.operation1_List
                    valueHandles = [ ...
                        app.value1_Date, ...
                        app.value1_Numeric, ...
                        app.value1_TextFree, ...
                        app.value1_TextList ...
                    ];
                    
                case app.operation2_List
                    valueHandles = [ ...
                        app.value2_Date, ...
                        app.value2_Numeric, ...
                        app.value2_TextFree, ...
                        app.value2_TextList ...
                    ];
            end
            tagHandles  = arrayfun(@(x) x.Tag, valueHandles, 'UniformOutput', false);

            columnName  = app.symbolicNameList.UserData.selected.columnName;
            pseudoClass = app.symbolicNameList.UserData.selected.pseudoClass;
            categories  = getCategories(app, columnName);

            switch pseudoClass
                case 'cellstr'
                    [~, tagIndex] = ismember('textFree', tagHandles);
                  % optionalArgs  = {'Value', ''};
                    optionalArgs  = {};

                case 'numeric'
                    [~, tagIndex] = ismember('numeric', tagHandles);
                    optionalArgs  = {};

                case 'datetime'
                    [~, tagIndex] = ismember('datePicker', tagHandles);
                    optionalArgs  = {};

                case 'categorical'
                    % Se a coluna tiver mais de 500 categorias, apresenta-se 
                    % como uieditfield (text) ao invés de dropdown.
                    if isempty(categories)
                        [~, tagIndex] = ismember('textFree', tagHandles);
                        optionalArgs  = {};
                    else
                        [~, tagIndex] = ismember('textList', tagHandles);
                        optionalArgs  = {'Items', [{''}; categories]};
                    end
            end

            event.Source.UserData.inputHandle = valueHandles(tagIndex);
            set(valueHandles(tagIndex), 'Visible', 1, optionalArgs{:})
            set(setdiff(valueHandles, valueHandles(tagIndex)), 'Visible', 0)

        end

        % Image clicked function: columnFilterAdd
        function onFilterAddImageClicked(app, event)
            
            columnName = app.symbolicNameList.UserData.selected.columnName;            
            operators  = {app.operation1_List.Value};
            values     = {app.operation1_List.UserData.inputHandle.Value};
            connector  = app.operation2_LogicalGrid.SelectedObject.Text;

            if ~isempty(app.operation2_List.Value) && (~strcmp(app.operation1_List.Value, app.operation2_List.Value) || ~isequal(app.operation1_List.UserData.inputHandle.Value, app.operation2_List.UserData.inputHandle.Value))
                operators = [operators, {app.operation2_List.Value}];
                values    = [values, {app.operation2_List.UserData.inputHandle.Value}];
            end

            try
                addFilterRule(app.mainApp.filteringObj, columnName, operators, values, connector);
            catch ME
                ui.Dialog(app.UIFigure, 'warning', ME.message);
                return
            end
            updateTree(app)

            ipcMainMatlabCallsHandler(app.mainApp, app, 'onColumnFilterChanged')



            try
                validateAndAddTableFilter(app)
                updateTree(app)
                
                context = app.inputArgs.context;
                tableId = app.TableIdList.Value;
                ipcMainMatlabCallsHandler(app.mainApp, app, 'onFilterChanged', context, tableId)

            catch ME
                ui.Dialog(app.UIFigure, 'error', ME.message);
            end

        end

        % Menu selected function: ExcluirMenu
        function onFilterDelImageClicked(app, event)
            
            selectedNodes = app.columnFilterList.SelectedNodes;

            if ~isempty(selectedNodes)
                selectedECD = app.ecdObj(app.inputArgs.index);
                tableId     = app.TableIdList.Value;

                [filterIndex, filterStatus] = findCustomTableFilter(app, selectedECD, tableId, 'basic');
    
                if filterStatus
                    filterObj = selectedECD.GUI.tableView(filterIndex).filter;
                    removeFilterRule(filterObj, [selectedNodes.NodeData])
                    updateTree(app)

                    context = app.inputArgs.context;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'onFilterChanged', context, tableId)
                end
            end

        end

        % Callback function: columnFilterList
        function onColumnFilterCheckedNodesChanged(app, event)
            
            selectedECD = app.ecdObj(app.inputArgs.index);
            tableId     = app.TableIdList.Value;

            [filterIndex, filterStatus] = findCustomTableFilter(app, selectedECD, tableId, 'basic');
    
            if filterStatus
                filterObj = selectedECD.GUI.tableView(filterIndex).filter;

                checkedNodes = [];            
                if ~isempty(app.columnFilterList.CheckedNodes)
                    checkedNodes = [app.columnFilterList.CheckedNodes.NodeData];
                end

                initialEnableArray = filterObj.filterRules.Enable;
                currentEnableArray = zeros(height(initialEnableArray), 1, 'logical');
                if ~isempty(checkedNodes)
                    currentEnableArray(checkedNodes) = true;
                end

                if ~isequal(initialEnableArray, currentEnableArray)
                    toogleFilterRule(filterObj, currentEnableArray)

                    context = app.inputArgs.context;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'onFilterChanged', context, tableId)
                end
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
                app.UIFigure.Position = [100 100 518 376];
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
            app.Document.ColumnWidth = {'1x', 63, 22};
            app.Document.RowHeight = {17, 22, 22, '1x'};
            app.Document.ColumnSpacing = 5;
            app.Document.RowSpacing = 5;
            app.Document.Padding = [10 10 10 5];
            app.Document.Layout.Row = 2;
            app.Document.Layout.Column = [1 2];
            app.Document.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create TableIdLabel
            app.TableIdLabel = uilabel(app.Document);
            app.TableIdLabel.VerticalAlignment = 'bottom';
            app.TableIdLabel.FontSize = 10;
            app.TableIdLabel.Layout.Row = 1;
            app.TableIdLabel.Layout.Column = [1 3];
            app.TableIdLabel.Text = 'REGISTRO';

            % Create TableIdList
            app.TableIdList = uidropdown(app.Document);
            app.TableIdList.Items = {};
            app.TableIdList.ValueChangedFcn = createCallbackFcn(app, @onTableIdValueChanged, true);
            app.TableIdList.FontSize = 11;
            app.TableIdList.BackgroundColor = [1 1 1];
            app.TableIdList.Layout.Row = 2;
            app.TableIdList.Layout.Column = [1 3];
            app.TableIdList.Value = {};

            % Create SpecificationPanel
            app.SpecificationPanel = uipanel(app.Document);
            app.SpecificationPanel.Layout.Row = 4;
            app.SpecificationPanel.Layout.Column = [1 3];

            % Create SpecificationGrid
            app.SpecificationGrid = uigridlayout(app.SpecificationPanel);
            app.SpecificationGrid.ColumnWidth = {130, '1x', 22};
            app.SpecificationGrid.RowHeight = {22, 22, 22, 22, 18, '1x'};
            app.SpecificationGrid.ColumnSpacing = 5;
            app.SpecificationGrid.RowSpacing = 5;
            app.SpecificationGrid.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create symbolicNameList
            app.symbolicNameList = uidropdown(app.SpecificationGrid);
            app.symbolicNameList.Items = {};
            app.symbolicNameList.ValueChangedFcn = createCallbackFcn(app, @onFilterColumnChanged, true);
            app.symbolicNameList.FontSize = 11;
            app.symbolicNameList.BackgroundColor = [1 1 1];
            app.symbolicNameList.Layout.Row = 1;
            app.symbolicNameList.Layout.Column = [1 3];
            app.symbolicNameList.Value = {};

            % Create operation1_List
            app.operation1_List = uidropdown(app.SpecificationGrid);
            app.operation1_List.Items = {};
            app.operation1_List.ValueChangedFcn = createCallbackFcn(app, @onFilterOperatorChanged, true);
            app.operation1_List.FontSize = 11;
            app.operation1_List.BackgroundColor = [1 1 1];
            app.operation1_List.Layout.Row = 2;
            app.operation1_List.Layout.Column = 1;
            app.operation1_List.Value = {};

            % Create value1_Date
            app.value1_Date = uidatepicker(app.SpecificationGrid);
            app.value1_Date.Editable = 'off';
            app.value1_Date.Tag = 'datePicker';
            app.value1_Date.FontSize = 11;
            app.value1_Date.BackgroundColor = [0.9804 0.9804 0.9804];
            app.value1_Date.Visible = 'off';
            app.value1_Date.Layout.Row = 2;
            app.value1_Date.Layout.Column = [2 3];

            % Create value1_Numeric
            app.value1_Numeric = uieditfield(app.SpecificationGrid, 'numeric');
            app.value1_Numeric.AllowEmpty = 'on';
            app.value1_Numeric.Tag = 'numeric';
            app.value1_Numeric.FontSize = 11;
            app.value1_Numeric.Visible = 'off';
            app.value1_Numeric.Layout.Row = 2;
            app.value1_Numeric.Layout.Column = [2 3];
            app.value1_Numeric.Value = [];

            % Create value1_TextList
            app.value1_TextList = uidropdown(app.SpecificationGrid);
            app.value1_TextList.Items = {''};
            app.value1_TextList.Editable = 'on';
            app.value1_TextList.Tag = 'textList';
            app.value1_TextList.Visible = 'off';
            app.value1_TextList.FontSize = 11;
            app.value1_TextList.BackgroundColor = [1 1 1];
            app.value1_TextList.Layout.Row = 2;
            app.value1_TextList.Layout.Column = [2 3];
            app.value1_TextList.Value = '';

            % Create value1_TextFree
            app.value1_TextFree = uieditfield(app.SpecificationGrid, 'text');
            app.value1_TextFree.Tag = 'textFree';
            app.value1_TextFree.FontSize = 11;
            app.value1_TextFree.FontColor = [0.149 0.149 0.149];
            app.value1_TextFree.Layout.Row = 2;
            app.value1_TextFree.Layout.Column = [2 3];

            % Create operation2_LogicalGrid
            app.operation2_LogicalGrid = uibuttongroup(app.SpecificationGrid);
            app.operation2_LogicalGrid.AutoResizeChildren = 'off';
            app.operation2_LogicalGrid.BorderType = 'none';
            app.operation2_LogicalGrid.BackgroundColor = [0.9804 0.9804 0.9804];
            app.operation2_LogicalGrid.Layout.Row = 3;
            app.operation2_LogicalGrid.Layout.Column = 1;

            % Create operation2_LogicalAnd
            app.operation2_LogicalAnd = uiradiobutton(app.operation2_LogicalGrid);
            app.operation2_LogicalAnd.Text = 'And';
            app.operation2_LogicalAnd.FontSize = 11;
            app.operation2_LogicalAnd.Position = [20 1 51 22];
            app.operation2_LogicalAnd.Value = true;

            % Create operation2_LogicalOr
            app.operation2_LogicalOr = uiradiobutton(app.operation2_LogicalGrid);
            app.operation2_LogicalOr.Text = 'Or';
            app.operation2_LogicalOr.FontSize = 11;
            app.operation2_LogicalOr.Position = [79 1 50 22];

            % Create operation2_List
            app.operation2_List = uidropdown(app.SpecificationGrid);
            app.operation2_List.Items = {};
            app.operation2_List.ValueChangedFcn = createCallbackFcn(app, @onFilterOperatorChanged, true);
            app.operation2_List.FontSize = 11;
            app.operation2_List.BackgroundColor = [1 1 1];
            app.operation2_List.Layout.Row = 4;
            app.operation2_List.Layout.Column = 1;
            app.operation2_List.Value = {};

            % Create value2_Date
            app.value2_Date = uidatepicker(app.SpecificationGrid);
            app.value2_Date.Editable = 'off';
            app.value2_Date.Tag = 'datePicker';
            app.value2_Date.FontSize = 11;
            app.value2_Date.BackgroundColor = [0.9804 0.9804 0.9804];
            app.value2_Date.Visible = 'off';
            app.value2_Date.Layout.Row = 4;
            app.value2_Date.Layout.Column = [2 3];

            % Create value2_Numeric
            app.value2_Numeric = uieditfield(app.SpecificationGrid, 'numeric');
            app.value2_Numeric.AllowEmpty = 'on';
            app.value2_Numeric.Tag = 'numeric';
            app.value2_Numeric.FontSize = 11;
            app.value2_Numeric.Visible = 'off';
            app.value2_Numeric.Layout.Row = 4;
            app.value2_Numeric.Layout.Column = [2 3];
            app.value2_Numeric.Value = [];

            % Create value2_TextList
            app.value2_TextList = uidropdown(app.SpecificationGrid);
            app.value2_TextList.Items = {''};
            app.value2_TextList.Editable = 'on';
            app.value2_TextList.Tag = 'textList';
            app.value2_TextList.Visible = 'off';
            app.value2_TextList.FontSize = 11;
            app.value2_TextList.BackgroundColor = [1 1 1];
            app.value2_TextList.Layout.Row = 4;
            app.value2_TextList.Layout.Column = [2 3];
            app.value2_TextList.Value = '';

            % Create value2_TextFree
            app.value2_TextFree = uieditfield(app.SpecificationGrid, 'text');
            app.value2_TextFree.Tag = 'textFree';
            app.value2_TextFree.FontSize = 11;
            app.value2_TextFree.FontColor = [0.149 0.149 0.149];
            app.value2_TextFree.Layout.Row = 4;
            app.value2_TextFree.Layout.Column = [2 3];

            % Create columnFilterAdd
            app.columnFilterAdd = uiimage(app.SpecificationGrid);
            app.columnFilterAdd.ScaleMethod = 'none';
            app.columnFilterAdd.ImageClickedFcn = createCallbackFcn(app, @onFilterAddImageClicked, true);
            app.columnFilterAdd.Enable = 'off';
            app.columnFilterAdd.Layout.Row = 5;
            app.columnFilterAdd.Layout.Column = 3;
            app.columnFilterAdd.ImageSource = 'Add_16.png';

            % Create columnFilterList
            app.columnFilterList = uitree(app.SpecificationGrid, 'checkbox');
            app.columnFilterList.FontSize = 11;
            app.columnFilterList.Layout.Row = 6;
            app.columnFilterList.Layout.Column = [1 3];

            % Assign Checked Nodes
            app.columnFilterList.CheckedNodesChangedFcn = createCallbackFcn(app, @onColumnFilterCheckedNodesChanged, true);

            % Create SpecificationLabel
            app.SpecificationLabel = uilabel(app.Document);
            app.SpecificationLabel.VerticalAlignment = 'bottom';
            app.SpecificationLabel.FontSize = 10;
            app.SpecificationLabel.Layout.Row = 3;
            app.SpecificationLabel.Layout.Column = 1;
            app.SpecificationLabel.Text = 'FILTRO POR COLUNA';

            % Create ContextMenu
            app.ContextMenu = uicontextmenu(app.UIFigure);
            app.ContextMenu.Tag = 'auxApp.dockECDFilter';

            % Create ExcluirMenu
            app.ExcluirMenu = uimenu(app.ContextMenu);
            app.ExcluirMenu.MenuSelectedFcn = createCallbackFcn(app, @onFilterDelImageClicked, true);
            app.ExcluirMenu.Text = '❌ Excluir';
            
            % Assign app.ContextMenu
            app.columnFilterList.ContextMenu = app.ContextMenu;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = dockECDFilter_exported(Container, varargin)

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
