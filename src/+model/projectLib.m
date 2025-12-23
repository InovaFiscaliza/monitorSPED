classdef projectLib < handle

    properties
        %-----------------------------------------------------------------%
        name (1,:) char = ''
        file (1,:) char = ''
        hash (1,:) char = ''

        report  = struct( ...
            'templates', [], ...
            'settings',  [] ...
        )

        % O "id", do "generatedFiles", é a lista ordenada de "hashs" dos fluxos 
        % relacionados aos documentos gerados.

        modules = struct( ...
            'File',  struct('annotationTable', [], ...
                            'generatedFiles',  struct('id', '', 'rawFiles', {{}}, 'lastHTMLDocFullPath', '', 'lastTableFullPath', '', 'lastZIPFullPath', ''), ...
                            'ui',              struct('system',        '',  ...
                                                      'unit',          '',  ...
                                                      'issue',         -1,  ...
                                                      'issueDetails',  [],  ...
                                                      'templates',    {{}}, ...
                                                      'reportModel',   '',  ...
                                                      'reportVersion', 'Preliminar')), ...
            'ECD',   struct('annotationTable', [], ...
                            'generatedFiles',  struct('id', '', 'rawFiles', {{}}, 'lastHTMLDocFullPath', '', 'lastTableFullPath', '', 'lastZIPFullPath', ''), ...
                            'ui',              struct('system',        '',  ...
                                                      'unit',          '',  ...
                                                      'issue',         -1,  ...
                                                      'issueDetails',  [],  ...
                                                      'templates',    {{}}, ...
                                                      'reportModel',   '',  ...
                                                      'reportVersion', 'Preliminar')) ...
        )

        INSS
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        mainApp
        rootFolder
    end


    methods
        %-----------------------------------------------------------------%
        function obj = projectLib(mainApp, rootFolder)
            obj.mainApp    = mainApp;
            obj.rootFolder = rootFolder;

            ReadReportTemplates(obj, rootFolder)
            ReadINSSReferenceTable(obj)
        end

        %-----------------------------------------------------------------%
        function updateNeeded = CheckIfUpdateNeeded(obj, ecdObj)
            updateNeeded = false;
            
            if ~isempty(obj.name)
                currentPrjHash = computeProjectHash(obj, obj.name, obj.file, ecdObj);
                updateNeeded   = ~isequal(obj.hash, currentPrjHash);
            end
        end

        %-----------------------------------------------------------------%
        function Save(obj, ecdObj, context, prjName, prjFile, outputFileCompressionMode)
            arguments
                obj
                ecdObj
                context char {mustBeMember(context, {'File', 'ECD'})}
                prjName
                prjFile
                outputFileCompressionMode
            end

            appName  = class.Constants.appName;
            prjHash  = computeProjectHash(obj, prjName, prjFile, ecdObj);
            prjData  = struct('version', 1, ...
                              'name',    prjName, ...
                              'hash',    prjHash, ...
                              'context', context, ...
                              'generatedFiles', struct('id', obj.modules.(context).generatedFiles.id, 'lastZIPFullPath', obj.modules.(context).generatedFiles.lastZIPFullPath), ...
                              'ui',      struct('system',       obj.modules.(context).ui.system, ...
                                                'unit',         obj.modules.(context).ui.unit,  ...
                                                'issue',        obj.modules.(context).ui.issue, ...
                                                'issueDetails', obj.modules.(context).ui.issueDetails, ...
                                                'reportModel',  obj.modules.(context).ui.reportModel));
            ecdData  = ecdObj;

            compressionMode = '';
            if strcmp(outputFileCompressionMode, 'Não')
                compressionMode = '-nocompression';
            end

            save(prjFile, 'appName', 'prjData', 'ecdData', '-mat', '-v7', compressionMode)

            obj.name = prjName;
            obj.file = prjFile;
            obj.hash = prjHash;
        end

        %-----------------------------------------------------------------%
        function [ecdObj, msg] = Load(obj, ecdObj, fileName, generalSettings)
            % Em 10/12/2025, a versão 1 do projeto contempla instâncias das 
            % classes model.ECD e model.projectLib. Ao ler um arquivo .mat, 
            % usando função "load", o MATLAB realiza validações simples, como
            % adicionar novas propriedades (com valores padrão) ou remover 
            % outras que não existem mais (independentemente do seu conteúdo). 

            % A seguir lista com principais propriedades de cada classe.
            % • model.ECD
            %   "FileName", "FileFullName", "Size", "Hash", "Encoding", "EncodingInfo", 
            %   "Content", "Layout", "Table", "CompanyName", "CompanyId", "CompanyInfo", 
            %   "State", "Period", "PeriodMerged", "Sources" e "GUI".            
            % • model.projectLib
            %   "name", "file", "report", "modules" e "INSS".

            % A alteração da forma de organização da informação no app pode 
            % demandar a criação de outras versões (2, 3...) do arquivo de 
            % projeto (.mat), o que deve vir acompanhado de parsers para manter 
            % compatibilidade, caso viável.

            required = {'appName', 'prjData', 'ecdData'};

            try
                varsInFile = who('-file', fileName);
                if any(~ismember(required, varsInFile))
                    missing = setdiff(required, varsInFile);
                    error('Missing required variables: %s', strjoin(missing, ', '))
                end
                
                load(fileName, '-mat', required{:})
                
                if ~strcmp(class.Constants.appName, appName)
                    error('File generated by a different application. Expected: %s. Found: %s.', class.Constants.appName, appName)
                end
    
                switch prjData.version
                    case 1
                        obj.name = prjData.name;
                        obj.file = fileName;
                        obj.hash = prjData.hash;
    
                        context = prjData.context;

                        if isfile(prjData.generatedFiles.lastZIPFullPath)
                            try
                                unzipFiles = unzip(prjData.generatedFiles.lastZIPFullPath, generalSettings.fileFolder.tempPath);
                                for ii = 1:numel(unzipFiles)
                                    [~, ~, unzipFileExt] = fileparts(unzipFiles{ii});

                                    switch lower(unzipFileExt)
                                        case '.html'
                                            obj.modules.(context).generatedFiles.lastHTMLDocFullPath = unzipFiles{ii};
                                        case '.json'
                                            obj.modules.(context).generatedFiles.lastTableFullPath   = unzipFiles{ii};
                                    end
                                end
                                
                                obj.modules.(context).generatedFiles.id              = prjData.generatedFiles.id;
                                obj.modules.(context).generatedFiles.lastZIPFullPath = prjData.generatedFiles.lastZIPFullPath;
                            catch 
                            end
                        end

                        obj.modules.(context).ui.system       = prjData.ui.system;
                        obj.modules.(context).ui.unit         = prjData.ui.unit;
                        obj.modules.(context).ui.issue        = prjData.ui.issue;
                        obj.modules.(context).ui.issueDetails = prjData.ui.issueDetails;
    
                        reportModel = prjData.ui.reportModel;
                        if ismember(reportModel, obj.modules.(context).ui.templates)
                            obj.modules.(context).ui.reportModel = reportModel;
                        end

                        % Pode ocorrer uma coincidência de fluxos que compõem
                        % o projeto e fluxos já lidos. Se evidenciado, serão
                        % mantidos os fluxos do projeto.
                        idx = ismember({ecdObj.Hash}, {ecdData.Hash});
                        if any(idx)
                            delete(ecdObj(idx))
                            ecdObj(idx) = [];
                        end
    
                        ecdObj = [ecdObj, ecdData];
    
                    otherwise
                        error('UnexpectedVersion')
                end
                msg = '';

            catch ME
                msg = ME.message;
            end
        end

        %-----------------------------------------------------------------%
        function Restart(obj)
            % ...

            updateGeneratedFiles(obj, 'File')
            updateGeneratedFiles(obj, 'ECD')
        end

        %-----------------------------------------------------------------%
        function ReadReportTemplates(obj, rootFolder)
            [projectFolder, ...
             programDataFolder] = appEngine.util.Path(class.Constants.appName, rootFolder);
            projectFilePath  = fullfile(projectFolder,     'ReportTemplates.json');
            externalFilePath = fullfile(programDataFolder, 'ReportTemplates.json');

            try
                if ~isdeployed()
                    error('ForceDebugMode')
                end
                obj.report.templates = jsondecode(fileread(externalFilePath));
            catch
                obj.report.templates = jsondecode(fileread(projectFilePath));
            end

            % Identifica lista de templates por módulo...
            moduleNameList   = fieldnames(obj.modules);
            templateNameList = {obj.report.templates.Name};

            for ii = 1:numel(moduleNameList)
                templateIndexes = ismember({obj.report.templates.Module}, moduleNameList(ii));
                obj.modules.(moduleNameList{ii}).ui.templates = [{''}, templateNameList(templateIndexes)];
            end
        end

        %-----------------------------------------------------------------%
        function ReadINSSReferenceTable(obj)
            [projectFolder, ...
             programDataFolder] = appEngine.util.Path(class.Constants.appName, obj.rootFolder);
            projectFilePath  = fullfile(projectFolder,     'DataBase', 'INSS.xlsx');
            externalFilePath = fullfile(programDataFolder, 'DataBase', 'INSS.xlsx');

            try
                if ~isdeployed()
                    error('ForceDebugMode')
                end
                obj.INSS = readtable(externalFilePath, 'UseExcel', false, 'VariableNamingRule', 'preserve');
            catch
                obj.INSS = readtable(projectFilePath,  'UseExcel', false, 'VariableNamingRule', 'preserve');
            end
        end
    end


    methods
        %-----------------------------------------------------------------%
        function prjHash = computeProjectHash(obj, prjName, prjFile, ecdObj)
            hashList = sort({ecdObj.Hash});

            annotationTable = [];
            for ii = 1:numel(ecdObj)
                if isfield(ecdObj(ii).Table, 'x_CONTAS_ANOTACAO') && ~isempty(ecdObj(ii).Table.x_CONTAS_ANOTACAO)
                    if isempty(annotationTable)
                        annotationTable = ecdObj(ii).Table.x_CONTAS_ANOTACAO;
                    else
                        annotationTable = [annotationTable; ecdObj(ii).Table.x_CONTAS_ANOTACAO];
                    end
                end
            end

            if ~isempty(annotationTable)
                annotationTable = sortrows(annotationTable, 'COD_CTA');
            end

            prjHash = Hash.sha1(sprintf('%s - %s - %s - %s', prjName, prjFile, strjoin(hashList, ' - '), jsonencode(annotationTable)));
        end

        %-----------------------------------------------------------------%
        function [rate, msgError] = calculateINSSRate(obj, state, period, rateType, numDecimals)
            arguments
                obj
                state    char {mustBeMember(state, {'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO'})}
                period   datetime
                rateType char {mustBeMember(rateType, {'mean', 'eomonth'})} = 'mean'
                numDecimals double = 3
            end
            
            Year = year(period);
            Month = month(period);
            endOfMonthDay = eomday(Year, Month);

            % Identifica limites do período sob análise:
            beginOfPeriod = datetime([Year, Month, 1]);
            endOfPeriod   = datetime([Year, Month, endOfMonthDay]);

            try    
                % Identifica registros relacionados à UF indicada:
                indexes = find(strcmp(obj.INSS.("UF"), state) & obj.INSS.("Vigência") <= endOfPeriod);            
                if isempty(indexes)
                    error('Não identificado registro que possibilite calcular a alíquota vigente de INSS')
                end
    
                refINSSTable = obj.INSS(indexes, :);
                switch rateType
                    case 'mean'
                        refNumDays = endOfMonthDay;            
                        rate = 0;
                        for ii = height(refINSSTable):-1:1
                            numDays    = refNumDays - day(max(refINSSTable.("Vigência")(ii), beginOfPeriod)) + 1;
                            rate   = rate + numDays * refINSSTable.("Alíquota máxima")(ii);
                            refNumDays = refNumDays - numDays;
                            if refNumDays <= 0
                                break
                            end
                        end
                        rate = rate/endOfMonthDay;
    
                    case 'eomonth'
                        rate = refINSSTable.("Alíquota máxima")(end);
                end
                msgError = '';

            catch ME
                index = find(strcmp(obj.INSS.("UF"), state), 1);
                rate = obj.INSS.("Alíquota máxima")(index);
                msgError = sprintf('[INSS Fallback] ∄ alíquota no domínio (%s, %s) ⇒ %.1f%%', state, endOfPeriod, 100 * rate);
            end

            rate = round(rate, numDecimals);
        end

        %-----------------------------------------------------------------%
        function updateGeneratedFiles(obj, context, ecdObj, id, rawFiles, htmlFile, tableFile, zipFile)
            arguments
                obj
                context   (1,:) char {mustBeMember(context, {'File', 'ECD'})}
                ecdObj         = []
                id        char = ''
                rawFiles  cell = {}
                htmlFile  char = ''
                tableFile char = ''
                zipFile   char = ''
            end

            obj.modules.(context).generatedFiles.id                  = id;
            obj.modules.(context).generatedFiles.rawFiles            = rawFiles;
            obj.modules.(context).generatedFiles.lastHTMLDocFullPath = htmlFile;
            obj.modules.(context).generatedFiles.lastTableFullPath   = tableFile;
            obj.modules.(context).generatedFiles.lastZIPFullPath     = zipFile;

            if isscalar(ecdObj)
                update(ecdObj, 'GUI.GeneratedFiles', 'addFinalReportFiles', obj, context)
            end
        end

        %-----------------------------------------------------------------%
        function updateUiInfo(obj, context, fieldName, fieldValue)
            arguments
                obj
                context    (1,:) char {mustBeMember(context, {'File', 'ECD'})}
                fieldName  (1,:) char
                fieldValue
            end

            obj.modules.(context).ui.(fieldName) = fieldValue;
        end

        %-----------------------------------------------------------------%
        function filename = getGeneratedDocumentFileName(obj, fileExt, context)
            arguments
                obj
                fileExt (1,:) char {mustBeMember(fileExt, {'.html', '.json', '.zip'})}
                context (1,:) char {mustBeMember(context, {'File', 'ECD'})}
            end

            switch fileExt
                case '.html'
                    filename = obj.modules.(context).generatedFiles.lastHTMLDocFullPath;
                case '.json'
                    filename = obj.modules.(context).generatedFiles.lastTableFullPath;
                case '.zip'
                    filename = obj.modules.(context).generatedFiles.lastZIPFullPath;
            end
        end
    end
    
end