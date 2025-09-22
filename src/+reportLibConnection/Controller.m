classdef (Abstract) Controller

    properties (Constant)
        %-----------------------------------------------------------------%
        fileName   = 'ReportTemplates.json'
        docVersion = dictionary(["Preliminar", "Definitiva"], ...
            [struct('version', 'preview', 'encoding', 'UTF-8'), struct('version', 'final', 'encoding', 'ISO-8859-1')])
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
                % !! INSERIDO AQUI APENAS P/ DEBUG, DEPOIS REMOVER !!        
                % % % % modelFileContent = jsondecode(fileread(externalFilePath));
                modelFileContent = jsondecode(fileread(projectFilePath));
            catch
                modelFileContent = jsondecode(fileread(projectFilePath));
            end        
        end

        %-----------------------------------------------------------------%
        function Run(app, ecdObj, issueId, modelNameIndex, reportVersion)        
            arguments
                app
                ecdObj         = app.ecdObj
                issueId        = -1
                modelNameIndex = 1
                reportVersion  = "Preliminar"
            end
        
            [modelFileContent, ...
             projectFolder,    ...
             programDataFolder] = reportLibConnection.Controller.Read(app.rootFolder);
        
            docIndex   = modelNameIndex;
            docName    = modelFileContent(docIndex).Name;
            docType    = modelFileContent(docIndex).DocumentType;
            
            % BAGUNCEI AQUI TAMBÉM
            % % docScript  = jsondecode(fileread(fullfile(programDataFolder, 'ReportTemplates', modelFileContent(docIndex).File)));
            docScript  = jsondecode(fileread(fullfile(projectFolder, 'ReportTemplates', modelFileContent(docIndex).File)));
            
            docVersion = reportLibConnection.Controller.docVersion(reportVersion);
        
            % reportInfo
            % Importante observar que o campo "Function" armazena informações
            % gerais, a compor itens "Introdução", "Metodologia" e "Conclusão",
            % e informações específicas, a compor itens com recorrências, como 
            % "Resultados".
            reportInfo = struct('App',      app, ...
                                'Version',  app.General.AppVersion,  ...
                                'Path',     struct('rootFolder',     app.rootFolder, ...
                                                   'userFolder',     app.General.fileFolder.userPath, ...
                                                   'tempFolder',     app.General.fileFolder.tempPath, ...
                                                   'appConnection',  projectFolder, ...
                                                   'appDataFolder',  programDataFolder), ...
                                'Model',    struct('Name',           docName, ...
                                                   'DocumentType',   docType, ...
                                                   'Script',         docScript, ...
                                                   'Version',        docVersion.version), ...
                                'Function', struct(...
                                                   'var_Issue',      num2str(issueId), ...
                                                   'table_FileStatus', 'reportLibConnection.tableInventory.FileStatus(dataOverview)', ...
                                                   'table_FileByCompany', 'reportLibConnection.tableInventory.FileByCompany(dataOverview)', ...
                                                   'table_PeriodByCompany', 'reportLibConnection.tableInventory.PeriodByCompany(dataOverview)', ...
                                                   ... 
                                                   'var_CompanyName', 'analyzedData.InfoSet.CompanyName', ...
                                                   'var_CompanyId',  'analyzedData.InfoSet.CompanyId', ...
                                                   'var_Hash',       'strjoin(unique([analyzedData.Sources.hash], "stable"), ", ")', ...
                                                   'var_Period',     'strjoin(string(analyzedData.InfoSet.Period), " a ")', ...
                                                   'var_FileName',   'analyzedData.InfoSet.FileName', ...
                                                   'var_ReceitaFederal', 'jsonencode(analyzedData.InfoSet.Sources(end).validationMessage)', ...
                                                   'var_ContentSample', '[strjoin(strtrim(splitlines(analyzedData.InfoSet.Content(1:min(500, numel(analyzedData.InfoSet.Content))))), ''<br>'') ''<br><font style="color: red;">... [texto truncado]</font>'']', ...
                                                   'var_Layout',     'analyzedData.InfoSet.Layout', ...
                                                   'table_Raw',      'reportLibConnection.tableAnalysis.Raw(analyzedData, tableSettings)'));
            
            fieldsUnnecessary = {'rootFolder', 'entryPointFolder', 'tempSessionFolder', 'ctfRoot'};
            fieldsUnnecessary(cellfun(@(x) ~isfield(reportInfo.Version.application, x), fieldsUnnecessary)) = [];
            if ~isempty(fieldsUnnecessary)
                reportInfo.Version.application = rmfield(reportInfo.Version.application, fieldsUnnecessary);
            end

            % dataOverview
            % Caso dataOverview não seja escalar e exista um item no relatório
            % com recorrência, a própria lib cria a variável "var_Index", acessível 
            % em "reportInfo.Function.var_Index".

            % Diferente da organização de "ecdObj", orientado à ordem de leitura
            % dos arquivos, o "dataOverview" é orientado ao CNPJ (ordenação 
            % primária) e período fiscal (ordenação secundária).
            dataOverview = struct('ID', {}, 'InfoSet', {}, 'HTML', {});
            
            idsList = {ecdObj.CompanyId};
            ids = unique(idsList);

            for id = ids
                idIndexes   = find(strcmp(idsList, id));
                [~, idSort] = sort(arrayfun(@(x) x.Period(2), ecdObj(idIndexes)));
                idIndexes   = idIndexes(idSort);

                nireInfo  = '';
                if ~isempty(ecdObj(idIndexes(1)).CompanyInfo.NIRE)
                    nireInfo = sprintf('%s - ', ecdObj(idIndexes(1)).CompanyInfo.NIRE);
                end
                companyId = sprintf('%s - %s%s', ecdObj(idIndexes(1)).CompanyId, nireInfo, ecdObj(idIndexes(1)).CompanyName);

                for idx = idIndexes
                    dataOverview(end+1) = struct('ID',      companyId,   ...
                                                 'InfoSet', ecdObj(idx), ...
                                                 'HTML',    struct('Component', {}, 'Source', {}, 'Value', {}));
                    
                    if ~isempty(ecdObj(idx).GUI.externalFiles)
                        dataOverview(end).HTML = ecdObj(idx).GUI.externalFiles;
                    end
                end
            end
            
            % Cria relatório:
            HTMLDocContent = reportLib.Controller(reportInfo, dataOverview);
            
            % Em sendo a versão "Preliminar", apenas apresenta o html no
            % navegador. Por outro lado, em sendo a versão "Definitiva",
            % salva-se o arquivo ZIP em pasta local.
            [baseFullFileName, baseFileName] = appUtil.DefaultFileName(app.General.fileFolder.tempPath, 'Report', issueId);
            HTMLFile = [baseFullFileName '.html'];
            
            writematrix(HTMLDocContent, HTMLFile, 'QuoteStrings', 'none', 'FileType', 'text', 'Encoding', docVersion.encoding)

            switch docVersion.version
                case 'preview'
                    web(HTMLFile, '-new')

                case 'final'
                    % !! PENDENTE !!

                    % JSONFile = [baseFullFileName '.json'];
                    % XLSXFile = [baseFullFileName '.xlsx'];
                    % ZIPFile  = appUtil.modalWindow(app.UIFigure, 'uiputfile', '', {'*.zip', 'SCH (*.zip)'}, fullfile(app.General.fileFolder.userPath, [baseFileName '.zip']));
                    % if isempty(ZIPFile)
                    %     return
                    % end
                    % 
                    % % Salva em pasta temporária os arquivos JSON e XLSX. E salva
                    % % em pasta escolhida pelo usuário o arquivo ZIP.
                    % jsonFileConfig  = {app.General.ui.reportTable.exportedFiles.sharepoint.name, ...
                    %                    app.General.ui.reportTable.exportedFiles.sharepoint.label};
                    % jsonFileTable   = renamevars(app.projectData.listOfProducts, jsonFileConfig{:});
                    % 
                    % jsonFileContent = struct('issueId', issueId,                    ...
                    %                          'entity',  struct('type', entityType,  ...
                    %                                            'id',   entityId,    ...
                    %                                            'name', entityName), ...
                    %                          'items',   jsonFileTable);
                    % 
                    % xlsxFileConfig  = app.General.ui.reportTable.exportedFiles.eFiscaliza;
                    % xlsxFileContent = reportLibConnection.tableProducts(app.projectData.listOfProducts, xlsxFileConfig);
                    % 
                    % writematrix(jsonencode(jsonFileContent, 'PrettyPrint', true), JSONFile, "FileType", "text", "QuoteStrings", "none", "WriteMode", "overwrite")
                    % writetable(xlsxFileContent, XLSXFile, "UseExcel", false, "Sheet", "Upload", "FileType", "spreadsheet", "WriteMode", "replacefile")
                    % 
                    % zip(ZIPFile, {HTMLFile, JSONFile, XLSXFile})
                    % 
                    % app.projectData.generatedFiles.lastHTMLDocFullPath = HTMLFile;
                    % app.projectData.generatedFiles.lastTableFullPath   = JSONFile;
                    % app.projectData.generatedFiles.lastZIPFullPath     = ZIPFile;
            end
        end
    end
end