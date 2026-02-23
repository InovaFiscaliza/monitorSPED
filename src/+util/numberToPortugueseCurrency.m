function ext = numberToPortugueseCurrency(value)
    if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || abs(value) > 999999999999.99
        error('Input must be a finite numeric scalar with absolute value less than or equal to 999,999,999,999.99.');
    end

    value    = abs(round(value, 2));
    inteiro  = floor(value);
    centavos = round((value - inteiro) * 100);

    if inteiro == 0 && centavos == 0
        ext = 'Zero reais';
        return
    end

    % INTEIRO
    reaisStr = convertNumber(inteiro);
    if inteiro == 0
        reaisPart = '';
    else
        if inteiro == 1
            reaisLabel = 'real';
        else
            reaisLabel = 'reais';
        end
        reaisPart = [reaisStr ' ' reaisLabel];
    end

    % DECIMAL
    centavosStr = convertNumber(centavos);
    if centavos == 0
        centPart = '';
    else
        if centavos == 1
            centLabel = 'centavo';
        else
            centLabel = 'centavos';
        end

        centPart = [centavosStr ' ' centLabel];
    end

    if inteiro > 0 && centavos > 0
        ext = [reaisPart ' e ' centPart];
    elseif inteiro > 0
        ext = reaisPart;
    else
        ext = centPart;
    end

    ext(1) = upper(ext(1));
end

%-------------------------------------------------------------------------%
function words = convertNumber(value)
    if value == 0
        words = 'zero';
        return
    end

    if value == 100
        words = 'cem';
        return
    end

    parts = {};

    bilhoes  = floor(value/1e9);
    milhoes  = floor(mod(value, 1e9)/1e6);
    milhares = floor(mod(value, 1e6)/1e3);
    resto    = mod(value, 1e3);

    if bilhoes > 0
        if bilhoes == 1
            parts{end+1} = 'um bilhão';
        else
            parts{end+1} = [centenasToWords(bilhoes) ' bilhões'];
        end
    end

    if milhoes > 0
        if milhoes == 1
            parts{end+1} = 'um milhão';
        else
            parts{end+1} = [centenasToWords(milhoes) ' milhões'];
        end
    end

    if milhares > 0
        if milhares == 1
            parts{end+1} = 'mil';
        else
            parts{end+1} = [centenasToWords(milhares) ' mil'];
        end
    end

    if resto > 0
        parts{end+1} = centenasToWords(resto);
    end

    if numel(parts) == 2 && ~contains(parts{2}, ' e ')
        words = strjoin(parts, ' e ');
    else
        words = strjoin(parts, ', ');
    end
end

%-------------------------------------------------------------------------%
function s = centenasToWords(x)
    if x == 100
        s = 'cem';
        return
    end

    unidades  = {'um','dois','três','quatro','cinco','seis','sete','oito','nove'};
    especiais = {'dez','onze','doze','treze','quatorze','quinze','dezesseis','dezessete','dezoito','dezenove'};
    dezenas   = {'','vinte','trinta','quarenta','cinquenta','sessenta','setenta','oitenta','noventa'};
    centenas  = {'cento','duzentos','trezentos','quatrocentos','quinhentos','seiscentos','setecentos','oitocentos','novecentos'};

    s = '';
    c = floor(x/100);
    d = mod(x,100);

    if c > 0
        s = centenas{c};
    end

    if d > 0
        if c > 0
            s = [s ' e '];
        end

        if d < 10
            s = [s unidades{d}];

        elseif d < 20
            s = [s especiais{d-9}];

        else
            dez = floor(d/10);
            un  = mod(d,10);

            if dez > 0
                s = [s dezenas{dez}];
            end

            if un > 0
                if isempty(s)
                    s = unidades{un};
                else
                    s = [s ' e ' unidades{un}];
                end
            end
        end
    end
end