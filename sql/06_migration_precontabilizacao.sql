-- ============================================================
-- 06_migration_precontabilizacao.sql
-- Migração NÃO DESTRUTIVA – pré-contabilização / conciliação
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

-- ── 1. Tabela fornecedores ────────────────────────────────
CREATE TABLE IF NOT EXISTS fornecedores (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo_senda  VARCHAR(30)  UNIQUE,
  -- Coluna mantida como `cnpj` por compatibilidade com o MVP.
  -- Armazena CPF (11 dígitos) ou CNPJ (14 dígitos), sempre sem pontuação.
  -- VARCHAR(18) preserva espaço para eventuais valores legados com máscara.
  -- O frontend salva apenas dígitos a partir desta versão.
  cnpj          VARCHAR(18)  UNIQUE,
  razao_social  VARCHAR(200) NOT NULL,
  nome_fantasia VARCHAR(200),
  ativo         BOOLEAN      NOT NULL DEFAULT true,
  observacao    TEXT,
  criado_em     TIMESTAMPTZ  NOT NULL DEFAULT now(),
  atualizado_em TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION trigger_set_fornecedores_atualizado_em()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.atualizado_em = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_fornecedores_upd ON fornecedores;
CREATE TRIGGER trg_fornecedores_upd
  BEFORE UPDATE ON fornecedores
  FOR EACH ROW EXECUTE FUNCTION trigger_set_fornecedores_atualizado_em();

-- ── 2. Novos campos em cartoes_credito ───────────────────
ALTER TABLE cartoes_credito
  ADD COLUMN IF NOT EXISTS banco_emissor            VARCHAR(100),
  ADD COLUMN IF NOT EXISTS dia_fechamento_fatura    SMALLINT
    CHECK (dia_fechamento_fatura BETWEEN 1 AND 31),
  ADD COLUMN IF NOT EXISTS dia_vencimento_fatura    SMALLINT
    CHECK (dia_vencimento_fatura BETWEEN 1 AND 31),
  ADD COLUMN IF NOT EXISTS conta_transitoria_codigo VARCHAR(30);

-- ── 3. Novos campos em despesas ───────────────────────────

-- 3a. Ampliar CHECK de status para incluir CANCELADA
-- SAFE: localiza o constraint real pela definição (não pelo nome),
-- pois o nome gerado pode variar entre ambientes e versões do Supabase.
DO $$
DECLARE v_name TEXT;
BEGIN
  SELECT conname INTO v_name
  FROM   pg_constraint
  WHERE  conrelid = 'despesas'::regclass
    AND  contype  = 'c'
    AND  pg_get_constraintdef(oid) ILIKE '%RASCUNHO%'; -- só o constraint de status contém isso
  IF v_name IS NOT NULL THEN
    EXECUTE 'ALTER TABLE despesas DROP CONSTRAINT ' || quote_ident(v_name);
  END IF;
END;
$$;
ALTER TABLE despesas ADD CONSTRAINT despesas_status_check
  CHECK (status IN ('RASCUNHO','ENVIADA','APROVADA','REPROVADA','CANCELADA'));

-- 3b. Campos de pagamento e parcelas
ALTER TABLE despesas
  ADD COLUMN IF NOT EXISTS tipo_pagamento   VARCHAR(20)
    CHECK (tipo_pagamento IN ('A_VISTA','PARCELADO','ADIANTAMENTO')),
  ADD COLUMN IF NOT EXISTS numero_parcelas  SMALLINT
    CHECK (numero_parcelas >= 1);

-- 3c. Períodos contábil e financeiro
ALTER TABLE despesas
  ADD COLUMN IF NOT EXISTS periodo_contabil  VARCHAR(7)
    CHECK (periodo_contabil  ~ '^\d{4}-\d{2}$'),
  ADD COLUMN IF NOT EXISTS periodo_financeiro VARCHAR(7)
    CHECK (periodo_financeiro ~ '^\d{4}-\d{2}$'),
  ADD COLUMN IF NOT EXISTS data_vencimento_financeiro DATE;

-- 3d. Fornecedores (compra e fiscal)
ALTER TABLE despesas
  ADD COLUMN IF NOT EXISTS fornecedor_compra_id  UUID REFERENCES fornecedores(id),
  ADD COLUMN IF NOT EXISTS fornecedor_fiscal_id  UUID REFERENCES fornecedores(id),
  ADD COLUMN IF NOT EXISTS is_marketplace        BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS fornecedor_compra_nome_snapshot         VARCHAR(200),
  ADD COLUMN IF NOT EXISTS fornecedor_compra_cnpj_snapshot         VARCHAR(18),
  ADD COLUMN IF NOT EXISTS fornecedor_compra_codigo_senda_snapshot VARCHAR(30),
  ADD COLUMN IF NOT EXISTS fornecedor_fiscal_nome_snapshot         VARCHAR(200),
  ADD COLUMN IF NOT EXISTS fornecedor_fiscal_cnpj_snapshot         VARCHAR(18),
  ADD COLUMN IF NOT EXISTS fornecedor_fiscal_codigo_senda_snapshot VARCHAR(30);

-- 3e. Campos operacionais e fiscais
ALTER TABLE despesas
  ADD COLUMN IF NOT EXISTS oc_os              VARCHAR(100),
  ADD COLUMN IF NOT EXISTS nomenclatura_cartao VARCHAR(200),
  ADD COLUMN IF NOT EXISTS tipo_documento_fiscal VARCHAR(30)
    CHECK (tipo_documento_fiscal IN (
      'NOTA_FISCAL','CUPOM_FISCAL','RECIBO_SEM_VALOR_FISCAL',
      'COMPROVANTE_PAGAMENTO','PENDENTE_NF','OUTRO'
    )),
  ADD COLUMN IF NOT EXISTS status_fiscal      VARCHAR(30) NOT NULL DEFAULT 'NAO_ANALISADO'
    CHECK (status_fiscal IN (
      'NAO_ANALISADO','DOCUMENTO_VALIDO','PENDENTE_NF',
      'RECIBO_SEM_VALOR_FISCAL','REGULARIZADO'
    )),
  ADD COLUMN IF NOT EXISTS observacao_aprovacao TEXT;

-- 3f. Cancelamento lógico
ALTER TABLE despesas
  ADD COLUMN IF NOT EXISTS cancelada_em       TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancelada_por      UUID REFERENCES usuarios(id),
  ADD COLUMN IF NOT EXISTS motivo_cancelamento TEXT;

-- ── 4. Tabela despesa_parcelas ────────────────────────────
CREATE TABLE IF NOT EXISTS despesa_parcelas (
  id                 UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  despesa_id         UUID          NOT NULL REFERENCES despesas(id) ON DELETE CASCADE,
  numero_parcela     SMALLINT      NOT NULL CHECK (numero_parcela >= 1),
  periodo_financeiro VARCHAR(7)    NOT NULL CHECK (periodo_financeiro ~ '^\d{4}-\d{2}$'),
  data_vencimento    DATE,
  valor_parcela      NUMERIC(15,2) NOT NULL CHECK (valor_parcela > 0),
  created_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
  UNIQUE (despesa_id, numero_parcela)
);

-- ── 5. Tabela despesa_eventos_contabeis ───────────────────
CREATE TABLE IF NOT EXISTS despesa_eventos_contabeis (
  id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  despesa_id       UUID          NOT NULL REFERENCES despesas(id) ON DELETE CASCADE,
  tipo_evento      VARCHAR(40)   NOT NULL
    CHECK (tipo_evento IN (
      'PROVISAO_DESPESA','ESTORNO_PROVISAO',
      'LANCAMENTO_FISCAL_DEFINITIVO','CANCELAMENTO'
    )),
  periodo_contabil VARCHAR(7)    NOT NULL CHECK (periodo_contabil ~ '^\d{4}-\d{2}$'),
  valor            NUMERIC(15,2) NOT NULL,
  criado_por       UUID          REFERENCES usuarios(id),
  observacao       TEXT,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ── 6. Índices ────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_fornecedores_razao    ON fornecedores(razao_social);
CREATE INDEX IF NOT EXISTS idx_fornecedores_cnpj     ON fornecedores(cnpj);
CREATE INDEX IF NOT EXISTS idx_desp_tipo_pagamento   ON despesas(tipo_pagamento);
CREATE INDEX IF NOT EXISTS idx_desp_status_fiscal    ON despesas(status_fiscal);
CREATE INDEX IF NOT EXISTS idx_desp_forn_compra      ON despesas(fornecedor_compra_id);
CREATE INDEX IF NOT EXISTS idx_desp_forn_fiscal      ON despesas(fornecedor_fiscal_id);
CREATE INDEX IF NOT EXISTS idx_desp_periodo_contabil ON despesas(periodo_contabil);
CREATE INDEX IF NOT EXISTS idx_desp_cancelada        ON despesas(cancelada_em) WHERE cancelada_em IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_parcelas_despesa      ON despesa_parcelas(despesa_id);
CREATE INDEX IF NOT EXISTS idx_parcelas_periodo      ON despesa_parcelas(periodo_financeiro);
CREATE INDEX IF NOT EXISTS idx_eventos_despesa       ON despesa_eventos_contabeis(despesa_id);

-- ── 7. RLS nas novas tabelas ──────────────────────────────
ALTER TABLE fornecedores              ENABLE ROW LEVEL SECURITY;
ALTER TABLE despesa_parcelas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE despesa_eventos_contabeis ENABLE ROW LEVEL SECURITY;

-- Fornecedores: leitura para todos autenticados, escrita apenas ADMIN
DROP POLICY IF EXISTS "forn_select" ON fornecedores;
CREATE POLICY "forn_select" ON fornecedores
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "forn_insert" ON fornecedores;
CREATE POLICY "forn_insert" ON fornecedores
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM usuarios WHERE auth_user_id = auth.uid() AND perfil = 'ADMIN'
  ));

