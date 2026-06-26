-- ============================================================
-- 08_funcoes_codigo.sql
-- Funções de geração de código sequencial
--
-- Regras:
--   • MAX do maior número existente + 1. Nunca COUNT(*).
--   • Lock + MAX + INSERT na MESMA transação (concorrência-safe).
--   • Inclui registros inativos/cancelados no MAX.
--   • codigo_senda (fornecedores) é campo externo do ERP:
--     NUNCA gerado automaticamente por este sistema.
-- ============================================================

-- ── 1. Garantir constraint UNIQUE em usuarios.codigo ─────
-- Idempotente: só cria se ainda não existir nenhum índice
-- unique na coluna, evitando erro em re-execução.
-- (01_tables.sql já define UNIQUE na coluna; este bloco é
-- proteção extra para ambientes onde 01 não foi rodado limpo.)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM   pg_index    pi
    JOIN   pg_class    pc ON pc.oid = pi.indrelid
    JOIN   pg_attribute pa ON pa.attrelid = pc.oid
                           AND pa.attnum  = ANY(pi.indkey)
    WHERE  pc.relname    = 'usuarios'
      AND  pa.attname    = 'codigo'
      AND  pi.indisunique = true
  ) THEN
    ALTER TABLE usuarios ADD CONSTRAINT usuarios_codigo_unique UNIQUE (codigo);
  END IF;
END;
$$;

-- ── 2. criar_usuario_operacional() ───────────────────────
--
-- FUNÇÃO PRINCIPAL. Chamada pela Edge Function admin-create-user
-- imediatamente após criar o usuário no Supabase Auth.
--
-- Por que é concorrência-safe:
--   O plpgsql executa inteiro dentro de UMA transação de banco.
--   O advisory lock é transacional (xact): só é liberado quando
--   a transação que o adquiriu faz COMMIT ou ROLLBACK.
--   Como o INSERT acontece na mesma transação que o MAX:
--     ① transação A: lock → MAX=5 → INSERT USR006 → COMMIT → lock liberado
--     ② transação B (bloqueada em ①): lock → MAX=6 (vê USR006) → INSERT USR007
--   Não há janela entre "ler o MAX" e "inserir" para outra
--   transação interferir.
--
-- Safety net adicional:
--   UNIQUE em usuarios.codigo: se por qualquer bug o lock falhar,
--   o INSERT da segunda chamada recebe unique_violation, nunca
--   cria silenciosamente um código duplicado.
--
-- Retorna SETOF usuarios (linha completa do registro criado).
-- O caller usa rows[0] para obter o novoUsuario.
CREATE OR REPLACE FUNCTION criar_usuario_operacional(
  p_auth_user_id UUID,
  p_nome         TEXT,
  p_email        TEXT,
  p_perfil       TEXT
)
RETURNS SETOF usuarios
LANGUAGE plpgsql
VOLATILE                 -- VOLATILE: efeito colateral (lock + insert)
SECURITY DEFINER         -- executa como owner (postgres), bypassa RLS
AS $$
DECLARE
  v_max    INTEGER;
  v_next   INTEGER;
  v_codigo TEXT;
