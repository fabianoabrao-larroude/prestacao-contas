-- ============================================================
-- 14_destinatario_e_leitura_mensagem.sql
-- Destinatário explícito por mensagem + controle de leitura, para
-- alertar quem foi acionado numa conversa de despesa.
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

ALTER TABLE despesa_mensagens
  ADD COLUMN IF NOT EXISTS destinatario_usuario_id UUID REFERENCES usuarios(id),
  ADD COLUMN IF NOT EXISTS lido_em                 TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_msg_destinatario_nao_lida
  ON despesa_mensagens(destinatario_usuario_id)
  WHERE lido_em IS NULL;

-- Marcar como lidas exige função dedicada (SECURITY DEFINER): o
-- destinatário não é o autor, então as policies de UPDATE existentes
-- (restritas a auto_usuario_id = auth_usuario_id()) não liberam isso —
-- e não queremos abrir UPDATE genérico pro destinatário, que poderia
-- editar o texto da mensagem de outra pessoa.
CREATE OR REPLACE FUNCTION marcar_mensagens_lidas(p_despesa_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE despesa_mensagens
  SET lido_em = now()
  WHERE despesa_id = p_despesa_id
    AND destinatario_usuario_id = auth_usuario_id()
    AND lido_em IS NULL;
END;
$$;
