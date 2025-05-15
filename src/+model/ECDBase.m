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
            2,   {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'NIRE_SUBST', 'IND_EMP_GRD_PRT'}, {}; ...
            3,   {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'NIRE_SUBST', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP'}, {}; ...
            4    {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'NIRE_SUBST', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF'}, {}; ...

            5:7, {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF', 'IND_ESC_CONS'}, {}; ...
            8:9, {'REG', 'LECD', 'DT_INI', 'DT_FIN', 'NOME', 'CNPJ', 'UF', 'IE', 'COD_MUN', 'IM', 'IND_SIT_ESP', 'IND_SIT_INI_PER', 'IND_NIRE', 'IND_FIN_ESC', 'COD_HASH_SUB', 'IND_GRANDE_PORTE', 'TIP_ECD', 'COD_SCP', 'IDENT_MF', 'IND_ESC_CONS', 'IND_CENTRALIZADA', 'IND_MUDANC_PC', 'COD_PLAN_REF'}, {}}
        
        x0001 =  {1:9,   {'REG',	'IND_DAD'}, {}}

        x0007 =  {1:9,   {'REG',	'COD_ENT_REF',	'COD_INSCR'}, {}}

        x0020 =  {1:8,   {'REG',	'IND_DEC',	'CNPJ',	'UF',	'IE',	'COD_MUN',	'IM',	'NIRE'} {}; ...            
            9,   {'REG', 'IND_DEC',	'UF',	'IE',	'COD_MUN',	'IM',	'NIRE'}, {}}

        x0035 =  {1:9,   {'REG',	'COD_SCP',	'NOME_SCP'}, {}}

        x0150 =  {1:9,   {'REG',	'COD_PART',	'NOME',	'COD_PAIS',	'CNPJ',	'CPF',	'NIT',	'UF',	'IE',	'IE_ST',	'COD_MUN',	'IM',	'SUFRAMA'}, {}}
     
        x0180 =  {1:9,   {'REG',	'COD_REL',	'DT_INI_REL',	'DT_FIN_REL'}, {}}
        
        x0990 =  {1:9,   {'REG',	'QTD_LIN_0'}, {}}

    
        % Bloco C: Informações recuperadas a escrituração contábil anterior

        xC001 =  {1:7,   {}, {}; ...
            8:9,   {'REG',	'IND_DAD'}, {}}

        xC040 =  {1:7,   {}, {}; ...
            8:9,   {'REG',	'HASH_ECD_REC',	'DT_INI_ECD_REC',	'DT_FIN_ECD_REC',	'CNPJ_ECD_REC',	'IND_ESC',	'COD_VER_LC',	'NUM_ORD',	'NAT_LIVR',	'IND_SIT_ESP_ECD_REC',	'IND_NIRE_ECD_REC',	'IND_FIN_ESC_ECD_REC',	'TIP_ECD_REC',	'COD_SCP_ECD_REC',	'IDENT_MF_ECD_REC',	'IND_ESC_CONS_ECD_REC',	'IND_CENTRALIZADA_ECD_REC',	'IND_MUDANCA_PC_ECD_REC',	'IND_PLANO_REF_ECD_REC'}, {}}
      
        xC050 =  {1:7,   {}, {}; ...
            8:9,   {'REG', 'DT_ALT', 'COD_NAT', 'IND_CTA', 'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}, {}}

        xC051 =  {1:7,   {}, {}; ...
            8:9,   {'REG', 'COD_CCUS', 'COD_CTA_REF'}, {}}

        xC052 =  {1:7,   {}, {}; ...
            8:9,   {'REG', 'COD_CCUS', 'COD_AGL'}, {}}

        xC150 =  {1:7,   {}, {}; ...
            8:9,   {'REG',	'DT_INI',	'DT_FIN'}, {}}

        xC155 =  {1:7,   {}, {}; ...
            8:9,   {'REG',	'COD_CTA_REC',	'COD_CCUS_REC',	'VL_SLD_INI_REC',	'IND_DC_INI_REC',	'VL_DEB_REC',	'VL_CRED_REC',	'VL_SLD_FIN_REC',	'IND_DC_FIN_REC'}, {}}
      
        xC600 =  {1:7,   {}, {}; ...
            8:9,   {'REG',	'DT_INI',	'DT_FIN',	'ID_DEM',	'CAB_DEM'}, {}}
      
        xC650 =  {1:7,   {}, {}; ...
            8:9,   {'REG',	'COD_AGL',	'NIVEL_AGL',	'DESCR_COD_AGL',	'VL_CTA_FIN',	'IND_DC_CTA_FIN'}, {}}
       
        xC990 =  {1:7,   {}, {}; ...
            8:9,   {'REG',	'QTD_LIN_0'}, {}}

      
        % Bloco I: Informações recuperadas a escrituração contábil anterior
        
        xI001 = {1:9, {'REG', 'IND_DAD'}, {}}

        xI010 = {1:9, {'REG', 'IND_ESC', 'COD_VER_LC'}, {}}
        
        xI012 = {1:9, {'REG', 'NUM_ORD', 'NAT_LIVR', 'TIPO', 'COD_HASH_AUX'}, {}}

        xI015 = {1:9, {'REG', 'COD_CTA_RES'}, {}}

        xI020 = {1:9, {'REG', 'REG_COD', 'NUM_AD', 'CAMPO', 'DESCRICAO', 'TIPO'}, {}}

        xI030 = {1,   {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN'}, {}; ...
            2,   {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN', 'DT_EX_SOCIAL', 'NOME_AUDITOR', 'COD_CVM_AUDITOR'}, {}; ...
            3:9, {'REG', 'DNRC_ABERT', 'NUM_ORD', 'NAT_LIVR', 'QTD_LIN', 'NOME', 'NIRE', 'CNPJ', 'DT_ARQ', 'DT_ARQ_CONV', 'DESC_MUN', 'DT_EX_SOCIAL'}, {}}

        xI050 = {1:9, {'REG', 'DT_ALT', 'COD_NAT', 'IND_CTA', 'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}, {}}

        xI051 = {1:9,   {'REG', 'COD_CCUS', 'COD_CTA_REF'}, {}}

        xI052 = {1:9,   {'REG', 'COD_CCUS', 'COD_AGL'}, {}}

        xI053 = {1:9, {'REG', 'COD_IDT', 'COD_CNT_CORR', 'NAT_SUB_CNT'}, {}}

        xI075 = {1:9, {'REG', 'COD_HIST', 'DESCR_HIST'}, {}}

        xI100 = {1:9, {'REG', 'DT_ALT', 'COD_CCUS', 'CCUS'}, {}}

        xI150 = {1:9, {'REG', 'DT_INI', 'DT_FIN'}, {}}

        xI155 = {1:4, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI', 'VL_DEB', 'VL_CRED', 'VL_SLD_FIN', 'IND_DC_FIN'}, {'VL_SLD_INI_AUX', 'IND_DC_INI_AUX', 'VL_DEB_AUX', 'VL_CRED_AUX', 'VL_SLD_FIN_AUX', 'IND_DC_FIN_AUX'}; ...
            5:8, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI', 'VL_DEB', 'VL_CRED', 'VL_SLD_FIN', 'IND_DC_FIN'}, {'VL_SLD_INI_MF', 'IND_DC_INI_MF', 'VL_DEB_MF', 'VL_CRED_MF', 'VL_SLD_FIN_MF', 'IND_DC_FIN_MF'}; ...
            9,   {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI', 'VL_DEB', 'VL_CRED', 'VL_SLD_FIN', 'IND_DC_FIN'}, {'VL_SLD_INI_MF', 'IND_DC_INI_MF', 'VL_DEB_MF', 'VL_CRED_MF', 'VL_SLD_FIN_MF', 'IND_DC_FIN_MF'}}
       
        xI157 = {1,   {}, {}; ...
            2:4, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI'}, {'VL_SLD_INI_AUX',	'IND_DC_INI_AUX'}; ...
            5:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_SLD_INI', 'IND_DC_INI'}, {'VL_SLD_INI_MF', 'IND_DC_INI_MF'}}

        xI200 = {1:4, {'REG', 'NUM_LCTO', 'DT_LCTO', 'VL_LCTO', 'IND_LCTO'}, {'VL_LCTO_AUX'}; ...
            5:6, {'REG', 'NUM_LCTO', 'DT_LCTO', 'VL_LCTO', 'IND_LCTO'}, {'VL_LCTO_MF'}; ...
            7:9, {'REG', 'NUM_LCTO', 'DT_LCTO', 'VL_LCTO', 'IND_LCTO', 'DT_LCTO_EXT'}, {'VL_LCTO_MF'}}

        xI250 = {1:4, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_DC', 'IND_DC', 'NUM_ARQ', 'COD_HIST_PAD', 'HIST', 'COD_PART'}, {'VL_DC_AUX', 'IND_DC_AUX'}; ...
            5:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_DC', 'IND_DC', 'NUM_ARQ', 'COD_HIST_PAD', 'HIST', 'COD_PART'}, {'VL_DC_MF', 'IND_DC_MF'}}

        xI300 = {1:9,   {'REG', 'DT_BCTE'}, {}}

        xI310 = {1:4,   {'REG', 'COD_CTA', 'COD_CCUS', 'VAL_DEBD', 'VAL_CREDD'}, {'VAL_DEB_AUX', 'VAL_CRED_AUX'}; ...
            5:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VAL_DEBD', 'VAL_CREDD'}, {'VAL_DEB_MF', 'VAL_CRED_MF'}}

        xI350 = {1:9, {'REG', 'DT_RES'}, {}}

        xI355 = {1:4, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_CTA', 'IND_DC'}, {'VL_CTA_AUX', 'IND_DC_AUX'}; ...
            5:9, {'REG', 'COD_CTA', 'COD_CCUS', 'VL_CTA', 'IND_DC'}, {'VL_CTA_MF', 'IND_DC_MF'}}

        xI500 = {1:9, {'REG', 'TAM_FONTE'}, {}}

        xI510 = {1:9, {'REG', 'NM_CAMPO', 'DESC_CAMPO',	'TIPO_CAMPO', 'TAM_CAMPO', 'DEC_CAMPO',	'COL_CAMPO'}, {}}

        xI550 = {1:9, {'REG', 'RZ_CONT'}, {}}

        xI555 = {1:9, {'REG', 'RZ_CONT_TOT'}, {}}

        xI990 = {1:9, {'REG', 'QTD_LIN_I'}, {}}

     
        % Bloco J: Demonstrações contábeis
        
        xJ001 = {1:9, {'REG',	'IND_DAD'}, {}}

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
     
        xJ210 = {1:5, {'REG', 'IND_TIP', 'COD_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_CTA', 'VL_CTA_INI', 'IND_DC_CTA_INI'}, {}; ...
            6,  {'REG', 'IND_TIP', 'COD_AGL', 'DESCR_COD_AGL', 'VL_CTA', 'IND_DC_CTA', 'VL_CTA_INI', 'IND_DC_CTA_INI',	'NOTAS_EXP_REF'}, {}; ...
            7:9,{'REG', 'IND_TIP', 'COD_AGL', 'DESCR_COD_AGL', 'VL_CTA_INI', 'IND_DC_CTA_INI', 'VL_CTA_FIN', 'IND_DC_CTA_FIN', 'NOTAS_EXP_REF'}, {}}
      
        xJ215 = {1:6, {'REG', 'COD_HIST_FAT', 'VL_FAT_CONT', 'IND_DC_FAT'}, {}; ...
            7:9, {'REG', 'COD_HIST_FAT', 'VL_FAT_CONT',	'IND_DC_FAT'}, {}}
     
        xJ800 = {1:4, {'REG', 'ARQ_RTF', 'IND_FIM_RTF'}, {}; ...
            5:9, {'REG', 'TIPO_DOC', 'DESC_RTF', 'HASH_RTF', 'ARQ_RTF', 'IND_FIM_RTF'}, {}}
    
        xJ801 = {1:4, {}, {}; ...
            5, {'REG',	'TIPO_DOC',	'DESC_RTF',	'HASH_RTF',	'ARQ_RTF',	'IND_FIM_RTF'}, {};...
            6:9, {'REG', 'TIPO_DOC', 'DESC_RTF', 'COD_MOT_SUBS', 'HASH_RTF', 'ARQ_RTF',	'IND_FIM_RTF'}, {}}
      
        xJ900 = {1:9, {'REG', 'DNRC_ENCER', 'NUM_ORD', 'NAT_LIVRO', 'NOME',	'QTD_LIN', 'DT_INI_ESCR', 'DT_FIN_ESCR'}, {}}
     
        xJ930 = {1,   {'REG', 'IDENT_NOM', 'IDENT_CPF', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC'}, {}; ...
            2:4, {'REG', 'IDENT_NOM', 'IDENT_CPF', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC', 'EMAIL', 'FONE', 'UF_CRC', 'NUM_SEQ_CRC', 'DT_CRC'}, {}; ...
            5:9, {'REG', 'IDENT_NOM', 'IDENT_CPF_CNPJ', 'IDENT_QUALIF', 'COD_ASSIN', 'IND_CRC', 'EMAIL', 'FONE', 'UF_CRC', 'NUM_SEQ_CRC', 'DT_CRC', 'IND_RESP_LEGAL'}, {}}
  
        xJ932 = {1:6, {}, {}; ...
            7:9, {'REG', 'IDENT_NOM_T',	'IDENT_CPF_CNPJ_T',	'IDENT_QUALIF_T', 'COD_ASSIN_T', 'IND_CRC_T', 'EMAIL_T', 'FONE_T', 'UF_CRC_T', 'NUM_SEQ_CRC_T', 'DT_CRC_T'}, {}}
    
        xJ935 = {1:6, {'REG', 'NOME_AUDITOR', 'COD_CVM_AUDITOR'}, {}; ...
            7:9, {'REG', 'NI_CPF_CNPJ', 'NOME_AUDITOR_FIRMA', 'COD_CVM_AUDITOR'}, {}}
 
        xJ990 = {1:9, {'REG', 'QTD_LIN_J'}, {}}

        
        % Bloco K: Conglomerados econômicos

        xK001 = {1:4,   {}, {}; ...
            5:9, {'REG', 'IND_DAD'}, {}}
        
        xK030 = {1:4,   {}, {}; ...
            5:9, {'REG', 'DT_INI', 'DT_FIN'}, {}}
        xK100 = {1:4,   {}, {}; ...
            5:9, {'REG', 'COD_PAIS', 'EMP_COD',	'CNPJ',	'NOME',	'PER_PART',	'EVENTO',	'PER_CONS',	'DATA_INI_EMP',	'DATA_FIN_EMP'}, {}}
        xK110 = {1:4,   {}, {}; ...
            5:9, {'REG', 'EVENTO', 'DT_EVENTO'}, {}}
        xK115 = {1:4,   {}, {}; ...
            5:9, {'REG', 'EMP_COD_PART', 'COND_PART', 'PER_EVT'}, {}}
        xK200 = {1:4,   {}, {}; ...
            5:9, {'REG', 'COD_NAT', 'IND_CTA', 'NIVEL', 'COD_CTA', 'COD_CTA_SUP', 'CTA'}, {}}
        xK210 = {1:4,   {}, {}; ...
            5:9, {'REG', 'COD_EMP',	'COD_CTA_EMP'}, {}}
        xK300 = {1:4,   {}, {}; ...
            5:9, {'REG', 'COD_CTA',	'VAL_AG', 'IND_VAL_AG', 'VAL_EL', 'IND_VAL_EL',	'VAL_CS', 'IND_VAL_CS'}, {}}
        xK310 = {1:4,   {}, {}; ...
            5:9, {'REG', 'EMP_COD_PARTE', 'VALOR', 'IND_VALOR'}, {}}
        xK315 = {1:4,   {}, {}; ...
            5:9, {'REG', 'EMP_COD_CONTRA', 'COD_CONTRA', 'VALOR', 'IND_VALOR'}, {}}
        xK990 = {1:4,   {}, {}; ...
            5:9, {'REG', 'QTD_LIN_K'}, {}}


        % Bloco 9: Controle e encerramento do arquivo digital
        
        x9001 = {1:9,   {'REG',	'IND_DAD'}, {}}

        x9900 = {1:9,   {'REG',	'REG_BLC', 'QTD_REG_BLC'}, {}}

        x9990 = {1:9,   {'REG', 'QTD_LIN_9'}, {}}

        x9999 = {1:9,   {'REG',	'QTD_LIN'}, {}}
    end

    properties (Access = protected, Constant = true)
        %-------------------------------------------------------%
        % CAMPOS RELACIONADOS ÀS TABELAS SOB ANÁLISE
        %-------------------------------------------------------%
       ARQ_RTF = struct('DataType', 'cell', 'Description', 'Sequência de bytes que representem um único arquivo no formato RTF (Rich Text Format).')
       CAB_DEM = struct('DataType', 'cell', 'Description', 'Cabeçalho das demonstrações.')
       CAMPO = struct('DataType', 'cell', 'Description', 'Nome do campo adicional.')
       CCUS = struct('DataType', 'cell', 'Description', 'Nome do centro de custos.')
       CNPJ = struct('DataType', 'cell', 'Description', 'Número de inscrição da pessoa jurídica no CNPJ.Observação: Esse CNPJ é sempre da Sócia Ostensiva, no caso do arquivo da SCP.')
       CNPJ_ECD_REC = struct('DataType', 'cell', 'Description', 'CNPJ da ECD recuperada.')
       COD_AGL = struct('DataType', 'cell', 'Description', 'Código de aglutinação das linhas, atribuído pela pessoa jurídica.')
       COD_AGL_SUP = struct('DataType', 'cell', 'Description', 'Código de aglutinação sintético/grupo de código de aglutinação de nível superior.')
       COD_ASSIN = struct('DataType', 'cell', 'Description', 'Código de qualificação do assinante, conforme tabela.')
       COD_ASSIN_T = struct('DataType', 'cell', 'Description', 'Código de qualificação do assinante do termo de verificação, conforme tabela.')
       COD_CCUS = struct('DataType', 'cell', 'Description', 'Código do centro de custos do plano de contas anterior.')
       COD_CCUS_REC = struct('DataType', 'cell', 'Description', 'Código do centro de custos.')
       COD_CNT_CORR = struct('DataType', 'cell', 'Description', 'Código da subconta correlata (deve estar no plano de contas e só pode estar relacionada a um único grupo)')
       COD_CONTRA = struct('DataType', 'cell', 'Description', 'Código da conta consolidada da contrapartida')
       COD_CTA = struct('DataType', 'cell', 'Description', 'Código da conta analítica.')
       COD_CTA_EMP = struct('DataType', 'cell', 'Description', 'Código da conta da empresa participante')
       COD_CTA_REC = struct('DataType', 'cell', 'Description', 'Código da conta analítica.')
       COD_CTA_REF = struct('DataType', 'cell', 'Description', 'Código da conta de acordo com o plano de contas referencial, conforme tabela publicada pelos órgãos indicados no campo COD_PLAN_REF do registro 0000.')
       COD_CTA_RES = struct('DataType', 'cell', 'Description', 'Código da(s) conta(s) analítica(s) do Livro Diário com Escrituração Resumida (R) que recebe os lançamentos globais.')
       COD_CTA_SUP = struct('DataType', 'cell', 'Description', 'Código da conta sintética /grupo de contas de nível imediatamente superior.')
       COD_CVM_AUDITOR = struct('DataType', 'cell', 'Description', 'auditor independente na CVM.')
       COD_EMP = struct('DataType', 'cell', 'Description', 'Código de identificação da empresa participante')
       COD_ENT_REF = struct('DataType', 'cell', 'Description', 'Código da instituição responsável pela manutenção do plano de contas referencial.')
       COD_HASH_AUX = struct('DataType', 'cell', 'Description', 'Verifica se o campo código Hash do arquivo correspondente ao livro auxiliar')
       COD_HASH_SUB = struct('DataType', 'cell', 'Description', 'Hash da escrituração substituída.')
       COD_HIST = struct('DataType', 'cell', 'Description', 'Código do histórico padronizado.')
       COD_HIST_FAT = struct('DataType', 'cell', 'Description', 'Código do histórico do fato contábil.')
       COD_HIST_PAD = struct('DataType', 'cell', 'Description', 'Código do histórico padronizado, conforme tabela I075.')
       COD_IDT = struct('DataType', 'cell', 'Description', 'Código de identificação do grupo de conta-subconta(a)')
       COD_INSCR = struct('DataType', 'cell', 'Description', 'Código cadastral da pessoa jurídica na instituição identificada no campo 02.')
       COD_MOT_SUBS = struct('DataType', 'cell', 'Description', 'Código do motivo da substituição: 001 – Mudanças de saldos das contas que não podem ser realizadas por meio de lançamentos extemporâneos 002 – Alteração de assinatura 003 – Alteração de demonstrações contábeis 004 – Alteração da forma de escrituração contábil 005 – Alteração do número do livro 099 – Outros')
       COD_MUN = struct('DataType', 'cell', 'Description', 'Código do município do domicílio fiscal da pessoa jurídica, conforme tabela do IBGE – Instituto Brasileiro de Geografia e Estatística.')
       COD_NAT = struct('DataType', 'cell', 'Description', 'Código da natureza da conta/grupo de contas, conforme tabela publicada pelo Sped.')
       COD_PAIS = struct('DataType', 'cell', 'Description', 'Código do país do participante, conforme a tabela do Banco Central do Brasil.')
       COD_PART = struct('DataType', 'cell', 'Description', 'Código de identificação do participante na partida conforme tabela 0150 (preencher somente quando identificado o tipo de participação no registro 0180')
       COD_PLAN_REF = struct('DataType', 'cell', 'Description', 'Código do Plano de Contas Referencial que será utilizado para o mapeamento de todas as contas analíticas: 1 – PJ em Geral – Lucro Real 2 – PJ em Geral – Lucro Presumido 3 – Financeiras – Lucro Real 4 – Seguradoras – Lucro Real 5 – Imunes e Isentas em Geral 6 – Imunes e Isentas – Financeiras 7 – Imunes e Isentas – Seguradoras 8 – Entidades Fechadas de Previdência Complementar 9 – Partidos Políticos 10 – Financeiras – Lucro Presumido Observação: Caso a pessoa jurídica não realize o mapeamento para os planos referenciais na ECD, este campo deve ficar em branco.')
       COD_REL = struct('DataType', 'cell', 'Description', 'Código do relacionamento conforme tabela publicada pelo Sped.')
       COD_SCP = struct('DataType', 'cell', 'Description', 'CNPJ da SCP (Anexo I, XVIII, da IN RFB nº 2.119, de 06 de dezembro de 2022 Observação: Só deve ser preenchido pela própria SCP com o CNPJ da SCP (Não é preenchido pelo sócio ostensivo"')
       COD_SCP_ECD_REC = struct('DataType', 'cell', 'Description', 'CNPJ da SCP.')
       COD_VER_LC = struct('DataType', 'double', 'Description', 'Código da versão do leiaute')
       COL_CAMPO = struct('DataType', 'cell', 'Description', 'Largura da coluna no relatório (em quantidade de caracteres).')
       COND_PART = struct('DataType', 'cell', 'Description', 'Condição da empresa relacionada à operação: 1 – Sucessora; 2 – Adquirente; 3 – Alienante.')
       CPF = struct('DataType', 'cell', 'Description', 'CPF.')
       CTA = struct('DataType', 'cell', 'Description', 'Nome da conta analítica/grupo de contas.')
       DATA_FIN_EMP = struct('DataType', 'cell', 'Description', 'Data final do período da escrituração contábil da empresa que foi consolidada')
       DATA_INI_EMP = struct('DataType', 'cell', 'Description', 'Data inicial do período da escrituração contábil da empresa que foi consolidada.')
       DEC_CAMPO = struct('DataType', 'cell', 'Description', 'Quantidade de casas decimais para campos tipo “N”.')
       DESC_CAMPO = struct('DataType', 'cell', 'Description', 'Descrição do campo (utilizada na visualização do Livro Auxiliar)')
       DESC_MUN = struct('DataType', 'cell', 'Description', ' Município.')
       DESC_RTF = struct('DataType', 'cell', 'Description', 'Descrição do arquivo .rtf.')
       DESCR_COD_AGL = struct('DataType', 'cell', 'Description', 'Descrição do Código de aglutinação.')
       DESCR_HIST = struct('DataType', 'cell', 'Description', 'Descrição do histórico padronizado.')
       DESCRICAO = struct('DataType', 'cell', 'Description', 'Descrição do campo adicional.')
       DNRC_ABERT = struct('DataType', 'cell', 'Description', 'Texto fixo contendo “TERMO DE ABERTURA”.')
       DNRC_ENCER = struct('DataType', 'cell', 'Description', 'Texto fixo contendo “TERMO DE ENCERRAMENTO”.')
       DT_ALT = struct('DataType', 'datetime', 'Description', 'Data da inclusão/alteração.')
       DT_ARQ = struct('DataType', 'datetime', 'Description', 'Data do arquivamento dos atos constitutivos.')
       DT_ARQ_CONV = struct('DataType', 'datetime', 'Description', 'Data de arquivamento do ato de conversão de sociedade simples em sociedade empresária.')
       DT_BCTE = struct('DataType', 'datetime', 'Description', 'Data do balancete.')
       DT_CRC = struct('DataType', 'datetime', 'Description', 'Data de validade da Certidão de Regularidade Profissional do Contador')
       DT_CRC_T = struct('DataType', 'cell', 'Description', 'Data de validade da Certidão de Regularidade Profissional do Contador')
       DT_EVENTO = struct('DataType', 'cell', 'Description', 'Data do evento societário.')
       DT_EX_SOCIAL = struct('DataType', 'datetime', 'Description', ' Data de encerramento do exercício social.')
       DT_FIN = struct('DataType', 'datetime', 'Description', 'Data final das demonstrações contábeis.')
       DT_FIN_ECD_REC = struct('DataType', 'cell', 'Description', 'Data final das informações contidas na ECD recuperada.')
       DT_FIN_ESCR = struct('DataType', 'cell', 'Description', 'Data de término da escrituração.')
       DT_FIN_REL = struct('DataType', 'cell', 'Description', 'Data do término do relacionamento.')
       DT_INI = struct('DataType', 'datetime', 'Description', 'Data inicial das demonstrações contábeis. Observação: A data inicial das demonstrações deve ser a data posterior ao último encerramento do exercício, mesmo que essa data não esteja no período da ECD transmitida. Exemplo: Data do Último Encerramento do Exercício: 31/12/2022 Data Inicial das Demonstrações Contábeis: 01/01/2023')
       DT_INI_ECD_REC = struct('DataType', 'cell', 'Description', 'Data inicial das informações contidas na ECD recuperada.')
       DT_INI_ESCR = struct('DataType', 'cell', 'Description', 'Data de início da escrituração.')
       DT_INI_REL = struct('DataType', 'cell', 'Description', 'Data do início do relacionamento.')
       DT_LCTO = struct('DataType', 'datetime', 'Description', 'Data do lançamento.')
       DT_LCTO_EXT = struct('DataType', 'datetime', 'Description', 'Data de ocorrência dos fatos objeto do lançamento extemporâneo. Observação: Caso não seja possível precisar a data a que se refiram os fatos do lançamento extemporâneo, informar a data de encerramento do exercício em que ocorreram esses fatos.')
       DT_RES = struct('DataType', 'datetime', 'Description', 'Data da apuração do resultado.')
       EMAIL = struct('DataType', 'cell', 'Description', 'Email do signatário.')
       EMAIL_T = struct('DataType', 'cell', 'Description', 'Email do signatário.')
       EMP_COD = struct('DataType', 'cell', 'Description', 'Código de identificação da empresa participante.')
       EMP_COD_CONTRA = struct('DataType', 'cell', 'Description', 'Código da empresa da contrapartida')
       EMP_COD_PART = struct('DataType', 'cell', 'Description', 'Código da empresa envolvida na operação')
       EMP_COD_PARTE = struct('DataType', 'cell', 'Description', 'Código da empresa detentora do valor aglutinado que foi eliminado')
       EVENTO = struct('DataType', 'cell', 'Description', 'Evento societário ocorrido no período: S - Sim N – Não')
       FONE = struct('DataType', 'cell', 'Description', 'Telefone do signatário.')
       FONE_T = struct('DataType', 'cell', 'Description', 'Telefone do signatário.')
       HASH_ECD_REC = struct('DataType', 'cell', 'Description', 'Hashcode da ECD recuperada.')
       HASH_RTF = struct('DataType', 'cell', 'Description', 'Hash do arquivo .rtf incluído. Observação: O HASH é preenchido automaticamente pelo sistema (não é editável e não pode ser alterado).')
       HIST = struct('DataType', 'cell', 'Description', 'Histórico completo da partida ou histórico complementar. Observação: Caso o lançamento seja do tipo “X” – lançamento extemporâneo - em qualquer das formas de retificação, o histórico do lançamento extemporâneo deve especificar o motivo da correção, a data e o número do lançamento de origem (item 32 do ITG 2000 (R1)')
       ID_DEM = struct('DataType', 'cell', 'Description', 'Identificação das demonstrações: 1 – demonstrações contábeis da pessoa jurídica a que se refere a escrituração (inclusive Matrix/Filiais); 2 – demonstrações consolidadas ou de outras pessoas jurídicas.')
       IDENT_CPF = struct('DataType', 'cell', 'Description', 'CPF')
       IDENT_CPF_CNPJ = struct('DataType', 'cell', 'Description', 'CPF ou CNPJ')
       IDENT_CPF_CNPJ_T = struct('DataType', 'cell', 'Description', 'CPF ou CNPJ do assinante do termo de verificação.')
       IDENT_MF = struct('DataType', 'cell', 'Description', 'Identificação de moeda funcional: Indica que a escrituração abrange valores com base na moeda funcional (art. 287 da Instrução Normativa RFB nº 1.700, de 14 de março de 2017 Observação: Deverá ser utilizado o registro I020 para informação de campos adicionais, conforme instruções do item 1.24.')
       IDENT_MF_ECD_REC = struct('DataType', 'cell', 'Description', 'Identificação de moeda funcional: S – Sim N – Não')
       IDENT_NOM = struct('DataType', 'cell', 'Description', 'Nome do signatário.')
       IDENT_NOM_T = struct('DataType', 'cell', 'Description', 'Nome do signatário do termo de verificação.')
       IDENT_QUALIF = struct('DataType', 'cell', 'Description', 'Qualificação do assinante, conforme tabela.')
       IDENT_QUALIF_T = struct('DataType', 'cell', 'Description', 'Qualificação do assinante do termo de verificação, conforme tabela.')
       IE = struct('DataType', 'cell', 'Description', 'Inscrição Estadual da pessoa jurídica.')
       IE_ST = struct('DataType', 'cell', 'Description', 'Inscrição Estadual do participante na unidade da federação do destinatário, na condição de contribuinte substituto.')
       IM = struct('DataType', 'cell', 'Description', 'Inscrição Municipal da pessoa jurídica.')
       IND_CENTRALIZADA = struct('DataType', 'cell', 'Description', 'Indicador da modalidade de escrituração centralizada ou descentralizada: 0 – Escrituração Centralizada 1 – Escrituração Descentralizada')
       IND_CENTRALIZADA_ECD_REC = struct('DataType', 'cell', 'Description', 'Identificação de escrituração contábil centralizada ou descentralizada: 0 – Escrituração centralizada. 1 – Escrituração descentralizada.')
       IND_COD_AGL = struct('DataType', 'cell', 'Description', 'Indicador do tipo de código de aglutinação das linhas: Observação: Caso o indicador de código de aglutinação seja totalizador (T), o código de aglutinação deve ser informado, mas não deve estar cadastrado no registro I052 – os códigos de aglutinação informados no registro I052 são somente para contas analíticas. T – Totalizador (nível que totaliza um ou mais níveis inferiores da demonstração financeira) D – Detalhe (nível mais detalhado da demonstração financeira')
       IND_CRC = struct('DataType', 'cell', 'Description', 'Número de inscrição do contabilista no Conselho Regional de Contabilidade.')
       IND_CRC_T = struct('DataType', 'cell', 'Description', 'Número de inscrição do contabilista no Conselho ')
       IND_CTA = struct('DataType', 'cell', 'Description', 'Indicador do tipo de conta: S - Sintética (grupo de contas A - Analítica (conta)')
       IND_DAD = struct('DataType', 'cell', 'Description', 'Indicador de movimento: 0- Bloco com dados informados; 1- Bloco sem dados informados.')
       IND_DC = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo final: D - Devedor; C - Credor.')
       IND_DC_AUX = struct('DataType', 'cell', 'Description', 'Indicador da natureza da partida em moeda funcional: D - Débito; C - Crédito.')
       IND_DC_BAL = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo informado no campo anterior: D - Devedor; C – Credor')
       IND_DC_BAL_INI = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo inicial informado no campo anterior: D - Devedor; C – Credor')
       IND_DC_CTA = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo final informado no campo anterior: D – Devedor C - Credor')
       IND_DC_CTA_FIN = struct('DataType', 'cell', 'Description', 'Indicador da situação do valor final da linha antes do encerramento do exercício: D – Devedor; C – Credor.')
       IND_DC_CTA_INI = struct('DataType', 'cell', 'Description', 'Indicador da situação do valor final da linha no período imediatamente anterior: D – Devedor; C – Credor.')
       IND_DC_FAT = struct('DataType', 'cell', 'Description', 'Indicador de situação do saldo informado no campo anterior: D – Devedor C – Credor P – Subtotal ou total positivo N – Subtotal ou total negativo')
       IND_DC_FIN = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo final: D - Devedor; C - Credor.')
       IND_DC_FIN_AUX = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo final em moeda funcional: D - Devedor; C - Credor.')
       IND_DC_FIN_MF = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo final em moeda funcional: D - Devedor; C - Credor.')
       IND_DC_FIN_REC = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo final do período.')
       IND_DC_INI = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo inicial: D - Devedor; C - Credor.')
       IND_DC_INI_AUX = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo inicial em moeda funcional: D - Devedor; C - Credor.')
       IND_DC_INI_MF = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo inicial em moeda funcional: D - Devedor; C - Credor.')
       IND_DC_INI_REC = struct('DataType', 'cell', 'Description', 'Indicador da situação do saldo inicial: D – Devedor. C – Credor.')
       IND_DC_MF = struct('DataType', 'cell', 'Description', 'Indicador da natureza da partida em moeda funcional: D - Devedor; C - Credor.')
       IND_DEC = struct('DataType', 'cell', 'Description', 'Indicador de descentralização: 0 – escrituração da matriz; 1 – escrituração da filial.')
       IND_EMP_GRD_PRT = struct('DataType', 'cell', 'Description', 'Indicador de empresa de grande porte: 0 – Empresa não é de grande porte 1 – Empresa de grande porte')
       IND_ESC = struct('DataType', 'cell', 'Description', 'Indicador da forma de escrituração contábil: G – Livro Diário Geral. R – Livro Diário com Escrituração Resumida. B – Livro de Balancetes Diários.')
       IND_ESC_CONS = struct('DataType', 'cell', 'Description', 'Escriturações Contábeis Consolidadas: (Deve ser preenchido pela empresa controladora obrigada a informar demonstrações contábeis consolidadas, nos termos da Lei nº 6.404/76 e/ou do Pronunciamento Técnico CPC 36 – Demonstrações Consolidadas S – Sim N – Não')
       IND_ESC_CONS_ECD_REC = struct('DataType', 'cell', 'Description', 'Identificação de escriturações contábeis consolidadas: S – Sim N – Não ')
       IND_FIM_RTF = struct('DataType', 'cell', 'Description', 'Indicador de fim do arquivo RTF. Texto fixo contendo “J800FIM”.')
       IND_FIN_ESC = struct('DataType', 'cell', 'Description', 'Indicador de finalidade da escrituração: 0 - Original 1 – Substituta')
       IND_FIN_ESC_ECD_REC = struct('DataType', 'cell', 'Description', 'Indicador da finalidade da escrituração: 0 – Original. 1 – Substituta.')
       IND_GRANDE_PORTE = struct('DataType', 'cell', 'Description', 'Indicador de entidade sujeita a auditoria independente: 0 – Empresa não é entidade sujeita a auditoria independente. 1 – Empresa é entidade sujeita a auditoria independente – Ativo Total superior a R$ 240.000.000,00 ou Receita Bruta Anual superior R$300.000.000,00.')
       IND_GRP_BAL = struct('DataType', 'cell', 'Description', 'Indicador de grupo do balanço: A – Ativo;P – Passivo e Patrimônio Líquido.')
       IND_GRP_DRE = struct('DataType', 'cell', 'Description', 'Indicador de grupo da DRE: D – Linha totalizadora ou de detalhe da demonstração que, por sua natureza de despesa, represente redução do lucro. R – Linha totalizadora ou de detalhe da demonstração que, por sua natureza de receita, represente incremento do lucro.')
       IND_LCTO = struct('DataType', 'cell', 'Description', 'Indicador do tipo de lançamento: N - Lançamento normal (todos os lançamentos, exceto os de encerramento das contas de resultado; E - Lançamento de encerramento de contas de resultado. X – Lançamento extemporâneo.')
       IND_MUDANC_PC = struct('DataType', 'cell', 'Description', 'Indicador de mudança de plano de contas: 0 – Não houve mudança no plano de contas. 1 – Houve mudança no plano de contas.')
       IND_MUDANCA_PC_ECD_REC = struct('DataType', 'cell', 'Description', 'Indicativo de mudança de plano de contas: 0 – Não houve alteração de plano de contas. 1 – Houve alteração de plano de contas.')
       IND_NIRE = struct('DataType', 'cell', 'Description', 'Indicador de existência de NIRE:0 – Empresa não possui registro na Junta Comercial (não possui NIRE "1 – Empresa possui registro na Junta Comercial (possui NIRE"')
       IND_NIRE_ECD_REC = struct('DataType', 'cell', 'Description', 'Indicador de existência de Nire: 0 – Pessoa jurídica não possui registro na Junta Comercial. 1 – Pessoa jurídica possui registro na Junta Comercial.')
       IND_PLANO_REF_ECD_REC = struct('DataType', 'cell', 'Description', 'Código do Plano de Contas Referencial que será utilizado para o mapeamento de todas as contas analíticas: 1 – PJ em Geral – Lucro Real. 2 – PJ em Geral – Lucro Presumido. 3 – Financeiras – Lucro Real. 4 – Seguradoras – Lucro Real. 5 – Imunes e Isentas em Geral. 6 – Imunes e Isentas – Financeiras. 7 – Imunes e Isentas – Seguradoras. 8 – Entidades Fechadas de Previdência Complementar. 9 – Partidos Políticos. 10 – Financeiras – Lucro Presumido.')
       IND_RESP_LEGAL = struct('DataType', 'cell', 'Description', 'Identificação do signatário que será validado como responsável pela assinatura da ECD, conforme atos societários: S – Sim N – Não')
       IND_SIT_ESP = struct('DataType', 'cell', 'Description', 'Indicador de situação especial (conforme tabela publicada pelo Sped"')
       IND_SIT_ESP_ECD_REC = struct('DataType', 'cell', 'Description', 'Indicador de situação especial da ECD recuperada: 1 – Cisão. 2 – Fusão. 3 - Incorporação. 4 – Extinção.')
       IND_SIT_INI_PER = struct('DataType', 'cell', 'Description', 'Indicador de situação no início do período (conforme tabela publicada pelo Sped"')
       IND_TIP = struct('DataType', 'cell', 'Description', 'Indicador do tipo de demonstração: 0 – DLPA – Demonstração de Lucro ou Prejuízos Acumulados 1 – DMPL – Demonstração de Mutações do Patrimônio Líquido')
       IND_VAL_AG = struct('DataType', 'cell', 'Description', 'Indicador da situação do valor aglutinado: D – Devedor C – Credor')
       IND_VAL_CS = struct('DataType', 'cell', 'Description', 'Indicador da situação do valor consolidado: D – Devedor C – Credor')
       IND_VAL_EL = struct('DataType', 'cell', 'Description', 'Indicador da situação do valor eliminado: D – Devedor C – Credor')
       IND_VALOR = struct('DataType', 'cell', 'Description', 'Indicador da situação do valor eliminado: D – Devedor C – Credor')
       IND_VL = struct('DataType', 'cell', 'Description', 'Indicador da situação do valor informado no campo anterior: D - Despesa ou valor que represente parcela redutora do lucro; R - Receita ou valor que represente incremento do lucro; P - Subtotal ou total positivo; N – Subtotal ou total negativo')
       IND_VL_ULT_DRE = struct('DataType', 'cell', 'Description', 'Indicador da situação do valor informado no campo anterior: D - Despesa ou valor que represente parcela redutora do lucro; R - Receita ou valor que represente incremento do lucro; P - Subtotal ou total positivo; N – Subtotal ou total negativo')
       LECD = struct('DataType', 'cell', 'Description', 'Texto fixo contendo “LECD”.')
       NAT_LIVR = struct('DataType', 'cell', 'Description', 'Natureza do livro; finalidade a que se destina o instrumento.')
       NAT_LIVRO = struct('DataType', 'cell', 'Description', 'Natureza do livro; finalidade a que se destinou o instrumento.')
       NAT_SUB_CNT = struct('DataType', 'cell', 'Description', 'Natureza da subconta correlata (conforme tabela de natureza da subconta publicada no Sped )')
       NI_CPF_CNPJ = struct('DataType', 'cell', 'Description', 'CPF do auditor independente/CNPJ da pessoa jurídica de auditoria independente.')
       NIRE = struct('DataType', 'cell', 'Description', 'Número de Identificação do Registro de Empresas da Junta Comercial.')
       NIRE_SUBST = struct('DataType', 'cell', 'Description', 'NIRE da escrituração substituída')
       NIT = struct('DataType', 'cell', 'Description', 'Indicador da situação do valor eliminado: D – Devedor C – Credor')
       NIVEL = struct('DataType', 'cell', 'Description', 'Nível da conta analítica/grupo de contas.')
       NIVEL_AGL = struct('DataType', 'cell', 'Description', 'Nível do Código de aglutinação (mesmo conceito do plano de contas – Registro I050')
       NM_CAMPO = struct('DataType', 'cell', 'Description', 'Nome do campo, sem espaços em branco ou caractere especial.')
       NOME = struct('DataType', 'cell', 'Description', 'Nome empresarial da pessoa jurídica.')
       NOME_AUDITOR = struct('DataType', 'cell', 'Description', 'Nome do auditor independente')
       NOME_AUDITOR_FIRMA = struct('DataType', 'cell', 'Description', 'Nome do auditor independente ou pessoa jurídica de auditoria independente.')
       NOME_SCP = struct('DataType', 'cell', 'Description', 'Nome da SCP')
       NOTA_EXP_REF = struct('DataType', 'cell', 'Description', 'Referência a numeração das notas explicativas relativas às demonstrações contábeis.')
       NOTAS_EXP_REF = struct('DataType', 'cell', 'Description', 'Referência à numeração das notas explicativas relativas às demonstrações contábeis.')
       NU_ORDEM = struct('DataType', 'double', 'Description', 'Número de ordem da linha na visualização da demonstração. Ordem de apresentação da linha na visualização do registro J150.')
       NUM_AD = struct('DataType', 'double', 'Description', 'Número sequencial do campo adicional.')
       NUM_ARQ = struct('DataType', 'cell', 'Description', 'Número, Código ou caminho de localização dos documentos arquivados.')
       NUM_LCTO = struct('DataType', 'cell', 'Description', 'Número ou Código de identificação único do lançamento contábil.')
       NUM_ORD = struct('DataType', 'double', 'Description', 'Número de ordem do instrumento de escrituração.')
       NUM_SEQ_CRC = struct('DataType', 'cell', 'Description', 'Número da Certidão de Regularidade Profissional do Contador no seguinte formato: UF/ano/número')
       NUM_SEQ_CRC_T = struct('DataType', 'cell', 'Description', 'Número da Certidão de Regularidade Profissional do Contador no seguinte formato: UF/ano/número')
       PER_CONS = struct('DataType', 'cell', 'Description', 'Percentual de consolidação da empresa no final do período consolidado: Informar o percentual do resultado da empresa que foi para a consolidação.')
       PER_EVT = struct('DataType', 'cell', 'Description', 'Percentual da empresa participante envolvida na operação')
       PER_PART = struct('DataType', 'cell', 'Description', 'Percentual de participação total do conglomerado na empresa no final do período consolidado. Observação: Neste campo, deve ser informado o percentual de participação acionária da empresa titular da ECD. ')
       QTD_LIN = struct('DataType', 'double', 'Description', 'Quantidade total de linhas do arquivo digital.')
       QTD_LIN_0 = struct('DataType', 'cell', 'Description', 'Quantidade total de linhas do Bloco 0.')
       QTD_LIN_9 = struct('DataType', 'cell', 'Description', 'Quantidade total de linhas do Bloco 9.')
       QTD_LIN_I = struct('DataType', 'cell', 'Description', 'Quantidade total de linhas do Bloco I.')
       QTD_LIN_J = struct('DataType', 'cell', 'Description', 'Quantidade total de linhas do Bloco J.')
       QTD_LIN_K = struct('DataType', 'cell', 'Description', 'Quantidade total de linhas do Bloco K.')
       QTD_REG_BLC = struct('DataType', 'cell', 'Description', 'Total de registros do tipo informado no campo anterior.')
       REG = struct('DataType', 'cell', 'Description', 'Texto fixo contendo a indicação do Registro da tabela, Ex: 000, I030, I050, etc.')
       REG_BLC = struct('DataType', 'cell', 'Description', 'Registro que será totalizado no próximo campo.')
       REG_COD = struct('DataType', 'cell', 'Description', 'Código do registro que recepciona o campo adicional.')
       RZ_CONT = struct('DataType', 'cell', 'Description', 'Conteúdo dos campos mencionados no Registro I510.')
       RZ_CONT_TOT = struct('DataType', 'cell', 'Description', 'Conteúdo dos campos mencionados no Registro I510.')
       SUFRAMA = struct('DataType', 'cell', 'Description', 'Número de inscrição do participante na Suframa.')
       TAM_CAMPO = struct('DataType', 'cell', 'Description', 'Tamanho do campo.')
       TAM_FONTE = struct('DataType', 'cell', 'Description', 'Tamanho da fonte.')
       TIP_ECD = struct('DataType', 'double', 'Description', 'Indicador do tipo de ECD: 0 – ECD de empresa não participante de SCP como sócio ostensivo. 1 – ECD de empresa participante de SCP como sócio ostensivo. 2 – ECD da SCP.')
       TIP_ECD_REC = struct('DataType', 'cell', 'Description', 'Indicador do tipo da ECD: 0 – ECD de empresa não participante de SCP como sócio ostensivo. 1 – ECD de empresa participante de SCP como sócio ostensivo. 2 – ECD da SCP.')
       TIPO = struct('DataType', 'cell', 'Description', 'Indicação do tipo de dado (N: numérico; C: caractere). N: numérico - campos adicionais que conterão informações de valores em espécie (moeda), com duas decimais.')
       TIPO_CAMPO = struct('DataType', 'cell', 'Description', 'Tipo do campo: “N” – Numérico; “C” – Caractere.')
       TIPO_DOC = struct('DataType', 'cell', 'Description', 'Tipo de documento: 001: Demonstração do Resultado Abrangente do Período 002: Demonstração dos Fluxos de Caixa 003: Demonstração do Valor Adicionado 010: Notas Explicativas 011: Relatório da Administração 012: Parecer dos Auditores 099: Outros')
       UF = struct('DataType', 'cell', 'Description', 'Sigla da unidade da federação da pessoa jurídica.')
       UF_CRC = struct('DataType', 'cell', 'Description', 'Indicação da unidade da federação que expediu o CRC.')
       UF_CRC_T = struct('DataType', 'cell', 'Description', 'Indicação da unidade da federação que expediu o CRC.')
       VAL_AG = struct('DataType', 'cell', 'Description', 'Valor absoluto aglutinado')
       VAL_CRED_AUX = struct('DataType', 'cell', 'Description', 'Total dos créditos do dia em moeda funcional, convertida para reais.')
       VAL_CRED_MF = struct('DataType', 'double', 'Description', 'Total dos créditos do dia em moeda funcional, convertido para reais.')
       VAL_CREDD = struct('DataType', 'double', 'Description', 'Total dos créditos do dia.')
       VAL_CS = struct('DataType', 'cell', 'Description', 'Valor absoluto consolidado: VAL_CS = VAL_AG – VAL_EL')
       VAL_DEB_AUX = struct('DataType', 'cell', 'Description', 'Total dos débitos do dia em moeda funcional, convertida para reais.')
       VAL_DEB_MF = struct('DataType', 'double', 'Description', 'Total dos débitos do dia em moeda funcional, convertido para reais.')
       VAL_DEBD = struct('DataType', 'double', 'Description', 'Total dos débitos do dia.')
       VAL_EL = struct('DataType', 'cell', 'Description', 'Valor absoluto das eliminações')
       VALOR = struct('DataType', 'cell', 'Description', 'Parcela do valor eliminado total')
       VL_CRED = struct('DataType', 'double', 'Description', 'Valor total dos créditos do período.')
       VL_CRED_AUX = struct('DataType', 'cell', 'Description', 'Valor total dos créditos do período em moeda funcional.')
       VL_CRED_MF = struct('DataType', 'double', 'Description', 'Valor total dos créditos do período em moeda funcional, convertido para reais.')
       VL_CRED_REC = struct('DataType', 'cell', 'Description', 'Valor total dos créditos no período.')
       VL_CTA = struct('DataType', 'double', 'Description', 'Valor do saldo final antes do lançamento de encerramento.')
       VL_CTA_AUX = struct('DataType', 'cell', 'Description', 'Valor do saldo final antes do lançamento de encerramento em moeda funcional, convertida para reais.')
       VL_CTA_FIN = struct('DataType', 'double', 'Description', 'Valor final do código de aglutinação no Balanço Patrimonial no exercício informado, ou de período definido em norma específica.')
       VL_CTA_INI = struct('DataType', 'double', 'Description', 'Valor inicial do código de aglutinação no Balanço Patrimonial no exercício informado, ou de período definido em norma específica.')
       VL_CTA_INI_ = struct('DataType', 'double', 'Description', 'Valor do saldo final da linha no período imediatamente anterior (saldo final da DRE anterior')
       VL_CTA_MF = struct('DataType', 'double', 'Description', 'Valor do saldo final antes do lançamento de encerramento em moeda funcional, convertido para reais')
       VL_CTA_ULT_DRE = struct('DataType', 'double', 'Description', 'Valor do saldo final antes do encerramento constante na Demonstração do Resultado do Exercício do último período informado')
       VL_DC = struct('DataType', 'double', 'Description', 'Valor da partida.')
       VL_DC_AUX = struct('DataType', 'cell', 'Description', 'Valor da partida em moeda funcional, convertida para reais.')
       VL_DC_MF = struct('DataType', 'double', 'Description', 'Valor da partida em moeda funcional, convertido para reais.')
       VL_DEB = struct('DataType', 'double', 'Description', 'Valor total dos débitos do período.')
       VL_DEB_AUX = struct('DataType', 'cell', 'Description', 'Valor total dos débitos do período em moeda funcional, convertida para reais.')
       VL_DEB_MF = struct('DataType', 'double', 'Description', 'Total dos débitos do dia em moeda funcional, convertido para reais.')
       VL_DEB_REC = struct('DataType', 'cell', 'Description', 'Valor total dos débitos no período.')
       VL_FAT_CONT = struct('DataType', 'cell', 'Description', 'Valor do fato contábil.')
       VL_LCTO = struct('DataType', 'double', 'Description', 'Valor do lançamento.')
       VL_LCTO_AUX = struct('DataType', 'cell', 'Description', 'Valor do lançamento em moeda funcional, convertida para reais.')
       VL_LCTO_MF = struct('DataType', 'double', 'Description', 'Valor do lançamento em moeda funcional, convertido para reais.')
       VL_SLD_FIN = struct('DataType', 'double', 'Description', 'Valor do saldo final do período.')
       VL_SLD_FIN_AUX = struct('DataType', 'cell', 'Description', 'Valor do saldo final do período em moeda funcional, convertida para reais')
       VL_SLD_FIN_MF = struct('DataType', 'double', 'Description', 'Valor do saldo final do período em moeda funcional, convertido para reais.')
       VL_SLD_FIN_REC = struct('DataType', 'cell', 'Description', 'Valor do saldo final do período.')
       VL_SLD_INI = struct('DataType', 'double', 'Description', 'Valor do saldo inicial do período.')
       VL_SLD_INI_AUX = struct('DataType', 'cell', 'Description', 'Valor do saldo inicial do período em moeda funcional, convertida para reais.')
       VL_SLD_INI_MF = struct('DataType', 'double', 'Description', 'Valor do saldo inicial do período em moeda funcional, convertido para reais.')
       VL_SLD_INI_REC = struct('DataType', 'cell', 'Description', 'Valor do saldo inicial do período.')
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

        function tableOut = parseSplitLine(obj, tableId, fileContent, fileLayout, ecdObjTable)
            arguments
                obj
                tableId {mustBeMember(tableId,{'0000', '0007', '0020', '0035', '0150', '0180', '0990', 'C001', 'C040', 'C050', 'C051', 'C052', 'C150', 'C155', ...
                    'C600', 'C650', 'C990', 'I001', 'I010', 'I001', 'I012', 'I015', 'I020', 'I030', 'I050', 'I051', 'I052', 'I053', ...
                    'I075', 'I100', 'I150', 'I155', 'I157', 'I200', 'I250', 'I300', 'I310', 'I350', 'I355', 'I500', 'I510', 'I550', ...
                    'I555', 'I990', 'J001', 'J005', 'J100', 'J150', 'J210', 'J215', 'J801', 'J900', 'J930', 'J932', 'J935', 'J990', ...
                    'K001', 'K030', 'K100', 'K110', 'K115', 'K200', 'K210', 'K300', 'K310', 'K315', 'K990', '9001', '9900', '9990', ...
                    '9999'})}
                fileContent
                fileLayout = 1
                ecdObjTable = 1
            end

            for mm = 1: numel(tableId)
                tableOut_I150_155_350_355{mm} = TableTypesAll(mm, tableId);
            end

            function tableOut_I150_155_350_355 = TableTypesAll(idtype, Tabletype)

                if idtype == 1

                    tableOut_I150_155_350_355 = TableTypes_1_3(idtype, Tabletype);

                elseif idtype == 2

                    tableOut_I150_155_350_355 = ecdObjTable.xI155;

                elseif idtype == 3

                    tableOut_I150_155_350_355 = TableTypes_1_3(idtype, Tabletype);

                elseif idtype == 4

                    tableOut_I150_155_350_355 = ecdObjTable.xI355;

                end
            end

            function tableOut_idtypes = TableTypes_1_3 (idtype, Tabletype)

                % Filtras as linhas com as informações de Tabletype{1} e Tabletype{2}
                regexPattern = ['^\|(' Tabletype{idtype} '|' Tabletype{idtype+1} ')\|[^\r\n]*'];
                regexMatches = regexp(fileContent, regexPattern, 'match', 'lineanchors')';
                regexMatches_idtypes = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);

                % Identifica as primeiras linhas com a informações de Tabletype
                linesIniIdxI_1_3 = find(contains(regexMatches_idtypes, Tabletype{idtype}));

                tableOut_All = [];

                if idtype == 1
                    Table_idtype_first = ecdObjTable.xI150;
                    Table_idtype_second = ecdObjTable.xI155;
                elseif idtype == 3
                    Table_idtype_first = ecdObjTable.xI350;
                    Table_idtype_second = ecdObjTable.xI355;
                end

                for ii = 1:height(Table_idtype_first)

                    if ii < height(Table_idtype_first)
                        numReps = linesIniIdxI_1_3(ii+1) - linesIniIdxI_1_3(ii) - 1;
                    else
                        numReps = height(Table_idtype_second) - linesIniIdxI_1_3(ii) + ii;
                    end

                    % Repete cada valor da linha 'ii', 'numReps' vezes
                    tableOutRowData = repmat(Table_idtype_first(ii, :), numReps, 1);

                    % Acumula resultado
                    tableOut_All = [tableOut_All; tableOutRowData];
                end
                tableOut_idtypes = tableOut_All;
            end

            tableOut_I150_155_350_355{1}.REG = strcat(tableOut_I150_155_350_355{1}.REG, '-', tableOut_I150_155_350_355{2}.REG);

            tableOut_I150_155_350_355{2} = removevars(tableOut_I150_155_350_355{2}, 'REG');

            % Concatenar tabelas I150 e I155
            T_I150_I155 = [tableOut_I150_155_350_355{1}, tableOut_I150_155_350_355{2}];

            tableOut_I150_155_350_355{3}.REG = strcat(tableOut_I150_155_350_355{3}.REG, '-', tableOut_I150_155_350_355{4}.REG);

            tableOut_I150_155_350_355{4} = removevars(tableOut_I150_155_350_355{4}, 'REG');

            % Concatenar colunas das tabelas I350 e I355
            T_I350_I355 = [tableOut_I150_155_350_355{3}, tableOut_I150_155_350_355{4}];

            % Concatenar as tabelas T_I150_I155 e T_I350_I355
            I150_I155_I350_I355 = [];
            pp = 1;

            datas_I150 = ecdObjTable.xI150.DT_INI;
            datas_I350 = ecdObjTable.xI350.DT_RES;

            line_Fim_155 = 0;
            line_Fim_355 = 0;

            for kk = 1:numel(datas_I150)

                if month(datas_I350(pp)) == month(datas_I150(kk))

                    line_Ini_155 = line_Fim_155 + 1;
                    line_Fim_155 = line_Fim_155 + numel(find(month(T_I150_I155.DT_INI) == month(datas_I150(kk))));

                    line_Ini_355 = line_Fim_355 + 1;
                    line_Fim_355 = line_Fim_355 + numel(find(month(T_I350_I355.DT_RES) == month(datas_I350(pp))));

                    I155_parcial = T_I150_I155(line_Ini_155:line_Fim_155,:);
                    I355_parcial = T_I350_I355(line_Ini_355:line_Fim_355,:);

                    I155_parcial.ordem_original = (1:height(I155_parcial))';

                    resultado = outerjoin(I155_parcial, I355_parcial, ...
                        'Keys', 'COD_CTA', ...
                        'MergeKeys', true, ...
                        'Type', 'full');

                    resultado = sortrows(resultado, 'ordem_original');
                    resultado.ordem_original = [];

                    resultado(ismissing(resultado.REG_I155_parcial), :) = [];

                    resultado.Properties.VariableNames{1} = 'REG';
                    resultado.Properties.VariableNames{5} = 'COD_CCUS';

                    resultado.REG = strcat(resultado.REG, '-', "I350-I355");
                    resultado = removevars(resultado, 'REG_I355_parcial');
                    resultado = removevars(resultado, 'COD_CCUS_I355_parcial');

                    I150_I155_I350_I355 = [I150_I155_I350_I355; resultado];

                    pp = pp+1;

                else
                
                    line_Ini_155 = line_Fim_155 + 1;
                    line_Fim_155 = line_Fim_155 + numel(find(month(T_I150_I155.DT_INI) == month(datas_I150(kk))));

                    resultado = T_I150_I155(line_Ini_155:line_Fim_155, :);

                    array_vazios = repmat({""}, (line_Fim_155 - line_Ini_155 +  1), numel(T_I350_I355.Properties.VariableNames));
                    array_vazios(:,2) = {NaT};

                    table_array_vazios_155 = cell2table(array_vazios, 'VariableNames', T_I350_I355.Properties.VariableNames);

                    resultado.REG = strcat(resultado.REG, '-', "I350-I355");

                    table_array_vazios_155 = removevars(table_array_vazios_155, 'REG');
                    table_array_vazios_155 = removevars(table_array_vazios_155, 'COD_CTA');
                    table_array_vazios_155 = removevars(table_array_vazios_155, 'COD_CCUS');

                    I150_I155_nullos = [resultado, table_array_vazios_155];

                    I150_I155_I350_I355 = [I150_I155_I350_I355; I150_I155_nullos];
                
                end
            end

            numrows = height(I150_I155_I350_I355);
            TNuls = array2table(NaN(numrows, 2), 'VariableNames', {'Mov_155', 'Mov_155_355'});

            I150_I155_I350_I355 = [I150_I155_I350_I355, TNuls];

            % Calcula os valores de Mov_I155 e de Mov_I155_I355
            idx_IND_DC_INI_D = find(I150_I155_I350_I355.IND_DC_INI == "D");
            I150_I155_I350_I355.VL_SLD_INI(idx_IND_DC_INI_D) = -abs(I150_I155_I350_I355.VL_SLD_INI(idx_IND_DC_INI_D));

            idx_IND_DC_FIN_D = find(I150_I155_I350_I355.IND_DC_FIN == "D");
            I150_I155_I350_I355.VL_SLD_FIN(idx_IND_DC_FIN_D) = -abs(I150_I155_I350_I355.VL_SLD_FIN(idx_IND_DC_FIN_D));

            idx_VL_CTA_D = find(I150_I155_I350_I355.IND_DC == "D");
            I150_I155_I350_I355.VL_CTA = str2double(replace(I150_I155_I350_I355.VL_CTA, ",", "."));
            I150_I155_I350_I355.VL_CTA(idx_VL_CTA_D) = -abs(I150_I155_I350_I355.VL_CTA(idx_VL_CTA_D));
            I150_I155_I350_I355.VL_CTA(isnan(I150_I155_I350_I355.VL_CTA)) = 0;

            I150_I155_I350_I355.Mov_I155 = I150_I155_I350_I355.VL_SLD_FIN - I150_I155_I350_I355.VL_SLD_INI;
            I150_I155_I350_I355.Mov_I155_I355 = I150_I155_I350_I355.Mov_I155 + I150_I155_I350_I355.VL_CTA;

            tableOut = I150_I155_I350_I355;

        end

        %----------------------------------------------------------------------------------------------------------------%

        function tableOut_others = parseSplitLineOthers(obj, tableId, fileContent, fileLayout, ecdObjTable)
            arguments
                obj
                tableId {mustBeMember(tableId,{'0000', '0007', '0020', '0035', '0150', '0180', '0990', 'C001', 'C040', 'C050', 'C051', 'C052', 'C150', 'C155', ...
                    'C600', 'C650', 'C990', 'I001', 'I010', 'I001', 'I012', 'I015', 'I020', 'I030', 'I050', 'I051', 'I052', 'I053', ...
                    'I075', 'I100', 'I150', 'I155', 'I157', 'I200', 'I250', 'I300', 'I310', 'I350', 'I355', 'I500', 'I510', 'I550', ...
                    'I555', 'I990', 'J001', 'J005', 'J100', 'J150', 'J210', 'J215', 'J801', 'J900', 'J930', 'J932', 'J935', 'J990', ...
                    'K001', 'K030', 'K100', 'K110', 'K115', 'K200', 'K210', 'K300', 'K310', 'K315', 'K990', '9001', '9900', '9990', ...
                    '9999'})}
                fileContent
                fileLayout = 1
                ecdObjTable = 1
            end

            switch tableId{1}

                case "I050"
                    for mm = 1: numel(tableId)
                        tableOutAll{mm} = linesTableId(mm, tableId, ecdObjTable.xI050, ecdObjTable.xI051, ecdObjTable.xI052);
                    end

                case "C050"
                    for mm = 1: numel(tableId)
                        if ~isempty(ecdObjTable.xC050)
                            tableOutAll{mm} = linesTableId(mm, tableId, ecdObjTable.xC050, ecdObjTable.xC051, ecdObjTable.xC052);
                        else
                            msgbox("Não há dados referemtes a Tabela C50, C51 e C52!");
                            tableOut_others = [];
                            return;
                        end
                    end

                case "I250"
                    for mm = 1: numel(tableId)
                        tableOutAll{mm} = linesTableId(mm, tableId, ecdObjTable.xI250, ecdObjTable.xI200, []);
                    end

                case "J100"
                    for mm = 1: numel(tableId)
                        tableOutAll{mm} = linesTableId(mm, tableId, ecdObjTable.xJ100, ecdObjTable.xJ005, []);
                    end
            end

            function tableOutAll = linesTableId(idtype, Tabletype, x1, x2, x3)

                if numel(Tabletype)  == 3
                    % regexPattern = ['^\|(' Tabletype{1} '|' Tabletype{2}  '|' Tabletype{3} ')\|[^\r\n]*'];
                    % regexMatches = regexp(fileContent, regexPattern, 'match', 'lineanchors')';
                    % regexMatches_xAll = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);
                    nTabletype = 3;
                elseif numel(Tabletype)  == 2
                    % regexPattern = ['^\|(' Tabletype{1} '|' Tabletype{2} ')\|[^\r\n]*'];
                    % regexMatches = regexp(fileContent, regexPattern, 'match', 'lineanchors')';
                    % regexMatches_xAll = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);
                    tableOutAll = [];
                    nTabletype = 2;
                end

                if idtype == 1

                    tableOutAll = x1;

                elseif idtype == 2

                    regexPattern = ['^\|(' Tabletype{1} '|' Tabletype{2} ')\|[^\r\n]*'];
                    regexMatches = regexp(fileContent, regexPattern, 'match', 'lineanchors')';
                    regexMatches_Tabletype1_Tabletype2 = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);

                    % Identifica as linhas com a informações de tableId
                    linesIniIdx_Tabletype2 = find(contains(regexMatches_Tabletype1_Tabletype2, Tabletype{2}));

                    % Criar vetor lógico indicando onde I355 aparece
                    isMatch = contains(regexMatches_Tabletype1_Tabletype2, tableId{1});
                    % Identifica o númeor de linhas que contém as sequências consecutivas de REG em "I355"
                    diffValues = diff([0; isMatch; 0]); % Adiciona zeros no início e fim para capturar grupos
                    startIndices = find(diffValues == 1); % Início de um grupo
                    endIndices = find(diffValues == -1) - 1; % Fim de um grupo
                    linesTabletype1 = endIndices - startIndices + 1;


                    for ii = 1:height(linesIniIdx_Tabletype2)

                        if nTabletype == 3
                            % Cria uma matriz de strings vazias
                            stringMatrix = strings(height(x1), numel(x2.Properties.VariableNames));

                            % Converte para tabela
                            tableOutAll = array2table(stringMatrix, 'VariableNames', x2.Properties.VariableNames);

                            tableOutAll.REG(1:end) = Tabletype{2};

                            if ii == 1
                                numReps = linesTabletype1(1);
                            else
                                numReps = numReps + linesTabletype1(ii);
                            end

                            newRow = x2(ii,:);

                            tableOutAll(numReps,:) = newRow;

                        elseif nTabletype == 2

                            numReps = linesTabletype1(ii);

                            % newRow = x2(ii,:);
                            newRow = repmat(x2(ii, :), numReps, 1);

                            tableOutAll = [tableOutAll; newRow];
                        end
                    end

                elseif idtype == 3

                    regexPattern = ['^\|(' Tabletype{1} '|' Tabletype{3} ')\|[^\r\n]*'];
                    regexMatches = regexp(fileContent, regexPattern, 'match', 'lineanchors')';
                    regexMatches_Tabletype1_Tabletype3 = cellfun(@(x) x(2:end-1), regexMatches, 'UniformOutput', false);

                    % Criar vetor lógico indicando onde I355 aparece
                    isMatch = contains(regexMatches_Tabletype1_Tabletype3, tableId{1});
                    % Identifica o númeor de linhas que contém as sequências consecutivas de REG em "I355"
                    diffValues = diff([0; isMatch; 0]); % Adiciona zeros no início e fim para capturar grupos
                    startIndices = find(diffValues == 1); % Início de um grupo
                    endIndices = find(diffValues == -1) - 1; % Fim de um grupo
                    linesTabletype1 = endIndices - startIndices + 1;

                    % Identifica as linhas com a informações de tableId
                    linesIniIdx_Tabletype3 = find(contains(regexMatches_Tabletype1_Tabletype3, Tabletype{3}));

                    % Cria uma matriz de strings vazias
                    stringMatrix = strings(height(x1), numel(x3.Properties.VariableNames));

                    % Converte para tabela
                    tableOutAll = array2table(stringMatrix, 'VariableNames', x3.Properties.VariableNames);
                    tableOutAll.REG(1:end) = Tabletype{3};

                    for ii = 1:height(linesIniIdx_Tabletype3)

                        if nTabletype == 3

                            % Cria uma matriz de strings vazias
                            stringMatrix = strings(height(x1), numel(x2.Properties.VariableNames));

                            % Converte para tabela
                            tableOutAll = array2table(stringMatrix, 'VariableNames', x2.Properties.VariableNames);

                            tableOutAll.REG(1:end) = Tabletype{2};

                            if ii == 1
                                numReps = linesTabletype1(1);
                            else
                                numReps = numReps + linesTabletype1(ii);
                            end

                            newRow = x3(ii,:);
                            tableOutAll(numReps,:) = newRow;

                        end
                    end
                end
            end
            
            if numel(tableId)  == 3
                tableOutAll{1}.REG = strcat(tableOutAll{1}.REG, '-', tableOutAll{2}.REG, '-', tableOutAll{3}.REG);
                tableOutAll{2} = removevars(tableOutAll{2}, 'REG');
                tableOutAll{3} = removevars(tableOutAll{3}, 'REG');
                tableOutAll{3} = removevars(tableOutAll{3}, 'COD_CCUS');

                tableOut_others = [tableOutAll{1}, tableOutAll{2}, tableOutAll{3}];
            elseif numel(tableId)  == 2
                tableOutAll{2}.REG = strcat(tableOutAll{2}.REG, '-', tableOutAll{1}.REG);
                tableOutAll{1} = removevars(tableOutAll{1}, 'REG');
                tableOut_others = [tableOutAll{2}, tableOutAll{1}];
            end
        end

        %----------------------------------------------------------------------------------------------------------------%

        function tableDinamica = tableDinamica_I150_I155_I350_I355(obj, leftTable)
            arguments
                obj
                leftTable;
            end

            Cod_CTA_I155_Din = unique(leftTable.COD_CTA, 'stable');
            tableDinamica_I150_I155_I350_I355 = table('Size', [height(Cod_CTA_I155_Din), 14], ...
                'VariableTypes', {'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                'VariableNames',  {'COD_CTA'	'MES01',	'MES02',	'MES03',	'MES04',	'MES05',	'MES06',	'MES07',	'MES08',	'MES09',	'MES10',	'MES11',	'MES12',	'MesTotal_Geral'});



            for ii = 1: 1:height(Cod_CTA_I155_Din)
                index_COD_CTA_Din = find(strcmp(leftTable.COD_CTA, Cod_CTA_I155_Din{ii}));
                kk = 1;
                Val_Mes = [];
                Valor_Total_Mes = 0;
                for jj = 1:12
                    month_list = month(leftTable.DT_INI(index_COD_CTA_Din));
                    if kk <= numel(month_list)
                        if month_list(kk) == jj
                            Val_Mes(jj) = leftTable.Mov_I155_I355(index_COD_CTA_Din(kk));
                            kk = kk + 1;
                        else
                            Val_Mes(jj) = "0";
                        end
                    else
                        Val_Mes(jj) = "0";
                    end
                end
                Valor_Total_Mes = sum(Val_Mes);

                tableDinamica_I150_I155_I350_I355(ii,:) = {Cod_CTA_I155_Din{ii}, Val_Mes(1), Val_Mes(2), Val_Mes(3), Val_Mes(4), ...
                    Val_Mes(5), Val_Mes(6), Val_Mes(7), Val_Mes(8), Val_Mes(9), Val_Mes(10), Val_Mes(11), Val_Mes(12), Valor_Total_Mes};
            end

            tableDinamica = tableDinamica_I150_I155_I350_I355;

        end

        %----------------------------------------------------------------------------------------------------------------%

        function Tab_LucrAcum_I150_I155_I350_I355 = lucrAcum_I150_I155_I350_I355(obj, TableX, leftTable, tableDinamica)
            arguments
                obj;
                TableX;
                leftTable;
                tableDinamica;
            end

            idx_LC = find(strcmp(TableX.xI050.CTA, "LUCROS ACUMULADOS"));
            Value_idx_200 = TableX.xI050.COD_CTA(idx_LC);
            idx_LC_200 = find(strcmp(TableX.xI250.COD_CTA, string(Value_idx_200)));
            filter_LC = TableX.xI250(idx_LC_200,:);
            idx_Filter_LC = find(strcmp(filter_LC.COD_HIST_PAD, "350"));
            filter_LC (idx_Filter_LC,:);
            idx_Filter_LC = find(strcmp(filter_LC.COD_HIST_PAD, "350"));

            for yy = 1:numel(filter_LC.VL_DC)
                if strcmp(filter_LC.IND_DC(yy), "D")
                    filter_LC.VL_DC(yy) = -abs(filter_LC.VL_DC(yy));
                end
            end

            Value_Real = sum(filter_LC.VL_DC (idx_Filter_LC,:));

            idx_tab_dinam = find(strcmp(tableDinamica.COD_CTA, Value_idx_200));

            tableDinamica.MES02(idx_tab_dinam) = "0";
            tableDinamica.MES03(idx_tab_dinam) = "0";
            tableDinamica.MES04(idx_tab_dinam) = "0";
            tableDinamica.MES05(idx_tab_dinam) = "0";
            tableDinamica.MES06(idx_tab_dinam) = "0";
            tableDinamica.MES07(idx_tab_dinam) = "0";
            tableDinamica.MES08(idx_tab_dinam) = "0";
            tableDinamica.MES09(idx_tab_dinam) = "0";
            tableDinamica.MES10(idx_tab_dinam) = "0";
            tableDinamica.MES11(idx_tab_dinam) = "0";

            tableDinamica.MES12(idx_tab_dinam) = Value_Real - str2double(tableDinamica.MES01(idx_tab_dinam));
            tableDinamica.MesTotal_Geral(idx_tab_dinam) = Value_Real;
            sum_Total = sum(str2double(tableDinamica.MesTotal_Geral));

            tableDinamica = sortrows(tableDinamica, 'COD_CTA');

            Tab_LucrAcum_I150_I155_I350_I355 = tableDinamica;
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