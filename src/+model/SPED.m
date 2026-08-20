classdef SPED < handle

    properties
        %-----------------------------------------------------------------%
        FileName = ''
        FileFullName = ''
        FileType % 'ECD' | 'ECF' | 'EFDI' (EFD ICMS/IPI) | 'EFDC' (EFD CONTRIBUIÇÕES)

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


    methods (Access = protected)
        %-----------------------------------------------------------------%
        function checkFileFlag = checkFileStatus(obj, receitaFederalObj, encodingList, checkType)
            arguments
                obj
                receitaFederalObj ws.ReceitaFederal
                encodingList
                checkType char {mustBeMember(checkType, {'OnlyCache', 'Cache+RealTime', 'RealTime'})} = 'Cache+RealTime'                
            end

            % O argumento de saída "checkFileFlag" possibilita que a GUI
            % renderize novamente a informação em tela, caso ocorra alguma
            % consulta válida à API.

            % Se o registro for resultado da mesclagem de fluxos, ou se o 
            % registro já tiver sido validado na base da Receita Federal,
            % então não é feita uma nova requisição à API. Exceto se for
            % passado como "checkType" o valor "RealTime", quando então é
            % forçada uma nova consulta.
            checkFileFlag = false;

            for ii = 1:numel(obj)
                if obj(ii).PeriodMerged || (any(ismember([obj(ii).Sources.validationStatus], [-1, 1])) && ~strcmp(checkType, 'RealTime'))
                    continue
                end

                encodingList = union(obj(ii).Encoding, setdiff(encodingList, obj(ii).Encoding, 'stable'), 'stable');
                for jj = 1:numel(encodingList) 
                    encoding = encodingList{jj};
                    index = find(strcmp({obj(ii).Sources.encoding}, encoding), 1);

                    if ~isempty(index)
                        fileHash = obj(ii).Sources(index).hash;
                    else
                        index = numel(obj(ii).Sources)+1;
                        obj(ii).Sources(index).file       = obj(ii).FileName;
                        obj(ii).Sources(index).period     = obj(ii).Period;
                        obj(ii).Sources(index).encoding   = encoding;
                        obj(ii).Sources(index).terminator = obj(ii).TERMINATOR;

                        fileHash = obj(ii).Hash;
                        if ~strcmp(encoding, obj(ii).Encoding)
                            try
                                fileContent = fileread(obj(ii).FileFullName, 'Encoding', encoding);
                                fileHash = util.calculateFileHash(fileContent, encoding, obj(ii).TERMINATOR);
                            catch
                            end
                        end
                        obj(ii).Sources(index).hash = fileHash;
                    end

                    [validationMessage, validationStatus]    = Get(receitaFederalObj, checkType, obj(ii).FileType, fileHash);
                    obj(ii).Sources(index).validationMessage = validationMessage;
                    obj(ii).Sources(index).validationStatus  = validationStatus;

                    if validationStatus == 1 || contains(obj(ii).FileName, fileHash, "IgnoreCase", true)
                        break;
                    end
                end
                
                checkFileFlag = true;
            end
        end
    end


    methods (Access = public)
        %-----------------------------------------------------------------%
        function checkIfScalar(obj)
            if ~isscalar(obj)
                error('model:SPED:ScalarObjectRequired', 'This method requires a scalar object.');
            end
        end

        %-----------------------------------------------------------------%
        function [ordinaryIds, customIds, readIds] = getTableIds(obj)
            checkIfScalar(obj)

            if (~isempty(obj.Content) || ~obj.PeriodMerged) && isfield(obj.Table, 'x9900') && ~isempty(obj.Table.x9900)
                ordinaryIds = unique(obj.Table.x9900.("REG_BLC")(obj.Table.x9900.("QTD_REG_BLC") > 0));
            else
                ordinaryIds = extractAfter(fieldnames(obj.Table), 'x');
                ordinaryIds(startsWith(ordinaryIds, '_')) = [];
            end
            
            tableNames = sort(fieldnames(obj.Table));
            customIds  = extractAfter(tableNames(contains(tableNames, '_')), 'x');

            % A exclusão das tabelas vazias ocorre apenas após a obtenção
            % da lista de tabelas customizadas - iniciadas por "m" - pois
            % essas somente serão lidas sob demanda, mas devem consta na 
            % lista de opções.
            tableNames(cellfun(@(x) isempty(obj.Table.(x)), tableNames)) = [];
            readIds    = cellfun(@(x) x(2:end), tableNames, 'UniformOutput', false);
        end

        %-----------------------------------------------------------------%
        function [validFile, filesStatus] = checkIfValidStatus(obj)
            checkIfScalar(obj)

            fileList = {obj.Sources.file};
            filesStatus = [];

            if isempty(fileList)
                validFile = false;
            else
                filesValidation = [];
    
                for file = unique(fileList)
                    fileIndex   = strcmp(fileList, file);
                    statusList  = [obj.Sources(fileIndex).validationStatus];
                    
                    filesStatus = [filesStatus, max(statusList)];
                    filesValidation = [filesValidation, any(statusList > 0)];
                end
        
                validFile = all(filesValidation);
            end
        end
    end


    methods (Static = true)
        %-----------------------------------------------------------------%
        function [fileType, has0000, reason] = classifyFile(filePath)
            [fileType, has0000, reason] = util.classifySPEDFilesByFirstLine(filePath);
        end
    end

end