-- ============================================================
-- 16_corrigir_numeros_despesas_legadas.sql
-- Preenche numero_despesa em registros legados que ficaram sem ID.
-- Pode ser executada mais de uma vez com segurança.
-- ============================================================

WITH maior AS (
  SELECT COALESCE(MAX(numero_despesa), 0) AS valor
  FROM despesas
), pendentes AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS ordem
  FROM despesas
  WHERE numero_despesa IS NULL
)
UPDATE despesas d
SET numero_despesa = maior.valor + pendentes.ordem
FROM maior, pendentes
WHERE d.id = pendentes.id
  AND d.numero_despesa IS NULL;

-- Garante a geração para os próximos registros.
CREATE OR REPLACE FUNCTION trigger_despesa_numero()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.numero_despesa IS NULL THEN
    SELECT COALESCE(MAX(numero_despesa), 0) + 1
      INTO NEW.numero_despesa
      FROM despesas;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_despesa_numero ON despesas;
CREATE TRIGGER trg_despesa_numero
  BEFORE INSERT ON despesas
  FOR EACH ROW EXECUTE FUNCTION trigger_despesa_numero();

-- Só aplica NOT NULL depois que todos os registros foram corrigidos.
ALTER TABLE despesas ALTER COLUMN numero_despesa SET NOT NULL;
