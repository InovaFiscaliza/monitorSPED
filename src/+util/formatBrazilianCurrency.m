function str = formatBrazilianCurrency(num)
    numParts = split(sprintf('%.2f', num), '.');
    intPart = numParts{1};

    thousandsSepPos = numel(intPart)-3:-3:1;
    for pos = thousandsSepPos
        intPart = [intPart(1:pos), '.', intPart(pos+1:end)];
    end

    str = [intPart, ',', numParts{2}];
end