-- ============================================================
-- 03_rls.sql  –  Habilitar RLS + funções auxiliares de segurança
-- ============================================================

-- Habilitar RLS em todas as tabelas
ALTER TABLE centros_custo         ENABLE ROW LEVEL SECURITY;
ALTER TABLE contas_despesa        ENABLE ROW LEVEL SECURITY;
ALTER TABLE cartoes_credito       ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios              ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuario_centros_custo ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuario_cartoes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE despesas              ENABLE ROW LEVEL SECURITY;
ALTER TABLE despesa_anexos        ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Funções auxiliares (SECURITY DEFINER → executam como owner,
-- nunca expõem dados ao chamador além do retorno)
-- ============================================================

-- Perfil do usuário autenticado
CREATE OR REPLACE FUNCTION auth_perfil()
RETURNS TEXT LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT perfil FROM usuarios
  WHERE auth_user_id = auth.uid() AND ativo = true LIMIT 1
$$;

-- ID operacional do usuário autenticado na tabela usuarios
CREATE OR REPLACE FUNCTION auth_usuario_id()
RETURNS UUID LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT id FROM usuarios
  WHERE auth_user_id = auth.uid() AND ativo = true LIMIT 1
$$;

-- O usuário autenticado é ADMIN ativo?
CREATE OR REPLACE FUNCTION auth_is_admin()
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM usuarios
    WHERE auth_user_id = auth.uid() AND perfil = 'ADMIN' AND ativo = true
  )
$$;

-- O usuário autenticado é GESTOR ou ADMIN ativo?
CREATE OR REPLACE FUNCTION auth_is_gestor_or_admin()
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM usuarios
    WHERE auth_user_id = auth.uid() AND perfil IN ('ADMIN','GESTOR') AND ativo = true
  )
$$;

-- Centros onde o usuário atual tem papel GESTOR
CREATE OR REPLACE FUNCTION auth_centros_gestor()
RETURNS SETOF UUID LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT ucc.centro_custo_id
  FROM usuario_centros_custo ucc
  JOIN usuarios u ON u.id = ucc.usuario_id
  WHERE u.auth_user_id = auth.uid()
    AND u.ativo = true
    AND ucc.papel_no_centro = 'GESTOR'
    AND ucc.ativo = true
$$;

-- Todos os centros vinculados ao usuário atual (MEMBRO ou GESTOR)
CREATE OR REPLACE FUNCTION auth_centros_usuario()
RETURNS SETOF UUID LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT ucc.centro_custo_id
  FROM usuario_centros_custo ucc
  JOIN usuarios u ON u.id = ucc.usuario_id
  WHERE u.auth_user_id = auth.uid()
    AND u.ativo = true
    AND ucc.ativo = true
$$;

-- Cartões vinculados ao usuário atual
CREATE OR REPLACE FUNCTION auth_cartoes_usuario()
RETURNS SETOF UUID LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT uc.cartao_id
  FROM usuario_cartoes uc
  JOIN usuarios u ON u.id = uc.usuario_id
  WHERE u.auth_user_id = auth.uid()
    AND u.ativo = true
    AND uc.ativo = true
$$;

-- ============================================================
-- Storage bucket para anexos
-- Execute após criar o bucket via Dashboard ou via SQL abaixo
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'despesas-anexos',
  'despesas-anexos',
  false,
  10485760,
  ARRAY['application/pdf','image/jpeg','image/jpg','image/png','image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Políticas de storage
CREATE POLICY "storage_select_auth" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'despesas-anexos');

CREATE POLICY "storage_insert_auth" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'despesas-anexos');

CREATE POLICY "storage_delete_owner" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'despesas-anexos'
    AND (auth_is_admin() OR owner = auth.uid())
  );
