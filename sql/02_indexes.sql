-- ============================================================
-- 02_indexes.sql  –  Índices e constraints adicionais
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_usuarios_auth_user_id    ON usuarios(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_email           ON usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_perfil          ON usuarios(perfil);
CREATE INDEX IF NOT EXISTS idx_usuarios_ativo           ON usuarios(ativo);

CREATE INDEX IF NOT EXISTS idx_ucc_usuario_id           ON usuario_centros_custo(usuario_id);
CREATE INDEX IF NOT EXISTS idx_ucc_centro_custo_id      ON usuario_centros_custo(centro_custo_id);
CREATE INDEX IF NOT EXISTS idx_ucc_papel                ON usuario_centros_custo(papel_no_centro);
CREATE INDEX IF NOT EXISTS idx_ucc_ativo                ON usuario_centros_custo(ativo);

CREATE INDEX IF NOT EXISTS idx_uc_usuario_id            ON usuario_cartoes(usuario_id);
CREATE INDEX IF NOT EXISTS idx_uc_cartao_id             ON usuario_cartoes(cartao_id);
CREATE INDEX IF NOT EXISTS idx_uc_ativo                 ON usuario_cartoes(ativo);

CREATE INDEX IF NOT EXISTS idx_despesas_usuario_id      ON despesas(usuario_id);
CREATE INDEX IF NOT EXISTS idx_despesas_cartao_id       ON despesas(cartao_id);
CREATE INDEX IF NOT EXISTS idx_despesas_centro_custo_id ON despesas(centro_custo_id);
CREATE INDEX IF NOT EXISTS idx_despesas_conta_id        ON despesas(conta_despesa_id);
CREATE INDEX IF NOT EXISTS idx_despesas_status          ON despesas(status);
CREATE INDEX IF NOT EXISTS idx_despesas_competencia     ON despesas(competencia);
CREATE INDEX IF NOT EXISTS idx_despesas_data_despesa    ON despesas(data_despesa);

CREATE INDEX IF NOT EXISTS idx_anexos_despesa_id        ON despesa_anexos(despesa_id);
CREATE INDEX IF NOT EXISTS idx_anexos_usuario_id        ON despesa_anexos(uploaded_by_usuario_id);
