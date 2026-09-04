classdef ECD_EFD_ConciliacaoReceita
    % Compara creditos de contas de receita da ECD com documentos de saida C100 da EFD.

    methods (Static)
        function [conciliacao, detalhePorConta, detalhePorCfop] = compararArquivos(entradaECD, entradaEFD, options)
            arguments
                entradaECD (1,1) string
                entradaEFD (1,1) string
                options.PadroesContaReceita (1,:) string = ["RECEITA", "VENDA", "FATURAMENTO"]
                options.Tolerancia (1,1) double {mustBeNonnegative} = 0.01
                options.Periodo (1,2) datetime = [NaT, NaT]
            end

            arquivosECD = model.ECD_EFD_ConciliacaoReceita.listarArquivos(entradaECD);
            arquivosEFD = model.ECD_EFD_ConciliacaoReceita.listarArquivos(entradaEFD);
            detalhePorConta = table.empty(0, 9);
            detalhePorCfop = table.empty(0, 4);
            if isempty(arquivosECD) || isempty(arquivosEFD)
                error('model:ECD_EFD_ConciliacaoReceita:EmptyInput', ...
                    'As entradas ECD e EFD devem conter ao menos um arquivo.')
            end

            registrosECD = cell(numel(arquivosECD), 1);
            periodosECD = NaT(numel(arquivosECD), 2);
            for indiceArquivo = 1:numel(arquivosECD)
                registrosECD{indiceArquivo} = model.ECD_EFD_ConciliacaoReceita.lerRegistros( ...
                    arquivosECD(indiceArquivo), ["0000", "I050", "I155"]);
                cabecalhoECD = model.ECD_EFD_ConciliacaoReceita.criarTabela( ...
                    registrosECD{indiceArquivo}.x0000, {'REG', 'LECD', 'DT_INI', 'DT_FIN'});
                [periodosECD(indiceArquivo, 1), periodosECD(indiceArquivo, 2)] = ...
                    model.ECD_EFD_ConciliacaoReceita.obterPeriodoDoCabecalho(cabecalhoECD);
            end

            if all(ismissing(options.Periodo))
                inicio = min(periodosECD(:, 1));
                fim = max(periodosECD(:, 2));
            elseif any(ismissing(options.Periodo)) || options.Periodo(1) > options.Periodo(2)
                error('model:ECD_EFD_ConciliacaoReceita:InvalidPeriod', ...
                    'Periodo deve conter data inicial e final validas, em ordem cronologica.')
            else
                inicio = dateshift(options.Periodo(1), 'start', 'day');
                fim = dateshift(options.Periodo(2), 'end', 'day');
            end

            ecdNoPeriodo = periodosECD(:, 1) <= fim & periodosECD(:, 2) >= inicio;
            if ~any(ecdNoPeriodo)
                error('model:ECD_EFD_ConciliacaoReceita:NoECDInPeriod', ...
                    'Nenhum arquivo ECD possui periodo sobreposto ao periodo de analise.')
            end

            meses = (dateshift(inicio, 'start', 'month'):calmonths(1):dateshift(fim, 'start', 'month'))';
            receitaECD = zeros(numel(meses), 1);
            saidasEFD = zeros(numel(meses), 1);
            documentosSaidaEFD = zeros(numel(meses), 1);
            codigosContasReceita = strings(0, 1);
            nomesContas = containers.Map('KeyType', 'char', 'ValueType', 'char');
            detalheMes = datetime.empty(0, 1);
            detalheCodConta = strings(0, 1);
            detalheReceita = zeros(0, 1);
            for indiceArquivo = find(ecdNoPeriodo)'
                contasECD = model.ECD_EFD_ConciliacaoReceita.criarTabela( ...
                    registrosECD{indiceArquivo}.xI050, ...
                    {'REG', 'DT_ALT', 'COD_NAT', 'IND_CTA', 'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'});
                codigosContasArquivo = model.ECD_EFD_ConciliacaoReceita.obterContasReceita( ...
                    contasECD, options.PadroesContaReceita);
                for indiceConta = 1:height(contasECD)
                    nomesContas(char(string(contasECD.COD_CTA(indiceConta)))) = char(string(contasECD.CTA(indiceConta)));
                end
                saldosMensais = model.ECD_EFD_ConciliacaoReceita.lerSaldosMensais(arquivosECD(indiceArquivo));
                linhasReceita = ismember(saldosMensais.COD_CTA, codigosContasArquivo);
                for indiceMes = 1:numel(meses)
                    linhasDoMes = linhasReceita & saldosMensais.PeriodoInicio >= meses(indiceMes) & ...
                        saldosMensais.PeriodoInicio <= dateshift(meses(indiceMes), 'end', 'month');
                    receitaECD(indiceMes) = receitaECD(indiceMes) + sum( ...
                        model.ECD_EFD_ConciliacaoReceita.converterValores(saldosMensais.VL_CRED(linhasDoMes)), "omitnan");

                    contasDoMes = saldosMensais.COD_CTA(linhasDoMes);
                    valoresDoMes = model.ECD_EFD_ConciliacaoReceita.converterValores(saldosMensais.VL_CRED(linhasDoMes));
                    [contasUnicasDoMes, ~, indiceGrupo] = unique(contasDoMes);
                    somaPorConta = accumarray(indiceGrupo, valoresDoMes, [], @(valores) sum(valores, "omitnan"));
                    detalheMes = [detalheMes; repmat(meses(indiceMes), numel(contasUnicasDoMes), 1)];
                    detalheCodConta = [detalheCodConta; contasUnicasDoMes];
                    detalheReceita = [detalheReceita; somaPorConta];
                end
                codigosContasReceita = [codigosContasReceita; codigosContasArquivo];
            end

            detalheServicoMes = datetime.empty(0, 1);
            detalheServicoCodConta = strings(0, 1);
            detalheServicoValor = zeros(0, 1);
            detalheServicoDocumentos = zeros(0, 1);
            detalheCfopMes = datetime.empty(0, 1);
            detalheCfopCodigo = strings(0, 1);
            detalheCfopValor = zeros(0, 1);
            detalheCfopDocumentos = zeros(0, 1);
            totalItensSaida = 0;
            itensSaidaComConta = 0;
            for indiceArquivo = 1:numel(arquivosEFD)
                registrosEFD = model.ECD_EFD_ConciliacaoReceita.lerRegistros(arquivosEFD(indiceArquivo), "C100");
                documentosEFD = model.ECD_EFD_ConciliacaoReceita.criarTabela(registrosEFD.xC100, ...
                    {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'NUM_DOC', 'CHV_NFE', 'DT_DOC', 'DT_E_S', 'VL_DOC'});
                datas = model.ECD_EFD_ConciliacaoReceita.converterDatas(documentosEFD.DT_DOC);
                linhasSaida = string(documentosEFD.IND_OPER) == "1" & ...
                    ~ismember(string(documentosEFD.COD_SIT), ["02", "03"]) & ...
                    datas >= inicio & datas <= fim;
                for indiceMes = 1:numel(meses)
                    linhasDoMes = linhasSaida & datas >= meses(indiceMes) & ...
                        datas <= dateshift(meses(indiceMes), 'end', 'month');
                    saidasEFD(indiceMes) = saidasEFD(indiceMes) + sum( ...
                        model.ECD_EFD_ConciliacaoReceita.converterValores(documentosEFD.VL_DOC(linhasDoMes)), "omitnan");
                    documentosSaidaEFD(indiceMes) = documentosSaidaEFD(indiceMes) + nnz(linhasDoMes);
                end

                documentosServico = model.ECD_EFD_ConciliacaoReceita.obterDocumentosServico(arquivosEFD(indiceArquivo));
                itensMercadoria = model.ECD_EFD_ConciliacaoReceita.obterItensMercadoriaPorConta(arquivosEFD(indiceArquivo));
                itensTelecom = model.ECD_EFD_ConciliacaoReceita.obterItensTelecomPorConta(arquivosEFD(indiceArquivo));
                itensMercadoriaComConta = itensMercadoria(strlength(itensMercadoria.COD_CTA) > 0, ...
                    {'IND_OPER', 'COD_SIT', 'DT_DOC', 'VL_DOC', 'COD_CTA'});
                itensTelecomComConta = itensTelecom(strlength(itensTelecom.COD_CTA) > 0, ...
                    {'IND_OPER', 'COD_SIT', 'DT_DOC', 'VL_DOC', 'COD_CTA'});
                documentosPorConta = [documentosServico; itensMercadoriaComConta; itensTelecomComConta];
                itensComCfop = [itensMercadoria(:, {'IND_OPER', 'COD_SIT', 'DT_DOC', 'VL_DOC', 'CFOP'}); ...
                                itensTelecom(:, {'IND_OPER', 'COD_SIT', 'DT_DOC', 'VL_DOC', 'CFOP'})];
                encontrouItemCfopSaida = false;
                if ~isempty(itensComCfop)
                    totalItensSaida = totalItensSaida + height(itensMercadoria) + height(itensTelecom);
                    itensSaidaComConta = itensSaidaComConta + height(itensMercadoriaComConta) + height(itensTelecomComConta);

                    datasCfop = model.ECD_EFD_ConciliacaoReceita.converterDatas(itensComCfop.DT_DOC);
                    linhasSaidaCfop = itensComCfop.IND_OPER == "1" & ...
                        ~ismember(itensComCfop.COD_SIT, ["02", "03"]) & ...
                        datasCfop >= inicio & datasCfop <= fim;
                    encontrouItemCfopSaida = any(linhasSaidaCfop);
                    for indiceMes = 1:numel(meses)
                        linhasDoMes = linhasSaidaCfop & datasCfop >= meses(indiceMes) & ...
                            datasCfop <= dateshift(meses(indiceMes), 'end', 'month');
                        if ~any(linhasDoMes)
                            continue
                        end

                        cfopsDoMes = itensComCfop.CFOP(linhasDoMes);
                        valoresDoMes = model.ECD_EFD_ConciliacaoReceita.converterValores(itensComCfop.VL_DOC(linhasDoMes));
                        [cfopsUnicosDoMes, ~, indiceGrupo] = unique(cfopsDoMes);
                        somaPorCfop = accumarray(indiceGrupo, valoresDoMes, [], @(valores) sum(valores, "omitnan"));
                        quantidadePorCfop = accumarray(indiceGrupo, 1);
                        detalheCfopMes = [detalheCfopMes; repmat(meses(indiceMes), numel(cfopsUnicosDoMes), 1)];
                        detalheCfopCodigo = [detalheCfopCodigo; cfopsUnicosDoMes];
                        detalheCfopValor = [detalheCfopValor; somaPorCfop];
                        detalheCfopDocumentos = [detalheCfopDocumentos; quantidadePorCfop];
                    end
                end

                if ~encontrouItemCfopSaida
                    % Fallback quando o arquivo nao possui C170/D510 vinculados a saida: usa o resumo mensal por CFOP (C190/D590).
                    consolidadoCfop = model.ECD_EFD_ConciliacaoReceita.obterConsolidadoCfop(arquivosEFD(indiceArquivo));
                    if ~isempty(consolidadoCfop) && consolidadoCfop.PeriodoInicio(1) >= inicio && consolidadoCfop.PeriodoInicio(1) <= fim
                        mesArquivo = dateshift(consolidadoCfop.PeriodoInicio(1), 'start', 'month');
                        valoresConsolidado = model.ECD_EFD_ConciliacaoReceita.converterValores(consolidadoCfop.VL_OPR);
                        [cfopsUnicosArquivo, ~, indiceGrupo] = unique(consolidadoCfop.CFOP);
                        somaPorCfop = accumarray(indiceGrupo, valoresConsolidado, [], @(valores) sum(valores, "omitnan"));
                        quantidadePorCfop = accumarray(indiceGrupo, 1);
                        detalheCfopMes = [detalheCfopMes; repmat(mesArquivo, numel(cfopsUnicosArquivo), 1)];
                        detalheCfopCodigo = [detalheCfopCodigo; cfopsUnicosArquivo];
                        detalheCfopValor = [detalheCfopValor; somaPorCfop];
                        detalheCfopDocumentos = [detalheCfopDocumentos; quantidadePorCfop];
                    end
                end

                if isempty(documentosPorConta)
                    continue
                end
                datasServico = model.ECD_EFD_ConciliacaoReceita.converterDatas(documentosPorConta.DT_DOC);
                linhasSaidaServico = documentosPorConta.IND_OPER == "1" & ...
                    ~ismember(documentosPorConta.COD_SIT, ["02", "03"]) & ...
                    datasServico >= inicio & datasServico <= fim;
                for indiceMes = 1:numel(meses)
                    linhasDoMes = linhasSaidaServico & datasServico >= meses(indiceMes) & ...
                        datasServico <= dateshift(meses(indiceMes), 'end', 'month');
                    if ~any(linhasDoMes)
                        continue
                    end

                    contasDoMes = documentosPorConta.COD_CTA(linhasDoMes);
                    valoresDoMes = model.ECD_EFD_ConciliacaoReceita.converterValores(documentosPorConta.VL_DOC(linhasDoMes));
                    [contasUnicasDoMes, ~, indiceGrupo] = unique(contasDoMes);
                    somaPorConta = accumarray(indiceGrupo, valoresDoMes, [], @(valores) sum(valores, "omitnan"));
                    quantidadePorConta = accumarray(indiceGrupo, 1);
                    detalheServicoMes = [detalheServicoMes; repmat(meses(indiceMes), numel(contasUnicasDoMes), 1)];
                    detalheServicoCodConta = [detalheServicoCodConta; contasUnicasDoMes];
                    detalheServicoValor = [detalheServicoValor; somaPorConta];
                    detalheServicoDocumentos = [detalheServicoDocumentos; quantidadePorConta];
                end
            end

            diferenca = receitaECD - saidasEFD;
            diferencaPercentual = NaN(numel(meses), 1);
            possuiSaidas = saidasEFD ~= 0;
            diferencaPercentual(possuiSaidas) = diferenca(possuiSaidas) ./ saidasEFD(possuiSaidas) * 100;
            diferencaPercentual(~possuiSaidas & receitaECD ~= 0) = Inf;

            status = repmat("Conciliado", numel(meses), 1);
            status(abs(diferenca) > options.Tolerancia) = "Divergente";
            periodoFim = dateshift(meses, 'end', 'month');

            conciliacao = table(meses, periodoFim, receitaECD, saidasEFD, diferenca, diferencaPercentual, ...
                repmat(numel(unique(codigosContasReceita)), numel(meses), 1), documentosSaidaEFD, status, ...
                'VariableNames', {'PeriodoInicio', 'PeriodoFim', 'ReceitaECD', 'SaidasEFD', ...
                                  'Diferenca', 'DiferencaPercentual', 'ContasReceitaECD', ...
                                  'DocumentosSaidaEFD', 'Status'});

            % SaidasEFDMes eh o total do mes (C100 nao possui COD_CTA), citado apenas como referencia.
            [~, indiceMesDetalhe] = ismember(detalheMes, meses);
            nomeContaDetalhe = repmat("", numel(detalheCodConta), 1);
            for indiceDetalhe = 1:numel(detalheCodConta)
                chaveConta = char(detalheCodConta(indiceDetalhe));
                if isKey(nomesContas, chaveConta)
                    nomeContaDetalhe(indiceDetalhe) = string(nomesContas(chaveConta));
                end
            end

            % SaidasEFDPorConta soma documentos de servico (D100/D500) e itens de mercadoria (C170), que possuem COD_CTA proprio.
            chaveDetalhe = string(detalheMes, 'yyyyMM') + "|" + detalheCodConta;
            chaveServico = string(detalheServicoMes, 'yyyyMM') + "|" + detalheServicoCodConta;
            [encontradoServico, indiceServico] = ismember(chaveDetalhe, chaveServico);
            saidasEFDPorConta = zeros(numel(detalheCodConta), 1);
            documentosServicoPorConta = zeros(numel(detalheCodConta), 1);
            saidasEFDPorConta(encontradoServico) = detalheServicoValor(indiceServico(encontradoServico));
            documentosServicoPorConta(encontradoServico) = detalheServicoDocumentos(indiceServico(encontradoServico));


            diferencaPorConta = detalheReceita - saidasEFDPorConta;

            detalhePorConta = table(detalheMes, dateshift(detalheMes, 'end', 'month'), detalheCodConta, ...
                nomeContaDetalhe, detalheReceita, saidasEFD(indiceMesDetalhe), ...
                saidasEFDPorConta, documentosServicoPorConta, diferencaPorConta, ...
                'VariableNames', {'PeriodoInicio', 'PeriodoFim', 'COD_CTA', 'CTA', 'ReceitaECD', 'SaidasEFDMes', ...
                                  'SaidasEFDPorConta', 'DocumentosServicoEFD', 'DiferencaPorConta'});
            detalhePorConta = sortrows(detalhePorConta, {'PeriodoInicio', 'COD_CTA'});

            % Alternativa quando COD_CTA nao e preenchido na EFD: agregacao por CFOP, sem vinculo a conta ECD.
            detalhePorCfop = table(detalheCfopMes, dateshift(detalheCfopMes, 'end', 'month'), ...
                detalheCfopCodigo, detalheCfopValor, ...
                'VariableNames', {'PeriodoInicio', 'PeriodoFim', 'CFOP', 'ValorEFD'});
            detalhePorCfop.QuantidadeDocumentos = detalheCfopDocumentos;
            detalhePorCfop = sortrows(detalhePorCfop, {'PeriodoInicio', 'CFOP'});

            coberturaCodCta = 0;
            if totalItensSaida > 0
                coberturaCodCta = itensSaidaComConta / totalItensSaida;
            end
            if totalItensSaida > 0 && coberturaCodCta < 0.2
                warning('model:ECD_EFD_ConciliacaoReceita:BaixaCoberturaCodCta', ...
                    ['Apenas %.1f%% dos itens de saida da EFD possuem COD_CTA preenchido. ', ...
                     'SaidasEFDPorConta pode estar subestimada; use detalhePorCfop como alternativa.'], ...
                    coberturaCodCta * 100)
            end
        end

        function conciliacao = comparar(ecdObj, efdObj, options)
            arguments
                ecdObj (1,:) model.ECD
                efdObj (1,:) model.EFD
                options.PadroesContaReceita (1,:) string = ["RECEITA", "VENDA", "FATURAMENTO"]
                options.Tolerancia (1,1) double {mustBeNonnegative} = 0.01
            end

            model.ECD_EFD_ConciliacaoReceita.validarTabelasECD(ecdObj)
            model.ECD_EFD_ConciliacaoReceita.validarTabelasEFD(efdObj)

            periodoInicio = datetime.empty(0, 1);
            periodoFim = datetime.empty(0, 1);
            receitaECD = zeros(0, 1);
            saidasEFD = zeros(0, 1);
            contasReceitaECD = zeros(0, 1);
            documentosSaidaEFD = zeros(0, 1);

            for indiceECD = 1:numel(ecdObj)
                [inicio, fim] = model.ECD_EFD_ConciliacaoReceita.obterPeriodo(ecdObj(indiceECD));
                codigosContasReceita = model.ECD_EFD_ConciliacaoReceita.obterContasReceita(ecdObj(indiceECD).Table.xI050, options.PadroesContaReceita);
                creditos = ecdObj(indiceECD).Table.xI155;
                contas = string(creditos.COD_CTA);
                linhasReceita = ismember(contas, codigosContasReceita);

                periodoInicio(end+1, 1) = inicio;
                periodoFim(end+1, 1) = fim;
                receitaECD(end+1, 1) = sum(creditos.VL_CRED(linhasReceita), "omitnan");
                contasReceitaECD(end+1, 1) = numel(unique(contas(linhasReceita)));

                [valorSaidas, quantidadeDocumentos] = model.ECD_EFD_ConciliacaoReceita.somarSaidasEFD(efdObj, inicio, fim);
                saidasEFD(end+1, 1) = valorSaidas;
                documentosSaidaEFD(end+1, 1) = quantidadeDocumentos;
            end

            diferenca = receitaECD - saidasEFD;
            diferencaPercentual = zeros(numel(receitaECD), 1);
            possuiSaidas = saidasEFD ~= 0;
            diferencaPercentual(possuiSaidas) = diferenca(possuiSaidas) ./ saidasEFD(possuiSaidas) * 100;
            diferencaPercentual(~possuiSaidas & receitaECD ~= 0) = Inf;

            status = repmat("Conciliado", height(receitaECD), 1);
            status(abs(diferenca) > options.Tolerancia) = "Divergente";

            conciliacao = table( ...
                periodoInicio, periodoFim, receitaECD, saidasEFD, diferenca, diferencaPercentual, ...
                contasReceitaECD, documentosSaidaEFD, status, ...
                'VariableNames', {'PeriodoInicio', 'PeriodoFim', 'ReceitaECD', 'SaidasEFD', ...
                                  'Diferenca', 'DiferencaPercentual', 'ContasReceitaECD', ...
                                  'DocumentosSaidaEFD', 'Status'});
        end
    end

    methods (Static, Access = private)
        function arquivos = listarArquivos(entrada)
            if isfile(entrada)
                arquivos = entrada;
                return
            end

            if ~isfolder(entrada)
                error('model:ECD_EFD_ConciliacaoReceita:InvalidInput', ...
                    'A entrada deve ser um arquivo ou uma pasta existente: %s', entrada)
            end

            arquivosNaPasta = dir(fullfile(entrada, '**', '*'));
            arquivosNaPasta = arquivosNaPasta(~[arquivosNaPasta.isdir]);
            arquivos = string(fullfile({arquivosNaPasta.folder}, {arquivosNaPasta.name}))';
        end

        function registros = lerRegistros(arquivo, registrosDesejados)
            registrosDesejados = string(registrosDesejados);
            registros = struct();
            for registro = registrosDesejados
                campo = "x" + registro;
                registros.(campo) = cell(0, 1);
            end

            linhas = model.ECD_EFD_ConciliacaoReceita.lerLinhas(arquivo);
            for linha = linhas'
                campos = split(linha, "|");
                campos = campos(2:end-1);
                if isempty(campos) || ~ismember(campos(1), registrosDesejados)
                    continue
                end

                campo = "x" + campos(1);
                registros.(campo)(end+1, 1) = {cellstr(campos')};
            end
        end

        function saldos = lerSaldosMensais(arquivo)
            linhas = model.ECD_EFD_ConciliacaoReceita.lerLinhas(arquivo);
            periodoInicio = datetime.empty(0, 1);
            codigoConta = strings(0, 1);
            valorCredito = strings(0, 1);
            inicioBalancete = NaT;

            for linha = linhas'
                campos = split(linha, "|");
                campos = campos(2:end-1);
                if isempty(campos)
                    continue
                end

                if campos(1) == "I150" && numel(campos) >= 3
                    inicioBalancete = model.ECD_EFD_ConciliacaoReceita.converterData(campos(2));
                elseif campos(1) == "I155" && ~ismissing(inicioBalancete) && numel(campos) >= 7
                    periodoInicio(end+1, 1) = inicioBalancete;
                    codigoConta(end+1, 1) = campos(2);
                    valorCredito(end+1, 1) = campos(7);
                end
            end

            saldos = table(periodoInicio, codigoConta, valorCredito, ...
                'VariableNames', {'PeriodoInicio', 'COD_CTA', 'VL_CRED'});
        end

        function linhas = lerLinhas(arquivo)
            fileId = fopen(arquivo, 'r');
            if fileId == -1
                error('model:ECD_EFD_ConciliacaoReceita:FileOpenFailed', ...
                    'Nao foi possivel abrir o arquivo: %s', arquivo)
            end
            fileCleanup = onCleanup(@() fclose(fileId));
            signature = fread(fileId, 4, '*uint8')';

            if ~isequal(signature, [80, 75, 3, 4])
                linhas = readlines(arquivo, 'EmptyLineRule', 'skip');
                return
            end

            temporaryFolder = tempname;
            mkdir(temporaryFolder);
            folderCleanup = onCleanup(@() rmdir(temporaryFolder, 's'));
            extractedFiles = string(unzip(arquivo, temporaryFolder));
            [~, fileNames] = fileparts(extractedFiles);
            isEscrituracao = startsWith(upper(fileNames), "ESCRITURACAO-") & ...
                ~contains(upper(fileNames), "TRANSFER_OBJECT");
            selectedFiles = extractedFiles(isEscrituracao);

            if numel(selectedFiles) ~= 1
                error('model:ECD_EFD_ConciliacaoReceita:InvalidSpedZip', ...
                    'O arquivo ZIP deve conter exatamente uma entrada ESCRITURACAO: %s', arquivo)
            end

            linhas = readlines(selectedFiles, 'EmptyLineRule', 'skip');
        end

        function documentos = obterItensMercadoriaPorConta(arquivo)
            linhas = model.ECD_EFD_ConciliacaoReceita.lerLinhas(arquivo);
            indOper = strings(0, 1);
            codSit = strings(0, 1);
            dtDoc = strings(0, 1);
            valorItem = strings(0, 1);
            codCta = strings(0, 1);
            cfop = strings(0, 1);

            indOperAtual = "";
            codSitAtual = "";
            dtDocAtual = "";
            for linha = linhas'
                campos = split(linha, "|");
                campos = campos(2:end-1);
                if isempty(campos)
                    continue
                end

                if campos(1) == "C100" && numel(campos) >= 10
                    indOperAtual = campos(2);
                    codSitAtual = campos(6);
                    dtDocAtual = campos(10);
                elseif campos(1) == "C170" && numel(campos) >= 11 && indOperAtual ~= ""
                    indOper(end+1, 1) = indOperAtual;
                    codSit(end+1, 1) = codSitAtual;
                    dtDoc(end+1, 1) = dtDocAtual;
                    valorItem(end+1, 1) = campos(7);
                    cfop(end+1, 1) = campos(11);
                    if numel(campos) >= 37
                        codCta(end+1, 1) = campos(37);
                    else
                        codCta(end+1, 1) = "";
                    end
                end
            end

            documentos = table(indOper, codSit, dtDoc, valorItem, codCta, cfop, ...
                'VariableNames', {'IND_OPER', 'COD_SIT', 'DT_DOC', 'VL_DOC', 'COD_CTA', 'CFOP'});
        end

        function documentos = obterItensTelecomPorConta(arquivo)
            linhas = model.ECD_EFD_ConciliacaoReceita.lerLinhas(arquivo);
            indOper = strings(0, 1);
            codSit = strings(0, 1);
            dtDoc = strings(0, 1);
            valorItem = strings(0, 1);
            codCta = strings(0, 1);
            cfop = strings(0, 1);

            indOperAtual = "";
            codSitAtual = "";
            dtDocAtual = "";
            for linha = linhas'
                campos = split(linha, "|");
                campos = campos(2:end-1);
                if isempty(campos)
                    continue
                end

                if campos(1) == "D500" && numel(campos) >= 10
                    indOperAtual = campos(2);
                    codSitAtual = campos(6);
                    dtDocAtual = campos(10);
                elseif campos(1) == "D510" && numel(campos) >= 10 && indOperAtual ~= ""
                    indOper(end+1, 1) = indOperAtual;
                    codSit(end+1, 1) = codSitAtual;
                    dtDoc(end+1, 1) = dtDocAtual;
                    valorItem(end+1, 1) = campos(7);
                    cfop(end+1, 1) = campos(10);
                    if numel(campos) >= 20
                        codCta(end+1, 1) = campos(20);
                    else
                        codCta(end+1, 1) = "";
                    end
                end
            end

            documentos = table(indOper, codSit, dtDoc, valorItem, codCta, cfop, ...
                'VariableNames', {'IND_OPER', 'COD_SIT', 'DT_DOC', 'VL_DOC', 'COD_CTA', 'CFOP'});
        end

        function consolidado = obterConsolidadoCfop(arquivo)
            registros = model.ECD_EFD_ConciliacaoReceita.lerRegistros(arquivo, ["0000", "C190", "D590"]);
            cabecalho = model.ECD_EFD_ConciliacaoReceita.criarTabela(registros.x0000, ...
                {'REG', 'COD_VER', 'COD_FIN', 'DT_INI', 'DT_FIN'});
            if height(cabecalho) ~= 1
                consolidado = table.empty(0, 3);
                return
            end

            periodoInicio = model.ECD_EFD_ConciliacaoReceita.converterData(cabecalho.DT_INI(1));
            tabelaC190 = model.ECD_EFD_ConciliacaoReceita.criarTabela(registros.xC190, ...
                {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR'});
            tabelaD590 = model.ECD_EFD_ConciliacaoReceita.criarTabela(registros.xD590, ...
                {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR'});

            consolidado = [tabelaC190(:, {'CFOP', 'VL_OPR'}); tabelaD590(:, {'CFOP', 'VL_OPR'})];
            consolidado = consolidado(startsWith(consolidado.CFOP, ["5", "6", "7"]), :);
            consolidado.PeriodoInicio = repmat(periodoInicio, height(consolidado), 1);
        end

        function documentos = obterDocumentosServico(arquivo)
            registros = model.ECD_EFD_ConciliacaoReceita.lerRegistros(arquivo, ["D100", "D500"]);

            documentosD100 = model.ECD_EFD_ConciliacaoReceita.criarTabela(registros.xD100, ...
                {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'NUM_DOC', ...
                 'CHV_CTE', 'DT_DOC', 'DT_A_P', 'TP_CT_E', 'CHV_CTE_REF', 'VL_DOC', 'VL_DESC', 'IND_FRT', ...
                 'VL_SERV', 'VL_BC_ICMS', 'VL_ICMS', 'VL_NT', 'COD_INF', 'COD_CTA'});
            documentosD500 = model.ECD_EFD_ConciliacaoReceita.criarTabela(registros.xD500, ...
                {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'NUM_DOC', ...
                 'DT_DOC', 'DT_A_P', 'VL_DOC', 'VL_DESC', 'VL_SERV', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', ...
                 'VL_BC_ICMS', 'VL_ICMS', 'COD_INF', 'VL_PIS', 'VL_COFINS', 'COD_CTA', 'TP_ASSINANTE'});

            colunasComuns = {'IND_OPER', 'COD_SIT', 'DT_DOC', 'VL_DOC', 'COD_CTA'};
            documentos = [documentosD100(:, colunasComuns); documentosD500(:, colunasComuns)];
            documentos = documentos(strlength(string(documentos.COD_CTA)) > 0, :);
        end

        function tabela = criarTabela(linhas, nomesColunas)
            quantidadeColunas = numel(nomesColunas);
            dados = strings(numel(linhas), quantidadeColunas);

            for indice = 1:numel(linhas)
                campos = string(linhas{indice});
                dados(indice, 1:min(numel(campos), quantidadeColunas)) = campos(1:min(numel(campos), quantidadeColunas));
            end

            tabela = array2table(dados, 'VariableNames', nomesColunas);
        end

        function [inicio, fim] = obterPeriodoDoCabecalho(cabecalho)
            if height(cabecalho) ~= 1
                error('model:ECD_EFD_ConciliacaoReceita:InvalidECDHeader', ...
                    'O arquivo ECD deve conter exatamente um registro 0000.')
            end

            inicio = model.ECD_EFD_ConciliacaoReceita.converterData(cabecalho.DT_INI(1));
            fim = model.ECD_EFD_ConciliacaoReceita.converterData(cabecalho.DT_FIN(1));
        end

        function valores = converterValores(valores)
            valores = str2double(strrep(string(valores), ',', '.'));
        end

        function validarTabelasECD(ecdObj)
            for indice = 1:numel(ecdObj)
                if ~isfield(ecdObj(indice).Table, 'xI050') || ~istable(ecdObj(indice).Table.xI050) || ...
                        ~isfield(ecdObj(indice).Table, 'xI155') || ~istable(ecdObj(indice).Table.xI155)
                    error('model:ECD_EFD_ConciliacaoReceita:MissingECDTables', ...
                        'A ECD deve ter as tabelas I050 e I155 carregadas antes da conciliacao.')
                end
            end
        end

        function validarTabelasEFD(efdObj)
            for indice = 1:numel(efdObj)
                if ~isfield(efdObj(indice).Table, 'xC100') || ~istable(efdObj(indice).Table.xC100)
                    error('model:ECD_EFD_ConciliacaoReceita:MissingEFDTable', ...
                        'A EFD deve ter a tabela C100 carregada antes da conciliacao.')
                end
            end
        end

        function codigos = obterContasReceita(contasECD, padroes)
            nomesContas = upper(string(contasECD.CTA));
            linhasReceita = any(contains(nomesContas, upper(padroes)), 2);

            if ismember('IND_CTA', contasECD.Properties.VariableNames)
                linhasReceita = linhasReceita & string(contasECD.IND_CTA) == "A";
            end

            codigos = unique(string(contasECD.COD_CTA(linhasReceita)));
        end

        function [inicio, fim] = obterPeriodo(spedObj)
            periodo = spedObj.Period;
            if isa(periodo, 'datetime') && numel(periodo) >= 2
                inicio = dateshift(periodo(1), 'start', 'day');
                fim = dateshift(periodo(end), 'end', 'day');
                return
            end

            if isfield(spedObj.Table, 'x0000') && istable(spedObj.Table.x0000)
                cabecalho = spedObj.Table.x0000;
                inicio = model.ECD_EFD_ConciliacaoReceita.converterData(cabecalho.DT_INI(1));
                fim = model.ECD_EFD_ConciliacaoReceita.converterData(cabecalho.DT_FIN(1));
                return
            end

            error('model:ECD_EFD_ConciliacaoReceita:MissingPeriod', ...
                'Nao foi possivel determinar o periodo da ECD.')
        end

        function [valor, quantidade] = somarSaidasEFD(efdObj, inicio, fim)
            valor = 0;
            quantidade = 0;

            for indice = 1:numel(efdObj)
                documentos = efdObj(indice).Table.xC100;
                datas = model.ECD_EFD_ConciliacaoReceita.converterDatas(documentos.DT_DOC);
                saidas = string(documentos.IND_OPER) == "1";
                noPeriodo = datas >= inicio & datas <= fim;
                naoCancelados = true(height(documentos), 1);

                if ismember('COD_SIT', documentos.Properties.VariableNames)
                    naoCancelados = ~ismember(string(documentos.COD_SIT), ["02", "03"]);
                end

                linhas = saidas & noPeriodo & naoCancelados;
                valor = valor + sum(documentos.VL_DOC(linhas), "omitnan");
                quantidade = quantidade + nnz(linhas);
            end
        end

        function datas = converterDatas(valores)
            if isa(valores, 'datetime')
                datas = dateshift(valores, 'start', 'day');
                return
            end

            valores = string(valores);
            datas = datetime(valores, 'InputFormat', 'ddMMyyyy', 'Format', 'dd/MM/yyyy');
        end

        function data = converterData(valor)
            data = model.ECD_EFD_ConciliacaoReceita.converterDatas(valor);
        end
    end
end