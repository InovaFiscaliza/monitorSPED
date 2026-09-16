function analyzeTaxKeywordFalsePositives()
    filePath = 'C:\Users\anatel_master\Downloads\Contas anotadas.xlsx';
    T = readtable(filePath, 'VariableNamingRule', 'preserve');

    labels = strtrim(string(T.('auditorAccountType')));
    labelsCollapsed = labels;
    labelsCollapsed(labelsCollapsed == "-" | labelsCollapsed == "") = "Não";

    desc = normalizeText(string(T.('description')));
    total = toNumeric(T.('total'));

    taxTerms = struct('icms', '\<icms\>', 'pis', '\<pis\>', 'cofins', '\<cofins\>');
    taxNames = fieldnames(taxTerms);

    for k = 1:numel(taxNames)
        pat = taxTerms.(taxNames{k});
        hasKw = ~cellfun(@isempty, regexp(cellstr(desc), pat, 'once'));

        fprintf('\n=== Accounts whose DESCRIPTION matches /%s/ ===\n', taxNames{k});
        fprintf('Total matches: %d\n', sum(hasKw));

        tabulateByLabelAndSign(labelsCollapsed(hasKw), total(hasKw));

        % Sample false-positive descriptions: label == "Não" but keyword matched, split by sign
        fpMaskPos = hasKw & labelsCollapsed == "Não" & total > 0;
        fpMaskNeg = hasKw & labelsCollapsed == "Não" & total <= 0;
        fprintf('-- Sample "Não" descriptions WITH keyword AND total>0 (n=%d) --\n', sum(fpMaskPos));
        printSamples(T.('description')(fpMaskPos), 8);
        fprintf('-- Sample "Não" descriptions WITH keyword AND total<=0 (n=%d) --\n', sum(fpMaskNeg));
        printSamples(T.('description')(fpMaskNeg), 8);
    end
end

function tabulateByLabelAndSign(labelSubset, totalSubset)
    cats = unique(labelSubset);
    for i = 1:numel(cats)
        m = labelSubset == cats(i);
        n = sum(m);
        posPct = 100 * sum(totalSubset(m) > 0) / max(n,1);
        fprintf('  %-16s n=%-6d total>0: %5.1f%%\n', cats(i), n, posPct);
    end
end

function printSamples(descCell, n)
    n = min(n, numel(descCell));
    seen = {};
    count = 0;
    for i = 1:numel(descCell)
        v = strtrim(string(descCell{i}));
        if any(strcmp(seen, v))
            continue
        end
        seen{end+1} = char(v); %#ok<AGROW>
        fprintf('    %s\n', v);
        count = count + 1;
        if count >= n
            break
        end
    end
end

function out = normalizeText(strArr)
    out = lower(strArr);
    out(ismissing(out)) = "";
    accentPairs = {'á','a';'à','a';'â','a';'ã','a';'é','e';'ê','e';'í','i';'î','i';'ó','o';'ô','o';'õ','o';'ú','u';'û','u';'ç','c'};
    for k = 1:size(accentPairs,1)
        out = replace(out, accentPairs{k,1}, accentPairs{k,2});
    end
    out = regexprep(out, '[^a-z0-9 ]', ' ');
    out = regexprep(out, '\s+', ' ');
    out = strtrim(out);
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
