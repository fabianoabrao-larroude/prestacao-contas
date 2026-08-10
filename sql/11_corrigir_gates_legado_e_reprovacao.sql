-- ============================================================
-- 11_corrigir_gates_legado_e_reprovacao.sql
-- 1) Backfill de despesas já APROVADAS antes da aprovação dupla existir
--    (aprovado_cartao_* ficou NULL porque a coluna não existia ainda).
-- 2) Coluna para saber qual lado efetivamente reprovou, já que
--    aprovado_por_usuario_id/aprovado_cartao_por_usuario_id também são
--    usados para registrar quem reprovou (ambíguo sem essa marcação).
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

-- ── 1. Backfill legado ─────────────────────────────────────
-- Despesas já aprovadas sob o sistema antigo (gate único) tinham só o
-- lado "centro" preenchido. Melhor estimativa: replicar para o cartão.
UPDATE despesas
SET aprovado_cartao_por_usuario_id = aprovado_por_usuario_id,
    aprovado_cartao_em             = aprovado_em
WHERE status = 'APROVADA'
  AND aprovado_cartao_por_usuario_id IS NULL
  AND aprovado_por_usuario_id IS NOT NULL;

-- ── 2. Lado que reprovou ────────────────────────────────────
ALTER TABLE despesas
  ADD COLUMN IF NOT EXISTS reprovado_lado VARCHAR(10)
    CHECK (reprovado_lado IN ('CENTRO','CARTAO'));

COMMENT ON COLUMN despesas.reprovado_lado IS 'Qual gate (CENTRO ou CARTAO) executou a reprovação, quando status=REPROVADA';
