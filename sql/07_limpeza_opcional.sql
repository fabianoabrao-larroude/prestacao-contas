-- ============================================================
-- 07_limpeza_opcional.sql
-- LIMPEZA OPCIONAL — RODAR SOMENTE COM AUTORIZAÇÃO EXPLÍCITA
-- Remove dados fictícios, preserva cadastros de referência.
-- ============================================================

-- ATENÇÃO: Execute em partes, na ordem abaixo.
-- Confirme cada etapa antes de prosseguir.

-- ── Passo 1: Eventos contábeis (se tabela já criada) ──────
DELETE FROM despesa_eventos_contabeis;

-- ── Passo 2: Parcelas financeiras (se tabela já criada) ───
DELETE FROM despesa_parcelas;

-- ── Passo 3: Anexos (registro em banco) ──────────────────
DELETE FROM despesa_anexos;

-- ── Passo 4: Despesas ────────────────────────────────────
DELETE FROM despesas;

-- ── Passo 5: Storage (execute via Supabase Dashboard) ────
-- Dashboard > Storage > despesas-anexos > selecionar tudo > deletar
-- OU via API (requer service_role key):
--
--   const { data, error } = await supabase.storage
--     .from('despesas-anexos')
--     .list('despesas');
--   // Para cada pasta, listar e remover os arquivos

-- ── Passo 6 (Opcional): Fornecedores de teste ────────────
-- DELETE FROM fornecedores WHERE observacao LIKE '%teste%';

-- ── Preservados (NÃO APAGAR): ─────────────────────────────
-- usuarios, usuario_centros_custo, usuario_cartoes
-- centros_custo, contas_despesa, cartoes_credito
-- ============================================================
