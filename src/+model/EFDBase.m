classdef (Abstract) EFDBase
    % Cadastro de fichas e dos seus campos, de acordo com os diversos layouts
    % dos arquivos. Na pasta "doc" consta os PDFs descrevendo cada layout,
    % mas outras informações podem ser obtidas em http://sped.rfb.gov.br/

    properties (Constant)
        %-------------------------------------------------------%
        % TABELAS SOB ANÁLISE
        % As tabelas (ou fichas) sob análise são organizadas num cellarray
        % com três colunas, em que a primeira coluna contém um array com a
        % indicação do layout aplicável (1:9, por exemplo), a segunda coluna
        % são os campos obrigatórios da ficha, e a terceira coluna os campos
        % opcionais (ou adicionais).
        %-------------------------------------------------------%

        % Bloco 0: Abertura, Identificação e Referências
        x0000 = {1,   {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP'}, {};
                 2,   {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'NIRE_SUBST', 'IND_EMP_GRD_PRT'}, {};
                 3,   {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'NIRE_SUBST', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP'}, {};
                 4    {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'NIRE_SUBST', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF'}, {};
                 5:7, {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF', 'IND_ESC_CONS'}, {};
                 8:9, {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF', 'IND_ESC_CONS', 'IND_CENTRALIZADA', 'IND_MUDANC_PC', 'COD_PLAN_REF'}, {}}
        x0001 = {1:9, {'REG', 'IND_DAD'}, {}}
        x0007 = {1:9, {'REG', 'COD_ENT_REF', 'COD_INSCR'}, {}}
        x0020 = {1:9, {'REG', 'IND_DEC', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'NIRE'}, {}}
        x0035 = {1:9, {'REG', 'COD_SCP', 'NOME_SCP'}, {}}
        x0150 = {1:9, {'REG', 'COD_PART', 'NOME', 'COD_PAIS', 'CNPJ', 'CPF', 'NIT', 'UF', 'IE', 'IE_ST', 'COD_MUN', 'IM', 'SUFRAMA'}, {}}
        x0180 = {1:9, {'REG', 'COD_REL', 'DT_INI_REL', 'DT_FIN_REL'}, {}}
        x0990 = {1:9, {'REG', 'QTD_LIN_0'}, {}}

        % Bloco C: Informações Recuperadas da Escrituração Contábil Anterior
        xC001 = {1:7, {}, {};
                 8:9, {'REG', 'IND_DAD'}, {}}
        xC040 = {1:7, {}, {};
                 8:9, {'REG', 'HASH_ECD_REC', 'DT_INI_ECD_REC', 'DT_FIN_ECD_REC', 'CNPJ_ECD_REC', 'IND_ESC', 'COD_VER_LC', 'NUM_ORD', 'NAT_LIVR', 'IND_SIT_ESP_ECD_REC', 'IND_NIRE_ECD_REC', 'IND_FIN_ESC_ECD_REC', 'TIP_ECD_REC', 'COD_SCP_ECD_REC', 'IDENT_MF_ECD_REC', 'IND_ESC_CONS_ECD_REC', 'IND_CENTRALIZADA_ECD_REC', 'IND_MUDANCA_PC_ECD_REC', 'IND_PLANO_REF_ECD_REC'}, {}}
        xC050 = {1:7, {}, {};
                 8:9, {'REG', 'DT_ALT', 'COD_NAT', 'IND_CTA', 'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}, {}}
        xC051 = {1:7, {}, {};
                 8:9, {'REG', 'COD_CCUS', 'COD_CTA_REF'}, {}}
        xC052 = {1:7, {}, {};
                 8:9, {'REG', 'COD_CCUS', 'COD_AGL'}, {}}
        xC150 = {1:7, {}, {};
                 8:9, {'REG', 'DT_INI', 'DT_FIN'}, {}}
        xC155 = {1:7, {}, {};
                 8:9, {'REG', 'COD_CTA_REC', 'COD_CCUS_REC', 'VL_SLD_INI_REC', 'IND_DC_INI_REC', 'VL_DEB_REC', 'VL_CRED_REC', 'VL_SLD_FIN_REC', 'IND_DC_FIN_REC'}, {}}
        xC600 = {1:7, {}, {};
                 8:9, {'REG', 'DT_INI', 'DT_FIN', 'ID_DEM', 'CAB_DEM'}, {}}
        xC650 = {1:7, {}, {};
                 8:9, {'REG', 'COD_AGL', 'NIVEL_AGL', 'DESCR_COD_AGL', 'VL_CTA_FIN', 'IND_DC_CTA_FIN'}, {}}
        xC990 = {1:7, {}, {};
                 8:9, {'REG', 'QTD_LIN_0'}, {}}

        % Bloco I: Lançamentos Contábeis
        xI001 = {1:9, {'REG', 'IND_DAD'}, {}}
        xI010 = {1:9, {'REG', 'IND_ESC', 'COD_VER_LC'}, {}}
        xI012 = {1:9, {'REG', 'NUM_ORD', 'NAT_LIVR', 'TIPO', 'COD_HASH_AUX'}, {}}
        xI015 = {1:9, {'REG', 'COD_CTA_RES'}, {}}
        xI020 = {1:9, {'REG', 'REG_COD', 'NUM_AD', 'CAMPO', 'DESCRICAO', 'TIPO'}, {}}
        xI030 = {1,   {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN'}, {};
                 2,   {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN', 'DT_EX_SOCIAL', 'NOME_AUDITOR', 'COD_CVM_AUDITOR'}, {};
                 3:9, {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN', 'DT_EX_SOCIAL'}, {}}
        xI050 = {1:9, {'REG', 'DT_ALT', 'COD_NAT', 'IND_CTA', 'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}, {}}
        xI051 = {1:7, {'REG', 'COD_PLAN_REF', 'COD_CCUS', 'COD_CTA_REF'}, {};
                 8:9, {'REG', 'COD_CCUS', 'COD_CTA_REF'}, {}}
        xI052 = {1:9, {'REG', 'COD_CCUS', 'COD_AGL'}, {}}
        xI053 = {1:9, {'REG', 'COD_IDT', 'COD_CNT_CORR', 'NAT_SUB_CNT'}, {}}
        xI075 = {1:9, {'REG', 'COD_HIST', 'DESCR_HIST'}, {}}
        xI100 = {1:9, {'REG', 'DT_ALT', 'COD_CCUS', 'CCUS'}, {}}
        xI150 = {1:9, {'REG', 'DT_INI', 'DT_FIN'}, {}}
        xI155 = {1:4, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI', 'VL_DEB', 'VL_CRED', 'VL_SLD_FIN', 'IND_DC_FIN'}, {'VL_SLD_INI_AUX', 'IND_DC_INI_AUX', 'VL_DEB_AUX', 'VL_CRED_AUX', 'VL_SLD_FIN_AUX', 'IND_DC_FIN_AUX'};
                 5:8, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI', 'VL_DEB', 'VL_CRED', 'VL_SLD_FIN', 'IND_DC_FIN'}, {'VL_SLD_INI_MF', 'IND_DC_INI_MF', 'VL_DEB_MF', 'VL_CRED_MF', 'VL_SLD_FIN_MF', 'IND_DC_FIN_MF'};
                 9,   {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI', 'VL_DEB', 'VL_CRED', 'VL_SLD_FIN', 'IND_DC_FIN'}, {'VL_SLD_INI_MF', 'IND_DC_INI_MF', 'VL_DEB_MF', 'VL_CRED_MF', 'VL_SLD_FIN_MF', 'IND_DC_FIN_MF'}}       
        xI157 = {1,   {}, {};
                 2:4, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI'}, {'VL_SLD_INI_AUX', 'IND_DC_INI_AUX'};
                 5:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI'}, {'VL_SLD_INI_MF', 'IND_DC_INI_MF'}}        
        xI200 = {1:4, {'REG', 'NUM_LCTO', 'DT_LCTO', 'VL_LCTO', 'IND_LCTO'}, {'VL_LCTO_AUX'};
                 5:6, {'REG', 'NUM_LCTO', 'DT_LCTO', 'VL_LCTO', 'IND_LCTO'}, {'VL_LCTO_MF'};
                 7:9, {'REG', 'NUM_LCTO', 'DT_LCTO', 'VL_LCTO', 'IND_LCTO', 'DT_LCTO_EXT'}, {'VL_LCTO_MF'}}
        xI250 = {1:4, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_DC', 'IND_DC', 'NUM_ARQ', 'COD_HIST_PAD', 'HIST', 'COD_PART'}, {'VL_DC_AUX', 'IND_DC_AUX'};
                 5:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_DC', 'IND_DC', 'NUM_ARQ', 'COD_HIST_PAD', 'HIST', 'COD_PART'}, {'VL_DC_MF', 'IND_DC_MF'}}        
        xI300 = {1:9, {'REG', 'DT_BCTE'}, {}}       
        xI310 = {1:4, {'REG', 'COD_CTA', 'COD_CCUS', 'VAL_DEBD', 'VAL_CREDD'}, {'VAL_DEB_AUX', 'VAL_CRED_AUX'};
                 5:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VAL_DEBD', 'VAL_CREDD'}, {'VAL_DEB_MF', 'VAL_CRED_MF'}}        
        xI350 = {1:9, {'REG', 'DT_RES'}, {}}        
        xI355 = {1:4, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_CTA', 'IND_DC'}, {'VL_CTA_AUX', 'IND_DC_AUX'};
                 5:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_CTA', 'IND_DC'}, {'VL_CTA_MF', 'IND_DC_MF'}}        
        xI500 = {1:9, {'REG', 'TAM_FONTE'}, {}}        
        xI510 = {1:9, {'REG', 'NM_CAMPO', 'DESC_CAMPO', 'TIPO_CAMPO', 'TAM_CAMPO', 'DEC_CAMPO', 'COL_CAMPO'}, {}}        
        xI550 = {1:9, {'REG', 'NM_CAMPO', 'DESC_CAMPO', 'TIPO_CAMPO', 'TAM_CAMPO', 'DEC_CAMPO', 'COL_CAMPO'}, {}}        
        xI555 = {1:9, {'REG', 'NM_CAMPO', 'DESC_CAMPO', 'TIPO_CAMPO', 'TAM_CAMPO', 'DEC_CAMPO', 'COL_CAMPO'}, {}}        
        xI990 = {1:9, {'REG', 'QTD_LIN_I'}, {}}

        % Bloco J: Demonstrações Contábeis
        xJ001 = {1:9, {'REG', 'IND_DAD'}, {}}
        xJ005 = {1:9, {'REG', 'DT_INI', 'DT_FIN', 'ID_DEM', 'CAB_DEM'}, {}}        
        xJ100 = {1,   {'REG', 'COD_AGL', 'NIVEL_AGL', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_BAL'}, {};
                 2:5, {'REG', 'COD_AGL', 'NIVEL_AGL', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_BAL', 'VL_CTA_INI', 'IND_DC_BAL_INI'}, {};
                 6,   {'REG', 'COD_AGL', 'NIVEL_AGL', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_BAL', 'VL_CTA_INI', 'IND_DC_BAL_INI', 'NOTA_EXP_REF'}, {};
                 7:9, {'REG', 'COD_AGL', 'IND_COD_AGL', 'NIVEL_AGL', 'COD_AGL_SUP', 'IND_GRP_BAL', 'DESCR_COD_AGL', 'VL_CTA_INI', 'IND_DC_CTA_INI', 'VL_CTA_FIN', 'IND_DC_CTA_FIN', 'NOTA_EXP_REF'}, {}}
        xJ150 = {1:3, {'REG', 'COD_AGL', 'NIVEL_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_VL'}, {};
                 4:5, {'REG', 'COD_AGL', 'NIVEL_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_VL', 'VL_CTA_ULT_DRE', 'IND_VL_ULT_DRE'}, {};
                 6,   {'REG', 'COD_AGL', 'NIVEL_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_VL', 'VL_CTA_ULT_DRE', 'IND_VL_ULT_DRE', 'NOTA_EXP_REF'}, {};
                 7,   {'REG', 'COD_AGL', 'IND_COD_AGL', 'NIVEL_AGL', 'COD_AGL_SUP', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_CTA', 'IND_GRP_DRE', 'NOTA_EXP_REF'}, {};
                 8:9, {'REG', 'NU_ORDEM', 'COD_AGL', 'IND_COD_AGL', 'NIVEL_AGL', 'COD_AGL_SUP', 'DESCR_COD_AGL', 'VL_CTA_INI_', 'IND_DC_CTA_INI', 'VL_CTA_FIN', 'IND_DC_CTA_FIN', 'IND_GRP_DRE', 'NOTA_EXP_REF'}, {}}
        xJ200 = {1:6, {'REG', 'COD_HIST_FAT', 'DESC_FAT'}, {};
                 7:9, {}, {}}
        xJ210 = {1:5, {'REG', 'IND_TIP', 'COD_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_CTA', 'VL_CTA_INI', 'IND_DC_CTA_INI'}, {};
                 6,   {'REG', 'IND_TIP', 'COD_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_CTA', 'VL_CTA_INI', 'IND_DC_CTA_INI', 'NOTAS_EXP_REF'}, {};
                 7:9, {'REG', 'IND_TIP', 'COD_AGL', 'DESCR_COD_AGL', 'VL_CTA_INI', 'IND_DC_CTA_INI', 'VL_CTA_FIN', 'IND_DC_CTA_FIN', 'NOTAS_EXP_REF'}, {}}
        xJ215 = {1:6, {'REG', 'COD_HIST_FAT', 'VL_FAT_CONT', 'IND_DC_FAT'}, {};
                 7:9, {'REG', 'COD_HIST_FAT', 'DESC_FAT', 'VL_FAT_CONT', 'IND_DC_FAT'}, {}}        
        xJ800 = {1:4, {'REG', 'ARQ_RTF', 'IND_FIM_RTF'}, {};
                 5:9, {'REG', 'TIPO_DOC', 'DESC_RTF', 'HASH_RTF', 'ARQ_RTF', 'IND_FIM_RTF'}, {}}        
        xJ801 = {1:4, {}, {};
                 5:9, {'REG', 'TIPO_DOC', 'DESC_RTF', 'COD_MOT_SUBS', 'HASH_RTF', 'ARQ_RTF', 'IND_FIM_RTF'}, {}}        
        xJ900 = {1:9, {'REG', 'DNRC_ENCER', 'NUM_ORD', 'NAT_LIVRO', 'NOME', 'QTD_LIN', 'DT_INI_ESCR', 'DT_FIN_ESCR'}, {}}        
        xJ930 = {1,   {'REG', 'IDENT_NOM', 'IDENT_CPF', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC'}, {};
                 2:4, {'REG', 'IDENT_NOM', 'IDENT_CPF', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC', 'EMAIL', 'FONE', 'UF_CRC', 'NUM_SEQ_CRC', 'DT_CRC'}, {};
                 5:9, {'REG', 'IDENT_NOM', 'IDENT_CPF_CNPJ', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC', 'EMAIL', 'FONE', 'UF_CRC', 'NUM_SEQ_CRC', 'DT_CRC', 'IND_RESP_LEGAL'}, {}}        
        xJ932 = {1:6, {}, {};
                 7:9, {'REG', 'IDENT_NOM_T', 'IDENT_CPF_CNPJ_T', 'IDENT_QUALIF_T', 'COD_ASSIN_T', 'IND_CRC_T', 'EMAIL_T', 'FONE_T', 'UF_CRC_T', 'NUM_SEQ_CRC_T', 'DT_CRC_T'}, {}}        
        xJ935 = {1:6, {'REG', 'NOME_AUDITOR', 'COD_CVM_AUDITOR'}, {};
                 7:9, {'REG', 'NI_CPF_CNPJ', 'NOME_AUDITOR_FIRMA', 'COD_CVM_AUDITOR'}, {}}        
        xJ990 = {1:9, {'REG', 'QTD_LIN_J'}, {}}

        % Bloco K: Conglomerados Econômicos
        xK001 = {1:4, {}, {};
                 5:9, {'REG', 'IND_DAD'}, {}}        
        xK030 = {1:4, {}, {};
                 5:9, {'REG', 'DT_INI', 'DT_FIN'}, {}}        
        xK100 = {1:4, {}, {};
                 5:9, {'REG', 'COD_PAIS', 'EMP_COD', 'CNPJ', 'NOME', 'PER_PART', 'EVENTO', 'PER_CONS', 'DATA_INI_EMP', 'DATA_FIN_EMP'}, {}}        
        xK110 = {1:4, {}, {};
                 5:9, {'REG', 'EVENTO', 'DT_EVENTO'}, {}}        
        xK115 = {1:4, {}, {};
                 5:9, {'REG', 'EMP_COD_PART', 'COND_PART', 'PER_EVT'}, {}}        
        xK200 = {1:4, {}, {};
                 5:9, {'REG', 'COD_NAT', 'IND_CTA', 'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}, {}}        
        xK210 = {1:4, {}, {};
                 5:9, {'REG', 'COD_EMP', 'COD_CTA_EMP'}, {}}        
        xK300 = {1:4, {}, {};
                 5:9, {'REG', 'COD_CTA', 'VAL_AG', 'IND_VAL_AG', 'VAL_EL', 'IND_VAL_EL', 'VAL_CS', 'IND_VAL_CS'}, {}}        
        xK310 = {1:4, {}, {};
                 5:9, {'REG', 'EMP_COD_PARTE', 'VALOR', 'IND_VALOR'}, {}}        
        xK315 = {1:4, {}, {};
                 5:9, {'REG', 'EMP_COD_CONTRA', 'COD_CONTRA', 'VALOR', 'IND_VALOR'}, {}}        
        xK990 = {1:4, {}, {};
                 5:9, {'REG', 'QTD_LIN_K'}, {}}

        % Bloco 9: Controle e Encerramento do Arquivo Digital
        x9001 = {1:9, {'REG', 'IND_DAD'}, {}}
        x9900 = {1:9, {'REG', 'REG_BLC', 'QTD_REG_BLC'}, {}}        
        x9990 = {1:9, {'REG', 'QTD_LIN_9'}, {}}        
        x9999 = {1:9, {'REG', 'QTD_LIN'}, {}}
    end

    properties (Constant)
        %-------------------------------------------------------%
        % CAMPOS RELACIONADOS ÀS TABELAS SOB ANÁLISE
        % Informação ordenada pelos campos "DataType" e "Field".
        % Os campos "01" a "12", "TOTAL", "DESCRIÇÃO" e 
        %-------------------------------------------------------%
        FieldSpecification = cell2table({ ...
            'ARQ_RTF',                  'cell',     [],     'Sequência de bytes que representem um único arquivo no formato RTF (Rich Text Format).'; 
            'CAB_DEM',                  'cell',     [],     'Cabeçalho das demonstrações.'; 
            'CAMPO',                    'cell',     [],     'Nome do campo adicional.'; 
            'CCUS',                     'cell',     [],     'Nome do centro de custos.'; 
            'CNPJ',                     'cell',     [],     'Número de inscrição da pessoa jurídica no CNPJ. Observação: Esse CNPJ é sempre da Sócia Ostensiva, no caso do arquivo da SCP.'; 
            'CNPJ_ECD_REC',             'cell',     [],     'CNPJ da ECD recuperada.'; 
            'COD_AGL',                  'cell',     [],     'Código de aglutinação das linhas, atribuído pela pessoa jurídica.'; 
            'COD_AGL_SUP',              'cell',     [],     'Código de aglutinação sintético/grupo de código de aglutinação de nível superior.'; 
            'COD_ASSIN',                'cell',     [],     'Código de qualificação do assinante, conforme tabela.'; 
            'COD_ASSIN_T',              'cell',     [],     'Código de qualificação do assinante do termo de verificação, conforme tabela.'; 
            'COD_CCUS',                 'cell',     [],     'Código do centro de custos do plano de contas anterior.'; 
            'COD_CCUS_REC',             'cell',     [],     'Código do centro de custos.'; 
            'COD_CNT_CORR',             'cell',     [],     'Código da subconta correlata (deve estar no plano de contas e só pode estar relacionada a um único grupo).'; 
            'COD_CONTRA',               'cell',     [],     'Código da conta consolidada da contrapartida.'; 
            'COD_CTA',                  'cell',     [],     'Código da conta analítica.'; 
            'COD_CTA_EMP',              'cell',     [],     'Código da conta da empresa participante.'; 
            'COD_CTA_REC',              'cell',     [],     'Código da conta analítica.'; 
            'COD_CTA_REF',              'cell',     [],     'Código da conta conforme plano de contas referencial.'; 
            'COD_CTA_RES',              'cell',     [],     'Código da(s) conta(s) analítica(s) do Livro Diário com Escrituração Resumida.'; 
            'COD_CTA_SUP',              'cell',     [],     'Código da conta sintética / grupo de contas de nível superior.'; 
            'COD_CVM_AUDITOR',          'cell',     [],     'Auditor independente na CVM.'; 
            'COD_EMP',                  'cell',     [],     'Código de identificação da empresa participante.'; 
            'COD_ENT_REF',              'cell',     [],     'Código da instituição responsável pelo plano de contas referencial.'; 
            'COD_HASH_AUX',             'cell',     [],     'Verifica se o campo código Hash do arquivo correspondente ao livro auxiliar.'; 
            'COD_HASH_SUB',             'cell',     [],     'Hash da escrituração substituída.'; 
            'COD_HIST',                 'cell',     [],     'Código do histórico padronizado.'; 
            'COD_HIST_FAT',             'cell',     [],     'Código do histórico do fato contábil.'; 
            'COD_HIST_PAD',             'cell',     [],     'Código do histórico padronizado, conforme tabela I075.'; 
            'COD_IDT',                  'cell',     [],     'Código de identificação do grupo de conta-subconta.'; 
            'COD_INSCR',                'cell',     [],     'Código cadastral da pessoa jurídica na instituição identificada.'; 
            'COD_MOT_SUBS',             'cell',     [],     'Código do motivo da substituição.'; 
            'COD_MUN',                  'cell',     [],     'Código do município conforme tabela do IBGE.'; 
            'COD_NAT',                  'cell',     [],     'Código da natureza da conta/grupo de contas.'; 
            'COD_PAIS',                 'cell',     [],     'Código do país conforme tabela do Banco Central do Brasil.'; 
            'COD_PART',                 'cell',     [],     'Código de identificação do participante.'; 
            'COD_PLAN_REF',             'cell',     [],     'Código do Plano de Contas Referencial.'; 
            'COD_REL',                  'cell',     [],     'Código do relacionamento conforme tabela do Sped.'; 
            'COD_SCP',                  'cell',     [],     'CNPJ da SCP.'; 
            'COD_SCP_ECD_REC',          'cell',     [],     'CNPJ da SCP.'; 
            'COL_CAMPO',                'cell',     [],     'Largura da coluna no relatório.'; 
            'COND_PART',                'cell',     [],     'Condição da empresa relacionada à operação.'; 
            'CPF',                      'cell',     [],     'CPF.'; 
            'CTA',                      'cell',     [],     'Nome da conta analítica/grupo de contas.'; 
            'DEC_CAMPO',                'cell',     [],     'Quantidade de casas decimais.'; 
            'DESC_CAMPO',               'cell',     [],     'Descrição do campo.'; 
            'DESC_FAT',                 'cell',     [],     'Descrição do Fato Contábil.'; 
            'DESC_MUN',                 'cell',     [],     'Município.'; 
            'DESC_RTF',                 'cell',     [],     'Descrição do arquivo .rtf.'; 
            'DESCR_COD_AGL',            'cell',     [],     'Descrição do Código de aglutinação.'; 
            'DESCR_HIST',               'cell',     [],     'Descrição do histórico padronizado.'; 
            'DESCRICAO',                'cell',     [],     'Descrição do campo adicional.'; 
            'DNRC_ABERT',               'cell',     [],     'Texto fixo contendo "TERMO DE ABERTURA".'; 
            'DNRC_ENCER',               'cell',     [],     'Texto fixo contendo "TERMO DE ENCERRAMENTO".'; 
            'EMAIL',                    'cell',     [],     'Email do signatário.'; 
            'EMAIL_T',                  'cell',     [],     'Email do signatário.'; 
            'EMP_COD',                  'cell',     [],     'Código de identificação da empresa participante.'; 
            'EMP_COD_CONTRA',           'cell',     [],     'Código da empresa da contrapartida.'; 
            'EMP_COD_PART',             'cell',     [],     'Código da empresa envolvida na operação.'; 
            'EMP_COD_PARTE',            'cell',     [],     'Código da empresa detentora do valor aglutinado.'; 
            'EVENTO',                   'cell',     [],     'Evento societário ocorrido no período.'; 
            'FONE',                     'cell',     [],     'Telefone do signatário.'; 
            'FONE_T',                   'cell',     [],     'Telefone do signatário.'; 
            'HASH_ECD_REC',             'cell',     [],     'Hashcode da ECD recuperada.'; 
            'HASH_RTF',                 'cell',     [],     'Hash do arquivo .rtf incluído.'; 
            'HIST',                     'cell',     [],     'Histórico completo da partida.'; 
            'ID_DEM',                   'cell',     [],     'Identificação das demonstrações.'; 
            'IDENT_CPF',                'cell',     [],     'CPF.'; 
            'IDENT_CPF_CNPJ',           'cell',     [],     'CPF ou CNPJ.'; 
            'IDENT_CPF_CNPJ_T',         'cell',     [],     'CPF ou CNPJ do assinante do termo.'; 
            'IDENT_MF',                 'cell',     [],     'Identificação de moeda funcional.'; 
            'IDENT_MF_ECD_REC',         'cell',     [],     'Identificação de moeda funcional.'; 
            'IDENT_NOM',                'cell',     [],     'Nome do signatário.'; 
            'IDENT_NOM_T',              'cell',     [],     'Nome do signatário do termo.'; 
            'IDENT_QUALIF',             'cell',     [],     'Qualificação do assinante.'; 
            'IDENT_QUALIF_T',           'cell',     [],     'Qualificação do assinante do termo.'; 
            'IE',                       'cell',     [],     'Inscrição Estadual.'; 
            'IE_ST',                    'cell',     [],     'Inscrição Estadual do participante.'; 
            'IM',                       'cell',     [],     'Inscrição Municipal.'; 
            'IND_CENTRALIZADA',         'cell',     [],     'Indicador de escrituração centralizada ou descentralizada.'; 
            'IND_CENTRALIZADA_ECD_REC', 'cell',     [],     'Indicador de escrituração centralizada ou descentralizada.'; 
            'IND_COD_AGL',              'cell',     [],     'Indicador do tipo de código de aglutinação.'; 
            'IND_CRC',                  'cell',     [],     'Número do CRC.'; 
            'IND_CRC_T',                'cell',     [],     'Número do CRC.'; 
            'IND_CTA',                  'cell',     [],     'Indicador do tipo de conta.'; 
            'IND_DAD',                  'cell',     [],     'Indicador de movimento.'; 
            'IND_DC',                   'cell',     [],     'Indicador da situação do saldo final.'; 
            'IND_DC_AUX',               'cell',     [],     'Indicador da natureza da partida em moeda funcional.'; 
            'IND_DC_BAL',               'cell',     [],     'Indicador da situação do saldo.'; 
            'IND_DC_BAL_INI',           'cell',     [],     'Indicador da situação do saldo inicial.'; 
            'IND_DC_CTA',               'cell',     [],     'Indicador da situação do saldo da conta.'; 
            'IND_DC_CTA_FIN',           'cell',     [],     'Indicador do valor final antes do encerramento.'; 
            'IND_DC_CTA_INI',           'cell',     [],     'Indicador do valor inicial.'; 
            'IND_DC_FAT',               'cell',     [],     'Indicador da situação do saldo do fato.'; 
            'IND_DC_FIN',               'cell',     [],     'Indicador do saldo final.'; 
            'IND_DC_FIN_AUX',           'cell',     [],     'Indicador do saldo final em moeda funcional.'; 
            'IND_DC_FIN_MF',            'cell',     [],     'Indicador do saldo final em moeda funcional.'; 
            'IND_DC_FIN_REC',           'cell',     [],     'Indicador do saldo final recuperado.'; 
            'IND_DC_INI',               'cell',     [],     'Indicador do saldo inicial.'; 
            'IND_DC_INI_AUX',           'cell',     [],     'Indicador do saldo inicial em moeda funcional.'; 
            'IND_DC_INI_MF',            'cell',     [],     'Indicador do saldo inicial em moeda funcional.'; 
            'IND_DC_INI_REC',           'cell',     [],     'Indicador do saldo inicial recuperado.'; 
            'IND_DC_MF',                'cell',     [],     'Indicador da natureza da partida em moeda funcional.'; 
            'IND_DEC',                  'cell',     [],     'Indicador de descentralização.'; 
            'IND_EMP_GRD_PRT',          'cell',     [],     'Indicador de empresa de grande porte.'; 
            'IND_ESC',                  'cell',     [],     'Indicador da forma de escrituração contábil.'; 
            'IND_ESC_CONS',             'cell',     [],     'Indicador de escriturações consolidadas.'; 
            'IND_ESC_CONS_ECD_REC',     'cell',     [],     'Indicador de escriturações consolidadas.'; 
            'IND_FIM_RTF',              'cell',     [],     'Indicador de fim do arquivo RTF.'; 
            'IND_FIN_ESC',              'cell',     [],     'Indicador de finalidade da escrituração.'; 
            'IND_FIN_ESC_ECD_REC',      'cell',     [],     'Indicador de finalidade da escrituração.'; 
            'IND_GRANDE_PORTE',         'cell',     [],     'Indicador de entidade sujeita a auditoria independente.'; 
            'IND_GRP_BAL',              'cell',     [],     'Indicador de grupo do balanço.'; 
            'IND_GRP_DRE',              'cell',     [],     'Indicador de grupo da DRE.'; 
            'IND_LCTO',                 'cell',     [],     'Indicador do tipo de lançamento.'; 
            'IND_MUDANC_PC',            'cell',     [],     'Indicador de mudança de plano de contas.'; 
            'IND_MUDANCA_PC_ECD_REC',   'cell',     [],     'Indicador de mudança de plano de contas.'; 
            'IND_NIRE',                 'cell',     [],     'Indicador de existência de NIRE.'; 
            'IND_NIRE_ECD_REC',         'cell',     [],     'Indicador de existência de NIRE.'; 
            'IND_PLANO_REF_ECD_REC',    'cell',     [],     'Indicador do plano de contas referencial.'; 
            'IND_RESP_LEGAL',           'cell',     [],     'Indicador de responsável legal.'; 
            'IND_SIT_ESP',              'cell',     [],     'Indicador de situação especial.'; 
            'IND_SIT_ESP_ECD_REC',      'cell',     [],     'Indicador de situação especial da ECD recuperada.'; 
            'IND_SIT_INI_PER',          'cell',     [],     'Indicador de situação no início do período.'; 
            'IND_TIP',                  'cell',     [],     'Indicador do tipo de demonstração.'; 
            'IND_VAL_AG',               'cell',     [],     'Indicador da situação do valor aglutinado.'; 
            'IND_VAL_CS',               'cell',     [],     'Indicador da situação do valor consolidado.'; 
            'IND_VAL_EL',               'cell',     [],     'Indicador da situação do valor eliminado.'; 
            'IND_VALOR',                'cell',     [],     'Indicador da situação do valor eliminado.'; 
            'IND_VL',                   'cell',     [],     'Indicador da situação do valor informado.'; 
            'IND_VL_ULT_DRE',           'cell',     [],     'Indicador da situação do valor informado.'; 
            'LECD',                     'cell',     [],     'Texto fixo contendo "LECD".'; 
            'NAT_LIVR',                 'cell',     [],     'Natureza do livro.'; 
            'NAT_LIVRO',                'cell',     [],     'Natureza do livro.'; 
            'NAT_SUB_CNT',              'cell',     [],     'Natureza da subconta correlata.'; 
            'NI_CPF_CNPJ',              'cell',     [],     'CPF ou CNPJ do auditor independente.'; 
            'NIRE',                     'cell',     [],     'Número de Identificação do Registro de Empresas.'; 
            'NIRE_SUBST',               'cell',     [],     'NIRE da escrituração substituída.'; 
            'NIT',                      'cell',     [],     'Indicador da situação do valor eliminado.'; 
            'NIVEL',                    'cell',     [],     'Nível da conta analítica.'; 
            'NIVEL_AGL',                'cell',     [],     'Nível do código de aglutinação.'; 
            'NM_CAMPO',                 'cell',     [],     'Nome do campo.'; 
            'NOME',                     'cell',     [],     'Nome empresarial da pessoa jurídica.'; 
            'NOME_AUDITOR',             'cell',     [],     'Nome do auditor independente.'; 
            'NOME_AUDITOR_FIRMA',       'cell',     [],     'Nome do auditor ou firma.'; 
            'NOME_SCP',                 'cell',     [],     'Nome da SCP.'; 
            'NOTA_EXP_REF',             'cell',     [],     'Referência às notas explicativas.'; 
            'NOTAS_EXP_REF',            'cell',     [],     'Referência às notas explicativas.'; 
            'NU_ORDEM',                 'cell',     [],     'Número de ordem da linha.'; 
            'NUM_AD',                   'cell',     [],     'Número sequencial do campo adicional.'; 
            'NUM_ARQ',                  'cell',     [],     'Número ou caminho do documento.'; 
            'NUM_LCTO',                 'cell',     [],     'Número do lançamento contábil.'; 
            'NUM_ORD',                  'cell',     [],     'Número de ordem do instrumento.'; 
            'NUM_SEQ_CRC',              'cell',     [],     'Número da Certidão de Regularidade Profissional.'; 
            'NUM_SEQ_CRC_T',            'cell',     [],     'Número da Certidão de Regularidade Profissional.'; 
            'PER_CONS',                 'cell',     [],     'Percentual de consolidação.'; 
            'PER_EVT',                  'cell',     [],     'Percentual da empresa participante.'; 
            'PER_PART',                 'cell',     [],     'Percentual de participação.'; 
            'REG',                      'cell',     [],     'Texto fixo do registro.'; 
            'REG_BLC',                  'cell',     [],     'Registro a ser totalizado.'; 
            'REG_COD',                  'cell',     [],     'Código do registro.'; 
            'RZ_CONT',                  'cell',     [],     'Conteúdo dos campos do registro I510.'; 
            'RZ_CONT_TOT',              'cell',     [],     'Conteúdo dos campos do registro I510.'; 
            'SUFRAMA',                  'cell',     [],     'Inscrição na Suframa.'; 
            'TAM_CAMPO',                'cell',     [],     'Tamanho do campo.'; 
            'TAM_FONTE',                'cell',     [],     'Tamanho da fonte.'; 
            'TIP_ECD',                  'cell',     [],     'Indicador do tipo de ECD.'; 
            'TIP_ECD_REC',              'cell',     [],     'Indicador do tipo da ECD.'; 
            'TIPO',                     'cell',     [],     'Indicação do tipo de dado.'; 
            'TIPO_CAMPO',               'cell',     [],     'Tipo do campo.'; 
            'TIPO_DOC',                 'cell',     [],     'Tipo de documento.'; 
            'UF',                       'cell',     [],     'Unidade da federação.'; 
            'UF_CRC',                   'cell',     [],     'UF do CRC.'; 
            'UF_CRC_T',                 'cell',     [],     'UF do CRC.';
            'DATA_FIN_EMP',             'datetime', [],     'Data final do período da escrituração consolidada.'; 
            'DATA_INI_EMP',             'datetime', [],     'Data inicial do período da escrituração consolidada.'; 
            'DT_ALT',                   'datetime', [],     'Data da inclusão ou alteração.'; 
            'DT_ARQ',                   'datetime', [],     'Data do arquivamento.'; 
            'DT_ARQ_CONV',              'datetime', [],     'Data do arquivamento do ato de conversão.'; 
            'DT_BCTE',                  'datetime', [],     'Data do balancete.'; 
            'DT_CRC',                   'datetime', [],     'Data de validade do CRC.'; 
            'DT_CRC_T',                 'datetime', [],     'Data de validade do CRC.'; 
            'DT_EVENTO',                'datetime', [],     'Data do evento societário.'; 
            'DT_EX_SOCIAL',             'datetime', [],     'Data de encerramento do exercício social.'; 
            'DT_FIN',                   'datetime', [],     'Data final das demonstrações.'; 
            'DT_FIN_ECD_REC',           'datetime', [],     'Data final da ECD recuperada.'; 
            'DT_FIN_ESCR',              'datetime', [],     'Data de término da escrituração.'; 
            'DT_FIN_REL',               'datetime', [],     'Data do término do relacionamento.'; 
            'DT_INI',                   'datetime', [],     'Data inicial das demonstrações.'; 
            'DT_INI_ECD_REC',           'datetime', [],     'Data inicial da ECD recuperada.'; 
            'DT_INI_ESCR',              'datetime', [],     'Data de início da escrituração.'; 
            'DT_INI_REL',               'datetime', [],     'Data de início do relacionamento.'; 
            'DT_LCTO',                  'datetime', [],     'Data do lançamento.'; 
            'DT_LCTO_EXT',              'datetime', [],     'Data do lançamento extemporâneo.'; 
            'DT_RES',                   'datetime', [],     'Data da apuração do resultado.';
            'COD_VER_LC',               'double',   [],     'Código da versão do leiaute.'; 
            'QTD_LIN',                  'double',   [],     'Quantidade total de linhas do arquivo.'; 
            'QTD_LIN_0',                'double',   [],     'Quantidade total de linhas do Bloco 0.'; 
            'QTD_LIN_9',                'double',   [],     'Quantidade total de linhas do Bloco 9.'; 
            'QTD_LIN_I',                'double',   [],     'Quantidade total de linhas do Bloco I.'; 
            'QTD_LIN_J',                'double',   [],     'Quantidade total de linhas do Bloco J.'; 
            'QTD_LIN_K',                'double',   [],     'Quantidade total de linhas do Bloco K.'; 
            'QTD_REG_BLC',              'double',   [],     'Total de registros do tipo informado.'; 
            'VAL_AG',                   'double',   'bank', 'Valor absoluto aglutinado.'; 
            'VAL_CRED_AUX',             'double',   'bank', 'Total dos créditos do dia em moeda funcional.'; 
            'VAL_CRED_MF',              'double',   'bank', 'Total dos créditos do dia em moeda funcional.'; 
            'VAL_CREDD',                'double',   'bank', 'Total dos créditos do dia.'; 
            'VAL_CS',                   'double',   'bank', 'Valor absoluto consolidado.'; 
            'VAL_DEB_AUX',              'double',   'bank', 'Total dos débitos do dia em moeda funcional.'; 
            'VAL_DEB_MF',               'double',   'bank', 'Total dos débitos do dia em moeda funcional.'; 
            'VAL_DEBD',                 'double',   'bank', 'Total dos débitos do dia.'; 
            'VAL_EL',                   'double',   'bank', 'Valor absoluto das eliminações.'; 
            'VALOR',                    'double',   'bank', 'Parcela do valor eliminado total.'; 
            'VL_CRED',                  'double',   'bank', 'Valor total dos créditos do período.'; 
            'VL_CRED_AUX',              'double',   'bank', 'Valor total dos créditos em moeda funcional.'; 
            'VL_CRED_MF',               'double',   'bank', 'Valor total dos créditos em moeda funcional.'; 
            'VL_CRED_REC',              'double',   'bank', 'Valor total dos créditos no período.'; 
            'VL_CTA',                   'double',   'bank', 'Valor do saldo final antes do encerramento.'; 
            'VL_CTA_AUX',               'double',   'bank', 'Valor do saldo final em moeda funcional.'; 
            'VL_CTA_FIN',               'double',   'bank', 'Valor final do código de aglutinação.'; 
            'VL_CTA_INI',               'double',   'bank', 'Valor inicial do código de aglutinação.'; 
            'VL_CTA_INI_',              'double',   'bank', 'Valor do saldo final do período anterior.'; 
            'VL_CTA_MF',                'double',   'bank', 'Valor do saldo final em moeda funcional.'; 
            'VL_CTA_ULT_DRE',           'double',   'bank', 'Valor do saldo final da última DRE.'; 
            'VL_DC',                    'double',   'bank', 'Valor da partida.'; 
            'VL_DC_AUX',                'double',   'bank', 'Valor da partida em moeda funcional.'; 
            'VL_DC_MF',                 'double',   'bank', 'Valor da partida em moeda funcional.'; 
            'VL_DEB',                   'double',   'bank', 'Valor total dos débitos do período.'; 
            'VL_DEB_AUX',               'double',   'bank', 'Valor total dos débitos em moeda funcional.'; 
            'VL_DEB_MF',                'double',   'bank', 'Total dos débitos em moeda funcional.'; 
            'VL_DEB_REC',               'double',   'bank', 'Valor total dos débitos no período.'; 
            'VL_FAT_CONT',              'double',   'bank', 'Valor do fato contábil.'; 
            'VL_LCTO',                  'double',   'bank', 'Valor do lançamento.'; 
            'VL_LCTO_AUX',              'double',   'bank', 'Valor do lançamento em moeda funcional.'; 
            'VL_LCTO_MF',               'double',   'bank', 'Valor do lançamento em moeda funcional.'; 
            'VL_SLD_FIN',               'double',   'bank', 'Valor do saldo final.'; 
            'VL_SLD_FIN_AUX',           'double',   'bank', 'Valor do saldo final em moeda funcional.'; 
            'VL_SLD_FIN_MF',            'double',   'bank', 'Valor do saldo final em moeda funcional.'; 
            'VL_SLD_FIN_REC',           'double',   'bank', 'Valor do saldo final recuperado.'; 
            'VL_SLD_INI',               'double',   'bank', 'Valor do saldo inicial.'; 
            'VL_SLD_INI_AUX',           'double',   'bank', 'Valor do saldo inicial em moeda funcional.'; 
            'VL_SLD_INI_MF',            'double',   'bank', 'Valor do saldo inicial em moeda funcional.'; 
            'VL_SLD_INI_REC',           'double',   'bank', 'Valor do saldo inicial recuperado.';
            'DESCRIÇÃO',                'cell',     [],     'Campo da tabela customizada "x_CONTAS_DESCRICAO"';
            'Apurado?  ✎',             'categorical', [],  'Campo da tabela customizada "x_CONTAS_ANOTACAO"';
            'Alíquota ICMS',            'cell',     [],     'Campo da tabela customizada "x_CONTAS_ANOTACAO"';
            'Observação  ✎',           'cell',     [],     'Campo da tabela customizada "x_CONTAS_ANOTACAO"';
            '01',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '02',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '03',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '04',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '05',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '06',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '07',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '08',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '09',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '10',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '11',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '12',                       'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            'TOTAL',                    'double',   'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"' ...
        }, 'VariableNames', {'Field','DataType','Format','Description'});
    end

    methods (Static = true)
        %-------------------------------------------------------%
        function MFilePath = path()
            MFilePath = fileparts(mfilename('fullpath'));
        end

        %-------------------------------------------------------%
        function implementedTableIds = getImplementedTableIds(removePrefixFlag)
            arguments
                removePrefixFlag (1,1) logical = true
            end

            classMeta = meta.class.fromName('model.ECDBase');

            tableIdPrefix = 'x';
            prefixedProps = classMeta.PropertyList(startsWith({classMeta.PropertyList.Name}, tableIdPrefix));
            
            implementedTableIds = {prefixedProps.Name};
            if removePrefixFlag
                implementedTableIds = extractAfter(implementedTableIds, tableIdPrefix);
            end
        end

        %-------------------------------------------------------%
        function [status, missingFields] = validateFieldMapping()
            implementedTableIds = model.ECDBase.getImplementedTableIds(false);
            availableFieldNames = model.ECDBase.FieldSpecification.Field;

            mappedFields = {};        
            for ii = 1:numel(implementedTableIds)
                tableFieldSubset = model.ECDBase.(implementedTableIds{ii})(:, 2:3);
                mappedFields = [mappedFields, horzcat(tableFieldSubset{:})];
            end        
            mappedFields = unique(mappedFields)';

            fieldsExist = ismember(mappedFields, availableFieldNames);        
            if all(fieldsExist)
                status = true;
                missingFields = {};
            else
                status = false;
                missingFields = mappedFields(~fieldsExist);
            end
        end

        %-------------------------------------------------------%
        function spec = getFieldSpecification(field, specType)
            arguments
                field
                specType {mustBeMember(specType, {'DataType', 'Format', 'Description'})}
            end

            scalarInput = false;
            if ~iscellstr(field)
                scalarInput = true;
                field = cellstr(field);
            end

            tbl = model.ECDBase.FieldSpecification;
            [isFound, indexes] = ismember(field, tbl.Field);

            if any(~isFound)
                error("ECDBase:getFieldSpecification:UnknownField", "Unknown field(s): %s", strjoin(field(~isFound), ", "));
            end

            spec = tbl.(specType)(indexes)';
            if scalarInput && isscalar(spec)
                spec = spec{1};
            end
        end

        %-----------------------------------------------------------------%
        function value = defaultValue(dataType)
            switch dataType
                case 'cell'
                    value = {''};
                case 'datetime'
                    value = datetime([0,0,0,0,0,0]);
                case 'double'
                    value = -1;
                otherwise
                    error('ECDBase:UnexpectedDataType', 'Unexpected data type "%s"', dataType)
            end
        end

        %-----------------------------------------------------------------%
        function tableOut = cellToTable(blockData, columnSpec)
            numInputColumns = width(blockData);
            numRequiredColumns = numel(columnSpec.required);
            numCompleteColumns = numel(columnSpec.complete);

            switch numInputColumns
                case numRequiredColumns
                    tableOut = cell2table(blockData, 'VariableNames', columnSpec.required);
    
                    for ii = 1:numel(columnSpec.optional)
                        columnName = columnSpec.optional{ii};
                        tableOut.(columnName) = repmat({''}, height(tableOut), 1);
                    end
    
                case numCompleteColumns
                    tableOut = cell2table(blockData, 'VariableNames', columnSpec.complete);
    
                otherwise
                    error('ECDBase:UnexpectedTableWidth', 'Unexpected table width - Expected: %d or %d, Received: %s', numRequiredColumns, numCompleteColumns, numInputColumns)
            end
        end

        %-----------------------------------------------------------------%
        function tableOut = initializeCustomTable(tableId, varargin)
            arguments
                tableId {mustBeMember(tableId, {'_BALANCETE_GERAL', '_CONTAS_ANOTACAO', '_CONTAS_DESCRICAO', '_CONTAS_HISTORICO', '_APURACAO_GERAL', '_APURACAO_INTERCONEXAO', '_CONCILIACAO_GERAL', '_CONCILIACAO_INTERCONEXAO'})}
            end

            arguments (Repeating)
                varargin
            end

            switch tableId
                case '_BALANCETE_GERAL'
                    numAccounts = varargin{1};
                    tableOut = table( ...
                        'Size', [numAccounts, 15], ...
                        'VariableTypes', {'cell', 'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                        'VariableNames', {'COD_NAT', 'COD_CTA', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'} ...
                    );

              % case '_BALANCETE_RESULTADO'
              %     numAccounts = varargin{1};
              %     tableOut = table( ...
              %         'Size', [numAccounts, 14], ...
              %         'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
              %         'VariableNames', {'COD_CTA', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'} ...
              %     );

                case '_CONTAS_ANOTACAO'
                    accountList = varargin{1};
                    numAccounts = numel(accountList);
                    generalSettings = varargin{2};

                    tableOut = table( ...
                        accountList, ...
                        repmat(categorical("-", generalSettings.context.ECD.accountOptions,         'Protected', true), numAccounts, 1), ...
                        repmat(categorical("-", generalSettings.context.ECD.interconnectionOptions, 'Protected', true), numAccounts, 1), ...
                        repmat({'-'}, numAccounts, 1), ...
                        repmat({''}, numAccounts, 1), ...
                        'VariableNames', {'COD_CTA', 'Apurado?  ✎', 'Interconexão?  ✎', 'Alíquota ICMS', 'Observação  ✎'} ...
                    );
              
                case '_CONTAS_DESCRICAO'
                    numAccounts = varargin{1};
                    tableOut = table( ...
                        'Size', [numAccounts, 2], ...
                        'VariableNames', {'COD_CTA', 'DESCRIÇÃO'}, ...
                        'VariableTypes', {'cell', 'cell'} ...
                    );

                case '_CONTAS_HISTORICO'
                    numAccounts = varargin{1};
                    tableOut = table( ...
                        'Size', [numAccounts, 3], ...
                        'VariableNames', {'COD_CTA', 'TOTAL DE LANÇAMENTOS', 'LANÇAMENTOS NORMALIZADOS DEDUPLICADOS'}, ...
                        'VariableTypes', {'cell', 'double', 'cell'} ...
                    );

                case '_APURACAO_GERAL'
                    tableOut = table( ...
                        'Size', [11, 14], ...
                        'VariableNames', {'TIPO', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                        'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'} ...
                    );
                    tableOut.("TIPO")(:) = {'ROB TELECOM'; 'ICMS ESTIMADO'; 'ICMS CONTÁBIL'; 'BASE DE CÁLCULO (PIS/COFINS)'; 'PIS ESTIMADO'; 'PIS CONTÁBIL'; 'COFINS ESTIMADO'; 'COFINS CONTÁBIL'; 'BASE DE CÁLCULO (FUST/FUNTTEL)'; 'VALOR APURADO FUST'; 'VALOR APURADO FUNTTEL'};

                case '_APURACAO_INTERCONEXAO'
                    tableOut = table( ...
                        'Size', [8, 14], ...
                        'VariableNames', {'TIPO', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                        'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'} ...
                    );
                    tableOut.("TIPO")(:) = {'ROB TELECOM'; 'ICMS ESTIMADO'; 'BASE DE CÁLCULO (PIS/COFINS)'; 'PIS ESTIMADO'; 'COFINS ESTIMADO'; 'BASE DE CÁLCULO (FUST/FUNTTEL)'; 'VALOR APURADO FUST'; 'VALOR APURADO FUNTTEL'};

                case '_CONCILIACAO_GERAL'
                    tableOut = table( ...
                        'Size', [5, 14], ...
                        'VariableNames', {'TIPO', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                        'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'} ...
                    );
                    tableOut.("TIPO")(:) = {'ROB TELECOM'; 'ICMS ESTIMADO'; 'ICMS CONTÁBIL'; 'PIS CONTÁBIL'; 'COFINS CONTÁBIL'};

                case '_CONCILIACAO_INTERCONEXAO'
                    tableOut = table( ...
                        'Size', [1, 14], ...
                        'VariableNames', {'TIPO', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                        'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'} ...
                    );
                    tableOut.("TIPO")(:) = {'ROB TELECOM'};
            end
        end
    end
end