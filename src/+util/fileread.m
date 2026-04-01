function fileread(obj, fileFullName, generalSettings, isInitialLoad, recordIds)
    arguments
        obj             (1,1) model.ECD
        fileFullName    (1,:) char
        generalSettings (1,1) struct
        isInitialLoad   (1,1) logical = true
        recordIds       (1,:) cell = {'I010', '0000', '9900', 'I030', 'I050', 'I075', 'I150', 'I155', 'I350', 'I355'}
    end

    % Lê arquivo como bloco de bytes (uint8).
    fileID = fopen(fileFullName, 'r');
    if fileID == -1
        error('util:fileread:FileNotFound', 'File not found')
    end    
    byteArray = fread(fileID, [1, inf], 'uint8=>uint8');
    fclose(fileID);


    % Identifica quebras de linhas, o que ajudará a parsear informações dos
    % diversos registros.
    newLineIdxs = strfind(byteArray, uint8(10))';


    % Em se tratando de um arquivo não mesclado, identifica-se posição do 
    % terminador do arquivo (9999), eliminando conteúdo registrado após essa 
    % linha...
    if ~obj.PeriodMerged
        idIxs = getByteRangesByRecord(byteArray, newLineIdxs, '9999');
        if isempty(idIxs)
            error('util:fileread:UnexpectedEmptyTable', 'Unexpected empty table "9999".');
        end    
        byteArray = byteArray(1:idIxs(2));
    end

    fileSize = numel(byteArray);
    newLineIdxs(newLineIdxs > fileSize) = [];
    largeFileThreshold = min([generalSettings.context.FILE.largeFileThresholdBytes, 2^30-1]);

    if isInitialLoad
        % Infere codificação de texto por meio da identificação dos principais dos
        % caracteres especiais do Português: "ç", "ã", "á", "é", "í", "ó" e "ú'".
        encodingInfo = table( ...
            'Size', [0, 3], ...
            'VariableTypes', {'cell', 'double', 'double'}, ...
            'VariableNames', {'Encoding', 'SpecialCharsTypeCount', 'SpecialCharsCount'} ...
        );
    
        encodingList = generalSettings.context.FILE.encodingList;
        encodingDetectionBytes = min([fileSize, generalSettings.context.FILE.encodingDetectionBytes]);
    
        for ii = 1:numel(encodingList)
            rawDecoded = lower(native2unicode(byteArray(1:encodingDetectionBytes), encodingList{ii}));
            numSpecialChars = cellfun(@(x) numel(strfind(rawDecoded, x)), textAnalysis.specialMain);
            encodingInfo(end+1, :) = {encodingList{ii}, sum(numSpecialChars > 0), sum(numSpecialChars)};
        end
        encodingInfo = sortrows(encodingInfo, {'SpecialCharsTypeCount', 'SpecialCharsCount'}, 'descend');
        encodingJson = matlab.jsonencode(encodingInfo);
        
        if ~isempty(generalSettings.context.FILE.encodingOverride)
            encoding = generalSettings.context.FILE.encodingOverride;
        else
            encoding = encodingInfo.Encoding{1};
        end
    
        % Avalia o tamanho do arquivo, adicionando mensagem de LOG e salvando a
        % a versão textual do conteúdo do arquivo na propriedade "Content", caso
        % aplicável.
        if fileSize > largeFileThreshold
            obj.GUI.warnings{end+1} = matlab.jsonencode(struct( ...
                'id', 'LargeFile', ...
                'message', sprintf('O arquivo excede %s e, por isso, é tratado como grande, com leitura e processamento realizados de forma diferenciada.', textFormatGUI.bytes2human(largeFileThreshold)) ...
            ));
    
            content = '';        
        else
            content = native2unicode(byteArray, encoding);
        end
        
        obj.Size = fileSize;
        obj.Hash = Hash.sha1(byteArray);
        obj.Encoding = encoding;
        obj.EncodingInfo = encodingJson;
        obj.Content = content;
    end


    % Leitura de tabelas...
    for ii = 1:numel(recordIds)
        id = recordIds{ii};
        idIxs = getByteRangesByRecord(byteArray, newLineIdxs, id);

        if isempty(idIxs)
            columnsSpec = getColumnSpecifications(obj, {id});
            columnTypes = model.ECDBase.getFieldSpecification(columnsSpec.complete, 'DataType');
            obj.Table.(['x' id]) = table('Size', [0, numel(columnsSpec.complete)], 'VariableNames', columnsSpec.complete, 'VariableTypes', columnTypes);

            continue
        end

        fileBlock = arrayfun(@(x,y) strtrim(native2unicode(byteArray(x:y), obj.Encoding)), idIxs(:, 1), idIxs(:, 2), "UniformOutput", false);

        if strcmp(id, 'I010')
            if isempty(fileBlock)
                error('util:fileread:UnexpectedEmptyTable', 'Unexpected empty table "I010".');
            end

            splittedFileBlock = strsplit(fileBlock{1}(2:end-1), '|');
            obj.Layout = str2double(splittedFileBlock{3});
        end

        obj.Table.(['x' id]) = initializeOrdinaryTable(obj.Layout, id, fileBlock);
        obj.Table.(['x' id]).Properties.UserData = idIxs(:, 1);
    end

    
    % Por fim, cria-se o balancete e tabelas de suporte, como "_CONTAS_HISTORICO".
    if isInitialLoad
        nI200 = expectedRowsByTableId(obj, 'I200');
        nI250 = expectedRowsByTableId(obj, 'I250');
    
        if isempty(nI200) || nI200 == 0 || isempty(nI250) || nI250 == 0
            columnsSpec = getColumnSpecifications(obj, {'I200'});
            columnTypes = model.ECDBase.getFieldSpecification(columnsSpec.complete, 'DataType');
            obj.Table.xI200 = table('Size', [0, numel(columnsSpec.complete)], 'VariableNames', columnsSpec.complete, 'VariableTypes', columnTypes);
    
            columnsSpec = getColumnSpecifications(obj, {'I250'});
            columnTypes = model.ECDBase.getFieldSpecification(columnsSpec.complete, 'DataType');
            obj.Table.xI250 = table('Size', [0, numel(columnsSpec.complete)], 'VariableNames', columnsSpec.complete, 'VariableTypes', columnTypes);
    
        else
            if isfield(obj.Table, 'xI150') && ~isempty(obj.Table.('xI150'))
                operation = 'Historic';
            else
                operation = 'TrialBalance+Historic';
            end

            [xI200, xI250] = initializeFactTable(obj, operation, byteArray, newLineIdxs, largeFileThreshold);
            
            if ~isempty(xI200)
                obj.Table.xI200 = xI200;
            end

            if ~isempty(xI250)
                obj.Table.xI250 = xI250;
            end
        end

        parseTableAndAddToCache(obj, {'_CONTAS_HISTORICO'}, generalSettings)
    end
