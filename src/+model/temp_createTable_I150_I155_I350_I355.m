%-----------------------------------------------------------------%
function [outTable, I133Result, I355Result] = temp_createTable_I150_I155_I350_I355(ecdObj)
    checkIfScalar(ecdObj)
    tableIdList = {'I150', 'I155', 'I350', 'I355'};
    isTableRead(ecdObj, tableIdList)

    outTable   = [];
    I133Result = -1;
    I355Result = -1;

    if ~isempty(ecdObj.Table.xI150)
        % Concatena os registros "I150" e "I155":
        refTable_I150_I155 = tableTypes1And3(ecdObj, 1, tableIdList);
        refTable_I150_I155.REG = strcat(refTable_I150_I155.REG, '-', ecdObj.Table.('xI155').REG);       % PRECISA DISSO MESMO?
        refTable_I150_I155 = [refTable_I150_I155, removevars(ecdObj.Table.('xI155'), 'REG')];

        refTable_I150_I155 = inseriCodCTA(ecdObj, refTable_I150_I155);

        if isfield(ecdObj.Table, 'xI350') && ~isempty(ecdObj.Table.('xI350'))
            % Concatena os registros "I350" e "I355":
            refTable_I350_I355 = tableTypes1And3(ecdObj, 3, tableIdList);
            refTable_I350_I355.REG = strcat(refTable_I350_I355.REG, '-', ecdObj.Table.('xI355').REG);
            refTable_I350_I355 = [refTable_I350_I355, removevars(ecdObj.Table.('xI355'), 'REG')];

            % Cria tabela de nulos de T_I350_I355 com mesmo númeor de linhas de T_I150_I155
            tableI350_I355Null = table('Size',          [height(refTable_I150_I155), width(refTable_I350_I355)], ...
                                       'VariableTypes', varfun(@class, refTable_I350_I355, 'OutputFormat', 'cell'), ...
                                       'VariableNames', refTable_I350_I355.Properties.VariableNames);

            tableI350_I355Null.REG(:,:) = {char};
            tableI350_I355Null.COD_CTA(:,:) = {char};
            tableI350_I355Null.COD_CCUS(:,:) = {char};
            tableI350_I355Null.IND_DC(:,:) = {char};
            tableI350_I355Null.IND_DC_MF(:,:) = {char};

            tableI350_I355Null.REG(:) = repmat({strcat(tableIdList{3}, '-', tableIdList{4})}, height(tableI350_I355Null), 1);

            refTable_I150_I155.REG = strcat(refTable_I150_I155.REG, '-', tableI350_I355Null.REG);

            tableI350_I355Null = removevars(tableI350_I355Null, {'REG', 'COD_CTA', 'COD_CCUS'});

            % Concatena as colunas das tabelas T_I150_I155 e T_I350_I355_Null
            tableI150_I155_I350_I355Null = [refTable_I150_I155, tableI350_I355Null];

            % Concatenar as tabelas T_I150_I155 e T_I350_I355
            datas_I350 = ecdObj.Table.xI350.DT_RES;

            lineIni = 1;
            for kk = 1:numel(datas_I350)
                I155Parcial = refTable_I150_I155(refTable_I150_I155.DT_FIN == datas_I350(kk), :);                
                I355Parcial = refTable_I350_I355(refTable_I350_I355.DT_RES == datas_I350(kk), :);                       

                I155Parcial.ordem_original = (1:height(I155Parcial))';

                indexDatasI350 = find(refTable_I150_I155.DT_FIN == datas_I350(kk));

                I155Parcial.COD_CTA = string(I155Parcial.COD_CTA);
                I155Parcial.COD_CCUS = string(I155Parcial.COD_CCUS);
                I355Parcial.COD_CTA = string(I355Parcial.COD_CTA);
                I355Parcial.COD_CCUS = string(I355Parcial.COD_CCUS);
                I155I355Parcial = outerjoin(I155Parcial, I355Parcial, 'Keys', {'COD_CTA', 'COD_CCUS'}, ...
                                                                      'MergeKeys', true, ...
                                                                      'Type', 'full');

                I155I355Parcial = removevars(I155I355Parcial, 'REG_I355Parcial');

                lineFim = indexDatasI350(1)-1;
                I150_I155_I350_I355_Null = tableI150_I155_I350_I355Null(lineIni:lineFim,:);
                lineIni = indexDatasI350(end)+1;

                I155I355Parcial = sortrows(I155I355Parcial, 'ordem_original');
                I155I355Parcial.ordem_original = [];

                I155I355Parcial(ismissing(I155I355Parcial.REG_I155Parcial), :) = [];
                I155I355Parcial.Properties.VariableNames{1} = 'REG';

                outTable = [outTable; I150_I155_I350_I355_Null; I155I355Parcial];
            end
        else
            outTable = refTable_I150_I155;            
        end

        % Calcula os valores de Mov_I155 e de Mov_I155_I355
        originColumnsToInvertValue = {'IND_DC_INI', 'IND_DC_FIN', 'IND_DC'};
        destinColumnsToInvertValue = {'VL_SLD_INI', 'VL_SLD_FIN', 'VL_CTA'};

        for ii = 1:numel(destinColumnsToInvertValue)
            % Identifica registros em que o valor da coluna "IND_DC_INI", 
            % "IND_DC_FIN" ou "IND_DC" é igual a "D". E também os registros 
            % "NotANumber" presentes na coluna final - "VL_SLD_INI",
            % "VL_SLD_FIN" e "VL_CTA", a depender do caso.

            if ismember(destinColumnsToInvertValue{ii}, outTable.Properties.VariableNames)
                idx1 = isnan(outTable.(destinColumnsToInvertValue{ii}));
                idx2 = strcmp(outTable.(originColumnsToInvertValue{ii}), 'D');
                
                outTable.(destinColumnsToInvertValue{ii})(idx1) = 0;
                outTable.(destinColumnsToInvertValue{ii})(idx2) = -abs(outTable.(destinColumnsToInvertValue{ii})(idx2));
            end
        end

        % Calcula os valores de Mov_I155 e de Mov_I155_I355
        outTable.Mov_I155 = outTable.VL_SLD_FIN - outTable.VL_SLD_INI;
        
        outTable.Mov_I155_I355 = outTable.Mov_I155;
        if ~isempty(ecdObj.Table.xI350)
            outTable.Mov_I155_I355 = outTable.Mov_I155_I355 + outTable.VL_CTA;
        end
    end

    if ~isempty(outTable)
        I133Result = sum(outTable.Mov_I155);
        I355Result = sum(outTable.Mov_I155_I355);
    end
