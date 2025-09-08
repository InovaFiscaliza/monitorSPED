function outputTable = tableProducts(listOfProducts, configTable, legalSituation)

    arguments
        listOfProducts table
        configTable    struct
        legalSituation string {mustBeMember(legalSituation, ["any", "Irregular", "Regular"])} = "any"
    end

    % A tabela "listOfProducts" possui mais de vinte colunas - 'Homologação', 
    % 'Tipo', 'Fabricante', 'Modelo', 'RF?', 'Em uso?', 'Interferência?',
    % 'Valor Unit. (R$)', 'Fonte do valor', 'Qtd. uso', 'Qtd. vendida' etc.

    if ismember(legalSituation, ["Irregular", "Regular"])
        idx = string(listOfProducts.("Situação")) == legalSituation;
        listOfProducts = listOfProducts(idx, :);
    end

    % Na presente função, criam-se cinco colunas calculadas:
    % - "#" 
    % - "Produto"
    % - "Qtd. vistoriadas"
    % - "Mercadoria retida (R$)"
    % - "Mercadoria vendida (R$)"

    listOfProducts.("#")                       = (1:height(listOfProducts))';
    listOfProducts.("Produto")                 = "HOMOLOGAÇÃO: <b>" + string(listOfProducts.("Homologação")) + "</b><br>" + ...
                                                 "TIPO: <b>"        + string(listOfProducts.("Tipo"))        + "</b><br>" + ...
                                                 "FABRICANTE: <b>"  + string(listOfProducts.("Fabricante"))  + "</b><br>" + ...
                                                 "MODELO: <b>"      + string(listOfProducts.("Modelo"))      + "</b>";
    listOfProducts.("Qtd. vistoriadas")        = listOfProducts.("Qtd. uso") + listOfProducts.("Qtd. vendida") + listOfProducts.("Qtd. estoque/aduana") + listOfProducts.("Qtd. anunciada");
    listOfProducts.("Mercadoria retida (R$)")  = listOfProducts.("Valor Unit. (R$)") .* double(listOfProducts.("Qtd. lacradas") + listOfProducts.("Qtd. apreendidas") + listOfProducts.("Qtd. retidas (RFB)"));
    listOfProducts.("Mercadoria vendida (R$)") = listOfProducts.("Valor Unit. (R$)") .* double(listOfProducts.("Qtd. vendida"));

    % Por fim, são realizadas algumas transformações nos dados, como substituição 
    % de true por "Sim" e "\n" por "<br>".

    for ii = 1:width(listOfProducts)
        columnName = listOfProducts.Properties.VariableNames{ii};

        switch columnName
            case 'Informações adicionais'
                for jj = 1:numel(listOfProducts.("Informações adicionais"))
                    currentValue = listOfProducts.("Informações adicionais"){jj};

                    if ~isempty(currentValue) && (ischar(currentValue) || (isstring(currentValue) && isscalar(currentValue)))
                        listOfProducts.("Informações adicionais"){jj} = replace(currentValue, newline, '<br>');

                    elseif iscellstr(currentValue)
                        listOfProducts.("Informações adicionais"){jj} = replace(strjoin(currentValue, '<br>'), newline, '<br>');
                    end
                end

            otherwise
                if islogical(listOfProducts.(columnName))
                    listOfProducts.(columnName) = reportLib.Constants.logical2String(listOfProducts.(columnName), 'cellstr');
                end
        end
    end 

    % A tabela renderizada no arquivo .HTML possuirá todas as linhas da tabela
    % "listOfProducts", mas apenas as colunas definidas no arquivo .JSON que 
    % alimenta a lib "reportLib".

    outputTable = listOfProducts(:, configTable.Columns);
    outputTable.Properties.VariableNames = {configTable.Settings.ColumnName};   

end