DROP POLICY IF EXISTS "forn_update" ON fornecedores;
CREATE POLICY "forn_update" ON fornecedores
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM usuarios WHERE auth_user_id = auth.uid() AND perfil = 'ADMIN'
  ));

-- Parcelas: acesso alinhado à RLS de despesas.
-- FOR ALL sem WITH CHECK não filtra INSERT no PostgreSQL — por isso
-- separamos em 4 políticas explícitas (BUG A corrigido).
DROP POLICY IF EXISTS "parc_all"    ON despesa_parcelas; -- remove policy problemática
DROP POLICY IF EXISTS "parc_select" ON despesa_parcelas;
DROP POLICY IF EXISTS "parc_insert" ON despesa_parcelas;
DROP POLICY IF EXISTS "parc_update" ON despesa_parcelas;
DROP POLICY IF EXISTS "parc_delete" ON despesa_parcelas;

CREATE POLICY "parc_select" ON despesa_parcelas
  FOR SELECT TO authenticated
  USING (despesa_id IN (SELECT id FROM despesas));

-- WITH CHECK herda o mesmo subquery de USING: usuário só pode inserir
-- parcela de uma despesa que ele próprio já conseguiria ver/editar.
CREATE POLICY "parc_insert" ON despesa_parcelas
  FOR INSERT TO authenticated
  WITH CHECK (despesa_id IN (SELECT id FROM despesas));