end

%-------------------------------------------------------------------------%
function tableI150_I155_CTA = inseriCodCTA(obj, tableI150_I155)
    checkIfScalar(obj)
    isTableRead(obj, {'I050'})

    I050_CTA = obj.Table.xI050;

    % Selecionar apenas a coluna 'CTA' e a chave
    I050_CTA_reduzida = I050_CTA(:, {'COD_CTA', 'CTA'});
    I050_CTA_reduzida = unique(I050_CTA_reduzida, 'rows');

    tableI150_I155.ordem_original = (1:height(tableI150_I155))';

    % Fazer o join
    tableI150_I155_CTA = outerjoin(tableI150_I155, I050_CTA_reduzida, ...
        'Keys', 'COD_CTA', ...
        'MergeKeys', true, ...
        'Type', 'left');

    tableI150_I155_CTA = sortrows(tableI150_I155_CTA, 'ordem_original');
    tableI150_I155_CTA.ordem_original = [];

    % Reordenar colunas para colocar 'CTA' na 5ª posição
    varNames = tableI150_I155_CTA.Properties.VariableNames;

    % Remover temporariamente a variável 'CTA'
    varNames(strcmp(varNames, 'CTA')) = [];

    % Inserir 'CTA' na posição 5
    varNames = [varNames(1:4), {'CTA'}, varNames(5:end)];

    % Aplicar nova ordem
    tableI150_I155_CTA = tableI150_I155_CTA(:, varNames);
end