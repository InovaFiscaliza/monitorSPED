classdef dockIcmsRate_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure               matlab.ui.Figure
        GridLayout             matlab.ui.container.GridLayout
        Document               matlab.ui.container.GridLayout
        IcmsRateByMonthPanel   matlab.ui.container.Panel
        IcmsRateByMonthGrid    matlab.ui.container.GridLayout
        IcmsMonth12            matlab.ui.control.Spinner
        IcmsMonth12Label       matlab.ui.control.Label
        IcmsMonth11            matlab.ui.control.Spinner
        IcmsMonth11Label       matlab.ui.control.Label
        IcmsMonth10            matlab.ui.control.Spinner
        IcmsMonth10Label       matlab.ui.control.Label
        IcmsMonth9             matlab.ui.control.Spinner
        IcmsMonth9Label        matlab.ui.control.Label
        IcmsMonth8             matlab.ui.control.Spinner
        IcmsMonth8Label        matlab.ui.control.Label
        IcmsMonth7             matlab.ui.control.Spinner
        IcmsMonth7Label        matlab.ui.control.Label
        IcmsMonth6             matlab.ui.control.Spinner
        IcmsMonth6Label        matlab.ui.control.Label
        IcmsMonth5             matlab.ui.control.Spinner
        IcmsMonth5Label        matlab.ui.control.Label
        IcmsMonth4             matlab.ui.control.Spinner
        IcmsMonth4Label        matlab.ui.control.Label
        IcmsMonth3             matlab.ui.control.Spinner
        IcmsMonth3Label        matlab.ui.control.Label
        IcmsMonth2             matlab.ui.control.Spinner
        IcmsMonth2Label        matlab.ui.control.Label
        IcmsMonth1             matlab.ui.control.Spinner
        IcmsMonth1Label        matlab.ui.control.Label
        IcmsRateCancelButton   matlab.ui.control.Image
        IcmsRateConfirmButton  matlab.ui.control.Image
        IcmsRateEditMode       matlab.ui.control.Image
        IcmsRateRefresh        matlab.ui.control.Image
        EntityInfo             matlab.ui.control.Label
        btnClose               matlab.ui.control.Image
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
        jsBackDoor
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        inputArgs
    end
    

    methods (Access = private)
        %-----------------------------------------------------------------%
        function updateLayout(app, index)
            app.EntityInfo.Text = util.HtmlTextGenerator.icmsRateDetails(app.mainApp.ecdObj(index));

            currentIcmsRate = app.mainApp.ecdObj(index).GUI.icmsRate.current.rate;
            updateIcmsRatePanel(app, currentIcmsRate)

            app.IcmsRateRefresh.Visible = ~strcmp(app.mainApp.ecdObj(index).GUI.icmsRate.source, 'default');
        end

        %-----------------------------------------------------------------%
        function updateIcmsRatePanel(app, value)
            value = 100*value;
            
            if isscalar(value)
                hSpinners = findobj(app.IcmsRateByMonthGrid.Children, 'Type', 'uispinner');
                set(hSpinners, 'Value', value)
            else
                for ii = 1:numel(value)
                    hSpinner = findobj(app.IcmsRateByMonthGrid.Children, 'Type', 'uispinner', 'Tag', num2str(ii));
                    set(hSpinner, 'Value', value(ii))
                end
            end
        end

        %-----------------------------------------------------------------%
        function setIcmsRateEditModeLayout(app, status)
            arguments
                app 
                status char {mustBeMember(status, {'on', 'off'})}
            end            

            switch status
                case 'on'
                    app.IcmsRateEditMode.ImageSource = 'Edit_32Filled.png';
                    app.IcmsRateEditMode.UserData.status = true;
                    
                    app.Document.ColumnWidth(end-1:end) = {18, 18};
                    app.IcmsRateConfirmButton.Enable = 1;
                    app.IcmsRateCancelButton.Enable  = 1;

                    setIcmsRatePanelEditable(app, true)

                case 'off'
                    app.IcmsRateEditMode.ImageSource = 'Edit_32.png';
                    app.IcmsRateEditMode.UserData.status = false;

                    app.Document.ColumnWidth(end-1:end) = {0,0};
                    app.IcmsRateConfirmButton.Enable = 0;
                    app.IcmsRateCancelButton.Enable  = 0;

                    setIcmsRatePanelEditable(app, false)
            end
        end

        %-----------------------------------------------------------------%
        function setIcmsRatePanelEditable(app, status)
            hSpinners = findobj(app.IcmsRateByMonthGrid.Children, 'Type', 'uispinner');
            set(hSpinners, 'Enable', status)
        end

        %-----------------------------------------------------------------%
        function icmsRateInfo = createIcmsRateInfo(app)
            rateList = round([ ...
                app.IcmsMonth1.Value, ...
                app.IcmsMonth2.Value, ...
                app.IcmsMonth3.Value, ...
                app.IcmsMonth4.Value, ...
                app.IcmsMonth5.Value, ...
                app.IcmsMonth6.Value, ...
                app.IcmsMonth7.Value, ...
                app.IcmsMonth8.Value, ...
                app.IcmsMonth9.Value, ...
                app.IcmsMonth10.Value, ...
                app.IcmsMonth11.Value, ...
                app.IcmsMonth12.Value ...
            ] ./ 100, 3);

            if isscalar(unique(rateList))
                rateList = rateList(1);
            end

            icmsRateInfo = struct( ...
                'mode', 'manual', ...
                'rate', rateList ...
            );
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp, callingApp, context, index)
            
            try
                appEngine.boot(app, app.Role, mainApp, callingApp)

                app.inputArgs = struct('context', context, 'index', index);
                app.IcmsRateEditMode.UserData.status = false;
                updateLayout(app, index)
                
            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME), 'CloseFcn', @(~,~)closeFcn(app));
            end
            
        end

        % Callback function: UIFigure, btnClose
        function closeFcn(app, event)
            
            context = app.inputArgs.context;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'closeFcnCallFromPopupApp', context, 'auxApp.dockECDAccount')

            delete(app)
            
        end

        % Image clicked function: IcmsRateCancelButton, 
        % ...and 3 other components
        function onIcmsRateEditModeChanged(app, event)
            
            index = app.inputArgs.index;

            switch event.Source
                case app.IcmsRateRefresh
                    update(app.mainApp.ecdObj(index), 'GUI.IcmsRate', 'refresh')
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'onIcmsRateChanged', index);
                    setIcmsRateEditModeLayout(app, 'off')

                case app.IcmsRateEditMode
                    app.IcmsRateEditMode.UserData.status = ~app.IcmsRateEditMode.UserData.status;
                    
                    if app.IcmsRateEditMode.UserData.status
                        setIcmsRateEditModeLayout(app, 'on')
                    else
                        setIcmsRateEditModeLayout(app, 'off')
                    end

                case app.IcmsRateConfirmButton
                    currentIcmsRate = app.mainApp.ecdObj(index).GUI.icmsRate.current.rate;
                    newIcmsRateInfo = createIcmsRateInfo(app);
                    if ~isequal(currentIcmsRate, newIcmsRateInfo)
                        update(app.mainApp.ecdObj(index), 'GUI.IcmsRate', 'valueChanged', newIcmsRateInfo)
                        ipcMainMatlabCallsHandler(app.mainApp, app, 'onIcmsRateChanged', index);
                    end
                    setIcmsRateEditModeLayout(app, 'off')

                case app.IcmsRateCancelButton
                    setIcmsRateEditModeLayout(app, 'off')
            end

            updateLayout(app, index)

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
                app.UIFigure.Position = [92 92 448 320];
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
            app.Document.ColumnWidth = {'1x', 18, 18, 0, 0};
            app.Document.RowHeight = {'1x', 18, 108};
            app.Document.ColumnSpacing = 5;
            app.Document.RowSpacing = 5;
            app.Document.Layout.Row = 2;
            app.Document.Layout.Column = [1 2];
            app.Document.BackgroundColor = [1 1 1];

            % Create EntityInfo
            app.EntityInfo = uilabel(app.Document);
            app.EntityInfo.VerticalAlignment = 'top';
            app.EntityInfo.WordWrap = 'on';
            app.EntityInfo.FontSize = 11;
            app.EntityInfo.Layout.Row = [1 2];
            app.EntityInfo.Layout.Column = [1 5];
            app.EntityInfo.Interpreter = 'html';
            app.EntityInfo.Text = '';

            % Create IcmsRateRefresh
            app.IcmsRateRefresh = uiimage(app.Document);
            app.IcmsRateRefresh.ScaleMethod = 'none';
            app.IcmsRateRefresh.ImageClickedFcn = createCallbackFcn(app, @onIcmsRateEditModeChanged, true);
            app.IcmsRateRefresh.Visible = 'off';
            app.IcmsRateRefresh.Layout.Row = 2;
            app.IcmsRateRefresh.Layout.Column = 2;
            app.IcmsRateRefresh.ImageSource = 'Refresh_18.png';

            % Create IcmsRateEditMode
            app.IcmsRateEditMode = uiimage(app.Document);
            app.IcmsRateEditMode.ImageClickedFcn = createCallbackFcn(app, @onIcmsRateEditModeChanged, true);
            app.IcmsRateEditMode.Layout.Row = 2;
            app.IcmsRateEditMode.Layout.Column = 3;
            app.IcmsRateEditMode.ImageSource = 'Edit_32.png';

            % Create IcmsRateConfirmButton
            app.IcmsRateConfirmButton = uiimage(app.Document);
            app.IcmsRateConfirmButton.ImageClickedFcn = createCallbackFcn(app, @onIcmsRateEditModeChanged, true);
            app.IcmsRateConfirmButton.Layout.Row = 2;
            app.IcmsRateConfirmButton.Layout.Column = 4;
            app.IcmsRateConfirmButton.ImageSource = 'Ok_32Green.png';

            % Create IcmsRateCancelButton
            app.IcmsRateCancelButton = uiimage(app.Document);
            app.IcmsRateCancelButton.ImageClickedFcn = createCallbackFcn(app, @onIcmsRateEditModeChanged, true);
            app.IcmsRateCancelButton.Layout.Row = 2;
            app.IcmsRateCancelButton.Layout.Column = 5;
            app.IcmsRateCancelButton.ImageSource = 'Delete_32Red.png';

            % Create IcmsRateByMonthPanel
            app.IcmsRateByMonthPanel = uipanel(app.Document);
            app.IcmsRateByMonthPanel.Layout.Row = 3;
            app.IcmsRateByMonthPanel.Layout.Column = [1 5];

            % Create IcmsRateByMonthGrid
            app.IcmsRateByMonthGrid = uigridlayout(app.IcmsRateByMonthPanel);
            app.IcmsRateByMonthGrid.ColumnWidth = {24, '1x', 24, '1x', 24, '1x', 24, '1x'};
            app.IcmsRateByMonthGrid.RowHeight = {22, 22, 22};
            app.IcmsRateByMonthGrid.BackgroundColor = [1 1 1];

            % Create IcmsMonth1Label
            app.IcmsMonth1Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth1Label.FontSize = 10;
            app.IcmsMonth1Label.Layout.Row = 1;
            app.IcmsMonth1Label.Layout.Column = [1 2];
            app.IcmsMonth1Label.Text = 'JAN:';

            % Create IcmsMonth1
            app.IcmsMonth1 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth1.Step = 0.5;
            app.IcmsMonth1.Limits = [0 100];
            app.IcmsMonth1.ValueDisplayFormat = '%.1f';
            app.IcmsMonth1.Tag = '1';
            app.IcmsMonth1.FontSize = 11;
            app.IcmsMonth1.Enable = 'off';
            app.IcmsMonth1.Layout.Row = 1;
            app.IcmsMonth1.Layout.Column = 2;

            % Create IcmsMonth2Label
            app.IcmsMonth2Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth2Label.FontSize = 10;
            app.IcmsMonth2Label.Layout.Row = 2;
            app.IcmsMonth2Label.Layout.Column = [1 2];
            app.IcmsMonth2Label.Text = 'FEV:';

            % Create IcmsMonth2
            app.IcmsMonth2 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth2.Step = 0.5;
            app.IcmsMonth2.Limits = [0 100];
            app.IcmsMonth2.ValueDisplayFormat = '%.1f';
            app.IcmsMonth2.Tag = '2';
            app.IcmsMonth2.FontSize = 11;
            app.IcmsMonth2.Enable = 'off';
            app.IcmsMonth2.Layout.Row = 2;
            app.IcmsMonth2.Layout.Column = 2;

            % Create IcmsMonth3Label
            app.IcmsMonth3Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth3Label.FontSize = 10;
            app.IcmsMonth3Label.Layout.Row = 3;
            app.IcmsMonth3Label.Layout.Column = [1 2];
            app.IcmsMonth3Label.Text = 'MAR:';

            % Create IcmsMonth3
            app.IcmsMonth3 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth3.Step = 0.5;
            app.IcmsMonth3.Limits = [0 100];
            app.IcmsMonth3.ValueDisplayFormat = '%.1f';
            app.IcmsMonth3.Tag = '3';
            app.IcmsMonth3.FontSize = 11;
            app.IcmsMonth3.Enable = 'off';
            app.IcmsMonth3.Layout.Row = 3;
            app.IcmsMonth3.Layout.Column = 2;

            % Create IcmsMonth4Label
            app.IcmsMonth4Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth4Label.FontSize = 10;
            app.IcmsMonth4Label.Layout.Row = 1;
            app.IcmsMonth4Label.Layout.Column = [3 4];
            app.IcmsMonth4Label.Text = 'ABR:';

            % Create IcmsMonth4
            app.IcmsMonth4 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth4.Step = 0.5;
            app.IcmsMonth4.Limits = [0 100];
            app.IcmsMonth4.ValueDisplayFormat = '%.1f';
            app.IcmsMonth4.Tag = '4';
            app.IcmsMonth4.FontSize = 11;
            app.IcmsMonth4.Enable = 'off';
            app.IcmsMonth4.Layout.Row = 1;
            app.IcmsMonth4.Layout.Column = 4;

            % Create IcmsMonth5Label
            app.IcmsMonth5Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth5Label.FontSize = 10;
            app.IcmsMonth5Label.Layout.Row = 2;
            app.IcmsMonth5Label.Layout.Column = [3 4];
            app.IcmsMonth5Label.Text = 'MAI:';

            % Create IcmsMonth5
            app.IcmsMonth5 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth5.Step = 0.5;
            app.IcmsMonth5.Limits = [0 100];
            app.IcmsMonth5.ValueDisplayFormat = '%.1f';
            app.IcmsMonth5.Tag = '5';
            app.IcmsMonth5.FontSize = 11;
            app.IcmsMonth5.Enable = 'off';
            app.IcmsMonth5.Layout.Row = 2;
            app.IcmsMonth5.Layout.Column = 4;

            % Create IcmsMonth6Label
            app.IcmsMonth6Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth6Label.FontSize = 10;
            app.IcmsMonth6Label.Layout.Row = 3;
            app.IcmsMonth6Label.Layout.Column = [3 4];
            app.IcmsMonth6Label.Text = 'JUN:';

            % Create IcmsMonth6
            app.IcmsMonth6 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth6.Step = 0.5;
            app.IcmsMonth6.Limits = [0 100];
            app.IcmsMonth6.ValueDisplayFormat = '%.1f';
            app.IcmsMonth6.Tag = '6';
            app.IcmsMonth6.FontSize = 11;
            app.IcmsMonth6.Enable = 'off';
            app.IcmsMonth6.Layout.Row = 3;
            app.IcmsMonth6.Layout.Column = 4;

            % Create IcmsMonth7Label
            app.IcmsMonth7Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth7Label.FontSize = 10;
            app.IcmsMonth7Label.Layout.Row = 1;
            app.IcmsMonth7Label.Layout.Column = [5 6];
            app.IcmsMonth7Label.Text = 'JUL:';

            % Create IcmsMonth7
            app.IcmsMonth7 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth7.Step = 0.5;
            app.IcmsMonth7.Limits = [0 100];
            app.IcmsMonth7.ValueDisplayFormat = '%.1f';
            app.IcmsMonth7.Tag = '7';
            app.IcmsMonth7.FontSize = 11;
            app.IcmsMonth7.Enable = 'off';
            app.IcmsMonth7.Layout.Row = 1;
            app.IcmsMonth7.Layout.Column = 6;

            % Create IcmsMonth8Label
            app.IcmsMonth8Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth8Label.FontSize = 10;
            app.IcmsMonth8Label.Layout.Row = 2;
            app.IcmsMonth8Label.Layout.Column = [5 6];
            app.IcmsMonth8Label.Text = 'AGO:';

            % Create IcmsMonth8
            app.IcmsMonth8 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth8.Step = 0.5;
            app.IcmsMonth8.Limits = [0 100];
            app.IcmsMonth8.ValueDisplayFormat = '%.1f';
            app.IcmsMonth8.Tag = '8';
            app.IcmsMonth8.FontSize = 11;
            app.IcmsMonth8.Enable = 'off';
            app.IcmsMonth8.Layout.Row = 2;
            app.IcmsMonth8.Layout.Column = 6;

            % Create IcmsMonth9Label
            app.IcmsMonth9Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth9Label.FontSize = 10;
            app.IcmsMonth9Label.Layout.Row = 3;
            app.IcmsMonth9Label.Layout.Column = [5 6];
            app.IcmsMonth9Label.Text = 'SET:';

            % Create IcmsMonth9
            app.IcmsMonth9 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth9.Step = 0.5;
            app.IcmsMonth9.Limits = [0 100];
            app.IcmsMonth9.ValueDisplayFormat = '%.1f';
            app.IcmsMonth9.Tag = '9';
            app.IcmsMonth9.FontSize = 11;
            app.IcmsMonth9.Enable = 'off';
            app.IcmsMonth9.Layout.Row = 3;
            app.IcmsMonth9.Layout.Column = 6;

            % Create IcmsMonth10Label
            app.IcmsMonth10Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth10Label.FontSize = 10;
            app.IcmsMonth10Label.Layout.Row = 1;
            app.IcmsMonth10Label.Layout.Column = [7 8];
            app.IcmsMonth10Label.Text = 'OUT:';

            % Create IcmsMonth10
            app.IcmsMonth10 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth10.Step = 0.5;
            app.IcmsMonth10.Limits = [0 100];
            app.IcmsMonth10.ValueDisplayFormat = '%.1f';
            app.IcmsMonth10.Tag = '10';
            app.IcmsMonth10.FontSize = 11;
            app.IcmsMonth10.Enable = 'off';
            app.IcmsMonth10.Layout.Row = 1;
            app.IcmsMonth10.Layout.Column = 8;

            % Create IcmsMonth11Label
            app.IcmsMonth11Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth11Label.FontSize = 10;
            app.IcmsMonth11Label.Layout.Row = 2;
            app.IcmsMonth11Label.Layout.Column = [7 8];
            app.IcmsMonth11Label.Text = 'NOV:';

            % Create IcmsMonth11
            app.IcmsMonth11 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth11.Step = 0.5;
            app.IcmsMonth11.Limits = [0 100];
            app.IcmsMonth11.ValueDisplayFormat = '%.1f';
            app.IcmsMonth11.Tag = '11';
            app.IcmsMonth11.FontSize = 11;
            app.IcmsMonth11.Enable = 'off';
            app.IcmsMonth11.Layout.Row = 2;
            app.IcmsMonth11.Layout.Column = 8;

            % Create IcmsMonth12Label
            app.IcmsMonth12Label = uilabel(app.IcmsRateByMonthGrid);
            app.IcmsMonth12Label.FontSize = 10;
            app.IcmsMonth12Label.Layout.Row = 3;
            app.IcmsMonth12Label.Layout.Column = [7 8];
            app.IcmsMonth12Label.Text = 'DEZ:';

            % Create IcmsMonth12
            app.IcmsMonth12 = uispinner(app.IcmsRateByMonthGrid);
            app.IcmsMonth12.Step = 0.5;
            app.IcmsMonth12.Limits = [0 100];
            app.IcmsMonth12.ValueDisplayFormat = '%.1f';
            app.IcmsMonth12.Tag = '12';
            app.IcmsMonth12.FontSize = 11;
            app.IcmsMonth12.Enable = 'off';
            app.IcmsMonth12.Layout.Row = 3;
            app.IcmsMonth12.Layout.Column = 8;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = dockIcmsRate_exported(Container, varargin)

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
