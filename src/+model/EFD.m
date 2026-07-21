classdef EFD < handle

    % SINTAXE:
    % >> efdObj = model.EFD.empty;
    % >> efdObj = addFiles(efdObj, {'Filename1.txt', 'Filename2.txt'});

    properties
        %-----------------------------------------------------------------%
        FileName = ''
        FileFullName = ''

        Size
        Hash = ''
        Encoding = ''
        EncodingInfo = ''

        Content = ''
        Layout = 1
        Table

        CompanyName
        CompanyId % CNPJ
        CompanyInfo = struct( ...
            'CNPJ', {}, ...
            'IE', {}, ...
            'IM', {}, ...
            'NIRE', {}, ...
            'UF', {}, ...
            'City', {} ...
        )
        
        State
        Period
        PeriodMerged = false

        Sources = struct( ...
            'file', {}, ...
            'period', {}, ...
            'encoding', {}, ...
            'terminator', {}, ...
            'hash', {}, ...
            'validationMessage', {}, ...
            'validationStatus', {} ... % -2 (Erro) | -1 (Diverge) | 0 (Pendente) | 1 (Coincide)
        )
        
        Enable = true
        UUID = char(matlab.lang.internal.uuid())
    end


    properties (Constant)
        %-----------------------------------------------------------------%
        TERMINATOR (1,2) uint8 = [13, 10]
    end


    methods (Access = public)
        %-----------------------------------------------------------------%
        function [obj, msg] = addFiles(obj, fileNameList, generalSettings)
            if ~iscellstr(fileNameList)
                fileNameList = cellstr(fileNameList);
            end

            msg = {};

            for ii = 1:numel(fileNameList)
                fileFullName = fileNameList{ii};
                [~, fileName, fileExt] = fileparts(fileFullName);
                fileName = [fileName, fileExt];

                if any(arrayfun(@(x) isequal(x.FileName, fileName), obj))
                    continue
                end

                idx = numel(obj)+1;                

                try
                    obj(idx).FileName = fileName;
                    obj(idx).FileFullName = fileFullName;
                    util.fileread_EFD(obj(idx), fileFullName, generalSettings);
                    initializeCompanyContext(obj(idx))

                catch ME
                    struct2table(ME.stack)
                    delete(obj(idx))
                    obj(idx) = [];
                    msg{end+1} = ME.message;
                end
            end

            msg = strjoin(msg, '\n');
        end

        %-----------------------------------------------------------------%
        function columnsSpec = getColumnSpecifications(obj, tableIdList)
            arguments
                obj
                tableIdList (1,:) cell {mustBeText}
            end

            checkIfScalar(obj)

            for ii = 1:numel(tableIdList)
                tableId = tableIdList{ii};
                definition = model.EFDBase.(['x' tableId]);
                layoutIdx = find(cellfun(@(x) ismember(obj.Layout, x), definition(:, 1)), 1);
                if isempty(layoutIdx)
                    layoutIdx = size(definition, 1);
                end

                required = definition{layoutIdx, 2};
                optional = definition{layoutIdx, 3};
                complete = [required, optional];

                columnsSpec(ii) = struct( ...
                    'id', tableId, ...
                    'required', {required}, ...
                    'optional', {optional}, ...
                    'complete', {complete} ...
                );
            end
        end

        %-----------------------------------------------------------------%
        function expectedRows = expectedRowsByTableId(obj, tableId)
            checkIfScalar(obj)

            expectedRows = [];
            if isfield(obj.Table, 'x9900') && ~isempty(obj.Table.x9900)
                tableIdIndex = find(strcmp(obj.Table.x9900.('REG_BLC'), tableId));
                if ~isempty(tableIdIndex)
                    expectedRows = sum(obj.Table.x9900.('QTD_REG_BLC')(tableIdIndex));
                end
            end
        end

        %-----------------------------------------------------------------%
        function exportMacroLikeWorkbook(obj, outputFile)
            arguments
                obj (1,1) model.EFD
                outputFile (1,:) char
            end

            checkIfScalar(obj)

            sheetMap = {
                'Resultados',      'x_RESULTADOS';
                '0000',            'x0000';
                '0100',            'x0100';
                '0150',            'x0150';
                '0200',            'x0200';
                '0400',            'x0400';
                '0450',            'x0450';
                '0460',            'x0460';
                '0500',            'x0500';
                '0600',            'x0600';
                '1400',            'x1400';
                'C100_C170_C190',  'xC100_C170_C190';
                'D500_D510_D590',  'xD500_D510_D590';
                'D695_D696_D697',  'xD695_D696_D697';
                'D700_E_FILHOS',   'xD700_E_FILHOS';
                'D750_D760_D761',  'xD750_D760_D761'
            };

            if isfile(outputFile)
                delete(outputFile)
            end

            for ii = 1:size(sheetMap, 1)
                sheetName = sheetMap{ii, 1};
                fieldName = sheetMap{ii, 2};

                if ~isfield(obj.Table, fieldName) || ~istable(obj.Table.(fieldName))
                    continue
                end

                writetable(obj.Table.(fieldName), outputFile, 'Sheet', sheetName, 'WriteMode', 'overwritesheet', 'UseExcel', false)
            end
        end

        %-----------------------------------------------------------------%
        function checkIfScalar(obj)
            if ~isscalar(obj)
                error('model:EFD:ScalarObjectRequired', 'This method requires a scalar object.')
            end
        end
    end


    methods (Access = private)
        %-----------------------------------------------------------------%
        function initializeCompanyContext(obj)
            if isfield(obj.Table, 'x0000') && ~isempty(obj.Table.x0000)
                obj.Table.x0000 = sortrows(obj.Table.x0000, 'DT_INI');
                obj.CompanyName = upper(strtrim(obj.Table.x0000.NOME{end}));
                obj.CompanyId = obj.Table.x0000.CNPJ{end};
                obj.CompanyInfo(1) = struct( ...
                    'CNPJ', obj.Table.x0000.CNPJ{end}, ...
                    'IE', obj.Table.x0000.IE{end}, ...
                    'IM', obj.Table.x0000.IM{end}, ...
                    'NIRE', '', ...
                    'UF', obj.Table.x0000.UF{end}, ...
                    'City', obj.Table.x0000.COD_MUN{end} ...
                );

                obj.State = obj.CompanyInfo.UF;
                if isdatetime(obj.Table.x0000.DT_INI) && isdatetime(obj.Table.x0000.DT_FIN)
                    obj.Period = [min(obj.Table.x0000.DT_INI), max(obj.Table.x0000.DT_FIN)];
                    obj.Period.Format = 'dd/MM/yyyy';
                end
            end

            if isfield(obj.Table, 'x_RESULTADOS') && ~isempty(obj.Table.x_RESULTADOS)
                sourceFiles = obj.Table.x_RESULTADOS.ARQUIVO_ZIP_INTERNO;
                payloadNames = obj.Table.x_RESULTADOS.PAYLOAD;
                for ii = 1:height(obj.Table.x_RESULTADOS)
                    obj.Sources(end+1) = struct( ...
                        'file', sourceFiles{ii}, ...
                        'period', obj.Period, ...
                        'encoding', obj.Encoding, ...
                        'terminator', obj.TERMINATOR, ...
                        'hash', obj.Hash, ...
                        'validationMessage', payloadNames{ii}, ...
                        'validationStatus', 0 ...
                    ); %#ok<AGROW>
                end
            end
        end
    end
end