CREATE POLICY "parc_update" ON despesa_parcelas
  FOR UPDATE TO authenticated
  USING (despesa_id IN (SELECT id FROM despesas));

CREATE POLICY "parc_delete" ON despesa_parcelas
  FOR DELETE TO authenticated
  USING (despesa_id IN (SELECT id FROM despesas));

-- Eventos contábeis
DROP POLICY IF EXISTS "evt_select" ON despesa_eventos_contabeis;
CREATE POLICY "evt_select" ON despesa_eventos_contabeis
  FOR SELECT TO authenticated USING (
    despesa_id IN (SELECT id FROM despesas)
  );

DROP POLICY IF EXISTS "evt_insert" ON despesa_eventos_contabeis;
CREATE POLICY "evt_insert" ON despesa_eventos_contabeis
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM usuarios
      WHERE auth_user_id = auth.uid() AND perfil IN ('ADMIN','GESTOR')
    )
    AND despesa_id IN (SELECT id FROM despesas)
  );

-- ── 8. Atualizar política de UPDATE em despesas ───────────
-- Sem alteração necessária: políticas existentes (01_tables.sql / 04_policies.sql)
-- cobrem UPDATE por owner (RASCUNHO/REPROVADA) e por GESTOR/ADMIN (ENVIADA).
-- ADMIN pode atualizar qualquer registro → cancela qualquer status != APROVADA.

-- ── 9. Trigger automático de evento CANCELAMENTO ──────────
-- BUG C corrigido: em vez de exigir que o JS insira o evento em
-- despesa_eventos_contabeis (o que bloqueava USUARIO pela policy evt_insert),
-- um trigger AFTER UPDATE gera o evento automaticamente no banco.
-- SECURITY DEFINER → executa como postgres, bypassa RLS.
-- O JS de despesas.html NÃO deve mais inserir o evento diretamente.
CREATE OR REPLACE FUNCTION trigger_despesa_cancelamento()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'CANCELADA' AND OLD.status <> 'CANCELADA' THEN
    INSERT INTO despesa_eventos_contabeis (
      despesa_id,
      tipo_evento,
      periodo_contabil,
      valor,
      criado_por,
      observacao
    ) VALUES (
      NEW.id,
      'CANCELAMENTO',
      COALESCE(NEW.periodo_contabil, NEW.competencia, TO_CHAR(NOW(), 'YYYY-MM')),
      NEW.valor,
      NEW.cancelada_por,
      NEW.motivo_cancelamento
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_despesa_cancelamento ON despesas;
CREATE TRIGGER trg_despesa_cancelamento
  AFTER UPDATE ON despesas
  FOR EACH ROW EXECUTE FUNCTION trigger_despesa_cancelamento();
