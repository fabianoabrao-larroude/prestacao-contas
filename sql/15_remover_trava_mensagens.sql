-- ============================================================
-- 15_remover_trava_mensagens.sql
-- Remove o bloqueio de aprovação baseado em mensagens.
-- A conversa continua disponível, mas não altera a despesa.
-- ============================================================

DROP TRIGGER IF EXISTS trg_despesa_mensagem_trava ON despesa_mensagens;
DROP FUNCTION IF EXISTS trigger_despesa_mensagem_trava();

-- Recria a policy sem depender de aguardando_resposta antes de
-- remover a coluna usada pela implementação anterior.
DROP POLICY IF EXISTS "desp_update" ON despesas;
CREATE POLICY "desp_update" ON despesas
  FOR UPDATE TO authenticated
  USING (
    auth_is_admin()
    OR (usuario_id = auth_usuario_id() AND status IN ('RASCUNHO','REPROVADA'))
    OR (
      status = 'ENVIADA'
      AND (
        (auth_perfil() = 'GESTOR' AND centro_custo_id IN (SELECT auth_centros_gestor()))
        OR cartao_id IN (SELECT auth_cartoes_aprovador())
      )
    )
  )
  WITH CHECK (
    auth_is_admin()
    OR usuario_id = auth_usuario_id()
    OR (auth_perfil() = 'GESTOR' AND centro_custo_id IN (SELECT auth_centros_gestor()))
    OR cartao_id IN (SELECT auth_cartoes_aprovador())
  );

ALTER TABLE despesas DROP COLUMN IF EXISTS aguardando_resposta;
