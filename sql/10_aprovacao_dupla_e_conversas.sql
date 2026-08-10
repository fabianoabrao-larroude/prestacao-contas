-- ============================================================
-- 10_aprovacao_dupla_e_conversas.sql
-- Migração NÃO DESTRUTIVA – aprovação dupla (cartão + centro de custo)
-- e conversa (thread de mensagens) anexada à despesa.
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

-- ── 1. Aprovador do cartão ────────────────────────────────
-- Cardinalidade 1:1 (um cartão tem no máximo um aprovador), por isso
-- é coluna direta em cartoes_credito, não uma tabela de vínculo N:N.
ALTER TABLE cartoes_credito
  ADD COLUMN IF NOT EXISTS aprovador_usuario_id UUID REFERENCES usuarios(id);

-- ── 2. Um centro de custo tem no máximo um GESTOR ativo ───
-- Regra de negócio: 1 aprovador por centro (mas 1 aprovador pode cobrir
-- vários centros). Índice único parcial impede vincular um segundo
-- GESTOR ativo ao mesmo centro.
CREATE UNIQUE INDEX IF NOT EXISTS idx_ucc_um_gestor_por_centro
  ON usuario_centros_custo (centro_custo_id)
  WHERE papel_no_centro = 'GESTOR' AND ativo = true;

-- ── 3. Segundo gate de aprovação em despesas ──────────────
-- aprovado_por_usuario_id / aprovado_em (já existentes) passam a
-- representar a aprovação PELO CENTRO DE CUSTO.
-- Os campos abaixo são a aprovação PELO CARTÃO, independente.
ALTER TABLE despesas
  ADD COLUMN IF NOT EXISTS aprovado_cartao_por_usuario_id UUID REFERENCES usuarios(id),
  ADD COLUMN IF NOT EXISTS aprovado_cartao_em             TIMESTAMPTZ;

COMMENT ON COLUMN despesas.aprovado_por_usuario_id IS 'Aprovação pelo GESTOR do centro de custo';
COMMENT ON COLUMN despesas.aprovado_em              IS 'Data/hora da aprovação pelo centro de custo';
COMMENT ON COLUMN despesas.aprovado_cartao_por_usuario_id IS 'Aprovação pelo aprovador do cartão';
COMMENT ON COLUMN despesas.aprovado_cartao_em              IS 'Data/hora da aprovação pelo cartão';

-- ── 4. Trava de aprovação enquanto há mensagem sem resposta ─
ALTER TABLE despesas
  ADD COLUMN IF NOT EXISTS aguardando_resposta BOOLEAN NOT NULL DEFAULT false;

