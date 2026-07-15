function fileStream(obj, fileFullName, generalSettings, isInitialLoad, recordIds, blockSizeMB)
    % FILESTREAM  Leitura de arquivos contábeis (SPED-ECD) sempre por streaming.
    %
    %   Diferente de "util.fileread", esta função NÃO decide entre leitura em
    %   memória ou segmentada: ela sempre lê o arquivo em blocos de tamanho
    %   configurável (blockSizeMB), independentemente do tamanho do arquivo.
    %   Cada bloco é alinhado por quebra de linha (nenhuma linha é perdida ou
    %   duplicada na fronteira entre blocos), e a posição global de cada linha
    %   é obtida diretamente via ftell.
    %
    %   Entrega os mesmos artefatos de "util.fileread": preenche obj.Table.x*,
    %   obj.Size, obj.Hash, obj.Encoding, obj.EncodingInfo e obj.Content.
    %
    %   Passagem única sobre o arquivo (streamParse): coleta registros
    %   ordinários (com posições), hash, conteúdo textual e os campos brutos das
    %   tabelas de fatos I200/I250. As tabelas de fatos são montadas ao final por
    %   buildFactTables. Hash/conteúdo/fatos apenas na carga inicial.

    arguments
        obj             (1,1) model.ECD
        fileFullName    (1,:) char
        generalSettings (1,1) struct
        isInitialLoad   (1,1) logical = true
        recordIds       (1,:) cell = {'I010', '0000', '9900', 'I030', 'I050', 'I075', 'I150', 'I155', 'I350', 'I355'}
        blockSizeMB     (1,1) double {mustBePositive, mustBeFinite} = 64
    end

    chunkSizeBytes = max(1, round(blockSizeMB * 1024 * 1024));

    fileInfo = dir(fileFullName);
    if isempty(fileInfo)
        error('util:fileStream:FileNotFound', 'File not found')
    end
    fileSize = fileInfo.bytes;

    stopAt9999 = ~obj.PeriodMerged;
    largeFileThreshold = min([generalSettings.context.FILE.largeFileThresholdBytes, 2^30-1]);


    % ----- Passagem única: metadados + registros + hash + conteúdo + fatos ---
    if isInitialLoad
        [encoding, encodingJson] = detectEncoding(fileFullName, fileSize, generalSettings);

        % O conteúdo textual completo só é mantido em memória para arquivos
        % dentro do limite (segurança de memória); acima disso, obj.Content
        % permanece vazio, exatamente como em "util.fileread".
        buildContent = fileSize <= largeFileThreshold;
    else
        encoding = obj.Encoding;
        encodingJson = '';
        buildContent = false;
    end

    % Percorre o arquivo UMA única vez, coletando simultaneamente registros
    % ordinários (com posições), hash, conteúdo textual e os campos brutos das
    % tabelas de fatos (I200/I250). Hash/conteúdo/fatos apenas na carga inicial.
    parseResult = streamParse(fileFullName, encoding, recordIds, stopAt9999, chunkSizeBytes, isInitialLoad, buildContent, isInitialLoad);
    recordLines = parseResult.recordLines;
    recordStarts = parseResult.recordStarts;

    if isInitialLoad
        if fileSize > largeFileThreshold
            obj.GUI.warnings{end+1} = matlab.jsonencode(struct( ...
                'id', 'LargeFile', ...
                'message', sprintf('O arquivo excede %s e, por isso, é tratado como grande, com leitura e processamento realizados de forma diferenciada.', textFormatGUI.bytes2human(largeFileThreshold)) ...
            ));
        end

        obj.Size = fileSize;
        obj.Hash = parseResult.fileHash;
        obj.Encoding = encoding;
        obj.EncodingInfo = encodingJson;
        obj.Content = parseResult.content;
    end


    % ----- Tabelas ordinárias -------------------------------------------------
    for ii = 1:numel(recordIds)
        id = recordIds{ii};
        [fileBlock, idStarts] = getRecordData(recordIds, recordLines, recordStarts, id);

        if isempty(fileBlock)
            columnsSpec = getColumnSpecifications(obj, {id});
            columnTypes = model.ECDBase.getFieldSpecification(columnsSpec.complete, 'DataType');
            obj.Table.(['x' id]) = table('Size', [0, numel(columnsSpec.complete)], 'VariableNames', columnsSpec.complete, 'VariableTypes', columnTypes);

            continue
        end

        if strcmp(id, 'I010')
            splittedFileBlock = strsplit(fileBlock{1}(2:end-1), '|');
            obj.Layout = str2double(splittedFileBlock{3});
        end

        obj.Table.(['x' id]) = initializeOrdinaryTable(obj.Layout, id, fileBlock);
        obj.Table.(['x' id]).Properties.UserData = idStarts(:);
    end


    % ----- Passagem 2: tabelas de fatos (I200/I250) e caches ------------------
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

            [xI200, xI250] = buildFactTables(operation, parseResult.facts);

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
function [encoding, encodingJson] = detectEncoding(fileFullName, fileSize, generalSettings)
    % Infere codificação de texto por meio da identificação dos principais
    % caracteres especiais do Português: "ç", "ã", "á", "é", "í", "ó" e "ú".
    encodingInfo = table( ...
        'Size', [0, 3], ...
        'VariableTypes', {'cell', 'double', 'double'}, ...
        'VariableNames', {'Encoding', 'SpecialCharsTypeCount', 'SpecialCharsCount'} ...
    );

    encodingList = generalSettings.context.FILE.encodingList;
    encodingDetectionBytes = min([fileSize, generalSettings.context.FILE.encodingDetectionBytes]);
    sampleBytes = readFilePrefix(fileFullName, encodingDetectionBytes);

    % Elimina da amostra tudo que venha após o terminador do arquivo (9999),
    % pois o bloco binário da assinatura digital que segue a linha |9999|
    % pode distorcer a contagem de caracteres especiais.
    sampleBytes = truncateSampleAtTerminator(sampleBytes);

    for ii = 1:numel(encodingList)
        rawDecoded = lower(native2unicode(sampleBytes, encodingList{ii}));
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
end


