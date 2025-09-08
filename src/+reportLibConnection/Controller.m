classdef (Abstract) Controller

    properties (Constant)
        %-----------------------------------------------------------------%
        fileName   = 'ReportTemplates.json'
        docVersion = dictionary(["Preliminar", "Definitiva"], ["preview", "final"])
    end

    methods (Static)
        %-----------------------------------------------------------------%
        function [modelFileContent, projectFolder, externalFolder] = Read(rootFolder)
            [projectFolder, ...
             externalFolder] = appUtil.Path(class.Constants.appName, rootFolder);
            fileName         = reportLibConnection.Controller.fileName;
        
            projectFilePath  = fullfile(projectFolder,  fileName);
            externalFilePath = fullfile(externalFolder, fileName);
        
            try
                modelFileContent = jsondecode(fileread(externalFilePath));
            catch
                modelFileContent = jsondecode(fileread(projectFilePath));
            end        
        end


        %-----------------------------------------------------------------%
        function Run(app, issueId, modelName, modelVersion, rootFolder, tempFolder, userFolder)
            arguments
                app 
                issueId
                modelName
                modelVersion
                rootFolder
                tempFolder
                userFolder
            end


            % A função Controller, da reportLib, espera os argumentos reportInfo 
            % e dataOverview.
            [modelFileContent, ...
             projectFolder,    ...
             appDataFolder] = reportLibConnection.Controller.Read(rootFolder);

            docIndex   = find(strcmp({modelFileContent.Name}, modelName), 1);
            docType    = modelFileContent(docIndex).DocumentType;
            docScript  = jsondecode(fileread(fullfile(appDataFolder, 'ReportTemplates', modelFileContent(docIndex).File)));            
            docVersion = reportLibConnection.Controller.docVersion(modelVersion);
            
            % reportInfo
            issueId    = num2str(issueId);
            entityType = upper(app.report_EntityType.Value);
            switch entityType
                case 'IMPORTADOR'
                    entityId   = '';
                    entityName = '';
                otherwise
                    entityId   = app.report_EntityID.Value;
                    entityName = strtrim(upper(app.report_Entity.Value));
            end            

            reportInfo = struct('App',      app,                                                                ...
                                'Version',  util.getAppVersion('reportLib', rootFolder, app.rawDataTable, app.releasedData), ...
                                'Path',     struct('rootFolder',                rootFolder,                    ...
                                                   'appConnection',             projectFolder,                     ...
                                                   'appDataFolder',             appDataFolder),                    ...
                                'Model',    struct('Name',                      modelName,        ...
                                                   'DocumentType',              docType,                           ...
                                                   'Script',                    docScript,                         ...
                                                   'Version',                   docVersion),                       ...
                                'Function', struct('var_Issue',                 issueId,                           ...
                                                   'var_EntityName',            'analyzedData.InfoSet.EntityName', ...
                                                   'var_EntityID',              'analyzedData.InfoSet.EntityID',   ...
                                                   'var_EntityType',            'analyzedData.InfoSet.EntityType', ...
                                                   'tableProducts',             'reportLibConnection.tableProducts(  analyzedData.InfoSet.reportTable, tableSettings)',              ...
                                                   'tableProducts_irregular',   'reportLibConnection.tableProducts(  analyzedData.InfoSet.reportTable, tableSettings, "Irregular")', ...
                                                   'tableProducts_regular',     'reportLibConnection.tableProducts(  analyzedData.InfoSet.reportTable, tableSettings, "Regular")',   ...
                                                   'tableSummarized',           'reportLibConnection.tableSummarized(analyzedData.InfoSet.reportTable, tableSettings)',              ...
                                                   'tableSummarized_irregular', 'reportLibConnection.tableSummarized(analyzedData.InfoSet.reportTable, tableSettings, "Irregular")', ...
                                                   'tableSummarized_regular',   'reportLibConnection.tableSummarized(analyzedData.InfoSet.reportTable, tableSettings, "Regular")'));
            
            % dataOverview (aceita recorrência, registra imagens e tabelas externas
            % no campo "HTML")
            dataOverview(1).ID      = app.report_EntityID.Value;
            dataOverview(1).InfoSet = struct('EntityType',  entityType, ...
                                             'EntityID',    entityId,   ...
                                             'EntityName',  entityName, ...                                             
                                             'reportTable', app.projectData.listOfProducts);
            dataOverview(1).HTML    = [];

            % Cria relatório:
            HTMLDocContent = reportLib.Controller(reportInfo, dataOverview);
            
            % Em sendo a versão "Preliminar", apenas apresenta o html no
            % navegador. Por outro lado, em sendo a versão "Definitiva",
            % salva-se o arquivo ZIP em pasta local.
            [baseFullFileName, baseFileName] = appUtil.DefaultFileName(tempFolder, 'Report', issueId);
            HTMLFile = [baseFullFileName '.html'];
            
            writematrix(HTMLDocContent, HTMLFile, 'QuoteStrings', 'none', 'FileType', 'text')

            switch docVersion
                case 'preview'
                    web(HTMLFile, '-new')
                    app.projectData.generatedFiles = [];

                case 'final'
                    JSONFile = [baseFullFileName '.json'];
                    XLSXFile = [baseFullFileName '.xlsx'];
                    ZIPFile  = appUtil.modalWindow(app.UIFigure, 'uiputfile', '', {'*.zip', 'SCH (*.zip)'}, fullfile(userFolder, [baseFileName '.zip']));
                    if isempty(ZIPFile)
                        return
                    end

                    % Salva em pasta temporária os arquivos JSON e XLSX. E salva
                    % em pasta escolhida pelo usuário o arquivo ZIP.
                    jsonFileConfig  = {app.General.ui.reportTable.exportedFiles.sharepoint.name, ...
                                       app.General.ui.reportTable.exportedFiles.sharepoint.label};
                    jsonFileTable   = renamevars(app.projectData.listOfProducts, jsonFileConfig{:});

                    jsonFileContent = struct('issueId', issueId,                    ...
                                             'entity',  struct('type', entityType,  ...
                                                               'id',   entityId,    ...
                                                               'name', entityName), ...
                                             'items',   jsonFileTable);

                    xlsxFileConfig  = app.General.ui.reportTable.exportedFiles.eFiscaliza;
                    xlsxFileContent = reportLibConnection.tableProducts(app.projectData.listOfProducts, xlsxFileConfig);

                    writematrix(jsonencode(jsonFileContent, 'PrettyPrint', true), JSONFile, "FileType", "text", "QuoteStrings", "none", "WriteMode", "overwrite")
                    writetable(xlsxFileContent, XLSXFile, "UseExcel", false, "Sheet", "Upload", "FileType", "spreadsheet", "WriteMode", "replacefile")

                    zip(ZIPFile, {HTMLFile, JSONFile, XLSXFile})
                
                    app.projectData.generatedFiles.lastHTMLDocFullPath = HTMLFile;
                    app.projectData.generatedFiles.lastTableFullPath   = JSONFile;
                    app.projectData.generatedFiles.lastZIPFullPath     = ZIPFile;
            end
        end
    end
end