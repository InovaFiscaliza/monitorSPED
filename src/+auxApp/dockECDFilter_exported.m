classdef dockECDFilter_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                  matlab.ui.Figure
        GridLayout                matlab.ui.container.GridLayout
        Document                  matlab.ui.container.GridLayout
        Tree                      matlab.ui.container.CheckBoxTree
        SpecificationPanel        matlab.ui.container.Panel
        SpecificationGrid         matlab.ui.container.GridLayout
        ButtonGroup               matlab.ui.container.ButtonGroup
        OUButton                  matlab.ui.control.RadioButton
        EButton                   matlab.ui.control.RadioButton
        value_TextFree_2          matlab.ui.control.EditField
        OperationList_2           matlab.ui.control.DropDown
        value_TextFree            matlab.ui.control.EditField
        value_TextList            matlab.ui.control.DropDown
        value_Numeric2            matlab.ui.control.NumericEditField
        value_Numeric1            matlab.ui.control.NumericEditField
        value_Date2               matlab.ui.control.DatePicker
        value_Date1               matlab.ui.control.DatePicker
        DateTimeSeparator         matlab.ui.control.Label
        OperationList             matlab.ui.control.DropDown
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
        function initialLayout(app, index, tableIdList, selectedTableId)
            set(app.TableIdList, 'Items', tableIdList, 'Value', selectedTableId)
            set(app.ColumnList, 'Items', app.ecdObj(index).Table.(['x' selectedTableId]).Properties.VariableNames)
            ColumnListValueChanged(app)
            
            app.AddNewFilter.UserData = false;
        end

        %-----------------------------------------------------------------%
        function [columnClass, columnArray] = checkFilterType(app)
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
                    
                    app.Document.RowHeight{4} = 70;
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

       %  %-----------------------------------------------------------------%
       %  function updateLayout(app)
       %      allColumns      = app.mainApp.General.ui.searchTable.name;
       %      [~, sortIndex]  = sort(lower(allColumns));
       %      GUIAllColumns   = allColumns(sortIndex);
       % 
       %      app.ColumnList.Items = GUIAllColumns;
       %      ColumnListValueChanged(app)
       % 
       %      app.ListOfFilters.Items = FilterList(app.mainApp.filteringObj, 'SCH');
       %  end
       % 
       % %-----------------------------------------------------------------%
       %  function [value, msgWarning] = SecundaryFilterValue(app)
       %      value      = [];
       %      msgWarning = '';
       % 
       %      columnName = app.ColumnList.Value;
       %      filterType = checkFilterType(app, columnName);
       %      operation  = app.OperationList.Value;
       % 
       %      switch filterType
       %          case 'datetime'
       %              switch operation
       %                  case {'=', '≠', '<', '≤', '>', '≥'}
       %                      value = datetime(app.SecundaryDateTime1.Value, 'InputFormat', 'dd/MM/yyyy', 'Format', 'dd/MM/yyyy');
       % 
       %                  case {'><', '<>'}
       %                      value = datetime({app.SecundaryDateTime1.Value, app.SecundaryDateTime2.Value}, 'InputFormat', 'dd/MM/yyyy', 'Format', 'dd/MM/yyyy');
       % 
       %                  case {'⊃', '⊅'}
       %                      try
       %                          value = cellfun(@(x) datetime(x, "InputFormat", 'dd/MM/yyyy', 'Format', 'dd/MM/yyyy'), strtrim(strsplit(app.value_TextFree.Value, ',')));
       %                      catch ME
       %                          app.value_TextFree.Value = '';
       % 
       %                          msgWarning = ME.message;
       %                          return
       %                      end
       %              end
       % 
       %          case 'freeText'
       %              value = strtrim(strsplit(app.value_TextFree.Value, ','));
       %              if isscalar(value)
       %                  value = char(value);
       %              end
       % 
       %          case 'listOfText'
       %              value = app.value_TextList.Value;
       %      end
       % 
       %      if isempty(value)
       %          msgWarning = 'Valor inválido.';
       %      end
       %  end
       % 
       %  %-----------------------------------------------------------------%
       %  function CallingMainApp(app, updateFlag, returnFlag)
       %      ipcMainMatlabCallsHandler(app.mainApp, app, 'SEARCH:FILTERSETUP', updateFlag, returnFlag)
       %  end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, callingApp, context, index, tableIdList, selectedTableId)
            
            app.mainApp    = mainApp;
            app.callingApp = callingApp;            
            app.inputArgs  = struct('context', context, 'index', index);
            app.ecdObj     = mainApp.ecdObj;

            initialLayout(app, index, tableIdList, selectedTableId)
            
        end

        % Callback function: UIFigure, btnClose
        function closeFcn(app, event)
            
            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcn', context)

            delete(app)
            
        end

        % Value changed function: ColumnList
        function ColumnListValueChanged(app, event)

            columnClass = checkFilterType(app);
            switch columnClass
                case 'cellstr'
                    symbol     = '🔤';
                    operations = {'=', '≠', '⊃', '⊅'};
                case 'numeric'
                    symbol     = '🔢';
                    operations = {'=', '≠', '<', '≤', '>', '≥', '><', '<>'};
                case 'datetime'
                    symbol     = '📅';
                    operations = {'=', '≠', '<', '≤', '>', '≥', '><', '<>'};
                case 'categorical'
                    symbol     = '🏷️';
                    operations = {'=', '≠'};
            end
            app.ColumnClass.Text = symbol;
            app.OperationList.Items = operations;

            app.OperationList.Value = app.OperationList.Items{1};
            OperationListValueChanged(app)
            
        end

        % Value changed function: OperationList
        function OperationListValueChanged(app, event)

            [columnClass, columnArray] = checkFilterType(app);
            operation  = app.OperationList.Value;

            valueHandles = [ ...
                app.value_Date1, ...
                app.value_Date2, ...
                app.value_Numeric1, ...
                app.value_Numeric2, ...
                app.value_TextFree, ...
                app.value_TextList, ...
                app.DateTimeSeparator ...
            ];

            tagHandles = arrayfun(@(x) x.Tag, valueHandles, 'UniformOutput', false);

            switch columnClass
                case 'cellstr'
                    [~, tagIndex] = ismember('textFree', tagHandles);
                  % optionalArgs  = {'Value', ''};
                    optionalArgs  = {};

                case 'numeric'
                    switch operation
                        case {'=', '≠', '<', '≤', '>', '≥'}
                            [~, tagIndex] = ismember('numeric1', tagHandles);
                        case {'><', '<>'}
                            [~, tagIndex] = ismember({'numeric1', 'numeric2', 'separator'}, tagHandles);
                    end
                    optionalArgs  = {};

                case 'datetime'
                    switch operation
                        case {'=', '≠', '<', '≤', '>', '≥'}
                            [~, tagIndex] = ismember('datePicker1', tagHandles);
                        case {'><', '<>'}
                            [~, tagIndex] = ismember({'datePicker1', 'datePicker2', 'separator'}, tagHandles);
                    end
                    optionalArgs  = {};

                case 'categorical'
                    [~, tagIndex] = ismember('textList', tagHandles);
                    uniqueValues  = unique(cellstr(columnArray));
                    optionalArgs  = {'Items', uniqueValues};
            end

            set(valueHandles(tagIndex), 'Visible', 1, optionalArgs{:})
            set(setdiff(valueHandles, valueHandles(tagIndex)), 'Visible', 0)

        end

        % Callback function: not associated with a component
        function SecundaryAddFilterImageClicked(app, event)
            
            % primaryIndex = app.mainApp.search_Table.UserData.primaryIndex;
            % if isempty(primaryIndex)
            %     appUtil.modalWindow(app.UIFigure, 'warning', 'A filtragem secundária é aplicável apenas após a realização de uma pesquisa (filtragem primária), e desde que tenha retornado algum registro dessa pesquisa.');
            %     return
            % end
            % 
            % % Afere os valores do novo filtro, validando-os.
            % Column    = app.ColumnList.Value;
            % Operation = app.OperationList.Value;
            % 
            % [Value, msgWarning] = SecundaryFilterValue(app);
            % if ~isempty(msgWarning)
            %     appUtil.modalWindow(app.UIFigure, 'warning', msgWarning);
            %     return
            % end
            % 
            % % Adiciona um novo filtro à lista de filtros secundários.
            % msgWarning = addFilterRule(app.mainApp.filteringObj, Column, Operation, Value);
            % if ~isempty(msgWarning)
            %     appUtil.modalWindow(app.UIFigure, 'warning', msgWarning);
            %     return
            % end
            % 
            % % Filtra...
            % CallingMainApp(app, true, true)
            % updateLayout(app)

        end

        % Menu selected function: ExcluirMenu
        function ExcluirMenuSelected(app, event)
            
            % selectedFilter = app.ListOfFilters.Value;
            % 
            % if ~isempty(selectedFilter)
            %     idxFilter = find(ismember(app.ListOfFilters.Items, selectedFilter));
            %     removeFilterRule(app.mainApp.filteringObj, idxFilter);
            % 
            %     CallingMainApp(app, true, true)
            %     updateLayout(app)
            % end

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
                    % ADICIONA O FILTRO
                    EditionPanelLayout(app, 'off')

                    context = app.inputArgs.context;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'changeFilter', context)

                case app.CancelNewFilter
                    EditionPanelLayout(app, 'off')
            end     

        end

        % Value changed function: TableIdList
        function TableIdListValueChanged(app, event)
            
            index = app.inputArgs.index;
            selectedTableId = app.TableIdList.Value;

            if ~isfield(app.ecdObj(index).Table, ['x' selectedTableId])
                context = app.inputArgs.context;
                ipcMainMatlabCallsHandler(app.mainApp, app, 'tableNotRead', context, selectedTableId)
            end

            set(app.ColumnList, 'Items', app.ecdObj(index).Table.(['x' selectedTableId]).Properties.VariableNames)
            ColumnListValueChanged(app)
            
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
                app.UIFigure.Position = [100 100 412 464];
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
            app.Document.RowHeight = {17, 22, 22, 126, '1x'};
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
            app.SpecificationLabel.Text = 'FILTRAGEM';

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
            app.SpecificationGrid.ColumnWidth = {55, '1x', 10, '1x', 22};
            app.SpecificationGrid.RowHeight = {22, 22, 22, 22};
            app.SpecificationGrid.ColumnSpacing = 5;
            app.SpecificationGrid.RowSpacing = 5;
            app.SpecificationGrid.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create ColumnList
            app.ColumnList = uidropdown(app.SpecificationGrid);
            app.ColumnList.Items = {};
            app.ColumnList.ValueChangedFcn = createCallbackFcn(app, @ColumnListValueChanged, true);
            app.ColumnList.FontSize = 11;
            app.ColumnList.BackgroundColor = [0.9804 0.9804 0.9804];
            app.ColumnList.Layout.Row = 1;
            app.ColumnList.Layout.Column = [1 4];
            app.ColumnList.Value = {};

            % Create ColumnClass
            app.ColumnClass = uilabel(app.SpecificationGrid);
            app.ColumnClass.FontSize = 18;
            app.ColumnClass.Layout.Row = 1;
            app.ColumnClass.Layout.Column = 5;
            app.ColumnClass.Text = '🔤';

            % Create OperationList
            app.OperationList = uidropdown(app.SpecificationGrid);
            app.OperationList.Items = {'=', '≠', '⊃', '⊅', '<', '≤', '>', '≥'};
            app.OperationList.ValueChangedFcn = createCallbackFcn(app, @OperationListValueChanged, true);
            app.OperationList.FontName = 'Consolas';
            app.OperationList.BackgroundColor = [0.9804 0.9804 0.9804];
            app.OperationList.Layout.Row = 2;
            app.OperationList.Layout.Column = 1;
            app.OperationList.Value = '=';

            % Create DateTimeSeparator
            app.DateTimeSeparator = uilabel(app.SpecificationGrid);
            app.DateTimeSeparator.Tag = 'separator';
            app.DateTimeSeparator.HorizontalAlignment = 'center';
            app.DateTimeSeparator.Layout.Row = 2;
            app.DateTimeSeparator.Layout.Column = 3;
            app.DateTimeSeparator.Text = '-';

            % Create value_Date1
            app.value_Date1 = uidatepicker(app.SpecificationGrid);
            app.value_Date1.Editable = 'off';
            app.value_Date1.Tag = 'datePicker1';
            app.value_Date1.FontSize = 11;
            app.value_Date1.Visible = 'off';
            app.value_Date1.Layout.Row = 2;
            app.value_Date1.Layout.Column = 2;

            % Create value_Date2
            app.value_Date2 = uidatepicker(app.SpecificationGrid);
            app.value_Date2.Editable = 'off';
            app.value_Date2.Tag = 'datePicker2';
            app.value_Date2.FontSize = 11;
            app.value_Date2.Visible = 'off';
            app.value_Date2.Layout.Row = 2;
            app.value_Date2.Layout.Column = 4;

            % Create value_Numeric1
            app.value_Numeric1 = uieditfield(app.SpecificationGrid, 'numeric');
            app.value_Numeric1.AllowEmpty = 'on';
            app.value_Numeric1.Tag = 'numeric1';
            app.value_Numeric1.FontSize = 11;
            app.value_Numeric1.Visible = 'off';
            app.value_Numeric1.Layout.Row = 2;
            app.value_Numeric1.Layout.Column = 2;

            % Create value_Numeric2
            app.value_Numeric2 = uieditfield(app.SpecificationGrid, 'numeric');
            app.value_Numeric2.AllowEmpty = 'on';
            app.value_Numeric2.Tag = 'numeric2';
            app.value_Numeric2.FontSize = 11;
            app.value_Numeric2.Visible = 'off';
            app.value_Numeric2.Layout.Row = 2;
            app.value_Numeric2.Layout.Column = 4;

            % Create value_TextList
            app.value_TextList = uidropdown(app.SpecificationGrid);
            app.value_TextList.Items = {};
            app.value_TextList.Tag = 'textList';
            app.value_TextList.Visible = 'off';
            app.value_TextList.FontSize = 11;
            app.value_TextList.BackgroundColor = [0.9804 0.9804 0.9804];
            app.value_TextList.Layout.Row = 2;
            app.value_TextList.Layout.Column = [2 4];
            app.value_TextList.Value = {};

            % Create value_TextFree
            app.value_TextFree = uieditfield(app.SpecificationGrid, 'text');
            app.value_TextFree.Tag = 'textFree';
            app.value_TextFree.FontSize = 11;
            app.value_TextFree.FontColor = [0.149 0.149 0.149];
            app.value_TextFree.BackgroundColor = [0.9804 0.9804 0.9804];
            app.value_TextFree.Layout.Row = 2;
            app.value_TextFree.Layout.Column = [2 4];

            % Create OperationList_2
            app.OperationList_2 = uidropdown(app.SpecificationGrid);
            app.OperationList_2.Items = {'', '=', '≠', '⊃', '⊅', '<', '≤', '>', '≥', '><', '<>'};
            app.OperationList_2.FontName = 'Consolas';
            app.OperationList_2.BackgroundColor = [0.9804 0.9804 0.9804];
            app.OperationList_2.Layout.Row = 4;
            app.OperationList_2.Layout.Column = 1;
            app.OperationList_2.Value = '';

            % Create value_TextFree_2
            app.value_TextFree_2 = uieditfield(app.SpecificationGrid, 'text');
            app.value_TextFree_2.Tag = 'textFree';
            app.value_TextFree_2.FontSize = 11;
            app.value_TextFree_2.FontColor = [0.149 0.149 0.149];
            app.value_TextFree_2.BackgroundColor = [0.9804 0.9804 0.9804];
            app.value_TextFree_2.Layout.Row = 4;
            app.value_TextFree_2.Layout.Column = [2 4];

            % Create ButtonGroup
            app.ButtonGroup = uibuttongroup(app.SpecificationGrid);
            app.ButtonGroup.AutoResizeChildren = 'off';
            app.ButtonGroup.BorderType = 'none';
            app.ButtonGroup.BackgroundColor = [0.9804 0.9804 0.9804];
            app.ButtonGroup.Layout.Row = 3;
            app.ButtonGroup.Layout.Column = [1 4];

            % Create EButton
            app.EButton = uiradiobutton(app.ButtonGroup);
            app.EButton.Text = 'E (&&)';
            app.EButton.FontSize = 11;
            app.EButton.Position = [1 1 58 22];
            app.EButton.Value = true;

            % Create OUButton
            app.OUButton = uiradiobutton(app.ButtonGroup);
            app.OUButton.Text = 'OU (||)';
            app.OUButton.FontSize = 11;
            app.OUButton.Position = [61 1 65 22];

            % Create Tree
            app.Tree = uitree(app.Document, 'checkbox');
            app.Tree.FontSize = 11;
            app.Tree.Layout.Row = 5;
            app.Tree.Layout.Column = [1 3];

            % Create ContextMenu
            app.ContextMenu = uicontextmenu(app.UIFigure);

            % Create ExcluirMenu
            app.ExcluirMenu = uimenu(app.ContextMenu);
            app.ExcluirMenu.MenuSelectedFcn = createCallbackFcn(app, @ExcluirMenuSelected, true);
            app.ExcluirMenu.Text = '❌ Excluir';

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
