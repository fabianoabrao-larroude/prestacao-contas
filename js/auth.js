// ============================================================
// js/auth.js – Gerenciamento de autenticação e sessão
// ============================================================

// Tempo máximo de espera por qualquer chamada ao Supabase (ms).
const SUPABASE_TIMEOUT_MS = 8000;

// withTimeout(promise, ms)
// Rejeita a promise se ela não resolver dentro de `ms` milissegundos.
function withTimeout(promise, ms = SUPABASE_TIMEOUT_MS) {
  const timeout = new Promise((_, reject) =>
    setTimeout(() => reject(new Error(`Timeout: sem resposta do servidor após ${ms / 1000}s.`)), ms)
  );
  return Promise.race([promise, timeout]);
}

const Auth = {
  _currentUser: null,

  // Verifica se há sessão ativa.
  // Lança erro se supabase não estiver configurado ou timeout estourar.
  async requireAuth() {
    if (!supabase) {
      throw new Error('CONFIG_INVALID');
    }

    const { data: { session }, error } = await withTimeout(
      supabase.auth.getSession()
    );

    if (error) {
      console.error('[Auth.requireAuth] Erro ao buscar sessão:', error.message);
      throw new Error(`Erro de autenticação: ${error.message}`);
    }

    if (!session) {
      window.location.href = 'login.html';
      return null;
    }

    return session;
  },

  // Retorna o registro operacional do usuário autenticado da tabela `usuarios`.
  // Lança erro em caso de timeout ou falha de rede/banco.
  async getCurrentUser(force = false) {
    if (Auth._currentUser && !force) return Auth._currentUser;

    if (!supabase) throw new Error('CONFIG_INVALID');

    const { data: authData, error: authErr } = await withTimeout(
      supabase.auth.getUser()
    );

    if (authErr) {
      console.error('[Auth.getCurrentUser] Erro ao buscar auth.user:', authErr.message);
      throw new Error(`Erro ao identificar usuário: ${authErr.message}`);
    }

    const user = authData?.user;
    if (!user) return null;

    const { data, error: dbErr } = await withTimeout(
      supabase
        .from('usuarios')
        .select('*')
        .eq('auth_user_id', user.id)
        .single()
    );

    if (dbErr) {
      // Código 42P01 = tabela não existe (SQL não foi executado)
      if (dbErr.code === '42P01' || dbErr.message?.includes('does not exist')) {
        throw new Error('DB_TABLE_MISSING');
      }
      // PGRST116 = nenhum registro encontrado (usuário auth sem registro em usuarios)
      if (dbErr.code === 'PGRST116') {
        throw new Error('DB_USER_NOT_FOUND');
      }
      console.error('[Auth.getCurrentUser] Erro ao buscar usuário:', dbErr.message);
      throw new Error(`Erro ao carregar perfil: ${dbErr.message}`);
    }

    Auth._currentUser = data;
    return data;
  },

  async logout() {
    Auth._currentUser = null;
    if (supabase) await supabase.auth.signOut();
    window.location.href = 'login.html';
  },

  canAccess(user, roles) {
    return roles.includes(user.perfil);
  },
};
