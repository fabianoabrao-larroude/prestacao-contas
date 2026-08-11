-- ============================================================
-- 18_titulo_obrigatorio.sql
-- Torna despesas.titulo obrigatório agora que todos os registros
-- existentes já foram preenchidos (sql/17 fez o backfill).
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

ALTER TABLE despesas ALTER COLUMN titulo SET NOT NULL;
