-- ============================================================
-- 05_seed.sql  –  Dados iniciais de exemplo
-- ============================================================

-- Centros de Custo
INSERT INTO centros_custo (codigo, nome) VALUES
  ('CC001', 'Comercial'),
  ('CC002', 'Tecnologia')
ON CONFLICT (codigo) DO NOTHING;

-- Contas de Despesa
INSERT INTO contas_despesa (codigo, nome) VALUES
  ('CD001', 'Alimentação e Refeições'),
  ('CD002', 'Transporte e Combustível'),
  ('CD003', 'Hospedagem e Viagens')
ON CONFLICT (codigo) DO NOTHING;

-- Cartões de Crédito
INSERT INTO cartoes_credito (codigo, nome, ultimos_4_digitos, bandeira) VALUES
  ('CART001', 'Mastercard Comercial',  '1234', 'Mastercard'),
  ('CART002', 'Visa Corporativo',      '5678', 'Visa')
ON CONFLICT (codigo) DO NOTHING;

-- ============================================================
-- ADMIN INICIAL
-- Instrução: crie o usuário admin@empresa.com via
--   Supabase Dashboard > Authentication > Users > Invite user
-- Depois execute o INSERT abaixo substituindo o UUID real:
-- ============================================================
-- INSERT INTO usuarios (auth_user_id, codigo, nome, email, perfil, status_acesso, ativo)
-- VALUES (
--   '<UUID_DO_AUTH_USER>',   -- substitua pelo id real
--   'USR001',
--   'Administrador',
--   'admin@empresa.com',
--   'ADMIN',
--   'ATIVO',
--   true
-- )
-- ON CONFLICT (codigo) DO NOTHING;

-- ============================================================
-- Após criar os demais usuários via interface, vincule-os:
-- Exemplo:
-- INSERT INTO usuario_centros_custo (usuario_id, centro_custo_id, papel_no_centro)
-- SELECT u.id, cc.id, 'GESTOR'
-- FROM usuarios u, centros_custo cc
-- WHERE u.email = 'gestor@empresa.com' AND cc.codigo = 'CC001';
--
-- INSERT INTO usuario_cartoes (usuario_id, cartao_id)
-- SELECT u.id, c.id
-- FROM usuarios u, cartoes_credito c
-- WHERE u.email = 'usuario1@empresa.com' AND c.codigo = 'CART001';
-- ============================================================
