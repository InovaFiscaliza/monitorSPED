classdef projectLib < handle

    properties
        %-----------------------------------------------------------------%
        name  (1,:) char
        file  (1,:) char
        issue (1,1) double
        unit  (1,:) char

        documentType {mustBeMember(documentType, {'Relatório de Atividades', 'Relatório de Fiscalização', 'Informe'})} = 'Relatório de Atividades'
        documentModel
        documentScript
        generatedFiles

        INSS
    end

    
    properties (Access = private)
        %-----------------------------------------------------------------%
        mainApp
        rootFolder
        defaultFilePreffix = 'monitorSPED'
    end


    methods
        %-----------------------------------------------------------------%
        function obj = projectLib(mainApp, generalSettings)            
            obj.mainApp    = mainApp;
            obj.rootFolder = mainApp.rootFolder;

            Restart(obj)
            ReadReportTemplates(obj)
            ReadINSSReferenceTable(obj)
        end

        %-----------------------------------------------------------------%
        function Restart(obj)
            obj.name           = '';
            obj.file           = '';
            obj.issue          = -1;
            obj.unit           = '';

            obj.documentType   = 'Relatório de Atividades';
            obj.documentScript = [];
            obj.generatedFiles = [];
        end

        %-----------------------------------------------------------------%
        function ReadReportTemplates(obj)
            [projectFolder, ...
             programDataFolder] = appUtil.Path(class.Constants.appName, obj.rootFolder);
            projectFilePath  = fullfile(projectFolder,     'ReportTemplates.json');
            externalFilePath = fullfile(programDataFolder, 'ReportTemplates.json');

            try
                if ~isdeployed()
                    error('ForceDebugMode')
                end
                obj.documentModel = jsondecode(fileread(externalFilePath));
            catch
                obj.documentModel = jsondecode(fileread(projectFilePath));
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
    end
    
end