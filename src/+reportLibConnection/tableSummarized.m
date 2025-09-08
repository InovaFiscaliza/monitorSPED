function outputTable = tableSummarized(listOfProducts, configTable, legalSituation)

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

    % Na presente função, sumariza-se "listOfProduts" em função dos valores
    % de uma das suas colunas.

    columnName   = configTable.Settings(1).ColumnName;
    columnClass  = class(listOfProducts.(columnName));
    columnValues = listOfProducts.(columnName);

    if ismember(columnClass, {'string', 'categorical'})
        columnValues = cellstr(listOfProducts.(columnName));
    end

    outputTable = table('Size',          [0, 6],                                               ...
                        'VariableTypes', {'cell', 'cell', 'cell', 'cell', 'double', 'double'}, ...
                        'VariableNames', {configTable.Settings.ColumnName});   

    [uniqueValues, ~, uniqueValuesIndex] = unique(columnValues, 'stable');
    for ii = 1:numel(uniqueValues)
        idx = find((ii == uniqueValuesIndex));

        pricePerProductStr  = {};
        for jj = idx'
            pricePerProductStr{end+1} = sprintf('R$ %.2f (#%d)', listOfProducts.("Valor Unit. (R$)")(jj), jj);
        end
        pricePerProductStr  = strjoin(pricePerProductStr, '<br>');

        unitPricePerProduct = listOfProducts.("Valor Unit. (R$)")(idx);
        quantityPerProduct  = double(listOfProducts.("Qtd. lacradas")(idx) + listOfProducts.("Qtd. apreendidas")(idx) + listOfProducts.("Qtd. retidas (RFB)")(idx));
        totalPrice          = sum(unitPricePerProduct .* quantityPerProduct);

        if sum(quantityPerProduct)
            meanPrice       = sprintf('R$ %.2f', totalPrice/sum(quantityPerProduct));
        else
            meanPrice       = '-';
        end

        outputTable(ii,:)   = {uniqueValues{ii},                                                              ...
                               pricePerProductStr,                                                            ...
                               char(strjoin(string(quantityPerProduct) + " (#" + string(idx) + ")", '<br>')), ...
                               meanPrice,                                                                     ...
                               sum(quantityPerProduct),                                                       ...
                               totalPrice};
    end
end