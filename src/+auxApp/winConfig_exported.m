classdef winConfig_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        GridLayout                     matlab.ui.container.GridLayout
        dockModuleGrid                 matlab.ui.container.GridLayout
        dockModule_Undock              matlab.ui.control.Image
        dockModule_Close               matlab.ui.control.Image
        GridLayout2                    matlab.ui.container.GridLayout
        tool_simulationMode            matlab.ui.control.Image
        openDevTools                   matlab.ui.control.Image
        TabGroup                       matlab.ui.container.TabGroup
        Tab1                           matlab.ui.container.Tab
        Tab1Grid                       matlab.ui.container.GridLayout
        versionInfoRefresh             matlab.ui.control.Image
        AMBIENTELabel                  matlab.ui.control.Label
        openAuxiliarApp2Debug          matlab.ui.control.CheckBox
        openAuxiliarAppAsDocked        matlab.ui.control.CheckBox
        versionInfo                    matlab.ui.control.Label
        Tab2                           matlab.ui.container.Tab
        Tab2Grid                       matlab.ui.container.GridLayout
        Panel_2                        matlab.ui.container.Panel
        GridLayout4                    matlab.ui.container.GridLayout
        fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel  matlab.ui.control.Label
        PROCESSODEANLISEDOSDADOSLabel  matlab.ui.control.Label
        Panel_3                        matlab.ui.container.Panel
        GridLayout3                    matlab.ui.container.GridLayout
        Encoding                       matlab.ui.control.DropDown
        EncodingLabel                  matlab.ui.control.Label
        CheckStatus                    matlab.ui.control.DropDown
        CheckStatusLabel               matlab.ui.control.Label
        SortMethod                     matlab.ui.control.DropDown
        SortMethodLabel                matlab.ui.control.Label
        InputType                      matlab.ui.control.DropDown
        InputTypeLabel                 matlab.ui.control.Label
        PROCESSODELEITURADOSARQUIVOSEVISUALIZAODOSSEUSMETADADOSLabel  matlab.ui.control.Label
        Tab3                           matlab.ui.container.Tab
        Tab3Grid                       matlab.ui.container.GridLayout
        reportPanel                    matlab.ui.container.Panel
        reportGrid                     matlab.ui.container.GridLayout
        reportBasemap                  matlab.ui.control.DropDown
        reportBasemapLabel             matlab.ui.control.Label
        reportVersion                  matlab.ui.control.DropDown
        reportVersionLabel             matlab.ui.control.Label
        reportModelName                matlab.ui.control.DropDown
        reportoModelNameLabel          matlab.ui.control.Label
        reportLabel                    matlab.ui.control.Label
        eFiscalizaPanel                matlab.ui.container.Panel
        eFiscalizaGrid                 matlab.ui.container.GridLayout
        unit                           matlab.ui.control.DropDown
        unitLabel                      matlab.ui.control.Label
        issueId                        matlab.ui.control.NumericEditField
        issueIdLabel                   matlab.ui.control.Label
        systemVersion                  matlab.ui.control.DropDown
        systemVersionLabel             matlab.ui.control.Label
        eFiscalizaRefresh              matlab.ui.control.Image
        eFiscalizaLabel                matlab.ui.control.Label
        Tab4                           matlab.ui.container.Tab
        Tab4Grid                       matlab.ui.container.GridLayout
        userPathButton                 matlab.ui.control.Image
        userPath                       matlab.ui.control.EditField
        userPathLabel                  matlab.ui.control.Label
        DataHubPOSTButton              matlab.ui.control.Image
        DataHubPOST                    matlab.ui.control.EditField
        DATAHUBPOSTLabel               matlab.ui.control.Label
    end

    
    properties
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
    end


    methods
        %-----------------------------------------------------------------%
        % IPC: COMUNICAÇÃO ENTRE PROCESSOS
        %-----------------------------------------------------------------%
        function ipcSecundaryJSEventsHandler(app, event)
            try
                switch event.HTMLEventName
                    case 'renderer'
                        startup_Controller(app)
                        
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
        % JSBACKDOOR
        %-----------------------------------------------------------------%
        function jsBackDoor_Initialization(app)
            app.jsBackDoor = uihtml(app.UIFigure, "HTMLSource",           appUtil.jsBackDoorHTMLSource(),                 ...
                                                  "HTMLEventReceivedFcn", @(~, evt)ipcSecundaryJSEventsHandler(app, evt), ...
                                                  "Visible",              "off");
        end

        %-----------------------------------------------------------------%
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
                                elToModify = {app.dockModuleGrid};
                                elDataTag  = ui.CustomizationBase.getElementsDataTag(elToModify);
                                if ~isempty(elDataTag)
                                    sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', { ...
                                        struct('appName', appName, 'dataTag', elDataTag{1}, 'style', struct('transition', 'opacity 2s ease', 'opacity', '0.5')), ...
                                    });
                                end
                            end
                            
                            % Outros elementos:
                            elToModify = {app.versionInfo};
                            elDataTag  = ui.CustomizationBase.getElementsDataTag(elToModify);
                            if ~isempty(elDataTag)
                                ui.TextView.startup(app.jsBackDoor, app.versionInfo, appName);
                            end

                        case 2
                            updatePanel_Analysis(app)

                        case 3
                            updatePanel_Report(app)

                        case 4
                            updatePanel_Folder(app)
                    end
            end
        end
    end


    methods (Access = private)
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

            startup_GUIComponents(app)
        end

        %-----------------------------------------------------------------%
        function startup_GUIComponents(app)
            if ~strcmp(app.mainApp.executionMode, 'webApp')
                app.dockModule_Undock.Enable = 1;
                app.openDevTools.Enable = 1;

                set([app.DataHubPOSTButton, app.userPathButton], 'Enable', 1)
                app.versionInfoRefresh.Enable      = 1;
                app.openAuxiliarAppAsDocked.Enable = 1;
            end

            if ~isdeployed
                app.openAuxiliarApp2Debug.Enable = 1;
            end

            updatePanel_General(app)
        end

        %-----------------------------------------------------------------%
        function updatePanel_General(app)
            % Versão:
            ui.TextView.update(app.versionInfo, util.HtmlTextGenerator.AppInfo(app.mainApp.General, app.mainApp.rootFolder, app.mainApp.executionMode));

            % Modo de operação:
            app.openAuxiliarAppAsDocked.Value   = app.mainApp.General.operationMode.Dock;
            app.openAuxiliarApp2Debug.Value     = app.mainApp.General.operationMode.Debug;
        end

        %-----------------------------------------------------------------%
        function updatePanel_Analysis(app)
            app.InputType.Value = app.mainApp.General.sped.input;
            app.SortMethod.Value = app.mainApp.General.sped.sortMethod;
            app.Encoding.Items = app.mainApp.General.sped.encoding.options;            
        end

        %-----------------------------------------------------------------%
        function updatePanel_Report(app)
            app.systemVersion.Value = app.mainApp.General.Report.system;
            app.issueId.Value       = app.mainApp.General.Report.issue;
            set(app.unit,            'Items', app.mainApp.General.eFiscaliza.defaultValues.unit,    'Value', app.mainApp.General.Report.unit)
            set(app.reportModelName, 'Items', [{''}, {app.mainApp.projectData.documentModel.Name}], 'Value', app.mainApp.General.Report.model)
            app.reportVersion.Value = app.mainApp.General.Report.reportVersion;
            app.reportBasemap.Value = app.mainApp.General.Report.Basemap;

            if checkEdition(app, 'REPORT')
                app.eFiscalizaRefresh.Visible = 1;
            else
                app.eFiscalizaRefresh.Visible = 0;
            end
        end

        %-----------------------------------------------------------------%
        function updatePanel_Folder(app)
            DataHub_POST = app.mainApp.General.fileFolder.DataHub_POST;    
            if isfolder(DataHub_POST)
                app.DataHubPOST.Value = DataHub_POST;
            end

            app.userPath.Value = app.mainApp.General.fileFolder.userPath;                
        end

        %-----------------------------------------------------------------%
        function saveGeneralSettings(app)
            appUtil.generalSettingsSave(class.Constants.appName, app.mainApp.rootFolder, app.mainApp.General_I, app.mainApp.executionMode)
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainApp)
            
            app.mainApp = mainApp;

            if app.isDocked
                app.GridLayout.Padding(4) = 30;
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
                    
                    app.mainApp.tabGroupController.Components.appHandle{idx} = [];

                    inputArguments = ipcMainMatlabCallsHandler(app.mainApp, app, 'dockButtonPushed', auxAppTag);
                    openModule(app.mainApp.tabGroupController, relatedButton, false, appGeneral, inputArguments{:})
                    closeModule(app.mainApp.tabGroupController, auxAppTag, app.mainApp.General, 'undock')
                    
                    delete(app)

                case app.dockModule_Close
                    closeModule(app.mainApp.tabGroupController, auxAppTag, app.mainApp.General)
            end

        end

        % Selection change function: TabGroup
        function TabGroup_TabSelectionChanged(app, event)
            
            [~, tabIndex] = ismember(app.TabGroup.SelectedTab, app.TabGroup.Children);
            jsBackDoor_Customizations(app, tabIndex)
            
        end

        % Image clicked function: versionInfoRefresh
        function Toolbar_AppEnvRefreshButtonPushed(app, event)
            
            app.progressDialog.Visible = 'visible';

            htmlContent = util.HtmlTextGenerator.checkUpdate(app.mainApp.General, app.mainApp.rootFolder);
            appUtil.modalWindow(app.UIFigure, "info", htmlContent);       

            app.progressDialog.Visible = 'hidden';

        end

        % Image clicked function: tool_simulationMode
        function Toolbar_SimulationModeButtonPushed(app, event)
            
            msgQuestion   = 'Deseja abrir os arquivos de <b>simulação</b>?';
            userSelection = appUtil.modalWindow(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 2, 2);
            
            if strcmp(userSelection, 'Não')
                return
            end

            app.mainApp.General.operationMode.Simulation = true;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'simulationModeChanged')

        end

        % Image clicked function: openDevTools
        function Toolbar_OpenDevToolsClicked(app, event)
            
            ipcMainMatlabCallsHandler(app.mainApp, app, 'openDevTools')

        end

        % Value changed function: CheckStatus, Encoding, InputType, 
        % ...and 3 other components
        function Config_AnalysisParameterValueChanged(app, event)
            
            switch event.Source
                case app.openAuxiliarAppAsDocked
                    app.mainApp.General.operationMode.Dock  = app.openAuxiliarAppAsDocked.Value;

                case app.openAuxiliarApp2Debug
                    app.mainApp.General.operationMode.Debug = app.openAuxiliarApp2Debug.Value;

                case app.InputType
                    app.mainApp.General.sped.input          = app.InputType.Value;

                case app.SortMethod
                    app.mainApp.General.sped.sortMethod     = app.SortMethod.Value;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'fileSortMethodChanged')

                case app.CheckStatus
                    app.mainApp.General.sped.checkStatus    = app.CheckStatus.Value;

                case app.Encoding
                    app.mainApp.General.sped.encoding.value = app.Encoding.Value;
            end

            app.mainApp.General_I.operationMode = app.mainApp.General.operationMode;
            app.mainApp.General_I.sped          = app.mainApp.General.sped;
            saveGeneralSettings(app)

        end

        % Image clicked function: eFiscalizaRefresh
        function Config_ProjectRefreshImageClicked(app, event)
            
            if ~checkEdition(app, 'REPORT')
                app.eFiscalizaRefresh.Visible = 0;
                return
            
            else
                app.mainApp.General.Report   = app.defaultValues.Report;
                app.mainApp.General_I.Report = app.mainApp.General.Report;
                
                updatePanel_Report(app)
                saveGeneralSettings(app)
            end

        end

        % Value changed function: issueId, reportBasemap, reportModelName, 
        % ...and 3 other components
        function Config_ProjectParameterValueChanged(app, event)
            
            switch event.Source
                case app.systemVersion
                    app.mainApp.General.Report.system = event.Value;

                case app.issueId
                    if isinf(event.Value)
                        app.issueId.Value = event.PreviousValue;
                        return
                    end
                    app.mainApp.General.Report.issue  = event.Value;

                case app.unit
                    app.mainApp.General.Report.unit   = event.Value;

                case app.reportModelName
                    app.mainApp.General.Report.model  = event.Value;

                case app.reportVersion
                    app.mainApp.General.Report.reportVersion = event.Value;

                case app.reportBasemap
                    app.mainApp.General.Report.Basemap = event.Value;
            end

            app.mainApp.General_I.Report = app.mainApp.General.Report;

            updatePanel_Report(app)
            saveGeneralSettings(app)
            
        end

        % Image clicked function: DataHubPOSTButton, userPathButton
        function Config_FolderButtonPushed(app, event)
            
            try
                relatedFolder = eval(sprintf('app.%s.Value', event.Source.Tag));                    
            catch
                relatedFolder = app.mainApp.General.fileFolder.(event.Source.Tag);
            end
            
            if isfolder(relatedFolder)
                initialFolder = relatedFolder;
            elseif isfile(relatedFolder)
                initialFolder = fileparts(relatedFolder);
            else
                initialFolder = app.userPath.Value;
            end
            
            selectedFolder = uigetdir(initialFolder);
            if ~strcmp(app.mainApp.executionMode, 'webApp')
                figure(app.UIFigure)
            end

            if selectedFolder
                switch event.Source
                    case app.DataHubPOSTButton
                        if strcmp(app.mainApp.General.fileFolder.DataHub_POST, selectedFolder) 
                            return
                        else
                            selectedFolderFiles = dir(selectedFolder);
                            if ~ismember('.monitorsped_post', {selectedFolderFiles.name})
                                appUtil.modalWindow(app.UIFigure, 'error', 'Não se trata da pasta "DataHub - POST", do monitorSPED.');
                                return
                            end

                            app.DataHubPOST.Value = selectedFolder;
                            app.mainApp.General.fileFolder.DataHub_POST = selectedFolder;
    
                            ipcMainMatlabCallsHandler(app.mainApp, app, 'checkDataHubLampStatus')
                        end

                    case app.userPathButton
                        app.userPath.Value = selectedFolder;
                        app.mainApp.General.fileFolder.userPath = selectedFolder;
                end

                app.mainApp.General_I.fileFolder = app.mainApp.General.fileFolder;
                saveGeneralSettings(app)
                updatePanel_Folder(app)
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
            app.GridLayout.ColumnWidth = {10, '1x', 48, 8, 2};
            app.GridLayout.RowHeight = {2, 8, 24, '1x', 10, 34};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.AutoResizeChildren = 'off';
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroup_TabSelectionChanged, true);
            app.TabGroup.Layout.Row = [3 4];
            app.TabGroup.Layout.Column = [2 3];

            % Create Tab1
            app.Tab1 = uitab(app.TabGroup);
            app.Tab1.AutoResizeChildren = 'off';
            app.Tab1.Title = 'ASPECTOS GERAIS';
            app.Tab1.BackgroundColor = 'none';

            % Create Tab1Grid
            app.Tab1Grid = uigridlayout(app.Tab1);
            app.Tab1Grid.ColumnWidth = {'1x', 22};
            app.Tab1Grid.RowHeight = {17, 150, 22, '1x', 1, 22, 15};
            app.Tab1Grid.RowSpacing = 5;
            app.Tab1Grid.BackgroundColor = [1 1 1];

            % Create versionInfo
            app.versionInfo = uilabel(app.Tab1Grid);
            app.versionInfo.BackgroundColor = [1 1 1];
            app.versionInfo.VerticalAlignment = 'top';
            app.versionInfo.WordWrap = 'on';
            app.versionInfo.FontSize = 11;
            app.versionInfo.Layout.Row = [2 4];
            app.versionInfo.Layout.Column = [1 2];
            app.versionInfo.Interpreter = 'html';
            app.versionInfo.Text = '';

            % Create openAuxiliarAppAsDocked
            app.openAuxiliarAppAsDocked = uicheckbox(app.Tab1Grid);
            app.openAuxiliarAppAsDocked.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.openAuxiliarAppAsDocked.Enable = 'off';
            app.openAuxiliarAppAsDocked.Text = 'Modo DOCK: módulos auxiliares abertos na janela principal do app';
            app.openAuxiliarAppAsDocked.FontSize = 11;
            app.openAuxiliarAppAsDocked.Layout.Row = 6;
            app.openAuxiliarAppAsDocked.Layout.Column = [1 2];

            % Create openAuxiliarApp2Debug
            app.openAuxiliarApp2Debug = uicheckbox(app.Tab1Grid);
            app.openAuxiliarApp2Debug.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.openAuxiliarApp2Debug.Enable = 'off';
            app.openAuxiliarApp2Debug.Text = 'Modo DEBUG';
            app.openAuxiliarApp2Debug.FontSize = 11;
            app.openAuxiliarApp2Debug.Layout.Row = 7;
            app.openAuxiliarApp2Debug.Layout.Column = [1 2];

            % Create AMBIENTELabel
            app.AMBIENTELabel = uilabel(app.Tab1Grid);
            app.AMBIENTELabel.VerticalAlignment = 'bottom';
            app.AMBIENTELabel.FontSize = 10;
            app.AMBIENTELabel.Layout.Row = 1;
            app.AMBIENTELabel.Layout.Column = 1;
            app.AMBIENTELabel.Text = 'AMBIENTE:';

            % Create versionInfoRefresh
            app.versionInfoRefresh = uiimage(app.Tab1Grid);
            app.versionInfoRefresh.ScaleMethod = 'none';
            app.versionInfoRefresh.ImageClickedFcn = createCallbackFcn(app, @Toolbar_AppEnvRefreshButtonPushed, true);
            app.versionInfoRefresh.Enable = 'off';
            app.versionInfoRefresh.Tooltip = {'Verifica atualizações'};
            app.versionInfoRefresh.Layout.Row = 1;
            app.versionInfoRefresh.Layout.Column = 2;
            app.versionInfoRefresh.VerticalAlignment = 'bottom';
            app.versionInfoRefresh.ImageSource = 'Refresh_18.png';

            % Create Tab2
            app.Tab2 = uitab(app.TabGroup);
            app.Tab2.AutoResizeChildren = 'off';
            app.Tab2.Title = 'ANÁLISE';
            app.Tab2.BackgroundColor = 'none';

            % Create Tab2Grid
            app.Tab2Grid = uigridlayout(app.Tab2);
            app.Tab2Grid.ColumnWidth = {'1x'};
            app.Tab2Grid.RowHeight = {17, 126, 22, '1x'};
            app.Tab2Grid.RowSpacing = 5;
            app.Tab2Grid.BackgroundColor = [1 1 1];

            % Create PROCESSODELEITURADOSARQUIVOSEVISUALIZAODOSSEUSMETADADOSLabel
            app.PROCESSODELEITURADOSARQUIVOSEVISUALIZAODOSSEUSMETADADOSLabel = uilabel(app.Tab2Grid);
            app.PROCESSODELEITURADOSARQUIVOSEVISUALIZAODOSSEUSMETADADOSLabel.VerticalAlignment = 'bottom';
            app.PROCESSODELEITURADOSARQUIVOSEVISUALIZAODOSSEUSMETADADOSLabel.FontSize = 10;
            app.PROCESSODELEITURADOSARQUIVOSEVISUALIZAODOSSEUSMETADADOSLabel.Layout.Row = 1;
            app.PROCESSODELEITURADOSARQUIVOSEVISUALIZAODOSSEUSMETADADOSLabel.Layout.Column = 1;
            app.PROCESSODELEITURADOSARQUIVOSEVISUALIZAODOSSEUSMETADADOSLabel.Text = 'PROCESSO DE LEITURA DOS ARQUIVOS E VISUALIZAÇÃO DOS SEUS METADADOS';

            % Create Panel_3
            app.Panel_3 = uipanel(app.Tab2Grid);
            app.Panel_3.AutoResizeChildren = 'off';
            app.Panel_3.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.Panel_3.Layout.Row = 2;
            app.Panel_3.Layout.Column = 1;

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.Panel_3);
            app.GridLayout3.ColumnWidth = {150, 220, '1x'};
            app.GridLayout3.RowHeight = {22, 22, 22, 22};
            app.GridLayout3.RowSpacing = 5;
            app.GridLayout3.BackgroundColor = [1 1 1];

            % Create InputTypeLabel
            app.InputTypeLabel = uilabel(app.GridLayout3);
            app.InputTypeLabel.FontSize = 10;
            app.InputTypeLabel.Layout.Row = 1;
            app.InputTypeLabel.Layout.Column = 1;
            app.InputTypeLabel.Text = 'ENTRADA:';

            % Create InputType
            app.InputType = uidropdown(app.GridLayout3);
            app.InputType.Items = {'file', 'folder'};
            app.InputType.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.InputType.FontSize = 11;
            app.InputType.BackgroundColor = [1 1 1];
            app.InputType.Layout.Row = 1;
            app.InputType.Layout.Column = 2;
            app.InputType.Value = 'file';

            % Create SortMethodLabel
            app.SortMethodLabel = uilabel(app.GridLayout3);
            app.SortMethodLabel.FontSize = 10;
            app.SortMethodLabel.Layout.Row = 2;
            app.SortMethodLabel.Layout.Column = 1;
            app.SortMethodLabel.Text = 'VISUALIZAÇÃO ÁRVORE:';

            % Create SortMethod
            app.SortMethod = uidropdown(app.GridLayout3);
            app.SortMethod.Items = {'CNPJ', 'PERÍODO FISCAL', 'RECEITA FEDERAL'};
            app.SortMethod.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.SortMethod.FontSize = 11;
            app.SortMethod.BackgroundColor = [1 1 1];
            app.SortMethod.Layout.Row = 2;
            app.SortMethod.Layout.Column = 2;
            app.SortMethod.Value = 'CNPJ';

            % Create CheckStatusLabel
            app.CheckStatusLabel = uilabel(app.GridLayout3);
            app.CheckStatusLabel.FontSize = 10;
            app.CheckStatusLabel.Layout.Row = 3;
            app.CheckStatusLabel.Layout.Column = [1 2];
            app.CheckStatusLabel.Text = 'CONSULTA RECEITA FEDERAL:';

            % Create CheckStatus
            app.CheckStatus = uidropdown(app.GridLayout3);
            app.CheckStatus.Items = {'OnlyCache', 'Cache+RealTime', 'RealTime'};
            app.CheckStatus.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.CheckStatus.FontSize = 11;
            app.CheckStatus.BackgroundColor = [1 1 1];
            app.CheckStatus.Layout.Row = 3;
            app.CheckStatus.Layout.Column = 2;
            app.CheckStatus.Value = 'Cache+RealTime';

            % Create EncodingLabel
            app.EncodingLabel = uilabel(app.GridLayout3);
            app.EncodingLabel.FontSize = 10;
            app.EncodingLabel.Layout.Row = 4;
            app.EncodingLabel.Layout.Column = 1;
            app.EncodingLabel.Text = 'CODIFICAÇÃO CARACTERE:';

            % Create Encoding
            app.Encoding = uidropdown(app.GridLayout3);
            app.Encoding.Items = {};
            app.Encoding.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.Encoding.Enable = 'off';
            app.Encoding.FontSize = 11;
            app.Encoding.BackgroundColor = [1 1 1];
            app.Encoding.Layout.Row = 4;
            app.Encoding.Layout.Column = 2;
            app.Encoding.Value = {};

            % Create PROCESSODEANLISEDOSDADOSLabel
            app.PROCESSODEANLISEDOSDADOSLabel = uilabel(app.Tab2Grid);
            app.PROCESSODEANLISEDOSDADOSLabel.VerticalAlignment = 'bottom';
            app.PROCESSODEANLISEDOSDADOSLabel.FontSize = 10;
            app.PROCESSODEANLISEDOSDADOSLabel.Layout.Row = 3;
            app.PROCESSODEANLISEDOSDADOSLabel.Layout.Column = 1;
            app.PROCESSODEANLISEDOSDADOSLabel.Text = 'PROCESSO DE ANÁLISE DOS DADOS';

            % Create Panel_2
            app.Panel_2 = uipanel(app.Tab2Grid);
            app.Panel_2.AutoResizeChildren = 'off';
            app.Panel_2.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.Panel_2.Layout.Row = 4;
            app.Panel_2.Layout.Column = 1;

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.Panel_2);
            app.GridLayout4.ColumnWidth = {'1x'};
            app.GridLayout4.RowHeight = {'1x'};
            app.GridLayout4.RowSpacing = 5;
            app.GridLayout4.BackgroundColor = [1 1 1];

            % Create fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel
            app.fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel = uilabel(app.GridLayout4);
            app.fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel.HorizontalAlignment = 'center';
            app.fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel.WordWrap = 'on';
            app.fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel.FontSize = 14;
            app.fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel.FontWeight = 'bold';
            app.fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel.Layout.Row = 1;
            app.fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel.Layout.Column = 1;
            app.fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel.Interpreter = 'html';
            app.fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel.Text = {'<font style="font-size: 32px;">🚧</font>'; ''; 'TRABALHO EM '; 'ANDAMENTO'};

            % Create Tab3
            app.Tab3 = uitab(app.TabGroup);
            app.Tab3.AutoResizeChildren = 'off';
            app.Tab3.Title = 'PROJETO';

            % Create Tab3Grid
            app.Tab3Grid = uigridlayout(app.Tab3);
            app.Tab3Grid.ColumnWidth = {'1x', 22};
            app.Tab3Grid.RowHeight = {17, 100, 22, '1x'};
            app.Tab3Grid.RowSpacing = 5;
            app.Tab3Grid.BackgroundColor = [1 1 1];

            % Create eFiscalizaLabel
            app.eFiscalizaLabel = uilabel(app.Tab3Grid);
            app.eFiscalizaLabel.VerticalAlignment = 'bottom';
            app.eFiscalizaLabel.FontSize = 10;
            app.eFiscalizaLabel.Layout.Row = 1;
            app.eFiscalizaLabel.Layout.Column = 1;
            app.eFiscalizaLabel.Text = 'eFISCALIZA';

            % Create eFiscalizaRefresh
            app.eFiscalizaRefresh = uiimage(app.Tab3Grid);
            app.eFiscalizaRefresh.ScaleMethod = 'none';
            app.eFiscalizaRefresh.ImageClickedFcn = createCallbackFcn(app, @Config_ProjectRefreshImageClicked, true);
            app.eFiscalizaRefresh.Visible = 'off';
            app.eFiscalizaRefresh.Tooltip = {'Retorna às configurações iniciais'};
            app.eFiscalizaRefresh.Layout.Row = 1;
            app.eFiscalizaRefresh.Layout.Column = 2;
            app.eFiscalizaRefresh.VerticalAlignment = 'bottom';
            app.eFiscalizaRefresh.ImageSource = 'Refresh_18.png';

            % Create eFiscalizaPanel
            app.eFiscalizaPanel = uipanel(app.Tab3Grid);
            app.eFiscalizaPanel.AutoResizeChildren = 'off';
            app.eFiscalizaPanel.Layout.Row = 2;
            app.eFiscalizaPanel.Layout.Column = [1 2];

            % Create eFiscalizaGrid
            app.eFiscalizaGrid = uigridlayout(app.eFiscalizaPanel);
            app.eFiscalizaGrid.ColumnWidth = {350, 110, 110};
            app.eFiscalizaGrid.RowHeight = {22, 22, 22};
            app.eFiscalizaGrid.RowSpacing = 5;
            app.eFiscalizaGrid.BackgroundColor = [1 1 1];

            % Create systemVersionLabel
            app.systemVersionLabel = uilabel(app.eFiscalizaGrid);
            app.systemVersionLabel.WordWrap = 'on';
            app.systemVersionLabel.FontSize = 11;
            app.systemVersionLabel.Layout.Row = 1;
            app.systemVersionLabel.Layout.Column = 1;
            app.systemVersionLabel.Text = 'Versão do sistema:';

            % Create systemVersion
            app.systemVersion = uidropdown(app.eFiscalizaGrid);
            app.systemVersion.Items = {'eFiscaliza', 'eFiscaliza DS', 'eFiscaliza HM'};
            app.systemVersion.ValueChangedFcn = createCallbackFcn(app, @Config_ProjectParameterValueChanged, true);
            app.systemVersion.FontSize = 11;
            app.systemVersion.BackgroundColor = [1 1 1];
            app.systemVersion.Layout.Row = 1;
            app.systemVersion.Layout.Column = [2 3];
            app.systemVersion.Value = 'eFiscaliza';

            % Create issueIdLabel
            app.issueIdLabel = uilabel(app.eFiscalizaGrid);
            app.issueIdLabel.WordWrap = 'on';
            app.issueIdLabel.FontSize = 11;
            app.issueIdLabel.Layout.Row = 2;
            app.issueIdLabel.Layout.Column = 1;
            app.issueIdLabel.Text = 'Atividade de inspeção (# ID):';

            % Create issueId
            app.issueId = uieditfield(app.eFiscalizaGrid, 'numeric');
            app.issueId.Limits = [-1 Inf];
            app.issueId.RoundFractionalValues = 'on';
            app.issueId.ValueDisplayFormat = '%d';
            app.issueId.ValueChangedFcn = createCallbackFcn(app, @Config_ProjectParameterValueChanged, true);
            app.issueId.FontSize = 11;
            app.issueId.FontColor = [0.149 0.149 0.149];
            app.issueId.Layout.Row = 2;
            app.issueId.Layout.Column = 2;
            app.issueId.Value = -1;

            % Create unitLabel
            app.unitLabel = uilabel(app.eFiscalizaGrid);
            app.unitLabel.WordWrap = 'on';
            app.unitLabel.FontSize = 11;
            app.unitLabel.Layout.Row = 3;
            app.unitLabel.Layout.Column = 1;
            app.unitLabel.Text = 'Unidade responsável:';

            % Create unit
            app.unit = uidropdown(app.eFiscalizaGrid);
            app.unit.Items = {};
            app.unit.ValueChangedFcn = createCallbackFcn(app, @Config_ProjectParameterValueChanged, true);
            app.unit.FontSize = 11;
            app.unit.BackgroundColor = [1 1 1];
            app.unit.Layout.Row = 3;
            app.unit.Layout.Column = 2;
            app.unit.Value = {};

            % Create reportLabel
            app.reportLabel = uilabel(app.Tab3Grid);
            app.reportLabel.VerticalAlignment = 'bottom';
            app.reportLabel.FontSize = 10;
            app.reportLabel.Layout.Row = 3;
            app.reportLabel.Layout.Column = 1;
            app.reportLabel.Text = 'RELATÓRIO';

            % Create reportPanel
            app.reportPanel = uipanel(app.Tab3Grid);
            app.reportPanel.AutoResizeChildren = 'off';
            app.reportPanel.BackgroundColor = [1 1 1];
            app.reportPanel.Layout.Row = 4;
            app.reportPanel.Layout.Column = [1 2];

            % Create reportGrid
            app.reportGrid = uigridlayout(app.reportPanel);
            app.reportGrid.ColumnWidth = {350, 110, 110};
            app.reportGrid.RowHeight = {22, 22, 22};
            app.reportGrid.RowSpacing = 5;
            app.reportGrid.BackgroundColor = [1 1 1];

            % Create reportoModelNameLabel
            app.reportoModelNameLabel = uilabel(app.reportGrid);
            app.reportoModelNameLabel.FontSize = 11;
            app.reportoModelNameLabel.Layout.Row = 1;
            app.reportoModelNameLabel.Layout.Column = 1;
            app.reportoModelNameLabel.Text = 'Modelo (.json):';

            % Create reportModelName
            app.reportModelName = uidropdown(app.reportGrid);
            app.reportModelName.Items = {''};
            app.reportModelName.ValueChangedFcn = createCallbackFcn(app, @Config_ProjectParameterValueChanged, true);
            app.reportModelName.FontSize = 11;
            app.reportModelName.BackgroundColor = [1 1 1];
            app.reportModelName.Layout.Row = 1;
            app.reportModelName.Layout.Column = [2 3];
            app.reportModelName.Value = '';

            % Create reportVersionLabel
            app.reportVersionLabel = uilabel(app.reportGrid);
            app.reportVersionLabel.WordWrap = 'on';
            app.reportVersionLabel.FontSize = 11;
            app.reportVersionLabel.Layout.Row = 2;
            app.reportVersionLabel.Layout.Column = 1;
            app.reportVersionLabel.Text = 'Versão do relatório:';

            % Create reportVersion
            app.reportVersion = uidropdown(app.reportGrid);
            app.reportVersion.Items = {'Preliminar', 'Definitiva'};
            app.reportVersion.ValueChangedFcn = createCallbackFcn(app, @Config_ProjectParameterValueChanged, true);
            app.reportVersion.FontSize = 11;
            app.reportVersion.BackgroundColor = [1 1 1];
            app.reportVersion.Layout.Row = 2;
            app.reportVersion.Layout.Column = [2 3];
            app.reportVersion.Value = 'Preliminar';

            % Create reportBasemapLabel
            app.reportBasemapLabel = uilabel(app.reportGrid);
            app.reportBasemapLabel.FontSize = 11;
            app.reportBasemapLabel.Layout.Row = 3;
            app.reportBasemapLabel.Layout.Column = 1;
            app.reportBasemapLabel.Text = 'Basemap dos plots:';

            % Create reportBasemap
            app.reportBasemap = uidropdown(app.reportGrid);
            app.reportBasemap.Items = {'darkwater', 'none', 'satellite', 'streets-dark', 'streets-light', 'topographic'};
            app.reportBasemap.ValueChangedFcn = createCallbackFcn(app, @Config_ProjectParameterValueChanged, true);
            app.reportBasemap.FontSize = 11;
            app.reportBasemap.BackgroundColor = [1 1 1];
            app.reportBasemap.Layout.Row = 3;
            app.reportBasemap.Layout.Column = [2 3];
            app.reportBasemap.Value = 'darkwater';

            % Create Tab4
            app.Tab4 = uitab(app.TabGroup);
            app.Tab4.AutoResizeChildren = 'off';
            app.Tab4.Title = 'MAPEAMENTO DE PASTAS';
            app.Tab4.BackgroundColor = 'none';

            % Create Tab4Grid
            app.Tab4Grid = uigridlayout(app.Tab4);
            app.Tab4Grid.ColumnWidth = {'1x', 20};
            app.Tab4Grid.RowHeight = {17, 22, 22, 22, '1x'};
            app.Tab4Grid.ColumnSpacing = 5;
            app.Tab4Grid.RowSpacing = 5;
            app.Tab4Grid.BackgroundColor = [1 1 1];

            % Create DATAHUBPOSTLabel
            app.DATAHUBPOSTLabel = uilabel(app.Tab4Grid);
            app.DATAHUBPOSTLabel.VerticalAlignment = 'bottom';
            app.DATAHUBPOSTLabel.FontSize = 10;
            app.DATAHUBPOSTLabel.Layout.Row = 1;
            app.DATAHUBPOSTLabel.Layout.Column = 1;
            app.DATAHUBPOSTLabel.Text = 'DATAHUB - POST:';

            % Create DataHubPOST
            app.DataHubPOST = uieditfield(app.Tab4Grid, 'text');
            app.DataHubPOST.Editable = 'off';
            app.DataHubPOST.FontSize = 11;
            app.DataHubPOST.Layout.Row = 2;
            app.DataHubPOST.Layout.Column = 1;

            % Create DataHubPOSTButton
            app.DataHubPOSTButton = uiimage(app.Tab4Grid);
            app.DataHubPOSTButton.ImageClickedFcn = createCallbackFcn(app, @Config_FolderButtonPushed, true);
            app.DataHubPOSTButton.Tag = 'DataHub_POST';
            app.DataHubPOSTButton.Enable = 'off';
            app.DataHubPOSTButton.Layout.Row = 2;
            app.DataHubPOSTButton.Layout.Column = 2;
            app.DataHubPOSTButton.ImageSource = 'OpenFile_36x36.png';

            % Create userPathLabel
            app.userPathLabel = uilabel(app.Tab4Grid);
            app.userPathLabel.VerticalAlignment = 'bottom';
            app.userPathLabel.FontSize = 10;
            app.userPathLabel.Layout.Row = 3;
            app.userPathLabel.Layout.Column = 1;
            app.userPathLabel.Text = 'PASTA DO USUÁRIO:';

            % Create userPath
            app.userPath = uieditfield(app.Tab4Grid, 'text');
            app.userPath.Editable = 'off';
            app.userPath.FontSize = 11;
            app.userPath.Layout.Row = 4;
            app.userPath.Layout.Column = 1;

            % Create userPathButton
            app.userPathButton = uiimage(app.Tab4Grid);
            app.userPathButton.ImageClickedFcn = createCallbackFcn(app, @Config_FolderButtonPushed, true);
            app.userPathButton.Tag = 'userPath';
            app.userPathButton.Enable = 'off';
            app.userPathButton.Layout.Row = 4;
            app.userPathButton.Layout.Column = 2;
            app.userPathButton.ImageSource = 'OpenFile_36x36.png';

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.GridLayout);
            app.GridLayout2.ColumnWidth = {22, '1x', 22};
            app.GridLayout2.RowHeight = {4, 17, 2};
            app.GridLayout2.ColumnSpacing = 5;
            app.GridLayout2.RowSpacing = 0;
            app.GridLayout2.Padding = [10 5 10 5];
            app.GridLayout2.Layout.Row = 6;
            app.GridLayout2.Layout.Column = [1 5];
            app.GridLayout2.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];

            % Create openDevTools
            app.openDevTools = uiimage(app.GridLayout2);
            app.openDevTools.ScaleMethod = 'none';
            app.openDevTools.ImageClickedFcn = createCallbackFcn(app, @Toolbar_OpenDevToolsClicked, true);
            app.openDevTools.Enable = 'off';
            app.openDevTools.Tooltip = {'Abre DevTools'};
            app.openDevTools.Layout.Row = 2;
            app.openDevTools.Layout.Column = 3;
            app.openDevTools.ImageSource = 'Debug_18.png';

            % Create tool_simulationMode
            app.tool_simulationMode = uiimage(app.GridLayout2);
            app.tool_simulationMode.ScaleMethod = 'none';
            app.tool_simulationMode.ImageClickedFcn = createCallbackFcn(app, @Toolbar_SimulationModeButtonPushed, true);
            app.tool_simulationMode.Tooltip = {'Leitura arquivos de simulação'};
            app.tool_simulationMode.Layout.Row = 2;
            app.tool_simulationMode.Layout.Column = 1;
            app.tool_simulationMode.ImageSource = 'Import_16.png';

            % Create dockModuleGrid
            app.dockModuleGrid = uigridlayout(app.GridLayout);
            app.dockModuleGrid.RowHeight = {'1x'};
            app.dockModuleGrid.ColumnSpacing = 2;
            app.dockModuleGrid.Padding = [5 2 5 2];
            app.dockModuleGrid.Visible = 'off';
            app.dockModuleGrid.Layout.Row = [2 3];
            app.dockModuleGrid.Layout.Column = [3 4];
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
        function app = winConfig_exported(Container, varargin)

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
