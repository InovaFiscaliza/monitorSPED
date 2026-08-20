classdef winConfig_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        GridLayout                    matlab.ui.container.GridLayout
        DockModule                    matlab.ui.container.GridLayout
        dockModule_Close              matlab.ui.control.Image
        dockModule_Undock             matlab.ui.control.Image
        SubTabGroup                   matlab.ui.container.TabGroup
        SubTab1                       matlab.ui.container.Tab
        SubGrid1                      matlab.ui.container.GridLayout
        openAuxiliarApp2Debug         matlab.ui.control.CheckBox
        openAuxiliarAppAsDocked       matlab.ui.control.CheckBox
        versionInfo                   matlab.ui.control.Label
        versionInfoRefresh            matlab.ui.control.Image
        versionInfoLabel              matlab.ui.control.Label
        SubTab2                       matlab.ui.container.Tab
        SubGrid2                      matlab.ui.container.GridLayout
        configAnalysisPanel2          matlab.ui.container.Panel
        configAnalysisGrid2           matlab.ui.container.GridLayout
        AddAccountDescription         matlab.ui.control.CheckBox
        Cofins                        matlab.ui.control.Spinner
        CofinsLabel                   matlab.ui.control.Label
        PIS                           matlab.ui.control.Spinner
        PISLabel                      matlab.ui.control.Label
        ICMS                          matlab.ui.control.Spinner
        ICMSLabel                     matlab.ui.control.Label
        CheckStatus                   matlab.ui.control.DropDown
        CheckStatusLabel              matlab.ui.control.Label
        configAnalysisPanel2Label     matlab.ui.control.Label
        configAnalysisPanel1          matlab.ui.container.Panel
        configAnalysisGrid1           matlab.ui.container.GridLayout
        LargeFileThresholdBytes       matlab.ui.control.Spinner
        LargeFileThresholdBytesLabel  matlab.ui.control.Label
        EncodingOverride              matlab.ui.control.DropDown
        EncodingOverrideLabel         matlab.ui.control.Label
        SortMethod                    matlab.ui.control.DropDown
        SortMethodLabel               matlab.ui.control.Label
        InputType                     matlab.ui.control.DropDown
        InputTypeLabel                matlab.ui.control.Label
        configAnalysisRefresh         matlab.ui.control.Image
        configAnalysisPanel1Label     matlab.ui.control.Label
        SubTab3                       matlab.ui.container.Tab
        SubGrid3                      matlab.ui.container.GridLayout
        reportPanel                   matlab.ui.container.Panel
        reportGrid                    matlab.ui.container.GridLayout
        prjFileCompressionMode        matlab.ui.control.DropDown
        prjFileCompressionModeLabel   matlab.ui.control.Label
        reportLabel                   matlab.ui.control.Label
        eFiscalizaPanel               matlab.ui.container.Panel
        eFiscalizaGrid                matlab.ui.container.GridLayout
        SubthemesButton               matlab.ui.control.Image
        SubthemesList                 matlab.ui.control.EditField
        SubthemesLabel                matlab.ui.control.Label
        reportUnit                    matlab.ui.control.DropDown
        reportUnitLabel               matlab.ui.control.Label
        reportSystem                  matlab.ui.control.DropDown
        reportSystemLabel             matlab.ui.control.Label
        eFiscalizaRefresh             matlab.ui.control.Image
        eFiscalizaLabel               matlab.ui.control.Label
        SubTab4                       matlab.ui.container.Tab
        SubGrid4                      matlab.ui.container.GridLayout
        userPathButton                matlab.ui.control.Image
        userPath                      matlab.ui.control.EditField
        userPathLabel                 matlab.ui.control.Label
        DataHubPOSTButton             matlab.ui.control.Image
        DataHubPOST                   matlab.ui.control.EditField
        DATAHUBPOSTLabel              matlab.ui.control.Label
        Toolbar                       matlab.ui.container.GridLayout
        tool_openDevTools             matlab.ui.control.Image
        tool_simulationMode           matlab.ui.control.Image
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        Role = 'secondaryApp'
        Context = 'CONFIG'
    end


    properties (Access = public)
        %-----------------------------------------------------------------%
        Container
        isDocked = false
        mainApp
        jsBackDoor
        progressDialog
    end


    properties (Access = private)
        %-----------------------------------------------------------------%
        defaultValues
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
        function applyJSCustomizations(app, tabIndex)
            if app.SubTabGroup.UserData.isTabInitialized(tabIndex)
                return
            end
            app.SubTabGroup.UserData.isTabInitialized(tabIndex) = true;
            
            appName = class(app);
            switch tabIndex
                case 1
                    elToModify = {
                        app.versionInfo;
                        app.versionInfoRefresh;
                        app.tool_simulationMode;
                        app.tool_openDevTools;
                        app.dockModule_Undock;
                        app.dockModule_Close
                    };
                    ui.CustomizationBase.getElementsDataTag(elToModify);

                    try
                        ui.TextView.startup(app.jsBackDoor, app.versionInfo, appName);
                    catch
                    end

                    try
                        sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', { ...
                            struct('appName', appName, 'dataTag', app.versionInfoRefresh.UserData.id,  'tooltip', struct('defaultPosition', 'top',    'textContent', 'Verifica atualizações')), ...
                            struct('appName', appName, 'dataTag', app.tool_simulationMode.UserData.id, 'tooltip', struct('defaultPosition', 'top',    'textContent', 'Leitura arquivos de simulação')), ...
                            struct('appName', appName, 'dataTag', app.tool_openDevTools.UserData.id,   'tooltip', struct('defaultPosition', 'top',    'textContent', 'Abre DevTools')), ...
                            struct('appName', appName, 'dataTag', app.dockModule_Undock.UserData.id,   'tooltip', struct('defaultPosition', 'bottom', 'textContent', 'Reabre módulo em outra janela')), ...
                            struct('appName', appName, 'dataTag', app.dockModule_Close.UserData.id,    'tooltip', struct('defaultPosition', 'bottom', 'textContent', 'Fecha módulo')) ...
                        });
                    catch
                    end

                case 2
                    elToModify = {
                        app.configAnalysisRefresh
                    };
                    ui.CustomizationBase.getElementsDataTag(elToModify);

                    try
                        sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', { ...
                            struct('appName', appName, 'dataTag', app.configAnalysisRefresh.UserData.id, 'tooltip', struct('defaultPosition', 'top', 'textContent', 'Retorna às configurações iniciais')) ...
                        });
                    catch
                    end

                    if ~strcmp(app.mainApp.executionMode, 'webApp')
                        app.InputType.Enable = "on";
                    end
                    app.EncodingOverride.Items = [{''}; app.mainApp.General.context.FILE.encodingList]';
                    updatePanel_Analysis(app)

                case 3
                    ui.CustomizationBase.getElementsDataTag({app.SubthemesButton});

                    try
                        sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', { ...
                            struct('appName', class(app), 'dataTag', app.SubthemesButton.UserData.id, 'tooltip', struct('defaultPosition', 'top', 'textContent', 'Habilita ou desabilita a edição da lista de subtemas<br>Ex: "Tributário - FUST", "Tributário - FUNTTEL", ""')) ...
                        });
                    catch
                    end

                    updatePanel_Report(app)

                case 4
                    if ~strcmp(app.mainApp.executionMode, 'webApp')
                        set([app.DataHubPOSTButton, app.userPathButton], 'Enable', 1)
                    end
                    updatePanel_Folder(app)
            end
        end

        %-----------------------------------------------------------------%
        function initializeAppProperties(app)
            % Lê a versão de "GeneralSettings.json" que vem junto ao
            % projeto (e não a versão armazenada em "ProgramData").
            projectFolder   = appEngine.util.Path(class.Constants.appName, app.mainApp.rootFolder);
            projectFilePath = fullfile(projectFolder, 'GeneralSettings.json');
            projectGeneral  = jsondecode(fileread(projectFilePath));

            app.defaultValues = struct( ...
                'FILE',      projectGeneral.context.FILE, ...
                'ECD',       projectGeneral.context.ECD, ...
                'reportLib', projectGeneral.reportLib ...
            );
        end

        %-----------------------------------------------------------------%
        function initializeUIComponents(app)
            if ~strcmp(app.mainApp.executionMode, 'webApp')
                app.dockModule_Undock.Enable       = 1;
                app.tool_openDevTools.Enable       = 1;                
                app.versionInfoRefresh.Enable      = 1;
                app.openAuxiliarAppAsDocked.Enable = 1;
            end

            if ~isdeployed
                app.openAuxiliarApp2Debug.Enable   = 1;
            end
        end

        %-----------------------------------------------------------------%
        function applyInitialLayout(app)
            % Versão:
            appInfo = util.HtmlTextGenerator.AppInfo( ...
                app.mainApp.General, ...
                app.mainApp.rootFolder, ...
                app.mainApp.executionMode, ...
                app.mainApp.renderCount, ...
                "textview" ...
            );
            ui.TextView.update(app.versionInfo, appInfo);

            % Modo de operação:
            app.openAuxiliarAppAsDocked.Value = app.mainApp.General.operationMode.Dock;
            app.openAuxiliarApp2Debug.Value   = app.mainApp.General.operationMode.Debug;
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function updatePanel_Analysis(app)
            % FILE
            app.InputType.Value   = app.mainApp.General.context.FILE.input;
            app.SortMethod.Value  = app.mainApp.General.context.FILE.sortMethod;
            app.CheckStatus.Value = app.mainApp.General.context.FILE.checkStatus;
            app.LargeFileThresholdBytes.Value = app.mainApp.General.context.FILE.largeFileThresholdBytes;

            % ECD
            app.ICMS.Value   = 100 * app.mainApp.General.context.ECD.taxConfig.ICMS_INTERCONEXAO;
            app.PIS.Value    = 100 * app.mainApp.General.context.ECD.taxConfig.PIS;
            app.Cofins.Value = 100 * app.mainApp.General.context.ECD.taxConfig.COFINS;
            app.AddAccountDescription.Value = app.mainApp.General.context.ECD.accountDescriptionScope;

            app.configAnalysisRefresh.Visible = checkEdition(app, 'ANALYSIS');
        end

        %-----------------------------------------------------------------%
        function updatePanel_Report(app)
            app.reportSystem.Value = app.mainApp.General.reportLib.system;
            set(app.reportUnit, 'Items', app.mainApp.General.eFiscaliza.defaultValues.unit, 'Value', app.mainApp.General.reportLib.unit)

            app.SubthemesButton.UserData.status = false;
            app.SubthemesButton.ImageSource = 'Edit_32.png';
            set(app.SubthemesList, 'Editable', 'off', 'FontColor', [0.65,0.65,0.65], 'Value', textFormatGUI.cellstr2ListWithQuotes(app.mainApp.General.reportLib.allowedSubthemes, 'none'))
            
            if ismember(app.mainApp.General.reportLib.outputCompressionMode, app.prjFileCompressionMode.Items)
                app.prjFileCompressionMode.Value = app.mainApp.General.reportLib.outputCompressionMode;
            end

            app.eFiscalizaRefresh.Visible = checkEdition(app, 'REPORT');
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
        function editionFlag = checkEdition(app, tabName)
            editionFlag   = false;
            currentValues = struct( ...
                'FILE',      app.mainApp.General.context.FILE, ...
                'ECD',       app.mainApp.General.context.ECD, ...
                'reportLib', app.mainApp.General.reportLib ...
            );

            switch tabName
                case 'ANALYSIS'
                    if ~isequal(rmfield(currentValues, 'reportLib'), rmfield(app.defaultValues, 'reportLib'))
                        editionFlag = true;
                    end
                case 'REPORT'
                    if ~isequal(currentValues.reportLib, app.defaultValues.reportLib)
                        editionFlag = true;
                    end
            end
        end

        %-----------------------------------------------------------------%
        function saveGeneralSettings(app)
            appEngine.util.generalSettingsSave(class.Constants.appName, app.mainApp.rootFolder, app.mainApp.General_I, app.mainApp.executionMode)
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
                    
                    app.mainApp.tabGroupController.Components.appHandle{idx} = [];

                    inputArguments = ipcMainMatlabCallsHandler(app.mainApp, app, 'dockButtonPushed', auxAppTag);
                    openModule(app.mainApp.tabGroupController, relatedButton, false, appGeneral, inputArguments{:})
                    closeModule(app.mainApp.tabGroupController, auxAppTag, app.mainApp.General, 'undock')
                    
                    delete(app)

                case app.dockModule_Close
                    closeModule(app.mainApp.tabGroupController, auxAppTag, app.mainApp.General)
            end

        end

        % Selection change function: SubTabGroup
        function SubTabGroup_TabSelectionChanged(app, event)
            
            [~, tabIndex] = ismember(app.SubTabGroup.SelectedTab, app.SubTabGroup.Children);
            applyJSCustomizations(app, tabIndex)
            
        end

        % Image clicked function: versionInfoRefresh
        function Toolbar_AppEnvRefreshButtonPushed(app, event)
            
            app.progressDialog.Visible = 'visible';

            htmlContent = util.HtmlTextGenerator.checkUpdate(app.mainApp.General, app.mainApp.rootFolder);
            ui.Dialog(app.UIFigure, "info", htmlContent);       

            app.progressDialog.Visible = 'hidden';

        end

        % Image clicked function: tool_simulationMode
        function Toolbar_SimulationModeButtonPushed(app, event)
            
            msgQuestion   = 'Deseja abrir os arquivos de <b>simulação</b>?';
            userSelection = ui.Dialog(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 2, 2);
            
            if strcmp(userSelection, 'Não')
                return
            end

            app.mainApp.General.operationMode.Simulation = true;
            ipcMainMatlabCallsHandler(app.mainApp, app, 'simulationModeChanged')

        end

        % Image clicked function: tool_openDevTools
        function Toolbar_OpenDevToolsClicked(app, event)
            
            ipcMainMatlabCallsHandler(app.mainApp, app, 'openDevTools')

        end

        % Value changed function: openAuxiliarApp2Debug, 
        % ...and 1 other component
        function Config_GeneralParameterValueChanged(app, event)
            
            switch event.Source
                case app.openAuxiliarAppAsDocked
                    app.mainApp.General.operationMode.Dock  = app.openAuxiliarAppAsDocked.Value;

                case app.openAuxiliarApp2Debug
                    app.mainApp.General.operationMode.Debug = app.openAuxiliarApp2Debug.Value;
            end

            app.mainApp.General_I.operationMode = app.mainApp.General.operationMode;
            saveGeneralSettings(app)
            
        end

        % Image clicked function: configAnalysisRefresh
        function Config_AnalysisRefreshImageClicked(app, event)
            
            if ~checkEdition(app, 'ANALYSIS')
                app.configAnalysisRefresh.Visible = 0;
                return

            else
                app.mainApp.General.context.FILE = app.defaultValues.FILE;
                app.mainApp.General.context.ECD  = app.defaultValues.ECD;

                if ~isequal(app.mainApp.General.context.FILE.sortMethod, app.SortMethod.Value)
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'fileSortMethodChanged')
                end

                app.mainApp.General_I.context.FILE = app.mainApp.General.context.FILE;
                app.mainApp.General_I.context.ECD  = app.mainApp.General.context.ECD;

                updatePanel_Analysis(app)
                saveGeneralSettings(app)
            end

        end

        % Value changed function: AddAccountDescription, CheckStatus, 
        % ...and 7 other components
        function Config_AnalysisParameterValueChanged(app, event)
            
            switch event.Source
                case app.InputType
                    app.mainApp.General.context.FILE.input = app.InputType.Value;

                case app.SortMethod
                    app.mainApp.General.context.FILE.sortMethod = app.SortMethod.Value;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'fileSortMethodChanged')

                case app.CheckStatus
                    app.mainApp.General.context.FILE.checkStatus = app.CheckStatus.Value;

                case app.EncodingOverride
                    app.mainApp.General.context.FILE.encodingOverride = app.EncodingOverride.Value;
                    return

                case app.LargeFileThresholdBytes
                    app.mainApp.General.context.FILE.largeFileThresholdBytes = app.LargeFileThresholdBytes.Value;

                case app.ICMS
                    app.mainApp.General.context.ECD.taxConfig.ICMS_INTERCONEXAO = app.ICMS.Value / 100;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'onICMSTaxChanged')

                case app.PIS
                    app.mainApp.General.context.ECD.taxConfig.PIS = app.PIS.Value / 100;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'onPISTaxChanged')

                case app.Cofins
                    app.mainApp.General.context.ECD.taxConfig.COFINS = app.Cofins.Value / 100;
                    ipcMainMatlabCallsHandler(app.mainApp, app, 'onCOFINSTaxChanged')

                case app.AddAccountDescription
                    app.mainApp.General.context.ECD.accountDescriptionScope = app.AddAccountDescription.Value;
            end

            app.mainApp.General_I.context.FILE = app.mainApp.General.context.FILE;
            app.mainApp.General_I.context.ECD  = app.mainApp.General.context.ECD;

            updatePanel_Analysis(app)
            saveGeneralSettings(app)

        end

        % Image clicked function: eFiscalizaRefresh
        function Config_ProjectRefreshImageClicked(app, event)
            
            if ~checkEdition(app, 'REPORT')
                app.eFiscalizaRefresh.Visible = 0;
                return
            
            else
                app.mainApp.General.reportLib   = app.defaultValues.reportLib;
                app.mainApp.General_I.reportLib = app.mainApp.General.reportLib;
                
                updatePanel_Report(app)
                saveGeneralSettings(app)
            end

        end

        % Value changed function: prjFileCompressionMode, reportSystem, 
        % ...and 1 other component
        function Config_ProjectParameterValueChanged(app, event)
            
            switch event.Source
                case app.reportSystem
                    app.mainApp.General.reportLib.system = event.Value;

                case app.reportUnit
                    app.mainApp.General.reportLib.unit = event.Value;

                case app.prjFileCompressionMode
                    app.mainApp.General.reportLib.outputCompressionMode = event.Value;
            end

            app.mainApp.General_I.reportLib = app.mainApp.General.reportLib;

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
                                ui.Dialog(app.UIFigure, 'error', 'Não se trata da pasta "DataHub - POST", do monitorSPED.');
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

        % Callback function: SubthemesButton, SubthemesList
        function Config_SubthemesEdition(app, event)
            
            switch event.Source
                case app.SubthemesButton
                    app.SubthemesButton.UserData.status = ~app.SubthemesButton.UserData.status;
                    if app.SubthemesButton.UserData.status
                        app.SubthemesButton.ImageSource = 'Edit_32Filled.png';
                        set(app.SubthemesList, 'Editable', 'on', 'FontColor', [0,0,0])
                    else
                        app.SubthemesButton.ImageSource = 'Edit_32.png';
                        set(app.SubthemesList, 'Editable', 'off', 'FontColor', [0.65,0.65,0.65])
                    end

                case app.SubthemesList
                    parts = strsplit(event.Value, ',');
                    try
                        requiredSubthemes = unique(strtrim(extractBetween(parts, '"', '"')));
                    catch
                        app.SubthemesList.Value = event.PreviousValue;
                        return
                    end

                    currentSubthemes = sort(app.mainApp.General.reportLib.allowedSubthemes);

                    if numel(requiredSubthemes) ~= numel(parts) || isequal(currentSubthemes, requiredSubthemes)
                        app.SubthemesList.Value = event.PreviousValue;
                        return
                    end

                    msgQuestion = sprintf([ ...
                        'LISTA ATUAL:\n%s\n\nLISTA PROPOSTA:\n%s\n\n' ...
                        'Confirma a troca da lista de subtemas?' ...
                    ], textFormatGUI.cellstr2ListWithQuotes(currentSubthemes, 'none'), textFormatGUI.cellstr2ListWithQuotes(requiredSubthemes, 'none'));

                    userSelection = ui.Dialog(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 1, 2);
                    if userSelection == "Não"
                        app.SubthemesList.Value = event.PreviousValue;
                        return
                    end

                    app.mainApp.General.reportLib.allowedSubthemes = requiredSubthemes;
                    app.mainApp.General_I.reportLib = app.mainApp.General.reportLib;

                    updatePanel_Report(app)
                    saveGeneralSettings(app)
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
            app.GridLayout.ColumnWidth = {10, '1x', 48, 8, 2};
            app.GridLayout.RowHeight = {2, 8, 24, '1x', 10, 34};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create Toolbar
            app.Toolbar = uigridlayout(app.GridLayout);
            app.Toolbar.ColumnWidth = {22, '1x', 22};
            app.Toolbar.RowHeight = {4, 17, 2};
            app.Toolbar.ColumnSpacing = 5;
            app.Toolbar.RowSpacing = 0;
            app.Toolbar.Padding = [10 5 10 5];
            app.Toolbar.Layout.Row = 6;
            app.Toolbar.Layout.Column = [1 5];
            app.Toolbar.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];

            % Create tool_simulationMode
            app.tool_simulationMode = uiimage(app.Toolbar);
            app.tool_simulationMode.ScaleMethod = 'none';
            app.tool_simulationMode.ImageClickedFcn = createCallbackFcn(app, @Toolbar_SimulationModeButtonPushed, true);
            app.tool_simulationMode.Layout.Row = [1 3];
            app.tool_simulationMode.Layout.Column = 1;
            app.tool_simulationMode.ImageSource = 'Import_16.png';

            % Create tool_openDevTools
            app.tool_openDevTools = uiimage(app.Toolbar);
            app.tool_openDevTools.ScaleMethod = 'none';
            app.tool_openDevTools.ImageClickedFcn = createCallbackFcn(app, @Toolbar_OpenDevToolsClicked, true);
            app.tool_openDevTools.Enable = 'off';
            app.tool_openDevTools.Layout.Row = [1 3];
            app.tool_openDevTools.Layout.Column = 3;
            app.tool_openDevTools.ImageSource = 'Debug_18.png';

            % Create SubTabGroup
            app.SubTabGroup = uitabgroup(app.GridLayout);
            app.SubTabGroup.AutoResizeChildren = 'off';
            app.SubTabGroup.SelectionChangedFcn = createCallbackFcn(app, @SubTabGroup_TabSelectionChanged, true);
            app.SubTabGroup.Layout.Row = [3 4];
            app.SubTabGroup.Layout.Column = [2 3];

            % Create SubTab1
            app.SubTab1 = uitab(app.SubTabGroup);
            app.SubTab1.AutoResizeChildren = 'off';
            app.SubTab1.Title = 'ASPECTOS GERAIS';
            app.SubTab1.BackgroundColor = 'none';

            % Create SubGrid1
            app.SubGrid1 = uigridlayout(app.SubTab1);
            app.SubGrid1.ColumnWidth = {'1x', 22};
            app.SubGrid1.RowHeight = {17, 150, 22, '1x', 1, 22, 15};
            app.SubGrid1.RowSpacing = 5;
            app.SubGrid1.BackgroundColor = [1 1 1];

            % Create versionInfoLabel
            app.versionInfoLabel = uilabel(app.SubGrid1);
            app.versionInfoLabel.VerticalAlignment = 'bottom';
            app.versionInfoLabel.FontSize = 10;
            app.versionInfoLabel.Layout.Row = 1;
            app.versionInfoLabel.Layout.Column = 1;
            app.versionInfoLabel.Text = 'AMBIENTE:';

            % Create versionInfoRefresh
            app.versionInfoRefresh = uiimage(app.SubGrid1);
            app.versionInfoRefresh.ScaleMethod = 'none';
            app.versionInfoRefresh.ImageClickedFcn = createCallbackFcn(app, @Toolbar_AppEnvRefreshButtonPushed, true);
            app.versionInfoRefresh.Enable = 'off';
            app.versionInfoRefresh.Layout.Row = 1;
            app.versionInfoRefresh.Layout.Column = 2;
            app.versionInfoRefresh.ImageSource = 'Refresh_18.png';

            % Create versionInfo
            app.versionInfo = uilabel(app.SubGrid1);
            app.versionInfo.BackgroundColor = [1 1 1];
            app.versionInfo.VerticalAlignment = 'top';
            app.versionInfo.WordWrap = 'on';
            app.versionInfo.FontSize = 11;
            app.versionInfo.Layout.Row = [2 4];
            app.versionInfo.Layout.Column = [1 2];
            app.versionInfo.Interpreter = 'html';
            app.versionInfo.Text = '';

            % Create openAuxiliarAppAsDocked
            app.openAuxiliarAppAsDocked = uicheckbox(app.SubGrid1);
            app.openAuxiliarAppAsDocked.ValueChangedFcn = createCallbackFcn(app, @Config_GeneralParameterValueChanged, true);
            app.openAuxiliarAppAsDocked.Enable = 'off';
            app.openAuxiliarAppAsDocked.Text = 'Modo DOCK: módulos auxiliares abertos na janela principal do app';
            app.openAuxiliarAppAsDocked.FontSize = 11;
            app.openAuxiliarAppAsDocked.Layout.Row = 6;
            app.openAuxiliarAppAsDocked.Layout.Column = [1 2];
            app.openAuxiliarAppAsDocked.Value = true;

            % Create openAuxiliarApp2Debug
            app.openAuxiliarApp2Debug = uicheckbox(app.SubGrid1);
            app.openAuxiliarApp2Debug.ValueChangedFcn = createCallbackFcn(app, @Config_GeneralParameterValueChanged, true);
            app.openAuxiliarApp2Debug.Enable = 'off';
            app.openAuxiliarApp2Debug.Text = 'Modo DEBUG';
            app.openAuxiliarApp2Debug.FontSize = 11;
            app.openAuxiliarApp2Debug.Layout.Row = 7;
            app.openAuxiliarApp2Debug.Layout.Column = [1 2];

            % Create SubTab2
            app.SubTab2 = uitab(app.SubTabGroup);
            app.SubTab2.AutoResizeChildren = 'off';
            app.SubTab2.Title = 'ANÁLISE';
            app.SubTab2.BackgroundColor = 'none';

            % Create SubGrid2
            app.SubGrid2 = uigridlayout(app.SubTab2);
            app.SubGrid2.ColumnWidth = {'1x', 22};
            app.SubGrid2.RowHeight = {17, 133, 22, '1x'};
            app.SubGrid2.RowSpacing = 5;
            app.SubGrid2.BackgroundColor = [1 1 1];

            % Create configAnalysisPanel1Label
            app.configAnalysisPanel1Label = uilabel(app.SubGrid2);
            app.configAnalysisPanel1Label.VerticalAlignment = 'bottom';
            app.configAnalysisPanel1Label.FontSize = 10;
            app.configAnalysisPanel1Label.Layout.Row = 1;
            app.configAnalysisPanel1Label.Layout.Column = 1;
            app.configAnalysisPanel1Label.Text = 'PROCESSO DE LEITURA DOS ARQUIVOS E VISUALIZAÇÃO DOS SEUS METADADOS';

            % Create configAnalysisRefresh
            app.configAnalysisRefresh = uiimage(app.SubGrid2);
            app.configAnalysisRefresh.ScaleMethod = 'none';
            app.configAnalysisRefresh.ImageClickedFcn = createCallbackFcn(app, @Config_AnalysisRefreshImageClicked, true);
            app.configAnalysisRefresh.Visible = 'off';
            app.configAnalysisRefresh.Layout.Row = 1;
            app.configAnalysisRefresh.Layout.Column = 2;
            app.configAnalysisRefresh.ImageSource = 'Refresh_18.png';

            % Create configAnalysisPanel1
            app.configAnalysisPanel1 = uipanel(app.SubGrid2);
            app.configAnalysisPanel1.AutoResizeChildren = 'off';
            app.configAnalysisPanel1.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.configAnalysisPanel1.Layout.Row = 2;
            app.configAnalysisPanel1.Layout.Column = [1 2];

            % Create configAnalysisGrid1
            app.configAnalysisGrid1 = uigridlayout(app.configAnalysisPanel1);
            app.configAnalysisGrid1.ColumnWidth = {110, 110, 110, 110};
            app.configAnalysisGrid1.RowHeight = {17, 22, 32, 22};
            app.configAnalysisGrid1.RowSpacing = 5;
            app.configAnalysisGrid1.BackgroundColor = [1 1 1];

            % Create InputTypeLabel
            app.InputTypeLabel = uilabel(app.configAnalysisGrid1);
            app.InputTypeLabel.VerticalAlignment = 'bottom';
            app.InputTypeLabel.FontSize = 11;
            app.InputTypeLabel.Layout.Row = 1;
            app.InputTypeLabel.Layout.Column = 1;
            app.InputTypeLabel.Text = 'Entrada:';

            % Create InputType
            app.InputType = uidropdown(app.configAnalysisGrid1);
            app.InputType.Items = {'file', 'folder'};
            app.InputType.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.InputType.Enable = 'off';
            app.InputType.FontSize = 11;
            app.InputType.BackgroundColor = [1 1 1];
            app.InputType.Layout.Row = 2;
            app.InputType.Layout.Column = 1;
            app.InputType.Value = 'file';

            % Create SortMethodLabel
            app.SortMethodLabel = uilabel(app.configAnalysisGrid1);
            app.SortMethodLabel.VerticalAlignment = 'bottom';
            app.SortMethodLabel.FontSize = 11;
            app.SortMethodLabel.Layout.Row = 1;
            app.SortMethodLabel.Layout.Column = [2 3];
            app.SortMethodLabel.Text = 'Visualização árvore:';

            % Create SortMethod
            app.SortMethod = uidropdown(app.configAnalysisGrid1);
            app.SortMethod.Items = {'CNPJ', 'PERÍODO FISCAL', 'RECEITA FEDERAL'};
            app.SortMethod.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.SortMethod.FontSize = 11;
            app.SortMethod.BackgroundColor = [1 1 1];
            app.SortMethod.Layout.Row = 2;
            app.SortMethod.Layout.Column = [2 3];
            app.SortMethod.Value = 'CNPJ';

            % Create EncodingOverrideLabel
            app.EncodingOverrideLabel = uilabel(app.configAnalysisGrid1);
            app.EncodingOverrideLabel.VerticalAlignment = 'bottom';
            app.EncodingOverrideLabel.WordWrap = 'on';
            app.EncodingOverrideLabel.FontSize = 11;
            app.EncodingOverrideLabel.Layout.Row = 3;
            app.EncodingOverrideLabel.Layout.Column = [1 2];
            app.EncodingOverrideLabel.Text = {'Codificação textual do arquivo:'; '(Padrão: ISO-8859-1)'};

            % Create EncodingOverride
            app.EncodingOverride = uidropdown(app.configAnalysisGrid1);
            app.EncodingOverride.Items = {'', 'ISO-8859-1', 'UTF-8'};
            app.EncodingOverride.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.EncodingOverride.FontSize = 11;
            app.EncodingOverride.BackgroundColor = [1 1 1];
            app.EncodingOverride.Layout.Row = 4;
            app.EncodingOverride.Layout.Column = [1 2];
            app.EncodingOverride.Value = '';

            % Create LargeFileThresholdBytesLabel
            app.LargeFileThresholdBytesLabel = uilabel(app.configAnalysisGrid1);
            app.LargeFileThresholdBytesLabel.VerticalAlignment = 'bottom';
            app.LargeFileThresholdBytesLabel.FontSize = 11;
            app.LargeFileThresholdBytesLabel.Layout.Row = 3;
            app.LargeFileThresholdBytesLabel.Layout.Column = [3 4];
            app.LargeFileThresholdBytesLabel.Text = {'Tamanho mínimo para '; 'arquivo grande (bytes):'};

            % Create LargeFileThresholdBytes
            app.LargeFileThresholdBytes = uispinner(app.configAnalysisGrid1);
            app.LargeFileThresholdBytes.Step = 10000000;
            app.LargeFileThresholdBytes.Limits = [50000000 100000000];
            app.LargeFileThresholdBytes.RoundFractionalValues = 'on';
            app.LargeFileThresholdBytes.ValueDisplayFormat = '%d';
            app.LargeFileThresholdBytes.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.LargeFileThresholdBytes.FontSize = 11;
            app.LargeFileThresholdBytes.Layout.Row = 4;
            app.LargeFileThresholdBytes.Layout.Column = 3;
            app.LargeFileThresholdBytes.Value = 50000000;

            % Create configAnalysisPanel2Label
            app.configAnalysisPanel2Label = uilabel(app.SubGrid2);
            app.configAnalysisPanel2Label.VerticalAlignment = 'bottom';
            app.configAnalysisPanel2Label.FontSize = 10;
            app.configAnalysisPanel2Label.Layout.Row = 3;
            app.configAnalysisPanel2Label.Layout.Column = 1;
            app.configAnalysisPanel2Label.Text = 'PROCESSO DE ANÁLISE DOS DADOS: VALORES PADRÕES DE TRIBUTOS + VISUALIZAÇÃO COLUNA "CTA"';

            % Create configAnalysisPanel2
            app.configAnalysisPanel2 = uipanel(app.SubGrid2);
            app.configAnalysisPanel2.AutoResizeChildren = 'off';
            app.configAnalysisPanel2.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.configAnalysisPanel2.Layout.Row = 4;
            app.configAnalysisPanel2.Layout.Column = [1 2];

            % Create configAnalysisGrid2
            app.configAnalysisGrid2 = uigridlayout(app.configAnalysisPanel2);
            app.configAnalysisGrid2.ColumnWidth = {110, 110, 110, '1x'};
            app.configAnalysisGrid2.RowHeight = {27, 22, 32, 22, 1, 22};
            app.configAnalysisGrid2.RowSpacing = 5;
            app.configAnalysisGrid2.BackgroundColor = [1 1 1];

            % Create CheckStatusLabel
            app.CheckStatusLabel = uilabel(app.configAnalysisGrid2);
            app.CheckStatusLabel.VerticalAlignment = 'bottom';
            app.CheckStatusLabel.WordWrap = 'on';
            app.CheckStatusLabel.FontSize = 11;
            app.CheckStatusLabel.Layout.Row = 1;
            app.CheckStatusLabel.Layout.Column = [1 2];
            app.CheckStatusLabel.Text = 'Consulta situação de arquivo na Receita Federal:';

            % Create CheckStatus
            app.CheckStatus = uidropdown(app.configAnalysisGrid2);
            app.CheckStatus.Items = {'OnlyCache', 'Cache+RealTime', 'RealTime'};
            app.CheckStatus.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.CheckStatus.FontSize = 11;
            app.CheckStatus.BackgroundColor = [1 1 1];
            app.CheckStatus.Layout.Row = 2;
            app.CheckStatus.Layout.Column = [1 2];
            app.CheckStatus.Value = 'Cache+RealTime';

            % Create ICMSLabel
            app.ICMSLabel = uilabel(app.configAnalysisGrid2);
            app.ICMSLabel.VerticalAlignment = 'bottom';
            app.ICMSLabel.FontSize = 11;
            app.ICMSLabel.Layout.Row = 3;
            app.ICMSLabel.Layout.Column = [1 2];
            app.ICMSLabel.Text = {'Valor padrão ICMS'; 'INTERCONEXÃO: (%)'};

            % Create ICMS
            app.ICMS = uispinner(app.configAnalysisGrid2);
            app.ICMS.Step = 0.1;
            app.ICMS.Limits = [0 Inf];
            app.ICMS.ValueDisplayFormat = '%.2f';
            app.ICMS.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.ICMS.FontSize = 11;
            app.ICMS.Layout.Row = 4;
            app.ICMS.Layout.Column = 1;

            % Create PISLabel
            app.PISLabel = uilabel(app.configAnalysisGrid2);
            app.PISLabel.VerticalAlignment = 'bottom';
            app.PISLabel.FontSize = 11;
            app.PISLabel.Layout.Row = 3;
            app.PISLabel.Layout.Column = 2;
            app.PISLabel.Text = {'Valor padrão PIS:'; '(%)'};

            % Create PIS
            app.PIS = uispinner(app.configAnalysisGrid2);
            app.PIS.Step = 0.1;
            app.PIS.Limits = [0 Inf];
            app.PIS.ValueDisplayFormat = '%.2f';
            app.PIS.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.PIS.FontSize = 11;
            app.PIS.Layout.Row = 4;
            app.PIS.Layout.Column = 2;
            app.PIS.Value = 0.65;

            % Create CofinsLabel
            app.CofinsLabel = uilabel(app.configAnalysisGrid2);
            app.CofinsLabel.VerticalAlignment = 'bottom';
            app.CofinsLabel.FontSize = 11;
            app.CofinsLabel.Layout.Row = 3;
            app.CofinsLabel.Layout.Column = 3;
            app.CofinsLabel.Text = {'Valor padrão COFINS:'; '(%)'};

            % Create Cofins
            app.Cofins = uispinner(app.configAnalysisGrid2);
            app.Cofins.Step = 0.1;
            app.Cofins.Limits = [0 Inf];
            app.Cofins.ValueDisplayFormat = '%.2f';
            app.Cofins.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.Cofins.FontSize = 11;
            app.Cofins.Layout.Row = 4;
            app.Cofins.Layout.Column = 3;
            app.Cofins.Value = 3;

            % Create AddAccountDescription
            app.AddAccountDescription = uicheckbox(app.configAnalysisGrid2);
            app.AddAccountDescription.ValueChangedFcn = createCallbackFcn(app, @Config_AnalysisParameterValueChanged, true);
            app.AddAccountDescription.Text = 'Habilita a inclusão da descrição da conta (coluna "CTA") sempre que o registro em análise possuir a coluna "COD_CTA".';
            app.AddAccountDescription.FontSize = 11;
            app.AddAccountDescription.Layout.Row = 6;
            app.AddAccountDescription.Layout.Column = [1 4];

            % Create SubTab3
            app.SubTab3 = uitab(app.SubTabGroup);
            app.SubTab3.AutoResizeChildren = 'off';
            app.SubTab3.Title = 'PROJETO';

            % Create SubGrid3
            app.SubGrid3 = uigridlayout(app.SubTab3);
            app.SubGrid3.ColumnWidth = {'1x', 22};
            app.SubGrid3.RowHeight = {17, 78, 22, '1x'};
            app.SubGrid3.RowSpacing = 5;
            app.SubGrid3.BackgroundColor = [1 1 1];

            % Create eFiscalizaLabel
            app.eFiscalizaLabel = uilabel(app.SubGrid3);
            app.eFiscalizaLabel.VerticalAlignment = 'bottom';
            app.eFiscalizaLabel.FontSize = 10;
            app.eFiscalizaLabel.Layout.Row = 1;
            app.eFiscalizaLabel.Layout.Column = 1;
            app.eFiscalizaLabel.Text = 'INICIALIZAÇÃO eFISCALIZA';

            % Create eFiscalizaRefresh
            app.eFiscalizaRefresh = uiimage(app.SubGrid3);
            app.eFiscalizaRefresh.ScaleMethod = 'none';
            app.eFiscalizaRefresh.ImageClickedFcn = createCallbackFcn(app, @Config_ProjectRefreshImageClicked, true);
            app.eFiscalizaRefresh.Visible = 'off';
            app.eFiscalizaRefresh.Layout.Row = 1;
            app.eFiscalizaRefresh.Layout.Column = 2;
            app.eFiscalizaRefresh.VerticalAlignment = 'bottom';
            app.eFiscalizaRefresh.ImageSource = 'Refresh_18.png';

            % Create eFiscalizaPanel
            app.eFiscalizaPanel = uipanel(app.SubGrid3);
            app.eFiscalizaPanel.AutoResizeChildren = 'off';
            app.eFiscalizaPanel.Layout.Row = 2;
            app.eFiscalizaPanel.Layout.Column = [1 2];

            % Create eFiscalizaGrid
            app.eFiscalizaGrid = uigridlayout(app.eFiscalizaPanel);
            app.eFiscalizaGrid.ColumnWidth = {230, 110, '1x', 18};
            app.eFiscalizaGrid.RowHeight = {27, 22};
            app.eFiscalizaGrid.RowSpacing = 5;
            app.eFiscalizaGrid.BackgroundColor = [1 1 1];

            % Create reportSystemLabel
            app.reportSystemLabel = uilabel(app.eFiscalizaGrid);
            app.reportSystemLabel.FontSize = 11;
            app.reportSystemLabel.Layout.Row = 1;
            app.reportSystemLabel.Layout.Column = 1;
            app.reportSystemLabel.Text = {'Ambiente do sistema de gestão à'; 'fiscalização:'};

            % Create reportSystem
            app.reportSystem = uidropdown(app.eFiscalizaGrid);
            app.reportSystem.Items = {'eFiscaliza', 'eFiscaliza TS', 'eFiscaliza HM', 'eFiscaliza DS'};
            app.reportSystem.ValueChangedFcn = createCallbackFcn(app, @Config_ProjectParameterValueChanged, true);
            app.reportSystem.FontSize = 11;
            app.reportSystem.BackgroundColor = [1 1 1];
            app.reportSystem.Layout.Row = 2;
            app.reportSystem.Layout.Column = 1;
            app.reportSystem.Value = 'eFiscaliza';

            % Create reportUnitLabel
            app.reportUnitLabel = uilabel(app.eFiscalizaGrid);
            app.reportUnitLabel.WordWrap = 'on';
            app.reportUnitLabel.FontSize = 11;
            app.reportUnitLabel.Layout.Row = 1;
            app.reportUnitLabel.Layout.Column = 2;
            app.reportUnitLabel.Text = 'Unidade responsável pela fiscalização:';

            % Create reportUnit
            app.reportUnit = uidropdown(app.eFiscalizaGrid);
            app.reportUnit.Items = {};
            app.reportUnit.ValueChangedFcn = createCallbackFcn(app, @Config_ProjectParameterValueChanged, true);
            app.reportUnit.FontSize = 11;
            app.reportUnit.BackgroundColor = [1 1 1];
            app.reportUnit.Layout.Row = 2;
            app.reportUnit.Layout.Column = 2;
            app.reportUnit.Value = {};

            % Create SubthemesLabel
            app.SubthemesLabel = uilabel(app.eFiscalizaGrid);
            app.SubthemesLabel.FontSize = 11;
            app.SubthemesLabel.Layout.Row = 1;
            app.SubthemesLabel.Layout.Column = 3;
            app.SubthemesLabel.Text = {'Subtemas aceitos para fins de'; 'elaboração do relato:'};

            % Create SubthemesList
            app.SubthemesList = uieditfield(app.eFiscalizaGrid, 'text');
            app.SubthemesList.ValueChangedFcn = createCallbackFcn(app, @Config_SubthemesEdition, true);
            app.SubthemesList.Editable = 'off';
            app.SubthemesList.FontSize = 11;
            app.SubthemesList.FontColor = [0.651 0.651 0.651];
            app.SubthemesList.Layout.Row = 2;
            app.SubthemesList.Layout.Column = [3 4];

            % Create SubthemesButton
            app.SubthemesButton = uiimage(app.eFiscalizaGrid);
            app.SubthemesButton.ImageClickedFcn = createCallbackFcn(app, @Config_SubthemesEdition, true);
            app.SubthemesButton.Layout.Row = 1;
            app.SubthemesButton.Layout.Column = 4;
            app.SubthemesButton.VerticalAlignment = 'bottom';
            app.SubthemesButton.ImageSource = 'Edit_32.png';

            % Create reportLabel
            app.reportLabel = uilabel(app.SubGrid3);
            app.reportLabel.VerticalAlignment = 'bottom';
            app.reportLabel.FontSize = 10;
            app.reportLabel.Layout.Row = 3;
            app.reportLabel.Layout.Column = 1;
            app.reportLabel.Text = 'OUTROS ASPECTOS RELACIONADOS AO PROJETO';

            % Create reportPanel
            app.reportPanel = uipanel(app.SubGrid3);
            app.reportPanel.AutoResizeChildren = 'off';
            app.reportPanel.BackgroundColor = [1 1 1];
            app.reportPanel.Layout.Row = 4;
            app.reportPanel.Layout.Column = [1 2];

            % Create reportGrid
            app.reportGrid = uigridlayout(app.reportPanel);
            app.reportGrid.ColumnWidth = {110, '1x'};
            app.reportGrid.RowHeight = {17, 22};
            app.reportGrid.RowSpacing = 5;
            app.reportGrid.BackgroundColor = [1 1 1];

            % Create prjFileCompressionModeLabel
            app.prjFileCompressionModeLabel = uilabel(app.reportGrid);
            app.prjFileCompressionModeLabel.FontSize = 11;
            app.prjFileCompressionModeLabel.Layout.Row = 1;
            app.prjFileCompressionModeLabel.Layout.Column = [1 2];
            app.prjFileCompressionModeLabel.Text = 'Compressão aplicada ao arquivo de saída do projeto?';

            % Create prjFileCompressionMode
            app.prjFileCompressionMode = uidropdown(app.reportGrid);
            app.prjFileCompressionMode.Items = {'Não', 'Sim'};
            app.prjFileCompressionMode.ValueChangedFcn = createCallbackFcn(app, @Config_ProjectParameterValueChanged, true);
            app.prjFileCompressionMode.FontSize = 11;
            app.prjFileCompressionMode.BackgroundColor = [1 1 1];
            app.prjFileCompressionMode.Layout.Row = 2;
            app.prjFileCompressionMode.Layout.Column = 1;
            app.prjFileCompressionMode.Value = 'Sim';

            % Create SubTab4
            app.SubTab4 = uitab(app.SubTabGroup);
            app.SubTab4.AutoResizeChildren = 'off';
            app.SubTab4.Title = 'MAPEAMENTO DE PASTAS';
            app.SubTab4.BackgroundColor = 'none';

            % Create SubGrid4
            app.SubGrid4 = uigridlayout(app.SubTab4);
            app.SubGrid4.ColumnWidth = {'1x', 20};
            app.SubGrid4.RowHeight = {17, 22, 22, 22, '1x'};
            app.SubGrid4.ColumnSpacing = 5;
            app.SubGrid4.RowSpacing = 5;
            app.SubGrid4.BackgroundColor = [1 1 1];

            % Create DATAHUBPOSTLabel
            app.DATAHUBPOSTLabel = uilabel(app.SubGrid4);
            app.DATAHUBPOSTLabel.VerticalAlignment = 'bottom';
            app.DATAHUBPOSTLabel.FontSize = 10;
            app.DATAHUBPOSTLabel.Layout.Row = 1;
            app.DATAHUBPOSTLabel.Layout.Column = 1;
            app.DATAHUBPOSTLabel.Text = 'DATAHUB - POST:';

            % Create DataHubPOST
            app.DataHubPOST = uieditfield(app.SubGrid4, 'text');
            app.DataHubPOST.Editable = 'off';
            app.DataHubPOST.FontSize = 11;
            app.DataHubPOST.Layout.Row = 2;
            app.DataHubPOST.Layout.Column = 1;

            % Create DataHubPOSTButton
            app.DataHubPOSTButton = uiimage(app.SubGrid4);
            app.DataHubPOSTButton.ScaleMethod = 'none';
            app.DataHubPOSTButton.ImageClickedFcn = createCallbackFcn(app, @Config_FolderButtonPushed, true);
            app.DataHubPOSTButton.Tag = 'DataHub_POST';
            app.DataHubPOSTButton.Enable = 'off';
            app.DataHubPOSTButton.Layout.Row = 2;
            app.DataHubPOSTButton.Layout.Column = 2;
            app.DataHubPOSTButton.ImageSource = 'folder-opened-16px.svg';

            % Create userPathLabel
            app.userPathLabel = uilabel(app.SubGrid4);
            app.userPathLabel.VerticalAlignment = 'bottom';
            app.userPathLabel.FontSize = 10;
            app.userPathLabel.Layout.Row = 3;
            app.userPathLabel.Layout.Column = 1;
            app.userPathLabel.Text = 'PASTA DO USUÁRIO:';

            % Create userPath
            app.userPath = uieditfield(app.SubGrid4, 'text');
            app.userPath.Editable = 'off';
            app.userPath.FontSize = 11;
            app.userPath.Layout.Row = 4;
            app.userPath.Layout.Column = 1;

            % Create userPathButton
            app.userPathButton = uiimage(app.SubGrid4);
            app.userPathButton.ScaleMethod = 'none';
            app.userPathButton.ImageClickedFcn = createCallbackFcn(app, @Config_FolderButtonPushed, true);
            app.userPathButton.Tag = 'userPath';
            app.userPathButton.Enable = 'off';
            app.userPathButton.Layout.Row = 4;
            app.userPathButton.Layout.Column = 2;
            app.userPathButton.ImageSource = 'folder-opened-16px.svg';

            % Create DockModule
            app.DockModule = uigridlayout(app.GridLayout);
            app.DockModule.RowHeight = {'1x'};
            app.DockModule.ColumnSpacing = 2;
            app.DockModule.Padding = [5 2 5 2];
            app.DockModule.Visible = 'off';
            app.DockModule.Layout.Row = [2 3];
            app.DockModule.Layout.Column = [3 4];
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
