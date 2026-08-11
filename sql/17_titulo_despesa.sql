-- ============================================================
-- 17_titulo_despesa.sql
-- Título amigável da despesa (ex: "Viagem São Paulo"), definido pelo
-- solicitante. Limite de 80 caracteres.
-- Backfill com placeholder só para testar comportamento na tela —
-- não deve ficar assim em produção.
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

ALTER TABLE despesas ADD COLUMN IF NOT EXISTS titulo VARCHAR(80);

UPDATE despesas
SET titulo = 'Título da despesa #' || numero_despesa
WHERE titulo IS NULL;