BEGIN
  -- ① Serializar: bloqueia concorrentes até este COMMIT.
  --   Qualquer chamada concorrente aguarda aqui até a transação atual
  --   concluir (inclusive o INSERT abaixo).
  PERFORM pg_advisory_xact_lock(hashtext('criar_usuario_operacional')::BIGINT);

  -- ② Validar duplicidade de auth_user_id.
  --   Cobre: reinvite de usuário que já tem registro operacional,
  --   ou bug no caller que usa o mesmo auth_user_id duas vezes.
  IF EXISTS (
    SELECT 1 FROM usuarios WHERE auth_user_id = p_auth_user_id
  ) THEN
    RAISE EXCEPTION
      'auth_user_id % já possui registro em public.usuarios', p_auth_user_id
      USING ERRCODE = 'unique_violation',
            HINT    = 'Usuário Auth já está cadastrado no sistema operacional';
  END IF;

  -- ③ Validar duplicidade de email.
  --   Cobre: email reutilizado após deleção do Auth sem limpeza do
  --   registro operacional, ou cadastro duplo via chamadas concorrentes.
  IF EXISTS (
    SELECT 1 FROM usuarios WHERE email = p_email
  ) THEN
    RAISE EXCEPTION
      'e-mail % já possui registro em public.usuarios', p_email
      USING ERRCODE = 'unique_violation',
            HINT    = 'E-mail já cadastrado no sistema operacional';
  END IF;

  -- ④ MAX do maior número já usado (todos: ativos, inativos, convidados).
  --   CASE ignora códigos mal-formados tratando-os como 0.
  --   COALESCE(NULL, 0) cobre tabela vazia → primeiro será USR001.
  SELECT COALESCE(
    MAX(
      CASE
        WHEN codigo ~ '^USR[0-9]+$'
        THEN SUBSTRING(codigo FROM 4)::INTEGER
        ELSE 0
      END
    ),
    0
  )
  INTO v_max
  FROM usuarios;

  v_next   := v_max + 1;
  v_codigo := 'USR' || LPAD(v_next::TEXT, 3, '0');

  -- ⑤ INSERT na mesma transação — lock ainda ativo aqui.
  RETURN QUERY
  INSERT INTO usuarios (
    auth_user_id,
    codigo,
    nome,
    email,
    perfil,
    status_acesso,
    ativo
  )
  VALUES (
    p_auth_user_id,
    v_codigo,
    p_nome,
    p_email,
    p_perfil,
    'CONVIDADO',
    true
  )
  RETURNING *;
  -- ⑥ COMMIT implícito ao sair da função → lock liberado aqui.
END;
$$;

-- ── 3. proximo_codigo_usuario() — DEPRECATED ─────────────
-- Esta função NÃO É MAIS CHAMADA pela Edge Function.
-- Mantida apenas para substituir eventual versão baseada em
-- COUNT que possa existir no banco. Pode ser dropada após
-- confirmação de que nenhum caller a referencia.
-- NÃO usar diretamente: a geração isolada de código sem o
-- INSERT subsequente na mesma transação não é concorrência-safe.
CREATE OR REPLACE FUNCTION proximo_codigo_usuario()
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_max INTEGER;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('criar_usuario_operacional')::BIGINT);
  SELECT COALESCE(MAX(
    CASE WHEN codigo ~ '^USR[0-9]+$'
         THEN SUBSTRING(codigo FROM 4)::INTEGER
         ELSE 0
    END), 0)
  INTO v_max FROM usuarios;
  RETURN 'USR' || LPAD((v_max + 1)::TEXT, 3, '0');
END;
$$;

-- ── 4. proximo_codigo_centro_custo() ─────────────────────
-- Reservado para futura Edge Function de cadastro de CC.
-- Formato: CC001, CC002, …
CREATE OR REPLACE FUNCTION proximo_codigo_centro_custo()
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_max INTEGER;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('proximo_codigo_centro_custo')::BIGINT);
  SELECT COALESCE(MAX(
    CASE WHEN codigo ~ '^CC[0-9]+$'
         THEN SUBSTRING(codigo FROM 3)::INTEGER
         ELSE 0
    END), 0)
  INTO v_max FROM centros_custo;
  RETURN 'CC' || LPAD((v_max + 1)::TEXT, 3, '0');
END;
$$;

-- ── 5. proximo_codigo_conta_despesa() ────────────────────
-- Formato: CD001, CD002, …
CREATE OR REPLACE FUNCTION proximo_codigo_conta_despesa()
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_max INTEGER;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('proximo_codigo_conta_despesa')::BIGINT);
  SELECT COALESCE(MAX(
    CASE WHEN codigo ~ '^CD[0-9]+$'
         THEN SUBSTRING(codigo FROM 3)::INTEGER
         ELSE 0
    END), 0)
  INTO v_max FROM contas_despesa;
  RETURN 'CD' || LPAD((v_max + 1)::TEXT, 3, '0');
END;
$$;