end


%-------------------------------------------------------------------------%
function ranges = getByteRangesByRecord(byteArray, newLineIdxs, recordId)
    arguments
        byteArray (1,:) uint8
        newLineIdxs
        recordId (1,:) char
    end

    ranges = [];

    switch recordId
        case {'J800', 'J801'}
            startPattern = [uint8(10), uint8(['|' recordId '|'])];
            endPattern   = uint8(['|' recordId 'FIM|']);

            startIdxs = strfind(byteArray, startPattern)';
            endIdxs   = strfind(byteArray, endPattern)';

            if isempty(startIdxs) || isempty(endIdxs)
                return
            end

            ranges = [];

            for ii = 1:numel(startIdxs)
                s = startIdxs(ii)+1;
                e = endIdxs(find(endIdxs > s, 1, 'first'));
                if isempty(e)
                    continue
                end

                ranges(end+1, :) = [s, e+numel(endPattern)-1];
            end

        otherwise
            pattern = uint8(['|' recordId '|']);

            switch recordId
                case '0000'
                    % Primeira linha...
                    startIdxs1 = strfind(byteArray, pattern)';
                    if ~isempty(startIdxs1)
                        startIdxs1 = startIdxs1(1);
                    end
                
                    % Outras linhas (caso se trate de arquivo mesclado)...
                    pattern = [uint8(10), pattern];
        
                    startIdxs2 = strfind(byteArray, pattern)';
                    if ~isempty(startIdxs2)
                        startIdxs2 = startIdxs2+1;
                    end
        
                    startIdxs = [startIdxs1; startIdxs2];

                otherwise
                    pattern = [uint8(10), pattern];
                
                    startIdxs = strfind(byteArray, pattern)';
                    if isempty(startIdxs)
                        return
                    end
                
                    startIdxs = startIdxs+1;
            end
        
            edges = [-inf; newLineIdxs(newLineIdxs > startIdxs(1))];
            endIdxs = edges(discretize(startIdxs, edges) + 1);
            ranges = [startIdxs, endIdxs];
    end
end


%-------------------------------------------------------------------------%
function tbl = initializeOrdinaryTable(layout, recordId, fileBlock)
    layoutIdx = find(cellfun(@(x) ismember(layout, x), model.ECDBase.(['x' recordId])(:,1)), 1);
    required = model.ECDBase.(['x' recordId]){layoutIdx, 2};
    optional = model.ECDBase.(['x' recordId]){layoutIdx, 3};
    complete = [required, optional];
    
    columnSpec = struct( ...
        'id', recordId, ...
        'required', {required}, ...
        'optional', {optional}, ...
        'complete', {complete} ...
    );

    fileBlock = strtrim(fileBlock);

    if isempty(fileBlock)
        columnTypes = model.ECDBase.getFieldSpecification(columnSpec.complete, 'DataType');
        tbl = table('Size', [0, numel(columnSpec.complete)], 'VariableNames', columnSpec.complete, 'VariableTypes', columnTypes);

    else
        mergedFileBlock = split(extractBetween(fileBlock, 2, strlength(fileBlock) - 1), '|', 2);
        tbl = model.ECDBase.cellToTable(mergedFileBlock, columnSpec);
    
        % Conversão de unidades...
        for kk = 1:numel(columnSpec.complete)
            columnName = columnSpec.complete{kk};
    
            if ~ismember(columnName, tbl.Properties.VariableNames)
                continue
            end
    
            switch model.ECDBase.getFieldSpecification(columnName, 'DataType')
                case 'double'
                    if ~isa(tbl.(columnName), 'double')
                        emptyIndexes = cellfun(@isempty, tbl.(columnName));
                        if any(emptyIndexes)
                            tbl.(columnName)(emptyIndexes) = {'0'};
                        end
                        tbl.(columnName) = sscanf(strjoin(strrep(tbl.(columnName), ',', '.')), '%f');
                    end
    
                case 'datetime'
                    if ~isa(tbl.(columnName), 'datetime')
                        tbl.(columnName) = datetime(tbl.(columnName), 'InputFormat', 'ddMMyyyy');
                    end
            end
        end
    end
