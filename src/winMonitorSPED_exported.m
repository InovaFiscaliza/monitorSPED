classdef winMonitorSPED_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        GridLayout              matlab.ui.container.GridLayout
        NavBar                  matlab.ui.container.GridLayout
        AppInfo                 matlab.ui.control.Image
        FigurePosition          matlab.ui.control.Image
        DataHubLamp             matlab.ui.control.Image
        jsBackDoor              matlab.ui.control.HTML
        Tab3Button              matlab.ui.control.StateButton
        ButtonsSeparator        matlab.ui.control.Image
        Tab2Button              matlab.ui.control.StateButton
        Tab1Button              matlab.ui.control.StateButton
        AppName                 matlab.ui.control.Label
        TabGroup                matlab.ui.container.TabGroup
        Tab1_File               matlab.ui.container.Tab
        file_Grid               matlab.ui.container.GridLayout
        FileTree                matlab.ui.container.Tree
        FileMetadata            matlab.ui.control.Label
        SubTabGroup             matlab.ui.container.TabGroup
        SubTab1                 matlab.ui.container.Tab
        SubGrid1                matlab.ui.container.GridLayout
        FileModuleLegend        matlab.ui.control.Image
        FileSortMethodSelector  matlab.ui.control.DropDown
        FileSortMethodIcon      matlab.ui.control.Image
        FileModuleIntroduction  matlab.ui.control.Label
        tool_Grid               matlab.ui.container.GridLayout
        tool_UploadFinalFile    matlab.ui.control.Image
        tool_GenerateReport     matlab.ui.control.Image
        tool_OpenPopupProject   matlab.ui.control.Image
        tool_CheckRFB           matlab.ui.control.Image
        tool_MergeFiles         matlab.ui.control.Image
        tool_Separator1         matlab.ui.control.Image
        tool_ReadFiles          matlab.ui.control.Image
        Tab2_Playback           matlab.ui.container.Tab
        Tab3_Config             matlab.ui.container.Tab
        ContextMenu             matlab.ui.container.ContextMenu
        contextmenu_merge       matlab.ui.container.Menu
        contextmenu_del         matlab.ui.container.Menu
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        Role = 'mainApp'
        Context = 'FILE'
    end


    properties (Access = public)
        %-----------------------------------------------------------------%
        General
        General_I

        rootFolder
        tabGroupController
        renderCount = 0

        executionMode
        progressDialog
        popupContainer
        popupCurrentApp

        eFiscalizaObj
        receitaFederalObj

        projectData
        ecdObj = model.ECD.empty        
    end


    methods (Access = public)
        %-----------------------------------------------------------------%
        % COMUNICAÇÃO ENTRE PROCESSOS:
        % • ipcMainJSEventsHandler
        %   Eventos recebidos do objeto app.jsBackDoor por meio de chamada 
        %   ao método "sendEventToMATLAB" do objeto "htmlComponent" (no JS).
        %
        % • ipcMainMatlabCallsHandler
        %   Eventos recebidos dos apps secundários.
        %
        % • ipcMainMatlabCallAuxiliarApp
        %   Reencaminha eventos recebidos aos apps secundários, viabilizando
        %   comunicação entre apps secundários e, também, redirecionando os 
        %   eventos JS quando o app secundário é executado em modo DOCK (e, 
        %   por essa razão, usa o "jsBackDoor" do app principal).
        %
        % • ipcMainMatlabOpenPopupApp
        %   Abre um app secundário como popup, no mainApp.
        %-----------------------------------------------------------------%
        function ipcMainJSEventsHandler(app, event)
            try
                switch event.HTMLEventName
                    % MATLAB-JS BRIDGE (matlabJSBridge.js)
                    case 'renderer'
                        MFilePath   = fileparts(mfilename('fullpath'));
                        parpoolFlag = true;

                        if ~app.renderCount
                            appEngine.activate(app, app.Role, MFilePath, parpoolFlag)
                        else
                            selectedNodes = app.FileTree.SelectedNodes;
                            if ~isempty(app.FileTree.SelectedNodes)
                                app.FileTree.SelectedNodes = [];
                                onTreeSelectionChanged(app)
                            end

                            appEngine.beforeReload(app, app.Role)
                            appEngine.activate(app, app.Role, MFilePath, parpoolFlag)

                            if ~isempty(selectedNodes)
                                app.FileTree.SelectedNodes = selectedNodes;
                                onTreeSelectionChanged(app)
                            end
                        end
                        
                        app.renderCount = app.renderCount+1;

                    case 'unload'
                        closeFcn(app)

                    case 'closeFcnCallFromPopupApp'
                        context = event.HTMLEventData.context;
                        popupCurrentAppTag = event.HTMLEventData.dockAppName;

                        switch context
                            case {'mainApp', app.Context}
                                hApp = app;
                            otherwise
                                hApp = getAppHandle(app.tabGroupController, context);
                        end
                        
                        if ~isempty(hApp) && isvalid(hApp)
                            deleteContextMenu(app.tabGroupController, hApp.UIFigure, popupCurrentAppTag)
                        end

                        delete(app.popupCurrentApp)
                        app.popupCurrentApp = [];

                    case 'syncPopupWithPanel'
                        if ~isempty(app.popupCurrentApp) && isvalid(app.popupCurrentApp)
                            app.popupCurrentApp.Container.Position(1:2) = [event.HTMLEventData.x, event.HTMLEventData.y];
                        end

                    case 'customForm'
                        switch event.HTMLEventData.uuid
                            case {'onFetchIssueDetails', 'onReportGenerate', 'onUploadArtifacts'}
                                eventName = event.HTMLEventData.uuid;
                                context = event.HTMLEventData.context;

                                varargin = {};
                                if isfield(event.HTMLEventData, 'varargin')
                                    varargin = event.HTMLEventData.varargin;
                                    if ~iscell(varargin)
                                        varargin = {varargin};
                                    end
                                end

                                reportHandleOperation(app, eventName, context, event.HTMLEventData, varargin{:})

                            case 'openDevTools'
                                if isequal(app.General.operationMode.DevTools, rmfield(event.HTMLEventData, 'uuid'))
                                    webWin = struct(struct(struct(app.UIFigure).Controller).PlatformHost).CEF;
                                    webWin.openDevTools();
                                end
                        end

                    case 'getNavigatorBasicInformation'
                        app.General.AppVersion.browser = event.HTMLEventData;

                    case 'findResourceStaticURL'
                        resourceStaticURL = event.HTMLEventData;
                        if ~isempty(resourceStaticURL)
                            app.General.AppVersion.application.resourceStaticURL = resourceStaticURL;
                        end

                    case 'getTableColumnWidth'
                        context = 'ECD';
                        tableId = event.HTMLEventData.tableId;
                        displayedColumnCount = event.HTMLEventData.displayedColumnCount;
                        columnWidths = event.HTMLEventData.columnWidths;

                        ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', 'getTableColumnWidth', tableId, displayedColumnCount, columnWidths)

                    % MAINAPP
                    case 'mainApp.file_Tree'
                        ContextMenu_DeleteSelectedTreeNode(app)

                    otherwise
                        error('winMonitorSPED:UnexpectedEvent', 'Unexpected event "%s"', event.HTMLEventName)
                end
                drawnow

            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME));
            end
        end

        %-----------------------------------------------------------------%
        function varargout = ipcMainMatlabCallsHandler(app, callingApp, eventName, varargin)
            varargout = {};

            try
                switch eventName
                    case 'closeFcn'
                        auxAppTag    = varargin{1};
                        closeModule(app.tabGroupController, auxAppTag, app.General, 'normal')

                    case 'dockButtonPushed'
                        auxAppTag    = varargin{1};
                        varargout{1} = {app};

                    otherwise
                        switch class(callingApp)
                            % auxApp.winConfig (CONFIG)
                            case {'auxApp.winConfig', 'auxApp.winConfig_exported'}
                                switch eventName
                                    case 'checkDataHubLampStatus'
                                        updateWarningLampVisibility(app)
        
                                    case 'openDevTools'
                                        dialogBox    = struct('id', 'login',    'label', 'Usuário: ', 'type', 'text');
                                        dialogBox(2) = struct('id', 'password', 'label', 'Senha: ',   'type', 'password');
                                        sendEventToHTMLSource(app.jsBackDoor, 'customForm', struct('UUID', 'openDevTools', 'Fields', dialogBox))
        
                                    case 'simulationModeChanged'
                                        if app.General.operationMode.Simulation
                                            Toolbar_SelectFileToReadImageClicked(app)
        
                                            % Muda programaticamente o modo p/ ARQUIVOS.
                                            set(app.Tab1Button, 'Enable', 1, 'Value', 1)                    
                                            onTabNavigatorButtonPushed(app, struct('Source', app.Tab1Button, 'PreviousValue', false))
                                        end
        
                                    case 'fileSortMethodChanged'
                                        if ~strcmp(app.FileSortMethodSelector.Value, app.General.context.FILE.sortMethod)
                                            app.FileSortMethodSelector.Value = app.General.context.FILE.sortMethod;
                                            onFileSortMethodValueChanged(app)
                                        end
        
                                    case {'onICMSTaxChanged', 'onPISTaxChanged', 'onCOFINSTaxChanged'}
                                        for ii = 1:numel(app.ecdObj)
                                            if isfield(app.ecdObj(ii).Table, 'x_APURACAO_GERAL')
                                                update(app.ecdObj(ii), 'Table.x_APURACAO_GERAL', 'accountValueChanged', app.General)
                                            end
                                        end

                                        context = 'ECD';
                                        ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', eventName)
        
                                    otherwise
                                        error('winMonitorSPED:UnexpectedCall', 'Unexpected call "%s"', eventName)
                                end
        
                            % auxApp.winECD (ECD)
                            case {'winMonitorSPED', 'winMonitorSPED_exported', ...
                                  'auxApp.winECD',  'auxApp.winECD_exported'}
                                switch eventName
                                    case 'getSelectedFileIndex'
                                        fileIndex = 1;
                                        if ~isempty(app.FileTree.SelectedNodes)
                                            fileIndex = unique([app.FileTree.SelectedNodes.NodeData], 'stable');
                                            fileIndex = fileIndex(1);
                                        end
                                        varargout{1} = fileIndex;

                                    case 'onUpdateLastVisitedFolder'
                                        filePath = varargin{1};
                                        updateLastVisitedFolder(app, filePath)

                                    case {'onReportGenerate', 'onUploadArtifacts'}
                                        context = varargin{1};
                                        varargin = varargin(2:end);
                                        reportHandleOperation(app, eventName, context, [], varargin{:})

                                    case 'onAccountingDataUpdated'
                                        if ~isempty(app.FileTree.SelectedNodes)
                                            nodeData = unique([app.FileTree.SelectedNodes.NodeData]);
        
                                            if isequal(nodeData, varargin{1})
                                                app.FileMetadata.UserData = [];
                                                onTreeSelectionChanged(app)
                                            end
                                        end
        
                                    otherwise
                                        error('winMonitorSPED:UnexpectedCall', 'Unexpected call "%s"', eventName)
                                end

                            % DOCKS:OTHERS
                            case {'auxApp.dockReportLib',      'auxApp.dockReportLib_exported',  ...
                                  'auxApp.dockIcmsRate',       'auxApp.dockIcmsRate_exported',   ...
                                  'auxApp.dockECDExport',      'auxApp.dockECDExport_exported',  ...
                                  'auxApp.dockECDAccount',     'auxApp.dockECDAccount_exported', ...
                                  'auxApp.dockECDFilter',      'auxApp.dockECDFilter_exported',  ...
                                  'auxApp.dockECDMemoryUsage', 'auxApp.dockECDMemoryUsage_exported'}
                                switch eventName
                                    % auxApp.dockReportLib
                                    case {'onProjectRestart', 'onProjectLoad', 'onFinalReportFileChanged'}
                                        refreshProjectFiles(app, [], 'FileListChanged:ProjectLoad')
                                        
                                    case 'onUpdateLastVisitedFolder'
                                        filePath = varargin{1};
                                        updateLastVisitedFolder(app, filePath)

                                    case 'onFetchIssueDetails'
                                        context  = varargin{1};
                                        reportFetchIssueDetails(app, context, [])

                                    % auxApp.dockIcmsRate
                                    case 'onIcmsRateChanged'
                                        if ~isempty(app.FileTree.SelectedNodes)
                                            nodeData = unique([app.FileTree.SelectedNodes.NodeData]);
        
                                            if isequal(nodeData, varargin{1})
                                                app.FileMetadata.UserData = [];
                                                onTreeSelectionChanged(app)
                                            end
                                        end
                                        
                                    % auxApp.dockECDExport
                                    case 'onExportECD'
                                        context  = varargin{1};
                                        varargin = [{eventName}, varargin(2:end)];
                                        ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})

                                        if callingApp.isDocked
                                            sendEventToHTMLSource(callingApp.callingApp.jsBackDoor, 'closePopupAppRequest', struct('dataTag', callingApp.GridLayout.UserData.id))
                                        else
                                            delete(callingApp)
                                        end
        
                                    % auxApp.dockECDAccount
                                    % auxApp.dockECDFilter        
                                    case {'onAccountEdited',  'onAccountSelectionChanged', 'onFilterChanged', 'onTableReadRequired'}
                                        context  = varargin{1};
                                        varargin = [{eventName}, varargin(2:end)];
                                        ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})

                                    % auxApp.dockECDMemoryUsage
                                    case 'onCacheCleanup'
                                        fileIndexes = varargin{1};
                                        tableIdList = varargin{2};
                                        
                                        for fileIndex = fileIndexes
                                            update(app.ecdObj(fileIndex), 'Table.NonEssentialFiles', 'onCacheCleanup', tableIdList)
                                            ipcMainMatlabCallsHandler(app, app, 'onAccountingDataUpdated', fileIndex);
                                        end
        
                                    otherwise
                                        error('winMonitorSPED:UnexpectedCall', 'Unexpected call "%s"', eventName)
                                end
            
                            otherwise
                                error('winMonitorSPED:UnexpectedCaller', 'Unexpected caller "%s"', class(callingApp))
                        end
                end

            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME));            
            end
        end

        %-----------------------------------------------------------------%
        function ipcMainMatlabCallAuxiliarApp(app, auxAppName, communicationType, varargin)
            hAuxApp = getAppHandle(app.tabGroupController, auxAppName);

            if ~isempty(hAuxApp)
                switch communicationType
                    case 'MATLAB'
                        operationType = varargin{1};
                        ipcSecondaryMatlabCallsHandler(hAuxApp, app, operationType, varargin{2:end});
                    case 'JS'
                        event = varargin{1};
                        ipcSecondaryJSEventsHandler(hAuxApp, event)
                end
            end
        end

        %-----------------------------------------------------------------%
        function ipcMainMatlabOpenPopupApp(app, callingApp, auxAppName, context, varargin)
            arguments
                app
                callingApp
                auxAppName char {mustBeMember(auxAppName, {'ReportLib', 'IcmsRate', 'ECDExport', 'ECDAccount', 'ECDFilter', 'ECDMemoryUsage'})}
                context    char {mustBeMember(context, {'mainApp', 'FILE', 'ECD', 'CONFIG'})}
            end

            arguments (Repeating)
                varargin 
            end

            requestVisibilityChange(callingApp.progressDialog, 'visible', 'unlocked')
            inputArguments = [{app, callingApp, context}, varargin];

            if app.General.operationMode.Debug
                app.popupCurrentApp = eval(sprintf('auxApp.dock%s(inputArguments{:})', auxAppName));
                app.popupCurrentApp.isDocked = false;

            else
                popupSpecifications = table( ...
                    'Size', [15, 4], ...
                    'VariableTypes', {'string', 'double', 'double', 'logical'}, ...
                    'VariableNames', {'AuxAppName', 'Width', 'Height', 'IsFluid'} ...
                );
                popupSpecifications( 1, :) = {"ECDAccount",     794, 580, false};
                popupSpecifications( 2, :) = {"ECDExport",      460, 598, false};
                popupSpecifications( 3, :) = {"ECDFilter",      518, 376, false};
                popupSpecifications( 4, :) = {"ECDMemoryUsage", 460, 580, false};
                popupSpecifications( 5, :) = {"IcmsRate",       448, 320, false};
                popupSpecifications( 6, :) = {"ReportLib",      460, 598, false};

                auxAppNameIdx = find(popupSpecifications.AuxAppName == string(auxAppName), 1);
                screenWidth = popupSpecifications.Width(auxAppNameIdx);
                screenHeight = popupSpecifications.Height(auxAppNameIdx);
                isFluid = popupSpecifications.IsFluid(auxAppNameIdx);

                ui.PopUpContainer(callingApp, screenWidth, screenHeight)
                auxDockAppName = sprintf('auxApp.dock%s', auxAppName);
                app.popupCurrentApp = feval([auxDockAppName '_exported'], callingApp.popupContainer, inputArguments{:});
                
                ui.CustomizationBase.getElementsDataTag({
                    callingApp.popupContainer;
                    app.popupCurrentApp.GridLayout
                });

                if isFluid
                    sizing = struct('type', 'fluid', 'width', 90, 'height', 80);
                else
                    sizing = struct('type', 'fixed', 'width', screenWidth, 'height', screenHeight+31);
                end

                sendEventToHTMLSource(callingApp.jsBackDoor, 'dockContainer', struct( ...
                    'dockAppName', auxDockAppName, ...
                    'dockAppDataTag', app.popupCurrentApp.GridLayout.UserData.id, ...
                    'dockAppContainerDataTag', callingApp.popupContainer.UserData.id, ...
                    'sizing', sizing, ...
                    'context', context, ...
                    'numCanvasElements', numel(findobj(app.popupCurrentApp.Container, 'Type', 'axes')) ...
                ))

                app.popupCurrentApp.GridLayout.UserData.auxDockAppName = auxDockAppName;
                callingApp.popupContainer.UserData.auxDockAppName = auxDockAppName;
            end

            requestVisibilityChange(callingApp.progressDialog, 'hidden', 'unlocked')
        end
    end
    
    
    methods (Access = public)
        %-----------------------------------------------------------------%
        function navigateToTab(app, clickedButton)
            onTabNavigatorButtonPushed(app, struct('Source', clickedButton, 'PreviousValue', false))
        end

        %-----------------------------------------------------------------%
        function applyJSCustomizations(app, tabIndex)
            if app.SubTabGroup.UserData.isTabInitialized(tabIndex)
                return
            end
            app.SubTabGroup.UserData.isTabInitialized(tabIndex) = true;

            switch tabIndex
                case 1
                    appName = class(app);
                    elToModify = {
                        app.Tab1Button;
                        app.Tab2Button;
                        app.Tab3Button;
                        app.FileModuleLegend;
                        app.FileTree; 
                        app.FileMetadata;
                        app.tool_ReadFiles;
                        app.tool_MergeFiles;
                        app.tool_CheckRFB;
                        app.tool_OpenPopupProject;
                        app.tool_GenerateReport;
                        app.tool_UploadFinalFile
                    };
                    ui.CustomizationBase.getElementsDataTag(elToModify);

                    try
                        ui.TextView.startup(app.jsBackDoor, app.FileMetadata, appName, struct('class', {{'textview--wordbreak'}}));
                    catch
                    end

                    try
                        sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', { ...
                            struct('appName', appName, 'dataTag', app.FileModuleLegend.UserData.id,       'tooltip', struct('defaultPosition', 'top', 'textContent', 'Mostra legenda de símbolos')), ...
                            struct('appName', appName, 'dataTag', app.tool_ReadFiles.UserData.id,         'tooltip', struct('defaultPosition', 'top', 'textContent', 'Seleciona arquivos')), ...
                            struct('appName', appName, 'dataTag', app.tool_MergeFiles.UserData.id,        'tooltip', struct('defaultPosition', 'top', 'textContent', 'Mescla informação contábil')), ...
                            struct('appName', appName, 'dataTag', app.tool_CheckRFB.UserData.id,          'tooltip', struct('defaultPosition', 'top', 'textContent', 'Consulta à Receita Federal')), ...
                            struct('appName', appName, 'dataTag', app.tool_OpenPopupProject.UserData.id,  'tooltip', struct('defaultPosition', 'top', 'textContent', 'Edita informações do projeto<br>(fiscalizada, arquivo de backup etc)')), ...
                            struct('appName', appName, 'dataTag', app.tool_GenerateReport.UserData.id,    'tooltip', struct('defaultPosition', 'top', 'textContent', 'Gera relatório')), ...
                            struct('appName', appName, 'dataTag', app.tool_UploadFinalFile.UserData.id,   'tooltip', struct('defaultPosition', 'top', 'textContent', 'Upload relatório')), ...
                            struct('appName', appName, 'dataTag', app.Tab1Button.UserData.id,             'generation', 1, 'class', 'tab-navigator-button'), ...
                            struct('appName', appName, 'dataTag', app.Tab2Button.UserData.id,             'generation', 1, 'class', 'tab-navigator-button'), ...
                            struct('appName', appName, 'dataTag', app.Tab3Button.UserData.id,             'generation', 1, 'class', 'tab-navigator-button'), ...
                            struct('appName', appName, 'dataTag', app.FileTree.UserData.id,               'listener', struct('componentName', 'mainApp.file_Tree', 'keyEvents', {{'Delete', 'Backspace'}})) ...
                        });
                    catch
                    end

                otherwise
                    % Previsto pensando em evolução, caso adicionado uitab
                    % ao app.SubTabGrid...
            end
        end

        %-----------------------------------------------------------------%
        function loadConfigurationFile(app, appName, MFilePath)
            % "GeneralSettings.json"
            [app.General_I, msgWarning] = appEngine.util.generalSettingsLoad(appName, app.rootFolder);
            if ~isempty(msgWarning)
                ui.Dialog(app.UIFigure, 'error', msgWarning);
            end

            % Para criação de arquivos temporários, cria-se uma pasta da 
            % sessão.
            tempDir = tempname;
            mkdir(tempDir)
            app.General_I.fileFolder.tempPath  = tempDir;
            app.General_I.fileFolder.MFilePath = MFilePath;

            if ~ismember(app.General_I.context.FILE.input, {'file', 'folder'})
                app.General_I.context.FILE.input = 'file';
            end

            if ~ismember(app.General_I.context.FILE.sortMethod, {'CNPJ', 'PERÍODO FISCAL', 'RECEITA FEDERAL'})
                app.General_I.context.FILE.sortMethod = 'CNPJ';
            end

            if ~ismember(app.General_I.context.FILE.checkStatus, {'OnlyCache', 'Cache+RealTime', 'RealTime'})
                app.General_I.context.FILE.checkStatus = 'Cache+RealTime';
            end

            if ~isempty(app.General_I.context.FILE.encodingOverride)
                app.General_I.context.FILE.encodingOverride = '';
            end

            switch app.executionMode
                case 'webApp'
                    % Força a exclusão do SplashScreen do MATLAB Web Server.
                    sendEventToHTMLSource(app.jsBackDoor, "delProgressDialog");

                    app.General_I.operationMode.Debug = false;
                    app.General_I.operationMode.Dock  = true;
                    
                    % A pasta do usuário não é configurável, mas obtida por 
                    % meio de chamada a uiputfile. 
                    app.General_I.fileFolder.userPath = tempDir;

                    if ~strcmp(app.General_I.context.FILE.input, 'file')
                        app.General_I.context.FILE.input = 'file';
                    end

                otherwise    
                    % Resgata a pasta de trabalho do usuário (configurável).
                    userPaths = appEngine.util.UserPaths(app.General_I.fileFolder.userPath);
                    app.General_I.fileFolder.userPath = userPaths{end};

                    switch app.executionMode
                        case 'desktopStandaloneApp'
                            app.General_I.operationMode.Debug = false;
                        case 'MATLABEnvironment'
                            app.General_I.operationMode.Debug = true;
                    end
            end

            app.General = app.General_I;        
            app.General.AppVersion = util.getAppVersion(app.rootFolder, MFilePath, tempDir);
            sendEventToHTMLSource(app.jsBackDoor, 'getNavigatorBasicInformation')

            % Ideia é identificar URL de pasta estática servida pelo backend, de 
            % forma que possam ser inseridas imagens em uilabel (como ui.TextView).
            try
                [~, resourceName, resourceExt] = fileparts(app.tool_ReadFiles.ImageSource);
                sendEventToHTMLSource(app.jsBackDoor, 'findResourceStaticURL', struct('resourceName', [resourceName resourceExt], 'resourceTag', 'img', 'resourceId', app.tool_ReadFiles.UserData.id))
            catch
            end
        end

        %-----------------------------------------------------------------%
        function initializeAppProperties(app)
            app.projectData = model.Project(app, app.rootFolder);
            app.receitaFederalObj = ws.ReceitaFederal();
        end

        %-----------------------------------------------------------------%
        function initializeUIComponents(app)
            app.tabGroupController = ui.TabNavigator(app.NavBar, app.TabGroup, app.progressDialog);
            addComponent(app.tabGroupController, "Built-in", "",                 app.Tab1Button, "AlwaysOn", struct('On', '', 'Off', ''), matlab.graphics.GraphicsPlaceholder, 1)
            addComponent(app.tabGroupController, "External", "auxApp.winECD",    app.Tab2Button, "AlwaysOn", struct('On', '', 'Off', ''), app.Tab1Button,                      2)
            addComponent(app.tabGroupController, "External", "auxApp.winConfig", app.Tab3Button, "AlwaysOn", struct('On', '', 'Off', ''), app.Tab1Button,                      3)
            app.tabGroupController.inlineSVG = true;

            addStyle(app.FileTree, uistyle('Interpreter', 'html'))
        end

        %-----------------------------------------------------------------%
        function applyInitialLayout(app)
            updateWarningLampVisibility(app)
            app.FileSortMethodSelector.Value = app.General.context.FILE.sortMethod;
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function refreshProjectFiles(app, indexes, updateType)
            arguments
                app
                indexes
                updateType char {mustBeMember(updateType, {'FileListChanged:Add', ...
                                                           'FileListChanged:Del', ...
                                                           'FileListChanged:Merge', ...
                                                           'FilesReordered', ...
                                                           'FileStatusChecked', ...
                                                           'FileListChanged:ProjectLoad'})}
            end

            buildFileTree(app, indexes)

            if contains(updateType, 'FileListChanged')
                ipcMainMatlabCallAuxiliarApp(app, 'ECD', 'MATLAB', updateType)
            end
        end

        %-----------------------------------------------------------------%
        function buildFileTree(app, selectedNodeData)
            arguments
                app
                selectedNodeData = []
            end

            if ~isempty(app.FileTree.Children)
                app.FileMetadata.UserData = [];
                delete(app.FileTree.Children)
            end

            idsList = {app.ecdObj.CompanyId};
            selectedNode = [];
            
            if ~isempty(idsList)
                ids = unique(idsList);

                switch app.FileSortMethodSelector.Value
                    case 'CNPJ'
                        selectedNode = createFileTreeNodes(app, idsList, ids, selectedNode, selectedNodeData);
                    otherwise
                        switch app.FileSortMethodSelector.Value
                            case 'PERÍODO FISCAL'
                                validTreeNodeText = '<font style="color: blue; font-weight: bold; text-decoration: underline;">VÁLIDOS</font> EM RELAÇÃO AO CRITÉRIO "PERÍODO FISCAL ANUAL"';
                            case 'RECEITA FEDERAL'
                                validTreeNodeText = '<font style="color: blue; font-weight: bold; text-decoration: underline;">VÁLIDOS</font> EM RELAÇÃO AO CRITÉRIO "ARQUIVO CONSTA NA BASE DA RECEITA FEDERAL"';
                        end
                        validTreeNode   = uitreenode(app.FileTree, 'Text', validTreeNodeText);
                        selectedNode    = createFileTreeNodes(app, idsList, ids, selectedNode, selectedNodeData, validTreeNode,   'only-valid');
                        
                        invalidTreeNode = uitreenode(app.FileTree, 'Text', '<font style="color: red; font-weight: bold; text-decoration: underline;">INVÁLIDOS</font>');
                        selectedNode    = createFileTreeNodes(app, idsList, ids, selectedNode, selectedNodeData, invalidTreeNode, 'only-invalid');
                end
            end

            expand(app.FileTree, 'all')

            if ~isempty(app.FileTree.Children)
                if ~isempty(selectedNode)
                    app.FileTree.SelectedNodes = selectedNode;
                else
                    if isempty(app.FileTree.Children(1).Children)
                        app.FileTree.SelectedNodes = app.FileTree.Children(1);
                    else
                        app.FileTree.SelectedNodes = app.FileTree.Children(1).Children(1);
                    end
                end
            end

            onTreeSelectionChanged(app)
        end

        %-----------------------------------------------------------------%
        function selectedNode = createFileTreeNodes(app, idsList, ids, selectedNode, selectedNodeData, varargin)
            arguments
                app 
                idsList 
                ids 
                selectedNode
                selectedNodeData
            end

            arguments (Repeating)
                varargin
            end

            switch app.FileSortMethodSelector.Value
                case 'CNPJ'
                    parentNode = app.FileTree;
                otherwise
                    parentNode = varargin{1};
                    requiredStatus = varargin{2};
            end

            for id = ids
                % Identifica fluxos relacionados a cada CNPJ, ordenando os 
                % fluxos de acordo com a data de fim do seu período fiscal.
                idIndexes   = find(strcmp(idsList, id));
                [~, idSort] = sort(arrayfun(@(x) x.Period(2), app.ecdObj(idIndexes)));
                idIndexes   = idIndexes(idSort);

                % Aplica filtro, caso construção da árvore seja orientada
                % ao "PERÍODO FISCAL" ou à "RECEITA FEDERAL".
                if ismember(app.FileSortMethodSelector.Value, {'PERÍODO FISCAL', 'RECEITA FEDERAL'})
                    for ii = numel(idIndexes):-1:1
                        index = idIndexes(ii);
    
                        switch app.FileSortMethodSelector.Value
                            case 'PERÍODO FISCAL'
                                validFile = checkIfValidPeriod(app.ecdObj(index));
                            case 'RECEITA FEDERAL'
                                validFile = checkIfValidStatus(app.ecdObj(index));
                        end
    
                        if strcmp(requiredStatus, 'only-valid') && ~validFile
                            idIndexes(ii) = [];
                        elseif strcmp(requiredStatus, 'only-invalid') && validFile
                            idIndexes(ii) = [];
                        end
                    end
    
                    if isempty(idIndexes)
                        continue
                    end
                end

                textCompanyNode = util.HtmlTextGenerator.generateTextId(app.ecdObj(idIndexes(1)), 'company-oriented');
                treeCompanyNode = uitreenode(parentNode, ...
                    'Text', textCompanyNode, ...
                    'NodeData', idIndexes, 'ContextMenu', app.ContextMenu);
    
                for idx = idIndexes
                    textPeriodNode = util.HtmlTextGenerator.generateTextId(app.ecdObj(idx), 'period-oriented', true);
                    treePeriodNode = uitreenode(treeCompanyNode, ...
                        'Text', textPeriodNode, ...
                        'NodeData', idx, 'ContextMenu', app.ContextMenu);
    
                    if ismember(idx, selectedNodeData)
                        selectedNode = [selectedNode, treePeriodNode];
                    end
                end
            end
        end

        %-----------------------------------------------------------------%
        function indexes = getSelectedECDIndexes(app)
            indexes = [];
            if ~isempty(app.FileTree.SelectedNodes)
                indexes = unique([app.FileTree.SelectedNodes.NodeData]);
            end
        end

        %-----------------------------------------------------------------%
        % MISCELÂNEAS
        %-----------------------------------------------------------------%
        function updateWarningLampVisibility(app)
            app.DataHubLamp.Visible = ~isfolder(app.General.fileFolder.DataHub_POST);
        end

        %-----------------------------------------------------------------%
        function updateToolbar(app)
            indexes = getSelectedECDIndexes(app);

            nonEmptySelection               = ~isempty(indexes);
            nonScalarSelection              = ~isscalar(indexes);
            reportFinalVersionGenerated     = ~isempty(app.projectData.modules.(app.Context).generatedFiles.lastHTMLDocFullPath);

            app.tool_MergeFiles.Enable      = nonEmptySelection && nonScalarSelection;
            app.tool_CheckRFB.Enable        = nonEmptySelection;
            app.tool_GenerateReport.Enable  = nonEmptySelection;
            app.tool_UploadFinalFile.Enable = reportFinalVersionGenerated;

            app.contextmenu_merge.Enable    = app.tool_MergeFiles.Enable;
            app.contextmenu_del.Enable      = nonEmptySelection;
        end

        %-----------------------------------------------------------------%
        function updateLastVisitedFolder(app, filePath)
            app.General_I.fileFolder.lastVisited = filePath;
            app.General.fileFolder.lastVisited   = filePath;

            appEngine.util.generalSettingsSave(class.Constants.appName, app.rootFolder, app.General_I, app.executionMode)
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        % SISTEMA DE GESTÃO DA FISCALIZAÇÃO (eFiscaliza/SEI)
        %-----------------------------------------------------------------%
        function createEFiscalizaObject(app, credentials)
            if ~isempty(credentials)
                app.eFiscalizaObj = ws.eFiscaliza(credentials.login, credentials.password);
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

            if isempty(app.eFiscalizaObj) || ~isvalid(app.eFiscalizaObj)
                dialogBox    = struct('id', 'login',    'label', 'Usuário: ', 'type', 'text');
                dialogBox(2) = struct('id', 'password', 'label', 'Senha: ',   'type', 'password');

                customFormData = struct('UUID', eventName, 'Fields', dialogBox, 'Context', app.Context);
                if ~isempty(varargin)
                    customFormData.Varargin = varargin;
                end

                sendEventToHTMLSource(app.jsBackDoor, 'customForm', customFormData)

            else
                reportHandleOperation(app, eventName, app.Context, [], varargin{:})
            end
        end

        %-----------------------------------------------------------------%
        function reportHandleOperation(app, eventName, context, credentials, varargin)
            arguments
                app
                eventName {mustBeMember(eventName, {'onFetchIssueDetails', 'onReportGenerate', 'onUploadArtifacts'})}
                context {mustBeMember(context, {'FILE', 'ECD'})}
                credentials
            end

            arguments (Repeating)
                varargin
            end

            switch eventName
                case 'onFetchIssueDetails'
                    reportFetchIssueDetails(app, context, credentials)

                case 'onReportGenerate'
                    indexes = varargin{1};
                    reportGenerate(app, context, credentials, indexes);
        
                case 'onUploadArtifacts'
                    reportUploadArtifacts(app, context, credentials);
            end
        end

        %-----------------------------------------------------------------%
        function reportFetchIssueDetails(app, context, credentials)
            callingApp = getAppHandle(app.tabGroupController, context);
            if isempty(callingApp)
                callingApp = app;
            end

            callingApp.progressDialog.Visible = 'visible';

            createEFiscalizaObject(app, credentials)
            system = app.projectData.modules.(context).ui.system;
            issue  = app.projectData.modules.(context).ui.issue;
            [details, msgError] = getOrFetchIssueDetails(app.projectData, system, issue, app.eFiscalizaObj);

            if app ~= callingApp
                ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', 'onFetchIssueDetails', system, issue, details, msgError)

            else
                if isempty(msgError)
                    msg = util.HtmlTextGenerator.issueDetails(system, issue, details);
                    icon = 'info';
                else
                    app.eFiscalizaObj = [];
                    msg = msgError;
                    icon = 'error';
                end
                ui.Dialog(app.UIFigure, icon, msg);
            end

            callingApp.progressDialog.Visible = 'hidden';
        end

        %-----------------------------------------------------------------%
        function reportGenerate(app, context, credentials, indexes)
            callingApp = getAppHandle(app.tabGroupController, context);
            if isempty(callingApp)
                callingApp = app;
            end

            callingApp.progressDialog.Visible = 'visible';

            createEFiscalizaObject(app, credentials)
            try
                reportLibConnection.Controller.Run(app, callingApp, context, app.ecdObj(indexes))
                if app == callingApp
                    updateToolbar(app)
                else
                    ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', 'onReportGenerate')
                end

            catch ME
                app.eFiscalizaObj = [];
                ui.Dialog(callingApp.UIFigure, 'error', ME.message);
            end

            callingApp.progressDialog.Visible = 'hidden';
        end

        %-----------------------------------------------------------------%
        function reportUploadArtifacts(app, context, credentials)
            callingApp = getAppHandle(app.tabGroupController, context);
            if isempty(callingApp)
                callingApp = app;
            end

            callingApp.progressDialog.Visible = 'visible';

            createEFiscalizaObject(app, credentials)

            [status1, icon1, msg1] = reportUploadToSEI(app, context, 'uploadDocument');
            [status2, ~, msg2] = reportUploadToSEI(app, context, 'uploadExternalDocument');

            if status1 && status2
                msg1 = sprintf('• RELATÓRIO:\n%s\n\n• PLANILHA DE SUPORTE:\n%s', msg1, msg2);
            end
            ui.Dialog(callingApp.UIFigure, icon1, msg1);

            callingApp.progressDialog.Visible = 'hidden';
            
            if status1 && strcmp(app.projectData.modules.(context).ui.system, 'eFiscaliza')
                [status3, msg3] = reportUploadFilesToSharepoint(app, context);

                if ~status3
                    ui.Dialog(callingApp.UIFigure, 'error', msg3);
                end
            end
        end

        %-------------------------------------------------------------------------%
        function [status, icon, msg] = reportUploadToSEI(app, context, operation)
            try
                env = strsplit(app.projectData.modules.(context).ui.system);
                if isscalar(env)
                    env = 'PD';
                else
                    env = env{2};
                end

                system = app.projectData.modules.(context).ui.system;
                unit = app.projectData.modules.(context).ui.unit;
                issue = app.projectData.modules.(context).ui.issue;
                issueInfo = struct( ...
                    'type', 'ATIVIDADE DE INSPEÇÃO', ...
                    'id', issue ...
                );

                switch operation
                    case 'uploadDocument'
                        HTMLFile = getGeneratedDocumentFileName(app.projectData, '.html', context);

                        [~, modelIdx]   = ismember(app.projectData.modules.(context).ui.reportModel, {app.projectData.report.templates.Name});
                        docType         = app.projectData.report.templates(modelIdx).DocumentType;
                        [~, docTypeIdx] = ismember(docType, {app.General.eFiscaliza.internal.typeIdMapping.type});

                        docSpec = app.General.eFiscaliza;
                        docSpec.originId = docSpec.internal.originId;
                        docSpec.typeId = app.General.eFiscaliza.internal.typeIdMapping(docTypeIdx).id;
                        docSpec.nomeArvore = ['[' class.Constants.appName ']'];

                        if app.projectData.modules.(context).ui.entity.status
                            docSpec.interessados = {struct( ...
                                'sigla', app.projectData.modules.(context).ui.entity.id, ...
                                'nome', app.projectData.modules.(context).ui.entity.name ...
                            )};
                        end                        

                        response = run(app.eFiscalizaObj, env, operation, issueInfo, unit, docSpec, HTMLFile);

                    case 'uploadExternalDocument'
                        XLSXFile = getGeneratedDocumentFileName(app.projectData, '.xlsx', context);
                        if isempty(XLSXFile)
                            status = false;
                            icon   = '';
                            msg    = '';
                            return
                        end

                        docSpec = app.General.eFiscaliza;
                        docSpec.originId = docSpec.external.originId;
                        docSpec.typeId = docSpec.external.typeId;
                        docSpec.nomeArvore = 'de Análise ECD e Apuração';

                        if app.projectData.modules.(context).ui.entity.status
                            docSpec.interessados = {struct( ...
                                'sigla', app.projectData.modules.(context).ui.entity.id, ...
                                'nome', app.projectData.modules.(context).ui.entity.name ...
                            )};
                        end   

                        response = run(app.eFiscalizaObj, env, operation, issueInfo, unit, docSpec, XLSXFile);

                    otherwise
                        error('Unexpected call')
                end

                if ~contains(response, 'Documento cadastrado no SEI', 'IgnoreCase', true)
                    error(response)
                end

                updateUploadedFiles(app.projectData, context, system, issue, response)

                status = true;
                icon   = 'success';
                msg    = response;

            catch ME
                app.eFiscalizaObj = [];
                
                status = false;
                icon   = 'error';
                msg    = ME.message;
            end
        end

        %------------------------------------------------------------------------%
        function [status, msg] = reportUploadFilesToSharepoint(app, context)        
            sharepointFileList = { ...
                getGeneratedDocumentFileName(app.projectData, '.json',  context), ...
                getGeneratedDocumentFileName(app.projectData, '.teams', context)  ...
            };
        
            statusList = false(1, numel(sharepointFileList));
            msgList = {};
        
            for ii = 1:numel(sharepointFileList)
                [statusList(ii), msgWarning] = copyfile(sharepointFileList{ii}, app.General.fileFolder.DataHub_POST, 'f');
        
                if ~statusList(ii)
                    msgList{end+1} = msgWarning;
                end
            end
        
            status = all(statusList);
            msg = strjoin(msgList, '\n\n');
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)

            try
                appEngine.boot(app, app.Role)
            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME), 'CloseFcn', @(~,~)closeFcn(app));
            end
            
        end

        % Close request function: UIFigure
        function closeFcn(app, event)

            if strcmp(app.progressDialog.Visible, 'visible')
                app.progressDialog.Visible = 'hidden';
                return
            end

            msgQuestion = '';
            if checkIfUpdateNeeded(app.projectData, app.ecdObj)
                msgQuestion = sprintf([ ...
                    'O projeto "%s" foi modificado (nome, arquivo de saída, ' ...
                    'lista de arquivos de entrada ou tabelas de anotação das ' ...
                    'contas de resultado). Caso o aplicativo seja encerrado ' ...
                    'agora, todas as alterações serão descartadas.\n\n' ...
                    'Deseja realmente fechar o aplicativo?' ...
                    ], app.projectData.name);
            
            elseif ~strcmp(app.executionMode, 'webApp')
                msgQuestion = 'Deseja fechar o aplicativo?';
            end

            if ~isempty(msgQuestion)                
                userSelection = ui.Dialog(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 1, 2);
                if userSelection == "Não"
                    return
                end
            end

            % Aspectos gerais (comum em todos os apps):
            appEngine.beforeDeleteApp(app.progressDialog, app.General_I.fileFolder.tempPath, app.tabGroupController, app.executionMode)
            delete(app)
            
        end

        % Callback function: AppInfo, DataHubLamp, FigurePosition, 
        % ...and 3 other components
        function onTabNavigatorButtonPushed(app, event)

            switch event.Source
                case {app.Tab1Button, app.Tab2Button, app.Tab3Button}
                    openModule(app.tabGroupController, event.Source, event.PreviousValue, app.General, app)

                case app.DataHubLamp
                    msg = [ ...
                        'Pendente mapear a pasta POST do SharePoint, de modo a viabilizar:<br>' ...
                        '•&thinsp;Upload do relatório final para o SEI.' ...
                    ];
                    ui.Dialog(app.UIFigure, 'error', msg);

                case app.FigurePosition
                    app.UIFigure.Position(3:4) = class.Constants.windowSize;
                    appEngine.util.setWindowPosition(app.UIFigure)
                    focus(findobj(app.NavBar.Children, 'Type', 'uistatebutton', 'Value', true))

                case app.AppInfo
                    appInfo = util.HtmlTextGenerator.AppInfo( ...
                        app.General, ...
                        app.rootFolder, ...
                        app.executionMode, ...
                        app.renderCount, ...
                        "popup" ...
                    );
                    ui.Dialog(app.UIFigure, 'info', appInfo);
            end
            
        end

        % Selection changed function: FileTree
        function onTreeSelectionChanged(app, event)
            
            indexes = getSelectedECDIndexes(app);
            
            if isempty(indexes)
                app.FileMetadata.Text     = '';
                app.FileMetadata.UserData = [];
            else
                if isequal(app.FileMetadata.UserData, indexes)
                    return
                end

                app.FileMetadata.Text     = util.HtmlTextGenerator.File(app.ecdObj(indexes));
                app.FileMetadata.UserData = indexes;
            end

            updateToolbar(app)
            
        end

        % Value changed function: FileSortMethodSelector
        function onFileSortMethodValueChanged(app, event)
            
            indexes = getSelectedECDIndexes(app);
            refreshProjectFiles(app, indexes, 'FilesReordered')

        end

        % Image clicked function: tool_ReadFiles
        function Toolbar_SelectFileToReadImageClicked(app, event)

            fileFullName = {};

            if app.General.operationMode.Simulation
                app.General.operationMode.Simulation = false;
                
                [projectFolder, ...
                 programDataFolder] = appEngine.util.Path(class.Constants.appName, app.rootFolder);
                simulationFolders   = {programDataFolder, projectFolder};

                for ii = 1:numel(simulationFolders)
                    filePath    = fullfile(simulationFolders{ii}, 'Simulation');    
                    listOfFiles = dir(filePath);
                    fileName    = {listOfFiles.name};
                    fileName    = fileName(endsWith(fileName, '.txt', 'IgnoreCase', true));
                    
                    if ~isempty(fileName)
                        fileFullName = fullfile(filePath, fileName);
                        break
                    end
                end

            else
                switch app.General.context.FILE.input
                    case 'file'
                        [~, filePath, ~, fileName] = ui.Dialog(app.UIFigure, 'uigetfile', '', {'*.txt;*.sped;*.zip;*.mat', 'monitorSPED (*.txt,*.sped,*.zip,*.mat)'; '*.*', 'Todos os arquivos (*.*)'}, app.General.fileFolder.lastVisited, {'MultiSelect', 'on'});
            
                        if isempty(fileName)
                            return
                        elseif ~iscell(fileName)
                            fileName = {fileName};
                        end
                        pathList = fullfile(filePath, fileName);

                    case 'folder'
                        filePath = uigetdir(app.General.fileFolder.lastVisited);
                        figure(app.UIFigure)
    
                        if isequal(filePath, 0)
                            return
                        end
                        pathList = {filePath};
                end

                [fileFullName, fileName] = util.getFilesFromPathList(pathList, app.General.fileFolder.tempPath, {'.txt', '', '.mat'});
                updateLastVisitedFolder(app, filePath)
            end

            if isempty(fileFullName)
                msgWarning = 'Não foi identificado arquivo em um dos formatos esperados.';
                ui.Dialog(app.UIFigure, "warning", msgWarning);
                return
            end

            d = ui.Dialog(app.UIFigure, "progressdlg", "Em andamento...");            
            filesError = struct('File', {}, 'Error', {});

            for ii = 1:numel(fileFullName)
                d.Message = textFormatGUI.HTMLParagraph(sprintf('Em andamento a leitura do arquivo %d de %d:<br>• <b>%s</b>', ii, numel(fileFullName), fileName{ii}));

                % Verifica se arquivo já foi lido, comparando o seu nome com 
                % a variável app.ecdObj.
                if ~ismember(fileName{ii}, {app.ecdObj.FileName})
                    [~, ~, fileExt] = fileparts(fileFullName{ii});
                    switch lower(fileExt)
                        case {'.txt', ''}
                            [app.ecdObj, msg] = addFiles(app.ecdObj, app.projectData, app.General, fileFullName{ii}, [], app.receitaFederalObj);                        
                        case '.mat'
                            [app.ecdObj, msg] = load(app.projectData, app.Context, fileFullName{ii}, app.General, app.ecdObj);
                        otherwise
                            continue
                    end

                    if ~isempty(msg)
                        filesError(end+1) = struct('File', sprintf('"%s"', fileName{ii}), 'Error', msg);
                        continue
                    end
                end
            end

            % LOG
            if ~isempty(filesError)
                msgWarning = sprintf('Arquivos que apresentaram erro na leitura:\n%s\n\n', strjoin(strcat({'•&thinsp;<b>'}, {filesError.File}, {'</b>: <i>'}, {filesError.Error}), '</i>\n\n'));
                ui.Dialog(app.UIFigure, "error", msgWarning);
            end
            
            % Atualiza app.FileTree.
            indexes = getSelectedECDIndexes(app);
            refreshProjectFiles(app, indexes, 'FileListChanged:Add')

            delete(d)

        end

        % Callback function: contextmenu_merge, tool_MergeFiles
        function Toolbar_MergeFilesImageClicked(app, event)

            indexes = getSelectedECDIndexes(app);

            if numel(indexes) >= 2
                if ~isscalar(unique({app.ecdObj(indexes).CompanyId}))
                    ui.Dialog(app.UIFigure, 'info', 'A mesclagem é aplicável apenas a registros de uma mesma empresa.');
                    return
                elseif ~isscalar(unique(year([app.ecdObj(indexes).Period])))
                    ui.Dialog(app.UIFigure, 'info', 'A mesclagem é aplicável apenas a registros de um mesmo ano fiscal.');
                    return
                end

                encodings = unique({app.ecdObj(indexes).Encoding});
                if ~isscalar(encodings)
                    msgQuestion = sprintf([ ...
                        'Encodings diferentes detectados - %s. Isso pode indicar falha ' ...
                        'na detecção automática e comprometer a leitura dos dados.<br><br>' ...
                        'Se necessário, o encoding pode ser definido manualmente nas configurações.<br><br>' ...
                        'Deseja continuar a mesclagem?' ...
                    ], textFormatGUI.cellstr2FriendlyListWithQuotes(encodings));
                    userSelection = ui.Dialog(app.UIFigure, 'uiconfirm', msgQuestion, {'Sim', 'Não'}, 2, 2);

                    if strcmp(userSelection, 'Não')
                        return
                    end
                end

                app.progressDialog.Visible = 'visible';

                [app.ecdObj, msg] = mergeFiles(app.ecdObj, app.projectData, app.General, indexes, app.General.fileFolder.tempPath);
                if isempty(msg)
                    refreshProjectFiles(app, indexes, 'FileListChanged:Merge')
                else
                    ui.Dialog(app.UIFigure, "error", msg); 
                end

                app.progressDialog.Visible = 'hidden';
            end

        end

        % Image clicked function: tool_CheckRFB
        function Toolbar_CheckStatusImageClicked(app, event)
            
            indexes = getSelectedECDIndexes(app);

            if ~isempty(indexes)
                if all([app.ecdObj(indexes).PeriodMerged])
                    ui.Dialog(app.UIFigure, 'info', 'Consulta à Receita Federal não é aplicável a registro mesclado.');
                    return
                end

                app.progressDialog.Visible = 'visible';

                checkFileFlag = checkFileStatus(app.ecdObj(indexes), app.receitaFederalObj, app.General.context.FILE.encodingList, app.General.context.FILE.checkStatus);
                if checkFileFlag
                    refreshProjectFiles(app, indexes, 'FileStatusChecked')
                end

                app.progressDialog.Visible = 'hidden';
            end

        end

        % Image clicked function: tool_OpenPopupProject
        function Toolbar_OpenPopupProjectImageClicked(app, event)

            ipcMainMatlabOpenPopupApp(app, app, 'ReportLib', app.Context, app.ecdObj)

        end

        % Image clicked function: tool_GenerateReport
        function Toolbar_GenerateReportImageClicked(app, event)
            
            context = app.Context;
            if ~validateReportRequirements(app.projectData, context, 'reportModel')
                ui.Dialog(app.UIFigure, 'warning', 'Pendente escolha do modelo de relatório.');
                return
            end
            
            indexes = getSelectedECDIndexes(app);

            if ~isempty(indexes)
                if numel(indexes) < numel(app.ecdObj)
                    msgQuestion   = 'Deseja gerar inventário de TODOS os arquivos lidos, ou apenas do SELECIONADO?';
                    userSelection = ui.Dialog(app.UIFigure, 'uiconfirm', msgQuestion, {'Todos', 'Selecionado', 'Cancelar'}, 1, 3);

                    switch userSelection
                        case 'Cancelar'
                            return
                        case 'Todos'
                            indexes = 1:numel(app.ecdObj);
                    end
                end

                % <VALIDAÇÕES>
                issue = app.projectData.modules.(context).ui.issue;
                reportVersion = app.projectData.modules.(context).ui.reportVersion;
    
                msgWarning = {};
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
                reportDispatchOperation(app, 'onReportGenerate', indexes)
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
            elseif ~isfolder(app.General.fileFolder.DataHub_POST)
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

            storedReportHash  = app.projectData.modules.(context).generatedFiles.id;
            currentReportHash = model.ProjectBase.computeReportFileInventoryHash(app.ecdObj);

            if ~isequal(storedReportHash, currentReportHash)
                [~, generatedHtmlFileName, generatedHtmlFileExt] = fileparts(generatedHtmlFilePath);
                msgQuestion = sprintf([ ...
                    'Lista de <i>hashs</i> dos arquivos no momento da geração do relatório "%s":<br>' ...
                    '%s<br><br>' ...
                    'Lista atual de <i>hashs</i> dos arquivos:<br>' ...
                    '%s<br><br>' ...
                    '<b>Continuar mesmo assim?</b>' ...
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

        % Image clicked function: FileModuleLegend
        function Toolbar_ShowLegendFileModuleLegendClicked(app, event)
            
            msg = ['Em relação ao conteúdo:<br>' ...
                   '🚫 Escrituração não possui lançamentos contábeis<br>' ...
                   '❗ Problema na validação de registro ou alíquota ICMS<br><br>' ...
                   'Em relação à situação:<br>' ...
                   '&#x1F7E2; Registro encontrado na base da Receita Federal<br>' ...
                   '&#x1F534; Registro não encontrado na base da Receita Federal<br>' ...
                   '⚪ Situação indeterminada<br><br>' ...
                   'Em relação à mesclagem:<br>' ...
                   '➕ Registro mesclado<br>' ...
                   '⌛ Período fiscal não anual'];

            ui.Dialog(app.UIFigure, 'none', msg);

        end

        % Menu selected function: contextmenu_del
        function ContextMenu_DeleteSelectedTreeNode(app, event)
            
            indexes = getSelectedECDIndexes(app);

            if ~isempty(indexes)
                delete(app.ecdObj(indexes))
                app.ecdObj(indexes) = [];
                
                refreshProjectFiles(app, [], 'FileListChanged:Del')
            end

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Color = [0.9412 0.9412 0.9412];
            app.UIFigure.Position = [100 100 1244 660];
            app.UIFigure.Name = 'monitorSPED';
            app.UIFigure.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'icon_16.png');
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @closeFcn, true);
            app.UIFigure.HandleVisibility = 'on';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {54, '1x'};
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.AutoResizeChildren = 'off';
            app.TabGroup.Layout.Row = [1 2];
            app.TabGroup.Layout.Column = 1;

            % Create Tab1_File
            app.Tab1_File = uitab(app.TabGroup);
            app.Tab1_File.AutoResizeChildren = 'off';
            app.Tab1_File.BackgroundColor = 'none';
            app.Tab1_File.ForegroundColor = [0.129411764705882 0.129411764705882 0.129411764705882];

            % Create file_Grid
            app.file_Grid = uigridlayout(app.Tab1_File);
            app.file_Grid.ColumnWidth = {10, 360, '1x', 10, '0.25x', 360, 10};
            app.file_Grid.RowHeight = {94, 10, '1x', 10, 34};
            app.file_Grid.ColumnSpacing = 0;
            app.file_Grid.RowSpacing = 0;
            app.file_Grid.Padding = [0 0 0 40];
            app.file_Grid.BackgroundColor = [1 1 1];

            % Create tool_Grid
            app.tool_Grid = uigridlayout(app.file_Grid);
            app.tool_Grid.ColumnWidth = {22, 5, 22, 22, '1x', 22, 22, 22};
            app.tool_Grid.RowHeight = {4, 17, 2};
            app.tool_Grid.ColumnSpacing = 5;
            app.tool_Grid.RowSpacing = 0;
            app.tool_Grid.Padding = [10 5 10 5];
            app.tool_Grid.Layout.Row = 5;
            app.tool_Grid.Layout.Column = [1 7];
            app.tool_Grid.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];

            % Create tool_ReadFiles
            app.tool_ReadFiles = uiimage(app.tool_Grid);
            app.tool_ReadFiles.ScaleMethod = 'none';
            app.tool_ReadFiles.ImageClickedFcn = createCallbackFcn(app, @Toolbar_SelectFileToReadImageClicked, true);
            app.tool_ReadFiles.Layout.Row = [1 3];
            app.tool_ReadFiles.Layout.Column = 1;
            app.tool_ReadFiles.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Import_16.png');

            % Create tool_Separator1
            app.tool_Separator1 = uiimage(app.tool_Grid);
            app.tool_Separator1.ScaleMethod = 'none';
            app.tool_Separator1.Enable = 'off';
            app.tool_Separator1.Layout.Row = [1 3];
            app.tool_Separator1.Layout.Column = 2;
            app.tool_Separator1.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'LineV.svg');

            % Create tool_MergeFiles
            app.tool_MergeFiles = uiimage(app.tool_Grid);
            app.tool_MergeFiles.ScaleMethod = 'none';
            app.tool_MergeFiles.ImageClickedFcn = createCallbackFcn(app, @Toolbar_MergeFilesImageClicked, true);
            app.tool_MergeFiles.Enable = 'off';
            app.tool_MergeFiles.Layout.Row = [1 3];
            app.tool_MergeFiles.Layout.Column = 3;
            app.tool_MergeFiles.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Merge_18.png');

            % Create tool_CheckRFB
            app.tool_CheckRFB = uiimage(app.tool_Grid);
            app.tool_CheckRFB.ScaleMethod = 'fill';
            app.tool_CheckRFB.ImageClickedFcn = createCallbackFcn(app, @Toolbar_CheckStatusImageClicked, true);
            app.tool_CheckRFB.Enable = 'off';
            app.tool_CheckRFB.Layout.Row = [1 3];
            app.tool_CheckRFB.Layout.Column = 4;
            app.tool_CheckRFB.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'receita-federal-novo-logo-png_seeklogo-203693.png');

            % Create tool_OpenPopupProject
            app.tool_OpenPopupProject = uiimage(app.tool_Grid);
            app.tool_OpenPopupProject.ScaleMethod = 'none';
            app.tool_OpenPopupProject.ImageClickedFcn = createCallbackFcn(app, @Toolbar_OpenPopupProjectImageClicked, true);
            app.tool_OpenPopupProject.Layout.Row = [1 3];
            app.tool_OpenPopupProject.Layout.Column = 6;
            app.tool_OpenPopupProject.ImageSource = 'organization-20px-black.svg';

            % Create tool_GenerateReport
            app.tool_GenerateReport = uiimage(app.tool_Grid);
            app.tool_GenerateReport.ScaleMethod = 'none';
            app.tool_GenerateReport.ImageClickedFcn = createCallbackFcn(app, @Toolbar_GenerateReportImageClicked, true);
            app.tool_GenerateReport.Enable = 'off';
            app.tool_GenerateReport.Layout.Row = [1 3];
            app.tool_GenerateReport.Layout.Column = 7;
            app.tool_GenerateReport.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Publish_HTML_16.png');

            % Create tool_UploadFinalFile
            app.tool_UploadFinalFile = uiimage(app.tool_Grid);
            app.tool_UploadFinalFile.ScaleMethod = 'none';
            app.tool_UploadFinalFile.ImageClickedFcn = createCallbackFcn(app, @Toolbar_UploadFinalFileImageClicked, true);
            app.tool_UploadFinalFile.Enable = 'off';
            app.tool_UploadFinalFile.Layout.Row = [1 3];
            app.tool_UploadFinalFile.Layout.Column = 8;
            app.tool_UploadFinalFile.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'up-20px.png');

            % Create SubTabGroup
            app.SubTabGroup = uitabgroup(app.file_Grid);
            app.SubTabGroup.AutoResizeChildren = 'off';
            app.SubTabGroup.Layout.Row = 1;
            app.SubTabGroup.Layout.Column = [2 6];

            % Create SubTab1
            app.SubTab1 = uitab(app.SubTabGroup);
            app.SubTab1.AutoResizeChildren = 'off';
            app.SubTab1.Title = 'ARQUIVOS';
            app.SubTab1.BackgroundColor = 'none';
            app.SubTab1.ForegroundColor = [0.129411764705882 0.129411764705882 0.129411764705882];

            % Create SubGrid1
            app.SubGrid1 = uigridlayout(app.SubTab1);
            app.SubGrid1.ColumnWidth = {22, 150, '1x', 22};
            app.SubGrid1.RowHeight = {22, 22};
            app.SubGrid1.ColumnSpacing = 5;
            app.SubGrid1.RowSpacing = 5;
            app.SubGrid1.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create FileModuleIntroduction
            app.FileModuleIntroduction = uilabel(app.SubGrid1);
            app.FileModuleIntroduction.VerticalAlignment = 'top';
            app.FileModuleIntroduction.WordWrap = 'on';
            app.FileModuleIntroduction.FontSize = 11;
            app.FileModuleIntroduction.FontColor = [0.149 0.149 0.149];
            app.FileModuleIntroduction.Layout.Row = 1;
            app.FileModuleIntroduction.Layout.Column = [1 4];
            app.FileModuleIntroduction.Text = 'Este aplicativo permite a leitura de arquivos textuais da Escrituração Contábil Digital (ECD) e a sua análise.';

            % Create FileSortMethodIcon
            app.FileSortMethodIcon = uiimage(app.SubGrid1);
            app.FileSortMethodIcon.ScaleMethod = 'none';
            app.FileSortMethodIcon.Layout.Row = 2;
            app.FileSortMethodIcon.Layout.Column = 1;
            app.FileSortMethodIcon.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'sort_az_ascending.png');

            % Create FileSortMethodSelector
            app.FileSortMethodSelector = uidropdown(app.SubGrid1);
            app.FileSortMethodSelector.Items = {'CNPJ', 'PERÍODO FISCAL', 'RECEITA FEDERAL'};
            app.FileSortMethodSelector.ValueChangedFcn = createCallbackFcn(app, @onFileSortMethodValueChanged, true);
            app.FileSortMethodSelector.FontSize = 10;
            app.FileSortMethodSelector.BackgroundColor = [0.9804 0.9804 0.9804];
            app.FileSortMethodSelector.Layout.Row = 2;
            app.FileSortMethodSelector.Layout.Column = 2;
            app.FileSortMethodSelector.Value = 'CNPJ';

            % Create FileModuleLegend
            app.FileModuleLegend = uiimage(app.SubGrid1);
            app.FileModuleLegend.ScaleMethod = 'none';
            app.FileModuleLegend.ImageClickedFcn = createCallbackFcn(app, @Toolbar_ShowLegendFileModuleLegendClicked, true);
            app.FileModuleLegend.Layout.Row = 2;
            app.FileModuleLegend.Layout.Column = 4;
            app.FileModuleLegend.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Legend_16.png');

            % Create FileMetadata
            app.FileMetadata = uilabel(app.file_Grid);
            app.FileMetadata.VerticalAlignment = 'top';
            app.FileMetadata.WordWrap = 'on';
            app.FileMetadata.FontSize = 11;
            app.FileMetadata.Layout.Row = 3;
            app.FileMetadata.Layout.Column = [5 6];
            app.FileMetadata.Interpreter = 'html';
            app.FileMetadata.Text = '';

            % Create FileTree
            app.FileTree = uitree(app.file_Grid);
            app.FileTree.Multiselect = 'on';
            app.FileTree.SelectionChangedFcn = createCallbackFcn(app, @onTreeSelectionChanged, true);
            app.FileTree.FontSize = 11;
            app.FileTree.Layout.Row = 3;
            app.FileTree.Layout.Column = [2 3];

            % Create Tab2_Playback
            app.Tab2_Playback = uitab(app.TabGroup);
            app.Tab2_Playback.AutoResizeChildren = 'off';
            app.Tab2_Playback.BackgroundColor = 'none';
            app.Tab2_Playback.ForegroundColor = [0.129411764705882 0.129411764705882 0.129411764705882];

            % Create Tab3_Config
            app.Tab3_Config = uitab(app.TabGroup);
            app.Tab3_Config.AutoResizeChildren = 'off';
            app.Tab3_Config.BackgroundColor = 'none';
            app.Tab3_Config.ForegroundColor = [0.129411764705882 0.129411764705882 0.129411764705882];

            % Create NavBar
            app.NavBar = uigridlayout(app.GridLayout);
            app.NavBar.ColumnWidth = {101, '1x', 34, 34, 5, 34, '1x', 20, 20, 1, 20, 20};
            app.NavBar.RowHeight = {5, 7, 20, 7, 5};
            app.NavBar.ColumnSpacing = 5;
            app.NavBar.RowSpacing = 0;
            app.NavBar.Padding = [10 5 5 5];
            app.NavBar.Tag = 'COLORLOCKED';
            app.NavBar.Layout.Row = 1;
            app.NavBar.Layout.Column = 1;
            app.NavBar.BackgroundColor = [0.2 0.2 0.2];

            % Create AppName
            app.AppName = uilabel(app.NavBar);
            app.AppName.WordWrap = 'on';
            app.AppName.FontSize = 11;
            app.AppName.FontColor = [1 1 1];
            app.AppName.Layout.Row = [1 5];
            app.AppName.Layout.Column = [1 2];
            app.AppName.Interpreter = 'html';
            app.AppName.Text = {'monitorSPED v. 1.00.0'; '<font style="font-size: 9px;">R2024a</font>'};

            % Create Tab1Button
            app.Tab1Button = uibutton(app.NavBar, 'state');
            app.Tab1Button.ValueChangedFcn = createCallbackFcn(app, @onTabNavigatorButtonPushed, true);
            app.Tab1Button.Tag = 'FILE';
            app.Tab1Button.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'folder-active-24px-yellow.svg');
            app.Tab1Button.Text = '';
            app.Tab1Button.BackgroundColor = [0.2 0.2 0.2];
            app.Tab1Button.Layout.Row = [2 4];
            app.Tab1Button.Layout.Column = 3;
            app.Tab1Button.Value = true;

            % Create Tab2Button
            app.Tab2Button = uibutton(app.NavBar, 'state');
            app.Tab2Button.ValueChangedFcn = createCallbackFcn(app, @onTabNavigatorButtonPushed, true);
            app.Tab2Button.Tag = 'ECD';
            app.Tab2Button.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'graph-24px-white.svg');
            app.Tab2Button.Text = '';
            app.Tab2Button.BackgroundColor = [0.2 0.2 0.2];
            app.Tab2Button.Layout.Row = [2 4];
            app.Tab2Button.Layout.Column = 4;

            % Create ButtonsSeparator
            app.ButtonsSeparator = uiimage(app.NavBar);
            app.ButtonsSeparator.ScaleMethod = 'none';
            app.ButtonsSeparator.Enable = 'off';
            app.ButtonsSeparator.Layout.Row = [2 4];
            app.ButtonsSeparator.Layout.Column = 5;
            app.ButtonsSeparator.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'LineV_White.svg');

            % Create Tab3Button
            app.Tab3Button = uibutton(app.NavBar, 'state');
            app.Tab3Button.ValueChangedFcn = createCallbackFcn(app, @onTabNavigatorButtonPushed, true);
            app.Tab3Button.Tag = 'CONFIG';
            app.Tab3Button.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'gear-24px-white.svg');
            app.Tab3Button.Text = '';
            app.Tab3Button.BackgroundColor = [0.2 0.2 0.2];
            app.Tab3Button.Layout.Row = [2 4];
            app.Tab3Button.Layout.Column = 6;

            % Create jsBackDoor
            app.jsBackDoor = uihtml(app.NavBar);
            app.jsBackDoor.Layout.Row = 3;
            app.jsBackDoor.Layout.Column = 8;

            % Create DataHubLamp
            app.DataHubLamp = uiimage(app.NavBar);
            app.DataHubLamp.ScaleMethod = 'fill';
            app.DataHubLamp.ImageClickedFcn = createCallbackFcn(app, @onTabNavigatorButtonPushed, true);
            app.DataHubLamp.Visible = 'off';
            app.DataHubLamp.Layout.Row = 3;
            app.DataHubLamp.Layout.Column = 9;
            app.DataHubLamp.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'red-circle-blink.gif');

            % Create FigurePosition
            app.FigurePosition = uiimage(app.NavBar);
            app.FigurePosition.ScaleMethod = 'none';
            app.FigurePosition.ImageClickedFcn = createCallbackFcn(app, @onTabNavigatorButtonPushed, true);
            app.FigurePosition.Visible = 'off';
            app.FigurePosition.Layout.Row = 3;
            app.FigurePosition.Layout.Column = 11;
            app.FigurePosition.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'screen-normal-24px-white.svg');

            % Create AppInfo
            app.AppInfo = uiimage(app.NavBar);
            app.AppInfo.ScaleMethod = 'none';
            app.AppInfo.ImageClickedFcn = createCallbackFcn(app, @onTabNavigatorButtonPushed, true);
            app.AppInfo.Layout.Row = 3;
            app.AppInfo.Layout.Column = 12;
            app.AppInfo.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'kebab-vertical-24px-white.svg');

            % Create ContextMenu
            app.ContextMenu = uicontextmenu(app.UIFigure);
            app.ContextMenu.Tag = 'winMonitorSPED';

            % Create contextmenu_merge
            app.contextmenu_merge = uimenu(app.ContextMenu);
            app.contextmenu_merge.MenuSelectedFcn = createCallbackFcn(app, @Toolbar_MergeFilesImageClicked, true);
            app.contextmenu_merge.Enable = 'off';
            app.contextmenu_merge.Text = '🔀 Mesclar';

            % Create contextmenu_del
            app.contextmenu_del = uimenu(app.ContextMenu);
            app.contextmenu_del.MenuSelectedFcn = createCallbackFcn(app, @ContextMenu_DeleteSelectedTreeNode, true);
            app.contextmenu_del.Enable = 'off';
            app.contextmenu_del.Text = '❌ Excluir';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = winMonitorSPED_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
