function ecdParserTest(repoFolder, outputFilename)
    arguments
        repoFolder = 'D:\sample-files\monitorSPED\inputs\Combo15 - CLARO\CLA_04_2024_SPED_COPIA_DE_SEGURANÇA'
        outputFilename = 'parser.xlsx'
    end

    t = fileDir(repoFolder);
    if ~isfile(outputFilename)
        writetable(t, outputFilename)
    else
        writetable(t, outputFilename, "WriteMode", "append")
    end
end



%-------------------------------------------------------------------------%
function t = fileDir(repoFolder)
    MFilePath = mfilename('fullpath');
    rootFolder = fullfile(fileparts(fileparts(MFilePath)), 'src');
    generalSettings = appEngine.util.generalSettingsLoad('monitorSPED', rootFolder);

    % Versões do parser a comparar. A ordem define a ordem das colunas.
    algorithms = {'fileread', 'fileStream'};

    % Colunas dinâmicas (uma de tempo e uma de resultado por versão), evitando
    % descasamento entre Size/VariableTypes/VariableNames.
    timeVars   = strcat('Time_',   algorithms);
    resultVars = strcat('Result_', algorithms);
    varNames   = [{'File', 'Bytes', 'FastestAlgorithm', 'Speedup_Stream_vs_Read'}, timeVars, resultVars];
    varTypes   = [{'cell', 'cell', 'cell', 'double'}, repmat({'double'}, 1, 2 * numel(algorithms))];

    t = table('Size', [0, numel(varNames)], 'VariableTypes', varTypes, 'VariableNames', varNames);

    d = dir(repoFolder);
    for ii = 1:numel(d)
        if ismember(d(ii).name, {'.', '..'})
            continue
        end

        fileFullName = fullfile(d(ii).folder, d(ii).name);

        if d(ii).isdir
            t = [t; fileDir(fileFullName)]; %#ok<AGROW>
            continue
        end

        [~, fileName, fileExt] = fileparts(fileFullName);

        timeArray    = -1 * ones(1, numel(algorithms));
        resultsArray = -1 * ones(1, numel(algorithms));

        for jj = 1:numel(algorithms)
            ecdObj = model.ECD;

            try
                ecdObj.FileName = fileName;
                ecdObj.FileFullName = fileFullName;

                % Mede APENAS o tempo do parser.
                tic
                util.(algorithms{jj})(ecdObj, fileFullName, generalSettings);
                timeArray(jj) = toc;

                % Métrica de correção (FORA da medição de tempo): soma do total
                % do balancete de resultado, derivado das tabelas parseadas.
                % Serve para verificar paridade entre as versões.
                parseTableAndAddToCache(ecdObj, {'_BALANCETE_RESULTADO'}, generalSettings);
                resultsArray(jj) = sum(ecdObj.Table.x_BALANCETE_RESULTADO.('TOTAL'));

            catch ME
                struct2table(ME.stack)
                warning('ecdParserTest:algorithmFailed', '%s | %s: %s', [fileName fileExt], algorithms{jj}, ME.message);
            end

            delete(ecdObj)
        end

        % Algoritmo mais rápido (menor tempo válido; ignora falhas = -1).
        validTimes = timeArray;
        validTimes(validTimes < 0) = NaN;
        if all(isnan(validTimes))
            fastestAlgorithm = '';
        else
            [~, fastestIdx] = min(validTimes);
            fastestAlgorithm = algorithms{fastestIdx};
        end

        % Quão mais rápido é fileStream em relação a fileread (em ×):
        % > 1 significa fileStream mais rápido; < 1, mais lento.
        idxRead   = find(strcmp(algorithms, 'fileread'), 1);
        idxStream = find(strcmp(algorithms, 'fileStream'), 1);
        if isempty(idxRead) || isempty(idxStream) || timeArray(idxRead) <= 0 || timeArray(idxStream) <= 0
            speedupStreamVsRead = NaN;
        else
            speedupStreamVsRead = timeArray(idxRead) / timeArray(idxStream);
        end

        t(end+1, :) = [{[fileName fileExt], textFormatGUI.bytes2human(d(ii).bytes), fastestAlgorithm, speedupStreamVsRead}, num2cell(timeArray), num2cell(resultsArray)]
    end

    if ~isempty(t)
        t = sortrows(t, timeVars{1}, 'descend');
    end
end