-- ── 6. proximo_codigo_cartao() ───────────────────────────
-- Formato: CART001, CART002, …
CREATE OR REPLACE FUNCTION proximo_codigo_cartao()
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_max INTEGER;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('proximo_codigo_cartao')::BIGINT);
  SELECT COALESCE(MAX(
    CASE WHEN codigo ~ '^CART[0-9]+$'
         THEN SUBSTRING(codigo FROM 5)::INTEGER
         ELSE 0
    END), 0)
  INTO v_max FROM cartoes_credito;
  RETURN 'CART' || LPAD((v_max + 1)::TEXT, 3, '0');
END;
$$;

-- ── 7. Permissões ─────────────────────────────────────────
-- criar_usuario_operacional: service_role apenas.
REVOKE ALL      ON FUNCTION criar_usuario_operacional(UUID,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE EXECUTE  ON FUNCTION criar_usuario_operacional(UUID,TEXT,TEXT,TEXT) FROM anon;
REVOKE EXECUTE  ON FUNCTION criar_usuario_operacional(UUID,TEXT,TEXT,TEXT) FROM authenticated;
GRANT  EXECUTE  ON FUNCTION criar_usuario_operacional(UUID,TEXT,TEXT,TEXT) TO service_role;

-- proximo_codigo_usuario: idem (deprecated, mas mantida restrita).
REVOKE ALL      ON FUNCTION proximo_codigo_usuario() FROM PUBLIC;
REVOKE EXECUTE  ON FUNCTION proximo_codigo_usuario() FROM anon;
REVOKE EXECUTE  ON FUNCTION proximo_codigo_usuario() FROM authenticated;
GRANT  EXECUTE  ON FUNCTION proximo_codigo_usuario() TO service_role;

-- Funções auxiliares de cadastro (CC, CD, CART): apenas service_role.
-- Se futuramente chamadas via frontend autenticado, adicionar
-- GRANT EXECUTE ON FUNCTION ... TO authenticated; naquele momento.
REVOKE ALL      ON FUNCTION proximo_codigo_centro_custo()  FROM PUBLIC;
REVOKE EXECUTE  ON FUNCTION proximo_codigo_centro_custo()  FROM anon;
REVOKE EXECUTE  ON FUNCTION proximo_codigo_centro_custo()  FROM authenticated;
GRANT  EXECUTE  ON FUNCTION proximo_codigo_centro_custo()  TO service_role;

REVOKE ALL      ON FUNCTION proximo_codigo_conta_despesa() FROM PUBLIC;
REVOKE EXECUTE  ON FUNCTION proximo_codigo_conta_despesa() FROM anon;
REVOKE EXECUTE  ON FUNCTION proximo_codigo_conta_despesa() FROM authenticated;
GRANT  EXECUTE  ON FUNCTION proximo_codigo_conta_despesa() TO service_role;

REVOKE ALL      ON FUNCTION proximo_codigo_cartao()        FROM PUBLIC;
REVOKE EXECUTE  ON FUNCTION proximo_codigo_cartao()        FROM anon;
REVOKE EXECUTE  ON FUNCTION proximo_codigo_cartao()        FROM authenticated;
GRANT  EXECUTE  ON FUNCTION proximo_codigo_cartao()        TO service_role;

-- ── 8. codigo_senda (fornecedores) ───────────────────────
-- Campo externo do ERP Senda. Nunca gerado por este sistema.
-- Informado manualmente pelo ADMIN ou importado via integração.

-- ── 9. Testes de sanidade (executar manualmente no SQL Editor) ──
--
-- a) Verificar retorno correto (executar como postgres/service_role):
--   SELECT * FROM criar_usuario_operacional(
--     gen_random_uuid(), 'Teste', 'teste@x.com', 'USUARIO'
--   );
--   -- Deve inserir e retornar linha com codigo = próximo USR00N
--   -- Lembre de fazer ROLLBACK ou DELETE após o teste.
--
-- b) Verificar que authenticated NÃO executa:
--   -- (como usuário logado via anon key)
--   SELECT * FROM criar_usuario_operacional(...);
--   -- Esperado: ERROR: permission denied for function criar_usuario_operacional
--
-- c) Verificar constraint unique:
--   SELECT conname, contype FROM pg_constraint
--   WHERE conrelid = 'usuarios'::regclass AND contype = 'u';
