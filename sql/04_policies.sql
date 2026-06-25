-- ============================================================
-- 04_policies.sql  –  Políticas RLS por tabela
-- ============================================================

-- ============================================================
-- centros_custo
-- ============================================================
CREATE POLICY "cc_select" ON centros_custo
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "cc_insert" ON centros_custo
  FOR INSERT TO authenticated WITH CHECK (auth_is_admin());

CREATE POLICY "cc_update" ON centros_custo
  FOR UPDATE TO authenticated
  USING (auth_is_admin()) WITH CHECK (auth_is_admin());

-- ============================================================
-- contas_despesa
-- ============================================================
CREATE POLICY "cd_select" ON contas_despesa
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "cd_insert" ON contas_despesa
  FOR INSERT TO authenticated WITH CHECK (auth_is_admin());

CREATE POLICY "cd_update" ON contas_despesa
  FOR UPDATE TO authenticated
  USING (auth_is_admin()) WITH CHECK (auth_is_admin());

-- ============================================================
-- cartoes_credito
-- ============================================================
CREATE POLICY "cart_select" ON cartoes_credito
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "cart_insert" ON cartoes_credito
  FOR INSERT TO authenticated WITH CHECK (auth_is_admin());

CREATE POLICY "cart_update" ON cartoes_credito
  FOR UPDATE TO authenticated
  USING (auth_is_admin()) WITH CHECK (auth_is_admin());

-- ============================================================
-- usuarios
-- SELECT: próprio | ADMIN: todos | GESTOR: membros dos seus centros
-- ============================================================
CREATE POLICY "usr_select" ON usuarios
  FOR SELECT TO authenticated
  USING (
    auth_user_id = auth.uid()
    OR auth_is_admin()
    OR (
      auth_is_gestor_or_admin()
      AND id IN (
        SELECT ucc.usuario_id FROM usuario_centros_custo ucc
        WHERE ucc.centro_custo_id IN (SELECT auth_centros_gestor())
          AND ucc.ativo = true
      )
    )
  );

-- UPDATE: próprio usuário atualiza seus próprios campos de login
CREATE POLICY "usr_update_self" ON usuarios
  FOR UPDATE TO authenticated
  USING (auth_user_id = auth.uid())
  WITH CHECK (auth_user_id = auth.uid());

-- ADMIN atualiza qualquer usuário
CREATE POLICY "usr_update_admin" ON usuarios
  FOR UPDATE TO authenticated
  USING (auth_is_admin()) WITH CHECK (auth_is_admin());

-- INSERT é feito exclusivamente pela Edge Function via service_role
-- (service_role bypassa RLS por padrão)

-- ============================================================
-- usuario_centros_custo
-- ============================================================
CREATE POLICY "ucc_select" ON usuario_centros_custo
  FOR SELECT TO authenticated
  USING (
    auth_is_admin()
    OR usuario_id = auth_usuario_id()
    OR (
      auth_is_gestor_or_admin()
      AND centro_custo_id IN (SELECT auth_centros_gestor())
    )
  );

CREATE POLICY "ucc_insert" ON usuario_centros_custo
  FOR INSERT TO authenticated WITH CHECK (auth_is_admin());

CREATE POLICY "ucc_update" ON usuario_centros_custo
  FOR UPDATE TO authenticated
  USING (auth_is_admin()) WITH CHECK (auth_is_admin());

CREATE POLICY "ucc_delete" ON usuario_centros_custo
  FOR DELETE TO authenticated USING (auth_is_admin());

-- ============================================================
-- usuario_cartoes
-- ============================================================
CREATE POLICY "uc_select" ON usuario_cartoes
  FOR SELECT TO authenticated
  USING (
    auth_is_admin()
    OR usuario_id = auth_usuario_id()
  );

CREATE POLICY "uc_insert" ON usuario_cartoes
  FOR INSERT TO authenticated WITH CHECK (auth_is_admin());

CREATE POLICY "uc_update" ON usuario_cartoes
  FOR UPDATE TO authenticated
  USING (auth_is_admin()) WITH CHECK (auth_is_admin());

CREATE POLICY "uc_delete" ON usuario_cartoes
  FOR DELETE TO authenticated USING (auth_is_admin());

-- ============================================================
-- despesas
-- SELECT: ADMIN=tudo | GESTOR=centros sob gestão | USUARIO=próprias
-- ============================================================
CREATE POLICY "desp_select" ON despesas
  FOR SELECT TO authenticated
  USING (
    auth_is_admin()
    OR (auth_perfil() = 'GESTOR' AND centro_custo_id IN (SELECT auth_centros_gestor()))
    OR usuario_id = auth_usuario_id()
  );

-- INSERT: usuário lança nas próprias competências + centros e cartões autorizados
CREATE POLICY "desp_insert" ON despesas
  FOR INSERT TO authenticated
  WITH CHECK (
    usuario_id = auth_usuario_id()
    AND centro_custo_id IN (SELECT auth_centros_usuario())
    AND cartao_id        IN (SELECT auth_cartoes_usuario())
  );

-- UPDATE: usuário edita RASCUNHO/REPROVADA próprias;
--         GESTOR aprova/reprova ENVIADAS dos seus centros; ADMIN tudo
CREATE POLICY "desp_update" ON despesas
  FOR UPDATE TO authenticated
  USING (
    auth_is_admin()
    OR (usuario_id = auth_usuario_id() AND status IN ('RASCUNHO','REPROVADA'))
    OR (auth_perfil() = 'GESTOR' AND centro_custo_id IN (SELECT auth_centros_gestor()) AND status = 'ENVIADA')
  )
  WITH CHECK (
    auth_is_admin()
    OR (usuario_id = auth_usuario_id())
    OR (auth_perfil() = 'GESTOR' AND centro_custo_id IN (SELECT auth_centros_gestor()))
  );

-- Sem DELETE físico de despesas

-- ============================================================
-- despesa_anexos
-- ============================================================
CREATE POLICY "anx_select" ON despesa_anexos
  FOR SELECT TO authenticated
  USING (
    auth_is_admin()
    OR uploaded_by_usuario_id = auth_usuario_id()
    OR despesa_id IN (SELECT id FROM despesas WHERE usuario_id = auth_usuario_id())
    OR despesa_id IN (
      SELECT id FROM despesas
      WHERE centro_custo_id IN (SELECT auth_centros_gestor())
    )
  );

-- INSERT: apenas o dono, na própria despesa em RASCUNHO ou REPROVADA
CREATE POLICY "anx_insert" ON despesa_anexos
  FOR INSERT TO authenticated
  WITH CHECK (
    uploaded_by_usuario_id = auth_usuario_id()
    AND despesa_id IN (
      SELECT id FROM despesas
      WHERE usuario_id = auth_usuario_id() AND status IN ('RASCUNHO','REPROVADA')
    )
  );

-- DELETE: dono (despesa em RASCUNHO/REPROVADA) ou ADMIN
CREATE POLICY "anx_delete" ON despesa_anexos
  FOR DELETE TO authenticated
  USING (
    auth_is_admin()
    OR (
      uploaded_by_usuario_id = auth_usuario_id()
      AND despesa_id IN (
        SELECT id FROM despesas
        WHERE usuario_id = auth_usuario_id() AND status IN ('RASCUNHO','REPROVADA')
      )
    )
  );
