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
    newLineIdxs = find(byteArray == uint8(10))';


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

            try
                startIdxs = strfind(byteArray, startPattern)';
                endIdxs   = strfind(byteArray, endPattern)';
            catch
                startIdxs = findRecordPattern(byteArray, newLineIdxs, startPattern)';
                endIdxs   = findRecordPattern(byteArray, newLineIdxs, endPattern)';
            end

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
                    try
                        % Primeira linha...
                        startIdxs1 = strfind(byteArray, pattern)';
                        if ~isempty(startIdxs1)
                            startIdxs1 = startIdxs1(1);
                        end
                    
                        % Outras linhas (caso se trate de arquivo mesclado)...            
                        startIdxs2 = strfind(byteArray, [uint8(10), pattern])';
                        if ~isempty(startIdxs2)
                            startIdxs2 = startIdxs2+1;
                        end

                        startIdxs = [startIdxs1; startIdxs2];
                    catch
                        startIdxs = findRecordPattern(byteArray, newLineIdxs, pattern)';
                    end

                otherwise
                    pattern = [uint8(10), pattern];

                    try
                        startIdxs = strfind(byteArray, pattern)';
                    catch
                        startIdxs = findRecordPattern(byteArray, newLineIdxs, pattern)';
                    end
                    
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
                case 'cell'
                    if columnName == "COD_CTA"
                        tbl = model.ECDBase.normalizeStringColumns(tbl);
                    end

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
            xI250 = parseFactTable('I250', {'cell', 'cell', 'cell' 'cell', 'double'}, {'COD_CTA', 'COD_HIST_PAD', 'HIST', 'IND_DC', 'VL_DC'});
    end

    function tbl = parseFactTable(registerId, variableTypes, variableNames)
        MIN_ROW_COUNT = 100000;
        encoding = obj.Encoding;
        numVariables = numel(variableNames);
        hasExtendedI250Fields = numVariables == 5;

        ranges = getByteRangesByRecord(byteArray, newLineIdxs, registerId);
        numRows = height(ranges);

        tbl = table( ...
            'Size', [numRows, numVariables], ...
            'VariableTypes', variableTypes, ...
            'VariableNames', variableNames ...
        );
        numLoops = ceil(numRows/MIN_ROW_COUNT);

        for ii = 1:numLoops
            startIdx = (ii - 1) * MIN_ROW_COUNT + 1;
            endIdx = min(ii * MIN_ROW_COUNT, numRows);

            currentRanges = ranges(startIdx:endIdx, :);
            decodedLines = arrayfun(@(x, y) strtrim(native2unicode(byteArray(x:y), encoding)), currentRanges(:, 1), currentRanges(:, 2), 'UniformOutput', false);
            parsedFields = split(extractBetween(decodedLines, 2, strlength(decodedLines) - 1), '|', 2);

            switch registerId
                case 'I200'
                    % Trecho comum a todos os layouts:
                    % | REG | NUM_LCTO | DT_LCTO | VL_LCTO | IND_LCTO |
                    tbl.DT_LCTO(startIdx:endIdx) = datetime(parsedFields(:, 3), 'InputFormat', 'ddMMyyyy');
                    tbl.IND_LCTO(startIdx:endIdx) = parsedFields(:, 5);

                case 'I250'
                    % Trecho comum a todos os layouts:
                    % | REG | COD_CTA | COD_CCUS | VL_DC | IND_DC | NUM_ARQ | COD_HIST_PAD | HIST | COD_PART |
                    tbl.COD_CTA(startIdx:endIdx) = strtrim(parsedFields(:, 2));
                    tbl.COD_HIST_PAD(startIdx:endIdx) = parsedFields(:, 7);
                    tbl.HIST(startIdx:endIdx) = parsedFields(:, 8);

                    if hasExtendedI250Fields
                        tbl.IND_DC(startIdx:endIdx) = parsedFields(:, 5);
                        tbl.VL_DC(startIdx:endIdx) = str2double(replace(parsedFields(:, 4), ',', '.'));
                    end
            end
        end
    end
end


%-------------------------------------------------------------------------%
function idxs = findRecordPattern(byteArray, newLineIdxs, pattern)
    % Fallback do strfind(byteArray, pattern), evitando o erro "Requested 
    % {numRows}x{numCols} ({Size}) array exceeds maximum array size preference 
    % (15.9GB). This might cause MATLAB to become unresponsive". Trata-se de 
    % método não tão rápido quanto o strfind, por isso usado apenas como fallback.

    if pattern(1) == uint8(10)
        compareBytes = pattern(2:end);
        compareOffsets = 1:numel(compareBytes);
        candidates = newLineIdxs(:);
    else
        compareBytes = pattern;
        compareOffsets = 0:(numel(compareBytes)-1);
        candidates = [1; newLineIdxs(:) + 1];
    end

    maxPos = numel(byteArray) - numel(pattern) + 1;
    candidates = candidates(candidates <= maxPos);

    if isempty(candidates)
        idxs = [];
        return
    end

    matchPositions = find(byteArray(candidates + compareOffsets(1)) == compareBytes(1));

    for pp = 2:numel(compareBytes)
        currentPositions = find(byteArray(candidates + compareOffsets(pp)) == compareBytes(pp));
        matchPositions = intersect(matchPositions, currentPositions, 'stable');

        if isempty(matchPositions)
            idxs = [];
            return
        end
    end

    idxs = candidates(matchPositions)';
end