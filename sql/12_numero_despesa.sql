-- ============================================================
-- 12_numero_despesa.sql
-- Identificador sequencial e legível para despesas (numero_despesa).
-- Gerado sempre por MAX+1, nunca COUNT(*)+1.
-- Execute no SQL Editor do Supabase (Dashboard > SQL Editor)
-- ============================================================

ALTER TABLE despesas ADD COLUMN IF NOT EXISTS numero_despesa INTEGER UNIQUE;

-- Backfill: numera despesas sem número a partir do maior número atual.
-- Isso também é seguro quando a migração é retomada parcialmente.
UPDATE despesas d
SET numero_despesa = sub.maior_numero + sub.rn
FROM (
  SELECT id,
         ROW_NUMBER() OVER (ORDER BY created_at, id) AS rn,
         COALESCE(MAX(numero_despesa) OVER (), 0) AS maior_numero
  FROM despesas
) sub
WHERE d.id = sub.id
  AND d.numero_despesa IS NULL;

-- Trigger: próximas despesas recebem MAX(numero_despesa)+1 automaticamente.
CREATE OR REPLACE FUNCTION trigger_despesa_numero()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.numero_despesa IS NULL THEN
    SELECT COALESCE(MAX(numero_despesa), 0) + 1 INTO NEW.numero_despesa FROM despesas;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_despesa_numero ON despesas;
CREATE TRIGGER trg_despesa_numero
  BEFORE INSERT ON despesas
  FOR EACH ROW EXECUTE FUNCTION trigger_despesa_numero();
