-- ============================================================
-- 01_tables.sql  –  Criação das tabelas
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

-- Trigger genérico para updated_at
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ============================================================
-- Centros de Custo
-- ============================================================
CREATE TABLE IF NOT EXISTS centros_custo (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo     VARCHAR(20) NOT NULL UNIQUE,
  nome       VARCHAR(100) NOT NULL,
  ativo      BOOLEAN     NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_centros_custo_upd
  BEFORE UPDATE ON centros_custo
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================================
-- Contas de Despesa
-- ============================================================
CREATE TABLE IF NOT EXISTS contas_despesa (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo     VARCHAR(20) NOT NULL UNIQUE,
  nome       VARCHAR(100) NOT NULL,
  ativo      BOOLEAN     NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_contas_despesa_upd
  BEFORE UPDATE ON contas_despesa
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================================
-- Cartões de Crédito
-- ============================================================
CREATE TABLE IF NOT EXISTS cartoes_credito (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo            VARCHAR(20) NOT NULL UNIQUE,
  nome              VARCHAR(100) NOT NULL,
  ultimos_4_digitos CHAR(4)     NOT NULL,
  bandeira          VARCHAR(30),
  ativo             BOOLEAN     NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_cartoes_upd
  BEFORE UPDATE ON cartoes_credito
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================================
-- Usuários Operacionais
-- ============================================================
CREATE TABLE IF NOT EXISTS usuarios (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id       UUID        UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  codigo             VARCHAR(20) NOT NULL UNIQUE,
  nome               VARCHAR(100) NOT NULL,
  email              VARCHAR(255) NOT NULL UNIQUE,
  perfil             VARCHAR(20) NOT NULL CHECK (perfil IN ('ADMIN','GESTOR','USUARIO')),
  status_acesso      VARCHAR(20) NOT NULL DEFAULT 'CONVIDADO'
                       CHECK (status_acesso IN ('CONVIDADO','ATIVO','INATIVO','BLOQUEADO')),
  ativo              BOOLEAN     NOT NULL DEFAULT true,
  primeiro_acesso_em TIMESTAMPTZ,
  ultimo_login_em    TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_usuarios_upd
  BEFORE UPDATE ON usuarios
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================================
-- Vínculos: Usuário <-> Centro de Custo
-- ============================================================
CREATE TABLE IF NOT EXISTS usuario_centros_custo (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id      UUID        NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  centro_custo_id UUID        NOT NULL REFERENCES centros_custo(id) ON DELETE CASCADE,
  papel_no_centro VARCHAR(20) NOT NULL DEFAULT 'MEMBRO'
                    CHECK (papel_no_centro IN ('MEMBRO','GESTOR')),
  ativo           BOOLEAN     NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (usuario_id, centro_custo_id)
);

-- ============================================================
-- Vínculos: Usuário <-> Cartão
-- ============================================================
CREATE TABLE IF NOT EXISTS usuario_cartoes (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID        NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  cartao_id  UUID        NOT NULL REFERENCES cartoes_credito(id) ON DELETE CASCADE,
  ativo      BOOLEAN     NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (usuario_id, cartao_id)
);

-- ============================================================
-- Despesas
-- ============================================================
CREATE TABLE IF NOT EXISTS despesas (
  id                      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id              UUID          NOT NULL REFERENCES usuarios(id),
  cartao_id               UUID          NOT NULL REFERENCES cartoes_credito(id),
  centro_custo_id         UUID          NOT NULL REFERENCES centros_custo(id),
  conta_despesa_id        UUID          NOT NULL REFERENCES contas_despesa(id),
  data_despesa            DATE          NOT NULL,
  data_cadastro           TIMESTAMPTZ   NOT NULL DEFAULT now(),
  competencia             VARCHAR(7)    NOT NULL CHECK (competencia ~ '^\d{4}-\d{2}$'),
  fornecedor              VARCHAR(200)  NOT NULL,
  descricao               TEXT          NOT NULL,
  valor                   NUMERIC(15,2) NOT NULL CHECK (valor > 0),
  observacao              TEXT,
  status                  VARCHAR(20)   NOT NULL DEFAULT 'RASCUNHO'
                            CHECK (status IN ('RASCUNHO','ENVIADA','APROVADA','REPROVADA')),
  aprovado_por_usuario_id UUID          REFERENCES usuarios(id),
  aprovado_em             TIMESTAMPTZ,
  motivo_reprovacao       TEXT,
  created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_despesas_upd
  BEFORE UPDATE ON despesas
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================================
-- Anexos de Despesas
-- ============================================================
CREATE TABLE IF NOT EXISTS despesa_anexos (
  id                     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  despesa_id             UUID         NOT NULL REFERENCES despesas(id) ON DELETE CASCADE,
  nome_arquivo           VARCHAR(255) NOT NULL,
  storage_path           TEXT         NOT NULL,
  tipo_arquivo           VARCHAR(50)  NOT NULL,
  tamanho_bytes          BIGINT       NOT NULL,
  uploaded_by_usuario_id UUID         NOT NULL REFERENCES usuarios(id),
  created_at             TIMESTAMPTZ  NOT NULL DEFAULT now()
);