end


%-------------------------------------------------------------------------%
function [xI200, xI250] = initializeFactTable(obj, operation, byteArray, newLineIdxs, largeFileThreshold)
    arguments
        obj
        operation {mustBeMember(operation, {'Historic', 'TrialBalance+Historic'})}
        byteArray 
        newLineIdxs
        largeFileThreshold
    end

    xI200 = [];
    xI250 = [];

    switch operation
        case 'Historic'
            xI250 = parseFactTable('I250', {'cell', 'cell' 'cell'}, {'COD_CTA', 'COD_HIST_PAD', 'HIST'});

        case 'TrialBalance+Historic'
            if obj.Size <= largeFileThreshold
                return
            end

            xI200 = parseFactTable('I200', {'datetime', 'cell'}, {'DT_LCTO', 'IND_LCTO'});
            xI250 = parseFactTable('I250', {'cell', 'cell', 'cell' 'cell', 'double'}, {'COD_CTA', 'COD_HIST_PAD', 'HIST', 'IND_DC', 'VD_DC'});
    end

    function tbl = parseFactTable(registerId, variableTypes, variableNames)
        MIN_ROW_COUNT = 100000;
        numTableRows = expectedRowsByTableId(obj, registerId);
        tbl = table( ...
            'Size', [numTableRows, numel(variableNames)], ...
            'VariableTypes', variableTypes, ...
            'VariableNames', variableNames ...
        );

        ranges = getByteRangesByRecord(byteArray, newLineIdxs, registerId);
        numRowsTotal = height(ranges);
        numLoops = ceil(numRowsTotal/MIN_ROW_COUNT);

        for ii = 1:numLoops
            startIdx = (ii - 1) * MIN_ROW_COUNT + 1;
            endIdx = min(ii * MIN_ROW_COUNT, numRowsTotal);

            currentRanges = ranges(startIdx:endIdx, :);
            numRows = height(currentRanges);

            blockData = cell(numRows, numel(variableNames));
            for jj = 1:numRows
                line = byteArray(currentRanges(jj, 1):currentRanges(jj, 2));
                delimiterIdxs = find(line == 124);

                switch registerId
                    case 'I200'
                        % Trecho comum a todos os layouts:
                        % | REG | NUM_LCTO | DT_LCTO | VL_LCTO | IND_LCTO | 
                        blockData{jj, 1} = datetime(native2unicode(line(delimiterIdxs(3)+1:delimiterIdxs(4)-1), obj.Encoding), 'InputFormat', 'ddMMyyyy');
                        blockData{jj, 2} = native2unicode(line(delimiterIdxs(5)+1:delimiterIdxs(6)-1), obj.Encoding);

                    case 'I250'
                        % Trecho comum a todos os layouts:
                        % | REG | COD_CTA | COD_CCUS | VL_DC | IND_DC | NUM_ARQ | COD_HIST_PAD | HIST | COD_PART |
                        blockData{jj, 1} = native2unicode(line(delimiterIdxs(2)+1:delimiterIdxs(3)-1), obj.Encoding);
                        if (delimiterIdxs(8)-delimiterIdxs(7) == 1)
                            blockData{jj, 2} = '';
                        else
                            blockData{jj, 2} = native2unicode(line(delimiterIdxs(7)+1:delimiterIdxs(8)-1), obj.Encoding);
                        end
                        blockData{jj, 3} = native2unicode(line(delimiterIdxs(8)+1:delimiterIdxs(9)-1), obj.Encoding);
                        
                        if numel(variableNames) == 5
                            blockData{jj, 4} = str2double(replace(native2unicode(line(delimiterIdxs(4)+1:delimiterIdxs(5)-1), obj.Encoding), ',', '.'));
                            blockData{jj, 5} = native2unicode(line(delimiterIdxs(5)+1:delimiterIdxs(6)-1), obj.Encoding);
                        end
                end
            end

            tableTempOut = cell2table(blockData, 'VariableNames', variableNames);
            tbl(startIdx:endIdx, :) = tableTempOut(:, variableNames);
        end
    end
end