classdef ECDBase < handle

    properties
        InfoPerFile = struct('FileName', {}, 'FileFullName', {}, 'Content', {}, 'Layout', {}, 'Table', {})
    end

    properties (Access = private)

        CAB_DEM =           struct('DataType', 'cell', 'Description', 'Cabeçalho das demonstrações.')
        CCUS =              struct('DataType', 'cell', 'Description', 'Nome do centro de custos.')
        CNPJ =              struct('DataType', 'cell', 'Description', 'Número de inscrição da pessoa jurídica no CNPJ.Observação: Esse CNPJ é sempre da Sócia Ostensiva, no caso do arquivo da SCP.')
        COD_AGL =           struct('DataType', 'cell', 'Description', 'Código de aglutinação das linhas, atribuído pela pessoa jurídica.')
        COD_AGL_SUP =       struct('DataType', 'cell', 'Description', 'Código de aglutinação sintético/grupo de código de aglutinação de nível superior.')
        COD_ASSIN =         struct('DataType', 'cell', 'Description', 'Código de qualificação do assinante, conforme tabela.')
        COD_CCUS =          struct('DataType', 'cell', 'Description', 'Código do centro de custos do plano de contas anterior.')
        COD_CTA =           struct('DataType', 'cell', 'Description', 'Código da conta analítica.')
        COD_CTA_SUP =       struct('DataType', 'cell', 'Description', 'Código da conta sintética /grupo de contas de nível imediatamente superior.')
        COD_HASH_SUB =      struct('DataType', 'cell', 'Description', 'Hash da escrituração substituída.')
        COD_HIST_PAD =      struct('DataType', 'cell', 'Description', 'Código do histórico padronizado, conforme tabela I075.')
        COD_MUN =           struct('DataType', 'cell', 'Description', 'Código do município do domicílio fiscal da pessoa jurídica, conforme tabela do IBGE – Instituto Brasileiro de Geografia e Estatística.')
        COD_NAT =           struct('DataType', 'cell', 'Description', 'Código da natureza da conta/grupo de contas, conforme tabela publicada pelo Sped.')
        COD_PART =          struct('DataType', 'cell', 'Description', 'Código de identificação do participante na partida conforme tabela 0150 (preencher somente quando identificado o tipo de participação no registro 0180')
        COD_PLAN_REF =      struct('DataType', 'cell', 'Description', 'Código do Plano de Contas Referencial que será utilizado para o mapeamento de todas as contas analíticas: 1 – PJ em Geral – Lucro Real 2 – PJ em Geral – Lucro Presumido 3 – Financeiras – Lucro Real 4 – Seguradoras – Lucro Real 5 – Imunes e Isentas em Geral 6 – Imunes e Isentas – Financeiras 7 – Imunes e Isentas – Seguradoras 8 – Entidades Fechadas de Previdência Complementar 9 – Partidos Políticos 10 – Financeiras – Lucro Presumido Observação: Caso a pessoa jurídica não realize o mapeamento para os planos referenciais na ECD, este campo deve ficar em branco.')
        COD_SCP =           struct('DataType', 'cell', 'Description', 'CNPJ da SCP (Anexo I, XVIII, da IN RFB nº 2.119, de 06 de dezembro de 2022 Observação: Só deve ser preenchido pela própria SCP com o CNPJ da SCP (Não é preenchido pelo sócio ostensivo"')
        COD_VER_LC =        struct('DataType', 'double', 'Description', 'Código da versão do leiaute')
        CTA =               struct('DataType', 'cell', 'Description', 'Nome da conta analítica/grupo de contas.')
        DESC_MUN =          struct('DataType', 'cell', 'Description', ' Município.')
        DESCR_COD_AGL =     struct('DataType', 'cell', 'Description', 'Descrição do Código de aglutinação.')
        DNRC_ABERT =        struct('DataType', 'cell', 'Description', 'Texto fixo contendo “TERMO DE ABERTURA”.')
        DT_ALT =            struct('DataType', 'datetime', 'Description', 'Data da inclusão/alteração.')
        DT_ARQ =            struct('DataType', 'datetime', 'Description', 'Data do arquivamento dos atos constitutivos.')
        DT_ARQ_CONV =       struct('DataType', 'datetime', 'Description', 'Data de arquivamento do ato de conversão de sociedade simples em sociedade empresária.')
        DT_CRC =            struct('DataType', 'datetime', 'Description', 'Data de validade da Certidão de Regularidade Profissional do Contador')
        DT_EX_SOCIAL =      struct('DataType', 'datetime', 'Description', ' Data de encerramento do exercício social.')
        DT_FIN =            struct('DataType', 'datetime', 'Description', 'Data final das demonstrações contábeis.')
        DT_INI =            struct('DataType', 'datetime', 'Description', 'Data inicial das demonstrações contábeis. Observação: A data inicial das demonstrações deve ser a data posterior ao último encerramento do exercício, mesmo que essa data não esteja no período da ECD transmitida. Exemplo: Data do Último Encerramento do Exercício: 31/12/2022 Data Inicial das Demonstrações Contábeis: 01/01/2023')
        DT_LCTO =           struct('DataType', 'datetime', 'Description', 'Data do lançamento.')
        DT_LCTO_EXT =       struct('DataType', 'datetime', 'Description', 'Data de ocorrência dos fatos objeto do lançamento extemporâneo. Observação: Caso não seja possível precisar a data a que se refiram os fatos do lançamento extemporâneo, informar a data de encerramento do exercício em que ocorreram esses fatos.')
        DT_RES =            struct('DataType', 'datetime', 'Description', 'Data da apuração do resultado.')
        EMAIL =             struct('DataType', 'cell', 'Description', 'Email do signatário.')
        FONE =              struct('DataType', 'cell', 'Description', 'Telefone do signatário.')
        HIST =              struct('DataType', 'cell', 'Description', 'Histórico completo da partida ou histórico complementar. Observação: Caso o lançamento seja do tipo “X” – lançamento extemporâneo - em qualquer das formas de retificação, o histórico do lançamento extemporâneo deve especificar o motivo da correção, a data e o número do lançamento de origem (item 32 do ITG 2000 (R1)')
        ID_DEM =            struct('DataType', 'cell', 'Description', 'Identificação das demonstrações: 1 – demonstrações contábeis da pessoa jurídica a que se refere a escrituração (inclusive Matrix/Filiais); 2 – demonstrações consolidadas ou de outras pessoas jurídicas.')
        IDENT_CPF_CNPJ =    struct('DataType', 'cell', 'Description', 'CPF ou CNPJ')
        IDENT_MF =          struct('DataType', 'cell', 'Description', 'Identificação de moeda funcional: Indica que a escrituração abrange valores com base na moeda funcional (art. 287 da Instrução Normativa RFB nº 1.700, de 14 de março de 2017 Observação: Deverá ser utilizado o registro I020 para informação de campos adicionais, conforme instruções do item 1.24.')
        IDENT_NOM =         struct('DataType', 'cell', 'Description', 'Nome do signatário.')
        IDENT_QUALIF =      struct('DataType', 'cell', 'Description', 'Qualificação do assinante, conforme tabela.')
        IE =                struct('DataType', 'cell', 'Description', 'Inscrição Estadual da pessoa jurídica.')
        IM =                struct('DataType', 'cell', 'Description', 'Inscrição Municipal da pessoa jurídica.')
        IND_CENTRALIZADA =  struct('DataType', 'cell', 'Description', 'Indicador da modalidade de escrituração centralizada ou descentralizada: 0 – Escrituração Centralizada 1 – Escrituração Descentralizada')
        IND_COD_AGL =       struct('DataType', 'cell', 'Description', 'Indicador do tipo de código de aglutinação das linhas: Observação: Caso o indicador de código de aglutinação seja totalizador (T), o código de aglutinação deve ser informado, mas não deve estar cadastrado no registro I052 – os códigos de aglutinação informados no registro I052 são somente para contas analíticas. T – Totalizador (nível que totaliza um ou mais níveis inferiores da demonstração financeira) D – Detalhe (nível mais detalhado da demonstração financeira')
        IND_CRC =           struct('DataType', 'cell', 'Description', 'Número de inscrição do contabilista no Conselho Regional de Contabilidade.')
        IND_CTA =           struct('DataType', 'cell', 'Description', 'Indicador do tipo de conta: S - Sintética (grupo de contas A - Analítica (conta)')
        IND_DC =            struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo final: D - Devedor; C - Credor.')
        IND_DC_CTA_FIN =    struct('DataType', 'cell', 'Description', 'Indicador da situação do valor final da linha antes do encerramento do exercício: D – Devedor; C – Credor.')
        IND_DC_CTA_INI =    struct('DataType', 'cell', 'Description', 'Indicador da situação do valor final da linha no período imediatamente anterior: D – Devedor; C – Credor.')
        IND_DC_FIN =        struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo final: D - Devedor; C - Credor.')
        IND_DC_INI =        struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo inicial: D - Devedor; C - Credor.')
        IND_DC_INI_MF     = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo inicial em moeda funcional: D - Devedor; C - Credor.')
        IND_ESC_CONS =      struct('DataType', 'cell', 'Description', 'Escriturações Contábeis Consolidadas: (Deve ser preenchido pela empresa controladora obrigada a informar demonstrações contábeis consolidadas, nos termos da Lei nº 6.404/76 e/ou do Pronunciamento Técnico CPC 36 – Demonstrações Consolidadas S – Sim N – Não')
        IND_ESC      =      struct('DataType', 'cell', 'Description', 'Indicador da forma de escrituração contábil: G – Livro Diário Geral. R – Livro Diário com Escrituração Resumida. B – Livro de Balancetes Diários.')
        IND_FIN_ESC =       struct('DataType', 'cell', 'Description', 'Indicador de finalidade da escrituração: 0 - Original 1 – Substituta')
        IND_GRANDE_PORTE =  struct('DataType', 'cell', 'Description', 'Indicador de entidade sujeita a auditoria independente: 0 – Empresa não é entidade sujeita a auditoria independente. 1 – Empresa é entidade sujeita a auditoria independente – Ativo Total superior a R$ 240.000.000,00 ou Receita Bruta Anual superior R$300.000.000,00.')
        IND_GRP_BAL =       struct('DataType', 'cell', 'Description', 'Indicador de grupo do balanço: A – Ativo;P – Passivo e Patrimônio Líquido.')
        IND_GRP_DRE =       struct('DataType', 'cell', 'Description', 'Indicador de grupo da DRE: D – Linha totalizadora ou de detalhe da demonstração que, por sua natureza de despesa, represente redução do lucro. R – Linha totalizadora ou de detalhe da demonstração que, por sua natureza de receita, represente incremento do lucro.')
        IND_LCTO =          struct('DataType', 'cell', 'Description', 'Indicador do tipo de lançamento: N - Lançamento normal (todos os lançamentos, exceto os de encerramento das contas de resultado; E - Lançamento de encerramento de contas de resultado. X – Lançamento extemporâneo.')
        IND_MUDANC_PC =     struct('DataType', 'cell', 'Description', 'Indicador de mudança de plano de contas: 0 – Não houve mudança no plano de contas. 1 – Houve mudança no plano de contas.')
        IND_NIRE =          struct('DataType', 'cell', 'Description', 'Indicador de existência de NIRE:0 – Empresa não possui registro na Junta Comercial (não possui NIRE "1 – Empresa possui registro na Junta Comercial (possui NIRE"')
        IND_RESP_LEGAL =    struct('DataType', 'cell', 'Description', 'Identificação do signatário que será validado como responsável pela assinatura da ECD, conforme atos societários: S – Sim N – Não')
        IND_SIT_ESP =       struct('DataType', 'cell', 'Description', 'Indicador de situação especial (conforme tabela publicada pelo Sped"')
        IND_SIT_INI_PER =   struct('DataType', 'cell', 'Description', 'Indicador de situação no início do período (conforme tabela publicada pelo Sped"')
        LECD =              struct('DataType', 'cell', 'Description', 'Texto fixo contendo “LECD”.')
        NAT_LIVR =          struct('DataType', 'cell', 'Description', 'Natureza do livro; finalidade a que se destina o instrumento.')
        NIRE =              struct('DataType', 'cell', 'Description', 'Número de Identificação do Registro de Empresas da Junta Comercial.')
        NIVEL =             struct('DataType', 'cell', 'Description', 'Nível da conta analítica/grupo de contas.')
        NIVEL_AGL =         struct('DataType', 'cell', 'Description', 'Nível do Código de aglutinação (mesmo conceito do plano de contas – Registro I050')
        NOME =              struct('DataType', 'cell', 'Description', 'Nome empresarial da pessoa jurídica.')
        NOTA_EXP_REF =      struct('DataType', 'cell', 'Description', 'Referência a numeração das notas explicativas relativas às demonstrações contábeis.')
        NU_ORDEM =          struct('DataType', 'double', 'Description', 'Número de ordem da linha na visualização da demonstração. Ordem de apresentação da linha na visualização do registro J150.')
        NUM_ARQ =           struct('DataType', 'cell', 'Description', 'Número, Código ou caminho de localização dos documentos arquivados.')
        NUM_LCTO =          struct('DataType', 'cell', 'Description', 'Número ou Código de identificação único do lançamento contábil.')
        NUM_ORD =           struct('DataType', 'double', 'Description', 'Número de ordem do instrumento de escrituração.')
        NUM_SEQ_CRC =       struct('DataType', 'cell', 'Description', 'Número da Certidão de Regularidade Profissional do Contador no seguinte formato: UF/ano/número')
        QTD_LIN =           struct('DataType', 'double', 'Description', 'Quantidade total de linhas do arquivo digital.')
        REG =               struct('DataType', 'cell', 'Description', 'Texto fixo contendo a indicação do Registro da tabela, Ex: 000, I030, I050, etc.')
        TIP_ECD =           struct('DataType', 'double', 'Description', 'Indicador do tipo de ECD: 0 – ECD de empresa não participante de SCP como sócio ostensivo. 1 – ECD de empresa participante de SCP como sócio ostensivo. 2 – ECD da SCP.')
        UF =                struct('DataType', 'cell', 'Description', 'Sigla da unidade da federação da pessoa jurídica.')
        UF_CRC =            struct('DataType', 'cell', 'Description', 'Indicação da unidade da federação que expediu o CRC.')
        VL_CRED =           struct('DataType', 'double', 'Description', 'Valor total dos créditos do período.')
        VL_CTA =            struct('DataType', 'cell', 'Description', 'Valor do saldo final antes do lançamento de encerramento.')
        VL_CTA_FIN =        struct('DataType', 'double', 'Description', 'Valor final do código de aglutinação no Balanço Patrimonial no exercício informado, ou de período definido em norma específica.')
        VL_CTA_INI =        struct('DataType', 'double', 'Description', 'Valor inicial do código de aglutinação no Balanço Patrimonial no exercício informado, ou de período definido em norma específica.')
        VL_CTA_INI_ =       struct('DataType', 'double', 'Description', 'Valor do saldo final da linha no período imediatamente anterior (saldo final da DRE anterior')
        VL_DC =             struct('DataType', 'double', 'Description', 'Valor da partida.')
        VL_DEB =            struct('DataType', 'double', 'Description', 'Valor total dos débitos do período.')
        VL_LCTO =           struct('DataType', 'double', 'Description', 'Valor do lançamento.')
        VL_SLD_FIN =        struct('DataType', 'cell', 'Description', 'Valor do saldo final do período.')
        VL_SLD_INI =        struct('DataType', 'cell', 'Description', 'Valor do saldo inicial do período.')
        VL_SLD_INI_MF =     struct('DataType', 'double', 'Description', 'Valor do saldo inicial do período em moeda funcional, convertido para reais.')


    end


    properties (Access = private)
        %-------------------------------------------------------%
        % TABELAS SOB ANÁLISE
        %-------------------------------------------------------%

        x0000 = {1,       {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP'}; ...
            2,       {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC'}; ...
            3,       {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'NIRE_SUBST', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP'}; ...
            4        {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'NIRE_SUBST', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF'}; ...
            5:7,     {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF', 'IND_ESC_CONS'}; ...
            8:9,     {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF', 'IND_ESC_CONS', 'IND_CENTRALIZADA', 'IND_MUDANC_PC', 'COD_PLAN_REF'}}

        xI010  = {1:9,    {'REG', 'IND_ESC', 'COD_VER_LC'}}

        xI030 =  {1,      {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN'}; ...
            2,       {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN', 'DT_EX_SOCIAL', 'NOME_AUDITOR', 'COD_CVM_AUDITOR'}; ...
            3:9,     {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN', 'DT_EX_SOCIAL'}}

        xI050 =  {1:9,    {'REG', 'DT_ALT', 'COD_NAT', 'IND_CTA', 'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}}

        xI100 =  {1:9,    {'REG', 'DT_ALT', 'COD_CCUS', 'CCUS'}}

        xI150 =  {1:9,    {'REG', 'DT_INI', 'DT_FIN'}}

        xI155 =  {1:9,    {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI', 'VL_DEB', 'VL_CRED', 'VL_SLD_FIN', 'IND_DC_FIN'}}

        xI157 =  {1,      {}; ...
            2:4,     {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI'}; ...
            5:9,     {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI', 'VL_SLD_INI_MF', 'IND_DC_INI_MF'}}

        xI200 =  {1:6,    {'REG', 'NUM_LCTO', 'DT_LCTO', 'VL_LCTO', 'IND_LCTO'}; ...
            7:9,     {'REG', 'NUM_LCTO', 'DT_LCTO', 'VL_LCTO', 'IND_LCTO', 'DT_LCTO_EXT'}}

        xI250 =  {1:9,    {'REG', 'COD_CTA', 'COD_CCUS', 'VL_DC', 'IND_DC', 'NUM_ARQ', 'COD_HIST_PAD', 'HIST', 'COD_PART'}}

        xI350 =  {1:9,    {'REG', 'DT_RES'}}

        xI355 =  {1:9,    {'REG', 'COD_CTA', 'COD_CCUS', 'VL_CTA', 'IND_DC'}}

        xJ005 =  {1:9,    {'REG', 'DT_INI', 'DT_FIN', 'ID_DEM', 'CAB_DEM'}}

        xJ100 =  {1,      {'REG', 'COD_AGL', 'NIVEL_AGL', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_BAL'}; ...
            2:5,     {'REG', 'COD_AGL', 'NIVEL_AGL', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_BAL', 'VL_CTA_INI', 'IND_DC_BAL_INI'}; ...
            6,       {'REG', 'COD_AGL', 'NIVEL_AGL', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_BAL', 'VL_CTA_INI', 'IND_DC_BAL_INI', 'NOTA_EXP_REF'}; ...
            7:9,     {'REG', 'COD_AGL', 'IND_COD_AGL', 'NIVEL_AGL', 'COD_AGL_SUP', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA_INI', 'IND_DC_CTA_INI', 'VL_CTA_FIN', 'IND_DC_CTA_FIN', 'NOTA_EXP_REF'}}

        xJ150 =  {1:3,    {'REG', 'COD_AGL', 'NIVEL_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_VL'}; ...
            4:5,     {'REG', 'COD_AGL', 'NIVEL_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_VL', 'VL_CTA_ULT_DRE', 'IND_VL_ULT_DRE'}; ...
            6,       {'REG', 'COD_AGL', 'NIVEL_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_VL', 'VL_CTA_ULT_DRE', 'IND_VL_ULT_DRE', 'NOTA_EXP_REF'}; ...
            7,       {'REG', 'COD_AGL', 'IND_COD_AGL', 'NIVEL_AGL', 'COD_AGL_SUP', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_CTA', 'IND_GRP_DRE', 'NOTA_EXP_REF'}; ...
            8:9,     {'REG', 'NU_ORDEM', 'COD_AGL', 'IND_COD_AGL', 'NIVEL_AGL', 'COD_AGL_SUP', 'DESCR_COD_AGL', 'VL_CTA_INI_', 'IND_DC_CTA_INI', 'VL_CTA_FIN', 'IND_DC_CTA_FIN', 'IND_GRP_DRE', 'NOTA_EXP_REF'}}

        xJ930 =  {1,      {'REG', 'IDENT_NOM', 'IDENT_CPF', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC'}; ...
            2:4,     {'REG', 'IDENT_NOM', 'IDENT_CPF', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC', 'EMAIL', 'FONE', 'UF_CRC', 'NUM_SEQ_CRC', 'DT_CRC'}; ...
            5:9,     {'REG', 'IDENT_NOM', 'IDENT_CPF_CNPJ', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC', 'EMAIL', 'FONE', 'UF_CRC', 'NUM_SEQ_CRC', 'DT_CRC', 'IND_RESP_LEGAL'}}

    end

    methods
        function obj = ECDBase(fileNameList)
            arguments
                fileNameList cell = {}
            end

            addFiles(obj, fileNameList)
        end

        %-------------------------------------------%
        function addFiles(obj, fileNameList)
            for ii = 1:numel(fileNameList)
                fileFullName = fileNameList{ii};
                [~, fileName, fileExt] = fileparts(fileFullName);
                fileName = [fileName, fileExt];

                if ismember(fileName, {obj.InfoPerFile.FileName})
                    continue
                end

                try
                    fileContent = fileread(fileFullName);
                    table_xI010 = parseTable(obj, 'I010', fileContent);
                    fileLayout  = table_xI010.COD_VER_LC(1);

                    obj.InfoPerFile(end+1) = struct('FileName', fileName, 'FileFullName', fileFullName, 'Content', fileContent, 'Layout', fileLayout, 'Table', struct('xI010', table_xI010));

                catch ME
                    warning('"%s" - %s', fileFullName, ME.message)
                end
            end
        end

        %----------------------------%
        function delFiles(obj, fileNameList)

        end

        %-----------------------------------------------------------%
        function tableOut = parseTable(obj, tableId, fileContent, fileLayout)
            arguments
                obj
                tableId {mustBeMember(tableId,{'0000', 'I010', 'I030', 'I050', 'I100', 'I150','I155','I157','I200','I250', 'I350','I355', 'J005', 'J100', 'J150', 'J930'})}
                fileContent
                fileLayout = 1
            end

            % Identifica a tabela sob análise e a sua estrutura.
            idxLayout    = find(cellfun(@(x) ismember(fileLayout, x), obj.(['x' tableId])(:,1)), 1);
            columnNames  = obj.(['x' tableId]){idxLayout, 2};

            % Busca no conteúdo do arquivo o ID da tabela sob análise.
            regexPattern = ['^\|' tableId '\|[^\r\n]*'];
            regexMatches = regexp(fileContent, regexPattern, 'match', 'lineanchors')';

            if isempty(regexMatches)
                columnTypes = cellfun(@(x) obj.(x).DataType, columnNames, 'UniformOutput', false);
                tableOut = table('Size', [0, numel(columnNames)], 'VariableNames', columnNames, 'VariableTypes', columnTypes);

            else
                % Elimina primeiro e último caractere "|", separa e
                % concatena.
                regexMatchesTransformation1 = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);
                regexMatchesTransformation2 = cellfun(@(x) strsplit(x, '|', 'CollapseDelimiters', false), regexMatchesTransformation1, 'UniformOutput', false);
                regexMatchesTransformation3 = vertcat(regexMatchesTransformation2{:});

                % Converte para tabela...
                tableOut = cell2table(regexMatchesTransformation3, 'VariableNames', columnNames);

                % Aplica mudança do tipo de dado p/ uma coluna específica...
                for ii = 1:numel(columnNames)
                    columnName = columnNames{ii};

                    switch obj.(columnName).DataType
                        case 'double'
                            tableOut.(columnName) = str2double(tableOut.(columnName));
                        case 'datetime'
                            tableOut.(columnName) = datetime(tableOut.(columnName), "InputFormat", "ddMMyyyy");
                    end
                end
            end
        end
    end

    methods
        function parseTableAndAddToCache(obj, tableIdList)
            arguments
                obj
                tableIdList (1,:) cell = {'0000', 'I010', 'I030', 'I050', 'I100', 'I150','I155','I157','I200','I250', 'I350','I355', 'J005', 'J100', 'J150', 'J930'}
            end

            for ii = 1:numel(obj.InfoPerFile)
                for jj = 1:numel(tableIdList)
                    tableId = tableIdList{jj};

                    if ~isfield(obj.InfoPerFile(ii).Table, ['x' tableId])
                        obj.InfoPerFile(ii).Table.(['x' tableId]) = parseTable(obj, tableId, obj.InfoPerFile(ii).Content, obj.InfoPerFile(ii).Layout);
                    end
                end
            end
        end

        %-------------------------------%
        function mergedTable = mergeTable(obj, tableID)
            arguments
                obj
                tableID char {mustBeMember(tableID, {'0000', 'I010', 'I030', 'I050', 'I100', 'I150','I155','I157','I200','I250', 'I350','I355', 'J005', 'J100', 'J150', 'J930'})}
            end

            mergedTable = arrayfun(@(x) x.Table.(['x' tableID]), obj.InfoPerFile, 'UniformOutput', false);
            mergedTable = vertcat(mergedTable{:});
        end

        function leftTable = table_I150_I155_I350_I355(obj)
            arguments
                obj
            end
               
                % table_I150_I155_I350_I355 = {'REG_150',	'DT_INI',	'DT_FIN', 'REG_155', 'COD_CTA_155', 'CTA_155',	'COD_CCUS_155',	'VL_SLD_INI',	'IND_DC_INI',	'VL_DEB',	'VL_CRED',	'VL_SLD_FIN',	'IND_DC_FIN',	'REG_350',	'DT_RES', 'REG_355',	'COD_CTA_355',	'CTA_355', 'COD_CCUS_355',	'VL_CTA',	'IND_DC',	'Mov_I155',	'Mov_I155_I355'};

                table_I150_I155_I350_I355 = table(...
                strings, strings, strings, strings, strings, strings, ...
                strings, strings, strings, strings, strings, strings, ...
                strings, strings, strings, strings, strings, ...
                strings, strings, strings, strings, strings, strings, ...
                'VariableNames',  {'REG_150',	'DT_INI',	'DT_FIN', 'REG_155', 'COD_CTA_155', 'CTA_155',	'COD_CCUS_155',	'VL_SLD_INI',	'IND_DC_INI',	'VL_DEB',	'VL_CRED',	'VL_SLD_FIN',	'IND_DC_FIN',	'REG_350',	'DT_RES', 'REG_355',	'COD_CTA_355',	'CTA_355', 'COD_CCUS_355',	'VL_CTA',	'IND_DC',	'Mov_I155',	'Mov_I155_I355'});

                month_I350 = month(obj.InfoPerFile.Table.xI350.DT_RES);
                Cod_CTA_I155 = unique(obj.InfoPerFile.Table.xI155.COD_CTA, 'stable');
                Cod_CTA_I355_first = Cod_CTA_I155(1);
                month_I150_number_now = 0;
                month_I350_number_now = 0;
                status_I355 = 0;
                pos_I355 = 0;
                incr_month = 1;

                % coincidentes = unique(Cod_CTA_I155(ismember(Cod_CTA_I155, Cod_CTA_I355) 'stable');
                % leftTable  = obj.InfoPerFile.Table.xI155;
                % rightTable = obj.InfoPerFile.Table.xI355;
                % 
                % columnNames_xI155  = leftTable.Properties.VariableNames;
                % columnNames_xI355  = rightTable.Properties.VariableNames;
                % columnInBothTables = intersect(columnNames_xI155, columnNames_xI355);
                % columnReference    = 'COD_CTA';
                % newColumns         = setdiff(columnNames_xI355, columnInBothTables);
                % 
                %  for ii = 1:height(leftTable)
                %      valueReference = leftTable.(columnReference){ii};
                %      idxFind = find(strcmp(rightTable.(columnReference), valueReference), 1);
                % 
                %      if ~isempty(idxFind)
                %          for jj = 1:numel(newColumns)
                %              newColumn = newColumns{jj};
                %              leftTable.(newColumn)(ii) = rightTable.(newColumn)(idxFind);
                %          end
                %      end
                %  end
                % 
                %  testJoin = join(a.InfoPerFile.Table.xI155, a.InfoPerFile.Table.xI050, 'Keys', 'COD_CTA');
                %  testJoin2 = outerjoin(testJoin, a.InfoPerFile.Table.xI150, 'LeftKeys', 'DT_ALT', 'RightKeys', 'DT_INI');
                % 
                %  idx = testJoin2.REG_left == ""; % Encontrar linhas vazias
                %  testJoin2(idx, :) = []; % Remover linhas
                %  disp(testJoin2)
                % 
                %  idx = cellfun(@isempty, testJoin2.REG); % Encontrar linhas com valores vazios
                % testJoin2(idx, :) = []; % Remover linhas vazias
                % disp(testJoin2); % Exibir tabela sem as linhas vazias
                % 
                % [~, idx] = unique(a.InfoPerFile.Table.xJ100.COD_CTA, 'stable'); % Índices das primeiras ocorrências
                % filteredTable = a.InfoPerFile.Table.xJ100(idx, :); % Seleciona as linhas únicas


                for ii = 1: 1:height(obj.InfoPerFile.Table.xI155)
                     if strcmp(Cod_CTA_I355_first, obj.InfoPerFile.Table.xI155.COD_CTA{ii})
                          month_I150_number_now = month_I150_number_now + 1;
                        if month_I150_number_now ==  month_I350(incr_month)
                           status_I355 = 1;
                           pos_I355 = pos_I355 + 1;
                           incr_month = incr_month+1;
                           month_I350_number_now = month_I350_number_now + 1;
                           difOcorr = 0;
                        else
                            status_I355 = 0;
                        end
                     end
                        % Preenche a tabela table_I150_I155_I350_I355 com alterando as datas de I150 até que altere o COD_CTA
                        table_I150_I155_I350_I355.REG_150(ii) = string(obj.InfoPerFile.Table.xI150.REG(month_I150_number_now));
                        table_I150_I155_I350_I355.DT_INI(ii) = datetime((obj.InfoPerFile.Table.xI150.DT_INI(month_I150_number_now)), "InputFormat", "dd/MM/yyyy");
                        table_I150_I155_I350_I355.DT_FIN(ii) = string(obj.InfoPerFile.Table.xI150.DT_FIN(month_I150_number_now));

                        % Preenche a tabela table_I150_I155_I350_I355 com com todos os dados de I155
                    	table_I150_I155_I350_I355.REG_155(ii) = string(obj.InfoPerFile.Table.xI155.REG(ii));
                        table_I150_I155_I350_I355.COD_CTA_155(ii) = string(obj.InfoPerFile.Table.xI155.COD_CTA(ii));
                        table_I150_I155_I350_I355.COD_CCUS_155(ii) = string(obj.InfoPerFile.Table.xI155.COD_CCUS(ii));
                        table_I150_I155_I350_I355.VL_SLD_INI(ii) = string(obj.InfoPerFile.Table.xI155.VL_SLD_INI(ii));
                        table_I150_I155_I350_I355.IND_DC_INI(ii) = string(obj.InfoPerFile.Table.xI155.IND_DC_INI(ii));
                        table_I150_I155_I350_I355.VL_DEB(ii) = str2double(obj.InfoPerFile.Table.xI155.VL_DEB(ii));
                        table_I150_I155_I350_I355.VL_CRED(ii) = string(obj.InfoPerFile.Table.xI155.VL_CRED(ii));
                        table_I150_I155_I350_I355.VL_SLD_FIN(ii) = string(obj.InfoPerFile.Table.xI155.VL_SLD_FIN(ii));
                        table_I150_I155_I350_I355.IND_DC_FIN(ii) = string(obj.InfoPerFile.Table.xI155.IND_DC_FIN(ii));

                        index_COD_CTA = find(strcmp(obj.InfoPerFile.Table.xI050.COD_CTA, obj.InfoPerFile.Table.xI155.COD_CTA{ii}));
                        
                        if ~isempty(index_COD_CTA)
                            table_I150_I155_I350_I355.CTA_155(ii) = obj.InfoPerFile.Table.xI050.CTA(index_COD_CTA(1));
                        end

                        if table_I150_I155_I350_I355.IND_DC_INI(ii) == "D"
                            VL_SLD_INI_155 = -abs(str2double(replace(table_I150_I155_I350_I355.VL_SLD_INI(ii), ",", ".")));
                        else
                            VL_SLD_INI_155 = str2double(replace(table_I150_I155_I350_I355.VL_SLD_INI(ii), ",", "."));
                        end
                        if table_I150_I155_I350_I355.IND_DC_FIN(ii) == "D"
                            VL_SLD_FIN_155 = -abs(str2double(replace(table_I150_I155_I350_I355.VL_SLD_FIN(ii), ",", ".")));
                        else
                            VL_SLD_FIN_155 = str2double(replace(table_I150_I155_I350_I355.VL_SLD_FIN(ii), ",", ".")); 
                        end

                        table_I150_I155_I350_I355.Mov_I155(ii) = VL_SLD_FIN_155 - VL_SLD_INI_155;
                        table_I150_I155_I350_I355.Mov_I155_I355(ii) = table_I150_I155_I350_I355.Mov_I155(ii);

                        table_I150_I155_I350_I355.REG_350(ii) = "";
                        table_I150_I155_I350_I355.DT_RES(ii) = "";  

                        table_I150_I155_I350_I355.REG_355(ii) = "";
                        table_I150_I155_I350_I355.COD_CTA_355(ii) = "";
                        table_I150_I155_I350_I355.COD_CCUS_355(ii) = "";
                        table_I150_I155_I350_I355.VL_CTA(ii) = "";
                        table_I150_I155_I350_I355.IND_DC(ii) = "";
                        table_I150_I155_I350_I355.CTA_355(ii) = "";


                        if status_I355 ==1
                             index_CTA = find(strcmp(obj.InfoPerFile.Table.xI355.COD_CTA, obj.InfoPerFile.Table.xI155.COD_CTA{ii}));

                             if ~isempty(index_CTA)
                                 if pos_I355 >1
                                     numOcorr = find(strcmp(table_I150_I155_I350_I355.COD_CTA_355, obj.InfoPerFile.Table.xI155.COD_CTA{ii}));
                                     difOcorr = pos_I355 - numel(numOcorr)-1;
                                 end
                                    
                                    table_I150_I155_I350_I355.REG_350(ii) = string(obj.InfoPerFile.Table.xI350.REG(month_I350_number_now));
                                    table_I150_I155_I350_I355.DT_RES(ii) = string(obj.InfoPerFile.Table.xI350.DT_RES(month_I350_number_now));   
    
                                    table_I150_I155_I350_I355.REG_355(ii) = string(obj.InfoPerFile.Table.xI355.REG(index_CTA(pos_I355-difOcorr)));
                                    table_I150_I155_I350_I355.COD_CTA_355(ii) = string(obj.InfoPerFile.Table.xI355.COD_CTA(index_CTA(pos_I355-difOcorr)));
                                    table_I150_I155_I350_I355.COD_CCUS_355(ii) =string(obj.InfoPerFile.Table.xI355.COD_CCUS(index_CTA(pos_I355-difOcorr)));
                                    table_I150_I155_I350_I355.VL_CTA(ii) = string(obj.InfoPerFile.Table.xI355.VL_CTA(index_CTA(pos_I355-difOcorr)));
                                    table_I150_I155_I350_I355.IND_DC(ii) = string(obj.InfoPerFile.Table.xI355.IND_DC(index_CTA(pos_I355-difOcorr)));

                                    if ~isempty(index_COD_CTA)
                                        table_I150_I155_I350_I355.CTA_355(ii) = table_I150_I155_I350_I355.CTA_155(ii);
                                    end
                                    

                                    if table_I150_I155_I350_I355.IND_DC(ii) == "D"
                                        VL_CTA_355 = -abs(str2double(replace(table_I150_I155_I350_I355.VL_CTA(ii), ",", "."))); 
                                    else
                                        VL_CTA_355 = str2double(replace(table_I150_I155_I350_I355.VL_CTA(ii), ",", ".")); 
                                    end

                                    table_I150_I155_I350_I355.Mov_I155_I355(ii) = str2double(table_I150_I155_I350_I355.Mov_I155(ii)) + VL_CTA_355; 
    
                            end
                        end                
                end

                leftTable = table_I150_I155_I350_I355;
          
                % table_I155_I355 = innerjoin(obj.InfoPerFile.Table.xI355, obj.InfoPerFile.Table.xI155, 'Keys', 'COD_CTA');

                writetable(table_I150_I155_I350_I355, 'C:\Users\leandrohz\OneDrive - ANATEL\Área de Trabalho\table_I150_I155_I350_I355.xlsx');
        end
    function tableDinamica = tableDinamica_I150_I155_I350_I355(obj, leftTable)
            arguments
                obj
                leftTable;
            end

                tableDinamica_I150_I155_I350_I355 = table(...
                strings, strings, strings, strings, strings, ...
                strings, strings, strings, strings, strings, ...
                strings, strings, strings, strings, ...
                'VariableNames',  {'COD_CTA'	'MES01',	'MES02',	'MES03',	'MES04',	'MES05',	'MES06',	'MES07',	'MES08',	'MES09',	'MES10',	'MES11',	'MES12',	'MesTotal_Geral'});

                Cod_CTA_I155_Din = unique(leftTable.COD_CTA_155, 'stable');

                for ii = 1: 1:height(Cod_CTA_I155_Din)
                     index_COD_CTA_Din = find(strcmp(leftTable.COD_CTA_155, Cod_CTA_I155_Din{ii}));
                     kk = 1;
                     Val_Mes = [];
                     Valor_Total_Mes = 0;
                     for jj = 1:12
                         month_list = month(leftTable.DT_INI(index_COD_CTA_Din));
                         if kk <= numel(month_list)
                             if month_list(kk) == jj
                                 Val_Mes(jj) = str2double(replace(leftTable.Mov_I155_I355(index_COD_CTA_Din(kk)),",","."));
                                 kk = kk + 1;
                             else
                                 Val_Mes(jj) = "0";
                             end
                         else
                             Val_Mes(jj) = "0";
                         end
                     end
                     Valor_Total_Mes = sum(Val_Mes);

                     tableDinamica_I150_I155_I350_I355.COD_CTA(ii) = Cod_CTA_I155_Din(ii); 
                     tableDinamica_I150_I155_I350_I355.MES01(ii) = Val_Mes(1);
                     tableDinamica_I150_I155_I350_I355.MES02(ii) = Val_Mes(2);
                     tableDinamica_I150_I155_I350_I355.MES03(ii) = Val_Mes(3);
                     tableDinamica_I150_I155_I350_I355.MES04(ii) = Val_Mes(4);
                     tableDinamica_I150_I155_I350_I355.MES05(ii) = Val_Mes(5);
                     tableDinamica_I150_I155_I350_I355.MES06(ii) = Val_Mes(6);
                     tableDinamica_I150_I155_I350_I355.MES07(ii) = Val_Mes(7);
                     tableDinamica_I150_I155_I350_I355.MES08(ii) = Val_Mes(8);
                     tableDinamica_I150_I155_I350_I355.MES09(ii) = Val_Mes(9);
                     tableDinamica_I150_I155_I350_I355.MES10(ii) = Val_Mes(10);
                     tableDinamica_I150_I155_I350_I355.MES11(ii) = Val_Mes(11);
                     tableDinamica_I150_I155_I350_I355.MES12(ii) = Val_Mes(12);
                     tableDinamica_I150_I155_I350_I355.MesTotal_Geral(ii) = Valor_Total_Mes;

                end

                tableDinamica = tableDinamica_I150_I155_I350_I355;
          
                % table_I155_I355 = innerjoin(obj.InfoPerFile.Table.xI355, obj.InfoPerFile.Table.xI155, 'Keys', 'COD_CTA');

                writetable(tableDinamica_I150_I155_I350_I355, 'C:\Users\leandrohz\OneDrive - ANATEL\Área de Trabalho\tableDinamica_I150_I155_I350_I355.xlsx');
    end

    end
  
end