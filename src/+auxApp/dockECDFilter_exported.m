classdef dockECDFilter_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                  matlab.ui.Figure
        GridLayout                matlab.ui.container.GridLayout
        Document                  matlab.ui.container.GridLayout
        Tree                      matlab.ui.container.CheckBoxTree
        SpecificationPanel        matlab.ui.container.Panel
        SpecificationGrid         matlab.ui.container.GridLayout
        value2_TextFree           matlab.ui.control.EditField
        value2_TextList           matlab.ui.control.DropDown
        value2_Numeric            matlab.ui.control.NumericEditField
        value2_Date               matlab.ui.control.DatePicker
        operation2_List           matlab.ui.control.DropDown
        operation2_LogicalGrid    matlab.ui.container.ButtonGroup
        operation2_LogicalOr      matlab.ui.control.RadioButton
        operation2_LogicalAnd     matlab.ui.control.RadioButton
        value1_TextFree           matlab.ui.control.EditField
        value1_TextList           matlab.ui.control.DropDown
        value1_Numeric            matlab.ui.control.NumericEditField
        value1_Date               matlab.ui.control.DatePicker
        operation1_List           matlab.ui.control.DropDown
        ColumnClass               matlab.ui.control.Label
        ColumnList                matlab.ui.control.DropDown
        SpecificationControlGrid  matlab.ui.container.GridLayout
        CancelNewFilter           matlab.ui.control.Image
        ConfirmNewFilter          matlab.ui.control.Image
        AddNewFilter              matlab.ui.control.Image
        SpecificationLabel        matlab.ui.control.Label
        TableIdList               matlab.ui.control.DropDown
        TableIdLabel              matlab.ui.control.Label
        btnClose                  matlab.ui.control.Image
        ContextMenu               matlab.ui.container.ContextMenu
        ExcluirMenu               matlab.ui.container.Menu
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        Container
        isDocked = true

        mainApp
        callingApp
        ecdObj

        inputArgs
    end
    
    
    methods (Access = private)
        %-----------------------------------------------------------------%
        function initialLayout(app, tableIdList, selectedTableId)
            app.AddNewFilter.UserData    = false;
            app.ColumnList.UserData      = struct('class', '', 'array', []);
            app.operation1_List.UserData = struct('inputHandle', []);
            app.operation2_List.UserData = struct('inputHandle', []);

            set(app.TableIdList, 'Items', tableIdList, 'Value', selectedTableId)
            TableIdListValueChanged(app)
        end

        %-----------------------------------------------------------------%
        function [columnClass, columnArray] = checkFilterType(app)
            if isempty(app.ColumnList.UserData.class)
                index       = app.inputArgs.index;
                tableId     = app.TableIdList.Value;
                columName   = app.ColumnList.Value;
                columnArray = app.ecdObj(index).Table.(['x' tableId]).(columName);
    
                % De forma geral, os dados dos registros ordinários da ECD se
                % restringem a "double", "cell" ou "datetime". As tabelas criadas 
                % pelo app - balancetes, contas e tabela de apuração - incluem
                % "double", "categorical" e "cell".
    
                if iscellstr(columnArray)
                    columnClass = 'cellstr';
                elseif isnumeric(columnArray)
                    columnClass = 'numeric';
                elseif isdatetime(columnArray)
                    columnClass = 'datetime';
                elseif iscategorical(columnArray)
                    columnClass = 'categorical';
                else
                    error('UnexpectedDataType')
                end
    
                app.ColumnList.UserData.class = columnClass;
                app.ColumnList.UserData.array = columnArray;
            
            else
                columnClass = app.ColumnList.UserData.class;
                columnArray = app.ColumnList.UserData.array;
            end
        end

        %-----------------------------------------------------------------%
        function EditionPanelLayout(app, editionStatus)
            arguments
                app 
                editionStatus char {mustBeMember(editionStatus, {'on', 'off'})}
            end

            switch editionStatus
                case 'on'
                    set(app.AddNewFilter, 'ImageSource', 'addFiles_32Filled.png', 'Tooltip', 'Desabilita painel de inclusão de filtro', 'UserData', true)
                    
                    app.Document.RowHeight{4} = 124;
                    app.SpecificationPanel.Visible = 1;
                    app.SpecificationControlGrid.ColumnWidth(end-1:end) = {18, 18};
                    app.ConfirmNewFilter.Enable = 1;
                    app.CancelNewFilter.Enable  = 1;
    
                case 'off'
                    set(app.AddNewFilter, 'ImageSource', 'addFiles_32.png',       'Tooltip', 'Habilita painel de inclusão de filtro',   'UserData', false)
    
                    app.Document.RowHeight{4} = 0;
                    app.SpecificationControlGrid.ColumnWidth(end-1:end) = {0,0};
                    app.ConfirmNewFilter.Enable = 0;
                    app.CancelNewFilter.Enable  = 0;
            end
        end

        %-----------------------------------------------------------------%
        function TreeUpdate(app)
            if ~isempty(app.Tree.Children)
                delete(app.Tree.Children)
            end

            selectedECD  = app.ecdObj(app.inputArgs.index);
            tableId      = app.TableIdList.Value;

            [filterIndex, filterStatus] = checkTableCustomFilter(app, selectedECD, tableId, 'basic');

            if filterStatus
                filterObj    = selectedECD.GUI.tableView(filterIndex).filter;
                filterList   = getFilterList(filterObj, ['ECD.x' tableId]);
                checkedNodes = [];

                for ii = 1:numel(filterList)
                    childNode = uitreenode(app.Tree, 'Text', filterList{ii}, 'NodeData', ii);

                    if filterObj.filterRules.Enable(ii)
                        checkedNodes = [checkedNodes, childNode];
                    end
                end

                app.Tree.CheckedNodes = checkedNodes;
            end
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
        function CheckAndAddFilter(app)
            selectedECD  = app.ecdObj(app.inputArgs.index);
            tableId      = app.TableIdList.Value;
            filterIndex  = checkTableCustomFilter(app, selectedECD, tableId, 'basic');

            if isempty(filterIndex)
                filterIndex = numel(selectedECD.GUI.tableView) + 1;

                selectedECD.GUI.tableView(filterIndex).id     = tableId;
                selectedECD.GUI.tableView(filterIndex).filter = tableFiltering;
            end

            fieldName = app.ColumnList.Value;            
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
            
            app.mainApp    = mainApp;
            app.callingApp = callingApp;            
            app.inputArgs  = struct('context', context, 'index', index);
            app.ecdObj     = mainApp.ecdObj;

            initialLayout(app, tableIdList, selectedTableId)
            
        end

        % Callback function: UIFigure, btnClose
        function closeFcn(app, event)
            
            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcn', context)

            delete(app)
            
        end

        % Value changed function: ColumnList
        function ColumnListValueChanged(app, event)

            app.ColumnList.UserData      = struct('class', '', 'array', []);
            app.operation1_List.UserData = struct('inputHandle', []);
            app.operation2_List.UserData = struct('inputHandle', []);
            
            columnClass = checkFilterType(app);
            switch columnClass
                case 'cellstr'
                    symbol     = '🔤';
                    operations = {'=', '≠', 'begins with', 'does not begin with', 'ends with', 'does not end with', 'contains', 'does not contain'};
                case 'numeric'
                    symbol     = '🔢';
                    operations = {'=', '≠', '<', '≤', '>', '≥'};
                case 'datetime'
                    symbol     = '📅';
                    operations = {'=', '≠', '<', '≤', '>', '≥'};
                case 'categorical'
                    symbol     = '🏷️';
                    operations = {'=', '≠', 'begins with', 'does not begin with', 'ends with', 'does not end with', 'contains', 'does not contain'};
            end
            app.ColumnClass.Text = symbol;
            
            app.operation1_List.Items = operations;
            app.operation1_List.Value = app.operation1_List.Items{1};
            OperationValueChanged(app, struct('Source', app.operation1_List))

            set(app.operation2_List, 'Items', [{''}, operations], 'Value', '')
            OperationValueChanged(app, struct('Source', app.operation2_List))
            
        end

        % Value changed function: operation1_List, operation2_List
        function OperationValueChanged(app, event)

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
            tagHandles = arrayfun(@(x) x.Tag, valueHandles, 'UniformOutput', false);

            [columnClass, columnArray] = checkFilterType(app);
            switch columnClass
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
                    [~, tagIndex] = ismember('textList', tagHandles);
                    uniqueValues  = unique(cellstr(columnArray));
                    optionalArgs  = {'Items', [{''}; uniqueValues]};
            end

            event.Source.UserData.inputHandle = valueHandles(tagIndex);
            set(valueHandles(tagIndex), 'Visible', 1, optionalArgs{:})
            set(setdiff(valueHandles, valueHandles(tagIndex)), 'Visible', 0)

        end

        % Menu selected function: ExcluirMenu
        function ExcluirMenuSelected(app, event)
            
            selectedNodes = app.Tree.SelectedNodes;

            if ~isempty(selectedNodes)
                selectedECD = app.ecdObj(app.inputArgs.index);
                tableId     = app.TableIdList.Value;

                [filterIndex, filterStatus] = checkTableCustomFilter(app, selectedECD, tableId, 'basic');
    
                if filterStatus
                    filterObj = selectedECD.GUI.tableView(filterIndex).filter;
                    removeFilterRule(filterObj, [selectedNodes.NodeData])
                    TreeUpdate(app)

                    context = app.inputArgs.context;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'changeFilter', context, tableId)
                end
            end

        end

        % Image clicked function: AddNewFilter, CancelNewFilter, 
        % ...and 1 other component
        function EditionModeImageClicked(app, event)
            
            switch event.Source
                case app.AddNewFilter
                    app.AddNewFilter.UserData = ~app.AddNewFilter.UserData;

                    if app.AddNewFilter.UserData
                        EditionPanelLayout(app, 'on')
                        focus(app.ColumnList)
                    else
                        EditionModeImageClicked(app, struct('Source', app.CancelNewFilter))
                    end

                case app.ConfirmNewFilter
                    try
                        CheckAndAddFilter(app)
                        EditionPanelLayout(app, 'off')
                        TreeUpdate(app)
                        
                        context = app.inputArgs.context;
                        tableId = app.TableIdList.Value;
                        ipcMainMatlabCallsHandler(app.mainApp, app, 'changeFilter', context, tableId)

                    catch ME
                        appUtil.modalWindow(app.UIFigure, 'error', ME.message);
                    end

                case app.CancelNewFilter
                    EditionPanelLayout(app, 'off')
            end     

        end

        % Value changed function: TableIdList
        function TableIdListValueChanged(app, event)
            
            index = app.inputArgs.index;
            tableId = app.TableIdList.Value;

            if ~isfield(app.ecdObj(index).Table, ['x' tableId])
                context = app.inputArgs.context;
                ipcMainMatlabCallsHandler(app.mainApp, app, 'tableNotRead', context, tableId)
            end

            set(app.ColumnList, 'Items', app.ecdObj(index).Table.(['x' tableId]).Properties.VariableNames)
            ColumnListValueChanged(app)

            TreeUpdate(app)
            
        end

        % Callback function: Tree
        function TreeCheckedNodesChanged(app, event)
            
            selectedECD = app.ecdObj(app.inputArgs.index);
            tableId     = app.TableIdList.Value;

            [filterIndex, filterStatus] = checkTableCustomFilter(app, selectedECD, tableId, 'basic');
    
            if filterStatus
                filterObj = selectedECD.GUI.tableView(filterIndex).filter;

                checkedNodes = [];            
                if ~isempty(app.Tree.CheckedNodes)
                    checkedNodes = [app.Tree.CheckedNodes.NodeData];
                end

                initialEnableArray = filterObj.filterRules.Enable;
                currentEnableArray = zeros(height(initialEnableArray), 1, 'logical');
                if ~isempty(checkedNodes)
                    currentEnableArray(checkedNodes) = true;
                end

                if ~isequal(initialEnableArray, currentEnableArray)
                    toogleFilterRule(filterObj, currentEnableArray)

                    context = app.inputArgs.context;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'changeFilter', context, tableId)
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
                app.UIFigure.Position = [100 100 640 376];
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
            app.Document.RowHeight = {17, 22, 22, 0, '1x'};
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
            app.TableIdList.ValueChangedFcn = createCallbackFcn(app, @TableIdListValueChanged, true);
            app.TableIdList.FontSize = 11;
            app.TableIdList.BackgroundColor = [1 1 1];
            app.TableIdList.Layout.Row = 2;
            app.TableIdList.Layout.Column = [1 3];
            app.TableIdList.Value = {};

            % Create SpecificationControlGrid
            app.SpecificationControlGrid = uigridlayout(app.Document);
            app.SpecificationControlGrid.ColumnWidth = {'1x', 18, 0, 0};
            app.SpecificationControlGrid.RowHeight = {22};
            app.SpecificationControlGrid.ColumnSpacing = 5;
            app.SpecificationControlGrid.Padding = [0 0 0 0];
            app.SpecificationControlGrid.Layout.Row = 3;
            app.SpecificationControlGrid.Layout.Column = [1 3];
            app.SpecificationControlGrid.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create SpecificationLabel
            app.SpecificationLabel = uilabel(app.SpecificationControlGrid);
            app.SpecificationLabel.VerticalAlignment = 'bottom';
            app.SpecificationLabel.FontSize = 10;
            app.SpecificationLabel.Layout.Row = 1;
            app.SpecificationLabel.Layout.Column = 1;
            app.SpecificationLabel.Text = 'FILTRO(S)';

            % Create AddNewFilter
            app.AddNewFilter = uiimage(app.SpecificationControlGrid);
            app.AddNewFilter.ImageClickedFcn = createCallbackFcn(app, @EditionModeImageClicked, true);
            app.AddNewFilter.Tooltip = {'Habilita painel de inclusão de filtro'};
            app.AddNewFilter.Layout.Row = 1;
            app.AddNewFilter.Layout.Column = 2;
            app.AddNewFilter.VerticalAlignment = 'bottom';
            app.AddNewFilter.ImageSource = 'addFiles_32.png';

            % Create ConfirmNewFilter
            app.ConfirmNewFilter = uiimage(app.SpecificationControlGrid);
            app.ConfirmNewFilter.ImageClickedFcn = createCallbackFcn(app, @EditionModeImageClicked, true);
            app.ConfirmNewFilter.Enable = 'off';
            app.ConfirmNewFilter.Tooltip = {'Confirma edição'};
            app.ConfirmNewFilter.Layout.Row = 1;
            app.ConfirmNewFilter.Layout.Column = 3;
            app.ConfirmNewFilter.VerticalAlignment = 'bottom';
            app.ConfirmNewFilter.ImageSource = 'Ok_32Green.png';

            % Create CancelNewFilter
            app.CancelNewFilter = uiimage(app.SpecificationControlGrid);
            app.CancelNewFilter.ImageClickedFcn = createCallbackFcn(app, @EditionModeImageClicked, true);
            app.CancelNewFilter.Enable = 'off';
            app.CancelNewFilter.Tooltip = {'Cancela edição'};
            app.CancelNewFilter.Layout.Row = 1;
            app.CancelNewFilter.Layout.Column = 4;
            app.CancelNewFilter.VerticalAlignment = 'bottom';
            app.CancelNewFilter.ImageSource = 'Delete_32Red.png';

            % Create SpecificationPanel
            app.SpecificationPanel = uipanel(app.Document);
            app.SpecificationPanel.Layout.Row = 4;
            app.SpecificationPanel.Layout.Column = [1 3];

            % Create SpecificationGrid
            app.SpecificationGrid = uigridlayout(app.SpecificationPanel);
            app.SpecificationGrid.ColumnWidth = {130, '1x', 22};
            app.SpecificationGrid.RowHeight = {22, 22, 22, 22};
            app.SpecificationGrid.ColumnSpacing = 5;
            app.SpecificationGrid.RowSpacing = 5;
            app.SpecificationGrid.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create ColumnList
            app.ColumnList = uidropdown(app.SpecificationGrid);
            app.ColumnList.Items = {};
            app.ColumnList.ValueChangedFcn = createCallbackFcn(app, @ColumnListValueChanged, true);
            app.ColumnList.FontSize = 11;
            app.ColumnList.BackgroundColor = [1 1 1];
            app.ColumnList.Layout.Row = 1;
            app.ColumnList.Layout.Column = [1 2];
            app.ColumnList.Value = {};

            % Create ColumnClass
            app.ColumnClass = uilabel(app.SpecificationGrid);
            app.ColumnClass.FontSize = 18;
            app.ColumnClass.Layout.Row = 1;
            app.ColumnClass.Layout.Column = 3;
            app.ColumnClass.Text = '🔤';

            % Create operation1_List
            app.operation1_List = uidropdown(app.SpecificationGrid);
            app.operation1_List.Items = {};
            app.operation1_List.ValueChangedFcn = createCallbackFcn(app, @OperationValueChanged, true);
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
            app.value1_Date.Layout.Column = 2;

            % Create value1_Numeric
            app.value1_Numeric = uieditfield(app.SpecificationGrid, 'numeric');
            app.value1_Numeric.AllowEmpty = 'on';
            app.value1_Numeric.Tag = 'numeric';
            app.value1_Numeric.FontSize = 11;
            app.value1_Numeric.Visible = 'off';
            app.value1_Numeric.Layout.Row = 2;
            app.value1_Numeric.Layout.Column = 2;
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
            app.value1_TextList.Layout.Column = 2;
            app.value1_TextList.Value = '';

            % Create value1_TextFree
            app.value1_TextFree = uieditfield(app.SpecificationGrid, 'text');
            app.value1_TextFree.Tag = 'textFree';
            app.value1_TextFree.FontSize = 11;
            app.value1_TextFree.FontColor = [0.149 0.149 0.149];
            app.value1_TextFree.Layout.Row = 2;
            app.value1_TextFree.Layout.Column = 2;

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
            app.operation2_List.ValueChangedFcn = createCallbackFcn(app, @OperationValueChanged, true);
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
            app.value2_Date.Layout.Column = 2;

            % Create value2_Numeric
            app.value2_Numeric = uieditfield(app.SpecificationGrid, 'numeric');
            app.value2_Numeric.AllowEmpty = 'on';
            app.value2_Numeric.Tag = 'numeric';
            app.value2_Numeric.FontSize = 11;
            app.value2_Numeric.Visible = 'off';
            app.value2_Numeric.Layout.Row = 4;
            app.value2_Numeric.Layout.Column = 2;
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
            app.value2_TextList.Layout.Column = 2;
            app.value2_TextList.Value = '';

            % Create value2_TextFree
            app.value2_TextFree = uieditfield(app.SpecificationGrid, 'text');
            app.value2_TextFree.Tag = 'textFree';
            app.value2_TextFree.FontSize = 11;
            app.value2_TextFree.FontColor = [0.149 0.149 0.149];
            app.value2_TextFree.Layout.Row = 4;
            app.value2_TextFree.Layout.Column = 2;

            % Create Tree
            app.Tree = uitree(app.Document, 'checkbox');
            app.Tree.FontSize = 11;
            app.Tree.Layout.Row = 5;
            app.Tree.Layout.Column = [1 3];

            % Assign Checked Nodes
            app.Tree.CheckedNodesChangedFcn = createCallbackFcn(app, @TreeCheckedNodesChanged, true);

            % Create ContextMenu
            app.ContextMenu = uicontextmenu(app.UIFigure);

            % Create ExcluirMenu
            app.ExcluirMenu = uimenu(app.ContextMenu);
            app.ExcluirMenu.MenuSelectedFcn = createCallbackFcn(app, @ExcluirMenuSelected, true);
            app.ExcluirMenu.Text = '❌ Excluir';
            
            % Assign app.ContextMenu
            app.Tree.ContextMenu = app.ContextMenu;

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
