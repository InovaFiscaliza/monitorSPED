function ecdFilesTest(repoFolder, outputFilename)
    arguments
        repoFolder 
        outputFilename = 'resultado.xlsx'
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
    rootFolder = fullfile(ProjectPath, 'src');
    generalSettings = appUtil.generalSettingsLoad('monitorSPED', rootFolder);
    projectData = model.projectLib([], rootFolder);

    t = table( ...
        'Size', [0,9], ...
        'VariableTypes', {'cell', 'double', 'double', 'cell', 'double', 'double', 'double', 'cell', 'cell'}, ...
        'VariableNames', {'File', 'Bytes', 'Altura registro I250', 'Período', 'Resultado contábil', 'Leitura metadados (seg)', 'Criação balancete (seg)', 'Log', 'Mensagem de erro'} ...
    );

    d = dir(repoFolder);    
    for ii = 1:numel(d)
        if ismember(d(ii).name, {'.', '..'})
            continue
        end

        fileFullName = fullfile(d(ii).folder, d(ii).name);

        if d(ii).isdir
            t = [t; fileDir(fileFullName)];
        else
            if isfile(fileFullName)
                [~, fileName, fileExt] = fileparts(fileFullName);

                try
                    ecdObj = model.ECD.empty;
                    tic
                    [ecdObj, msg] = addFiles(ecdObj, projectData, generalSettings, {fileFullName});
                    leitura_metadados = toc;
                    if ~isempty(msg)
                        error(msg)
                    end

                    tic
                    parseTableAndAddToCache(ecdObj, {'_BALANCETE_RESULTADO'}, generalSettings)
                    criacao_balancete = toc;

                    expectedRows = expectedRowsByTableId(ecdObj, 'I250');
                    if isempty(expectedRows)
                        expectedRows = 0;
                    end

                    t(end+1, :) = { ...
                        [fileName fileExt], ...
                        ecdObj.Size, ...
                        expectedRows, ...
                        char(strjoin(string(ecdObj.Period), ' a ')), ...
                        sum(ecdObj.Table.x_BALANCETE_RESULTADO.('TOTAL')), ...
                        leitura_metadados, ...
                        criacao_balancete, ...
                        strjoin(ecdObj.GUI.warnings, '\n'), ...
                        '' ...
                    };

                    delete(ecdObj)

                catch ME
                    t(end+1, [1,9]) = { ...
                        [fileName fileExt], ...
                        ME.message ...
                    };
                end
            end
        end
    end

    t = sortrows(t, 'Bytes', 'descend');
end