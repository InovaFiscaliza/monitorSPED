classdef (Abstract) EFDCBase
    % Registro de campos para EFD Contribuições (EFDC)
    % Layout versão 1.35+
    % Diferenças principais em relação ao EFDI:
    % - Registro 0000: 14 campos vs 15 (falta IND_PERFIL, adicionado IND_NAT_PJ, IND_ATIV)
    % - Bloco C/D/M: diferenças nos registros de operação
    % - Compostas: A100_A170, C100_C170_C175, C180_C181_C185, D600_D601_D605

    properties (Constant)
        %-------------------------------------------------------%
        % Layouts conforme Guia Pratico da EFD-Contribuicoes. Campos opcionais (terceira
        % celula) sao os acrescentados em versoes mais recentes do leiaute.
        % Bloco 0
        x0000 = {1, {'REG', 'COD_VER', 'TIPO_ESCRIT', 'IND_SIT_ESP', 'NUM_REC_ANTERIOR', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'COD_MUN', 'SUFRAMA', 'IND_NAT_PJ', 'IND_ATIV'}, {}}
        x0001 = {1, {'REG', 'IND_MOV'}, {}}
        x0100 = {1, {'REG', 'NOME', 'CPF', 'CRC', 'CNPJ', 'CEP', 'END', 'NUM', 'COMPL', 'BAIRRO', 'FONE', 'FAX', 'EMAIL', 'COD_MUN'}, {}}
        x0110 = {1, {'REG', 'COD_INC_TRIB', 'IND_APRO_CRED', 'COD_TIPO_CONT', 'IND_REG_CUM'}, {}}
        x0111 = {1, {'REG', 'REC_BRU_NCUM_TRIB_MI', 'REC_BRU_NCUM_NT_MI', 'REC_BRU_NCUM_EXP', 'REC_BRU_CUM', 'REC_BRU_TOTAL'}, {}}
        x0120 = {1, {'REG', 'MES_REFER', 'INF_COMP'}, {}}
        x0140 = {1, {'REG', 'COD_EST', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'SUFRAMA'}, {}}
        x0145 = {1, {'REG', 'COD_INC_TRIB', 'VL_REC_TOT', 'VL_REC_ATIV', 'VL_REC_DEMAIS_ATIV', 'INFO_COMPL'}, {}}
        x0150 = {1, {'REG', 'COD_PART', 'NOME', 'COD_PAIS', 'CNPJ', 'CPF', 'IE', 'COD_MUN', 'SUFRAMA', 'END', 'NUM', 'COMPL', 'BAIRRO'}, {}}
        x0190 = {1, {'REG', 'UNID', 'DESCR'}, {}}
        x0200 = {1, {'REG', 'COD_ITEM', 'DESCR_ITEM', 'COD_BARRA', 'COD_ANT_ITEM', 'UNID_INV', 'TIPO_ITEM', 'COD_NCM', 'EX_IPI', 'COD_GEN', 'COD_LST', 'ALIQ_ICMS'}, {}}
        x0206 = {1, {'REG', 'COD_COMB'}, {}}
        x0208 = {1, {'REG', 'COD_TAB', 'COD_GRU', 'MARCA_COM'}, {}}
        x0400 = {1, {'REG', 'COD_NAT', 'DESCR_NAT'}, {}}
        x0450 = {1, {'REG', 'COD_INF', 'TXT'}, {}}
        x0500 = {1, {'REG', 'DT_ALT', 'COD_NAT_CC', 'IND_CTA', 'NIVEL', 'COD_CTA', 'NOME_CTA', 'COD_CTA_REF', 'CNPJ_EST'}, {}}
        x0600 = {1, {'REG', 'DT_ALT', 'COD_CCUS', 'CCUS'}, {}}
        x0990 = {1, {'REG', 'QTD_LIN_0'}, {}}

        % Bloco A
        xA001 = {1, {'REG', 'IND_MOV'}, {}}
        xA010 = {1, {'REG', 'CNPJ'}, {}}
        xA100 = {1, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_SIT', 'SER', 'SUB', 'NUM_DOC', 'CHV_NFSE', 'DT_DOC', 'DT_EXE_SERV', 'VL_DOC', 'IND_PGTO', 'VL_DESC', 'VL_BC_PIS', 'VL_PIS', 'VL_BC_COFINS', 'VL_COFINS', 'VL_PIS_RET', 'VL_COFINS_RET', 'VL_ISS'}, {}}
        xA110 = {1, {'REG', 'COD_INF', 'TXT_COMPL'}, {}}
        xA111 = {1, {'REG', 'NUM_PROC', 'IND_PROC'}, {}}
        xA120 = {1, {'REG', 'VL_TOT_SERV', 'VL_BC_PIS', 'VL_PIS_IMP', 'DT_PAG_PIS', 'VL_BC_COFINS', 'VL_COFINS_IMP', 'DT_PAG_COFINS', 'LOC_EXE_SERV'}, {}}
        xA170 = {1, {'REG', 'NUM_ITEM', 'COD_ITEM', 'DESCR_COMPL', 'VL_ITEM', 'VL_DESC', 'NAT_BC_CRED', 'IND_ORIG_CRED', 'CST_PIS', 'VL_BC_PIS', 'ALIQ_PIS', 'VL_PIS', 'CST_COFINS', 'VL_BC_COFINS', 'ALIQ_COFINS', 'VL_COFINS', 'COD_CTA', 'COD_CCUS'}, {}}
        xA990 = {1, {'REG', 'QTD_LIN_A'}, {}}

        % Bloco C
        xC001 = {1, {'REG', 'IND_MOV'}, {}}
        xC010 = {1, {'REG', 'CNPJ', 'IND_ESCRI'}, {}}
        xC100 = {1, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'NUM_DOC', 'CHV_NFE', 'DT_DOC', 'DT_E_S', 'VL_DOC', 'IND_PGTO', 'VL_DESC', 'VL_ABAT_NT', 'VL_MERC', 'IND_FRT', 'VL_FRT', 'VL_SEG', 'VL_OUT_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'VL_ICMS_ST', 'VL_IPI', 'VL_PIS', 'VL_COFINS', 'VL_PIS_ST', 'VL_COFINS_ST'}, {}}
        xC110 = {1, {'REG', 'COD_INF', 'TXT_COMPL'}, {}}
        xC111 = {1, {'REG', 'NUM_PROC', 'IND_PROC'}, {}}
        xC120 = {1, {'REG', 'COD_DOC_IMP', 'NUM_DOC_IMP', 'VL_PIS_IMP', 'VL_COFINS_IMP', 'NUM_ACDRAW'}, {}}
        xC170 = {1, {'REG', 'NUM_ITEM', 'COD_ITEM', 'DESCR_COMPL', 'QTD', 'UNID', 'VL_ITEM', 'VL_DESC', 'IND_MOV', 'CST_ICMS', 'CFOP', 'COD_NAT', 'VL_BC_ICMS', 'ALIQ_ICMS', 'VL_ICMS', 'VL_BC_ICMS_ST', 'ALIQ_ST', 'VL_ICMS_ST', 'IND_APUR', 'CST_IPI', 'COD_ENQ', 'VL_BC_IPI', 'ALIQ_IPI', 'VL_IPI', 'CST_PIS', 'VL_BC_PIS', 'ALIQ_PIS', 'QUANT_BC_PIS', 'ALIQ_PIS_QUANT', 'VL_PIS', 'CST_COFINS', 'VL_BC_COFINS', 'ALIQ_COFINS', 'QUANT_BC_COFINS', 'ALIQ_COFINS_QUANT', 'VL_COFINS', 'COD_CTA'}, {}}
        xC175 = {1, {'REG', 'CFOP', 'VL_OPR', 'VL_DESC', 'CST_PIS', 'VL_BC_PIS', 'ALIQ_PIS', 'QUANT_BC_PIS', 'ALIQ_PIS_QUANT', 'VL_PIS', 'CST_COFINS', 'VL_BC_COFINS', 'ALIQ_COFINS', 'QUANT_BC_COFINS', 'ALIQ_COFINS_QUANT', 'VL_COFINS', 'COD_CTA'}, {'INFO_COMPL'}}
        xC180 = {1, {'REG', 'COD_MOD', 'DT_DOC_INI', 'DT_DOC_FIN', 'COD_ITEM', 'COD_NCM', 'EX_IPI', 'VL_TOT_ITEM'}, {}}
        xC181 = {1, {'REG', 'CST_PIS', 'CFOP', 'VL_ITEM', 'VL_DESC', 'VL_BC_PIS', 'ALIQ_PIS', 'QUANT_BC_PIS', 'ALIQ_PIS_QUANT', 'VL_PIS', 'COD_CTA'}, {}}
        xC185 = {1, {'REG', 'CST_COFINS', 'CFOP', 'VL_ITEM', 'VL_DESC', 'VL_BC_COFINS', 'ALIQ_COFINS', 'QUANT_BC_COFINS', 'ALIQ_COFINS_QUANT', 'VL_COFINS', 'COD_CTA'}, {}}
        xC190 = {1, {'REG', 'COD_MOD', 'DT_REF_INI', 'DT_REF_FIN', 'COD_ITEM', 'COD_NCM', 'EX_IPI', 'VL_TOT_ITEM'}, {}}
        xC500 = {1, {'REG', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'NUM_DOC', 'DT_DOC', 'DT_ENT', 'VL_DOC', 'VL_ICMS', 'COD_INF', 'VL_PIS', 'VL_COFINS'}, {'CHV_DOCE'}}
        xC501 = {1, {'REG', 'CST_PIS', 'VL_ITEM', 'NAT_BC_CRED', 'VL_BC_PIS', 'ALIQ_PIS', 'VL_PIS', 'COD_CTA'}, {}}
        xC505 = {1, {'REG', 'CST_COFINS', 'VL_ITEM', 'NAT_BC_CRED', 'VL_BC_COFINS', 'ALIQ_COFINS', 'VL_COFINS', 'COD_CTA'}, {}}
        xC990 = {1, {'REG', 'QTD_LIN_C'}, {}}

        % Bloco D
        xD001 = {1, {'REG', 'IND_MOV'}, {}}
        xD010 = {1, {'REG', 'CNPJ'}, {}}
        xD100 = {1, {'REG', 'IND_OPER', 'IND_EMIT', 'COD_PART', 'COD_MOD', 'COD_SIT', 'SER', 'SUB', 'NUM_DOC', 'CHV_CTE', 'DT_DOC', 'DT_A_P', 'TP_CT_E', 'CHV_CTE_REF', 'VL_DOC', 'VL_DESC', 'IND_FRT', 'VL_SERV', 'VL_BC_ICMS', 'VL_ICMS', 'VL_NT', 'COD_INF', 'COD_CTA'}, {}}
        xD101 = {1, {'REG', 'IND_NAT_FRT', 'VL_ITEM', 'CST_PIS', 'NAT_BC_CRED', 'VL_BC_PIS', 'ALIQ_PIS', 'VL_PIS', 'COD_CTA'}, {}}
        xD105 = {1, {'REG', 'IND_NAT_FRT', 'VL_ITEM', 'CST_COFINS', 'NAT_BC_CRED', 'VL_BC_COFINS', 'ALIQ_COFINS', 'VL_COFINS', 'COD_CTA'}, {}}
        xD600 = {1, {'REG', 'COD_MOD', 'COD_MUN', 'SER', 'SUB', 'IND_REC', 'QTD_CONS', 'DT_DOC_INI', 'DT_DOC_FIN', 'VL_DOC', 'VL_DESC', 'VL_SERV', 'VL_SERV_NT', 'VL_TERC', 'VL_DA', 'VL_BC_ICMS', 'VL_ICMS', 'VL_PIS', 'VL_COFINS'}, {}}
        xD601 = {1, {'REG', 'COD_CLASS', 'VL_ITEM', 'VL_DESC', 'CST_PIS', 'VL_BC_PIS', 'ALIQ_PIS', 'VL_PIS', 'COD_CTA'}, {}}
        xD605 = {1, {'REG', 'COD_CLASS', 'VL_ITEM', 'VL_DESC', 'CST_COFINS', 'VL_BC_COFINS', 'ALIQ_COFINS', 'VL_COFINS', 'COD_CTA'}, {}}
        xD990 = {1, {'REG', 'QTD_LIN_D'}, {}}

        % Bloco F
        xF001 = {1, {'REG', 'IND_MOV'}, {}}
        xF010 = {1, {'REG', 'CNPJ'}, {}}
        xF100 = {1, {'REG', 'IND_OPER', 'COD_PART', 'COD_ITEM', 'DT_OPER', 'VL_OPER', 'CST_PIS', 'VL_BC_PIS', 'ALIQ_PIS', 'VL_PIS', 'CST_COFINS', 'VL_BC_COFINS', 'ALIQ_COFINS', 'VL_COFINS', 'NAT_BC_CRED', 'IND_ORIG_CRED', 'COD_CTA', 'COD_CCUS', 'DESC_DOC_OPER'}, {}}
        xF120 = {1, {'REG', 'NAT_BC_CRED', 'IDENT_BEM_IMOB', 'IND_ORIG_CRED', 'IND_UTIL_BEM_IMOB', 'VL_OPER_DEP', 'PARC_OPER_NAO_BC_CRED', 'CST_PIS', 'VL_BC_PIS', 'ALIQ_PIS', 'VL_PIS', 'CST_COFINS', 'VL_BC_COFINS', 'ALIQ_COFINS', 'VL_COFINS', 'COD_CTA', 'COD_CCUS', 'DESC_BEM_IMOB'}, {}}
        xF990 = {1, {'REG', 'QTD_LIN_F'}, {}}

        % Bloco I
        xI001 = {1, {'REG', 'IND_MOV'}, {}}
        xI010 = {1, {'REG', 'CNPJ', 'IND_ATIV', 'INFO_COMPL'}, {}}
        xI990 = {1, {'REG', 'QTD_LIN_I'}, {}}

        % Bloco M
        xM001 = {1, {'REG', 'IND_MOV'}, {}}
        xM100 = {1, {'REG', 'COD_CRED', 'IND_CRED_ORI', 'VL_BC_PIS', 'ALIQ_PIS', 'QUANT_BC_PIS', 'ALIQ_PIS_QUANT', 'VL_CRED', 'VL_AJUS_ACRES', 'VL_AJUS_REDUC', 'VL_CRED_DIF', 'VL_CRED_DISP', 'IND_DESC_CRED', 'VL_CRED_DESC', 'SLD_CRED'}, {}}
        xM105 = {1, {'REG', 'NAT_BC_CRED', 'CST_PIS', 'VL_BC_PIS_TOT', 'VL_BC_PIS_CUM', 'VL_BC_PIS_NC', 'VL_BC_PIS', 'QUANT_BC_PIS_TOT', 'QUANT_BC_PIS', 'DESC_CRED'}, {}}
        xM200 = {1, {'REG', 'VL_TOT_CONT_NC_PER', 'VL_TOT_CRED_DESC', 'VL_TOT_CRED_DESC_ANT', 'VL_TOT_CONT_NC_DEV', 'VL_RET_NC', 'VL_OUT_DED_NC', 'VL_CONT_NC_REC', 'VL_TOT_CONT_CUM_PER', 'VL_RET_CUM', 'VL_OUT_DED_CUM', 'VL_CONT_CUM_REC', 'VL_TOT_CONT_REC'}, {}}
        xM205 = {1, {'REG', 'NUM_CAMPO', 'COD_REC', 'VL_DEBITO'}, {}}
        xM210 = {1, {'REG', 'COD_CONT', 'VL_REC_BRT', 'VL_BC_CONT', 'VL_AJUS_ACRES_BC_PIS', 'VL_AJUS_REDUC_BC_PIS', 'VL_BC_CONT_AJUS', 'ALIQ_PIS', 'QUANT_BC_PIS', 'ALIQ_PIS_QUANT', 'VL_CONT_APUR', 'VL_AJUS_ACRES', 'VL_AJUS_REDUC', 'VL_CONT_DIFER', 'VL_CONT_DIFER_ANT', 'VL_CONT_PER'}, {}}
        xM400 = {1, {'REG', 'CST_PIS', 'VL_TOT_REC', 'COD_CTA', 'DESC_COMPL'}, {}}
        xM410 = {1, {'REG', 'NAT_REC', 'VL_REC', 'COD_CTA', 'DESC_COMPL'}, {}}
        xM500 = {1, {'REG', 'COD_CRED', 'IND_CRED_ORI', 'VL_BC_COFINS', 'ALIQ_COFINS', 'QUANT_BC_COFINS', 'ALIQ_COFINS_QUANT', 'VL_CRED', 'VL_AJUS_ACRES', 'VL_AJUS_REDUC', 'VL_CRED_DIF', 'VL_CRED_DISP', 'IND_DESC_CRED', 'VL_CRED_DESC', 'SLD_CRED'}, {}}
        xM505 = {1, {'REG', 'NAT_BC_CRED', 'CST_COFINS', 'VL_BC_COFINS_TOT', 'VL_BC_COFINS_CUM', 'VL_BC_COFINS_NC', 'VL_BC_COFINS', 'QUANT_BC_COFINS_TOT', 'QUANT_BC_COFINS', 'DESC_CRED'}, {}}
        xM600 = {1, {'REG', 'VL_TOT_CONT_NC_PER', 'VL_TOT_CRED_DESC', 'VL_TOT_CRED_DESC_ANT', 'VL_TOT_CONT_NC_DEV', 'VL_RET_NC', 'VL_OUT_DED_NC', 'VL_CONT_NC_REC', 'VL_TOT_CONT_CUM_PER', 'VL_RET_CUM', 'VL_OUT_DED_CUM', 'VL_CONT_CUM_REC', 'VL_TOT_CONT_REC'}, {}}
        xM605 = {1, {'REG', 'NUM_CAMPO', 'COD_REC', 'VL_DEBITO'}, {}}
        xM610 = {1, {'REG', 'COD_CONT', 'VL_REC_BRT', 'VL_BC_CONT', 'VL_AJUS_ACRES_BC_COFINS', 'VL_AJUS_REDUC_BC_COFINS', 'VL_BC_CONT_AJUS', 'ALIQ_COFINS', 'QUANT_BC_COFINS', 'ALIQ_COFINS_QUANT', 'VL_CONT_APUR', 'VL_AJUS_ACRES', 'VL_AJUS_REDUC', 'VL_CONT_DIFER', 'VL_CONT_DIFER_ANT', 'VL_CONT_PER'}, {}}
        xM800 = {1, {'REG', 'CST_COFINS', 'VL_TOT_REC', 'COD_CTA', 'DESC_COMPL'}, {}}
        xM810 = {1, {'REG', 'NAT_REC', 'VL_REC', 'COD_CTA', 'DESC_COMPL'}, {}}
        xM990 = {1, {'REG', 'QTD_LIN_M'}, {}}

        % Bloco P
        xP001 = {1, {'REG', 'IND_MOV'}, {}}
        xP010 = {1, {'REG', 'CNPJ'}, {}}
        xP990 = {1, {'REG', 'QTD_LIN_P'}, {}}

        % Bloco 1
        x1001 = {1, {'REG', 'IND_MOV'}, {}}
        x1100 = {1, {'REG', 'PER_APU_CRED', 'ORIG_CRED', 'CNPJ_SUC', 'COD_CRED', 'VL_CRED_APU', 'VL_CRED_EXT_APU', 'VL_TOT_CRED_APU', 'VL_CRED_DESC_PA_ANT', 'VL_CRED_PER_PA_ANT', 'VL_CRED_DCOMP_PA_ANT', 'SLD_CRED_PA_ANT', 'VL_CRED_DESC_PA', 'VL_CRED_PER_PA', 'VL_CRED_DCOMP_PA', 'VL_CRED_TRANS', 'VL_CRED_OUT', 'SLD_CRED_FIM'}, {}}
        x1300 = {1, {'REG', 'IND_NAT_RET', 'PR_REC_RET', 'VL_RET_APU', 'VL_RET_DED', 'VL_RET_PER', 'VL_RET_DCOMP', 'SLD_RET'}, {}}
        x1500 = {1, {'REG', 'PER_APU_CRED', 'ORIG_CRED', 'CNPJ_SUC', 'COD_CRED', 'VL_CRED_APU', 'VL_CRED_EXT_APU', 'VL_TOT_CRED_APU', 'VL_CRED_DESC_PA_ANT', 'VL_CRED_PER_PA_ANT', 'VL_CRED_DCOMP_PA_ANT', 'SLD_CRED_PA_ANT', 'VL_CRED_DESC_PA', 'VL_CRED_PER_PA', 'VL_CRED_DCOMP_PA', 'VL_CRED_TRANS', 'VL_CRED_OUT', 'SLD_CRED_FIM'}, {}}
        x1700 = {1, {'REG', 'IND_NAT_RET', 'PR_REC_RET', 'VL_RET_APU', 'VL_RET_DED', 'VL_RET_PER', 'VL_RET_DCOMP', 'SLD_RET'}, {}}
        x1990 = {1, {'REG', 'QTD_LIN_1'}, {}}

        % Bloco 9
        x9001 = {1, {'REG', 'IND_MOV'}, {}}
        x9900 = {1, {'REG', 'REG_BLC', 'QTD_REG_BLC'}, {}}
        x9990 = {1, {'REG', 'QTD_LIN_9'}, {}}
        x9999 = {1, {'REG', 'QTD_LIN'}, {}}
    end
    methods (Static = true)
        %-------------------------------------------------------%
        function implementedTableIds = getImplementedTableIds(removePrefixFlag)
            arguments
                removePrefixFlag (1,1) logical = true
            end

            classMeta = meta.class.fromName('model.EFDCBase');
            tableIdPrefix = 'x';
            prefixedProps = classMeta.PropertyList(startsWith({classMeta.PropertyList.Name}, tableIdPrefix));
            
            implementedTableIds = {prefixedProps.Name};
            if removePrefixFlag
                implementedTableIds = extractAfter(implementedTableIds, tableIdPrefix);
            end
        end

        %-------------------------------------------------------%
        function compositeSheets = efdcCompositeSheets()
            % Registros EFDC que compõem cada tabela composta (mesclada)
            compositeSheets = struct( ...
                'xA100_A170', {{'A100', 'A170'}}, ... % NFSe: A100 (nota) + A170 (itens)
                'xC100_C170_C175', {{'C100', 'C170', 'C175'}}, ... % NF-e: C100 + C170 + C175
                'xC180_C181_C185', {{'C180', 'C181', 'C185'}}, ... % Consolidadas: C180 + C181 + C185
                'xD600_D601_D605', {{'D600', 'D601', 'D605'}} ... % Telecom: D600 + D601 + D605
            );
        end

        %-------------------------------------------------------%
        function fieldNames = getFieldNames()
            tableIds = model.EFDCBase.getImplementedTableIds(false);
            fieldNames = {};
            for ii = 1:numel(tableIds)
                definition = model.EFDCBase.(tableIds{ii});
                fieldNames = [fieldNames, definition{1, 2}, definition{1, 3}]; %#ok<AGROW>
            end
            fieldNames = unique(fieldNames, 'stable');
        end

        %-------------------------------------------------------%
        function spec = getFieldSpecification(field, specType)
            arguments
                field
                specType {mustBeMember(specType, {'DataType', 'Format', 'Description'})}
            end

            scalarInput = ~iscellstr(field);
            field = cellstr(field);

            baseSpec = model.EFDIBase.FieldSpecification;
            spec = cell(1, numel(field));
            for ii = 1:numel(field)
                [isFound, idx] = ismember(field{ii}, baseSpec.Field);

                if isFound
                    spec{ii} = baseSpec.(specType){idx};
                    continue
                end

                % Campos exclusivos da EFD Contribuições: tipo inferido pelo prefixo.
                if startsWith(field{ii}, {'VL_', 'ALIQ_', 'QUANT_'})
                    dataType = 'double';
                    format   = 'bank';
                elseif startsWith(field{ii}, 'DT_')
                    dataType = 'datetime';
                    format   = [];
                else
                    dataType = 'cell';
                    format   = [];
                end

                switch specType
                    case 'DataType';    spec{ii} = dataType;
                    case 'Format';      spec{ii} = format;
                    case 'Description'; spec{ii} = '';
                end
            end

            if scalarInput
                spec = spec{1};
            end
        end

    end
end
