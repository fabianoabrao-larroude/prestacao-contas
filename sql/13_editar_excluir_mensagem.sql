-- ============================================================
-- 13_editar_excluir_mensagem.sql
-- Permite ao autor de uma mensagem da conversa editar/excluir a
-- própria mensagem. Antes a thread era só INSERT/SELECT (imutável).
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

ALTER TABLE despesa_mensagens ADD COLUMN IF NOT EXISTS editado_em TIMESTAMPTZ;

DROP POLICY IF EXISTS "msg_update" ON despesa_mensagens;
CREATE POLICY "msg_update" ON despesa_mensagens
  FOR UPDATE TO authenticated
  USING (autor_usuario_id = auth_usuario_id())
  WITH CHECK (autor_usuario_id = auth_usuario_id());

DROP POLICY IF EXISTS "msg_delete" ON despesa_mensagens;
CREATE POLICY "msg_delete" ON despesa_mensagens
  FOR DELETE TO authenticated
  USING (autor_usuario_id = auth_usuario_id());
