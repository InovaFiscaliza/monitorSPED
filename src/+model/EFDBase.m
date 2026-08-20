classdef (Abstract) EFDBase
    % Cadastro de fichas e dos seus campos, de acordo com os diversos layouts
    % dos arquivos. Na pasta "doc" consta os PDFs descrevendo cada layout,
    % mas outras informaÃƒÂ§ÃƒÂµes podem ser obtidas em http://sped.rfb.gov.br/

    properties (Constant)
        %-------------------------------------------------------%
        % TABELAS SOB ANÃƒÂLISE
        % As tabelas (ou fichas) sob análise são organizadas num cellarray
        % com trÃƒÂªs colunas, em que a primeira coluna contÃƒÂ©m um array com a
        % indicaÃƒÂ§ÃƒÂ£o do layout aplicÃƒÂ¡vel (1:9, por exemplo), a segunda coluna
        % sÃƒÂ£o os campos obrigatÃƒÂ³rios da ficha, e a terceira coluna os campos
        % opcionais (ou adicionais).
        %-------------------------------------------------------%

        % EFD ICMS/IPI: Layout 3.2.2 (Fev/2026)
        % Range 1:18 maps to layouts from 2010 to 2026.

        % Bloco 0: Abertura, IdentificaÃƒÂ§ÃƒÂ£o e ReferÃƒÂªncias
        x0000 = {1:18, {'REG', 'COD_VER', 'COD_FIN', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'CPF', 'UF', 'IE', 'COD_MUN', 'IM', 'SUFRAMA', 'IND_PERFIL', 'IND_ATIV'}, {}}
        x0001 = {1:18, {'REG', 'IND_MOV'}, {}}
        x0002 = {1:11, {}, {};
                12:18, {'REG', 'CLAS_ESTAB_IND'}, {}}
        x0005 = {1:18, {'REG', 'FANTASIA', 'CEP', 'END', 'NUM', 'COMPL', 'BAIRRO', 'FONE', 'FAX', 'EMAIL'}, {}}
        x0015 = {1:18, {'REG', 'UF_ST', 'IE_ST'}, {}}
        x0100 = {1:18, {'REG', 'NOME', 'CPF', 'CRC', 'CNPJ', 'CEP', 'END', 'NUM', 'COMPL', 'BAIRRO', 'FONE', 'FAX', 'EMAIL', 'COD_MUN'}, {}}
        x0150 = {1:18, {'REG', 'COD_PART', 'NOME', 'COD_PAIS', 'CNPJ', 'CPF', 'IE', 'COD_MUN', 'SUFRAMA', 'END', 'NUM', 'COMPL', 'BAIRRO'}, {}}
        x0175 = {1:18, {'REG', 'DT_ALT', 'NR_CAMPO', 'CONT_ANT'}, {}}
        x0190 = {1:18, {'REG', 'UNID', 'DESCR'}, {}}
        x0200 = {1:8,  {'REG', 'COD_ITEM', 'DESCR_ITEM', 'COD_BARRA', 'COD_ANT_ITEM', 'UNID_INV', 'TIPO_ITEM', 'COD_NCM', 'EX_IPI', 'COD_GEN', 'COD_LST', 'ALIQ_ICMS'}, {};
                 9:18, {'REG', 'COD_ITEM', 'DESCR_ITEM', 'COD_BARRA', 'COD_ANT_ITEM', 'UNID_INV', 'TIPO_ITEM', 'COD_NCM', 'EX_IPI', 'COD_GEN', 'COD_LST', 'ALIQ_ICMS', 'CEST'}, {}}
        x0205 = {1:18, {'REG', 'DESCR_ANT_ITEM', 'DT_INI', 'DT_FIM', 'COD_ANT_ITEM'}, {}}
        x0206 = {1:18, {'REG', 'COD_COMB'}, {}}
        x0210 = {1:7, {}, {};
                 8:18, {'REG', 'COD_ITEM_COMP', 'QTD_COMP', 'PERDA'}, {}}
        x0220 = {1:13, {'REG', 'UNID_CONV', 'FAT_CONV'}, {};
             14:18, {'REG', 'UNID_CONV', 'FAT_CONV', 'COD_BARRA'}, {}}
        x0221 = {1:14, {}, {};
                 15:18, {'REG', 'COD_ITEM_ATOMICO', 'QTD_CONTIDA'}, {}}
        x0300 = {1, {}, {};
                 2:18, {'REG', 'COD_IND_BEM', 'IDENT_MERC', 'DESCR_ITEM', 'COD_PRNC', 'COD_CTA', 'NR_PARC'}, {}}
        x0305 = {1, {}, {};
             2:18, {'REG', 'COD_CCUS', 'FUNC', 'VIDA_UTIL'}, {}}
        x0400 = {1:18, {'REG', 'COD_NAT', 'DESCR_NAT'}, {}}
        x0450 = {1:18, {'REG', 'COD_INF', 'TXT'}, {}}
        x0460 = {1:18, {'REG', 'COD_OBS', 'TXT'}, {}}
        x0500 = {1, {}, {};
                 2:18, {'REG', 'DT_ALT', 'COD_NAT_CC', 'IND_CTA', 'NIVEL', 'COD_CTA', 'NOME_CTA'}, {}}
        x0600 = {1, {}, {};
                 2:18, {'REG', 'DT_ALT', 'COD_CCUS', 'CCUS'}, {}}
        x0990 = {1:18, {'REG', 'QTD_LIN'}, {}}

        % Bloco B: Escrituracao e Apuracao do ISS
        xB001 = {1:18, {'REG', 'IND_MOV'}, {}}
        xB020 = {1:18, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'NUM_DOC', 'CHV_NFE', 'DT_DOC', 'COD_MUN_SERV', 'VL_CONT', 'VL_MAT_TERC', 'VL_SUB', 'VL_ISNT_ISS', 'VL_DED_BC', 'VL_BC_ISS', 'VL_BC_ISS_RT', 'VL_ISS_RT', 'VL_ISS', 'COD_INF_OBS'}, {}}
        xB025 = {1:18, {'REG', 'VL_CONT_P', 'VL_BC_ISS_P', 'ALIQ_ISS', 'VL_ISS_P', 'VL_ISNT_ISS_P', 'COD_SERV'}, {}}
        xB030 = {1:18, {'REG', 'COD_MOD', 'SER', 'NUM_DOC_INI', 'NUM_DOC_FIN', 'DT_DOC', 'QTD_CANC', 'VL_CONT', 'VL_ISNT_ISS', 'VL_BC_ISS', 'VL_ISS', 'COD_INF_OBS'}, {}}
        xB035 = {1:18, {'REG', 'VL_CONT_P', 'VL_BC_ISS_P', 'ALIQ_ISS', 'VL_ISS_P', 'VL_ISNT_ISS_P', 'COD_SERV'}, {}}
        xB350 = {1:18, {'REG', 'COD_CTD', 'CTA_ISS', 'CTA_COSIF', 'QTD_OCOR', 'COD_SERV', 'VL_CONT', 'VL_BC_ISS', 'ALIQ_ISS', 'VL_ISS', 'COD_INF_OBS'}, {}}
        xB420 = {1:18, {'REG', 'VL_CONT', 'VL_BC_ISS', 'ALIQ_ISS', 'VL_ISNT_ISS', 'VL_ISS', 'COD_SERV'}, {}}
        xB440 = {1:18, {'REG', 'IND_OPER', 'COD_PART', 'VL_CONT_RT', 'VL_BC_ISS_RT', 'VL_ISS_RT'}, {}}
        xB460 = {1:18, {'REG', 'IND_DED', 'VL_DED', 'NUM_PROC', 'IND_PROC', 'PROC', 'COD_INF_OBS', 'IND_OBR'}, {}}
        xB470 = {1:18, {'REG', 'VL_CONT', 'VL_MAT_TERC', 'VL_MAT_PROP', 'VL_SUB', 'VL_ISNT', 'VL_DED_BC', 'VL_BC_ISS', 'VL_BC_ISS_RT', 'VL_ISS', 'VL_ISS_RT', 'VL_DED', 'VL_ISS_REC', 'VL_ISS_ST', 'VL_ISS_REC_UNI'}, {}}
        xB500 = {1:18, {'REG', 'VL_REC', 'QTD_PROF', 'VL_OR'}, {}}
        xB510 = {1:18, {'REG', 'IND_PROF', 'IND_ESC', 'IND_SOC', 'CPF', 'NOME'}, {}}
        xB990 = {1:18, {'REG', 'QTD_LIN_B'}, {}}

        % Bloco C: Documentos Fiscais I - Mercadorias (ICMS/IPI)
        xC001 = {1:18, {'REG', 'IND_MOV'}, {}}
        xC100 = {1:18, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'NUM_DOC', 'CHV_NFE', 'DT_DOC', 'DT_E_S', 'VL_DOC', 'IND_PGTO', 'VL_DESC', 'VL_ABAT_NT', 'VL_MERC', 'IND_FRT', 'VL_FRT', 'VL_SEG', 'VL_OUT_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'VL_IPI', 'VL_PIS', 'VL_COFINS', 'VL_PIS_ST', 'VL_COFINS_ST'}, {}}
        xC101 = {1:7, {}, {};
                 8:18, {'REG', 'VL_FCP_UF_DEST', 'VL_ICMS_UF_DEST', 'VL_ICMS_UF_REM'}, {}}
        xC105 = {1:18, {'REG', 'OPER', 'UF'}, {}}
        xC120 = {1:18, {'REG', 'COD_DOC_IMP', 'NUM_DOC_IMP', 'PIS_IMP', 'COFINS_IMP', 'NUM_ACDRAW'}, {}}
        xC110 = {1:18, {'REG', 'COD_INF', 'TXT_COMPL'}, {}}
        xC111 = {1:18, {'REG', 'NUM_PROC', 'IND_PROC'}, {}}
        xC112 = {1:18, {'REG', 'COD_DA', 'UF', 'NUM_DA', 'COD_AUT', 'VL_DA', 'DT_VCTO', 'DT_PGTO'}, {}}
        xC113 = {1:18, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'CHV_DOCE'}, {}}
        xC114 = {1:18, {'REG', 'COD_MOD', 'ECF_FAB', 'ECF_CX', 'NUM_DOC', 'DT_DOC'}, {}}
        xC115 = {1:18, {'REG', 'IND_CARGA', 'CNPJ_COL', 'IE_COL', 'CPF_COL', 'COD_MUN_COL', 'CNPJ_ENTG', 'IE_ENTG', 'CPF_ENTG', 'COD_MUN_ENTG'}, {}}
        xC116 = {1:18, {'REG', 'COD_MOD', 'NR_SAT', 'CHV_CFE', 'NUM_CFE', 'DT_DOC'}, {}}
        xC130 = {1:18, {'REG', 'VL_SERV_NT', 'VL_BC_ISSQN', 'VL_ISSQN', 'VL_BC_IRRF', 'VL_IRRF', 'VL_BC_PREV', 'VL_PREV'}, {}}
        xC140 = {1:18, {'REG', 'IND_EMIT', 'IND_TIT', 'DESC_TIT', 'NUM_TIT', 'QTD_PARC', 'VL_TIT'}, {}}
        xC141 = {1:18, {'REG', 'NUM_PARC', 'DT_VCTO', 'VL_PARC'}, {}}
        xC160 = {1:18, {'REG', 'COD_PART', 'VEIC_ID', 'QTD_VOL', 'PESO_BRT', 'PESO_LIQ', 'UF_ID'}, {}}
        xC165 = {1:18, {'REG', 'COD_PART', 'VEIC_ID', 'COD_AUT', 'NR_PASSE', 'HORA', 'TEMPER', 'QTD_VOL', 'PESO_BRT', 'PESO_LIQ', 'NOM_MOT', 'CPF', 'UF_ID'}, {}}
        xC170 = {1:10, {'REG', 'NUM_ITEM', 'COD_ITEM', 'DESCR_COMPL', 'QTD', 'UNID', 'VL_ITEM', 'VL_DESC', 'IND_MOV', 'CST_ICMS', 'CFOP', 'COD_NAT', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'ALIQ_ST', 'VL_ICMS_ST', 'IND_APUR', 'CST_IPI', 'COD_ENQ', 'VL_BC_IPI', 'ALIQ_IPI', 'VL_IPI', 'CST_PIS', 'VL_BC_PIS', 'ALIQ_PIS', 'QUANT_BC_PIS', 'ALIQ_PIS_R', 'VL_PIS', 'CST_COFINS', 'VL_BC_COFINS', 'ALIQ_COFINS', 'QUANT_BC_COFINS', 'ALIQ_COFINS_R', 'VL_COFINS', 'COD_CTA'}, {};
                11:18, {'REG', 'NUM_ITEM', 'COD_ITEM', 'DESCR_COMPL', 'QTD', 'UNID', 'VL_ITEM', 'VL_DESC', 'IND_MOV', 'CST_ICMS', 'CFOP', 'COD_NAT', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'ALIQ_ST', 'VL_ICMS_ST', 'IND_APUR', 'CST_IPI', 'COD_ENQ', 'VL_BC_IPI', 'ALIQ_IPI', 'VL_IPI', 'CST_PIS', 'VL_BC_PIS', 'ALIQ_PIS', 'QUANT_BC_PIS', 'ALIQ_PIS_R', 'VL_PIS', 'CST_COFINS', 'VL_BC_COFINS', 'ALIQ_COFINS', 'QUANT_BC_COFINS', 'ALIQ_COFINS_R', 'VL_COFINS', 'COD_CTA', 'VL_ABAT_NT'}, {}}
        xC171 = {1:18, {'REG', 'NUM_TANQUE', 'QTDE'}, {}}
        xC172 = {1:18, {'REG', 'VL_BC_ISSQN', 'ALIQ_ISSQN', 'VL_ISSQN'}, {}}
        xC173 = {1:18, {'REG', 'LOTE_MED', 'QTD_ITEM', 'DT_FAB', 'DT_VAL', 'IND_MED', 'TP_PROD', 'VL_TAB_MAX'}, {}}
        xC174 = {1:18, {'REG', 'IND_ARM', 'NUM_ARM', 'DESCR_COMPL'}, {}}
        xC175 = {1:18, {'REG', 'IND_VEIC_OPER', 'CNPJ', 'UF', 'CHASSI_VEIC'}, {}}
        xC176 = {1:18, {'REG', 'COD_MOD_ULT_E', 'NUM_DOC_ULT_E', 'SER_ULT_E', 'DT_ULT_E', 'COD_PART_ULT_E', 'QUANT_ULT_E', 'VL_UNIT_ULT_E', 'VL_UNIT_BC_ST', 'CHAVE_NFE_ULT_E', 'NUM_ITEM_ULT_E', 'VL_UNIT_BC_ICMS_ULT_E', 'ALIQ_ICMS_ULT_E', 'VL_UNIT_LIMITE_BC_ICMS_ULT_E', 'VL_UNIT_ICMS_ULT_E', 'ALIQ_ST_ULT_E', 'VL_UNIT_RES', 'COD_RESP_RET', 'COD_MOT_RES', 'CHAVE_NFE_RET', 'COD_PART_NFE_RET', 'SER_NFE_RET', 'NUM_NFE_RET', 'ITEM_NFE_RET', 'COD_DA', 'NUM_DA', 'VL_UNIT_RES_FCP_ST'}, {}}
        xC178 = {1:18, {'REG', 'CL_ENQ', 'VL_UNID', 'QUANT_PAD'}, {}}
        xC179 = {1:18, {'REG', 'BC_ST_ORIG_DEST', 'ICMS_ST_REP', 'ICMS_ST_COMPL', 'BC_RET', 'ICMS_RET'}, {}}
        xC180 = {1:18, {'REG', 'COD_RESP_RET', 'QUANT_CONV', 'UNID', 'VL_UNIT_CONV', 'VL_UNIT_ICMS_OP_CONV', 'VL_UNIT_BC_ICMS_ST_CONV', 'VL_UNIT_ICMS_ST_CONV', 'VL_UNIT_FCP_ST_CONV', 'COD_DA', 'NUM_DA'}, {}}
        xC185 = {1:18, {'REG', 'NUM_ITEM', 'COD_ITEM', 'CST_ICMS', 'CFOP', 'COD_MOT_REST_COMPL', 'QUANT_CONV', 'UNID', 'VL_UNIT_ICMS_NA_OPERACAO_CONV', 'VL_UNIT_ICMS_OP_CONV', 'VL_UNIT_ICMS_OP_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_FCP_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_CONV_REST', 'VL_UNIT_FCP_ST_CONV_REST', 'VL_UNIT_ICMS_ST_CONV_COMPL', 'VL_UNIT_FCP_ST_CONV_COMPL'}, {}}
        xC191 = {1:18, {'REG', 'VL_FCP_OP', 'VL_FCP_ST', 'VL_FCP_RET'}, {}}
        xC190 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'VL_RED_BC', 'VL_IPI', 'COD_OBS'}, {}}
        xC195 = {1:18, {'REG', 'COD_OBS', 'TXT_COMPL'}, {}}
        xC197 = {1:18, {'REG', 'COD_AJ', 'DESCR_COMPL_AJ', 'COD_ITEM', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_OUTROS'}, {}}
        xC300 = {1:18, {'REG', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC_INI', 'NUM_DOC_FIN', 'DT_DOC', 'VL_DOC', 'VL_PIS', 'VL_COFINS', 'COD_CTA'}, {}}
        xC310 = {1:18, {'REG', 'NUM_DOC_CANC'}, {}}
        xC320 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_RED_BC', 'COD_OBS'}, {}}
        xC321 = {1:18, {'REG', 'COD_ITEM', 'QTD', 'UNID', 'VL_ITEM', 'VL_DESC', 'VL_BC_ICMS', 'VL_ICMS', 'VL_PIS', 'VL_COFINS'}, {}}
        xC330 = {1:18, {'REG', 'COD_MOT_REST_COMPL', 'QUANT_CONV', 'UNID', 'VL_UNIT_ICMS_NA_OPERACAO_CONV', 'VL_UNIT_ICMS_OP_CONV', 'VL_UNIT_ICMS_OP_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_FCP_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_CONV_REST', 'VL_UNIT_FCP_ST_CONV_REST', 'VL_UNIT_ICMS_ST_CONV_COMPL', 'VL_UNIT_FCP_ST_CONV_COMPL'}, {}}
        xC350 = {1:18, {'REG', 'SER', 'SUB_SER', 'NUM_DOC', 'DT_DOC', 'CNPJ_CPF', 'VL_MERC', 'VL_DOC', 'VL_DESC', 'VL_PIS', 'VL_COFINS', 'COD_CTA'}, {}}
        xC370 = {1:18, {'REG', 'NUM_ITEM', 'COD_ITEM', 'QTD', 'UNID', 'VL_ITEM', 'VL_DESC'}, {}}
        xC380 = {1:18, {'REG', 'COD_MOT_REST_COMPL', 'QUANT_CONV', 'UNID', 'VL_UNIT_ICMS_NA_OPERACAO_CONV', 'VL_UNIT_ICMS_OP_CONV', 'VL_UNIT_ICMS_OP_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_FCP_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_CONV_REST', 'VL_UNIT_FCP_ST_CONV_REST', 'VL_UNIT_ICMS_ST_CONV_COMPL', 'VL_UNIT_FCP_ST_CONV_COMPL', 'CST_ICMS', 'CFOP'}, {}}
        xC390 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_RED_BC', 'COD_OBS'}, {}}
        xC400 = {1:18, {'REG', 'COD_MOD', 'ECF_MOD', 'ECF_FAB', 'ECF_CX'}, {}}
        xC405 = {1:18, {'REG', 'DT_DOC', 'CRO', 'CRZ', 'NUM_COO_FIN', 'GT_FIN', 'VL_BRT'}, {}}
        xC410 = {1:18, {'REG', 'VL_PIS', 'VL_COFINS'}, {}}
        xC420 = {1:18, {'REG', 'COD_TOT_PAR', 'VLR_ACUM_TOT', 'NR_TOT', 'DESCR_NR_TOT'}, {}}
        xC425 = {1:18, {'REG', 'COD_ITEM', 'QTD', 'UNID', 'VL_ITEM', 'VL_PIS', 'VL_COFINS'}, {}}
        xC430 = {1:18, {'REG', 'COD_MOT_REST_COMPL', 'QUANT_CONV', 'UNID', 'VL_UNIT_ICMS_NA_OPERACAO_CONV', 'VL_UNIT_ICMS_OP_CONV', 'VL_UNIT_ICMS_OP_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_FCP_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_CONV_REST', 'VL_UNIT_FCP_ST_CONV_REST', 'VL_UNIT_ICMS_ST_CONV_COMPL', 'VL_UNIT_FCP_ST_CONV_COMPL', 'CST_ICMS', 'CFOP'}, {}}
        xC460 = {1:18, {'REG', 'COD_MOD', 'COD_SIT', 'NUM_DOC', 'DT_DOC', 'VL_DOC', 'VL_PIS', 'VL_COFINS', 'CPF_CNPJ', 'NOM_ADQ'}, {}}
        xC465 = {1:18, {'REG', 'CHV_CFE', 'NUM_CCF'}, {}}
        xC470 = {1:18, {'REG', 'COD_ITEM', 'QTD', 'QTD_CANC', 'UNID', 'VL_ITEM', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_PIS', 'VL_COFINS'}, {}}
        xC480 = {1:18, {'REG', 'COD_MOT_REST_COMPL', 'QUANT_CONV', 'UNID', 'VL_UNIT_ICMS_NA_OPERACAO_CONV', 'VL_UNIT_ICMS_OP_CONV', 'VL_UNIT_ICMS_OP_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_FCP_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_CONV_REST', 'VL_UNIT_FCP_ST_CONV_REST', 'VL_UNIT_ICMS_ST_CONV_COMPL', 'VL_UNIT_FCP_ST_CONV_COMPL', 'CST_ICMS', 'CFOP'}, {}}
        xC490 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'COD_OBS'}, {}}
        xC495 = {1:18, {'REG', 'ALIQ_ICMS', 'COD_ITEM', 'QTD', 'QTD_CANC', 'UNID', 'VL_ITEM', 'VL_DESC', 'VL_CANC', 'VL_ACMO', 'VL_BC_ICMS', 'VL_ICMS', 'VL_ISEN', 'VL_NT', 'VL_ICMS_ST'}, {}}
        xC500 = {1:11, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'COD_CONS', 'NUM_DOC', 'DT_DOC', 'DT_E_S', 'VL_DOC', 'VL_DESC', 'VL_FORN', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'COD_INF', 'VL_PIS', 'VL_COFINS', 'TP_LIGACAO', 'COD_GRUPO_TENSAO'}, {};
                12:13, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'COD_CONS', 'NUM_DOC', 'DT_DOC', 'DT_E_S', 'VL_DOC', 'VL_DESC', 'VL_FORN', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'COD_INF', 'VL_PIS', 'VL_COFINS', 'TP_LIGACAO', 'COD_GRUPO_TENSAO', 'CHV_DOCe', 'FIN_DOCe', 'CHV_DOCe_REF', 'IND_DEST', 'COD_MUN_DEST', 'COD_CTA'}, {};
                14:18, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'COD_CONS', 'NUM_DOC', 'DT_DOC', 'DT_E_S', 'VL_DOC', 'VL_DESC', 'VL_FORN', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'COD_INF', 'VL_PIS', 'VL_COFINS', 'TP_LIGACAO', 'COD_GRUPO_TENSAO', 'CHV_DOCe', 'FIN_DOCe', 'CHV_DOCe_REF', 'IND_DEST', 'COD_MUN_DEST', 'COD_CTA', 'COD_MOD_DOC_REF', 'HASH_DOC_REF', 'SER_DOC_REF', 'NUM_DOC_REF', 'MES_DOC_REF', 'ENER_INJET', 'OUTRAS_DED'}, {}}
        xC510 = {1:18, {'REG', 'NUM_ITEM', 'COD_ITEM', 'COD_CLASS', 'QTD', 'UNID', 'VL_ITEM', 'VL_DESC', 'CST_ICMS', 'CFOP', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'ALIQ_ST', 'VL_ICMS_ST', 'IND_REC', 'COD_PART', 'VL_PIS', 'VL_COFINS', 'COD_CTA'}, {}}
        xC590 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'VL_RED_BC', 'COD_OBS'}, {}}
        xC591 = {1:11, {}, {};
                12:18, {'REG', 'VL_FCP_OP', 'VL_FCP_ST'}, {}}
        xC600 = {1:18, {'REG', 'COD_MOD', 'COD_MUN', 'SER', 'SUB', 'COD_CONS', 'QTD_CONS', 'QTD_CANC', 'DT_DOC', 'VL_DOC', 'VL_DESC', 'CONS', 'VL_FORN', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'VL_PIS', 'VL_COFINS'}, {}}
        xC601 = {1:18, {'REG', 'NUM_DOC_CANC'}, {}}
        xC610 = {1:18, {'REG', 'COD_CLASS', 'COD_ITEM', 'QTD', 'UNID', 'VL_ITEM', 'VL_DESC', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'VL_PIS', 'VL_COFINS', 'COD_CTA'}, {}}
        xC690 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_RED_BC', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'COD_OBS'}, {}}
        xC700 = {1:18, {'REG', 'COD_MOD', 'SER', 'NRO_ORD_INI', 'NRO_ORD_FIN', 'DT_DOC_INI', 'DT_DOC_FIN', 'NOM_MEST', 'CHV_COD_DIG'}, {}}
        xC790 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'VL_RED_BC', 'COD_OBS'}, {}}
        xC791 = {1:18, {'REG', 'UF', 'VL_BC_ICMS_ST', 'VL_ICMS_ST'}, {}}
        xC800 = {1:18, {'REG', 'COD_MOD', 'COD_SIT', 'NUM_CFE', 'DT_DOC', 'VL_CFE', 'VL_PIS', 'VL_COFINS', 'CNPJ_CPF', 'NR_SAT', 'CHV_CFE', 'VL_DESC', 'VL_MERC', 'VL_OUT_DA', 'VL_ICMS', 'VL_PIS_ST', 'VL_COFINS_ST'}, {}}
        xC850 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'COD_OBS'}, {}}
        xC860 = {1:18, {'REG', 'COD_MOD', 'NR_SAT', 'DT_DOC', 'DOC_INI', 'DOC_FIM'}, {}}
        xC890 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'COD_OBS'}, {}}
        xC177 = {1:10, {}, {};
                11:18, {'REG', 'COD_INF_ITEM'}, {}}
        xC181 = {1:12, {}, {};
                13:18, {'REG', 'COD_MOT_REST_COMPL', 'QUANT_CONV', 'UNID', 'COD_MOD_SAIDA', 'SERIE_SAIDA', 'ECF_FAB_SAIDA', 'NUM_DOC_SAIDA', 'CHV_DFE_SAIDA', 'DT_DOC_SAIDA', 'NUM_ITEM_SAIDA', 'VL_UNIT_CONV_SAIDA', 'VL_UNIT_ICMS_OP_ESTOQUE_CONV_SAIDA', 'VL_UNIT_ICMS_ST_ESTOQUE_CONV_SAIDA', 'VL_UNIT_FCP_ICMS_ST_ESTOQUE_CONV_SAIDA', 'VL_UNIT_ICMS_NA_OPERACAO_CONV_SAIDA', 'VL_UNIT_ICMS_OP_CONV_SAIDA', 'VL_UNIT_ICMS_ST_CONV_REST', 'VL_UNIT_FCP_ST_CONV_REST', 'VL_UNIT_ICMS_ST_CONV_COMPL', 'VL_UNIT_FCP_ST_CONV_COMPL'}, {}}
        xC186 = {1:12, {}, {};
                13:18, {'REG', 'NUM_ITEM', 'COD_ITEM', 'CST_ICMS', 'CFOP', 'COD_MOT_REST_COMPL', 'QUANT_CONV', 'UNID', 'COD_MOD_ENTRADA', 'SERIE_ENTRADA', 'NUM_DOC_ENTRADA', 'CHV_DFE_ENTRADA', 'DT_DOC_ENTRADA', 'NUM_ITEM_ENTRADA', 'VL_UNIT_CONV_ENTRADA', 'VL_UNIT_ICMS_OP_CONV_ENTRADA', 'VL_UNIT_BC_ICMS_ST_CONV_ENTRADA', 'VL_UNIT_ICMS_ST_CONV_ENTRADA', 'VL_UNIT_FCP_ST_CONV_ENTRADA'}, {}}
        xC595 = {1:12, {}, {};
                13:18, {'REG', 'COD_OBS', 'TXT_COMPL'}, {}}
        xC597 = {1:12, {}, {};
                13:18, {'REG', 'COD_AJ', 'DESCR_COMPL_AJ', 'COD_ITEM', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_OUTROS'}, {}}
        xC810 = {1:11, {}, {};
                12:18, {'REG', 'NUM_ITEM', 'COD_ITEM', 'QTD', 'UNID', 'VL_ITEM', 'CST_ICMS', 'CFOP'}, {}}
        xC815 = {1:11, {}, {};
                12:18, {'REG', 'COD_MOT_REST_COMPL', 'QUANT_CONV', 'UNID', 'VL_UNIT_ICMS_NA_OPERACAO_CONV', 'VL_UNIT_ICMS_OP_CONV', 'VL_UNIT_ICMS_OP_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_FCP_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_CONV_REST', 'VL_UNIT_FCP_ST_CONV_REST', 'VL_UNIT_ICMS_ST_CONV_COMPL', 'VL_UNIT_FCP_ST_CONV_COMPL'}, {}}
        xC870 = {1:11, {}, {};
                12:18, {'REG', 'COD_ITEM', 'QTD', 'UNID', 'CST_ICMS', 'CFOP'}, {}}
        xC880 = {1:11, {}, {};
                12:18, {'REG', 'COD_MOT_REST_COMPL', 'QUANT_CONV', 'UNID', 'VL_UNIT_ICMS_NA_OPERACAO_CONV', 'VL_UNIT_ICMS_OP_CONV', 'VL_UNIT_ICMS_OP_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_FCP_ICMS_ST_ESTOQUE_CONV', 'VL_UNIT_ICMS_ST_CONV_REST', 'VL_UNIT_FCP_ST_CONV_REST', 'VL_UNIT_ICMS_ST_CONV_COMPL', 'VL_UNIT_FCP_ST_CONV_COMPL'}, {}}
        xC855 = {1:14, {}, {};
                15:18, {'REG', 'COD_OBS', 'TXT_COMPL'}, {}}
        xC857 = {1:14, {}, {};
                15:18, {'REG', 'COD_AJ', 'DESCR_COMPL_AJ', 'COD_ITEM', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_OUTROS'}, {}}
        xC895 = {1:14, {}, {};
                15:18, {'REG', 'COD_OBS', 'TXT_COMPL'}, {}}
        xC897 = {1:14, {}, {};
                15:18, {'REG', 'COD_AJ', 'DESCR_COMPL_AJ', 'COD_ITEM', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_OUTROS'}, {}}
        xC990 = {1:18, {'REG', 'QTD_LIN_C'}, {}}

        % Bloco D: Documentos Fiscais II - ServiÃƒÂ§os (ICMS)
        xD001 = {1:18, {'REG', 'IND_MOV'}, {}}
        xD100 = {1:9, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'NUM_DOC', 'CHV_CTE', 'DT_DOC', 'DT_A_P', 'TP_CT_E', 'CHV_CTE_REF', 'VL_DOC', 'VL_DESC', 'IND_FRT', 'VL_SERV', 'VL_BC_ICMS', 'VL_ICMS', 'VL_NT', 'COD_INF', 'COD_CTA'}, {};
                10:18, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'NUM_DOC', 'CHV_CTE', 'DT_DOC', 'DT_A_P', 'TP_CT_E', 'CHV_CTE_REF', 'VL_DOC', 'VL_DESC', 'IND_FRT', 'VL_SERV', 'VL_BC_ICMS', 'VL_ICMS', 'VL_NT', 'COD_INF', 'COD_CTA', 'COD_MUN_ORIG', 'COD_MUN_DEST'}, {}}
        xD101 = {1:7, {}, {};
                 8:18, {'REG', 'VL_FCP_UF_DEST', 'VL_ICMS_UF_DEST', 'VL_ICMS_UF_REM'}, {}}
        xD110 = {1:18, {'REG', 'NUM_ITEM', 'COD_ITEM', 'VL_SERV', 'VL_OUT'}, {}}
        xD120 = {1:18, {'REG', 'COD_MUN_ORIG', 'COD_MUN_DEST', 'VEIC_ID', 'UF_ID'}, {}}
        xD130 = {1:18, {'REG', 'COD_PART_CONSG', 'COD_PART_RED', 'IND_FRT_RED', 'COD_MUN_ORIG', 'COD_MUN_DEST', 'VEIC_ID', 'VL_LIQ_FRT', 'VL_SEC_CAT', 'VL_DESP', 'VL_PEDG', 'VL_OUT', 'VL_FRT', 'UF_ID'}, {}}
        xD140 = {1:18, {'REG', 'COD_PART_CONSG', 'COD_MUN_ORIG', 'COD_MUN_DEST', 'IND_VEIC', 'VEIC_ID', 'IND_NAV', 'VIAGEM', 'VL_FRT_LIQ', 'VL_DESP_PORT', 'VL_DESP_CAR_DESC', 'VL_OUT', 'VL_FRT_BRT', 'VL_FRT_MM'}, {}}
        xD150 = {1:18, {'REG', 'COD_MUN_ORIG', 'COD_MUN_DEST', 'VEIC_ID', 'VIAGEM', 'IND_TFA', 'VL_PESO_TX', 'VL_TX_TERR', 'VL_TX_RED', 'VL_OUT', 'VL_TX_ADV'}, {}}
        xD160 = {1:18, {'REG', 'DESPACHO', 'CNPJ_CPF_REM', 'IE_REM', 'COD_MUN_ORI', 'CNPJ_CPF_DEST', 'IE_DEST', 'COD_MUN_DEST'}, {}}
        xD161 = {1:18, {'REG', 'IND_CARGA', 'CNPJ_CPF_COL', 'IE_COL', 'COD_MUN_COL', 'CNPJ_CPF_ENTG', 'IE_ENTG', 'COD_MUN_ENTG'}, {}}
        xD162 = {1:18, {'REG', 'COD_MOD', 'SER', 'NUM_DOC', 'DT_DOC', 'VL_DOC', 'VL_MERC', 'QTD_VOL', 'PESO_BRT', 'PESO_LIQ'}, {}}
        xD170 = {1:18, {'REG', 'COD_PART_CONSG', 'COD_PART_RED', 'COD_MUN_ORIG', 'COD_MUN_DEST', 'OTM', 'IND_NAT_FRT', 'VL_LIQ_FRT', 'VL_GRIS', 'VL_PDG', 'VL_OUT', 'VL_FRT', 'VEIC_ID', 'UF_ID'}, {}}
        xD180 = {1:18, {'REG', 'NUM_SEQ', 'IND_EMIT', 'CNPJ_CPF_EMIT', 'UF_EMIT', 'IE_EMIT', 'COD_MUN_ORIG', 'CNPJ_CPF_TOM', 'UF_TOM', 'IE_TOM', 'COD_MUN_DEST', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'VL_DOC'}, {}}
        xD190 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_RED_BC', 'COD_OBS'}, {}}
        xD195 = {1:3, {}, {};
                 4:18, {'REG', 'COD_OBS', 'TXT_COMPL'}, {}}
        xD197 = {1:3, {}, {};
                 4:18, {'REG', 'COD_AJ', 'DESCR_COMPL_AJ', 'COD_ITEM', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_OUTROS'}, {}}
        xD300 = {1:18, {'REG', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC_INI', 'NUM_DOC_FIN', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'DT_DOC', 'VL_OPR', 'VL_DESC', 'VL_SERV', 'VL_SEG', 'VL_OUTDESP', 'VL_BC_ICMS', 'VL_ICMS', 'VL_RED_BC', 'COD_OBS', 'COD_CTA'}, {}}
        xD301 = {1:18, {'REG', 'NUM_DOC_CANC'}, {}}
        xD310 = {1:18, {'REG', 'COD_MUN_ORIG', 'VL_SERV', 'VL_BC_ICMS', 'VL_ICMS'}, {}}
        xD350 = {1:18, {'REG', 'COD_MOD', 'ECF_MOD', 'ECF_FAB', 'ECF_CX'}, {}}
        xD355 = {1:18, {'REG', 'DT_DOC', 'CRO', 'CRZ', 'NUM_COO_FIN', 'GT_FIN', 'VL_BRT'}, {}}
        xD360 = {1:18, {'REG', 'VL_PIS', 'VL_COFINS'}, {}}
        xD365 = {1:18, {'REG', 'COD_TOT_PAR', 'VLR_ACUM_TOT', 'NR_TOT', 'DESCR_NR_TOT'}, {}}
        xD370 = {1:18, {'REG', 'COD_MUN_ORIG', 'VL_SERV', 'QTD_BILH', 'VL_BC_ICMS', 'VL_ICMS'}, {}}
        xD390 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ISSQN', 'ALIQ_ISSQN', 'VL_ISSQN', 'VL_BC_ICMS', 'VL_ICMS', 'COD_OBS'}, {}}
        xD400 = {1:18, {'REG', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'VL_DOC', 'VL_DESC', 'VL_SERV', 'VL_BC_ICMS', 'VL_ICMS', 'VL_PIS', 'VL_COFINS', 'COD_CTA'}, {}}
        xD410 = {1:18, {'REG', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC_INI', 'NUM_DOC_FIN', 'DT_DOC', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_DESC', 'VL_SERV', 'VL_BC_ICMS', 'VL_ICMS'}, {}}
        xD411 = {1:18, {'REG', 'NUM_DOC_CANC'}, {}}
        xD420 = {1:18, {'REG', 'COD_MUN_ORIG', 'VL_SERV', 'VL_BC_ICMS', 'VL_ICMS'}, {}}
        xD500 = {1:18, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'DT_A_P', 'VL_DOC', 'VL_DESC', 'VL_SERV', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'COD_INF', 'VL_PIS', 'VL_COFINS', 'COD_CTA', 'TP_ASSINANTE'}, {}}
        xD510 = {1:18, {'REG', 'NUM_ITEM', 'COD_ITEM', 'COD_CLASS', 'QTD', 'UNID', 'VL_ITEM', 'VL_DESC', 'CST_ICMS', 'CFOP', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_BC_ICMS_UF', 'VL_ICMS_UF', 'IND_REC', 'COD_PART', 'VL_PIS', 'VL_COFINS', 'COD_CTA'}, {}}
        xD530 = {1:18, {'REG', 'IND_SERV', 'DT_INI_SERV', 'DT_FIN_SERV', 'PER_FISCAL', 'COD_AREA', 'TERMINAL'}, {}}
        xD590 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_UF', 'VL_ICMS_UF', 'VL_RED_BC', 'COD_OBS'}, {}}
        xD600 = {1:18, {'REG', 'COD_MOD', 'COD_MUN', 'SER', 'SUB', 'COD_CONS', 'QTD_CONS', 'DT_DOC', 'VL_DOC', 'VL_DESC', 'VL_SERV', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_PIS', 'VL_COFINS'}, {}}
        xD610 = {1:18, {'REG', 'COD_CLASS', 'COD_ITEM', 'QTD', 'UNID', 'VL_ITEM', 'VL_DESC', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_UF', 'VL_ICMS_UF', 'VL_RED_BC', 'VL_PIS', 'VL_COFINS', 'COD_CTA'}, {}}
        xD690 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_UF', 'VL_ICMS_UF', 'VL_RED_BC', 'COD_OBS'}, {}}
        xD695 = {1:18, {'REG', 'COD_MOD', 'SER', 'NRO_ORD_INI', 'NRO_ORD_FIN', 'DT_DOC_INI', 'DT_DOC_FIN', 'NOM_MEST', 'CHV_COD_DIG'}, {}}
        xD696 = {1:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_UF', 'VL_ICMS_UF', 'VL_RED_BC', 'COD_OBS'}, {}}
        xD697 = {1:18, {'REG', 'UF', 'VL_BC_ICMS', 'VL_ICMS'}, {}}
        xD700 = {1:14, {}, {};
                15:16, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'NUM_DOC', 'DT_DOC', 'DT_E_S', 'VL_DOC', 'VL_DESC', 'VL_SERV', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'COD_INF', 'VL_PIS', 'VL_COFINS', 'CHV_DOCE', 'FIN_DOCe', 'TIP_FAT', 'COD_MOD_DOC_REF', 'CHV_DOCe_REF', 'HASH_DOC_REF', 'SER_DOC_REF', 'NUM_DOC_REF', 'MES_DOC_REF', 'COD_MUN_DEST'}, {};
                17:18, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'NUM_DOC', 'DT_DOC', 'DT_E_S', 'VL_DOC', 'VL_DESC', 'VL_SERV', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'COD_INF', 'VL_PIS', 'VL_COFINS', 'CHV_DOCE', 'FIN_DOCe', 'TIP_FAT', 'COD_MOD_DOC_REF', 'CHV_DOCe_REF', 'HASH_DOC_REF', 'SER_DOC_REF', 'NUM_DOC_REF', 'MES_DOC_REF', 'COD_MUN_DEST', 'DED'}, {}}
        xD730 = {1:14, {}, {};
                15:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_RED_BC', 'COD_OBS'}, {}}
        xD731 = {1:14, {}, {};
                15:18, {'REG', 'VL_FCP_OP'}, {}}
        xD735 = {1:14, {}, {};
                15:18, {'REG', 'COD_OBS', 'TXT_COMPL'}, {}}
        xD737 = {1:14, {}, {};
                15:18, {'REG', 'COD_AJ', 'DESCR_COMPL_AJ', 'COD_ITEM', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_OUTROS'}, {}}
        xD750 = {1:14, {}, {};
                15:16, {'REG', 'COD_MOD', 'SER', 'DT_DOC', 'QTD_CONS', 'IND_PREPAGO', 'VL_DOC', 'VL_SERV', 'VL_SERV_NT', 'VL_TERC', 'VL_DESC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_PIS', 'VL_COFINS'}, {};
                17:18, {'REG', 'COD_MOD', 'SER', 'DT_DOC', 'QTD_CONS', 'IND_PREPAGO', 'VL_DOC', 'VL_SERV', 'VL_SERV_NT', 'VL_TERC', 'VL_DESC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_PIS', 'VL_COFINS', 'DED'}, {}}
        xD760 = {1:14, {}, {};
                15:18, {'REG', 'CST_ICMS', 'CFOP', 'ALIQ_ICMS', 'VL_OPR', 'VL_BC_ICMS', 'VL_ICMS', 'VL_RED_BC', 'COD_OBS'}, {}}
        xD761 = {1:14, {}, {};
                15:18, {'REG', 'VL_FCP_OP'}, {}}
        xD990 = {1:18, {'REG', 'QTD_LIN_D'}, {}}

        % Bloco E: ApuraÃƒÂ§ÃƒÂ£o do ICMS e do IPI
        xE001 = {1:18, {'REG', 'IND_MOV'}, {}}
        xE100 = {1:18, {'REG', 'DT_INI', 'DT_FIN'}, {}}
        xE110 = {1:18, {'REG', 'VL_TOT_DEBITOS', 'VL_AJ_DEBITOS', 'VL_TOT_AJ_DEBITOS', 'VL_ESTORNOS_CRED', 'VL_TOT_CREDITOS', 'VL_AJ_CREDITOS', 'VL_TOT_AJ_CREDITOS', 'VL_ESTORNOS_DEB', 'VL_SLD_CREDOR_ANT', 'VL_SLD_APURADO', 'VL_TOT_DED', 'VL_ICMS_RECOLHER', 'VL_SLD_CREDOR_TRANSPORTAR', 'DEB_ESP'}, {}}
        xE111 = {1:18, {'REG', 'COD_AJ_APUR', 'DESCR_COMPL_AJ', 'VL_AJ_APUR'}, {}}
        xE112 = {1:18, {'REG', 'NUM_DA', 'NUM_PROC', 'IND_PROC', 'PROC', 'TXT_COMPL'}, {}}
        xE113 = {1:8, {'REG', 'COD_PART', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'COD_ITEM', 'VL_AJ_ITEM'}, {};
             9:18, {'REG', 'COD_PART', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'COD_ITEM', 'VL_AJ_ITEM', 'CHV_DOCE'}, {}}
        xE115 = {1:18, {'REG', 'COD_INF_ADIC', 'VL_INF_ADIC', 'DESCR_COMPL_AJ'}, {}}
        xE116 = {1, {'REG', 'COD_OR', 'VL_OR', 'DT_VCTO', 'COD_REC', 'NUM_PROC', 'IND_PROC', 'PROC', 'TXT_COMPL'}, {};
             2:18, {'REG', 'COD_OR', 'VL_OR', 'DT_VCTO', 'COD_REC', 'NUM_PROC', 'IND_PROC', 'PROC', 'TXT_COMPL', 'MES_REF'}, {}}
        xE200 = {1:18, {'REG', 'UF', 'DT_INI', 'DT_FIN'}, {}}
        xE210 = {1:18, {'REG', 'IND_MOV_ST', 'VL_SLD_CRED_ANT_ST', 'VL_DEVOL_ST', 'VL_RESSARC_ST', 'VL_OUT_CRED_ST', 'VL_AJ_CREDITOS_ST', 'VL_RETENCAO_ST', 'VL_OUT_DEB_ST', 'VL_AJ_DEBITOS_ST', 'VL_SLD_DEV_ANT_ST', 'VL_DEDUCOES_ST', 'VL_ICMS_RECOL_ST', 'VL_SLD_CRED_ST_TRANSPORTAR', 'DEB_ESP_ST'}, {}}
        xE220 = {1:18, {'REG', 'COD_AJ_APUR', 'DESCR_COMPL_AJ', 'VL_AJ_APUR'}, {}}
        xE230 = {1:18, {'REG', 'NUM_DA', 'NUM_PROC', 'IND_PROC', 'PROC', 'TXT_COMPL'}, {}}
        xE240 = {1:7, {}, {};
             8, {'REG', 'COD_PART', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'COD_ITEM', 'VL_AJ_ITEM'}, {};
             9:18, {'REG', 'COD_PART', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'COD_ITEM', 'VL_AJ_ITEM', 'CHV_DOCE'}, {}}
        xE250 = {1, {'REG', 'COD_OR', 'VL_OR', 'DT_VCTO', 'COD_REC', 'NUM_PROC', 'IND_PROC', 'PROC', 'TXT_COMPL'}, {};
             2:18, {'REG', 'COD_OR', 'VL_OR', 'DT_VCTO', 'COD_REC', 'NUM_PROC', 'IND_PROC', 'PROC', 'TXT_COMPL', 'MES_REF'}, {}}
        xE300 = {1:7, {}, {};
             8:18, {'REG', 'UF', 'DT_INI', 'DT_FIN'}, {}}
        xE310 = {1:7, {}, {};
             8, {'REG', 'IND_MOV_FCP_DIFAL', 'VL_SLD_CRED_ANT_DIFAL', 'VL_TOT_DEBITOS_DIFAL', 'VL_OUT_DEB_DIFAL', 'VL_TOT_CREDITOS_DIFAL', 'VL_OUT_CRED_DIFAL', 'VL_SLD_DEV_ANT_DIFAL', 'VL_DEDUCOES_DIFAL', 'VL_RECOL_DIFAL', 'VL_SLD_CRED_TRANSPORTAR_DIFAL', 'DEB_ESP_DIFAL'}, {};
             9:18, {'REG', 'IND_MOV_FCP_DIFAL', 'VL_SLD_CRED_ANT_DIFAL', 'VL_TOT_DEBITOS_DIFAL', 'VL_OUT_DEB_DIFAL', 'VL_TOT_CREDITOS_DIFAL', 'VL_OUT_CRED_DIFAL', 'VL_SLD_DEV_ANT_DIFAL', 'VL_DEDUCOES_DIFAL', 'VL_RECOL_DIFAL', 'VL_SLD_CRED_TRANSPORTAR_DIFAL', 'DEB_ESP_DIFAL', 'VL_SLD_CRED_ANT_FCP', 'VL_TOT_DEB_FCP', 'VL_OUT_DEB_FCP', 'VL_TOT_CRED_FCP', 'VL_OUT_CRED_FCP', 'VL_SLD_DEV_ANT_FCP', 'VL_DEDUCOES_FCP', 'VL_RECOL_FCP', 'VL_SLD_CRED_TRANSPORTAR_FCP', 'DEB_ESP_FCP'}, {}}
        xE311 = {1:7, {}, {};
             8:18, {'REG', 'COD_AJ_APUR', 'DESCR_COMPL_AJ', 'VL_AJ_APUR'}, {}}
        xE312 = {1:7, {}, {};
             8:18, {'REG', 'NUM_DA', 'NUM_PROC', 'IND_PROC', 'PROC', 'TXT_COMPL'}, {}}
        xE313 = {1:7, {}, {};
             8, {'REG', 'COD_PART', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'COD_ITEM', 'VL_AJ_ITEM'}, {};
             9:18, {'REG', 'COD_PART', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'CHV_DOCE', 'DT_DOC', 'COD_ITEM', 'VL_AJ_ITEM'}, {}}
        xE316 = {1:7, {}, {};
             8:18, {'REG', 'COD_OR', 'VL_OR', 'DT_VCTO', 'COD_REC', 'NUM_PROC', 'IND_PROC', 'PROC', 'TXT_COMPL', 'MES_REF'}, {}}
        xE500 = {1:18, {'REG', 'IND_APUR', 'DT_INI', 'DT_FIN'}, {}}
        xE510 = {1:18, {'REG', 'CFOP', 'CST_IPI', 'VL_CONT_IPI', 'VL_BC_IPI', 'VL_IPI'}, {}}
        xE520 = {1:18, {'REG', 'VL_SD_ANT_IPI', 'VL_DEB_IPI', 'VL_CRED_IPI', 'VL_OD_IPI', 'VL_OC_IPI', 'VL_SC_IPI', 'VL_SD_IPI'}, {}}
        xE530 = {1:18, {'REG', 'IND_AJ', 'VL_AJ', 'COD_AJ', 'IND_DOC', 'NUM_DOC', 'DESCR_AJ'}, {}}
        xE531 = {1:9, {}, {};
             10:18, {'REG', 'COD_PART', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'COD_ITEM', 'VL_AJ_ITEM', 'CHV_NFE'}, {}}
        xE990 = {1:18, {'REG', 'QTD_LIN_E'}, {}}

        % Bloco G, H e K
        xG001 = {1, {}, {};
             2:18, {'REG', 'IND_MOV'}, {}}
        xG110 = {1, {}, {};
             2:18, {'REG', 'DT_INI', 'DT_FIN', 'SALDO_IN_ICMS', 'SOM_PARC', 'VL_TRIB_EXP', 'VL_TOTAL', 'IND_PER_SAI', 'ICMS_APROP', 'SOM_ICMS_OC'}, {}}
        xG125 = {1, {}, {};
             2:18, {'REG', 'COD_IND_BEM', 'DT_MOV', 'TIPO_MOV', 'VL_IMOB_ICMS_OP', 'VL_IMOB_ICMS_ST', 'VL_IMOB_ICMS_FRT', 'VL_IMOB_ICMS_DIF', 'NUM_PARC', 'VL_PARC_PASS'}, {}}
        xG126 = {1, {}, {};
             2:18, {'REG', 'DT_INI', 'DT_FIM', 'NUM_PARC', 'VL_PARC_PASS', 'VL_TRIB_OC', 'VL_TOTAL', 'IND_PER_SAI', 'VL_PARC_APROP'}, {}}
        xG130 = {1, {}, {};
             2:11, {'REG', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'SERIE', 'NUM_DOC', 'CHV_NFE_CTE', 'DT_DOC'}, {};
             12:18, {'REG', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'SERIE', 'NUM_DOC', 'CHV_NFE_CTE', 'DT_DOC', 'NUM_DA'}, {}}
        xG140 = {1, {}, {};
             2:11, {'REG', 'NUM_ITEM', 'COD_ITEM'}, {};
             12:18, {'REG', 'NUM_ITEM', 'COD_ITEM', 'QTDE', 'UNID', 'VL_ICMS_OP_APLICADO', 'VL_ICMS_ST_APLICADO', 'VL_ICMS_FRT_APLICADO', 'VL_ICMS_DIF_APLICADO'}, {}}
        xG990 = {1, {}, {};
             2:18, {'REG', 'QTD_LIN_G'}, {}}

        xH001 = {1:18, {'REG', 'IND_MOV'}, {}}
        xH005 = {1:3,  {'REG', 'DT_INV', 'VL_INV'}, {};
             4:18, {'REG', 'DT_INV', 'VL_INV', 'MOT_INV'}, {}}
        xH010 = {1:6,  {'REG', 'COD_ITEM', 'UNID', 'QTD', 'VL_UNIT', 'VL_ITEM', 'IND_PROP', 'COD_PART', 'TXT_COMPL', 'COD_CTA'}, {};
             7:18, {'REG', 'COD_ITEM', 'UNID', 'QTD', 'VL_UNIT', 'VL_ITEM', 'IND_PROP', 'COD_PART', 'TXT_COMPL', 'COD_CTA', 'VL_ITEM_IR'}, {}}
        xH020 = {1:3, {}, {};
             4:18, {'REG', 'CST_ICMS', 'BC_ICMS', 'VL_ICMS'}, {}}
        xH030 = {1:11, {}, {};
             12:18, {'REG', 'VL_ICMS_OP', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'VL_FCP'}, {}}
        xH990 = {1:18, {'REG', 'QTD_LIN_H'}, {}}

        xK001 = {1:7, {}, {};
             8:18, {'REG', 'IND_MOV'}, {}}
        xK010 = {1:14, {}, {};
             15:18, {'REG', 'IND_TP_LEIAUTE'}, {}}
        xK100 = {1:7, {}, {};
             8:18, {'REG', 'DT_INI', 'DT_FIN'}, {}}
        xK200 = {1:7, {}, {};
             8:18, {'REG', 'DT_EST', 'COD_ITEM', 'QTD', 'IND_EST', 'COD_PART'}, {}}
        xK210 = {1:8, {}, {};
             9:18, {'REG', 'DT_INI_OS', 'DT_FIN_OS', 'COD_DOC_OS', 'COD_ITEM_ORI', 'QTD_ORI'}, {}}
        xK215 = {1:8, {}, {};
             9:18, {'REG', 'COD_ITEM_DES', 'QTD_DES'}, {}}
        xK220 = {1:7, {}, {};
             8:9, {'REG', 'DT_MOV', 'COD_ITEM_ORI', 'COD_ITEM_DEST', 'QTD_ORI'}, {};
             10:18, {'REG', 'DT_MOV', 'COD_ITEM_ORI', 'COD_ITEM_DEST', 'QTD_ORI', 'QTD_DEST'}, {}}
        xK230 = {1:7, {}, {};
             8:18, {'REG', 'DT_INI_OP', 'DT_FIN_OP', 'COD_DOC_OP', 'COD_ITEM', 'QTD_ENC'}, {}}
        xK235 = {1:7, {}, {};
             8:18, {'REG', 'DT_SAIDA', 'COD_ITEM', 'QTD', 'COD_INS_SUBST'}, {}}
        xK250 = {1:7, {}, {};
             8:18, {'REG', 'DT_PROD', 'COD_ITEM', 'QTD'}, {}}
        xK255 = {1:7, {}, {};
             8:18, {'REG', 'DT_CONS', 'COD_ITEM', 'QTD', 'COD_INS_SUBST'}, {}}
        xK260 = {1:8, {}, {};
             9:18, {'REG', 'COD_OP_OS', 'COD_ITEM', 'DT_SAIDA', 'QTD_SAIDA', 'DT_RET', 'QTD_RET'}, {}}
        xK265 = {1:8, {}, {};
             9:18, {'REG', 'COD_ITEM', 'QTD_CONS', 'QTD_RET'}, {}}
        xK270 = {1:8, {}, {};
             9:18, {'REG', 'DT_INI_AP', 'DT_FIN_AP', 'COD_OP_OS', 'COD_ITEM', 'QTD_COR_POS', 'QTD_COR_NEG', 'ORIGEM'}, {}}
        xK275 = {1:8, {}, {};
             9:18, {'REG', 'COD_ITEM', 'QTD_COR_POS', 'QTD_COR_NEG', 'COD_INS_SUBST'}, {}}
        xK280 = {1:8, {}, {};
             9:18, {'REG', 'DT_EST', 'COD_ITEM', 'QTD_COR_POS', 'QTD_COR_NEG', 'IND_EST', 'COD_PART'}, {}}
        xK290 = {1:10, {}, {};
             11:18, {'REG', 'DT_INI_OP', 'DT_FIN_OP', 'COD_DOC_OP'}, {}}
        xK291 = {1:10, {}, {};
             11:18, {'REG', 'COD_ITEM', 'QTD'}, {}}
        xK292 = {1:10, {}, {};
             11:18, {'REG', 'COD_ITEM', 'QTD'}, {}}
        xK300 = {1:10, {}, {};
             11:18, {'REG', 'DT_PROD'}, {}}
        xK301 = {1:10, {}, {};
             11:18, {'REG', 'COD_ITEM', 'QTD'}, {}}
        xK302 = {1:10, {}, {};
             11:18, {'REG', 'COD_ITEM', 'QTD'}, {}}
        xK990 = {1:7, {}, {};
             8:18, {'REG', 'QTD_LIN_K'}, {}}

        % Bloco 1 e Bloco 9
        x1001 = {1:18, {'REG', 'IND_MOV'}, {}}
        x1010 = {1:3, {}, {};
             4:11, {'REG', 'IND_EXP', 'IND_CCRF', 'IND_COMB', 'IND_USINA', 'IND_VA', 'IND_EE', 'IND_CART', 'IND_FORM', 'IND_AER', 'IND_GIAF1', 'IND_GIAF3', 'IND_GIAF4'}, {};
             12:18, {'REG', 'IND_EXP', 'IND_CCRF', 'IND_COMB', 'IND_USINA', 'IND_VA', 'IND_EE', 'IND_CART', 'IND_FORM', 'IND_AER', 'IND_GIAF1', 'IND_GIAF3', 'IND_GIAF4', 'IND_REST_RESSARC_COMPL_ICMS'}, {}}
        x1100 = {1:18, {'REG', 'IND_DOC', 'NRO_DE', 'DT_DE', 'NAT_EXP', 'NRO_RE', 'DT_RE', 'CHC_EMB', 'DT_CHC', 'DT_AVB', 'TP_CHC', 'PAIS'}, {}}
        x1105 = {1:18, {'REG', 'COD_MOD', 'SERIE', 'NUM_DOC', 'CHV_NFE', 'DT_DOC', 'COD_ITEM'}, {}}
        x1110 = {1:18, {'REG', 'COD_PART', 'COD_MOD', 'SER', 'NUM_DOC', 'DT_DOC', 'CHV_NFE', 'NR_MEMO', 'QTD', 'UNID'}, {}}
        x1200 = {1:18, {'REG', 'COD_AJ_APUR', 'SLD_CRED', 'CRED_APR', 'CRED_RECEB', 'CRED_UTIL', 'SLD_CRED_FIM'}, {}}
        x1210 = {1:8, {'REG', 'TIPO_UTI', 'NR_DOC', 'VL_CRED_UTIL'}, {};
             9:18, {'REG', 'TIPO_UTI', 'NR_DOC', 'VL_CRED_UTIL', 'CHV_DOCE'}, {}}
        x1250 = {1:11, {}, {};
             12:18, {'REG', 'VL_CREDITO_ICMS_OP', 'VL_ICMS_ST_REST', 'VL_FCP_ST_REST', 'VL_ICMS_ST_COMPL', 'VL_FCP_ST_COMPL'}, {}}
        x1255 = {1:11, {}, {};
             12:18, {'REG', 'COD_MOT_REST_COMPL', 'VL_CREDITO_ICMS_OP_MOT', 'VL_ICMS_ST_REST_MOT', 'VL_FCP_ST_REST_MOT', 'VL_ICMS_ST_COMPL_MOT', 'VL_FCP_ST_COMPL_MOT'}, {}}
        x1300 = {1:18, {'REG', 'COD_ITEM', 'DT_FECH', 'ESTQ_ABERT', 'VOL_ENTR', 'VOL_DISP', 'VOL_SAIDAS', 'ESTQ_ESCR', 'VAL_AJ_PERDA', 'VAL_AJ_GANHO', 'FECH_FISICO'}, {}}
        x1310 = {1:17, {'REG', 'NUM_TANQUE', 'ESTQ_ABERT', 'VOL_ENTR', 'VOL_DISP', 'VOL_SAIDAS', 'ESTQ_ESCR', 'VAL_AJ_PERDA', 'VAL_AJ_GANHO', 'FECH_FISICO'}, {};
             18, {'REG', 'NUM_TANQUE', 'ESTQ_ABERT', 'VOL_ENTR', 'VOL_DISP', 'VOL_SAIDAS', 'ESTQ_ESCR', 'VAL_AJ_PERDA', 'VAL_AJ_GANHO', 'FECH_FISICO', 'CAP_TANQUE'}, {}}
        x1320 = {1:18, {'REG', 'NUM_BICO', 'NR_INTERV', 'MOT_INTERV', 'NOM_INTERV', 'CNPJ_INTERV', 'CPF_INTERV', 'VAL_FECHA', 'VAL_ABERT', 'VOL_AFERI', 'VOL_VENDAS'}, {}}
        x1350 = {1:18, {'REG', 'SERIE', 'FABRICANTE', 'MODELO', 'TIPO_MEDICAO'}, {}}
        x1360 = {1:18, {'REG', 'NUM_LACRE', 'DT_APLICACAO'}, {}}
        x1370 = {1:18, {'REG', 'NUM_BICO', 'COD_ITEM', 'NUM_TANQUE'}, {}}
        x1390 = {1:3, {}, {};
             4:18, {'REG', 'COD_PROD'}, {}}
        x1391 = {1:3, {}, {};
             4:11, {'REG', 'DT_REGISTRO', 'QTD_MOID', 'ESTQ_INI', 'QTD_PRODUZ', 'ENT_ANID_HID', 'OUTR_ENTR', 'PERDA', 'CONS', 'SAI_ANI_HID', 'SAIDAS', 'ESTQ_FIN', 'ESTQ_INI_MEL', 'PROD_DIA_MEL', 'UTIL_MEL', 'PROD_ALC_MEL', 'OBS'}, {};
             12:15, {'REG', 'DT_REGISTRO', 'QTD_MOID', 'ESTQ_INI', 'QTD_PRODUZ', 'ENT_ANID_HID', 'OUTR_ENTR', 'PERDA', 'CONS', 'SAI_ANI_HID', 'SAIDAS', 'ESTQ_FIN', 'ESTQ_INI_MEL', 'PROD_DIA_MEL', 'UTIL_MEL', 'PROD_ALC_MEL', 'OBS', 'COD_ITEM', 'TP_RESIDUO', 'QTD_RESIDUO'}, {};
             16:18, {'REG', 'DT_REGISTRO', 'QTD_MOID', 'ESTQ_INI', 'QTD_PRODUZ', 'ENT_ANID_HID', 'OUTR_ENTR', 'PERDA', 'CONS', 'SAI_ANI_HID', 'SAIDAS', 'ESTQ_FIN', 'ESTQ_INI_MEL', 'PROD_DIA_MEL', 'UTIL_MEL', 'PROD_ALC_MEL', 'OBS', 'COD_ITEM', 'TP_RESIDUO', 'QTD_RESIDUO', 'QTD_RESIDUO_DDG', 'QTD_RESIDUO_WDG', 'QTD_RESIDUO_CANA'}, {}}
        x1400 = {1:18, {'REG', 'COD_ITEM_IP', 'MUN', 'VALOR'}, {}}
        x1500 = {1:18, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'COD_CONS', 'NUM_DOC', 'DT_DOC', 'DT_E_S', 'VL_DOC', 'VL_DESC', 'VL_FORN', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'COD_INF', 'VL_PIS', 'VL_COFINS', 'TP_LIGACAO', 'COD_GRUPO_TENSAO'}, {}}
        x1510 = {1:18, {'REG', 'NUM_ITEM', 'COD_ITEM', 'COD_CLASS', 'QTD', 'UNID', 'VL_ITEM', 'VL_DESC', 'CST_ICMS', 'CFOP', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'ALIQ_ST', 'VL_ICMS_ST', 'IND_REC', 'COD_PART', 'VL_PIS', 'VL_COFINS', 'COD_CTA'}, {}}
        x1600 = {1:13, {'REG', 'COD_PART', 'TOT_CREDITO', 'TOT_DEBITO'}, {}}
        x1601 = {1:13, {}, {};
             14:18, {'REG', 'COD_PART_IP', 'COD_PART_IT', 'TOT_VS', 'TOT_ISS', 'TOT_OUTROS'}, {}}
        x1700 = {1:18, {'REG', 'COD_DISP', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC_INI', 'NUM_DOC_FIN', 'NUM_AUT'}, {}}
        x1710 = {1:18, {'REG', 'NUM_DOC_INI', 'NUM_DOC_FIN'}, {}}
        x1800 = {1:18, {'REG', 'VL_CARGA', 'VL_PASS', 'VL_FAT', 'IND_RAT', 'VL_ICMS_ANT', 'VL_BC_ICMS', 'VL_ICMS_APUR', 'VL_BC_ICMS_APUR', 'VL_DIF'}, {}}
        x1900 = {1, {}, {};
             2:18, {'REG', 'IND_APUR_ICMS', 'DESCR_COMPL_OUT_APUR'}, {}}
        x1910 = {1, {}, {};
             2:18, {'REG', 'DT_INI', 'DT_FIN'}, {}}
        x1920 = {1, {}, {};
             2:18, {'REG', 'VL_TOT_TRANSF_DEBITOS_OA', 'VL_TOT_AJ_DEBITOS_OA', 'VL_ESTORNOS_CRED_OA', 'VL_TOT_TRANSF_CREDITOS_OA', 'VL_TOT_AJ_CREDITOS_OA', 'VL_ESTORNOS_DEB_OA', 'VL_SLD_CREDOR_ANT_OA', 'VL_SLD_APURADO_OA', 'VL_TOT_DED', 'VL_ICMS_RECOLHER_OA', 'VL_SLD_CREDOR_TRANSP_OA', 'DEB_ESP_OA'}, {}}
        x1921 = {1, {}, {};
             2:18, {'REG', 'COD_AJ_APUR', 'DESCR_COMPL_AJ', 'VL_AJ_APUR'}, {}}
        x1922 = {1, {}, {};
             2:18, {'REG', 'NUM_DA', 'NUM_PROC', 'IND_PROC', 'PROC', 'TXT_COMPL'}, {}}
        x1923 = {1, {}, {};
             2:8, {'REG', 'COD_PART', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'COD_ITEM', 'VL_AJ_ITEM'}, {};
             9:18, {'REG', 'COD_PART', 'COD_MOD', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'COD_ITEM', 'VL_AJ_ITEM', 'CHV_DOCE'}, {}}
        x1925 = {1, {}, {};
             2:18, {'REG', 'COD_INF_ADIC', 'VL_INF_ADIC', 'DESCR_COMPL_AJ'}, {}}
        x1926 = {1, {}, {};
             2:18, {'REG', 'COD_OR', 'VL_OR', 'DT_VCTO', 'COD_REC', 'NUM_PROC', 'IND_PROC', 'PROC', 'TXT_COMPL', 'MES_REF'}, {}}
        x1960 = {1:10, {}, {};
             11:18, {'REG', 'IND_AP', 'G1_01', 'G1_02', 'G1_03', 'G1_04', 'G1_05', 'G1_06', 'G1_07', 'G1_08', 'G1_09', 'G1_10', 'G1_11'}, {}}
        x1970 = {1:10, {}, {};
             11:18, {'REG', 'IND_AP', 'G3_01', 'G3_02', 'G3_03', 'G3_04', 'G3_05', 'G3_06', 'G3_07', 'G3_08', 'G3_09'}, {}}
        x1975 = {1:10, {}, {};
             11:18, {'REG', 'ALIQ_IMP_BASE', 'G3_10', 'G3_11', 'G3_12'}, {}}
        x1980 = {1:10, {}, {};
             11:18, {'REG', 'IND_AP', 'G4_01', 'G4_02', 'G4_03', 'G4_04', 'G4_05', 'G4_06', 'G4_07', 'G4_08', 'G4_09', 'G4_10', 'G4_11', 'G4_12'}, {}}
        x1990 = {1:18, {'REG', 'QTD_LIN_1'}, {}}

        x9001 = {1:18, {'REG', 'IND_MOV'}, {}}
        x9900 = {1:18, {'REG', 'REG_BLC', 'QTD_REG_BLC'}, {}}
        x9990 = {1:18, {'REG', 'QTD_LIN_9'}, {}}
        x9999 = {1:18, {'REG', 'QTD_LIN'}, {}}
    end

    properties (Constant)
        %-------------------------------------------------------%
        % CAMPOS RELACIONADOS Ãƒâ‚¬S TABELAS SOB ANÃƒÂLISE
        % InformaÃƒÂ§ÃƒÂ£o ordenada pelos campos "DataType" e "Field".
        % Os campos "01" a "12", "TOTAL", "DESCRIÃƒâ€¡ÃƒÆ’O" e 
        %-------------------------------------------------------%
        FieldSpecification = cell2table({ ...
            'ARQ_RTF',                          'cell',         [],     'SequÃƒÂªncia de bytes que representem um ÃƒÂºnico arquivo no formato RTF (Rich Text Format).';
            '01',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '02',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '03',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '04',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '05',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '06',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '07',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '08',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '09',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '10',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '11',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            '12',                               'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            'AlÃƒÂ­quota ICMS',                 'cell',         [],     'Campo da tabela customizada "x_CONTAS_ANOTACAO"';
            'ALIQ_COFINS',                      'double',       'bank', 'Alíquota do COFINS (em percentual) N 008 04 OC OC';
            'ALIQ_COFINS_R',                    'double',       'bank', 'Alíquota do COFINS (em reais).';
            'ALIQ_ICMS',                        'double',       'bank', 'Alíquota de ICMS aplicável ao item nas operações internas';
            'ALIQ_ICMS_ULT_E',                  'double',       'bank', 'Alíquota do ICMS aplicável à última entrada da mercadoria';
            'ALIQ_IPI',                         'double',       'bank', 'Alíquota do IPI N 006 02 OC OC';
            'ALIQ_ISS',                         'double',       'bank', 'Alíquota do ISS N - 02 O O';
            'ALIQ_ISSQN',                       'double',       'bank', 'Alíquota do ISSQN';
            'ALIQ_PIS',                         'double',       'bank', 'Alíquota do PIS (em percentual) N 008 04 OC OC';
            'ALIQ_PIS_R',                       'double',       'bank', 'Alíquota do PIS (em reais).';
            'ALIQ_ST',                          'double',       'bank', 'Alíquota do ICMS da substituição tributária na unidade da federação de destino N - 02 OC OC';
            'ALIQ_ST_ULT_E',                    'double',       'bank', 'Alíquota do ICMS ST relativa à última entrada da mercadoria';
            'Apurado?  Ã¢Å“Å½',                 'categorical',  [],     'Campo da tabela customizada "x_CONTAS_ANOTACAO"';
            'ARQ_RTF',                          'cell',         [],     'SequÃƒÂªncia de bytes que representem um ÃƒÂºnico arquivo no formato RTF (Rich Text Format).';
            'BAIRRO',                           'cell',         [],     'Bairro em que o imóvel está situado.';
            'BC_RET',                           'cell',         [],     'Valor da BC de retenção em remessa promovida por Substituído intermediário';
            'BC_ST_ORIG_DEST',                  'cell',         [],     'Valor da base de cálculo ST na origem/destino em operações interestaduais.';
            'CAB_DEM',                          'cell',         [],     'CabeÃƒÂ§alho das demonstraÃƒÂ§ÃƒÂµes.';
            'CAMPO',                            'cell',         [],     'Nome do campo adicional.';
            'CCUS',                             'cell',         [],     'Nome do centro de custos.';
            'CEST',                             'cell',         [],     'Codigo Especificador da Substituicao Tributaria.';
            'CEP',                              'cell',         [],     'Código de Endereçamento Postal.';
            'CFOP',                             'cell',         [],     'Código Fiscal de Operação e Prestação, conforme a tabela indicada no item 4.2.2 N 004* - O O';
            'CHASSI_VEIC',                      'cell',         [],     'Chassi do veículo C 017 - O O';
            'CHAVE_NFE_RET',                    'cell',         [],     'Número completo da chave da NF-e emitida pelo substituto, na qual consta o valor do ICMS ST retido';
            'CHAVE_NFE_ULT_E',                  'cell',         [],     'Chave da NF-e relativa à última entrada.';
            'CHC_EMB',                          'cell',         [],     'Nº do conhecimento de embarque';
            'CHV_CFE',                          'cell',         [],     'Chave do Cupom Fiscal Eletrônico N 044 - O O';
            'CHV_COD_DIG',                      'cell',         [],     'Chave de codificação digital do arquivo Mestre de Documento Fiscal';
            'CHV_CTE',                          'cell',         [],     'Chave do Conhecimento de Transporte Eletrônico ou do Bilhete de Passagem Eletrônico N 044* - OC OC';
            'CHV_CTE_REF',                      'cell',         [],     'Chave do Documento Eletrônico Substituído N 044* - OC OC';
            'CHV_DOCe',                         'cell',         [],     'Chave do documento eletronico.';
            'CHV_DOCe_REF',                     'cell',         [],     'Chave do documento fiscal eletronico referenciado.';
            'CHV_DOCE',                         'cell',         [],     'Chave do documento eletrônico (DF-e).';
            'CHV_NFE',                          'cell',         [],     'Chave da Nota Fiscal Eletrônica N 044* - OC OC';
            'CL_ENQ',                           'cell',         [],     'Código da classe de enquadramento do IPI, conforme Tabela 4.5.1.';
            'CNPJ',                             'cell',         [],     'NÃƒÂºmero de inscriÃƒÂ§ÃƒÂ£o da pessoa jurÃƒÂ­dica no CNPJ. ObservaÃƒÂ§ÃƒÂ£o: Esse CNPJ ÃƒÂ© sempre da SÃƒÂ³cia Ostensiva, no caso do arquivo da SCP.';
            'CNPJ_COL',                         'cell',         [],     'Número do CNPJ do contribuinte do local de coleta';
            'CNPJ_CPF',                         'cell',         [],     'CNPJ ou CPF do destinatário';
            'CNPJ_CPF_COL',                     'cell',         [],     'Número do CNPJ ou CPF do local da coleta';
            'CNPJ_CPF_DEST',                    'cell',         [],     'CNPJ ou CPF do destinatário das mercadorias que constam na nota fiscal.';
            'CNPJ_CPF_EMIT',                    'cell',         [],     'CNPJ ou CPF do participante emitente do modal';
            'CNPJ_CPF_ENTG',                    'cell',         [],     'Número do CNPJ ou CPF do local da entrega';
            'CNPJ_CPF_REM',                     'cell',         [],     'CNPJ ou CPF do remetente das mercadorias que constam na nota fiscal.';
            'CNPJ_CPF_TOM',                     'cell',         [],     'CNPJ/CPF do participante tomador do serviço';
            'CNPJ_ECD_REC',                     'cell',         [],     'CNPJ da ECD recuperada.';
            'CNPJ_ENTG',                        'cell',         [],     'Número do CNPJ do contribuinte do local de entrega';
            'CNPJ_INTERV',                      'cell',         [],     'CNPJ da empresa responsável pela intervenção';
            'COD_AGL',                          'cell',         [],     'CÃƒÂ³digo de aglutinaÃƒÂ§ÃƒÂ£o das linhas, atribuÃƒÂ­do pela pessoa jurÃƒÂ­dica.';
            'COD_AGL_SUP',                      'cell',         [],     'CÃƒÂ³digo de aglutinaÃƒÂ§ÃƒÂ£o sintÃƒÂ©tico/grupo de cÃƒÂ³digo de aglutinaÃƒÂ§ÃƒÂ£o de nÃƒÂ­vel superior.';
            'COD_AJ',                           'cell',         [],     'Código dos ajustes/benefício/incentivo, conforme tabela indicada no item 5.3. C 010* - O O';
            'COD_AJ_APUR',                      'cell',         [],     'Código do ajuste da SUB-APURAÇÃO e dedução, conforme a Tabela indicada no item 5.1.1.';
            'COD_ANT_ITEM',                     'cell',         [],     'Código anterior do item com relação à última informação apresentada. C 060 - N (informar no 0205)';
            'COD_AREA',                         'cell',         [],     'Código de área do terminal faturado';
            'COD_ASSIN',                        'cell',         [],     'CÃƒÂ³digo de qualificaÃƒÂ§ÃƒÂ£o do assinante, conforme tabela.';
            'COD_ASSIN_T',                      'cell',         [],     'CÃƒÂ³digo de qualificaÃƒÂ§ÃƒÂ£o do assinante do termo de verificaÃƒÂ§ÃƒÂ£o, conforme tabela.';
            'COD_AUT',                          'cell',         [],     'Código da autorização fornecido pela SEFAZ (combustíveis)';
            'COD_BARRA',                        'cell',         [],     'Representação alfanumérica do código de barra da unidade comercial do produto, se houver';
            'COD_CCUS',                         'cell',         [],     'CÃƒÂ³digo do centro de custos do plano de contas anterior.';
            'COD_CCUS_REC',                     'cell',         [],     'CÃƒÂ³digo do centro de custos.';
            'COD_CLASS',                        'cell',         [],     'Código de classificação do item do serviço de comunicação ou de telecomunicação, conforme a Tabela 4.4.1';
            'COD_CNT_CORR',                     'cell',         [],     'CÃƒÂ³digo da subconta correlata (deve estar no plano de contas e sÃƒÂ³ pode estar relacionada a um ÃƒÂºnico grupo).';
            'COD_COMB',                         'cell',         [],     'Código do produto, conforme tabela publicada pela ANP';
            'COD_CONS',                         'cell',         [],     '- Código de classe de consumo de energia elétrica ou gás: 01 - Comercial 02 - Consumo Próprio 03 - Iluminação Pública 04 - Industrial 05 - Poder Público 06 - Residencial 07 - Rural 08 - Serviço Público. - Código de classe de consumo de Fornecimento D´água – Tabela 4.4.2. C 002* - OC OC';
            'COD_CONTRA',                       'cell',         [],     'CÃƒÂ³digo da conta consolidada da contrapartida.';
            'COD_CTA',                          'cell',         [],     'Código da conta analatíca.';
            'COD_CTA_EMP',                      'cell',         [],     'CÃƒÂ³digo da conta da empresa participante.';
            'COD_CTA_REC',                      'cell',         [],     'CÃƒÂ³digo da conta analÃƒÂ­tica.';
            'COD_CTA_REF',                      'cell',         [],     'CÃƒÂ³digo da conta conforme plano de contas referencial.';
            'COD_CTA_RES',                      'cell',         [],     'CÃƒÂ³digo da(s) conta(s) analÃƒÂ­tica(s) do Livro DiÃƒÂ¡rio com EscrituraÃƒÂ§ÃƒÂ£o Resumida.';
            'COD_CTA_SUP',                      'cell',         [],     'CÃƒÂ³digo da conta sintÃƒÂ©tica / grupo de contas de nÃƒÂ­vel superior.';
            'COD_CTD',                          'cell',         [],     'Código da conta do plano de contas';
            'COD_CVM_AUDITOR',                  'cell',         [],     'Auditor independente na CVM.';
            'COD_DA',                           'cell',         [],     'Código do modelo do documento de arrecadação: 0 – Documento estadual de arrecadação 1 – GNRE C 001* - O O';
            'COD_DISP',                         'cell',         [],     'Código dispositivo autorizado: 00 - Formulário de Segurança – impressor autônomo 01 - FS-DA – Formulário de Segurança para Impressão de DANFE 02 – Formulário de segurança - NF-e 03 - Formulário Contínuo 04 – Blocos 05 - Jogos Soltos';
            'COD_DOC_IMP',                      'cell',         [],     'Documento de importação: 0 – Declaração de Importação; 1 – Declaração Simplificada de Importação. 2 – Declaração Única de Importação (DUIMP)';
            'COD_EMP',                          'cell',         [],     'CÃƒÂ³digo de identificaÃƒÂ§ÃƒÂ£o da empresa participante.';
            'COD_ENQ',                          'cell',         [],     'Código de enquadramento legal do IPI, conforme tabela indicada no item 4.5.3. C 003* - OC OC';
            'COD_ENT_REF',                      'cell',         [],     'CÃƒÂ³digo da instituiÃƒÂ§ÃƒÂ£o responsÃƒÂ¡vel pelo plano de contas referencial.';
            'COD_FIN',                          'cell',         [],     'Código da finalidade do arquivo: 0 - Remessa do arquivo original; 1 - Remessa do arquivo substituto.';
            'COD_GEN',                          'cell',         [],     'Código do gênero do item, conforme a Tabela 4.2.1';
            'COD_GRUPO_TENSAO',                 'cell',         [],     'Código de grupo de tensão: 01 - A1 - Alta Tensão (230kV ou mais) 02 - A2 - Alta Tensão (88 a 138kV) 03 - A3 - Alta Tensão (69kV) 04 - A3a - Alta Tensão (30kV a 44kV) 05 - A4 - Alta Tensão (2,3kV a 25kV) 06 - AS - Alta Tensão Subterrâneo 06 07 - B1 - Residencial 07 08 - B1 - Residencial Baixa Renda 08 09 - B2 - Rural 09 10 - B2 - Cooperativa de Eletrificação Rural 11 - B2 - Serviço Público de Irrigação 12 - B3 - Demais Classes 13 - B4a - Iluminação Pública - rede de distribuição C 002* - OC OC 14 - B4b - Iluminação Pública - bulbo de lâmpada';
            'COD_HASH_AUX',                     'cell',         [],     'Verifica se o campo cÃƒÂ³digo Hash do arquivo correspondente ao livro auxiliar.';
            'COD_HASH_SUB',                     'cell',         [],     'Hash da escrituraÃƒÂ§ÃƒÂ£o substituÃƒÂ­da.';
            'COD_HIST',                         'cell',         [],     'CÃƒÂ³digo do histÃƒÂ³rico padronizado.';
            'COD_HIST_FAT',                     'cell',         [],     'CÃƒÂ³digo do histÃƒÂ³rico do fato contÃƒÂ¡bil.';
            'COD_HIST_PAD',                     'cell',         [],     'CÃƒÂ³digo do histÃƒÂ³rico padronizado, conforme tabela I075.';
            'COD_IDT',                          'cell',         [],     'CÃƒÂ³digo de identificaÃƒÂ§ÃƒÂ£o do grupo de conta-subconta.';
            'COD_INF',                          'cell',         [],     'Código da informação complementar do documento fiscal (campo 02 do Registro 0450) C 006 - OC OC';
            'COD_INF_ADIC',                     'cell',         [],     'Código da informação adicional conforme tabela a ser definida pelas SEFAZ, conforme tabela definida no item 5.2.';
            'COD_INF_OBS',                      'cell',         [],     'Código da observação do lançamento fiscal (campo 02 do Registro 0460) C 060 - OC OC';
            'COD_INSCR',                        'cell',         [],     'CÃƒÂ³digo cadastral da pessoa jurÃƒÂ­dica na instituiÃƒÂ§ÃƒÂ£o identificada.';
            'COD_ITEM',                         'cell',         [],     'Código do produto/insumo a ser reprocessado/reparado ou já reprocessado/reparado (campo 02 do Registro 0200) C 060 - O 04 DT_SAÍDA Data de saída do estoque N 008* - O 05 QTD_SAÍDA Quantidade de saída do estoque';
            'COD_ITEM_IP',                      'cell',         [],     'Código do item do imposto retido por substituição (campo 02 do Registro 0200).';
            'COD_LST',                          'cell',         [],     'Código do serviço conforme lista do Anexo I da Lei Complementar Federal nº 116/03. C 005 OC';
            'COD_MOD',                          'cell',         [],     'Código do modelo do documento fiscal, conforme a tabela indicada no item 4.1.1 C 002* - O O';
            'COD_MOD_DOC_REF',                  'cell',         [],     'Codigo do modelo do documento fiscal referenciado.';
            'COD_MOD_ULT_E',                    'cell',         [],     'Código do modelo do documento fiscal relativa a última entrada';
            'COD_MOT_RES',                      'cell',         [],     'Código do motivo do ressarcimento: 1 - Saída para outra UF; 2 -Saída amparada por isenção ou não incidência; 3 - Perda ou deterioração; 4 - Furto ou roubo; 5 - Exportação; 6 - Venda interna para Simples Nacional 9 - Outros';
            'COD_MOT_REST_COMPL',               'cell',         [],     'Código do motivo da restituição ou complementação conforme Tabela 5.7 C 005* - O O';
            'COD_MOT_SUBS',                     'cell',         [],     'CÃƒÂ³digo do motivo da substituiÃƒÂ§ÃƒÂ£o.';
            'COD_MUN',                          'cell',         [],     'CÃƒÂ³digo do municÃƒÂ­pio conforme tabela do IBGE.';
            'COD_MUN_COL',                      'cell',         [],     'Código do Município do local de coleta, conforme tabela IBGE (Preencher com 9999999, se Exterior)';
            'COD_MUN_DEST',                     'cell',         [],     'Código do município de destino, conforme a tabela IBGE (Preencher com 9999999, se Exterior) N 007* - OC O';
            'COD_MUN_ENTG',                     'cell',         [],     'Código do Município do local de entrega, conforme tabela IBGE (Preencher com 9999999, se Exterior)';
            'COD_MUN_ORI',                      'cell',         [],     'Código do Município de origem, conforme tabela IBGE (Preencher com 9999999, se exterior)';
            'COD_MUN_ORIG',                     'cell',         [],     'Código do município de origem do serviço, conforme a tabela IBGE (Preencher com 9999999, se Exterior) N 007* - OC O';
            'COD_MUN_SERV',                     'cell',         [],     'Código do município onde o serviço foi prestado, conforme a tabela IBGE.';
            'COD_NAT',                          'cell',         [],     'CÃƒÂ³digo da natureza da conta/grupo de contas.';
            'COD_NAT_CC',                       'cell',         [],     'Codigo da natureza da conta/grupo de contas.';
            'COD_NCM',                          'cell',         [],     'Código da Nomenclatura Comum do Mercosul';
            'COD_OBS',                          'cell',         [],     'Código da observação do lançamento fiscal (campo 02 do Registro 0460) C 006 - OC OC';
            'COD_OR',                           'cell',         [],     'Código da obrigação recolhida ou a recolher, conforme a Tabela 5.4';
            'COD_PAIS',                         'cell',         [],     'CÃƒÂ³digo do paÃƒÂ­s conforme tabela do Banco Central do Brasil.';
            'COD_PART',                         'cell',         [],     'CÃƒÂ³digo de identificaÃƒÂ§ÃƒÂ£o do participante.';
            'COD_PART_CONSG',                   'cell',         [],     'Código do participante (campo 02 do Registro 0150): C 060 - OC - consignatário, se houver';
            'COD_PART_NFE_RET',                 'cell',         [],     'Código do participante emitente da NF-e em que houve retenção do ICMS ST.';
            'COD_PART_RED',                     'cell',         [],     'Código do participante (campo 02 do Registro 0150): - redespachante, se houver';
            'COD_PART_ULT_E',                   'cell',         [],     'Código do participante (do emitente do documento relativa a última entrada)';
            'COD_PLAN_REF',                     'cell',         [],     'CÃƒÂ³digo do Plano de Contas Referencial.';
            'COD_REC',                          'cell',         [],     'Código de receita referente à obrigação, próprio da unidade da federação da origem/destino, conforme legislação estadual.';
            'COD_REL',                          'cell',         [],     'CÃƒÂ³digo do relacionamento conforme tabela do Sped.';
            'COD_RESP_RET',                     'cell',         [],     'Código que indica o responsável pela retenção do ICMS ST: 1 - Remetente Direto Regime Comum 2 - Remetente Indireto 3 - Próprio Declarante 4 – Remetente Direto Simples Nacional';
            'COD_SCP',                          'cell',         [],     'CNPJ da SCP.';
            'COD_SCP_ECD_REC',                  'cell',         [],     'CNPJ da SCP.';
            'COD_SERV',                         'cell',         [],     'Item da lista de serviços, conforme Tabela 4.6.3 C 004* - O O';
            'COD_SIT',                          'cell',         [],     'Código da situação do documento fiscal, conforme a Tabela 4.1.2 N 002* - O O';
            'COD_TOT_PAR',                      'cell',         [],     'Código do totalizador, conforme Tabela 4.4.6';
            'COD_VER',                          'cell',         [],     'Código da versão do leiaute conforme a tabela indicada no Ato COTEPE.';
            'COFINS_IMP',                       'cell',         [],     'Valor pago de COFINS na importação.';
            'COL_CAMPO',                        'cell',         [],     'Largura da coluna no relatÃƒÂ³rio.';
            'COMPL',                            'cell',         [],     'Dados complementares do endereço.';
            'COND_PART',                        'cell',         [],     'CondiÃƒÂ§ÃƒÂ£o da empresa relacionada ÃƒÂ  operaÃƒÂ§ÃƒÂ£o.';
            'CONS',                             'cell',         [],     'Consumo total acumulado, em kWh (Código 06)';
            'CONT_ANT',                         'cell',         [],     'Conteúdo anterior do campo';
            'CPF',                              'cell',         [],     'CPF.';
            'CPF_CNPJ',                         'cell',         [],     'CPF ou CNPJ do adquirente';
            'CPF_COL',                          'cell',         [],     'CPF do contribuinte do local de coleta das mercadorias';
            'CPF_ENTG',                         'cell',         [],     'CPF do contribuinte do local de entrega';
            'CPF_INTERV',                       'cell',         [],     'CPF do técnico responsável pela intervenção';
            'CRC',                              'cell',         [],     'Número de inscrição do contabilista no Conselho Regional de Contabilidade.';
            'CRED_APR',                         'cell',         [],     'Total de crédito apropriado no mês';
            'CRED_RECEB',                       'cell',         [],     'Total de créditos recebidos por transferência';
            'CRED_UTIL',                        'cell',         [],     'Total de créditos utilizados no período';
            'CRO',                              'cell',         [],     'Posição do Contador de Reinício de Operação';
            'CRZ',                              'cell',         [],     'Posição do Contador de Redução Z';
            'CST_COFINS',                       'cell',         [],     'Código da Situação Tributária referente ao COFINS. N 002* - OC OC';
            'CST_ICMS',                         'cell',         [],     'Código da Situação Tributária referente ao ICMS, conforme a Tabela indicada no item 4.3.1 N 003* - O O';
            'CST_IPI',                          'cell',         [],     'Código da Situação Tributária referente ao IPI, conforme a Tabela indicada no item 4.3.2. C 002* - OC OC';
            'CST_PIS',                          'cell',         [],     'Código da Situação Tributária referente ao PIS. N 002* - OC OC';
            'CTA',                              'cell',         [],     'Nome da conta analÃƒÂ­tica/grupo de contas.';
            'CTA_COSIF',                        'cell',         [],     'Código COSIF a que está subordinada a conta do ISS das instituições financeiras';
            'CTA_ISS',                          'cell',         [],     'Descrição da conta no plano de contas';
            'DATA_FIN_EMP',                     'datetime',     [],     'Data final do perÃƒÂ­odo da escrituraÃƒÂ§ÃƒÂ£o consolidada.';
            'DATA_INI_EMP',                     'datetime',     [],     'Data inicial do perÃƒÂ­odo da escrituraÃƒÂ§ÃƒÂ£o consolidada.';
            'DEB_ESP',                          'cell',         [],     'Valores recolhidos ou a recolher, extra-apuração.';
            'DEB_ESP_ST',                       'cell',         [],     'Valores recolhidos ou a recolher, extra-apuração.';
            'DED',                              'double',       'bank', 'Deducoes.';
            'DEC_CAMPO',                        'cell',         [],     'Quantidade de casas decimais.';
            'DESC_CAMPO',                       'cell',         [],     'DescriÃƒÂ§ÃƒÂ£o do campo.';
            'DESC_FAT',                         'cell',         [],     'DescriÃƒÂ§ÃƒÂ£o do Fato ContÃƒÂ¡bil.';
            'DESC_MUN',                         'cell',         [],     'MunicÃƒÂ­pio.';
            'DESC_RTF',                         'cell',         [],     'DescriÃƒÂ§ÃƒÂ£o do arquivo .rtf.';
            'DESC_TIT',                         'cell',         [],     'Descrição complementar do título de crédito C - - OC OC';
            'DESCR',                            'cell',         [],     'Descrição da unidade de medida';
            'DESCR_AJ',                         'cell',         [],     'Descrição detalhada do ajuste, com citação dos documentos fiscais.';
            'DESCR_ANT_ITEM',                   'cell',         [],     'Descrição anterior do item';
            'DESCR_COD_AGL',                    'cell',         [],     'DescriÃƒÂ§ÃƒÂ£o do CÃƒÂ³digo de aglutinaÃƒÂ§ÃƒÂ£o.';
            'DESCR_COMPL',                      'cell',         [],     'Descrição da arma, compreendendo: número do cano, calibre, marca, capacidade de cartuchos, tipo de funcionamento, quantidade de canos, comprimento, tipo de alma, quantidade e sentido das raias e demais elementos que permitam sua perfeita identificação';
            'DESCR_COMPL_AJ',                   'cell',         [],     'Descrição complementar do ajuste do documento fiscal C - - OC OC';
            'DESCR_HIST',                       'cell',         [],     'DescriÃƒÂ§ÃƒÂ£o do histÃƒÂ³rico padronizado.';
            'DESCR_ITEM',                       'cell',         [],     'Descrição do bem ou componente (modelo, marca e outras características necessárias a sua individualização)';
            'DESCR_NAT',                        'cell',         [],     'Descrição da natureza da operação/prestação';
            'DESCR_NR_TOT',                     'cell',         [],     'Descrição da situação tributária relativa ao totalizador parcial, quando houver mais de um com a mesma carga tributária efetiva.';
            'DESCRIÃƒâ€¡ÃƒÆ’O',                 'cell',         [],     'Campo da tabela customizada "x_CONTAS_DESCRICAO"';
            'DESCRICAO',                        'cell',         [],     'DescriÃƒÂ§ÃƒÂ£o do campo adicional.';
            'DESPACHO',                         'cell',         [],     'Identificação do número do despacho';
            'DNRC_ABERT',                       'cell',         [],     'Texto fixo contendo "TERMO DE ABERTURA".';
            'DNRC_ENCER',                       'cell',         [],     'Texto fixo contendo "TERMO DE ENCERRAMENTO".';
            'DOC_FIM',                          'cell',         [],     'Número do documento final';
            'DOC_INI',                          'cell',         [],     'Número do documento inicial';
            'DT_A_P',                           'datetime',     [],     'Data da aquisição ou da prestação do serviço N 008* - O OC 13 TP_CT-e Tipo de Conhecimento de Transporte Eletrônico conforme definido no Manual de Integração do CT-e ou do Bilhete de Passagem Eletrônico conforme definido no Manual de Integração do BP-e N 001* - OC OC';
            'DT_ALT',                           'datetime',     [],     'Data da inclusÃƒÂ£o ou alteraÃƒÂ§ÃƒÂ£o.';
            'DT_APLICACAO',                     'datetime',     [],     'Data de aplicação do Lacre';
            'DT_ARQ',                           'datetime',     [],     'Data do arquivamento.';
            'DT_ARQ_CONV',                      'datetime',     [],     'Data do arquivamento do ato de conversÃƒÂ£o.';
            'DT_AVB',                           'datetime',     [],     'Data da averbação da Declaração de exportação (ddmmaaaa)';
            'DT_BCTE',                          'datetime',     [],     'Data do balancete.';
            'DT_CHC',                           'datetime',     [],     'Data do conhecimento de embarque (DDMMAAAA)';
            'DT_CRC',                           'datetime',     [],     'Data de validade do CRC.';
            'DT_CRC_T',                         'datetime',     [],     'Data de validade do CRC.';
            'DT_DE',                            'datetime',     [],     'Data da declaração (DDMMAAAA)';
            'DT_DOC',                           'datetime',     [],     'Data da emissão do documento fiscal recebido com fins específicos de exportação';
            'DT_DOC_FIN',                       'datetime',     [],     'Data de emissão final dos documentos / Data final do vencimento da fatura';
            'DT_DOC_INI',                       'datetime',     [],     'Data de emissão inicial dos documentos / Data inicial de vencimento da fatura';
            'DT_E_S',                           'datetime',     [],     'Data da entrada ou da saída N 008* - O OC';
            'DT_EVENTO',                        'datetime',     [],     'Data do evento societÃƒÂ¡rio.';
            'DT_EX_SOCIAL',                     'datetime',     [],     'Data de encerramento do exercÃƒÂ­cio social.';
            'DT_FAB',                           'datetime',     [],     'Data de fabricação do medicamento N 008* - O O';
            'DT_FECH',                          'datetime',     [],     'Data do fechamento da movimentação';
            'DT_FIM',                           'datetime',     [],     'Data final de utilização da descrição do item';
            'DT_FIN',                           'datetime',     [],     'Data final das demonstraÃƒÂ§ÃƒÂµes.';
            'DT_FIN_ECD_REC',                   'datetime',     [],     'Data final da ECD recuperada.';
            'DT_FIN_ESCR',                      'datetime',     [],     'Data de tÃƒÂ©rmino da escrituraÃƒÂ§ÃƒÂ£o.';
            'DT_FIN_REL',                       'datetime',     [],     'Data do tÃƒÂ©rmino do relacionamento.';
            'DT_FIN_SERV',                      'datetime',     [],     'Data em que se encerrou a prestação do serviço';
            'DT_INI',                           'datetime',     [],     'Data inicial das demonstraÃƒÂ§ÃƒÂµes.';
            'DT_INI_ECD_REC',                   'datetime',     [],     'Data inicial da ECD recuperada.';
            'DT_INI_ESCR',                      'datetime',     [],     'Data de inÃƒÂ­cio da escrituraÃƒÂ§ÃƒÂ£o.';
            'DT_INI_REL',                       'datetime',     [],     'Data de inÃƒÂ­cio do relacionamento.';
            'DT_INI_SERV',                      'datetime',     [],     'Data em que se iniciou a prestação do serviço';
            'DT_INV',                           'datetime',     [],     'Data do inventário';
            'DT_LCTO',                          'datetime',     [],     'Data do lanÃƒÂ§amento.';
            'DT_LCTO_EXT',                      'datetime',     [],     'Data do lanÃƒÂ§amento extemporÃƒÂ¢neo.';
            'DT_PGTO',                          'datetime',     [],     'Data de pagamento do documento de arrecadação, ou data do vencimento, no caso de ICMS antecipado a recolher. N 008* - O O';
            'DT_RE',                            'datetime',     [],     'Data do Registro de Exportação (DDMMAAAA)';
            'DT_RES',                           'datetime',     [],     'Data da apuraÃƒÂ§ÃƒÂ£o do resultado.';
            'DT_ULT_E',                         'datetime',     [],     'Data relativa a última entrada da mercadoria';
            'DT_VAL',                           'datetime',     [],     'Data de expiração da validade do medicamento N 008* - O O';
            'DT_VCTO',                          'datetime',     [],     'Data de vencimento do documento de arrecadação N 008* - O O';
            'ECF_CX',                           'cell',         [],     'Número do caixa atribuído ao ECF N 003 - O O';
            'ECF_FAB',                          'cell',         [],     'Número de série de fabricação do ECF C 021 - O O';
            'ECF_MOD',                          'cell',         [],     'Modelo do equipamento';
            'EMAIL',                            'cell',         [],     'Email do signatÃƒÂ¡rio.';
            'EMAIL_T',                          'cell',         [],     'Email do signatÃƒÂ¡rio.';
            'EMP_COD',                          'cell',         [],     'CÃƒÂ³digo de identificaÃƒÂ§ÃƒÂ£o da empresa participante.';
            'EMP_COD_CONTRA',                   'cell',         [],     'CÃƒÂ³digo da empresa da contrapartida.';
            'EMP_COD_PART',                     'cell',         [],     'CÃƒÂ³digo da empresa envolvida na operaÃƒÂ§ÃƒÂ£o.';
            'EMP_COD_PARTE',                    'cell',         [],     'CÃƒÂ³digo da empresa detentora do valor aglutinado.';
            'END',                              'cell',         [],     'Logradouro e endereço do imóvel.';
            'ESTQ_ABERT',                       'double',       'bank', 'Estoque no início do dia, em litros';
            'ESTQ_ESCR',                        'double',       'bank', 'Estoque Escritural (06 – 07), litros';
            'EVENTO',                           'cell',         [],     'Evento societÃƒÂ¡rio ocorrido no perÃƒÂ­odo.';
            'EX_IPI',                           'cell',         [],     'Código EX, conforme a TIPI';
            'FABRICANTE',                       'cell',         [],     'Nome do Fabricante da Bomba';
            'FANTASIA',                         'cell',         [],     'Nome de fantasia associado ao nome empresarial.';
            'FAT_CONV',                         'cell',         [],     'Fator de conversão: fator utilizado para converter (multiplicar) a unidade a ser convertida na unidade adotada no inventário.';
            'FAX',                              'cell',         [],     'Número do fax.';
            'FECH_FISICO',                      'cell',         [],     'Volume aferido no tanque, em litros. Estoque de fechamento físico do tanque.';
            'FIN_DOCe',                         'cell',         [],     'Finalidade da emissao do documento eletronico.';
            'FONE',                             'cell',         [],     'Telefone do signatÃƒÂ¡rio.';
            'FONE_T',                           'cell',         [],     'Telefone do signatÃƒÂ¡rio.';
            'GT_FIN',                           'cell',         [],     'Valor do Grande Total final';
            'HASH_ECD_REC',                     'cell',         [],     'Hashcode da ECD recuperada.';
            'HASH_DOC_REF',                     'cell',         [],     'Codigo de autenticacao digital do registro referenciado.';
            'HASH_RTF',                         'cell',         [],     'Hash do arquivo .rtf incluÃƒÂ­do.';
            'HIST',                             'cell',         [],     'HistÃƒÂ³rico completo da partida.';
            'HORA',                             'cell',         [],     'Hora da saída das mercadorias';
            'ICMS_RET',                         'cell',         [],     'Valor da parcela do imposto retido em remessa promovida por substituído intermediário N’ - 02 OC';
            'ICMS_ST_COMPL',                    'cell',         [],     'Valor do ICMS ST a complementar à UF de destino';
            'ICMS_ST_REP',                      'cell',         [],     'Valor do ICMS ST a repassar/deduzir em operações interestaduais';
            'ID_DEM',                           'cell',         [],     'IdentificaÃƒÂ§ÃƒÂ£o das demonstraÃƒÂ§ÃƒÂµes.';
            'IDENT_CPF',                        'cell',         [],     'CPF.';
            'IDENT_CPF_CNPJ',                   'cell',         [],     'CPF ou CNPJ.';
            'IDENT_CPF_CNPJ_T',                 'cell',         [],     'CPF ou CNPJ do assinante do termo.';
            'IDENT_MF',                         'cell',         [],     'IdentificaÃƒÂ§ÃƒÂ£o de moeda funcional.';
            'IDENT_MF_ECD_REC',                 'cell',         [],     'IdentificaÃƒÂ§ÃƒÂ£o de moeda funcional.';
            'IDENT_NOM',                        'cell',         [],     'Nome do signatÃƒÂ¡rio.';
            'IDENT_NOM_T',                      'cell',         [],     'Nome do signatÃƒÂ¡rio do termo.';
            'IDENT_QUALIF',                     'cell',         [],     'QualificaÃƒÂ§ÃƒÂ£o do assinante.';
            'IDENT_QUALIF_T',                   'cell',         [],     'QualificaÃƒÂ§ÃƒÂ£o do assinante do termo.';
            'IE',                               'cell',         [],     'InscriÃƒÂ§ÃƒÂ£o Estadual.';
            'IE_COL',                           'cell',         [],     'Inscrição Estadual do contribuinte do local de coleta';
            'IE_DEST',                          'cell',         [],     'Inscrição Estadual do destinatário das mercadorias que constam na nota fiscal.';
            'IE_EMIT',                          'cell',         [],     'Inscrição Estadual do participante emitente do modal';
            'IE_ENTG',                          'cell',         [],     'Inscrição Estadual do contribuinte do local de entrega';
            'IE_REM',                           'cell',         [],     'Inscrição Estadual do remetente das mercadorias que constam na nota fiscal.';
            'IE_ST',                            'cell',         [],     'InscriÃƒÂ§ÃƒÂ£o Estadual do participante.';
            'IE_TOM',                           'cell',         [],     'Inscrição Estadual do participante tomador do serviço';
            'IM',                               'cell',         [],     'InscriÃƒÂ§ÃƒÂ£o Municipal.';
            'IND_AJ',                           'cell',         [],     'Indicador do tipo de ajuste: 0- Ajuste a débito; 1- Ajuste a crédito';
            'IND_APUR',                         'cell',         [],     'Indicador de período de apuração do IPI: 0 - Mensal; 1 - Decendial C 001* - OC OC';
            'IND_ARM',                          'cell',         [],     'Indicador do tipo da arma de fogo: 0 - Uso permitido; C 001* - O 1 - Uso restrito';
            'IND_ATIV',                         'cell',         [],     'Indicador de tipo de atividade: 0 – Industrial ou equiparado a industrial; 1 – Outros.';
            'IND_CARGA',                        'cell',         [],     'Indicador do tipo de transporte: 0 – Rodoviário; 1 – Ferroviário; 2 – Rodo-Ferroviário; 3 – Aquaviário; 4 – Dutoviário; 5 – Aéreo; 9 – Outros.';
            'IND_CENTRALIZADA',                 'cell',         [],     'Indicador de escrituraÃƒÂ§ÃƒÂ£o centralizada ou descentralizada.';
            'IND_CENTRALIZADA_ECD_REC',         'cell',         [],     'Indicador de escrituraÃƒÂ§ÃƒÂ£o centralizada ou descentralizada.';
            'IND_COD_AGL',                      'cell',         [],     'Indicador do tipo de cÃƒÂ³digo de aglutinaÃƒÂ§ÃƒÂ£o.';
            'IND_CRC',                          'cell',         [],     'NÃƒÂºmero do CRC.';
            'IND_CRC_T',                        'cell',         [],     'NÃƒÂºmero do CRC.';
            'IND_CTA',                          'cell',         [],     'Indicador do tipo de conta.';
            'IND_DAD',                          'cell',         [],     'Indicador de movimento.';
            'IND_DC',                           'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do saldo final.';
            'IND_DC_AUX',                       'cell',         [],     'Indicador da natureza da partida em moeda funcional.';
            'IND_DC_BAL',                       'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do saldo.';
            'IND_DC_BAL_INI',                   'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do saldo inicial.';
            'IND_DC_CTA',                       'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do saldo da conta.';
            'IND_DC_CTA_FIN',                   'cell',         [],     'Indicador do valor final antes do encerramento.';
            'IND_DC_CTA_INI',                   'cell',         [],     'Indicador do valor inicial.';
            'IND_DC_FAT',                       'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do saldo do fato.';
            'IND_DC_FIN',                       'cell',         [],     'Indicador do saldo final.';
            'IND_DC_FIN_AUX',                   'cell',         [],     'Indicador do saldo final em moeda funcional.';
            'IND_DC_FIN_MF',                    'cell',         [],     'Indicador do saldo final em moeda funcional.';
            'IND_DC_FIN_REC',                   'cell',         [],     'Indicador do saldo final recuperado.';
            'IND_DC_INI',                       'cell',         [],     'Indicador do saldo inicial.';
            'IND_DC_INI_AUX',                   'cell',         [],     'Indicador do saldo inicial em moeda funcional.';
            'IND_DC_INI_MF',                    'cell',         [],     'Indicador do saldo inicial em moeda funcional.';
            'IND_DC_INI_REC',                   'cell',         [],     'Indicador do saldo inicial recuperado.';
            'IND_DC_MF',                        'cell',         [],     'Indicador da natureza da partida em moeda funcional.';
            'IND_DEC',                          'cell',         [],     'Indicador de descentralizaÃƒÂ§ÃƒÂ£o.';
            'IND_DED',                          'cell',         [],     'Indicador do tipo de dedução: 0 - Compensação do ISS calculado a maior; 1 - Benefício fiscal por incentivo à cultura; 2 - Decisão administrativa ou judicial; 9 - Outros C 001* - O O';
            'IND_DOC',                          'cell',         [],     'Indicador da origem do documento vinculado ao ajuste: C 001* - O 0 - Processo Judicial; 1 - Processo Administrativo; 2 - PER/DCOMP; 3 – Documento Fiscal 9 – Outros.';
            'IND_EMIT',                         'cell',         [],     'Indicador do emitente do documento fiscal: 0 - Emissão própria; 1 - Terceiros C 001* - O O';
            'IND_EMP_GRD_PRT',                  'cell',         [],     'Indicador de empresa de grande porte.';
            'IND_ESC',                          'cell',         [],     'Indicador da forma de escrituraÃƒÂ§ÃƒÂ£o contÃƒÂ¡bil.';
            'IND_ESC_CONS',                     'cell',         [],     'Indicador de escrituraÃƒÂ§ÃƒÂµes consolidadas.';
            'IND_ESC_CONS_ECD_REC',             'cell',         [],     'Indicador de escrituraÃƒÂ§ÃƒÂµes consolidadas.';
            'IND_FIM_RTF',                      'cell',         [],     'Indicador de fim do arquivo RTF.';
            'IND_FIN_ESC',                      'cell',         [],     'Indicador de finalidade da escrituraÃƒÂ§ÃƒÂ£o.';
            'IND_FIN_ESC_ECD_REC',              'cell',         [],     'Indicador de finalidade da escrituraÃƒÂ§ÃƒÂ£o.';
            'IND_FRT',                          'cell',         [],     'Indicador do tipo do frete: 0 - Por conta de terceiros; 1 - Por conta do emitente; 2 - Por conta do destinatário; 9 - Sem cobrança de frete. C 001* - O O Obs.: A partir de 01/01/2012 passará a ser: Indicador do tipo do frete: 0 - Por conta do emitente; 1 - Por conta do destinatário/remetente; 2 - Por conta de terceiros; 9 - Sem cobrança de frete. Obs: A partir de 01/01/2018 passará a ser: Indicador do tipo de frete: 0 - Contratação do Frete por conta do Remetente (CIF); 1 - Contratação do Frete por conta do Destinatário (FOB); 2 - Contratação do Frete por conta de Terceiros; 3 - Transporte Próprio por conta do Remetente; 4 - Transporte Próprio por conta do Destinatário; 9 - Sem Ocorrência de Transporte.';
            'IND_FRT_RED',                      'cell',         [],     'Indicador do tipo do frete da operação de redespacho: 0 – Sem redespacho; 1 - Por conta do emitente; 2 - Por conta do destinatário; 9 – Outros.';
            'IND_GRANDE_PORTE',                 'cell',         [],     'Indicador de entidade sujeita a auditoria independente.';
            'IND_GRP_BAL',                      'cell',         [],     'Indicador de grupo do balanÃƒÂ§o.';
            'IND_GRP_DRE',                      'cell',         [],     'Indicador de grupo da DRE.';
            'IND_LCTO',                         'cell',         [],     'Indicador do tipo de lanÃƒÂ§amento.';
            'IND_MED',                          'cell',         [],     'Indicador de tipo de referência da base de cálculo do ICMS (ST) do produto farmacêutico: 0 - Base de cálculo referente ao preço tabelado ou preço máximo sugerido; 1 - Base cálculo – Margem de valor agregado; 2 - Base de cálculo referente à Lista Negativa; 3 - Base de cálculo referente à Lista Positiva; 4 - Base de cálculo referente à Lista Neutra C 001* - O O';
            'IND_MOV',                          'cell',         [],     'Indicador de movimento: 0 - Bloco com dados informados; 1 - Bloco sem dados informados.';
            'IND_MOV_ST',                       'cell',         [],     'Indicador de movimento: 0 – Sem operações com ST 1 – Com operações de ST';
            'IND_MUDANC_PC',                    'cell',         [],     'Indicador de mudanÃƒÂ§a de plano de contas.';
            'IND_MUDANCA_PC_ECD_REC',           'cell',         [],     'Indicador de mudanÃƒÂ§a de plano de contas.';
            'IND_NAT_FRT',                      'cell',         [],     'Indicador da natureza do frete: 0- Negociável; 1- Não negociável';
            'IND_NAV',                          'cell',         [],     'Indicador do tipo da navegação: 0- Interior; 1- Cabotagem';
            'IND_NIRE',                         'cell',         [],     'Indicador de existÃƒÂªncia de NIRE.';
            'IND_NIRE_ECD_REC',                 'cell',         [],     'Indicador de existÃƒÂªncia de NIRE.';
            'IND_OBR',                          'cell',         [],     'Indicador da obrigação onde será aplicada a dedução: 0 - ISS Próprio; - ISS Substituto (devido pelas aquisições de serviços do declarante). - ISS Uniprofissionais. C 001* - O O';
            'IND_OPER',                         'cell',         [],     'Indicador do tipo de operação: 0- Entrada/aquisição; 1- Saída/prestação C 001* - O O';
            'IND_PERFIL',                       'cell',         [],     'Perfil de apresentação do arquivo fiscal; A – Perfil A; B – Perfil B.; C – Perfil C.';
            'IND_PREPAGO',                      'cell',         [],     'Forma de pagamento: 0 - pre pago; 1 - pos pago.';
            'IND_PGTO',                         'cell',         [],     'Indicador do tipo de pagamento: 0 - À vista; 1 - A prazo; 9 - Sem pagamento. C 001* - O O Obs.: A partir de 01/07/2012 passará a ser: Indicador do tipo de pagamento: 0 - À vista; 1 - A prazo; 2 - Outros';
            'IND_PLANO_REF_ECD_REC',            'cell',         [],     'Indicador do plano de contas referencial.';
            'IND_PROC',                         'cell',         [],     'Indicador da origem do processo: 0 - SEFAZ; 1 - Justiça Federal; 2 - Justiça Estadual; 3 - SECEX/SRF 9 - Outros. C 001* - O O';
            'IND_PROF',                         'cell',         [],     'Indicador de habilitação: 0- Profissional habilitado 1- Profissional não habilitado';
            'IND_PROP',                         'cell',         [],     'Indicador de propriedade/posse do item: 0- Item de propriedade do informante e em seu poder; 1- Item de propriedade do informante em posse de terceiros; 2- Item de propriedade de terceiros em posse do informante';
            'IND_RAT',                          'cell',         [],     'Índice para rateio(2 / 4)';
            'IND_REC',                          'cell',         [],     'Indicador do tipo de receita: 0- Receita própria - serviços prestados; 1- Receita própria - cobrança de débitos; 2- Receita própria - venda de mercadorias; 3- Receita própria - venda de serviço pré-pago; 4- Outras receitas próprias; 5- Receitas de terceiros (co-faturamento); 9- Outras receitas de terceiros';
            'IND_RESP_LEGAL',                   'cell',         [],     'Indicador de responsÃƒÂ¡vel legal.';
            'IND_SERV',                         'cell',         [],     'Indicador do tipo de serviço prestado: 0 - Telefonia; 1 - Comunicação de dados; 2 - TV por assinatura; 3 - Provimento de acesso à Internet; 4 - Multimídia; C 001* - O 9 - Outros';
            'IND_SIT_ESP',                      'cell',         [],     'Indicador de situaÃƒÂ§ÃƒÂ£o especial.';
            'IND_SIT_ESP_ECD_REC',              'cell',         [],     'Indicador de situaÃƒÂ§ÃƒÂ£o especial da ECD recuperada.';
            'IND_SIT_INI_PER',                  'cell',         [],     'Indicador de situaÃƒÂ§ÃƒÂ£o no inÃƒÂ­cio do perÃƒÂ­odo.';
            'IND_SOC',                          'cell',         [],     'Indicador de participação societária: 0 - Sócio 1 - Não sócio';
            'IND_TFA',                          'cell',         [],     'Indicador do tipo de tarifa aplicada: 0- Exp.; 1- Enc.; 2- C.I.; 9- Outra';
            'IND_TIP',                          'cell',         [],     'Indicador do tipo de demonstraÃƒÂ§ÃƒÂ£o.';
            'IND_TIT',                          'cell',         [],     'Indicador do tipo de título de crédito: 00 - Duplicata; 01 - Cheque; 02 - Promissória; 03 - Recibo; 99 - Outros (descrever) C 002* - O O';
            'IND_VAL_AG',                       'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do valor aglutinado.';
            'IND_VAL_CS',                       'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do valor consolidado.';
            'IND_VAL_EL',                       'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do valor eliminado.';
            'IND_VALOR',                        'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do valor eliminado.';
            'IND_VEIC',                         'cell',         [],     'Indicador do tipo do veículo transportador: 0- Embarcação; 1- Empurrador/rebocador';
            'IND_VEIC_OPER',                    'cell',         [],     'Indicador do tipo de operação com veículo: 0 - Venda para concessionária; 1 - Faturamento direto; 2 - Venda direta; 3 - Venda da concessionária; 9 - Outros C 001* - O O';
            'IND_VL',                           'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do valor informado.';
            'IND_VL_ULT_DRE',                   'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do valor informado.';
            'ITEM_NFE_RET',                     'cell',         [],     'Número sequencial do item na NF-e em que houve a retenção do ICMS ST, que corresponde à mercadoria objeto de pedido de ressarcimento';
            'LECD',                             'cell',         [],     'Texto fixo contendo "LECD".';
            'LOTE_MED',                         'cell',         [],     'Número do lote de fabricação do medicamento C - - O O';
            'MES_DOC_REF',                      'cell',         [],     'Mes e ano da emissao do documento fiscal referenciado.';
            'MODELO',                           'cell',         [],     'Modelo da Bomba';
            'MOT_INTERV',                       'cell',         [],     'Motivo da Intervenção';
            'MUN',                              'cell',         [],     'Código do Município de origem/destino';
            'NAT_EXP',                          'cell',         [],     'Preencher com: 0 - Exportação Direta 1 - Exportação Indireta';
            'NAT_LIVR',                         'cell',         [],     'Natureza do livro.';
            'NAT_LIVRO',                        'cell',         [],     'Natureza do livro.';
            'NAT_SUB_CNT',                      'cell',         [],     'Natureza da subconta correlata.';
            'NI_CPF_CNPJ',                      'cell',         [],     'CPF ou CNPJ do auditor independente.';
            'NIRE',                             'cell',         [],     'NÃƒÂºmero de IdentificaÃƒÂ§ÃƒÂ£o do Registro de Empresas.';
            'NIRE_SUBST',                       'cell',         [],     'NIRE da escrituraÃƒÂ§ÃƒÂ£o substituÃƒÂ­da.';
            'NIT',                              'cell',         [],     'Indicador da situaÃƒÂ§ÃƒÂ£o do valor eliminado.';
            'NIVEL',                            'cell',         [],     'NÃƒÂ­vel da conta analÃƒÂ­tica.';
            'NIVEL_AGL',                        'cell',         [],     'NÃƒÂ­vel do cÃƒÂ³digo de aglutinaÃƒÂ§ÃƒÂ£o.';
            'NM_CAMPO',                         'cell',         [],     'Nome do campo.';
            'NOM_ADQ',                          'cell',         [],     'Nome do adquirente';
            'NOM_INTERV',                       'cell',         [],     'Nome do Interventor';
            'NOM_MEST',                         'cell',         [],     'Nome do arquivo Mestre de Documento Fiscal';
            'NOM_MOT',                          'cell',         [],     'Nome do motorista';
            'NOME',                             'cell',         [],     'Nome empresarial da pessoa jurÃƒÂ­dica.';
            'NOME_CTA',                         'cell',         [],     'Nome da conta analitica/grupo de contas.';
            'NOME_AUDITOR',                     'cell',         [],     'Nome do auditor independente.';
            'NOME_AUDITOR_FIRMA',               'cell',         [],     'Nome do auditor ou firma.';
            'NOME_SCP',                         'cell',         [],     'Nome da SCP.';
            'NOTA_EXP_REF',                     'cell',         [],     'ReferÃƒÂªncia ÃƒÂ s notas explicativas.';
            'NOTAS_EXP_REF',                    'cell',         [],     'ReferÃƒÂªncia ÃƒÂ s notas explicativas.';
            'NR_CAMPO',                         'cell',         [],     'Número do campo alterado (campos 03 a 13, exceto 07)';
            'NR_DOC',                           'cell',         [],     'Número do documento utilizado na baixa de créditos';
            'NR_INTERV',                        'cell',         [],     'Número da intervenção';
            'NR_MEMO',                          'cell',         [],     'Número do memorando.';
            'NR_PASSE',                         'cell',         [],     'Número do Passe Fiscal';
            'NR_SAT',                           'cell',         [],     'Número de Série do equipamento SAT N 009 - O O';
            'NR_TOT',                           'cell',         [],     'Número do totalizador quando ocorrer mais de uma situação com a mesma carga tributária efetiva.';
            'NRO_DE',                           'cell',         [],     'Número da declaração';
            'NRO_ORD_FIN',                      'cell',         [],     'Número de ordem final';
            'NRO_ORD_INI',                      'cell',         [],     'Número de ordem inicial';
            'NRO_RE',                           'cell',         [],     'Nº do registro de Exportação';
            'NU_ORDEM',                         'cell',         [],     'NÃƒÂºmero de ordem da linha.';
            'NUM',                              'cell',         [],     'Número do imóvel.';
            'NUM_ACDRAW',                       'cell',         [],     'Número do Ato Concessório do regime Drawback';
            'NUM_AD',                           'cell',         [],     'NÃƒÂºmero sequencial do campo adicional.';
            'NUM_ARM',                          'cell',         [],     'Numeração de série de fabricação da arma';
            'NUM_ARQ',                          'cell',         [],     'NÃƒÂºmero ou caminho do documento.';
            'NUM_AUT',                          'cell',         [],     'Número da autorização, conforme dispositivo autorizado';
            'NUM_BICO',                         'cell',         [],     'Número sequencial do bico ligado a bomba';
            'NUM_CCF',                          'cell',         [],     'Número do Contador de Cupom Fiscal';
            'NUM_CFE',                          'cell',         [],     'Número do cupom fiscal eletrônico N 006 - O O';
            'NUM_COO_FIN',                      'cell',         [],     'Número do Contador de Ordem de Operação do último documento emitido no dia. (Número do COO na Redução Z)';
            'NUM_DA',                           'cell',         [],     'Número do documento de arrecadação estadual, se houver';
            'NUM_DOC',                          'cell',         [],     'Número do documento / processo / declaração ao qual o ajuste está vinculado, se houver';
            'NUM_DOC_REF',                      'cell',         [],     'Numero do documento fiscal referenciado.';
            'NUM_DOC_CANC',                     'cell',         [],     'Número do documento fiscal cancelado';
            'NUM_DOC_FIN',                      'cell',         [],     'Número do documento fiscal final (mesmo modelo, série e subsérie)';
            'NUM_DOC_IMP',                      'cell',         [],     'Número do documento de Importação.';
            'NUM_DOC_INI',                      'cell',         [],     'Número do primeiro documento fiscal emitido (mesmo modelo, série e subsérie)';
            'NUM_DOC_ULT_E',                    'cell',         [],     'Número do documento fiscal relativa a última entrada';
            'NUM_ITEM',                         'cell',         [],     'Número sequencial do item no documento fiscal N 003 - O O';
            'NUM_ITEM_ULT_E',                   'cell',         [],     'Número sequencial do item na NF entrada que corresponde à mercadoria objeto de pedido de ressarcimento';
            'NUM_LACRE',                        'cell',         [],     'Número do Lacre associado na Bomba';
            'NUM_LCTO',                         'cell',         [],     'NÃƒÂºmero do lanÃƒÂ§amento contÃƒÂ¡bil.';
            'NUM_NFE_RET',                      'cell',         [],     'Número da NF-e em que houve a retenção do ICMS ST';
            'NUM_ORD',                          'cell',         [],     'NÃƒÂºmero de ordem do instrumento.';
            'NUM_PARC',                         'cell',         [],     'Número da parcela a receber/pagar N 002 - O O';
            'NUM_PROC',                         'cell',         [],     'Número do processo ou auto de infração ao qual a obrigação está vinculada, se houver.';
            'NUM_SEQ',                          'cell',         [],     'Número de ordem sequencial do modal';
            'NUM_SEQ_CRC',                      'cell',         [],     'NÃƒÂºmero da CertidÃƒÂ£o de Regularidade Profissional.';
            'NUM_SEQ_CRC_T',                    'cell',         [],     'NÃƒÂºmero da CertidÃƒÂ£o de Regularidade Profissional.';
            'NUM_TANQUE',                       'cell',         [],     'Tanque onde foi armazenado o combustível';
            'NUM_TIT',                          'cell',         [],     'Número ou código identificador do título de crédito C - - O O';
            'ObservaÃƒÂ§ÃƒÂ£o  Ã¢Å“Å½',         'cell',         [],     'Campo da tabela customizada "x_CONTAS_ANOTACAO"';
            'OPER',                             'cell',         [],     'Indicador do tipo de operação: 0 - Combustíveis e Lubrificantes; 1 - Leasing de veículos ou faturamento direto. 2 - Recusa de recebimento (de acordo com as condições descritas nas instruções do Registro) N 001* - O O';
            'OTM',                              'cell',         [],     'Registro do operador de transporte multimodal';
            'PAIS',                             'cell',         [],     'Código do país de destino da mercadoria (Preencher conforme tabela do SISCOMEX)';
            'PER_CONS',                         'cell',         [],     'Percentual de consolidaÃƒÂ§ÃƒÂ£o.';
            'PER_EVT',                          'cell',         [],     'Percentual da empresa participante.';
            'PER_FISCAL',                       'cell',         [],     'Período fiscal da prestação do serviço (MMAAAA)';
            'PER_PART',                         'cell',         [],     'Percentual de participaÃƒÂ§ÃƒÂ£o.';
            'PESO_BRT',                         'double',       'bank', 'Peso bruto dos volumes transportados (em kg)';
            'PESO_LIQ',                         'double',       'bank', 'Peso líquido dos volumes transportados (em kg)';
            'PIS_IMP',                          'cell',         [],     'Valor pago de PIS na importação';
            'PROC',                             'cell',         [],     'Descrição do processo que embasou o lançamento C - - OC OC';
            'QTD',                              'cell',         [],     'Quantidade do item efetivamente exportado.';
            'QTD_BILH',                         'double',       'bank', 'Quantidade de bilhetes emitidos';
            'QTD_CANC',                         'double',       'bank', 'Quantidade cancelada acumulada, no caso de cancelamento parcial de item';
            'QTD_CONS',                         'double',       'bank', 'Quantidade de documentos consolidados neste registro';
            'QTD_ITEM',                         'double',       'bank', 'Quantidade de item por lote N - 003 O O';
            'QTD_LIN',                          'double',       [],     'Quantidade total de linhas do arquivo.';
            'QTD_LIN_0',                        'double',       [],     'Quantidade total de linhas do Bloco 0.';
            'QTD_LIN_1',                        'double',       'bank', 'Quantidade total de linhas do Bloco 1';
            'QTD_LIN_9',                        'double',       [],     'Quantidade total de linhas do Bloco 9.';
            'QTD_LIN_B',                        'double',       'bank', 'Quantidade total de linhas do Bloco B N - - O O O';
            'QTD_LIN_C',                        'double',       'bank', 'Quantidade total de linhas do Bloco C N - - O O';
            'QTD_LIN_D',                        'double',       'bank', 'Quantidade total de linhas do Bloco D N - - O O';
            'QTD_LIN_E',                        'double',       'bank', 'Quantidade total de linhas do Bloco E';
            'QTD_LIN_H',                        'double',       'bank', 'Quantidade total de linhas do Bloco H';
            'QTD_LIN_I',                        'double',       [],     'Quantidade total de linhas do Bloco I.';
            'QTD_LIN_J',                        'double',       [],     'Quantidade total de linhas do Bloco J.';
            'QTD_LIN_K',                        'double',       [],     'Quantidade total de linhas do Bloco K.';
            'QTD_OCOR',                         'double',       'bank', 'Quantidade de ocorrências na conta';
            'QTD_PARC',                         'double',       'bank', 'Quantidade de parcelas a receber/pagar N 002 - O O';
            'QTD_PROF',                         'double',       'bank', 'Quantidade de profissionais habilitados';
            'QTD_REG_BLC',                      'double',       [],     'Total de registros do tipo informado.';
            'QTD_VOL',                          'double',       'bank', 'Quantidade de volumes transportados';
            'QTDE',                             'cell',         [],     'Quantidade, deste item da nota fiscal, que foi aplicada neste bem, expressa na mesma unidade constante no documento fiscal de entrada';
            'QUANT_BC_COFINS',                  'double',       'bank', 'Quantidade - Base de cálculo da COFINS.';
            'QUANT_BC_PIS',                     'double',       'bank', 'Quantidade – Base de cálculo PIS N - 03 OC OC';
            'QUANT_CONV',                       'double',       'bank', 'Quantidade do item no documento fiscal de saída de acordo com as instruções de preenchimento.';
            'QUANT_PAD',                        'double',       'bank', 'Quantidade total de produtos na unidade padrão de tributação';
            'QUANT_ULT_E',                      'double',       'bank', 'Quantidade do item relativa a última entrada';
            'REG',                              'cell',         [],     'Texto fixo do registro.';
            'REG_BLC',                          'cell',         [],     'Registro a ser totalizado.';
            'REG_COD',                          'cell',         [],     'CÃƒÂ³digo do registro.';
            'RZ_CONT',                          'cell',         [],     'ConteÃƒÂºdo dos campos do registro I510.';
            'RZ_CONT_TOT',                      'cell',         [],     'ConteÃƒÂºdo dos campos do registro I510.';
            'SER',                              'cell',         [],     'Série do documento fiscal recebido com fins específicos de exportação.';
            'SER_DOC_REF',                      'cell',         [],     'Serie do documento fiscal referenciado.';
            'SER_NFE_RET',                      'cell',         [],     'Série da NF-e em que houve a retenção do ICMS ST';
            'SER_ULT_E',                        'cell',         [],     'Série do documento fiscal relativa a última entrada';
            'SERIE',                            'cell',         [],     'Série do documento fiscal';
            'SLD_CRED',                         'cell',         [],     'Saldo de créditos fiscais de períodos anteriores';
            'SLD_CRED_FIM',                     'cell',         [],     'Saldo de crédito fiscal acumulado a transportar para o período seguinte';
            'SUB',                              'cell',         [],     'Subsérie do documento fiscal N 003 - OC OC';
            'SUB_SER',                          'cell',         [],     'Subsérie do documento fiscal';
            'SUFRAMA',                          'cell',         [],     'InscriÃƒÂ§ÃƒÂ£o na Suframa.';
            'TAM_CAMPO',                        'cell',         [],     'Tamanho do campo.';
            'TAM_FONTE',                        'cell',         [],     'Tamanho da fonte.';
            'TEMPER',                           'cell',         [],     'Temperatura em graus Celsius utilizada para quantificação do volume de combustível';
            'TERMINAL',                         'cell',         [],     'Identificação do terminal faturado';
            'TIP_ECD',                          'cell',         [],     'Indicador do tipo de ECD.';
            'TIP_ECD_REC',                      'cell',         [],     'Indicador do tipo da ECD.';
            'TIP_FAT',                          'cell',         [],     'Tipo de faturamento do documento eletronico.';
            'TIPO',                             'cell',         [],     'IndicaÃƒÂ§ÃƒÂ£o do tipo de dado.';
            'TIPO_CAMPO',                       'cell',         [],     'Tipo do campo.';
            'TIPO_DOC',                         'cell',         [],     'Tipo de documento.';
            'TIPO_ITEM',                        'cell',         [],     'Tipo do item – Atividades Industriais, Comerciais e Serviços: 00 – Mercadoria para Revenda; 01 – Matéria-prima; 02 – Embalagem; 03 – Produto em Processo; 04 – Produto Acabado; 05 – Subproduto; 06 – Produto Intermediário; 07 – Material de Uso e Consumo; 08 – Ativo Imobilizado; 09 – Serviços; 10 – Outros insumos; 99 – Outras';
            'TIPO_MEDICAO',                     'cell',         [],     'Identificador de medição: 0 – analógico 1 – digital';
            'TIPO_UTI',                         'cell',         [],     'Tipo de utilização do crédito.';
            'TOT_CREDITO',                      'cell',         [],     'Valor total das operações de crédito realizadas no período';
            'TOT_DEBITO',                       'cell',         [],     'Valor total das operações de débito realizadas no período';
            'TOTAL',                            'double',       'bank', 'Campo das tabelas customizadas "x_BALANCETE" e "x_APURACAO"';
            'TP_ASSINANTE',                     'cell',         [],     'Código do Tipo de Assinante: 1 - Comercial/Industrial 2 - Poder Público 3 - Residencial/Pessoa física 4 - Público 5 - Semi-Público 6 - Outros N 001* - OC O';
            'TP_CHC',                           'cell',         [],     'Informação do tipo de conhecimento de embarque: 01 – AWB; 02 – MAWB; 03 – HAWB; 04 – COMAT; 06 – R. EXPRESSAS; N 002* - O 07 – ETIQ. REXPRESSAS; 08 – HR. EXPRESSAS; 09 – AV7; 10 – BL; 11 – MBL; 12 – HBL; 13 – CRT; 14 – DSIC; 16 – COMAT BL; 17 – RWB; 18 – HRWB; 19 – TIF/DTA; 20 – CP2; 91 – NÂO IATA; 92 – MNAO IATA; 93 – HNAO IATA; 99 – OUTROS.';
            'TP_CT_E',                          'cell',         [],     'Tipo de Conhecimento de Transporte Eletrônico.';
            'TP_LIGACAO',                       'cell',         [],     'Código de tipo de Ligação 1 - Monofásico 2 - Bifásico 3 - Trifásico';
            'TP_PROD',                          'cell',         [],     'Tipo de produto: 0 - Similar; 1 - Genérico; 2 - Ético ou de marca; C 1* - O O';
            'TXT',                              'cell',         [],     'Texto livre da informação complementar existente no documento fiscal, inclusive espécie de normas legais, poder normativo, número, capitulação, data e demais referências pertinentes com indicações referentes ao tributo.';
            'TXT_COMPL',                        'cell',         [],     'Descrição complementar das obrigações recolhidas ou a recolher C - - OC 10 MES_REF* Informe o mês de referência no formato “mmaaaa”';
            'UF',                               'cell',         [],     'Unidade da federaÃƒÂ§ÃƒÂ£o.';
            'UF_CRC',                           'cell',         [],     'UF do CRC.';
            'UF_CRC_T',                         'cell',         [],     'UF do CRC.';
            'UF_EMIT',                          'cell',         [],     'Sigla da unidade da federação do participante emitente do modal';
            'UF_ID',                            'cell',         [],     'Sigla da UF da placa do veículo';
            'UF_ST',                            'cell',         [],     'Sigla da unidade da federação do contribuinte substituído ou unidade de federação do consumidor final não contribuinte - ICMS Destino EC 87/15.';
            'UF_TOM',                           'cell',         [],     'Sigla da unidade da federação do participante tomador do serviço';
            'UNID',                             'cell',         [],     'Unidade do item constante no documento fiscal de entrada';
            'UNID_CONV',                        'cell',         [],     'Unidade comercial a ser convertida na unidade de estoque, referida no registro 0200. Ou unidade do 0200 utilizada na EFD anterior.';
            'UNID_INV',                         'cell',         [],     'Unidade de medida utilizada na quantificação de estoques.';
            'VAL_ABERT',                        'double',       'bank', 'Valor da leitura inicial do contador, na abertura do bico.';
            'VAL_AG',                           'double',       'bank', 'Valor absoluto aglutinado.';
            'VAL_AJ_GANHO',                     'double',       'bank', 'Valor do ganho, em litros';
            'VAL_AJ_PERDA',                     'double',       'bank', 'Valor da Perda, em litros';
            'VAL_CRED_AUX',                     'double',       'bank', 'Total dos crÃƒÂ©ditos do dia em moeda funcional.';
            'VAL_CRED_MF',                      'double',       'bank', 'Total dos crÃƒÂ©ditos do dia em moeda funcional.';
            'VAL_CREDD',                        'double',       'bank', 'Total dos crÃƒÂ©ditos do dia.';
            'VAL_CS',                           'double',       'bank', 'Valor absoluto consolidado.';
            'VAL_DEB_AUX',                      'double',       'bank', 'Total dos dÃƒÂ©bitos do dia em moeda funcional.';
            'VAL_DEB_MF',                       'double',       'bank', 'Total dos dÃƒÂ©bitos do dia em moeda funcional.';
            'VAL_DEBD',                         'double',       'bank', 'Total dos dÃƒÂ©bitos do dia.';
            'VAL_EL',                           'double',       'bank', 'Valor absoluto das eliminaÃƒÂ§ÃƒÂµes.';
            'VAL_FECHA',                        'double',       'bank', 'Valor da leitura final do contador, no fechamento do bico.';
            'VALOR',                            'double',       'bank', 'Parcela do valor eliminado total.';
            'VEIC_ID',                          'cell',         [],     'Identificação da embarcação (IRIM ou Registro CPP)';
            'VIAGEM',                           'cell',         [],     'Número da viagem';
            'VL_ABAT_NT',                       'double',       'bank', 'Abatimento não tributado e não comercial Por exemplo: desconto ICMS nas remessas para ZFM. N - 02 OC OC';
            'VL_ACMO',                          'double',       'bank', 'Valor acumulado dos acréscimos';
            'VL_AJ',                            'double',       'bank', 'Valor do ajuste';
            'VL_AJ_APUR',                       'double',       'bank', 'Valor do ajuste da apuração';
            'VL_AJ_CREDITOS',                   'double',       'bank', 'Valor total dos ajustes a crédito decorrentes do documento fiscal.';
            'VL_AJ_CREDITOS_ST',                'double',       'bank', 'Valor total dos ajustes a crédito de ICMS ST, provenientes de ajustes do documento fiscal. N - 02 O 08 VL_RETENÇAO_ST Valor Total do ICMS retido por Substituição Tributária';
            'VL_AJ_DEBITOS',                    'double',       'bank', 'Valor total dos ajustes a débito decorrentes do documento fiscal.';
            'VL_AJ_DEBITOS_ST',                 'double',       'bank', 'Valor total dos ajustes a débito de ICMS ST, provenientes de ajustes do documento fiscal.';
            'VL_AJ_ITEM',                       'double',       'bank', 'Valor do ajuste para a operação/item';
            'VL_BC_COFINS',                     'double',       'bank', 'Valor da base de cálculo da COFINS N - 02 OC OC';
            'VL_BC_ICMS',                       'double',       'bank', 'Parcela correspondente ao "Valor da base de cálculo do ICMS" referente à combinação de CST_ICMS, CFOP e alíquota do ICMS. N - 02 OC O';
            'VL_BC_ICMS_APUR',                  'double',       'bank', 'Valor da base de cálculo do ICMS apurada (5 x 7)';
            'VL_BC_ICMS_ST',                    'double',       'bank', 'Parcela correspondente ao "Valor da base de cálculo do ICMS" da substituição tributária referente à combinação de CST_ICMS, CFOP e alíquota do ICMS. N - 02 OC O';
            'VL_BC_ICMS_UF',                    'double',       'bank', 'Parcela correspondente ao valor da base de cálculo do ICMS de outras UFs, referente à combinação de CST_ICMS, CFOP e alíquota do ICMS. N - 02 O O';
            'VL_BC_IPI',                        'double',       'bank', 'Parcela correspondente ao "Valor da base de cálculo do IPI" referente ao CFOP e ao Código de Tributação do IPI, para operações tributadas';
            'VL_BC_IRRF',                       'double',       'bank', 'Valor da base de cálculo do Imposto de Renda Retido na Fonte';
            'VL_BC_ISS',                        'double',       'bank', 'Totalização do Valor da base de cálculo do ISS das prestações do declarante referente à combinação da alíquota e item da lista';
            'VL_BC_ISS_P',                      'double',       'bank', 'Parcela correspondente ao “Valor da base de cálculo do ISS” referente à combinação da alíquota e item da lista N - 02 O O';
            'VL_BC_ISS_RT',                     'double',       'bank', 'H - Valor total da base de cálculo de retenção do ISS referente às prestações do declarante.';
            'VL_BC_ISSQN',                      'double',       'bank', 'Valor da base de cálculo do ISSQN';
            'VL_BC_PIS',                        'double',       'bank', 'Valor da base de cálculo do PIS N - 02 OC OC';
            'VL_BC_PREV',                       'double',       'bank', 'Valor da base de cálculo de retenção da Previdência Social';
            'VL_BRT',                           'double',       'bank', 'Valor da venda bruta';
            'VL_CANC',                          'double',       'bank', 'Valor acumulado dos cancelamentos';
            'VL_CARGA',                         'double',       'bank', 'Valor das prestações cargas (Tributado)';
            'VL_CFE',                           'double',       'bank', 'Valor total do Cupom Fiscal Eletrônico';
            'VL_COFINS',                        'double',       'bank', 'Valor total da COFINS N - 02 OC OC';
            'VL_COFINS_ST',                     'double',       'bank', 'Valor total da COFINS retido por substituição tributária N - 02 OC OC';
            'VL_CONT',                          'double',       'bank', 'Totalização do Valor Contábil das prestações do declarante referente à combinação da alíquota e item da lista';
            'VL_CONT_IPI',                      'double',       'bank', 'Parcela correspondente ao "Valor Contábil" referente ao CFOP e ao Código de Tributação do IPI';
            'VL_CONT_P',                        'double',       'bank', 'Parcela correspondente ao “Valor Contábil” referente à combinação da alíquota e item da lista N - 02 O O';
            'VL_CONT_RT',                       'double',       'bank', 'Totalização do Valor Contábil das prestações e/ou aquisições do declarante pela combinação de tipo de operação e participante. N - 02 O O';
            'VL_CRED',                          'double',       'bank', 'Valor total dos crÃƒÂ©ditos do perÃƒÂ­odo.';
            'VL_CRED_AUX',                      'double',       'bank', 'Valor total dos crÃƒÂ©ditos em moeda funcional.';
            'VL_CRED_IPI',                      'double',       'bank', 'Valor total dos créditos por "Entradas e aquisições com crédito do imposto"';
            'VL_CRED_MF',                       'double',       'bank', 'Valor total dos crÃƒÂ©ditos em moeda funcional.';
            'VL_CRED_REC',                      'double',       'bank', 'Valor total dos crÃƒÂ©ditos no perÃƒÂ­odo.';
            'VL_CRED_UTIL',                     'double',       'bank', 'Total de crédito utilizado';
            'VL_CTA',                           'double',       'bank', 'Valor do saldo final antes do encerramento.';
            'VL_CTA_AUX',                       'double',       'bank', 'Valor do saldo final em moeda funcional.';
            'VL_CTA_FIN',                       'double',       'bank', 'Valor final do cÃƒÂ³digo de aglutinaÃƒÂ§ÃƒÂ£o.';
            'VL_CTA_INI',                       'double',       'bank', 'Valor inicial do cÃƒÂ³digo de aglutinaÃƒÂ§ÃƒÂ£o.';
            'VL_CTA_INI_',                      'double',       'bank', 'Valor do saldo final do perÃƒÂ­odo anterior.';
            'VL_CTA_MF',                        'double',       'bank', 'Valor do saldo final em moeda funcional.';
            'VL_CTA_ULT_DRE',                   'double',       'bank', 'Valor do saldo final da ÃƒÂºltima DRE.';
            'VL_DA',                            'double',       'bank', 'Valor do total do documento de arrecadação (principal, atualização monetária, juros e multa) N - 02 O O';
            'VL_DC',                            'double',       'bank', 'Valor da partida.';
            'VL_DC_AUX',                        'double',       'bank', 'Valor da partida em moeda funcional.';
            'VL_DC_MF',                         'double',       'bank', 'Valor da partida em moeda funcional.';
            'VL_DEB',                           'double',       'bank', 'Valor total dos dÃƒÂ©bitos do perÃƒÂ­odo.';
            'VL_DEB_AUX',                       'double',       'bank', 'Valor total dos dÃƒÂ©bitos em moeda funcional.';
            'VL_DEB_IPI',                       'double',       'bank', 'Valor total dos débitos por "Saídas com débito do imposto"';
            'VL_DEB_MF',                        'double',       'bank', 'Total dos dÃƒÂ©bitos em moeda funcional.';
            'VL_DEB_REC',                       'double',       'bank', 'Valor total dos dÃƒÂ©bitos no perÃƒÂ­odo.';
            'VL_DED',                           'double',       'bank', 'K - Valor total das deduções do ISS próprio';
            'VL_DED_BC',                        'double',       'bank', 'F - Valor total das deduções da base de cálculo (B + C + D + E)';
            'VL_DEDUCOES_ST',                   'double',       'bank', 'Valor total das deduções do ICMS ST.';
            'VL_DESC',                          'double',       'bank', 'Valor do desconto comercial N - 02 OC OC';
            'VL_DESP',                          'double',       'bank', 'Soma de valores de despacho';
            'VL_DESP_CAR_DESC',                 'double',       'bank', 'Valor das despesas de carga e descarga.';
            'VL_DESP_PORT',                     'double',       'bank', 'Valor das despesas portuárias';
            'VL_DEVOL_ST',                      'double',       'bank', 'Valor total do ICMS ST de devolução de mercadorias';
            'VL_DIF',                           'double',       'bank', 'Valor da diferença a ser levada a estorno de crédito na apuração (6 - 8) N';
            'VL_DOC',                           'double',       'bank', 'Valor total acumulado dos documentos fiscais';
            'VL_ESTORNOS_CRED',                 'double',       'bank', 'Valor total de Ajustes “Estornos de créditos”';
            'VL_ESTORNOS_DEB',                  'double',       'bank', 'Valor total de Ajustes “Estornos de Débitos”';
            'VL_FAT',                           'double',       'bank', 'Valor total do faturamento (2+3)';
            'VL_FAT_CONT',                      'double',       'bank', 'Valor do fato contÃƒÂ¡bil.';
            'VL_FCP_OP',                        'double',       'bank', 'Valor do Fundo de Combate à Pobreza (FCP) vinculado à operação própria, na combinação de CST_ICMS, CFOP e alíquota do ICMS N - 02 OC OC';
            'VL_FCP_RET',                       'double',       'bank', 'Valor do Fundo de Combate à Pobreza retido por substituição tributária.';
            'VL_FCP_ST',                        'double',       'bank', 'Valor do Fundo de Combate à Pobreza (FCP) vinculado à operação de substituição tributária, na combinação de CST_ICMS, CFOP e alíquota do ICMS. N - 02 OC OC';
            'VL_FORN',                          'double',       'bank', 'Valor total fornecido/consumido N - 02 O O';
            'VL_FRT',                           'double',       'bank', 'Valor do frete indicado no documento fiscal N - 02 OC OC';
            'VL_FRT_BRT',                       'double',       'bank', 'Valor bruto do frete';
            'VL_FRT_LIQ',                       'double',       'bank', 'Valor líquido do frete';
            'VL_FRT_MM',                        'double',       'bank', 'Valor adicional do frete para renovação da Marinha Mercante';
            'VL_GRIS',                          'double',       'bank', 'Valor do gris (gerenciamento de risco)';
            'VL_ICMS',                          'double',       'bank', 'Parcela correspondente ao "Valor do ICMS" referente à combinação CST_ICMS, CFOP, e alíquota do ICMS, incluindo o FCP, quando aplicável, referente à combinação de CST_ICMS, CFOP e alíquota do ICMS. N - 02 O O';
            'VL_ICMS_ANT',                      'double',       'bank', 'Valor total dos créditos do ICMS';
            'VL_ICMS_APUR',                     'double',       'bank', 'Valor do ICMS apurado no cálculo (5 x 6)';
            'VL_ICMS_RECOL_ST',                 'double',       'bank', 'Imposto a recolher ST (11-12)';
            'VL_ICMS_RECOLHER',                 'double',       'bank', 'Valor total de "ICMS a recolher (11-12)';
            'VL_ICMS_ST',                       'double',       'bank', 'Parcela correspondente ao valor creditado/debitado do ICMS da substituição tributária, incluindo o FCP_ ST, quando aplicável, referente à combinação de CST_ICMS, CFOP, e alíquota do ICMS. N - 02 O O';
            'VL_ICMS_UF',                       'double',       'bank', 'Parcela correspondente ao valor do ICMS de outras UFs, referente à combinação de CST_ICMS, CFOP, e alíquota do ICMS. N - 02 O O';
            'VL_INF_ADIC',                      'double',       'bank', 'Valor referente à informação adicional';
            'VL_INV',                           'double',       'bank', 'Valor total do estoque';
            'VL_IPI',                           'double',       'bank', 'Parcela correspondente ao "Valor do IPI" referente ao CFOP e ao Código de Tributação do IPI, para operações tributadas';
            'VL_IRRF',                          'double',       'bank', 'Valor do Imposto de Renda Retido na Fonte.';
            'VL_ISEN',                          'double',       'bank', 'Valor das saídas isentas do ICMS';
            'VL_ISNT',                          'double',       'bank', 'E - Valor total das operações isentas ou não-tributadas pelo ISS';
            'VL_ISNT_ISS',                      'double',       'bank', 'Totalização do valor das operações isentas ou não-tributadas pelo ISS referente à combinação da alíquota e item da lista';
            'VL_ISNT_ISS_P',                    'double',       'bank', 'Parcela correspondente ao “Valor das operações isentas ou não- tributadas pelo ISS” referente à combinação da alíquota e item da lista N - 02 O O';
            'VL_ISS',                           'double',       'bank', 'Totalização, por combinação da alíquota e item da lista, do Valor do ISS';
            'VL_ISS_P',                         'double',       'bank', 'Parcela correspondente ao “Valor do ISS” referente à combinação da alíquota e item da lista N - 02 O O';
            'VL_ISS_REC',                       'double',       'bank', 'Valor do ISS recolhido.';
            'VL_ISS_REC_UNI',                   'double',       'bank', 'N - Valor do ISS próprio a recolher pela Sociedade Uniprofissional';
            'VL_ISS_RT',                        'double',       'bank', 'Totalização do Valor do ISS retido pelo tomador das prestações e/ou aquisições do declarante pela combinação de tipo de operação e participante. N - 02 O O';
            'VL_ISS_ST',                        'double',       'bank', 'Valor do ISS retido por substituição tributária.';
            'VL_ISSQN',                         'double',       'bank', 'Valor do ISSQN';
            'VL_ITEM',                          'double',       'bank', 'Valor total do item (mercadorias ou serviços) N - 02 O O';
            'VL_LCTO',                          'double',       'bank', 'Valor do lanÃƒÂ§amento.';
            'VL_LCTO_AUX',                      'double',       'bank', 'Valor do lanÃƒÂ§amento em moeda funcional.';
            'VL_LCTO_MF',                       'double',       'bank', 'Valor do lanÃƒÂ§amento em moeda funcional.';
            'VL_LIQ_FRT',                       'double',       'bank', 'Valor líquido do frete';
            'VL_MAT_PROP',                      'double',       'bank', 'C - Valor do material próprio utilizado na prestação do serviço';
            'VL_MAT_TERC',                      'double',       'bank', 'B - Valor total do material fornecido por terceiros na prestação do serviço';
            'VL_MERC',                          'double',       'bank', 'Valor das mercadorias constantes no documento fiscal';
            'VL_NT',                            'double',       'bank', 'Valor das saídas sob não-incidência ou não- tributadas pelo ICMS';
            'VL_OC_IPI',                        'double',       'bank', 'Valor de "Outros créditos" do IPI (inclusive estornos de débitos)';
            'VL_OD_IPI',                        'double',       'bank', 'Valor de "Outros débitos" do IPI (inclusive estornos de crédito)';
            'VL_OPR',                           'double',       'bank', 'Valor da operação na combinação de CST_ICMS, CFOP e alíquota do ICMS, correspondente ao somatório do valor das mercadorias, despesas acessórias (frete, seguros e outras despesas acessórias), ICMS_ST, FCP_ST e IPI. N - 02 O O';
            'VL_OR',                            'double',       'bank', 'Valor da obrigação recolhida ou a recolher';
            'VL_OUT',                           'double',       'bank', 'DESP Valor de outras despesas';
            'VL_OUT_CRED_ST',                   'double',       'bank', 'Valor total de Ajustes "Outros créditos ST" e “Estorno de débitos ST”';
            'VL_OUT_DA',                        'double',       'bank', 'Valor total de outras despesas acessórias e acréscimos';
            'VL_OUT_DEB_ST',                    'double',       'bank', 'Valor Total dos ajustes "Outros débitos ST" " e “Estorno de créditos ST”';
            'VL_OUTDESP',                       'double',       'bank', 'Valor de outras despesas.';
            'VL_OUTROS',                        'double',       'bank', 'Outros valores N - 02 OC OC';
            'VL_PARC',                          'double',       'bank', 'Valor da parcela a receber/pagar N - 02 O O';
            'VL_PASS',                          'double',       'bank', 'Valor das prestações passageiros/cargas (Não Tributado)';
            'VL_PDG',                           'double',       'bank', 'Somatório dos valores de pedágio';
            'VL_PEDG',                          'double',       'bank', 'Soma dos valores de pedágio';
            'VL_PESO_TX',                       'double',       'bank', 'Peso taxado';
            'VL_PIS',                           'double',       'bank', 'Valor total do PIS N - 02 OC OC';
            'VL_PIS_ST',                        'double',       'bank', 'Valor total do PIS retido por substituição tributária N - 02 OC OC';
            'VL_PREV',                          'double',       'bank', 'Valor da retenção da Previdência Social.';
            'VL_REC',                           'double',       'bank', 'Valor mensal das receitas auferidas pela sociedade uniprofissional';
            'VL_RED_BC',                        'double',       'bank', 'Valor não tributado em função da redução da base de cálculo do ICMS, referente à combinação de CST_ICMS, CFOP e alíquota do ICMS. N - 02 OC O';
            'VL_RESSARC_ST',                    'double',       'bank', 'Valor total do ICMS ST de ressarcimentos';
            'VL_RETENCAO_ST',                   'double',       'bank', 'Valor total do ICMS retido por substituição tributária.';
            'VL_SC_IPI',                        'double',       'bank', 'Valor do saldo credor do IPI a transportar para o período seguinte';
            'VL_SD_ANT_IPI',                    'double',       'bank', 'Saldo credor do IPI transferido do período anterior';
            'VL_SD_IPI',                        'double',       'bank', 'Valor do saldo devedor do IPI a recolher';
            'VL_SEC_CAT',                       'double',       'bank', 'Soma de valores de Sec/Cat (serviços de coleta/custo adicional de transporte)';
            'VL_SEG',                           'double',       'bank', 'Valor do seguro indicado no documento fiscal N - 02 OC OC';
            'VL_SERV',                          'double',       'bank', 'Valor acumulado das prestações de serviços tributados pelo ICMS';
            'VL_SERV_NT',                       'double',       'bank', 'Valores cobrados em nome do prestador sem destaque de ICMS. N - 2 OC OC';
            'VL_SLD_APURADO',                   'double',       'bank', 'Valor do saldo devedor apurado';
            'VL_SLD_CRED_ANT_ST',               'double',       'bank', 'Valor do "Saldo credor de período anterior – Substituição Tributária"';
            'VL_SLD_CRED_ST_TRANSPORTAR',       'double',       'bank', 'Valor do saldo credor de ICMS ST a transportar para o período seguinte.';
            'VL_SLD_CREDOR_ANT',                'double',       'bank', 'Valor total de "Saldo credor do período anterior"';
            'VL_SLD_CREDOR_TRANSPORTAR',        'double',       'bank', 'Valor do saldo credor a transportar para o período seguinte.';
            'VL_SLD_DEV_ANT_ST',                'double',       'bank', 'Valor total de Saldo devedor antes das deduções N - 02 O 12 VL_DEDUÇÕES_ST Valor total dos ajustes "Deduções ST"';
            'VL_SLD_FIN',                       'double',       'bank', 'Valor do saldo final.';
            'VL_SLD_FIN_AUX',                   'double',       'bank', 'Valor do saldo final em moeda funcional.';
            'VL_SLD_FIN_MF',                    'double',       'bank', 'Valor do saldo final em moeda funcional.';
            'VL_SLD_FIN_REC',                   'double',       'bank', 'Valor do saldo final recuperado.';
            'VL_SLD_INI',                       'double',       'bank', 'Valor do saldo inicial.';
            'VL_SLD_INI_AUX',                   'double',       'bank', 'Valor do saldo inicial em moeda funcional.';
            'VL_SLD_INI_MF',                    'double',       'bank', 'Valor do saldo inicial em moeda funcional.';
            'VL_SLD_INI_REC',                   'double',       'bank', 'Valor do saldo inicial recuperado.';
            'VL_SUB',                           'double',       'bank', 'D - Valor total das subempreitadas';
            'VL_TAB_MAX',                       'double',       'bank', 'Valor do preço tabelado ou valor do preço máximo N - 02 O O';
            'VL_TERC',                          'double',       'bank', 'Valor total cobrado em nome de terceiros N - 02 OC OC';
            'VL_TIT',                           'double',       'bank', 'Valor total dos títulos de créditos N - 02 O O';
            'VL_TOT_AJ_CREDITOS',               'double',       'bank', 'Valor total de "Ajustes a crédito"';
            'VL_TOT_AJ_DEBITOS',                'double',       'bank', 'Valor total de "Ajustes a débito"';
            'VL_TOT_CREDITOS',                  'double',       'bank', 'Valor total dos créditos por "Entradas e aquisições com crédito do imposto"';
            'VL_TOT_DEBITOS',                   'double',       'bank', 'Valor total dos débitos por "Saídas e prestações com débito do imposto"';
            'VL_TOT_DED',                       'double',       'bank', 'Valor total de "Deduções"';
            'VL_TX_ADV',                        'double',       'bank', 'Valor da taxa "ad valorem"';
            'VL_TX_RED',                        'double',       'bank', 'Valor da taxa de redespacho';
            'VL_TX_TERR',                       'double',       'bank', 'Valor da taxa terrestre';
            'VL_UNID',                          'double',       'bank', 'Valor por unidade padrão de tributação';
            'VL_UNIT',                          'double',       'bank', 'Valor unitário do item';
            'VL_UNIT_BC_ICMS_ST_CONV',          'double',       'bank', 'Valor unitário da base de cálculo do ICMS ST convertido.';
            'VL_UNIT_BC_ICMS_ULT_E',            'double',       'bank', 'Valor unitário da base de cálculo do ICMS da última entrada.';
            'VL_UNIT_BC_ST',                    'double',       'bank', 'Valor unitário da base de cálculo do imposto pago por substituição.';
            'VL_UNIT_CONV',                     'double',       'bank', 'Valor unitário da mercadoria, considerando a unidade utilizada para informar o campo “QUANT_CONV”.';
            'VL_UNIT_FCP_ICMS_ST_ESTOQUE_CONV', 'double',       'bank', 'Valor unitário do FCP ICMS ST em estoque convertido.';
            'VL_UNIT_FCP_ST_CONV',              'double',       'bank', '_COMPL Valor unitário correspondente à parcela de ICMS FCP ST que compõe o campo “VL_UNIT_ICMS_ST_CONV_COMPL ”, considerando unidade utilizada para informar o campo “QUANT_CONV”.';
            'VL_UNIT_FCP_ST_CONV_COMPL',        'double',       'bank', 'Valor unitário do FCP ST convertido para complementação.';
            'VL_UNIT_FCP_ST_CONV_REST',         'double',       'bank', 'Valor unitário do FCP ST convertido para restituição.';
            'VL_UNIT_ICMS_NA_OPERACAO_CONV',    'double',       'bank', 'Valor unitário do ICMS na operação convertido.';
            'VL_UNIT_ICMS_OP_CONV',             'double',       'bank', 'Valor unitário do ICMS OP calculado conforme a legislação de cada UF, considerando a unidade utilizada para informar o campo “QUANT_CONV”, utilizado para cálculo de ressarcimento/restituição de ST, no desfazimento da substituição tributária, quando se utiliza a fórmula descrita nas instruções de preenchimento do campo 15, no item a1).';
            'VL_UNIT_ICMS_OP_ESTOQUE_CONV',     'double',       'bank', 'Valor unitário do ICMS da operação em estoque convertido.';
            'VL_UNIT_ICMS_ST_CONV',             'double',       'bank', '_REST Valor unitário do total do ICMS ST, incluindo FCP ST, a ser restituído/ressarcido, calculado conforme a legislação de cada UF, considerando a unidade utilizada para informar o campo “QUANT_CONV”.';
            'VL_UNIT_ICMS_ST_CONV_COMPL',       'double',       'bank', 'Valor unitário do ICMS ST convertido para complementação.';
            'VL_UNIT_ICMS_ST_CONV_REST',        'double',       'bank', 'Valor unitário do ICMS ST convertido para restituição.';
            'VL_UNIT_ICMS_ST_ESTOQUE_CONV',     'double',       'bank', 'Valor unitário do ICMS ST em estoque convertido.';
            'VL_UNIT_ICMS_ULT_E',               'double',       'bank', 'Valor unitário do ICMS da última entrada.';
            'VL_UNIT_LIMITE_BC_ICMS_ULT_E',     'double',       'bank', 'Valor unitário do limite da base de cálculo do ICMS da última entrada.';
            'VL_UNIT_RES',                      'double',       'bank', 'Valor unitário do ressarcimento (parcial ou completo) de ICMS decorrente da quebra da ST';
            'VL_UNIT_RES_FCP_ST',               'double',       'bank', 'Valor unitário do ressarcimento de FCP ST.';
            'VL_UNIT_ULT_E',                    'double',       'bank', 'Valor unitário da mercadoria constante na NF relativa a última entrada inclusive despesas acessórias.';
            'VLR_ACUM_TOT',                     'cell',         [],     'Valor acumulado no totalizador, relativo à respectiva Redução Z.';
            'VOL_AFERI',                        'double',       'bank', 'Aferições da Bomba, em litros';
            'VOL_DISP',                         'double',       'bank', 'Volume Disponível (04 + 05), em litros';
            'VOL_ENTR',                         'double',       'bank', 'Volume Recebido no dia (em litros)';
            'VOL_SAIDAS',                       'double',       'bank', 'Volume Total das Saídas, em litros';
            'VOL_VENDAS',                       'double',       'bank', 'Volume de vendas no período, em litros.' ...
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

            classMeta = meta.class.fromName('model.EFDBase');

            tableIdPrefix = 'x';
            prefixedProps = classMeta.PropertyList(startsWith({classMeta.PropertyList.Name}, tableIdPrefix));
            
            implementedTableIds = {prefixedProps.Name};
            if removePrefixFlag
                implementedTableIds = extractAfter(implementedTableIds, tableIdPrefix);
            end
        end

        %-------------------------------------------------------%
        function [status, missingFields] = validateFieldMapping()
            implementedTableIds = model.EFDBase.getImplementedTableIds(false);
            availableFieldNames = model.EFDBase.FieldSpecification.Field;

            mappedFields = {};        
            for ii = 1:numel(implementedTableIds)
                tableFieldSubset = model.EFDBase.(implementedTableIds{ii})(:, 2:3);
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

            tbl = model.EFDBase.FieldSpecification;
            [isFound, indexes] = ismember(field, tbl.Field);

            if any(~isFound)
                error("EFDBase:getFieldSpecification:UnknownField", "Unknown field(s): %s", strjoin(field(~isFound), ", "));
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
                    error('EFDBase:UnexpectedDataType', 'Unexpected data type "%s"', dataType)
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
                         error('EFDBase:UnexpectedTableWidth', 'Unexpected table width - Expected: %d or %d, Received: %d', numRequiredColumns, numCompleteColumns, numInputColumns)
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
                        'VariableNames', {'COD_CTA', 'Apurado?  Ã¢Å“Å½', 'InterconexÃƒÂ£o?  Ã¢Å“Å½', 'AlÃƒÂ­quota ICMS', 'ObservaÃƒÂ§ÃƒÂ£o  Ã¢Å“Å½'} ...
                    );
              
                case '_CONTAS_DESCRICAO'
                    numAccounts = varargin{1};
                    tableOut = table( ...
                        'Size', [numAccounts, 2], ...
                        'VariableNames', {'COD_CTA', 'DESCRIÃƒâ€¡ÃƒÆ’O'}, ...
                        'VariableTypes', {'cell', 'cell'} ...
                    );

                case '_CONTAS_HISTORICO'
                    numAccounts = varargin{1};
                    tableOut = table( ...
                        'Size', [numAccounts, 3], ...
                        'VariableNames', {'COD_CTA', 'TOTAL DE LANÃƒâ€¡AMENTOS', 'LANÃƒâ€¡AMENTOS NORMALIZADOS DEDUPLICADOS'}, ...
                        'VariableTypes', {'cell', 'double', 'cell'} ...
                    );

                case '_APURACAO_GERAL'
                    tableOut = table( ...
                        'Size', [11, 14], ...
                        'VariableNames', {'TIPO', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                        'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'} ...
                    );
                    tableOut.("TIPO")(:) = {'ROB TELECOM'; 'ICMS ESTIMADO'; 'ICMS CONTÃƒÂBIL'; 'BASE DE CÃƒÂLCULO (PIS/COFINS)'; 'PIS ESTIMADO'; 'PIS CONTÃƒÂBIL'; 'COFINS ESTIMADO'; 'COFINS CONTÃƒÂBIL'; 'BASE DE CÃƒÂLCULO (FUST/FUNTTEL)'; 'VALOR APURADO FUST'; 'VALOR APURADO FUNTTEL'};

                case '_APURACAO_INTERCONEXAO'
                    tableOut = table( ...
                        'Size', [8, 14], ...
                        'VariableNames', {'TIPO', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                        'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'} ...
                    );
                    tableOut.("TIPO")(:) = {'ROB TELECOM'; 'ICMS ESTIMADO'; 'BASE DE CÃƒÂLCULO (PIS/COFINS)'; 'PIS ESTIMADO'; 'COFINS ESTIMADO'; 'BASE DE CÃƒÂLCULO (FUST/FUNTTEL)'; 'VALOR APURADO FUST'; 'VALOR APURADO FUNTTEL'};

                case '_CONCILIACAO_GERAL'
                    tableOut = table( ...
                        'Size', [5, 14], ...
                        'VariableNames', {'TIPO', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', 'TOTAL'}, ...
                        'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'} ...
                    );
                    tableOut.("TIPO")(:) = {'ROB TELECOM'; 'ICMS ESTIMADO'; 'ICMS CONTÃƒÂBIL'; 'PIS CONTÃƒÂBIL'; 'COFINS CONTÃƒÂBIL'};

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
