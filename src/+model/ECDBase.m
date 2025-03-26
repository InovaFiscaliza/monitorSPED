classdef ECDBase < handle
    % Cadastro de fichas e dos seus campos, de acordo com os diversos layouts 
    % dos arquivos. Na pasta "doc" consta os PDFs descrevendo cada layout,
    % mas outras informações podem ser obtidas em http://sped.rfb.gov.br/

    % ToDo:
    % • Inseridos todos os IDs dos campos, mas mapeados apenas alguns deles.
    %   Avaliar quais deles precisam ser mapeados para execução da auditoria.

    % • Pendente confirmar os campos adicionais, além da ficha I020, dos
    %   layouts 1 a 8.

    % • Pendente cadastrar campos "COD_CVM_AUDITOR", "IDENT_CPF", "IND_DC_BAL",
    %   "IND_DC_BAL_INI", "IND_DC_CTA", "IND_VL" "IND_VL_ULT_DRE", "NIRE_SUBST", 
    %   "NOME_AUDITOR", "VL_CTA_ULT_DRE" que aparecem nos primeiros layouts.

    properties (Access = protected, Constant = true)
        %-------------------------------------------------------%
        % TABELAS SOB ANÁLISE
        % As tabelas (ou fichas) sob análise são organizadas num cellarray
        % com três colunas, em que a primeira coluna contém um array com a 
        % indicação do layout aplicável (1:9, por exemplo), a segunda coluna
        % são os campos obrigatórios da ficha, e a terceira coluna os campos
        % opcionais (ou adicionais).
        %-------------------------------------------------------%
        
        % Bloco 0: Abertura, identificações e referências
        x0000 = {1,   {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP'}, {}; ...
                 2,   {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC'}, {}; ...
                 3,   {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'NIRE_SUBST', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP'}, {}; ...
                 4    {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'NIRE_SUBST', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF'}, {}; ...
                 5:7, {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF', 'IND_ESC_CONS'}, {}; ...
                 8:9, {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF', 'IND_ESC_CONS', 'IND_CENTRALIZADA', 'IND_MUDANC_PC', 'COD_PLAN_REF'}, {}}
        x0001
        x0007
        x0020
        x0035
        x0150
        x0180
        x0990

        % Bloco C: Informações recuperadas a escrituração contábil anterior
        xC001
        xC040
        xC050 = {9,   {'REG', 'DT_ALT', 'COD_NAT', 'IND_CTA', 'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}, {}}
        xC051 = {9,   {'REG', 'COD_CCUS', 'COD_CTA_REF'}, {}}
        xC052 = {9,   {'REG', 'COD_CCUS', 'COD_AGL'}, {}}
        xC150
        xC155
        xC600
        xC650
        xC990

        % Bloco I: Informações recuperadas a escrituração contábil anterior
        xI001
        xI010 = {1:9, {'REG', 'IND_ESC', 'COD_VER_LC'}, {}}
        xI012
        xI015
        xI020 = {1:9, {'REG', 'REG_COD', 'NUM_AD', 'CAMPO', 'DESCRICAO', 'TIPO', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN'}, {}}
        xI030 = {1,   {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN'}, {}; ...
                 2,   {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN', 'DT_EX_SOCIAL', 'NOME_AUDITOR', 'COD_CVM_AUDITOR'}, {}; ...
                 3:9, {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN', 'DT_EX_SOCIAL'}, {}}
        xI050 = {1:9, {'REG', 'DT_ALT', 'COD_NAT', 'IND_CTA', 'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}, {}}
        xI051 = {9,   {'REG', 'COD_CCUS', 'COD_CTA_REF'}, {}}
        xI052 = {9,   {'REG', 'COD_CCUS', 'COD_AGL'}, {}}
        xI053
        xI075
        xI100 = {1:9, {'REG', 'DT_ALT', 'COD_CCUS', 'CCUS'}, {}}
        xI150 = {1:9, {'REG', 'DT_INI', 'DT_FIN'}, {}}
        xI155 = {1:8, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI', 'VL_DEB', 'VL_CRED', 'VL_SLD_FIN', 'IND_DC_FIN'}, {}; ...
                 9,   {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI', 'VL_DEB', 'VL_CRED', 'VL_SLD_FIN', 'IND_DC_FIN'}, {'VL_SLD_INI_MF', 'IND_DC_INI_MF', 'VL_DEB_MF', 'VL_CRED_MF', 'VL_SLD_FIN_MF', 'IND_DC_FIN_MF'}}
        xI157 = {1,   {}, {}; ...
                 2:4, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI'}, {}; ... 
                 5:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI'}, {'VL_SLD_INI_MF', 'IND_DC_INI_MF'}}
        xI200 = {1:6, {'REG', 'NUM_LCTO', 'DT_LCTO', 'VL_LCTO', 'IND_LCTO'}, {}; ...
                 7:9, {'REG', 'NUM_LCTO', 'DT_LCTO', 'VL_LCTO', 'IND_LCTO', 'DT_LCTO_EXT'}, {'VL_LCTO_MF'}}
        xI250 = {1:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_DC', 'IND_DC', 'NUM_ARQ', 'COD_HIST_PAD', 'HIST', 'COD_PART'}, {'VL_DC_MF', 'IND_DC_MF'}}
        xI300 = {9,   {'REG', 'DT_BCTE'}, {}}
        xI310 = {9,   {'REG', 'COD_CTA', 'COD_CCUS', 'VAL_DEBD', 'VAL_CREDD'}, {'VAL_DEB_MF', 'VAL_CRED_MF'}}
        xI350 = {1:9, {'REG', 'DT_RES'}, {}}
        xI355 = {1:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_CTA', 'IND_DC'}, {'VL_CTA_MF', 'IND_DC_MF'}}
        xI500
        xI510
        xI550
        xI555
        xI990

        % Bloco J: Demonstrações contábeis
        xJ001
        xJ005 = {1:9, {'REG', 'DT_INI', 'DT_FIN', 'ID_DEM', 'CAB_DEM'}, {}}
        xJ100 = {1,   {'REG', 'COD_AGL', 'NIVEL_AGL', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_BAL'}, {}; ...
                 2:5, {'REG', 'COD_AGL', 'NIVEL_AGL', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_BAL', 'VL_CTA_INI', 'IND_DC_BAL_INI'}, {}; ...
                 6,   {'REG', 'COD_AGL', 'NIVEL_AGL', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_BAL', 'VL_CTA_INI', 'IND_DC_BAL_INI', 'NOTA_EXP_REF'}, {}; ...
                 7:9, {'REG', 'COD_AGL', 'IND_COD_AGL', 'NIVEL_AGL', 'COD_AGL_SUP', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA_INI', 'IND_DC_CTA_INI', 'VL_CTA_FIN', 'IND_DC_CTA_FIN', 'NOTA_EXP_REF'}, {}}
        xJ150 = {1:3, {'REG', 'COD_AGL', 'NIVEL_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_VL'}, {}; ...
                 4:5, {'REG', 'COD_AGL', 'NIVEL_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_VL', 'VL_CTA_ULT_DRE', 'IND_VL_ULT_DRE'}, {}; ...
                 6,   {'REG', 'COD_AGL', 'NIVEL_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_VL', 'VL_CTA_ULT_DRE', 'IND_VL_ULT_DRE', 'NOTA_EXP_REF'}, {}; ...
                 7,   {'REG', 'COD_AGL', 'IND_COD_AGL', 'NIVEL_AGL', 'COD_AGL_SUP', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_CTA', 'IND_GRP_DRE', 'NOTA_EXP_REF'}, {}; ...
                 8:9, {'REG', 'NU_ORDEM', 'COD_AGL', 'IND_COD_AGL', 'NIVEL_AGL', 'COD_AGL_SUP', 'DESCR_COD_AGL', 'VL_CTA_INI_', 'IND_DC_CTA_INI', 'VL_CTA_FIN', 'IND_DC_CTA_FIN', 'IND_GRP_DRE', 'NOTA_EXP_REF'}, {}}
        xJ210
        xJ215
        xJ800
        xJ801
        xJ900
        xJ930 = {1,   {'REG', 'IDENT_NOM', 'IDENT_CPF', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC'}, {}; ...
                 2:4, {'REG', 'IDENT_NOM', 'IDENT_CPF', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC', 'EMAIL', 'FONE', 'UF_CRC', 'NUM_SEQ_CRC', 'DT_CRC'}, {}; ...
                 5:9, {'REG', 'IDENT_NOM', 'IDENT_CPF_CNPJ', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC', 'EMAIL', 'FONE', 'UF_CRC', 'NUM_SEQ_CRC', 'DT_CRC', 'IND_RESP_LEGAL'}, {}}
        xJ932
        xJ935
        xJ990

        % Bloco K: Conglomerados econômicos
        xK001
        xK030
        xK100
        xK110
        xK115
        xK200
        xK210
        xK300
        xK310
        xK315
        xK990

        % Bloco 9: Controle e encerramento do arquivo digital
        x9001
        x9900
        x9990
        x9999
    end


    properties (Access = protected, Constant = true)
        %-------------------------------------------------------%
        % CAMPOS RELACIONADOS ÀS TABELAS SOB ANÁLISE
        %-------------------------------------------------------%
        CAB_DEM          = struct('DataType', 'cell',     'Description', 'Cabeçalho das demonstrações.')
        CAMPO            = struct('DataType', 'cell',     'Description', 'Nome do campo adicional.')
        CCUS             = struct('DataType', 'cell',     'Description', 'Nome do centro de custos.')
        CNPJ             = struct('DataType', 'cell',     'Description', 'Número de inscrição da pessoa jurídica no CNPJ.Observação: Esse CNPJ é sempre da Sócia Ostensiva, no caso do arquivo da SCP.')
        COD_AGL          = struct('DataType', 'cell',     'Description', 'Código de aglutinação das linhas, atribuído pela pessoa jurídica.')
        COD_AGL_SUP      = struct('DataType', 'cell',     'Description', 'Código de aglutinação sintético/grupo de código de aglutinação de nível superior.')
        COD_ASSIN        = struct('DataType', 'cell',     'Description', 'Código de qualificação do assinante, conforme tabela.')
        COD_CCUS         = struct('DataType', 'cell',     'Description', 'Código do centro de custos do plano de contas anterior.')
        COD_CTA          = struct('DataType', 'cell',     'Description', 'Código da conta analítica.')
        COD_CTA_REF      = struct('DataType', 'cell',     'Description', 'Código da conta de acordo com o plano de contas referencial, conforme tabela publicada pelos órgãos indicados no campo COD_PLAN_REF do registro 0000.')
        COD_CTA_SUP      = struct('DataType', 'cell',     'Description', 'Código da conta sintética /grupo de contas de nível imediatamente superior.')
      % COD_CVM_AUDITOR
        COD_HASH_SUB     = struct('DataType', 'cell',     'Description', 'Hash da escrituração substituída.')
        COD_HIST_PAD     = struct('DataType', 'cell',     'Description', 'Código do histórico padronizado, conforme tabela I075.')
        COD_MUN          = struct('DataType', 'cell',     'Description', 'Código do município do domicílio fiscal da pessoa jurídica, conforme tabela do IBGE – Instituto Brasileiro de Geografia e Estatística.')
        COD_NAT          = struct('DataType', 'cell',     'Description', 'Código da natureza da conta/grupo de contas, conforme tabela publicada pelo Sped.')
        COD_PART         = struct('DataType', 'cell',     'Description', 'Código de identificação do participante na partida conforme tabela 0150 (preencher somente quando identificado o tipo de participação no registro 0180')
        COD_PLAN_REF     = struct('DataType', 'cell',     'Description', 'Código do Plano de Contas Referencial que será utilizado para o mapeamento de todas as contas analíticas: 1 – PJ em Geral – Lucro Real 2 – PJ em Geral – Lucro Presumido 3 – Financeiras – Lucro Real 4 – Seguradoras – Lucro Real 5 – Imunes e Isentas em Geral 6 – Imunes e Isentas – Financeiras 7 – Imunes e Isentas – Seguradoras 8 – Entidades Fechadas de Previdência Complementar 9 – Partidos Políticos 10 – Financeiras – Lucro Presumido Observação: Caso a pessoa jurídica não realize o mapeamento para os planos referenciais na ECD, este campo deve ficar em branco.')
        COD_SCP          = struct('DataType', 'cell',     'Description', 'CNPJ da SCP (Anexo I, XVIII, da IN RFB nº 2.119, de 06 de dezembro de 2022 Observação: Só deve ser preenchido pela própria SCP com o CNPJ da SCP (Não é preenchido pelo sócio ostensivo"')
        COD_VER_LC       = struct('DataType', 'double',   'Description', 'Código da versão do leiaute')
        CTA              = struct('DataType', 'cell',     'Description', 'Nome da conta analítica/grupo de contas.')
        DESC_MUN         = struct('DataType', 'cell',     'Description', ' Município.')
        DESCR_COD_AGL    = struct('DataType', 'cell',     'Description', 'Descrição do Código de aglutinação.')
        DESCRICAO        = struct('DataType', 'cell',     'Description', 'Descrição do campo adicional.')
        DNRC_ABERT       = struct('DataType', 'cell',     'Description', 'Texto fixo contendo “TERMO DE ABERTURA”.')
        DT_ALT           = struct('DataType', 'datetime', 'Description', 'Data da inclusão/alteração.')
        DT_ARQ           = struct('DataType', 'datetime', 'Description', 'Data do arquivamento dos atos constitutivos.')
        DT_ARQ_CONV      = struct('DataType', 'datetime', 'Description', 'Data de arquivamento do ato de conversão de sociedade simples em sociedade empresária.')
        DT_BCTE          = struct('DataType', 'datetime', 'Description', 'Data do balancete.')
        DT_CRC           = struct('DataType', 'datetime', 'Description', 'Data de validade da Certidão de Regularidade Profissional do Contador')
        DT_EX_SOCIAL     = struct('DataType', 'datetime', 'Description', ' Data de encerramento do exercício social.')
        DT_FIN           = struct('DataType', 'datetime', 'Description', 'Data final das demonstrações contábeis.')
        DT_INI           = struct('DataType', 'datetime', 'Description', 'Data inicial das demonstrações contábeis. Observação: A data inicial das demonstrações deve ser a data posterior ao último encerramento do exercício, mesmo que essa data não esteja no período da ECD transmitida. Exemplo: Data do Último Encerramento do Exercício: 31/12/2022 Data Inicial das Demonstrações Contábeis: 01/01/2023')
        DT_LCTO          = struct('DataType', 'datetime', 'Description', 'Data do lançamento.')
        DT_LCTO_EXT      = struct('DataType', 'datetime', 'Description', 'Data de ocorrência dos fatos objeto do lançamento extemporâneo. Observação: Caso não seja possível precisar a data a que se refiram os fatos do lançamento extemporâneo, informar a data de encerramento do exercício em que ocorreram esses fatos.')
        DT_RES           = struct('DataType', 'datetime', 'Description', 'Data da apuração do resultado.')
        EMAIL            = struct('DataType', 'cell',     'Description', 'Email do signatário.')
        FONE             = struct('DataType', 'cell',     'Description', 'Telefone do signatário.')
        HIST             = struct('DataType', 'cell',     'Description', 'Histórico completo da partida ou histórico complementar. Observação: Caso o lançamento seja do tipo “X” – lançamento extemporâneo - em qualquer das formas de retificação, o histórico do lançamento extemporâneo deve especificar o motivo da correção, a data e o número do lançamento de origem (item 32 do ITG 2000 (R1)')
        ID_DEM           = struct('DataType', 'cell',     'Description', 'Identificação das demonstrações: 1 – demonstrações contábeis da pessoa jurídica a que se refere a escrituração (inclusive Matrix/Filiais); 2 – demonstrações consolidadas ou de outras pessoas jurídicas.')
      % IDENT_CPF
        IDENT_CPF_CNPJ   = struct('DataType', 'cell',     'Description', 'CPF ou CNPJ')
        IDENT_MF         = struct('DataType', 'cell',     'Description', 'Identificação de moeda funcional: Indica que a escrituração abrange valores com base na moeda funcional (art. 287 da Instrução Normativa RFB nº 1.700, de 14 de março de 2017 Observação: Deverá ser utilizado o registro I020 para informação de campos adicionais, conforme instruções do item 1.24.')
        IDENT_NOM        = struct('DataType', 'cell',     'Description', 'Nome do signatário.')
        IDENT_QUALIF     = struct('DataType', 'cell',     'Description', 'Qualificação do assinante, conforme tabela.')
        IE               = struct('DataType', 'cell',     'Description', 'Inscrição Estadual da pessoa jurídica.')
        IM               = struct('DataType', 'cell',     'Description', 'Inscrição Municipal da pessoa jurídica.')
        IND_CENTRALIZADA = struct('DataType', 'cell',     'Description', 'Indicador da modalidade de escrituração centralizada ou descentralizada: 0 – Escrituração Centralizada 1 – Escrituração Descentralizada')
        IND_COD_AGL      = struct('DataType', 'cell',     'Description', 'Indicador do tipo de código de aglutinação das linhas: Observação: Caso o indicador de código de aglutinação seja totalizador (T), o código de aglutinação deve ser informado, mas não deve estar cadastrado no registro I052 – os códigos de aglutinação informados no registro I052 são somente para contas analíticas. T – Totalizador (nível que totaliza um ou mais níveis inferiores da demonstração financeira) D – Detalhe (nível mais detalhado da demonstração financeira')
        IND_CRC          = struct('DataType', 'cell',     'Description', 'Número de inscrição do contabilista no Conselho Regional de Contabilidade.')
        IND_CTA          = struct('DataType', 'cell',     'Description', 'Indicador do tipo de conta: S - Sintética (grupo de contas A - Analítica (conta)')
        IND_DC           = struct('DataType', 'cell',     'Description', 'Indicador da situação do saldo final: D - Devedor; C - Credor.')
      % IND_DC_BAL
      % IND_DC_BAL_INI
      % IND_DC_CTA
        IND_DC_CTA_FIN   = struct('DataType', 'cell',     'Description', 'Indicador da situação do valor final da linha antes do encerramento do exercício: D – Devedor; C – Credor.')
        IND_DC_CTA_INI   = struct('DataType', 'cell',     'Description', 'Indicador da situação do valor final da linha no período imediatamente anterior: D – Devedor; C – Credor.')
        IND_DC_FIN       = struct('DataType', 'cell',     'Description', 'Indicador da situação do saldo final: D - Devedor; C - Credor.')
        IND_DC_FIN_MF    = struct('DataType', 'cell',     'Description', 'Indicador da situação do saldo final em moeda funcional: D - Devedor; C - Credor.')
        IND_DC_INI       = struct('DataType', 'cell',     'Description', 'Indicador da situação do saldo inicial: D - Devedor; C - Credor.')
        IND_DC_INI_MF    = struct('DataType', 'cell',     'Description', 'Indicador da situação do saldo inicial em moeda funcional: D - Devedor; C - Credor.')
        IND_DC_MF        = struct('DataType', 'cell',     'Description', 'Indicador da natureza da partida em moeda funcional: D - Devedor; C - Credor.')
        IND_ESC_CONS     = struct('DataType', 'cell',     'Description', 'Escriturações Contábeis Consolidadas: (Deve ser preenchido pela empresa controladora obrigada a informar demonstrações contábeis consolidadas, nos termos da Lei nº 6.404/76 e/ou do Pronunciamento Técnico CPC 36 – Demonstrações Consolidadas S – Sim N – Não')
        IND_ESC          = struct('DataType', 'cell',     'Description', 'Indicador da forma de escrituração contábil: G – Livro Diário Geral. R – Livro Diário com Escrituração Resumida. B – Livro de Balancetes Diários.')
        IND_FIN_ESC      = struct('DataType', 'cell',     'Description', 'Indicador de finalidade da escrituração: 0 - Original 1 – Substituta')
        IND_GRANDE_PORTE = struct('DataType', 'cell',     'Description', 'Indicador de entidade sujeita a auditoria independente: 0 – Empresa não é entidade sujeita a auditoria independente. 1 – Empresa é entidade sujeita a auditoria independente – Ativo Total superior a R$ 240.000.000,00 ou Receita Bruta Anual superior R$300.000.000,00.')
        IND_GRP_BAL      = struct('DataType', 'cell',     'Description', 'Indicador de grupo do balanço: A – Ativo;P – Passivo e Patrimônio Líquido.')
        IND_GRP_DRE      = struct('DataType', 'cell',     'Description', 'Indicador de grupo da DRE: D – Linha totalizadora ou de detalhe da demonstração que, por sua natureza de despesa, represente redução do lucro. R – Linha totalizadora ou de detalhe da demonstração que, por sua natureza de receita, represente incremento do lucro.')
        IND_LCTO         = struct('DataType', 'cell',     'Description', 'Indicador do tipo de lançamento: N - Lançamento normal (todos os lançamentos, exceto os de encerramento das contas de resultado; E - Lançamento de encerramento de contas de resultado. X – Lançamento extemporâneo.')
        IND_MUDANC_PC    = struct('DataType', 'cell',     'Description', 'Indicador de mudança de plano de contas: 0 – Não houve mudança no plano de contas. 1 – Houve mudança no plano de contas.')
        IND_NIRE         = struct('DataType', 'cell',     'Description', 'Indicador de existência de NIRE:0 – Empresa não possui registro na Junta Comercial (não possui NIRE "1 – Empresa possui registro na Junta Comercial (possui NIRE"')
        IND_RESP_LEGAL   = struct('DataType', 'cell',     'Description', 'Identificação do signatário que será validado como responsável pela assinatura da ECD, conforme atos societários: S – Sim N – Não')
        IND_SIT_ESP      = struct('DataType', 'cell',     'Description', 'Indicador de situação especial (conforme tabela publicada pelo Sped"')
        IND_SIT_INI_PER  = struct('DataType', 'cell',     'Description', 'Indicador de situação no início do período (conforme tabela publicada pelo Sped"')
      % IND_VL
      % IND_VL_ULT_DRE
        LECD             = struct('DataType', 'cell',     'Description', 'Texto fixo contendo “LECD”.')
        NAT_LIVR         = struct('DataType', 'cell',     'Description', 'Natureza do livro; finalidade a que se destina o instrumento.')
        NIRE             = struct('DataType', 'cell',     'Description', 'Número de Identificação do Registro de Empresas da Junta Comercial.')
      % NIRE_SUBST
        NIVEL            = struct('DataType', 'cell',     'Description', 'Nível da conta analítica/grupo de contas.')
        NIVEL_AGL        = struct('DataType', 'cell',     'Description', 'Nível do Código de aglutinação (mesmo conceito do plano de contas – Registro I050')
        NOME             = struct('DataType', 'cell',     'Description', 'Nome empresarial da pessoa jurídica.')
      % NOME_AUDITOR
        NOTA_EXP_REF     = struct('DataType', 'cell',     'Description', 'Referência a numeração das notas explicativas relativas às demonstrações contábeis.')
        NU_ORDEM         = struct('DataType', 'double',   'Description', 'Número de ordem da linha na visualização da demonstração. Ordem de apresentação da linha na visualização do registro J150.')
        NUM_AD           = struct('DataType', 'double',   'Description', 'Número sequencial do campo adicional.')
        NUM_ARQ          = struct('DataType', 'cell',     'Description', 'Número, Código ou caminho de localização dos documentos arquivados.')
        NUM_LCTO         = struct('DataType', 'cell',     'Description', 'Número ou Código de identificação único do lançamento contábil.')
        NUM_ORD          = struct('DataType', 'double',   'Description', 'Número de ordem do instrumento de escrituração.')
        NUM_SEQ_CRC      = struct('DataType', 'cell',     'Description', 'Número da Certidão de Regularidade Profissional do Contador no seguinte formato: UF/ano/número')
        QTD_LIN          = struct('DataType', 'double',   'Description', 'Quantidade total de linhas do arquivo digital.')
        REG              = struct('DataType', 'cell',     'Description', 'Texto fixo contendo a indicação do Registro da tabela, Ex: 000, I030, I050, etc.')
        REG_COD          = struct('DataType', 'cell',     'Description', 'Código do registro que recepciona o campo adicional.')
        TIP_ECD          = struct('DataType', 'double',   'Description', 'Indicador do tipo de ECD: 0 – ECD de empresa não participante de SCP como sócio ostensivo. 1 – ECD de empresa participante de SCP como sócio ostensivo. 2 – ECD da SCP.')
        TIPO             = struct('DataType', 'cell',     'Description', 'Indicação do tipo de dado (N: numérico; C: caractere). N: numérico - campos adicionais que conterão informações de valores em espécie (moeda), com duas decimais.')
        UF               = struct('DataType', 'cell',     'Description', 'Sigla da unidade da federação da pessoa jurídica.')
        UF_CRC           = struct('DataType', 'cell',     'Description', 'Indicação da unidade da federação que expediu o CRC.')
        VAL_CRED_MF      = struct('DataType', 'double',   'Description', 'Total dos créditos do dia em moeda funcional, convertido para reais.')
        VAL_DEBD         = struct('DataType', 'double',   'Description', 'Total dos débitos do dia.')
        VAL_DEB_MF       = struct('DataType', 'double',   'Description', 'Total dos débitos do dia em moeda funcional, convertido para reais.')
        VL_CRED          = struct('DataType', 'double',   'Description', 'Valor total dos créditos do período.')
        VAL_CREDD        = struct('DataType', 'double',   'Description', 'Total dos créditos do dia.')
        VL_CRED_MF       = struct('DataType', 'double',   'Description', 'Valor total dos créditos do período em moeda funcional, convertido para reais.')
        VL_CTA           = struct('DataType', 'double',   'Description', 'Valor do saldo final antes do lançamento de encerramento.')
        VL_CTA_FIN       = struct('DataType', 'double',   'Description', 'Valor final do código de aglutinação no Balanço Patrimonial no exercício informado, ou de período definido em norma específica.')
        VL_CTA_INI       = struct('DataType', 'double',   'Description', 'Valor inicial do código de aglutinação no Balanço Patrimonial no exercício informado, ou de período definido em norma específica.')
        VL_CTA_INI_      = struct('DataType', 'double',   'Description', 'Valor do saldo final da linha no período imediatamente anterior (saldo final da DRE anterior')
        VL_CTA_MF        = struct('DataType', 'double',   'Description', 'Valor do saldo final antes do lançamento de encerramento em moeda funcional, convertido para reais')
      % VL_CTA_ULT_DRE
        VL_DC            = struct('DataType', 'double',   'Description', 'Valor da partida.')
        VL_DC_MF         = struct('DataType', 'double',   'Description', 'Valor da partida em moeda funcional, convertido para reais.')
        VL_DEB           = struct('DataType', 'double',   'Description', 'Valor total dos débitos do período.')
        VL_DEB_MF        = struct('DataType', 'double',   'Description', 'Total dos débitos do dia em moeda funcional, convertido para reais.')
        VL_LCTO          = struct('DataType', 'double',   'Description', 'Valor do lançamento.')
        VL_LCTO_MF       = struct('DataType', 'double',   'Description', 'Valor do lançamento em moeda funcional, convertido para reais.')
        VL_SLD_FIN       = struct('DataType', 'double',   'Description', 'Valor do saldo final do período.')
        VL_SLD_FIN_MF    = struct('DataType', 'double',   'Description', 'Valor do saldo final do período em moeda funcional, convertido para reais.')
        VL_SLD_INI       = struct('DataType', 'double',   'Description', 'Valor do saldo inicial do período.')
        VL_SLD_INI_MF    = struct('DataType', 'double',   'Description', 'Valor do saldo inicial do período em moeda funcional, convertido para reais.')
    end


    methods (Static = true)
        %-------------------------------------------------------%
        % PATH
        %-------------------------------------------------------%
        function MFilePath = path()
            MFilePath = fileparts(mfilename('fullpath'));
        end

        %-------------------------------------------------------%
        % TABELAS IMPLEMENTADAS
        %-------------------------------------------------------%
        function implTable = checkImplementedTables()
            tempObj        = struct(model.ECDBase());
            tempObjFields  = fields(tempObj);

            listOfTables   = tempObjFields(startsWith(tempObjFields, 'x'));
            implTable      = tempObjFields(cellfun(@(x) ~isempty(tempObj.(x)), listOfTables));
            implTable      = extractAfter(implTable, 'x');
        end

        %-------------------------------------------------------%
        % MAPEAMENTO TABELAS X CAMPOS
        %-------------------------------------------------------%
        function [status, missingFields, notImplTables] = validateFieldMapping()
            tempObj        = struct(model.ECDBase());
            tempObjFields  = fields(tempObj);
            listOfTables   = tempObjFields(startsWith(tempObjFields, 'x'));
            implTable      = tempObjFields(cellfun(@(x) ~isempty(tempObj.(x)), listOfTables));
            notImplTables  = setdiff(listOfTables, implTable);            
            listOfFields   = setdiff(tempObjFields, listOfTables);

            requiredFields = {};
            for ii = 1:numel(implTable)
                specificTableFields = tempObj.(implTable{ii})(:, 2:3);
                requiredFields      = [requiredFields, horzcat(specificTableFields{:})];
            end
            requiredFields = unique(requiredFields)';

            statusFields   = ismember(requiredFields, listOfFields);
            if all(statusFields)
                status = true;
                missingFields = {};
            else
                status = false;
                missingFields = requiredFields(~statusFields);
            end
        end
    end
end