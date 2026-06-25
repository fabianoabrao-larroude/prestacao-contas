# Guia de Configuração – Prestação de Contas MVP

## Pré-requisitos
- Conta no [Supabase](https://supabase.com) (plano Free é suficiente)
- Node.js 18+ e Supabase CLI (para deploy da Edge Function)
- Navegador moderno

---

## 1. Criar o Projeto no Supabase

1. Acesse https://supabase.com/dashboard → **New project**
2. Defina nome, senha do banco e região
3. Aguarde a inicialização (~2 min)

---

## 2. Executar o SQL

No **SQL Editor** do Dashboard, execute os arquivos na ordem:

```
sql/01_tables.sql
sql/02_indexes.sql
sql/03_rls.sql      ← inclui criação do bucket
sql/04_policies.sql
sql/05_seed.sql     ← dados de exemplo
```

Execute um arquivo por vez. Se ocorrer erro de bucket já existente, ignore.

---

## 3. Configurar o Storage Bucket (alternativa manual)

Caso o bucket não seja criado via SQL:

1. Dashboard → **Storage** → **New bucket**
2. Nome: `despesas-anexos`
3. **Public bucket**: NÃO (manter privado)
4. File size limit: `10485760` (10 MB)
5. Allowed MIME types:
   ```
   application/pdf, image/jpeg, image/jpg, image/png, image/webp
   ```

---

## 4. Configurar Autenticação

1. Dashboard → **Authentication** → **Settings** → **Email**
2. Habilite **Enable email confirmations** → `OFF` (para testes)  
   OU deixe ON se quiser confirmação em produção.
3. Em **URL Configuration**:
   - **Site URL**: URL onde os arquivos estão servidos  
     (ex.: `http://127.0.0.1:5500` para Live Server local)
   - **Redirect URLs**: adicione a mesma URL + `/auth-callback.html`
     ```
     http://127.0.0.1:5500/auth-callback.html
     ```
4. Em **Email Templates** → **Invite user**, verifique se o link de convite
   aponta para `{{ .SiteURL }}/auth-callback.html`.

---

## 5. Criar o Usuário ADMIN Inicial

Como não há cadastro público, o primeiro ADMIN deve ser criado manualmente:

### Opção A — via Dashboard
1. Dashboard → **Authentication** → **Users** → **Invite user**
2. Informe o e-mail do admin (ex.: `admin@empresa.com`)
3. O admin receberá e-mail para definir senha
4. Após aceitar o convite, execute no SQL Editor:

```sql
INSERT INTO usuarios (auth_user_id, codigo, nome, email, perfil, status_acesso, ativo)
SELECT
  id,               -- UUID do auth.users criado pelo convite
  'USR001',
  'Administrador',
  'admin@empresa.com',
  'ADMIN',
  'ATIVO',
  true
FROM auth.users
WHERE email = 'admin@empresa.com';
```

### Opção B — via SQL (cria usuário com senha direta, apenas para dev)
```sql
-- Inserir usuário no auth (apenas ambiente de desenvolvimento)
SELECT supabase_admin.create_user(
  '{"email": "admin@empresa.com", "password": "TROQUE_POR_UMA_SENHA_FORTE", "email_confirm": true}'::jsonb
);
-- Depois execute o INSERT em usuarios acima
```

---

## 6. Deploy da Edge Function

### Instalar Supabase CLI
```bash
npm install -g supabase
```

### Login e link ao projeto
```bash
supabase login
supabase link --project-ref SEU_PROJECT_ID
```

### Deploy
```bash
supabase functions deploy admin-create-user
```

### Verificar no Dashboard
Dashboard → **Edge Functions** → `admin-create-user` deve aparecer como **Active**.

---

## 7. Configurar config.js

Abra `config.js` e substitua os placeholders:

```javascript
const SUPABASE_URL      = 'https://SEU_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'SUA_ANON_KEY';
```

Onde encontrar:
- Dashboard → **Settings** → **API**
- **Project URL** → `SUPABASE_URL`
- **anon / public** key → `SUPABASE_ANON_KEY`

> ⚠️ NUNCA coloque a `service_role` key no frontend.

---

## 8. Rodar Localmente

### Opção A — VS Code Live Server (recomendado)
1. Instale a extensão **Live Server**
2. Clique com botão direito em `login.html` → **Open with Live Server**
3. URL padrão: `http://127.0.0.1:5500/login.html`

### Opção B — Python HTTP Server
```bash
cd C:\supabase
python -m http.server 5500
# Acesse: http://localhost:5500/login.html
```

### Opção C — Node http-server
```bash
npx http-server . -p 5500
# Acesse: http://localhost:5500/login.html
```

---

## 9. Configurar os Redirect URLs do Supabase Auth

Para o convite por e-mail funcionar corretamente:

1. Dashboard → **Authentication** → **URL Configuration**
2. **Site URL**: `http://127.0.0.1:5500` (ou seu domínio em produção)
3. **Additional Redirect URLs**:
   ```
   http://127.0.0.1:5500/auth-callback.html
   ```

---

## 10. Seed de Exemplo — Fluxo Completo

Após criar o ADMIN e fazer login:

1. **Acesse** `usuarios.html` → Convidar Usuário
   - Crie 1 GESTOR e 2 USUARIOs via interface
2. **Acesse** `vinculos-usuarios.html` → vincule cada usuário a centros e cartões
3. Faça login como USUARIO → `despesa-form.html` → crie uma despesa com anexo
4. Faça login como GESTOR → `aprovacoes.html` → aprove ou reprove
5. Acesse `relatorios.html` → filtre e exporte CSV

---

## Estrutura de Arquivos

```
C:\supabase\
├── config.js                          ← URL + anon key do Supabase
├── login.html
├── auth-callback.html                 ← Primeiro acesso / definir senha
├── dashboard.html
├── usuarios.html
├── centros-custo.html
├── contas-despesa.html
├── cartoes.html
├── vinculos-usuarios.html
├── despesas.html
├── despesa-form.html
├── aprovacoes.html
├── relatorios.html
├── js/
│   ├── auth.js                        ← Gerenciamento de sessão
│   ├── layout.js                      ← Sidebar + inicialização
│   └── utils.js                       ← Formatadores, CSV, toast
├── sql/
│   ├── 01_tables.sql
│   ├── 02_indexes.sql
│   ├── 03_rls.sql
│   ├── 04_policies.sql
│   └── 05_seed.sql
└── supabase/
    └── functions/
        └── admin-create-user/
            └── index.ts               ← Edge Function (TypeScript)
```

---

## Checklist Final de Teste

### Autenticação
- [ ] Login com e-mail e senha funciona
- [ ] Login com credenciais erradas mostra mensagem de erro
- [ ] Usuário sem sessão é redirecionado para `login.html`
- [ ] Convite por e-mail é enviado ao criar usuário
- [ ] Usuário convidado define senha em `auth-callback.html`
- [ ] Logout funciona e redireciona para login

### Controle de Acesso (RLS)
- [ ] ADMIN vê sidebar com Cadastros
- [ ] GESTOR não vê menu de Cadastros
- [ ] USUARIO não vê Aprovações nem Relatórios
- [ ] Consulta direta ao Supabase via console com anon key respeita RLS

### Cadastros Mestres (ADMIN)
- [ ] Criar centro de custo
- [ ] Editar centro de custo (ativar/inativar)
- [ ] Criar conta de despesa
- [ ] Criar cartão (sem número completo)
- [ ] Vincular usuário a centros e cartões em `vinculos-usuarios.html`

### Despesas (USUARIO)
- [ ] Só vê cartões e centros vinculados a ele nos selects
- [ ] Cria despesa → status RASCUNHO
- [ ] Faz upload de anexo (PDF ou imagem)
- [ ] Despesa sem anexo não pode ser enviada
- [ ] Despesa com anexo → status ENVIADA
- [ ] Pode editar despesa em RASCUNHO
- [ ] Não pode editar despesa ENVIADA/APROVADA

### Aprovações (GESTOR/ADMIN)
- [ ] GESTOR vê apenas despesas dos seus centros
- [ ] ADMIN vê todas as despesas
- [ ] Aprovar despesa → status APROVADA
- [ ] Reprovar sem motivo → erro
- [ ] Reprovar com motivo → status REPROVADA
- [ ] Usuário vê motivo de reprovação em `despesa-form.html`
- [ ] Usuário pode reenviar despesa reprovada

### Relatórios
- [ ] Relatório Geral lista despesas com filtros
- [ ] Relatório por Centro agrupa corretamente
- [ ] Relatório por Cartão funciona
- [ ] Relatório por Usuário funciona
- [ ] Relatório por Conta funciona
- [ ] Exportação CSV funciona e abre no Excel com acentos corretos

### Anexos
- [ ] Upload de PDF funciona
- [ ] Upload de JPG/PNG funciona
- [ ] Arquivo > 10 MB é rejeitado
- [ ] Mais de 5 anexos é rejeitado
- [ ] Download de anexo funciona
- [ ] Remoção de anexo funciona (despesa em RASCUNHO)

---

## Variáveis de Ambiente da Edge Function

A Edge Function usa automaticamente as variáveis injetadas pelo Supabase:
- `SUPABASE_URL` — URL do projeto
- `SUPABASE_ANON_KEY` — chave anon
- `SUPABASE_SERVICE_ROLE_KEY` — chave service_role (nunca exposta no frontend)

Não é necessário configurar manualmente.

---

## Produção

Para deploy em produção:
1. Hospede os arquivos HTML/JS/CSS em qualquer CDN estático
   (Netlify, Vercel static, Cloudflare Pages, S3+CloudFront)
2. Atualize **Site URL** e **Redirect URLs** no Supabase Auth para o domínio real
3. Habilite confirmação de e-mail em Authentication Settings
4. Revise as RLS policies antes de ir a ar