-- ── 5. Conversa por despesa ────────────────────────────────
CREATE TABLE IF NOT EXISTS despesa_mensagens (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  despesa_id       UUID        NOT NULL REFERENCES despesas(id) ON DELETE CASCADE,
  autor_usuario_id UUID        NOT NULL REFERENCES usuarios(id),
  mensagem         TEXT        NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_msg_despesa ON despesa_mensagens(despesa_id);

-- ── 6. Função de RLS: cartões onde o usuário atual é aprovador ─
CREATE OR REPLACE FUNCTION auth_cartoes_aprovador()
RETURNS SETOF UUID LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT c.id
  FROM cartoes_credito c
  JOIN usuarios u ON u.id = c.aprovador_usuario_id
  WHERE u.auth_user_id = auth.uid()
    AND u.ativo = true
$$;

-- ── 7. Trigger: nova mensagem trava/destrava aprovação ─────
-- Se quem escreve é o próprio solicitante da despesa, entende-se como
-- resposta → destrava. Se é qualquer outra pessoa (aprovador de
-- cartão, gestor do centro, ADMIN), entende-se como pedido → trava.
CREATE OR REPLACE FUNCTION trigger_despesa_mensagem_trava()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_usuario_id UUID;
BEGIN
  SELECT usuario_id INTO v_usuario_id FROM despesas WHERE id = NEW.despesa_id;
  UPDATE despesas
  SET aguardando_resposta = (NEW.autor_usuario_id <> v_usuario_id)
  WHERE id = NEW.despesa_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_despesa_mensagem_trava ON despesa_mensagens;
CREATE TRIGGER trg_despesa_mensagem_trava
  AFTER INSERT ON despesa_mensagens
  FOR EACH ROW EXECUTE FUNCTION trigger_despesa_mensagem_trava();

-- ── 8. Trigger: aprovação dupla completa → status = APROVADA ──
-- Fecha status automaticamente quando os dois gates estão preenchidos.
-- Reprovação por qualquer um dos dois lados reprova a despesa inteira
-- (a app seta status='REPROVADA' diretamente, este trigger só cuida
-- do caminho positivo).
CREATE OR REPLACE FUNCTION trigger_despesa_aprovacao_dupla()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status = 'ENVIADA'
     AND NEW.aprovado_por_usuario_id IS NOT NULL
     AND NEW.aprovado_cartao_por_usuario_id IS NOT NULL THEN
    NEW.status := 'APROVADA';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_despesa_aprovacao_dupla ON despesas;
CREATE TRIGGER trg_despesa_aprovacao_dupla
  BEFORE UPDATE ON despesas
  FOR EACH ROW EXECUTE FUNCTION trigger_despesa_aprovacao_dupla();

-- ── 9. RLS: despesas — incluir visibilidade do aprovador de cartão ─
DROP POLICY IF EXISTS "desp_select" ON despesas;
CREATE POLICY "desp_select" ON despesas
  FOR SELECT TO authenticated
  USING (
    auth_is_admin()
    OR (auth_perfil() = 'GESTOR' AND centro_custo_id IN (SELECT auth_centros_gestor()))
    OR cartao_id IN (SELECT auth_cartoes_aprovador())
    OR usuario_id = auth_usuario_id()
  );

-- UPDATE: dono edita RASCUNHO/REPROVADA; GESTOR do centro e aprovador
-- do cartão aprovam/reprovam ENVIADAS (cada um só mexe nos seus
-- próprios campos de gate na app, mas a policy libera o UPDATE);
-- trava se aguardando_resposta = true (exceto o próprio dono
-- respondendo, que não faz UPDATE de aprovação, só de mensagem).
DROP POLICY IF EXISTS "desp_update" ON despesas;
CREATE POLICY "desp_update" ON despesas
  FOR UPDATE TO authenticated
  USING (
    auth_is_admin()
    OR (usuario_id = auth_usuario_id() AND status IN ('RASCUNHO','REPROVADA'))
    OR (
      status = 'ENVIADA' AND NOT aguardando_resposta
      AND (
        (auth_perfil() = 'GESTOR' AND centro_custo_id IN (SELECT auth_centros_gestor()))
        OR cartao_id IN (SELECT auth_cartoes_aprovador())
      )
    )
  )
  WITH CHECK (
    auth_is_admin()
    OR (usuario_id = auth_usuario_id())
    OR (auth_perfil() = 'GESTOR' AND centro_custo_id IN (SELECT auth_centros_gestor()))
    OR cartao_id IN (SELECT auth_cartoes_aprovador())
  );

-- ── 10. RLS: despesa_anexos — incluir aprovador de cartão ──────
DROP POLICY IF EXISTS "anx_select" ON despesa_anexos;
CREATE POLICY "anx_select" ON despesa_anexos
  FOR SELECT TO authenticated
  USING (
    auth_is_admin()
    OR uploaded_by_usuario_id = auth_usuario_id()
    OR despesa_id IN (SELECT id FROM despesas WHERE usuario_id = auth_usuario_id())
    OR despesa_id IN (SELECT id FROM despesas WHERE centro_custo_id IN (SELECT auth_centros_gestor()))
    OR despesa_id IN (SELECT id FROM despesas WHERE cartao_id IN (SELECT auth_cartoes_aprovador()))
  );

-- ── 11. RLS: despesa_mensagens ──────────────────────────────
ALTER TABLE despesa_mensagens ENABLE ROW LEVEL SECURITY;

-- Visibilidade da thread = visibilidade da despesa (reaproveita desp_select)
CREATE POLICY "msg_select" ON despesa_mensagens
  FOR SELECT TO authenticated
  USING (despesa_id IN (SELECT id FROM despesas));

CREATE POLICY "msg_insert" ON despesa_mensagens
  FOR INSERT TO authenticated
  WITH CHECK (
    autor_usuario_id = auth_usuario_id()
    AND despesa_id IN (SELECT id FROM despesas)
  );

-- Sem UPDATE/DELETE de mensagens — thread é histórico imutável.

-- ── 12. cartoes_credito: liberar UPDATE do aprovador para ADMIN ──
-- (já coberto por cart_update existente com auth_is_admin(); nenhuma
-- policy nova necessária aqui, só o campo criado no passo 1.)
