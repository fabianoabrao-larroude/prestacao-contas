-- ============================================================
-- 09_remover_pago_parcelas.sql
-- Remove colunas de baixa financeira de despesa_parcelas.
-- Baixa financeira não faz parte do MVP atual.
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

ALTER TABLE despesa_parcelas DROP COLUMN IF EXISTS pago;
ALTER TABLE despesa_parcelas DROP COLUMN IF EXISTS data_pagamento;