%-------------------------------------------------------------------------%
function sampleBytes = truncateSampleAtTerminator(sampleBytes)
    % Corta o sample no fim da linha terminadora |9999|, caso presente. A busca
    % exige a quebra de linha imediatamente anterior (\n|9999|) para não casar
    % com o mapeamento de contagem de registros "|9900|9999|...|".
    pattern = [uint8(10), uint8('|9999|')];
    idx = strfind(sampleBytes, pattern);
    if isempty(idx)
        return
    end

    lineStart = idx(1) + 1;
    nlRel = find(sampleBytes(lineStart:end) == uint8(10), 1, 'first');
    if isempty(nlRel)
        endPos = numel(sampleBytes);
    else
        endPos = lineStart + nlRel - 1;
    end

    sampleBytes = sampleBytes(1:endPos);
end


%-------------------------------------------------------------------------%
function result = streamParse(fileFullName, encoding, recordIds, stopAt9999, chunkSizeBytes, computeHash, buildContent, collectFacts)
    % Percorre o arquivo UMA única vez, coletando simultaneamente:
    %   - linhas (e posições globais) dos registros ordinários solicitados;
    %   - hash SHA-1 (opcional);
    %   - conteúdo textual do arquivo (opcional);
    %   - campos brutos das tabelas de fatos I200/I250 (opcional).
    % A decodificação do bloco (native2unicode) é feita UMA vez e compartilhada
    % entre conteúdo e fatos. Retorna um struct "result"; a montagem das tabelas
    % de fatos é feita depois por buildFactTables.

    recordLines  = repmat({cell(0, 1)},  1, numel(recordIds));
    recordStarts = repmat({zeros(0, 1)}, 1, numel(recordIds));
    contentParts = {};

    % Acumuladores das tabelas de fatos (arrays de string por campo).
    codCtaParts  = {};
    codHistParts = {};
    histParts    = {};
    indDcParts   = {};
    vdDcRawParts = {};
    dtRawParts   = {};
    indLctoParts = {};

    % Modo Histórico (existe I150) vs TrialBalance+Historic (sem I150). Como o
    % I150 aparece ANTES de I200/I250, o modo já é conhecido quando a enxurrada
    % de fatos começa. Isso evita acumular campos desnecessários (IND_DC, VL_DC
    % e todo o I200) no modo Histórico — minimiza risco de estourar a memória.
    i150Index = find(strcmp(recordIds, 'I150'), 1);
    sawI150 = false;

    if computeHash
        md = java.security.MessageDigest.getInstance('SHA-1');
    end

    fileID = fopen(fileFullName, 'r');
    if fileID == -1
        error('util:fileStream:FileNotFound', 'File not found')
    end
    fileCleanup = onCleanup(@() fclose(fileID));

    iterateLineAlignedBlocks(fileID, chunkSizeBytes, @handleBlock);

    result = struct();
    result.recordLines = recordLines;
    result.recordStarts = recordStarts;

    if computeHash
        digest = typecast(md.digest(), 'uint8');
        result.fileHash = lower(reshape(dec2hex(digest, 2).', 1, []));
    else
        result.fileHash = '';
    end

    if buildContent && ~isempty(contentParts)
        result.content = [contentParts{:}];
    else
        result.content = '';
    end

    result.facts = struct( ...
        'codCtaParts',  {codCtaParts}, ...
        'codHistParts', {codHistParts}, ...
        'histParts',    {histParts}, ...
        'indDcParts',   {indDcParts}, ...
        'vdDcRawParts', {vdDcRawParts}, ...
        'dtRawParts',   {dtRawParts}, ...
        'indLctoParts', {indLctoParts} ...
    );

    function shouldStop = handleBlock(blockBytes, blockStartPos)
        shouldStop = false;
        consumedEnd = numel(blockBytes);
        truncated = false;

        % Identifica o terminador do arquivo (linha |9999|) dentro do bloco, se
        % existir, limitando a área efetiva de busca/hash/conteúdo. Exige a
        % quebra de linha anterior (\n|9999|) para não casar com o mapeamento
        % de contagem de registros "|9900|9999|...|".
        if stopAt9999
            termIdx = strfind(blockBytes, [uint8(10), uint8('|9999|')]);
            if ~isempty(termIdx)
                lineStart9999 = termIdx(1) + 1;
                nlRel = find(blockBytes(lineStart9999:end) == uint8(10), 1, 'first');
                if isempty(nlRel)
                    consumedEnd = numel(blockBytes);
                else
                    consumedEnd = lineStart9999 + nlRel - 1;
                end
                shouldStop = true;
                truncated = true;
            end
        end

        % Evita copiar o bloco quando não há truncamento (caso comum).
        if truncated
            searchBytes = blockBytes(1:consumedEnd);
        else
            searchBytes = blockBytes;
        end
        nBytes = numel(searchBytes);

        % Localiza os inícios das linhas de cada registro-alvo via strfind
        % (nível C), sem iterar todas as linhas do bloco.
        startsByRecord = cell(1, numel(recordIds));
        anyMatch = false;
        for r = 1:numel(recordIds)
            st = recordStartsInBlock(recordIds{r}, searchBytes);
            startsByRecord{r} = st;
            if ~isempty(st)
                anyMatch = true;
            end
        end

        % Detecta a presença de I150 (define o modo Histórico) o quanto antes.
        if ~sawI150 && ~isempty(i150Index) && ~isempty(startsByRecord{i150Index})
            sawI150 = true;
        end

        % As quebras de linha só são necessárias para delimitar as linhas dos
        % registros encontrados. No miolo do arquivo (enxurrada de I200/I250)
        % não há registro-alvo, então evita-se a varredura completa de quebras.
        if anyMatch
            newLineIdxs = find(searchBytes == uint8(10));
            for r = 1:numel(recordIds)
                st = startsByRecord{r};
                if isempty(st)
                    continue
                end
                ends = lineEndsFor(st, newLineIdxs, nBytes);
                appendRecordLines(r, st, ends, searchBytes, blockStartPos);
            end
        end

        if computeHash
            md.update(typecast(searchBytes, 'int8'));
        end

        % Decodificação compartilhada: conteúdo textual e tabelas de fatos
        % (I200/I250) usam a MESMA decodificação do bloco (native2unicode),
        % feita uma única vez. Em carga não-inicial nada disso ocorre.
        if buildContent || collectFacts
            blockText = native2unicode(searchBytes, encoding);

            if buildContent
                contentParts{end+1, 1} = blockText;
            end

            if collectFacts
                lines = splitlines(string(blockText));

                % No modo Histórico (com I150) o balancete vem dos saldos I155,
                % e só COD_CTA/COD_HIST_PAD/HIST do I250 são necessários; I200 e
                % IND_DC/VL_DC não são acumulados (economia de memória).
                extended = ~sawI150;

                % I250: | REG | COD_CTA | COD_CCUS | VL_DC | IND_DC | NUM_ARQ | COD_HIST_PAD | HIST | COD_PART |
                sel250 = lines(startsWith(lines, '|I250|'));
                if ~isempty(sel250)
                    parsed = split(extractBetween(sel250, 2, strlength(sel250) - 1), '|', 2);
                    codCtaParts{end+1, 1}  = parsed(:, 2);
                    codHistParts{end+1, 1} = parsed(:, 7);
                    histParts{end+1, 1}    = parsed(:, 8);

                    if extended
                        indDcParts{end+1, 1}   = parsed(:, 5);
                        vdDcRawParts{end+1, 1} = parsed(:, 4);
                    end
                end

                % I200: | REG | NUM_LCTO | DT_LCTO | VL_LCTO | IND_LCTO |
                if extended
                    sel200 = lines(startsWith(lines, '|I200|'));
                    if ~isempty(sel200)
                        parsed = split(extractBetween(sel200, 2, strlength(sel200) - 1), '|', 2);
                        dtRawParts{end+1, 1}   = parsed(:, 3);
                        indLctoParts{end+1, 1} = parsed(:, 5);
                    end
                end
            end
        end
    end

    function starts = recordStartsInBlock(id, searchBytes)
        prefix = uint8(['|' id '|']);
        plen = numel(prefix);

        if numel(searchBytes) < plen
            starts = [];
            return
        end

        % Linhas do registro no meio do bloco (precedidas por quebra de linha).
        starts = strfind(searchBytes, [uint8(10), prefix]);
        if ~isempty(starts)
            starts = starts + 1;
        end

        % A primeira linha do bloco não é precedida por quebra de linha neste
        % bloco (o bloco sempre inicia no começo de uma linha).
        if isequal(searchBytes(1:plen), prefix)
            starts = [1, starts];
        end

        if ~isempty(starts)
            starts = sort(starts);
        end
    end

    function appendRecordLines(r, starts, ends, searchBytes, blockStartPos)
        n = numel(starts);
        lines = cell(n, 1);
        positions = zeros(n, 1);
        for jj = 1:n
            s = starts(jj);
            lines{jj} = strtrim(native2unicode(searchBytes(s:ends(jj)), encoding));
            positions(jj) = blockStartPos + s - 1;
        end

        recordLines{r} = [recordLines{r}; lines];
        recordStarts{r} = [recordStarts{r}; positions];
    end
end


%-------------------------------------------------------------------------%
function ends = lineEndsFor(starts, newLineIdxs, nBytes)
    % Para cada início de linha (starts), retorna a posição da próxima quebra de
    % linha (ou nBytes, quando a linha não termina em quebra — último bloco).
    % Usa busca binária vetorizada (discretize) sobre newLineIdxs, já ordenado.
    starts = double(starts(:));
    ends = zeros(numel(starts), 1);

    if isempty(newLineIdxs)
        ends(:) = nBytes;
        return
    end

    nl = double(newLineIdxs(:));
    firstNl = nl(1);
    lastNl = nl(end);

    % Primeira linha do bloco (sem quebra anterior neste bloco).
    belowFirst = starts <= firstNl;
    
    % Última linha sem quebra de linha final.
    aboveLast = starts > lastNl;
    mid = ~belowFirst & ~aboveLast;

    ends(belowFirst) = firstNl;
    ends(aboveLast) = nBytes;

    if any(mid)
        bins = discretize(starts(mid), nl);
        ends(mid) = nl(bins + 1);
    end
end


%-------------------------------------------------------------------------%
function [xI200, xI250] = buildFactTables(operation, facts)
    % Monta as tabelas de fatos I200/I250 a partir dos campos brutos acumulados
    % em streamParse. Nenhuma leitura de arquivo aqui: apenas vertcat + as
    % conversões (cellstr/strip/str2double/datetime) UMA única vez sobre o total.

    extended = strcmp(operation, 'TrialBalance+Historic');

    if extended
        i250Names = {'COD_CTA', 'COD_HIST_PAD', 'HIST', 'IND_DC', 'VL_DC'};
        i250Types = {'cell', 'cell', 'cell', 'cell', 'double'};
    else
        i250Names = {'COD_CTA', 'COD_HIST_PAD', 'HIST'};
        i250Types = {'cell', 'cell', 'cell'};
    end
    i200Names = {'DT_LCTO', 'IND_LCTO'};
    i200Types = {'datetime', 'cell'};

    if isempty(facts.codCtaParts)
        xI250 = table('Size', [0, numel(i250Names)], 'VariableTypes', i250Types, 'VariableNames', i250Names);
    else
        codCta  = cellstr(strip(vertcat(facts.codCtaParts{:})));
        codHist = cellstr(vertcat(facts.codHistParts{:}));
        hist    = cellstr(vertcat(facts.histParts{:}));

        if extended
            indDc = cellstr(vertcat(facts.indDcParts{:}));
            vdDc  = str2double(replace(vertcat(facts.vdDcRawParts{:}), ',', '.'));
            xI250 = table(codCta, codHist, hist, indDc, vdDc, 'VariableNames', i250Names);
        else
            xI250 = table(codCta, codHist, hist, 'VariableNames', i250Names);
        end
    end

    xI200 = [];
    if extended
        if isempty(facts.dtRawParts)
            xI200 = table('Size', [0, numel(i200Names)], 'VariableTypes', i200Types, 'VariableNames', i200Names);
        else
            dtLcto  = datetime(vertcat(facts.dtRawParts{:}), 'InputFormat', 'ddMMyyyy');
            indLcto = cellstr(vertcat(facts.indLctoParts{:}));
            xI200 = table(dtLcto, indLcto, 'VariableNames', i200Names);
        end
    end
end


%-------------------------------------------------------------------------%
function iterateLineAlignedBlocks(fileID, chunkSizeBytes, handler)
    % Lê o arquivo em blocos alinhados por quebra de linha. Uma leitura pode
    % terminar no meio de uma linha; nesse caso o ponteiro do arquivo é
    % reposicionado (fseek) para logo após a última quebra de linha, garantindo
    % que o próximo bloco SEMPRE comece no início de uma linha.
    while true
        blockStartPos = ftell(fileID) + 1;
        chunk = fread(fileID, [1, chunkSizeBytes], 'uint8=>uint8');

        if isempty(chunk)
            break
        end

        atEOF = numel(chunk) < chunkSizeBytes;
        newLines = find(chunk == uint8(10));

        % Caso patológico: linha maior que o bloco. Continua lendo até encontrar
        % uma quebra de linha (ou o fim do arquivo).
        while isempty(newLines) && ~atEOF
            more = fread(fileID, [1, chunkSizeBytes], 'uint8=>uint8');
            atEOF = numel(more) < chunkSizeBytes;
            chunk = [chunk, more];
            newLines = find(chunk == uint8(10));
        end

        rewind = 0;
        if isempty(newLines)
            blockBytes = chunk;
        else
            lastNewLine = newLines(end);
            blockBytes = chunk(1:lastNewLine);
            rewind = numel(chunk) - lastNewLine;
            if rewind > 0
                fseek(fileID, -rewind, 'cof');
            end
        end

        shouldStop = handler(blockBytes, blockStartPos);

        if shouldStop || (atEOF && rewind == 0)
            break
        end
    end
end


%-------------------------------------------------------------------------%
function [fileBlock, idStarts] = getRecordData(recordIds, recordLines, recordStarts, recordId)
    idx = find(strcmp(recordIds, recordId), 1);
    if isempty(idx)
        fileBlock = {};
        idStarts = [];
        return
    end

    fileBlock = recordLines{idx};
    if isempty(fileBlock)
        fileBlock = {};
    end

    idStarts = recordStarts{idx};
    if isempty(idStarts)
        idStarts = [];
    end
end


%-------------------------------------------------------------------------%
function bytes = readFilePrefix(fileFullName, numBytes)
    if numBytes <= 0
        bytes = uint8([]);
        return
    end

    fileID = fopen(fileFullName, 'r');
    if fileID == -1
        error('util:fileStream:FileNotFound', 'File not found')
    end
    bytes = fread(fileID, [1, numBytes], 'uint8=>uint8');
    fclose(fileID);
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
        for ii = 1:numel(columnSpec.complete)
            columnName = columnSpec.complete{ii};

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
