classdef winMonitorSPED_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        GridLayout               matlab.ui.container.GridLayout
        NavBar                   matlab.ui.container.GridLayout
        AppInfo                  matlab.ui.control.Image
        FigurePosition           matlab.ui.control.Image
        DataHubLamp              matlab.ui.control.Image
        jsBackDoor               matlab.ui.control.HTML
        Tab3Button               matlab.ui.control.StateButton
        ButtonsSeparator         matlab.ui.control.Image
        Tab2Button               matlab.ui.control.StateButton
        Tab1Button               matlab.ui.control.StateButton
        AppName                  matlab.ui.control.Label
        AppIcon                  matlab.ui.control.Image
        TabGroup                 matlab.ui.container.TabGroup
        Tab1_File                matlab.ui.container.Tab
        file_Grid                matlab.ui.container.GridLayout
        file_Tree                matlab.ui.container.Tree
        file_Metadata            matlab.ui.control.Label
        TabGroup2                matlab.ui.container.TabGroup
        ARQUIVOSTab              matlab.ui.container.Tab
        GridLayout2              matlab.ui.container.GridLayout
        Image                    matlab.ui.control.Image
        file_FileSortMethodIcon  matlab.ui.control.Image
        file_FileSortMethod      matlab.ui.control.DropDown
        file_ModuleIntro         matlab.ui.control.Label
        file_toolGrid            matlab.ui.container.GridLayout
        tool_UploadFinalFile     matlab.ui.control.Image
        tool_GenerateReport      matlab.ui.control.Image
        tool_CheckRFB            matlab.ui.control.Image
        tool_Separator2          matlab.ui.control.Image
        tool_MergeFiles          matlab.ui.control.Image
        tool_ReadFiles           matlab.ui.control.Image
        tool_Separator1          matlab.ui.control.Image
        tool_SelectFilesToRead   matlab.ui.control.Image
        Tab2_Playback            matlab.ui.container.Tab
        Tab3_Config              matlab.ui.container.Tab
        ContextMenu              matlab.ui.container.ContextMenu
        contextmenu_merge        matlab.ui.container.Menu
        contextmenu_del          matlab.ui.container.Menu
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        Role = 'mainApp'
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
                            selectedNodes = app.file_Tree.SelectedNodes;
                            if ~isempty(app.file_Tree.SelectedNodes)
                                app.file_Tree.SelectedNodes = [];
                                file_TreeSelectionChanged(app)
                            end

                            appEngine.beforeReload(app, app.Role)
                            appEngine.activate(app, app.Role, MFilePath, parpoolFlag)

                            if ~isempty(selectedNodes)
                                app.file_Tree.SelectedNodes = selectedNodes;
                                file_TreeSelectionChanged(app)
                            end
                        end
                        
                        app.renderCount = app.renderCount+1;

                    case 'unload'
                        closeFcn(app)
                    
                    case 'customForm'
                        switch event.HTMLEventData.uuid
                            case 'eFiscalizaSignInPage'
                                context = event.HTMLEventData.context;
                                report_uploadInfoController(app, event.HTMLEventData, 'uploadDocument', context)

                            case 'eFiscalizaSignInPage:IssueQuery'
                                context = event.HTMLEventData.context;
                                report_queryIssueDetails(app, event.HTMLEventData, context)

                            case 'openDevTools'
                                if isequal(app.General.operationMode.DevTools, rmfield(event.HTMLEventData, 'uuid'))
                                    webWin = struct(struct(struct(app.UIFigure).Controller).PlatformHost).CEF;
                                    webWin.openDevTools();
                                end

                            case 'onProjectSave'
                                context = event.HTMLEventData.context;
                                prjName = event.HTMLEventData.projectName;
                                report_saveProject(app, context, prjName)
                        end

                    case 'getNavigatorBasicInformation'
                        app.General.AppVersion.browser = event.HTMLEventData;

                    case 'getCssPropertyValue'
                        componentName = event.HTMLEventData.componentName;

                        if ~isempty(componentName)
                            if ~isprop(app, 'isDocked') % mainApp (app container)
                                auxAppTag = event.HTMLEventData.auxAppTag;
                                if ~isempty(auxAppTag)
                                    hAuxApp   = getAppHandle(app.tabGroupController, auxAppTag);
                                    objHandle = hAuxApp.(componentName);
                                else
                                    objHandle = eval(['app.' componentName]);
                                end
                            else
                                objHandle = eval(['app.' componentName]);
                            end
                            
                            cssProp  = event.HTMLEventData.propertyName;
                            cssValue = event.HTMLEventData.propertyValue;
    
                            if ~isprop(objHandle, 'StyleObservations')
                                objHandle.addprop('StyleObservations');
                            end
                            objHandle.StyleObservations.(cssProp) = cssValue;
                        end

                    % MAINAPP
                    case 'mainApp.file_Tree'
                        contextMenu_delTreeNodeSelected(app)

                    otherwise
                        error('UnexpectedEvent')
                end
                drawnow

            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME));
            end
        end

        %-----------------------------------------------------------------%
        function varargout = ipcMainMatlabCallsHandler(app, callingApp, operationType, varargin)
            varargout = {};

            try
                switch class(callingApp)
                    % auxApp.winConfig
                    case {'auxApp.winConfig', 'auxApp.winConfig_exported'}
                        switch operationType
                            case 'closeFcn'
                                closeModule(app.tabGroupController, "CONFIG", app.General)

                            case 'dockButtonPushed'
                                auxAppTag = varargin{1};
                                varargout{1} = auxAppInputArguments(app, auxAppTag);

                            case 'checkDataHubLampStatus'
                                DataHubWarningLamp(app)

                            case 'openDevTools'
                                dialogBox    = struct('id', 'login',    'label', 'Usuário: ', 'type', 'text');
                                dialogBox(2) = struct('id', 'password', 'label', 'Senha: ',   'type', 'password');
                                sendEventToHTMLSource(app.jsBackDoor, 'customForm', struct('UUID', 'openDevTools', 'Fields', dialogBox))

                            case 'simulationModeChanged'
                                if app.General.operationMode.Simulation
                                    toolbar_SelectFileToReadImageClicked(app)

                                    % Muda programaticamente o modo p/ ARQUIVOS.
                                    set(app.Tab1Button, 'Enable', 1, 'Value', 1)                    
                                    tabNavigatorButtonPushed(app, struct('Source', app.Tab1Button, 'PreviousValue', false))
                                end

                            case 'fileSortMethodChanged'
                                if ~strcmp(app.file_FileSortMethod.Value, app.General.File.sortMethod)
                                    app.file_FileSortMethod.Value = app.General.File.sortMethod;
                                    file_FileSortMethodValueChanged(app)
                                end

                            case {'PISValueChanged', 'COFINSValueChanged'}
                                error('Pendente de implementação! :(')

                            otherwise
                                error('UnexpectedCall')
                        end

                    % auxApp.winECD
                    case {'auxApp.winECD', 'auxApp.winECD_exported'}
                        switch operationType
                            case 'closeFcn'
                                closeModule(app.tabGroupController, "ECD", app.General)

                            case 'dockButtonPushed'
                                auxAppTag = varargin{1};
                                varargout{1} = auxAppInputArguments(app, auxAppTag);

                            case 'updateTreeView'
                                if ~isempty(app.file_Tree.SelectedNodes)
                                    nodeData = unique([app.file_Tree.SelectedNodes.NodeData]);

                                    if isequal(nodeData, varargin{1})
                                        app.file_Metadata.UserData = [];
                                        file_TreeSelectionChanged(app)
                                    end
                                end

                            otherwise
                                error('UnexpectedCall')
                        end

                    % auxApp.dockReportLib
                    case {'auxApp.dockReportLib', 'auxApp.dockReportLib_exported'}
                        switch operationType
                            case 'closeFcn'
                                context = varargin{1};
                                switch context
                                    case 'File'
                                        app.popupContainer.Parent.Visible = 0;
                                    case 'ECD'
                                        varargin = [{'closeFcnCallFromDockModule'}, varargin];
                                        ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})
                                end

                            case 'reportUserConfirmation'
                                context = varargin{1};
                                indexes = varargin{2};

                                delete(callingApp)
                                ipcMainMatlabCallsHandler(app, callingApp, 'closeFcn', varargin{:});
                                reportGeneratorCall(app, context, indexes)

                            otherwise
                                error('UnexpectedCall')
                        end

                    % auxApp.dockECDExport
                    case {'auxApp.dockECDExport', 'auxApp.dockECDExport_exported'}
                        switch operationType
                            case 'closeFcn'
                                context  = varargin{1};
                                varargin = [{'closeFcnCallFromDockModule'}, varargin(2:end)];
                                ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})

                            case 'exportECD'
                                delete(callingApp)
                                
                                context  = varargin{1};
                                varargin = [{operationType}, varargin(2:end)];
                                ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})

                            otherwise
                                error('UnexpectedCall')
                        end

                    % auxApp.dockECDAccount
                    case {'auxApp.dockECDAccount', 'auxApp.dockECDAccount_exported'}
                        switch operationType
                            case 'closeFcn'
                                context  = varargin{1};
                                varargin = [{'closeFcnCallFromDockModule'}, varargin(2:end)];
                                ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})

                            case 'accountEdited'
                                context  = varargin{1};
                                varargin = [{operationType}, varargin(2:end)];
                                ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})
                                return

                            otherwise
                                error('UnexpectedCall')
                        end

                    % auxApp.dockECDFilter
                    case {'auxApp.dockECDFilter', 'auxApp.dockECDFilter_exported'}
                        switch operationType
                            case 'closeFcn'
                                context  = varargin{1};
                                varargin = [{'closeFcnCallFromDockModule'}, varargin(2:end)];
                                ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})
                                
                                % Apaga menu de contexto:
                                hAuxApp = getAppHandle(app.tabGroupController, context);
                                if ~isempty(hAuxApp)
                                    deleteContextMenu(app.tabGroupController, hAuxApp.UIFigure, 'auxApp.dockECDFilter')
                                end

                            case {'changeFilter', 'tableNotRead'}
                                context  = varargin{1};
                                varargin = [{operationType}, varargin(2:end)];
                                ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})
                                return

                            otherwise
                                error('UnexpectedCall')
                        end

                    % auxApp.dockECDFilter
                    case {'auxApp.dockECDMemoryUsage', 'auxApp.dockECDMemoryUsage_exported'}
                        switch operationType
                            case 'closeFcn'
                                context  = varargin{1};
                                varargin = [{'closeFcnCallFromDockModule'}, varargin(2:end)];
                                ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})

                            case 'freeMemory'
                                context  = varargin{1};
                                varargin = [{operationType}, varargin(2:end)];
                                ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', varargin{:})
                                return

                            otherwise
                                error('UnexpectedCall')
                        end
    
                    otherwise
                        error('UnexpectedCaller')
                end

            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME));            
            end

            % Caso um app auxiliar esteja em modo DOCK, o progressDialog do
            % app auxiliar coincide com o do appAnalise. Força-se, portanto, 
            % a condição abaixo para evitar possível bloqueio da tela.
            app.progressDialog.Visible = 'hidden';
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
        function ipcMainMatlabOpenPopupApp(app, callingApp, auxAppName, varargin)
            arguments
                app
                callingApp
                auxAppName char {mustBeMember(auxAppName, {'ReportLib', 'ECDExport', 'ECDAccount', 'ECDFilter', 'ECDMemoryUsage'})}
            end

            arguments (Repeating)
                varargin 
            end

            switch auxAppName
                case 'ReportLib'
                    screenWidth  = 460;
                    screenHeight = 308;
                case 'ECDExport'
                    screenWidth  = 460;
                    screenHeight = 404;
                case 'ECDAccount'
                    screenWidth  = 720;
                    screenHeight = 580;
                case 'ECDFilter'
                    screenWidth  = 640;
                    screenHeight = 376;
                case 'ECDMemoryUsage'
                    screenWidth  = 460;
                    screenHeight = 580;
            end

            requestVisibilityChange(callingApp.progressDialog, 'visible', 'unlocked')
            ui.PopUpContainer(callingApp, class.Constants.appName, screenWidth, screenHeight)

            % Executa o app auxiliar.
            inputArguments = [{app, callingApp}, varargin];
            auxDockAppName = sprintf('auxApp.dock%s', auxAppName);
            
            if app.General.operationMode.Debug
                eval(sprintf('auxApp.dock%s(inputArguments{:})', auxAppName))
            else
                eval([auxDockAppName '_exported(callingApp.popupContainer, inputArguments{:})'])
                
                callingApp.popupContainer.UserData.auxDockAppName = auxDockAppName;
                callingApp.popupContainer.Parent.Visible = 1;
            end

            requestVisibilityChange(callingApp.progressDialog, 'hidden', 'unlocked')
        end
    end
    
    
    methods (Access = public)
        %-----------------------------------------------------------------%
        function navigateToTab(app, clickedButton)
            tabNavigatorButtonPushed(app, struct('Source', clickedButton, 'PreviousValue', false))
        end

        %-----------------------------------------------------------------%
        function applyJSCustomizations(app, tabIndex)
            persistent customizationStatus
            if isempty(customizationStatus)
                customizationStatus = [false, false, false];
            end

            switch tabIndex
                case 0
                    sendEventToHTMLSource(app.jsBackDoor, 'startup', app.executionMode);
                    customizationStatus = [false, false, false];

                otherwise
                    if customizationStatus(tabIndex)
                        return
                    end

                    customizationStatus(tabIndex) = true;
                    switch tabIndex
                        case 1 % FILE
                            elToModify = {app.file_Tree, app.file_Metadata};
                            ui.CustomizationBase.getElementsDataTag(elToModify);

                            appName = class(app);
                            try
                                sendEventToHTMLSource(app.jsBackDoor, 'initializeComponents', {struct('appName', appName, 'dataTag', elToModify{1}.UserData.id, 'listener', struct('componentName', 'mainApp.file_Tree', 'keyEvents', {{'Delete', 'Backspace'}}))});
                            catch ME
                                ui.Dialog(app.UIFigure, 'error', getReport(ME));
                            end

                            try
                                ui.TextView.startup(app.jsBackDoor, elToModify{2}, appName);
                            catch ME
                                ui.Dialog(app.UIFigure, 'error', getReport(ME));
                            end

                        otherwise
                            % Customização dos módulos que são renderizados
                            % nesta figura são controladas pelos próprios
                            % módulos.
                    end
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

            if ~ismember(app.General_I.File.input, {'file', 'folder'})
                app.General_I.File.input = 'file';
            end

            if ~ismember(app.General_I.File.sortMethod, {'CNPJ', 'PERÍODO FISCAL', 'RECEITA FEDERAL'})
                app.General_I.File.sortMethod = 'CNPJ';
            end

            if ~ismember(app.General_I.File.checkStatus, {'OnlyCache', 'Cache+RealTime', 'RealTime'})
                app.General_I.File.checkStatus = 'Cache+RealTime';
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

                    % A renderização do plot no MATLAB WebServer, enviando-o à uma 
                    % sessão do webapp como imagem Base64, é crítica por depender 
                    % das comunicações WebServer-webapp e WebServer-BaseMapServer. 
                    % Ao configurar o Basemap como "none", entretanto, elimina-se a 
                    % necessidade de comunicação com BaseMapServer, além de tornar 
                    % mais eficiente a comunicação com webapp porque as imagens
                    % Base64 são menores (uma imagem com Basemap "sattelite" pode 
                    % ter 500 kB, enquanto uma imagem sem Basemap pode ter 25 kB).
                    app.General_I.Plot.GeographicAxes.Basemap = 'none';

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

            app.General            = app.General_I;        
            app.General.AppVersion = util.getAppVersion(app.rootFolder, MFilePath, tempDir);
            sendEventToHTMLSource(app.jsBackDoor, 'getNavigatorBasicInformation')
        end

        %-----------------------------------------------------------------%
        function initializeAppProperties(app)
            app.projectData = model.projectLib(app, app.rootFolder);
            app.receitaFederalObj = ws.ReceitaFederal();
        end

        %-----------------------------------------------------------------%
        function initializeUIComponents(app)
            app.tabGroupController = ui.TabNavigator(app.NavBar, app.TabGroup, app.progressDialog, @app.applyJSCustomizations, []);
            addComponent(app.tabGroupController, "Built-in", "",                 app.Tab1Button, "AlwaysOn", struct('On', 'OpenFile_32Yellow.png', 'Off', 'OpenFile_32White.png'), matlab.graphics.GraphicsPlaceholder, 1)
            addComponent(app.tabGroupController, "External", "auxApp.winECD",    app.Tab2Button, "AlwaysOn", struct('On', 'Zoom_32Yellow.png',     'Off', 'Zoom_32White.png'),     app.Tab1Button,                      2)
            addComponent(app.tabGroupController, "External", "auxApp.winConfig", app.Tab3Button, "AlwaysOn", struct('On', 'Settings_36Yellow.png', 'Off', 'Settings_36White.png'), app.Tab1Button,                      3)

            addStyle(app.file_Tree, uistyle('Interpreter', 'html'))
        end

        %-----------------------------------------------------------------%
        function applyInitialLayout(app)
            DataHubWarningLamp(app)
            app.file_FileSortMethod.Value = app.General.File.sortMethod;
        end

        %-----------------------------------------------------------------%
        function DataHubWarningLamp(app)
            if isfolder(app.General.fileFolder.DataHub_POST)
                app.DataHubLamp.Visible = 0;
            else
                app.DataHubLamp.Visible = 1;
            end
        end

        %-----------------------------------------------------------------%
        function file_ProjectRestart(app, indexes, updateType)
            arguments
                app
                indexes
                updateType char {mustBeMember(updateType, {'FileListChanged:Add', ...
                                                           'FileListChanged:Del', ...
                                                           'FileListChanged:Merge', ...
                                                           'FilesReordered', ...
                                                           'FileFullyLoaded', ...
                                                           'FileStatusChecked'})}
            end

            file_TreeBuilding(app, indexes)

            if contains(updateType, 'FileListChanged')
                ipcMainMatlabCallAuxiliarApp(app, 'ECD', 'MATLAB', updateType)
            end
        end

        %-----------------------------------------------------------------%
        function file_TreeBuilding(app, selectedNodeData)
            arguments
                app
                selectedNodeData = []
            end

            if ~isempty(app.file_Tree.Children)
                app.file_Metadata.UserData = [];
                delete(app.file_Tree.Children)
            end

            idsList = {app.ecdObj.CompanyId};
            selectedNode = [];
            
            if ~isempty(idsList)
                ids = unique(idsList);

                switch app.file_FileSortMethod.Value
                    case 'CNPJ'
                        selectedNode = file_createTreeElements(app, idsList, ids, selectedNode, selectedNodeData);
                    otherwise
                        switch app.file_FileSortMethod.Value
                            case 'PERÍODO FISCAL'
                                validTreeNodeText = '<font style="color: blue; font-weight: bold; text-decoration: underline;">VÁLIDOS</font> EM RELAÇÃO AO CRITÉRIO "PERÍODO FISCAL ANUAL"';
                            case 'RECEITA FEDERAL'
                                validTreeNodeText = '<font style="color: blue; font-weight: bold; text-decoration: underline;">VÁLIDOS</font> EM RELAÇÃO AO CRITÉRIO "ARQUIVO CONSTA NA BASE DA RECEITA FEDERAL"';
                        end
                        validTreeNode   = uitreenode(app.file_Tree, 'Text', validTreeNodeText);
                        selectedNode    = file_createTreeElements(app, idsList, ids, selectedNode, selectedNodeData, validTreeNode,   'only-valid');
                        
                        invalidTreeNode = uitreenode(app.file_Tree, 'Text', '<font style="color: red; font-weight: bold; text-decoration: underline;">INVÁLIDOS</font>');
                        selectedNode    = file_createTreeElements(app, idsList, ids, selectedNode, selectedNodeData, invalidTreeNode, 'only-invalid');
                end
            end

            expand(app.file_Tree, 'all')

            if ~isempty(app.file_Tree.Children)
                if ~isempty(selectedNode)
                    app.file_Tree.SelectedNodes = selectedNode;
                else
                    if isempty(app.file_Tree.Children(1).Children)
                        app.file_Tree.SelectedNodes = app.file_Tree.Children(1);
                    else
                        app.file_Tree.SelectedNodes = app.file_Tree.Children(1).Children(1);
                    end
                end
            end

            file_TreeSelectionChanged(app)
        end

        %-----------------------------------------------------------------%
        function selectedNode = file_createTreeElements(app, idsList, ids, selectedNode, selectedNodeData, varargin)
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

            switch app.file_FileSortMethod.Value
                case 'CNPJ'
                    parentNode = app.file_Tree;
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
                if ismember(app.file_FileSortMethod.Value, {'PERÍODO FISCAL', 'RECEITA FEDERAL'})
                    for ii = numel(idIndexes):-1:1
                        index = idIndexes(ii);
    
                        switch app.file_FileSortMethod.Value
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
        function indexes = file_findSelectedNodeData(app)
            indexes = [];
            if ~isempty(app.file_Tree.SelectedNodes)
                indexes = unique([app.file_Tree.SelectedNodes.NodeData]);
            end
        end

        %-----------------------------------------------------------------%
        function updateToolbar(app)
            context = 'File';
            indexes = file_findSelectedNodeData(app);

            nonEmptySelection               = ~isempty(indexes);
            nonScalarSelection              = ~isscalar(indexes);
            reportFinalVersionGenerated     = ~isempty(app.projectData.modules.(context).generatedFiles.lastHTMLDocFullPath);

            app.tool_ReadFiles.Enable       = nonEmptySelection;
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


    methods
        %-----------------------------------------------------------------%
        % SISTEMA DE GESTÃO DA FISCALIZAÇÃO (eFiscaliza/SEI)
        %-----------------------------------------------------------------%
        function report_saveProject(app, context, prjName)
            if isfile(app.projectData.file)
                [defaultPath, defaultFile] = fileparts(app.projectData.file);
                defaultName = fullfile(defaultPath, defaultFile);
            else
                defaultName = class.Constants.DefaultFileName(app.General.fileFolder.userPath, 'monitorSPED_ProjectData', -1);
            end
            
            prjFile = ui.Dialog(app.UIFigure, 'uiputfile', '', {'*.mat', 'monitorSPED (*.mat)'}, defaultName);
            if isempty(prjFile)
                return
            end

            app.progressDialog.Visible = 'visible';

            try
                Save(app.projectData, app.ecdObj, context, prjName, prjFile, app.General.Report.outputCompressionMode)
            catch ME
                ui.Dialog(app.UIFigure, 'error', ME.message);
            end

            app.progressDialog.Visible = 'hidden';
        end

        %-----------------------------------------------------------------%
        function status = report_checkEFiscalizaIssueId(app, issue)
            status = (issue > 0) && (issue < inf);
        end

        %-----------------------------------------------------------------%
        function report_showIssueDetails(app, context)
            issueId      = app.projectData.modules.(context).ui.issue;
            issueDetails = app.projectData.modules.(context).ui.issueDetails;

            if isempty(issueDetails) || issueDetails.issueId ~= issueId
                msg = sprintf('Não identificada informações acerca da Atividade de Inspeção nº %d', issueId);
            else
                dataStruct = struct('group', 'ATIVIDADE DE INSPEÇÃO', 'value', issueDetails);
                msg = textFormatGUI.struct2PrettyPrintList(dataStruct, 'print -1', '', 'popup');
            end

            ui.Dialog(app.UIFigure, 'info', msg);
        end

        %-----------------------------------------------------------------%
        function reportGeneratorCall(app, context, indexes)
            hCallingApp = app;
            if ~strcmp(context, 'File')
                hSecondaryApp = getAppHandle(app.tabGroupController, context);
                
                if ~isempty(hSecondaryApp) && isvalid(hSecondaryApp) && ~hSecondaryApp.isDocked
                    hCallingApp = hSecondaryApp;
                end
            end

            hCallingApp.progressDialog.Visible = 'visible';

            try
                reportSettings = struct('context',       context,                                          ...
                                        'system',        app.projectData.modules.(context).ui.system,      ...
                                        'unit',          app.projectData.modules.(context).ui.unit,        ...
                                        'issue',         app.projectData.modules.(context).ui.issue,       ...
                                        'model',         app.projectData.modules.(context).ui.reportModel, ...
                                        'reportVersion', app.projectData.modules.(context).ui.reportVersion);
                reportLibConnection.Controller.Run(app, app.projectData, app.ecdObj(indexes), reportSettings, app.General)

                if strcmp(context, 'File')
                    updateToolbar(app)
                else
                    ipcMainMatlabCallAuxiliarApp(app, context, 'MATLAB', 'generateFinalReport')
                end

            catch ME
                ui.Dialog(hCallingApp.UIFigure, 'error', getReport(ME));
            end

            hCallingApp.progressDialog.Visible = 'hidden';
        end

        %-------------------------------------------------------------------------%
        function report_queryIssueDetails(app, credentials, context)
            app.progressDialog.Visible = 'visible';

            try
                if ~isempty(credentials)
                    app.eFiscalizaObj = ws.eFiscaliza(credentials.login, credentials.password);
                end

                env = strsplit(app.projectData.modules.(context).ui.system);
                if numel(env) < 2
                    env = 'PD';
                else
                    env = env{2};
                end

                issue = struct( ...
                    'type', 'ATIVIDADE DE INSPEÇÃO', ...
                    'id', app.projectData.modules.(context).ui.issue ...
                );
                
                msg = run(app.eFiscalizaObj, env, 'queryIssue', issue);
                if isstruct(msg)
                    app.projectData.modules.(context).ui.issueDetails = msg;
                else
                    error(msg)
                end

            catch ME
                ui.Dialog(app.UIFigure, 'error', ME.message);
            end

            report_showIssueDetails(app, context)            
            app.progressDialog.Visible = 'hidden';
        end

        %-----------------------------------------------------------------%
        function report_uploadInfoController(app, credentials, operation, context)
            [communicationStatus, communicationMessage] = report_sendHTMLDocToSEIviaEFiscaliza(app, credentials, operation, context);
            
            if communicationStatus 
                if strcmp(app.projectData.modules.(context).ui.system, 'eFiscaliza')
                    report_sendFilesToSharepoint(app, context)
                end

                generatedFilesId = app.projectData.modules.(context).generatedFiles.id;
                [~, generatedFilesIdIndex] = ismember(generatedFilesId, {app.ecdObj.Hash});
                if generatedFilesIdIndex
                    update(app.ecdObj(generatedFilesIdIndex), 'GUI.GeneratedFiles', 'updateFinalReportStatus', app.projectData, context, communicationMessage)
                end
            end
        end

        %-------------------------------------------------------------------------%
        function [communicationStatus, communicationMessage] = report_sendHTMLDocToSEIviaEFiscaliza(app, credentials, operation, context)
            app.progressDialog.Visible = 'visible';
            
            try
                if ~isempty(credentials)
                    app.eFiscalizaObj = ws.eFiscaliza(credentials.login, credentials.password);
                end

                env = strsplit(app.projectData.modules.(context).ui.system);
                if numel(env) < 2
                    env = 'PD';
                else
                    env = env{2};
                end

                unit = app.projectData.modules.(context).ui.unit;

                issue = struct( ...
                    'type', 'ATIVIDADE DE INSPEÇÃO', ...
                    'id', app.projectData.modules.(context).ui.issue ...
                );

                switch operation
                    case 'uploadDocument'
                        % O HTML definitivo criado...
                        fileName = getGeneratedDocumentFileName(app.projectData, '.html', context);

                        % Identificando o ID do documento a ser criado no
                        % SEI...
                        [~, modelIdx]   = ismember(app.projectData.modules.(context).ui.reportModel, {app.projectData.report.templates.Name});
                        docType         = app.projectData.report.templates(modelIdx).DocumentType;
                        [~, docTypeIdx] = ismember(docType, {app.General.eFiscaliza.internal.typeIdMapping.type});

                        docSpec = app.General.eFiscaliza;
                        docSpec.originId = docSpec.internal.originId;
                        docSpec.typeId   = app.General.eFiscaliza.internal.typeIdMapping(docTypeIdx).id;

                        msg = run(app.eFiscalizaObj, env, operation, issue, unit, docSpec, fileName);
        
                    otherwise
                        error('Unexpected call')
                end
                
                if ~contains(msg, 'Documento cadastrado no SEI', 'IgnoreCase', true)
                    error(msg)
                end

                modalWindowIcon      = 'success';
                communicationMessage = msg;
                communicationStatus  = true;

            catch ME
                app.eFiscalizaObj    = [];

                modalWindowIcon      = 'error';
                communicationMessage = ME.message;
                communicationStatus  = false;
            end

            ui.Dialog(app.UIFigure, modalWindowIcon, communicationMessage);
            app.progressDialog.Visible = 'hidden';
        end

        %------------------------------------------------------------------------%
        function report_sendFilesToSharepoint(app, context)
            % Evita subir por engano, quando no ambiente de desenvolvimento,
            % de arquivos na pasta "POST".
            try
                if ~isdeployed()
                    error('ForceDebugMode')
                end
                sharepointFolder = app.General.fileFolder.DataHub_POST;
            catch
                sharepointFolder = app.General.fileFolder.userPath;
            end

            try
                sharepointFile = getGeneratedDocumentFileName(app.projectData, '.json', context);
                copyfile(sharepointFile, sharepointFolder, 'f');
            catch ME
                ui.Dialog(app.UIFigure, 'error', getReport(ME))
            end
        end

        %-----------------------------------------------------------------%
        function inputArguments = auxAppInputArguments(app, auxAppTag)
            inputArguments = {app};
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
            if CheckIfUpdateNeeded(app.projectData, app.ecdObj)
                msgQuestion = sprintf([ ...
                    'O projeto "%s" foi modificado (nome, arquivo de saída, ' ...
                    'lista de arquivos de entrada ou tabelas de anotação das ' ...
                    'contas de resultado). Caso o aplicativo seja encerrado ' ...
                    'agora, todas as alterações serão descartadas.\n\n' ...
                    'Deseja realmente fechar o aplicativo?' ...
                    ], app.projectData.name);
            
            elseif ~strcmp(app.executionMode, 'webApp') && ~isempty(app.ecdObj)
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

        % Value changed function: Tab1Button, Tab2Button, Tab3Button
        function tabNavigatorButtonPushed(app, event)

            clickedButton  = event.Source;
            auxAppTag      = clickedButton.Tag;

            inputArguments = auxAppInputArguments(app, auxAppTag);
            openModule(app.tabGroupController, event.Source, event.PreviousValue, app.General, inputArguments{:})
            
        end

        % Image clicked function: AppInfo, FigurePosition
        function menuImageClicked(app, event)

            switch event.Source
                case app.FigurePosition
                    app.UIFigure.Position(3:4) = class.Constants.windowSize;
                    appEngine.util.setWindowPosition(app.UIFigure)

                case app.AppInfo
                    appInfo = util.HtmlTextGenerator.AppInfo(app.General, app.rootFolder, app.executionMode, app.renderCount, "popup");
                    ui.Dialog(app.UIFigure, 'info', appInfo);
            end

        end

        % Selection changed function: file_Tree
        function file_TreeSelectionChanged(app, event)
            
            indexes = file_findSelectedNodeData(app);
            
            if isempty(indexes)
                app.file_Metadata.Text     = '';
                app.file_Metadata.UserData = [];
            else
                if isequal(app.file_Metadata.UserData, indexes)
                    return
                end

                app.file_Metadata.Text     = util.HtmlTextGenerator.File(app.ecdObj(indexes));
                app.file_Metadata.UserData = indexes;
            end

            updateToolbar(app)
            
        end

        % Value changed function: file_FileSortMethod
        function file_FileSortMethodValueChanged(app, event)
            
            indexes = file_findSelectedNodeData(app);
            file_ProjectRestart(app, indexes, 'FilesReordered')

        end

        % Image clicked function: tool_SelectFilesToRead
        function toolbar_SelectFileToReadImageClicked(app, event)

            d = [];
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

                if isempty(fileFullName)
                    msgWarning = 'Nenhum arquivo de simulação foi identificado.';
                    ui.Dialog(app.UIFigure, "warning", msgWarning);
                    return
                end

            else
                switch app.General.File.input
                    case 'file'
                        [~, filePath, ~, fileName] = ui.Dialog( ...
                            app.UIFigure, ...
                            'uigetfile', ...
                            '', ...
                            {'*.txt;*.sped;*.mat', 'monitorSPED (.txt, .sped, .mat)'}, ...
                            app.General.fileFolder.lastVisited, ...
                            {'MultiSelect', 'on'} ...
                        );
            
                        if isempty(fileName)
                            return
                        elseif ~iscell(fileName)
                            fileName = {fileName};
                        end

                        fileFullName = util.getFilesFromCompressedFile(fullfile(filePath, fileName), app.General.fileFolder.tempPath);
    
                    case 'folder'
                        filePath = uigetdir(app.General.fileFolder.lastVisited);
                        figure(app.UIFigure)
    
                        if isequal(filePath, 0)
                            return
                        end
    
                        d = ui.Dialog(app.UIFigure, "progressdlg", "Em andamento...");
                        [fileFullName, fileName] = util.getFilesFromFolder(filePath, {'.txt', '.sped'}, app.General.fileFolder.tempPath);
                end
                updateLastVisitedFolder(app, filePath)
            end

            if isempty(d)
                d = ui.Dialog(app.UIFigure, "progressdlg", "Em andamento...");
            end
            
            filesError = struct('File', {}, 'Error', {});

            for ii = 1:numel(fileFullName)
                d.Message = textFormatGUI.HTMLParagraph(sprintf('Em andamento a leitura do arquivo %d de %d:<br>• <b>%s</b>', ii, numel(fileFullName), fileName{ii}));

                % Verifica se arquivo já foi lido, comparando o seu nome com 
                % a variável app.ecdObj.
                if ~ismember(fileName{ii}, {app.ecdObj.FileName})
                    [~, ~, fileExt] = fileparts(fileFullName{ii});
                    switch fileExt
                        case {'.txt', '.sped'}
                            [app.ecdObj, msg] = addFiles(app.ecdObj, app.projectData, app.General, fileFullName{ii}, [], app.receitaFederalObj);
                        
                        case '.mat'
                            [app.ecdObj, msg] = Load(app.projectData, app.ecdObj, fileFullName{ii}, app.General);
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
            
            % Atualiza app.file_Tree.
            indexes = file_findSelectedNodeData(app);
            file_ProjectRestart(app, indexes, 'FileListChanged:Add')

            delete(d)

        end

        % Image clicked function: tool_ReadFiles
        function toolbar_ReadFilesImageClicked(app, event)
            
            d = ui.Dialog(app.UIFigure, "progressdlg", textFormatGUI.HTMLParagraph('Em andamento...'));

            switch event.Source
                case app.tool_ReadFiles
                    indexes = file_findSelectedNodeData(app);
                case app.tool_GenerateReport
                    indexes = event.Indexes;
                otherwise
                    error('UnexpectedCaller')
            end

            warnings = {};
            for ii = 1:numel(indexes)
                d.Message = textFormatGUI.HTMLParagraph(sprintf('Em andamento a leitura dos registros do arquivo %d de %d:<br>• <b>%s</b>', ii, numel(indexes), app.ecdObj(indexes(ii)).FileName));
                parseTableAndAddToCache(app.ecdObj(indexes(ii)))

                if ~isempty(app.ecdObj(indexes(ii)).GUI.warnings)
                    warnings{end+1} = sprintf('• <b>%s</b><br>%s', app.ecdObj(indexes(ii)).FileName, strjoin(app.ecdObj(indexes(ii)).GUI.warnings, '<br>'));
                end
            end
            file_ProjectRestart(app, indexes, 'FileFullyLoaded')

            if event.Source == app.tool_ReadFiles && ~isempty(warnings)
                msgWarning = ['Alarme(s) gerado(s) no processo de leitura do(s) arquivo(s):<br>', strjoin(warnings, '<br>')];
                ui.Dialog(app.UIFigure, "warning", msgWarning);
            end

            delete(d)

        end

        % Callback function: contextmenu_merge, tool_MergeFiles
        function toolbar_MergeFilesImageClicked(app, event)

            indexes = file_findSelectedNodeData(app);

            if numel(indexes) >= 2
                if ~isscalar(unique({app.ecdObj(indexes).CompanyId}))
                    ui.Dialog(app.UIFigure, 'info', 'A mesclagem é aplicável apenas a registros de uma mesma empresa.');
                    return
                elseif ~isscalar(unique(year([app.ecdObj(indexes).Period])))
                    ui.Dialog(app.UIFigure, 'info', 'A mesclagem é aplicável apenas a registros de um mesmo ano fiscal.');
                    return
                end

                app.progressDialog.Visible = 'visible';

                [app.ecdObj, msg] = mergeFiles(app.ecdObj, app.projectData, app.General, indexes, app.General.fileFolder.tempPath);
                if isempty(msg)
                    file_ProjectRestart(app, indexes, 'FileListChanged:Merge')
                else
                    ui.Dialog(app.UIFigure, "error", msg); 
                end

                app.progressDialog.Visible = 'hidden';
            end

        end

        % Image clicked function: tool_CheckRFB
        function toolbar_CheckStatusImageClicked(app, event)
            
            indexes = file_findSelectedNodeData(app);

            if ~isempty(indexes)
                if all([app.ecdObj(indexes).PeriodMerged])
                    ui.Dialog(app.UIFigure, 'info', 'Consulta à Receita Federal não é aplicável a registro mesclado.');
                    return
                end

                app.progressDialog.Visible = 'visible';

                checkFileFlag = checkFileStatus(app.ecdObj(indexes), app.receitaFederalObj, app.General.File.encodingList, app.General.File.checkStatus);
                if checkFileFlag
                    file_ProjectRestart(app, indexes, 'FileStatusChecked')
                end

                app.progressDialog.Visible = 'hidden';
            end

        end

        % Image clicked function: tool_GenerateReport
        function toolbar_GenerateReportImageClicked(app, event)
            
            indexes = file_findSelectedNodeData(app);

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

                context = 'File';
                ipcMainMatlabOpenPopupApp(app, app, 'ReportLib', context, indexes)
            end

        end

        % Image clicked function: tool_UploadFinalFile
        function toolbar_UploadFinalFileImageClicked(app, event)
            
            % <VALIDAÇÕES>
            context = 'File';
            lastHTMLDocFullPath = getGeneratedDocumentFileName(app.projectData, '.html', context);

            msg = '';
            if isempty(lastHTMLDocFullPath)
                msg = 'A versão definitiva do relatório ainda não foi gerada.';
            elseif ~isfile(lastHTMLDocFullPath)
                msg = sprintf('O arquivo "%s" não foi encontrado.', lastHTMLDocFullPath);
            elseif ~isfolder(app.General.fileFolder.DataHub_POST)
                msg = 'Pendente mapear pasta do Sharepoint';
            elseif ~report_checkEFiscalizaIssueId(app, app.projectData.modules.(context).ui.issue)
                msg = sprintf('O número da inspeção "%.0f" é inválido.', app.projectData.modules.(context).ui.issue);
            elseif isempty(app.projectData.modules.(context).ui.system)
                msg = 'Ambiente do eFiscaliza precisa ser selecionado.';
            elseif isempty(app.projectData.modules.(context).ui.unit)
                msg = 'Unidade geradora do documento precisa ser selecionada.';
            end

            if ~isempty(msg)
                ui.Dialog(app.UIFigure, 'warning', msg);
                return
            end
            % </VALIDAÇÕES>

            % <PROCESSO>
            if isempty(app.eFiscalizaObj) || ~isvalid(app.eFiscalizaObj)
                dialogBox    = struct('id', 'login',    'label', 'Usuário: ', 'type', 'text');
                dialogBox(2) = struct('id', 'password', 'label', 'Senha: ',   'type', 'password');
                sendEventToHTMLSource(app.jsBackDoor, 'customForm', struct('UUID', 'eFiscalizaSignInPage', 'Fields', dialogBox, 'Context', context))
            else
                report_uploadInfoController(app, [], 'uploadDocument', context)
            end
            % </PROCESSO>

        end

        % Image clicked function: Image
        function toolbar_ShowLegendImageClicked(app, event)
            
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
        function contextMenu_delTreeNodeSelected(app, event)
            
            indexes = file_findSelectedNodeData(app);

            if ~isempty(indexes)
                delete(app.ecdObj(indexes))
                app.ecdObj(indexes) = [];
                
                file_ProjectRestart(app, [], 'FileListChanged:Del')
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
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Tag = 'winMonitorSPED';
            app.GridLayout.Tooltip = {''};
            app.GridLayout.BackgroundColor = [0.9412 0.9412 0.9412];

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

            % Create file_toolGrid
            app.file_toolGrid = uigridlayout(app.file_Grid);
            app.file_toolGrid.ColumnWidth = {22, 5, 22, 22, 5, 22, '1x', 22, 22};
            app.file_toolGrid.RowHeight = {4, 17, 2};
            app.file_toolGrid.ColumnSpacing = 5;
            app.file_toolGrid.RowSpacing = 0;
            app.file_toolGrid.Padding = [10 5 10 5];
            app.file_toolGrid.Layout.Row = 5;
            app.file_toolGrid.Layout.Column = [1 7];
            app.file_toolGrid.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];

            % Create tool_SelectFilesToRead
            app.tool_SelectFilesToRead = uiimage(app.file_toolGrid);
            app.tool_SelectFilesToRead.ScaleMethod = 'none';
            app.tool_SelectFilesToRead.ImageClickedFcn = createCallbackFcn(app, @toolbar_SelectFileToReadImageClicked, true);
            app.tool_SelectFilesToRead.Tooltip = {'Seleciona arquivos'};
            app.tool_SelectFilesToRead.Layout.Row = 2;
            app.tool_SelectFilesToRead.Layout.Column = 1;
            app.tool_SelectFilesToRead.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Import_16.png');

            % Create tool_Separator1
            app.tool_Separator1 = uiimage(app.file_toolGrid);
            app.tool_Separator1.ScaleMethod = 'none';
            app.tool_Separator1.Enable = 'off';
            app.tool_Separator1.Layout.Row = [1 3];
            app.tool_Separator1.Layout.Column = 2;
            app.tool_Separator1.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'LineV.svg');

            % Create tool_ReadFiles
            app.tool_ReadFiles = uiimage(app.file_toolGrid);
            app.tool_ReadFiles.ScaleMethod = 'none';
            app.tool_ReadFiles.ImageClickedFcn = createCallbackFcn(app, @toolbar_ReadFilesImageClicked, true);
            app.tool_ReadFiles.Enable = 'off';
            app.tool_ReadFiles.Tooltip = {'Leitura de todos os registros ordinários'};
            app.tool_ReadFiles.Layout.Row = 2;
            app.tool_ReadFiles.Layout.Column = 3;
            app.tool_ReadFiles.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'run_all_tests_16.png');

            % Create tool_MergeFiles
            app.tool_MergeFiles = uiimage(app.file_toolGrid);
            app.tool_MergeFiles.ScaleMethod = 'none';
            app.tool_MergeFiles.ImageClickedFcn = createCallbackFcn(app, @toolbar_MergeFilesImageClicked, true);
            app.tool_MergeFiles.Enable = 'off';
            app.tool_MergeFiles.Tooltip = {'Mescla informação contábil'};
            app.tool_MergeFiles.Layout.Row = [1 3];
            app.tool_MergeFiles.Layout.Column = 4;
            app.tool_MergeFiles.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Merge_18.png');

            % Create tool_Separator2
            app.tool_Separator2 = uiimage(app.file_toolGrid);
            app.tool_Separator2.ScaleMethod = 'none';
            app.tool_Separator2.Enable = 'off';
            app.tool_Separator2.Layout.Row = [1 3];
            app.tool_Separator2.Layout.Column = 5;
            app.tool_Separator2.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'LineV.svg');

            % Create tool_CheckRFB
            app.tool_CheckRFB = uiimage(app.file_toolGrid);
            app.tool_CheckRFB.ImageClickedFcn = createCallbackFcn(app, @toolbar_CheckStatusImageClicked, true);
            app.tool_CheckRFB.Enable = 'off';
            app.tool_CheckRFB.Tooltip = {'Consulta à Receita Federal'};
            app.tool_CheckRFB.Layout.Row = [1 3];
            app.tool_CheckRFB.Layout.Column = 6;
            app.tool_CheckRFB.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'receita-federal-novo-logo-png_seeklogo-203693.png');

            % Create tool_GenerateReport
            app.tool_GenerateReport = uiimage(app.file_toolGrid);
            app.tool_GenerateReport.ScaleMethod = 'none';
            app.tool_GenerateReport.ImageClickedFcn = createCallbackFcn(app, @toolbar_GenerateReportImageClicked, true);
            app.tool_GenerateReport.Enable = 'off';
            app.tool_GenerateReport.Tooltip = {'Gera relatório'; '(estado escrituração na Receita Federal)'};
            app.tool_GenerateReport.Layout.Row = 2;
            app.tool_GenerateReport.Layout.Column = 8;
            app.tool_GenerateReport.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Publish_HTML_16.png');

            % Create tool_UploadFinalFile
            app.tool_UploadFinalFile = uiimage(app.file_toolGrid);
            app.tool_UploadFinalFile.ImageClickedFcn = createCallbackFcn(app, @toolbar_UploadFinalFileImageClicked, true);
            app.tool_UploadFinalFile.Enable = 'off';
            app.tool_UploadFinalFile.Tooltip = {'Upload relatório'};
            app.tool_UploadFinalFile.Layout.Row = 2;
            app.tool_UploadFinalFile.Layout.Column = 9;
            app.tool_UploadFinalFile.ImageSource = 'Up_24.png';

            % Create TabGroup2
            app.TabGroup2 = uitabgroup(app.file_Grid);
            app.TabGroup2.AutoResizeChildren = 'off';
            app.TabGroup2.Layout.Row = 1;
            app.TabGroup2.Layout.Column = [2 6];

            % Create ARQUIVOSTab
            app.ARQUIVOSTab = uitab(app.TabGroup2);
            app.ARQUIVOSTab.AutoResizeChildren = 'off';
            app.ARQUIVOSTab.Title = 'ARQUIVOS';
            app.ARQUIVOSTab.BackgroundColor = 'none';
            app.ARQUIVOSTab.ForegroundColor = [0.129411764705882 0.129411764705882 0.129411764705882];

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.ARQUIVOSTab);
            app.GridLayout2.ColumnWidth = {22, 150, '1x', 22};
            app.GridLayout2.RowHeight = {22, 22};
            app.GridLayout2.ColumnSpacing = 5;
            app.GridLayout2.RowSpacing = 5;
            app.GridLayout2.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create file_ModuleIntro
            app.file_ModuleIntro = uilabel(app.GridLayout2);
            app.file_ModuleIntro.VerticalAlignment = 'top';
            app.file_ModuleIntro.WordWrap = 'on';
            app.file_ModuleIntro.FontSize = 11;
            app.file_ModuleIntro.FontColor = [0.149 0.149 0.149];
            app.file_ModuleIntro.Layout.Row = 1;
            app.file_ModuleIntro.Layout.Column = [1 4];
            app.file_ModuleIntro.Text = 'Este aplicativo permite a leitura de arquivos textuais da Escrituração Contábil Digital (ECD) e a sua análise.';

            % Create file_FileSortMethod
            app.file_FileSortMethod = uidropdown(app.GridLayout2);
            app.file_FileSortMethod.Items = {'CNPJ', 'PERÍODO FISCAL', 'RECEITA FEDERAL'};
            app.file_FileSortMethod.ValueChangedFcn = createCallbackFcn(app, @file_FileSortMethodValueChanged, true);
            app.file_FileSortMethod.FontSize = 10;
            app.file_FileSortMethod.BackgroundColor = [0.9804 0.9804 0.9804];
            app.file_FileSortMethod.Layout.Row = 2;
            app.file_FileSortMethod.Layout.Column = 2;
            app.file_FileSortMethod.Value = 'CNPJ';

            % Create file_FileSortMethodIcon
            app.file_FileSortMethodIcon = uiimage(app.GridLayout2);
            app.file_FileSortMethodIcon.ScaleMethod = 'none';
            app.file_FileSortMethodIcon.Layout.Row = 2;
            app.file_FileSortMethodIcon.Layout.Column = 1;
            app.file_FileSortMethodIcon.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'sort_az_ascending.png');

            % Create Image
            app.Image = uiimage(app.GridLayout2);
            app.Image.ScaleMethod = 'none';
            app.Image.ImageClickedFcn = createCallbackFcn(app, @toolbar_ShowLegendImageClicked, true);
            app.Image.Tooltip = {'Legenda de símbolos'};
            app.Image.Layout.Row = 2;
            app.Image.Layout.Column = 4;
            app.Image.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Legend_16.png');

            % Create file_Metadata
            app.file_Metadata = uilabel(app.file_Grid);
            app.file_Metadata.VerticalAlignment = 'top';
            app.file_Metadata.WordWrap = 'on';
            app.file_Metadata.FontSize = 11;
            app.file_Metadata.Layout.Row = 3;
            app.file_Metadata.Layout.Column = [5 6];
            app.file_Metadata.Interpreter = 'html';
            app.file_Metadata.Text = '';

            % Create file_Tree
            app.file_Tree = uitree(app.file_Grid);
            app.file_Tree.Multiselect = 'on';
            app.file_Tree.SelectionChangedFcn = createCallbackFcn(app, @file_TreeSelectionChanged, true);
            app.file_Tree.FontSize = 11;
            app.file_Tree.Layout.Row = 3;
            app.file_Tree.Layout.Column = [2 3];

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
            app.NavBar.ColumnWidth = {22, 74, '1x', 34, 34, 5, 34, '1x', 20, 20, 1, 20, 20};
            app.NavBar.RowHeight = {5, 7, 20, 7, 5};
            app.NavBar.ColumnSpacing = 5;
            app.NavBar.RowSpacing = 0;
            app.NavBar.Padding = [10 5 5 5];
            app.NavBar.Tag = 'COLORLOCKED';
            app.NavBar.Layout.Row = 1;
            app.NavBar.Layout.Column = 1;
            app.NavBar.BackgroundColor = [0.2 0.2 0.2];

            % Create AppIcon
            app.AppIcon = uiimage(app.NavBar);
            app.AppIcon.ScaleMethod = 'none';
            app.AppIcon.Layout.Row = [1 5];
            app.AppIcon.Layout.Column = 1;
            app.AppIcon.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'deleteEntireRow_16-aa465db167fbf7f8e67f1c8f29834ebd.png');

            % Create AppName
            app.AppName = uilabel(app.NavBar);
            app.AppName.WordWrap = 'on';
            app.AppName.FontSize = 11;
            app.AppName.FontColor = [1 1 1];
            app.AppName.Layout.Row = [1 5];
            app.AppName.Layout.Column = [2 3];
            app.AppName.Interpreter = 'html';
            app.AppName.Text = {'monitorSPED v. 1.0.0'; '<font style="font-size: 9px;">R2024a</font>'};

            % Create Tab1Button
            app.Tab1Button = uibutton(app.NavBar, 'state');
            app.Tab1Button.ValueChangedFcn = createCallbackFcn(app, @tabNavigatorButtonPushed, true);
            app.Tab1Button.Tag = 'FILE';
            app.Tab1Button.Tooltip = {'Leitura de arquivos'};
            app.Tab1Button.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'OpenFile_32Yellow.png');
            app.Tab1Button.IconAlignment = 'top';
            app.Tab1Button.Text = '';
            app.Tab1Button.BackgroundColor = [0.2 0.2 0.2];
            app.Tab1Button.FontSize = 11;
            app.Tab1Button.Layout.Row = [2 4];
            app.Tab1Button.Layout.Column = 4;
            app.Tab1Button.Value = true;

            % Create Tab2Button
            app.Tab2Button = uibutton(app.NavBar, 'state');
            app.Tab2Button.ValueChangedFcn = createCallbackFcn(app, @tabNavigatorButtonPushed, true);
            app.Tab2Button.Tag = 'ECD';
            app.Tab2Button.Tooltip = {'Escrituração Contábil Digital'};
            app.Tab2Button.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'Zoom_32White.png');
            app.Tab2Button.IconAlignment = 'top';
            app.Tab2Button.Text = '';
            app.Tab2Button.BackgroundColor = [0.2 0.2 0.2];
            app.Tab2Button.FontSize = 11;
            app.Tab2Button.Layout.Row = [2 4];
            app.Tab2Button.Layout.Column = 5;

            % Create ButtonsSeparator
            app.ButtonsSeparator = uiimage(app.NavBar);
            app.ButtonsSeparator.ScaleMethod = 'none';
            app.ButtonsSeparator.Enable = 'off';
            app.ButtonsSeparator.Layout.Row = [2 4];
            app.ButtonsSeparator.Layout.Column = 6;
            app.ButtonsSeparator.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'LineV_White.svg');

            % Create Tab3Button
            app.Tab3Button = uibutton(app.NavBar, 'state');
            app.Tab3Button.ValueChangedFcn = createCallbackFcn(app, @tabNavigatorButtonPushed, true);
            app.Tab3Button.Tag = 'CONFIG';
            app.Tab3Button.Tooltip = {'Configurações gerais'};
            app.Tab3Button.Icon = fullfile(pathToMLAPP, 'resources', 'Icons', 'Settings_36White.png');
            app.Tab3Button.IconAlignment = 'top';
            app.Tab3Button.Text = '';
            app.Tab3Button.BackgroundColor = [0.2 0.2 0.2];
            app.Tab3Button.FontSize = 11;
            app.Tab3Button.Layout.Row = [2 4];
            app.Tab3Button.Layout.Column = 7;

            % Create jsBackDoor
            app.jsBackDoor = uihtml(app.NavBar);
            app.jsBackDoor.Layout.Row = 3;
            app.jsBackDoor.Layout.Column = 9;

            % Create DataHubLamp
            app.DataHubLamp = uiimage(app.NavBar);
            app.DataHubLamp.Visible = 'off';
            app.DataHubLamp.Tooltip = {'Pendente mapear o Sharepoint'};
            app.DataHubLamp.Layout.Row = 3;
            app.DataHubLamp.Layout.Column = 10;
            app.DataHubLamp.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'red-circle-blink.gif');

            % Create FigurePosition
            app.FigurePosition = uiimage(app.NavBar);
            app.FigurePosition.ImageClickedFcn = createCallbackFcn(app, @menuImageClicked, true);
            app.FigurePosition.Visible = 'off';
            app.FigurePosition.Tooltip = {'Reposiciona janela'};
            app.FigurePosition.Layout.Row = 3;
            app.FigurePosition.Layout.Column = 12;
            app.FigurePosition.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'layout1_32White.png');

            % Create AppInfo
            app.AppInfo = uiimage(app.NavBar);
            app.AppInfo.ImageClickedFcn = createCallbackFcn(app, @menuImageClicked, true);
            app.AppInfo.Tooltip = {'Informações gerais'};
            app.AppInfo.Layout.Row = 3;
            app.AppInfo.Layout.Column = 13;
            app.AppInfo.ImageSource = fullfile(pathToMLAPP, 'resources', 'Icons', 'Dots_32White.png');

            % Create ContextMenu
            app.ContextMenu = uicontextmenu(app.UIFigure);
            app.ContextMenu.Tag = 'winMonitorSPED';

            % Create contextmenu_merge
            app.contextmenu_merge = uimenu(app.ContextMenu);
            app.contextmenu_merge.MenuSelectedFcn = createCallbackFcn(app, @toolbar_MergeFilesImageClicked, true);
            app.contextmenu_merge.Enable = 'off';
            app.contextmenu_merge.Text = '🔀 Mesclar';

            % Create contextmenu_del
            app.contextmenu_del = uimenu(app.ContextMenu);
            app.contextmenu_del.MenuSelectedFcn = createCallbackFcn(app, @contextMenu_delTreeNodeSelected, true);
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
