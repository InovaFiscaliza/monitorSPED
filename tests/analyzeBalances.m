function analyzeBalances()
    filePath = 'C:\Users\anatel_master\Downloads\Contas anotadas.xlsx';
    T = readtable(filePath, 'VariableNamingRule', 'preserve');

    labels = strtrim(string(T.('auditorAccountType')));
    labelsCollapsed = labels;
    labelsCollapsed(labelsCollapsed == "-" | labelsCollapsed == "") = "Não";
    uCats = unique(labelsCollapsed);

    months = {'jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'};
    monthlyBalances = zeros(height(T), 12);
    for m = 1:12
        monthlyBalances(:, m) = toNumeric(T.(months{m}));
    end
    total = toNumeric(T.('total'));
    entryCount = toNumeric(T.('entryHistoryCount'));

    fprintf('=== MONTHLY BALANCE PATTERNS PER CLASS ===\n');
    for i = 1:numel(uCats)
        mask = labelsCollapsed == uCats(i);
        n = sum(mask);
        totalPositivePct = 100 * sum(total(mask) > 0) / n;
        allMonthsNonNegPct = 100 * sum(all(monthlyBalances(mask,:) >= 0, 2)) / n;
        totalZeroPct = 100 * sum(total(mask) == 0) / n;
        totalNegPct = 100 * sum(total(mask) < 0) / n;
        medEntryCount = median(entryCount(mask));
        fprintf('  %-16s n=%-6d total>0: %6.1f%%  allMonths>=0: %6.1f%%  total==0: %5.1f%%  total<0: %5.1f%%  medianEntryCount=%.0f\n', ...
            uCats(i), n, totalPositivePct, allMonthsNonNegPct, totalZeroPct, totalNegPct, medEntryCount);
    end
end

function out = toNumeric(col)
    if isnumeric(col)
        out = double(col);
        return
    end
    if iscell(col)
        out = zeros(numel(col), 1);
        for i = 1:numel(col)
            v = col{i};
            if isnumeric(v)
                out(i) = double(v);
            elseif isempty(v)
                out(i) = 0;
            else
                s = strtrim(string(v));
                s = replace(s, '.', '');
                s = replace(s, ',', '.');
                out(i) = str2double(s);
            end
        end
        out(isnan(out)) = 0;
        return
    end
    out = str2double(string(col));
    out(isnan(out)) = 0;
end
