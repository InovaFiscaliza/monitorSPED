classdef winConfig_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        GridLayout                     matlab.ui.container.GridLayout
        dockModuleGrid                 matlab.ui.container.GridLayout
        dockModule_Undock              matlab.ui.control.Image
        dockModule_Close               matlab.ui.control.Image
        GridLayout2                    matlab.ui.container.GridLayout
        versionInfoRefresh             matlab.ui.control.Image
        openDevTools                   matlab.ui.control.Image
        TabGroup                       matlab.ui.container.TabGroup
        ASPECTOSGERAISTab              matlab.ui.container.Tab
        General_Grid                   matlab.ui.container.GridLayout
        AMBIENTELabel                  matlab.ui.control.Label
        openAuxiliarApp2Debug          matlab.ui.control.CheckBox
        openAuxiliarAppAsDocked        matlab.ui.control.CheckBox
        versionInfo                    matlab.ui.control.Label
        ANLISETab                      matlab.ui.container.Tab
        GridLayout_3                   matlab.ui.container.GridLayout
        Panel_2                        matlab.ui.container.Panel
        GridLayout4                    matlab.ui.container.GridLayout
        fontstylefontsize32pxfontTRABALHOEMANDAMENTOLabel  matlab.ui.control.Label
        PROCESSODEANLISEDOSDADOSLabel  matlab.ui.control.Label
        Panel                          matlab.ui.container.Panel
        GridLayout3                    matlab.ui.container.GridLayout
        Encoding                       matlab.ui.control.DropDown
        CODIFICAOTEXTUALLabel          matlab.ui.control.Label
        InputType                      matlab.ui.control.DropDown
        InputTypeLabel                 matlab.ui.control.Label
        PROCESSODELEITURADOSARQUIVOSLabel  matlab.ui.control.Label
        MAPEAMENTODEPASTASTab          matlab.ui.container.Tab
        FolderMapGrid                  matlab.ui.container.GridLayout
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
                customizationStatus = [false, false, false];
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

                        otherwise
                            % Customização de componentes constantes nas outras abas, 
                            % os quais são renderizados completamente apenas após a 
                            % abertura da aba.
                            % ...
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

            General_updatePanel(app)
            Analysis_updatePanel(app)
            Folder_updatePanel(app)
        end

        %-----------------------------------------------------------------%
        function General_updatePanel(app)
            % Versão:
            ui.TextView.update(app.versionInfo, util.HtmlTextGenerator.AppInfo(app.mainApp.General, app.mainApp.rootFolder, app.mainApp.executionMode));

            % Modo de operação:
            app.openAuxiliarAppAsDocked.Value   = app.mainApp.General.operationMode.Dock;
            app.openAuxiliarApp2Debug.Value     = app.mainApp.General.operationMode.Debug;
        end

        %-----------------------------------------------------------------%
        function Analysis_updatePanel(app)
            app.Encoding.Items = app.mainApp.General.sped.encoding.options;
            app.InputType.Value = app.mainApp.General.sped.input;
        end

        %-----------------------------------------------------------------%
        function Folder_updatePanel(app)
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

        % Image clicked function: versionInfoRefresh
        function AppEnvRefreshButtonPushed(app, event)
            
            app.progressDialog.Visible = 'visible';

            htmlContent = util.HtmlTextGenerator.checkUpdate(app.mainApp.General, app.mainApp.rootFolder);
            appUtil.modalWindow(app.UIFigure, "info", htmlContent);       

            app.progressDialog.Visible = 'hidden';

        end

        % Value changed function: Encoding, InputType, 
        % ...and 2 other components
        function ParameterValueChanged(app, event)
            
            switch event.Source
                case app.openAuxiliarAppAsDocked
                    app.mainApp.General.operationMode.Dock  = app.openAuxiliarAppAsDocked.Value;

                case app.openAuxiliarApp2Debug
                    app.mainApp.General.operationMode.Debug = app.openAuxiliarApp2Debug.Value;

                case app.InputType
                    app.mainApp.General.sped.input          = app.InputType.Value;

                case app.Encoding
                    app.mainApp.General.sped.encoding.value = app.Encoding.Value;
            end

            app.mainApp.General_I.operationMode = app.mainApp.General.operationMode;
            app.mainApp.General_I.sped          = app.mainApp.General.sped;
            saveGeneralSettings(app)

        end

        % Image clicked function: DataHubPOSTButton, userPathButton
        function FolderButtonPushed(app, event)
            
            try
                relatedFolder = eval(sprintf('app.config_Folder_%s.Value', event.Source.Tag));                    
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
            figure(app.UIFigure)

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
                Folder_updatePanel(app)
            end

        end

        % Image clicked function: openDevTools
        function openDevToolsClicked(app, event)
            
            ipcMainMatlabCallsHandler(app.mainApp, app, 'openDevTools')

        end

        % Image clicked function: dockModule_Close, dockModule_Undock
        function menu_DockButtonPushed(app, event)
            
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
        function TabGroupSelectionChanged(app, event)
            
            [~, tabIndex] = ismember(app.TabGroup.SelectedTab, app.TabGroup.Children);
            jsBackDoor_Customizations(app, tabIndex)
            
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
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
            app.TabGroup.Layout.Row = [3 4];
            app.TabGroup.Layout.Column = [2 3];

            % Create ASPECTOSGERAISTab
            app.ASPECTOSGERAISTab = uitab(app.TabGroup);
            app.ASPECTOSGERAISTab.AutoResizeChildren = 'off';
            app.ASPECTOSGERAISTab.Title = 'ℹ  ASPECTOS GERAIS';
            app.ASPECTOSGERAISTab.BackgroundColor = 'none';

            % Create General_Grid
            app.General_Grid = uigridlayout(app.ASPECTOSGERAISTab);
            app.General_Grid.ColumnWidth = {'1x'};
            app.General_Grid.RowHeight = {17, 150, 22, '1x', 1, 22, 15};
            app.General_Grid.RowSpacing = 5;
            app.General_Grid.BackgroundColor = [1 1 1];

            % Create versionInfo
            app.versionInfo = uilabel(app.General_Grid);
            app.versionInfo.BackgroundColor = [1 1 1];
            app.versionInfo.VerticalAlignment = 'top';
            app.versionInfo.WordWrap = 'on';
            app.versionInfo.FontSize = 11;
            app.versionInfo.FontColor = [0 0 0];
            app.versionInfo.Layout.Row = [2 4];
            app.versionInfo.Layout.Column = 1;
            app.versionInfo.Interpreter = 'html';
            app.versionInfo.Text = '';

            % Create openAuxiliarAppAsDocked
            app.openAuxiliarAppAsDocked = uicheckbox(app.General_Grid);
            app.openAuxiliarAppAsDocked.ValueChangedFcn = createCallbackFcn(app, @ParameterValueChanged, true);
            app.openAuxiliarAppAsDocked.Enable = 'off';
            app.openAuxiliarAppAsDocked.Text = 'Modo DOCK: módulos auxiliares abertos na janela principal do app';
            app.openAuxiliarAppAsDocked.FontSize = 11;
            app.openAuxiliarAppAsDocked.FontColor = [0 0 0];
            app.openAuxiliarAppAsDocked.Layout.Row = 6;
            app.openAuxiliarAppAsDocked.Layout.Column = 1;

            % Create openAuxiliarApp2Debug
            app.openAuxiliarApp2Debug = uicheckbox(app.General_Grid);
            app.openAuxiliarApp2Debug.ValueChangedFcn = createCallbackFcn(app, @ParameterValueChanged, true);
            app.openAuxiliarApp2Debug.Enable = 'off';
            app.openAuxiliarApp2Debug.Text = 'Modo DEBUG';
            app.openAuxiliarApp2Debug.FontSize = 11;
            app.openAuxiliarApp2Debug.FontColor = [0 0 0];
            app.openAuxiliarApp2Debug.Layout.Row = 7;
            app.openAuxiliarApp2Debug.Layout.Column = 1;

            % Create AMBIENTELabel
            app.AMBIENTELabel = uilabel(app.General_Grid);
            app.AMBIENTELabel.VerticalAlignment = 'bottom';
            app.AMBIENTELabel.FontSize = 10;
            app.AMBIENTELabel.Layout.Row = 1;
            app.AMBIENTELabel.Layout.Column = 1;
            app.AMBIENTELabel.Text = 'AMBIENTE:';

            % Create ANLISETab
            app.ANLISETab = uitab(app.TabGroup);
            app.ANLISETab.AutoResizeChildren = 'off';
            app.ANLISETab.Title = '📊  ANÁLISE';
            app.ANLISETab.BackgroundColor = 'none';

            % Create GridLayout_3
            app.GridLayout_3 = uigridlayout(app.ANLISETab);
            app.GridLayout_3.ColumnWidth = {'1x'};
            app.GridLayout_3.RowHeight = {17, 69, 22, '1x'};
            app.GridLayout_3.RowSpacing = 5;
            app.GridLayout_3.BackgroundColor = [1 1 1];

            % Create PROCESSODELEITURADOSARQUIVOSLabel
            app.PROCESSODELEITURADOSARQUIVOSLabel = uilabel(app.GridLayout_3);
            app.PROCESSODELEITURADOSARQUIVOSLabel.VerticalAlignment = 'bottom';
            app.PROCESSODELEITURADOSARQUIVOSLabel.FontSize = 10;
            app.PROCESSODELEITURADOSARQUIVOSLabel.Layout.Row = 1;
            app.PROCESSODELEITURADOSARQUIVOSLabel.Layout.Column = 1;
            app.PROCESSODELEITURADOSARQUIVOSLabel.Text = 'PROCESSO DE LEITURA DOS ARQUIVOS';

            % Create Panel
            app.Panel = uipanel(app.GridLayout_3);
            app.Panel.Layout.Row = 2;
            app.Panel.Layout.Column = 1;

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.Panel);
            app.GridLayout3.ColumnWidth = {130, 220};
            app.GridLayout3.RowHeight = {22, 22};
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
            app.InputType.ValueChangedFcn = createCallbackFcn(app, @ParameterValueChanged, true);
            app.InputType.FontSize = 11;
            app.InputType.BackgroundColor = [1 1 1];
            app.InputType.Layout.Row = 1;
            app.InputType.Layout.Column = 2;
            app.InputType.Value = 'file';

            % Create CODIFICAOTEXTUALLabel
            app.CODIFICAOTEXTUALLabel = uilabel(app.GridLayout3);
            app.CODIFICAOTEXTUALLabel.FontSize = 10;
            app.CODIFICAOTEXTUALLabel.FontColor = [0 0 0];
            app.CODIFICAOTEXTUALLabel.Layout.Row = 2;
            app.CODIFICAOTEXTUALLabel.Layout.Column = 1;
            app.CODIFICAOTEXTUALLabel.Text = 'CODIFICAÇÃO TEXTUAL:';

            % Create Encoding
            app.Encoding = uidropdown(app.GridLayout3);
            app.Encoding.Items = {};
            app.Encoding.ValueChangedFcn = createCallbackFcn(app, @ParameterValueChanged, true);
            app.Encoding.FontSize = 11;
            app.Encoding.FontColor = [0 0 0];
            app.Encoding.BackgroundColor = [1 1 1];
            app.Encoding.Layout.Row = 2;
            app.Encoding.Layout.Column = 2;
            app.Encoding.Value = {};

            % Create PROCESSODEANLISEDOSDADOSLabel
            app.PROCESSODEANLISEDOSDADOSLabel = uilabel(app.GridLayout_3);
            app.PROCESSODEANLISEDOSDADOSLabel.VerticalAlignment = 'bottom';
            app.PROCESSODEANLISEDOSDADOSLabel.FontSize = 10;
            app.PROCESSODEANLISEDOSDADOSLabel.Layout.Row = 3;
            app.PROCESSODEANLISEDOSDADOSLabel.Layout.Column = 1;
            app.PROCESSODEANLISEDOSDADOSLabel.Text = 'PROCESSO DE ANÁLISE DOS DADOS';

            % Create Panel_2
            app.Panel_2 = uipanel(app.GridLayout_3);
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

            % Create MAPEAMENTODEPASTASTab
            app.MAPEAMENTODEPASTASTab = uitab(app.TabGroup);
            app.MAPEAMENTODEPASTASTab.AutoResizeChildren = 'off';
            app.MAPEAMENTODEPASTASTab.Title = '📁  MAPEAMENTO DE PASTAS';
            app.MAPEAMENTODEPASTASTab.BackgroundColor = 'none';

            % Create FolderMapGrid
            app.FolderMapGrid = uigridlayout(app.MAPEAMENTODEPASTASTab);
            app.FolderMapGrid.ColumnWidth = {'1x', 20};
            app.FolderMapGrid.RowHeight = {17, 22, 22, 22, '1x'};
            app.FolderMapGrid.ColumnSpacing = 5;
            app.FolderMapGrid.RowSpacing = 5;
            app.FolderMapGrid.BackgroundColor = [1 1 1];

            % Create DATAHUBPOSTLabel
            app.DATAHUBPOSTLabel = uilabel(app.FolderMapGrid);
            app.DATAHUBPOSTLabel.VerticalAlignment = 'bottom';
            app.DATAHUBPOSTLabel.FontSize = 10;
            app.DATAHUBPOSTLabel.Layout.Row = 1;
            app.DATAHUBPOSTLabel.Layout.Column = 1;
            app.DATAHUBPOSTLabel.Text = 'DATAHUB - POST:';

            % Create DataHubPOST
            app.DataHubPOST = uieditfield(app.FolderMapGrid, 'text');
            app.DataHubPOST.Editable = 'off';
            app.DataHubPOST.FontSize = 11;
            app.DataHubPOST.FontColor = [0 0 0];
            app.DataHubPOST.Layout.Row = 2;
            app.DataHubPOST.Layout.Column = 1;

            % Create DataHubPOSTButton
            app.DataHubPOSTButton = uiimage(app.FolderMapGrid);
            app.DataHubPOSTButton.ImageClickedFcn = createCallbackFcn(app, @FolderButtonPushed, true);
            app.DataHubPOSTButton.Tag = 'DataHub_POST';
            app.DataHubPOSTButton.Enable = 'off';
            app.DataHubPOSTButton.Layout.Row = 2;
            app.DataHubPOSTButton.Layout.Column = 2;
            app.DataHubPOSTButton.ImageSource = 'OpenFile_36x36.png';

            % Create userPathLabel
            app.userPathLabel = uilabel(app.FolderMapGrid);
            app.userPathLabel.VerticalAlignment = 'bottom';
            app.userPathLabel.FontSize = 10;
            app.userPathLabel.Layout.Row = 3;
            app.userPathLabel.Layout.Column = 1;
            app.userPathLabel.Text = 'PASTA DO USUÁRIO:';

            % Create userPath
            app.userPath = uieditfield(app.FolderMapGrid, 'text');
            app.userPath.Editable = 'off';
            app.userPath.FontSize = 11;
            app.userPath.FontColor = [0 0 0];
            app.userPath.Layout.Row = 4;
            app.userPath.Layout.Column = 1;

            % Create userPathButton
            app.userPathButton = uiimage(app.FolderMapGrid);
            app.userPathButton.ImageClickedFcn = createCallbackFcn(app, @FolderButtonPushed, true);
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
            app.GridLayout2.Padding = [5 5 5 5];
            app.GridLayout2.Layout.Row = 6;
            app.GridLayout2.Layout.Column = [1 5];

            % Create openDevTools
            app.openDevTools = uiimage(app.GridLayout2);
            app.openDevTools.ScaleMethod = 'none';
            app.openDevTools.ImageClickedFcn = createCallbackFcn(app, @openDevToolsClicked, true);
            app.openDevTools.Enable = 'off';
            app.openDevTools.Tooltip = {'DevTools'};
            app.openDevTools.Layout.Row = 2;
            app.openDevTools.Layout.Column = 3;
            app.openDevTools.ImageSource = 'Debug_18.png';

            % Create versionInfoRefresh
            app.versionInfoRefresh = uiimage(app.GridLayout2);
            app.versionInfoRefresh.ScaleMethod = 'none';
            app.versionInfoRefresh.ImageClickedFcn = createCallbackFcn(app, @AppEnvRefreshButtonPushed, true);
            app.versionInfoRefresh.Enable = 'off';
            app.versionInfoRefresh.Tooltip = {'Verifica atualizações'};
            app.versionInfoRefresh.Layout.Row = 2;
            app.versionInfoRefresh.Layout.Column = 1;
            app.versionInfoRefresh.VerticalAlignment = 'bottom';
            app.versionInfoRefresh.ImageSource = 'Refresh_18.png';

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
            app.dockModule_Close.ImageClickedFcn = createCallbackFcn(app, @menu_DockButtonPushed, true);
            app.dockModule_Close.Tag = 'DRIVETEST';
            app.dockModule_Close.Tooltip = {'Fecha módulo'};
            app.dockModule_Close.Layout.Row = 1;
            app.dockModule_Close.Layout.Column = 2;
            app.dockModule_Close.ImageSource = 'Delete_12SVG_white.svg';

            % Create dockModule_Undock
            app.dockModule_Undock = uiimage(app.dockModuleGrid);
            app.dockModule_Undock.ScaleMethod = 'none';
            app.dockModule_Undock.ImageClickedFcn = createCallbackFcn(app, @menu_DockButtonPushed, true);
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
