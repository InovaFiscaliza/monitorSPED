classdef projectLib < handle

    properties
        %-----------------------------------------------------------------%
        name (1,:) char = ''
        file (1,:) char = ''

        report  = struct( ...
            'templates', [], ...
            'settings',  [] ...
        )

        modules = struct( ...
            'File',  struct('annotationTable', [], ...
                            'generatedFiles',  struct('rawFiles', {{}}, 'lastHTMLDocFullPath', '', 'lastTableFullPath', '', 'lastZIPFullPath', ''), ...
                            'ui',              struct('system',        '',  ...
                                                      'unit',          '',  ...
                                                      'issue',         -1,  ...
                                                      'templates',    {{}}, ...
                                                      'reportModel',   '',  ...
                                                      'reportVersion', 'Preliminar')), ...
            'ECD',   struct('annotationTable', [], ...
                            'generatedFiles',  struct('rawFiles', {{}}, 'lastHTMLDocFullPath', '', 'lastTableFullPath', '', 'lastZIPFullPath', ''), ...
                            'ui',              struct('system',        '',  ...
                                                      'unit',          '',  ...
                                                      'issue',         -1,  ...
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
        function Restart(obj)
            % ...

            updateGeneratedFiles(obj, 'File')
            updateGeneratedFiles(obj, 'ECD')
        end

        %-----------------------------------------------------------------%
        function ReadReportTemplates(obj, rootFolder)
            [projectFolder, ...
             programDataFolder] = appUtil.Path(class.Constants.appName, rootFolder);
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
             programDataFolder] = appUtil.Path(class.Constants.appName, obj.rootFolder);
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
        function rate = calculateINSSRate(obj, state, period, rateType)
            arguments
                obj
                state    char {mustBeMember(state, {'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO'})}
                period   datetime
                rateType char {mustBeMember(rateType, {'mean', 'eomonth'})} = 'mean'
            end
            
            Year = year(period);
            Month = month(period);
            endOfMonthDay = eomday(Year, Month);

            % Identifica limites do período sob análise:
            beginOfPeriod = datetime([Year, Month, 1]);
            endOfPeriod   = datetime([Year, Month, endOfMonthDay]);

            % Identifica registros relacionados à UF indicada:
            indexes = find(strcmp(obj.INSS.("UF"), state) & obj.INSS.("Vigência") <= endOfPeriod);
            if isempty(indexes)
                error('Não identificado registro que possibilite calcular a alíquota de INSS vigente de %s no período %s', state, endOfPeriod)
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
        end

        %-----------------------------------------------------------------%
        function updateGeneratedFiles(obj, context, rawFiles, htmlFile, tableFile, zipFile)
            arguments
                obj
                context   (1,:) char {mustBeMember(context, {'File', 'ECD'})}
                rawFiles  cell = {}
                htmlFile  char = ''
                tableFile char = ''
                zipFile   char = ''
            end

            obj.modules.(context).generatedFiles.rawFiles            = rawFiles;
            obj.modules.(context).generatedFiles.lastHTMLDocFullPath = htmlFile;
            obj.modules.(context).generatedFiles.lastTableFullPath   = tableFile;
            obj.modules.(context).generatedFiles.lastZIPFullPath     = zipFile;
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
                fileExt (1,:) char {mustBeMember(fileExt, {'rawFiles', '.html', '.xlsx', '.zip'})}
                context (1,:) char {mustBeMember(context, {'File', 'ECD'})}
            end

            switch fileExt
                case 'rawFiles'
                    filename = obj.modules.(context).generatedFiles.rawFiles;
                case '.html'
                    filename = obj.modules.(context).generatedFiles.lastHTMLDocFullPath;
                case '.xlsx'
                    filename = obj.modules.(context).generatedFiles.lastTableFullPath;
                case '.zip'
                    filename = obj.modules.(context).generatedFiles.lastZIPFullPath;
            end
        end
    end
    
end