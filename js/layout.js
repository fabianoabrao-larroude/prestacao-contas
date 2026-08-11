// ============================================================
// js/layout.js – Sidebar, inicialização de página e nav
// ============================================================

const Layout = {
  navItems: [
    { href: 'home.html',             label: 'Home',            icon: 'M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6', roles: ['ADMIN','GESTOR','USUARIO'] },
    { href: 'despesas.html',         label: 'Minhas Despesas', icon: 'M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z', roles: ['ADMIN','GESTOR','USUARIO'] },
    { href: 'aprovacoes.html',       label: 'Aprovações',      icon: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z', roles: ['ADMIN','GESTOR','USUARIO'] },
    { href: 'mensagens.html',        label: 'Mensagens',       icon: 'M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z', roles: ['ADMIN','GESTOR','USUARIO'] },
    { href: 'relatorios.html',       label: 'Relatórios',      icon: 'M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z', roles: ['ADMIN','GESTOR'] },
    { href: 'dashboards.html',       label: 'Dashboards',      icon: 'M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z', roles: ['ADMIN','GESTOR'] },
    { separator: true, label: 'Cadastros', roles: ['ADMIN'] },
    { href: 'usuarios.html',         label: 'Usuários',        icon: 'M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z', roles: ['ADMIN'] },
    { href: 'centros-custo.html',    label: 'Centros de Custo',icon: 'M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4', roles: ['ADMIN'] },
    { href: 'contas-despesa.html',   label: 'Contas Despesa',  icon: 'M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z', roles: ['ADMIN'] },
    { href: 'cartoes.html',          label: 'Cartões',         icon: 'M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z', roles: ['ADMIN'] },
    { href: 'vinculos-usuarios.html',label: 'Vínculos',        icon: 'M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1', roles: ['ADMIN'] },
    { href: 'fornecedores.html',      label: 'Fornecedores',    icon: 'M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4', roles: ['ADMIN'] },
  ],

  // ── Exibir erro na tela (substitui o spinner) ──────────────
  // Chamado sempre que Layout.init() detecta um problema irrecuperável.
  showError(title, detail, hint = null) {
    // Garantir que o spinner suma independentemente do que aconteça
    document.getElementById('app-loading')?.classList.add('hidden');
    document.getElementById('app')?.classList.add('hidden');

    // Remover erro anterior, se existir
    document.getElementById('layout-error-screen')?.remove();

    const iconMap = {
      config:  '#f59e0b', // amarelo — configuração
      network: '#ef4444', // vermelho — rede/timeout
      db:      '#3b82f6', // azul — banco de dados
      auth:    '#8b5cf6', // roxo — autenticação
    };
    const iconColor = hint ? iconMap[hint] || '#ef4444' : '#ef4444';

    const el = document.createElement('div');
    el.id = 'layout-error-screen';
    el.style.cssText = 'position:fixed;inset:0;background:#f8fafc;display:flex;align-items:center;justify-content:center;z-index:9999;font-family:system-ui,sans-serif;padding:1rem';
    el.innerHTML = `
      <div style="max-width:480px;width:100%;text-align:center">
        <div style="width:56px;height:56px;border-radius:16px;background:${iconColor}20;display:flex;align-items:center;justify-content:center;margin:0 auto 20px">
          <svg width="28" height="28" fill="none" stroke="${iconColor}" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
          </svg>
        </div>
        <h2 style="font-size:1.125rem;font-weight:700;color:#0f172a;margin:0 0 8px">${title}</h2>
        <p style="font-size:.875rem;color:#475569;margin:0 0 20px;line-height:1.5">${detail}</p>
        ${hint === 'config' ? `
          <div style="background:#fefce8;border:1px solid #fde68a;border-radius:10px;padding:14px;text-align:left;margin-bottom:20px">
            <p style="font-size:.8rem;font-weight:600;color:#92400e;margin:0 0 8px">Como corrigir:</p>
            <ol style="font-size:.8rem;color:#78350f;margin:0;padding-left:18px;line-height:1.8">
              <li>Acesse o <strong>Supabase Dashboard</strong></li>
              <li>Vá em <strong>Settings → API</strong></li>
              <li>Copie <strong>Project URL</strong> → cole em <code>SUPABASE_URL</code></li>
              <li>Copie <strong>anon / public</strong> key → cole em <code>SUPABASE_ANON_KEY</code></li>
              <li>Salve o arquivo <strong>config.js</strong> e recarregue</li>
            </ol>
          </div>` : ''}
        ${hint === 'db' ? `
          <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;padding:14px;text-align:left;margin-bottom:20px">
            <p style="font-size:.8rem;font-weight:600;color:#1e3a8a;margin:0 0 8px">Como corrigir:</p>
            <ol style="font-size:.8rem;color:#1e40af;margin:0;padding-left:18px;line-height:1.8">
              <li>Abra o <strong>SQL Editor</strong> no Supabase Dashboard</li>
              <li>Execute os arquivos na ordem:<br>
                <code>sql/01_tables.sql</code><br>
                <code>sql/02_indexes.sql</code><br>
                <code>sql/03_rls.sql</code><br>
                <code>sql/04_policies.sql</code>
              </li>
              <li>Recarregue esta página</li>
            </ol>
          </div>` : ''}
        ${hint === 'auth' ? `
          <div style="background:#f5f3ff;border:1px solid #ddd6fe;border-radius:10px;padding:14px;text-align:left;margin-bottom:20px">
            <p style="font-size:.8rem;font-weight:600;color:#4c1d95;margin:0 0 8px">Como corrigir:</p>
            <p style="font-size:.8rem;color:#5b21b6;margin:0;line-height:1.8">
              Seu usuário Auth existe mas não tem registro na tabela <code>usuarios</code>.<br>
              Peça ao ADMIN para executar o INSERT de seed ou use o SQL Editor para criar o registro.
            </p>
          </div>` : ''}
        <a href="login.html" style="display:inline-block;padding:10px 24px;background:#1e40af;color:#fff;border-radius:8px;font-size:.875rem;font-weight:600;text-decoration:none">
          Voltar ao Login
        </a>
      </div>`;
    document.body.appendChild(el);
  },

  // ── Sidebar builder ────────────────────────────────────────
  buildSidebar(user, currentPage) {
    const navHTML = Layout.navItems
      .filter(item => item.roles.includes(user.perfil))
      .map(item => {
        if (item.separator) {
          return `<div class="pt-4 pb-1"><p class="text-xs font-semibold text-slate-500 uppercase tracking-wider px-3">${item.label}</p></div>`;
        }
        const isActive = currentPage && item.href.includes(currentPage);
        const cls = isActive
          ? 'flex items-center gap-3 px-3 py-2 rounded-lg bg-blue-600 text-white text-sm font-medium'
          : 'flex items-center gap-3 px-3 py-2 rounded-lg text-slate-300 hover:bg-slate-800 hover:text-white text-sm transition-colors';
        const badgeId = item.href === 'aprovacoes.html' ? ' id="badge-aprovacoes"'
          : item.href === 'mensagens.html' ? ' id="badge-mensagens"' : '';
        return `
          <a href="${item.href}" class="${cls}">
            <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${item.icon}"/>
            </svg>
            ${item.label}
            <span${badgeId} class="hidden ml-auto min-w-[1.25rem] h-5 px-1.5 rounded-full bg-red-500 text-white text-xs font-semibold flex items-center justify-center"></span>
          </a>`;
      }).join('');

    const initial = (user.nome || '?')[0].toUpperCase();

    return `
      <aside class="w-64 bg-slate-900 flex flex-col flex-shrink-0">
        <div class="p-4 border-b border-slate-700">
          <div class="flex items-center gap-3">
            <div class="w-8 h-8 bg-blue-500 rounded-lg flex items-center justify-center flex-shrink-0">
              <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 11h.01M12 11h.01M15 11h.01M4 19h16a2 2 0 002-2V7a2 2 0 00-2-2H4a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
            </div>
            <div>
              <p class="text-white text-sm font-semibold leading-tight">Prestação de Contas</p>
              <p class="text-slate-400 text-xs">Sistema Corporativo</p>
            </div>
          </div>
        </div>
        <nav class="flex-1 p-3 space-y-0.5 overflow-y-auto">${navHTML}</nav>
        <div class="p-4 border-t border-slate-700">
          <div class="flex items-center gap-3">
            <div class="w-8 h-8 bg-slate-600 rounded-full flex items-center justify-center flex-shrink-0">
              <span class="text-xs text-white font-semibold">${initial}</span>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm text-white font-medium truncate">${user.nome}</p>
              <p class="text-xs text-slate-400">${user.perfil}</p>
            </div>
            <button onclick="Auth.logout()" title="Sair" class="text-slate-400 hover:text-white transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/>
              </svg>
            </button>
          </div>
        </div>
      </aside>`;
  },

  // ── Notificações do navegador (Web Notification API) ───────
  // Só avisa sobre chegadas NOVAS, nunca sobre a contagem que já
  // existia. Guardado em localStorage (não só em memória) para
  // sobreviver a recarregar a página — senão todo F5 reseta a
  // referência e a próxima checagem nunca "aumenta" de verdade.
  _chaveContagem(user, tipo) {
    return `prestacontas_alerta_${tipo}_${user.id}`;
  },

  _lerContagemAnterior(user, tipo) {
    const v = localStorage.getItem(Layout._chaveContagem(user, tipo));
    return v === null ? null : parseInt(v, 10);
  },

  _salvarContagem(user, tipo, count) {
    localStorage.setItem(Layout._chaveContagem(user, tipo), String(count));
  },

  pedirPermissaoNotificacao() {
    if (!('Notification' in window)) return;
    if (Notification.permission === 'default') {
      Notification.requestPermission();
    }
  },

  notificar(titulo, corpo, url) {
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    // tag único por disparo — tag repetida faz o navegador substituir a
    // notificação anterior em silêncio, sem alertar de novo
    const n = new Notification(`PrestaContas · ${titulo}`, { body: corpo, tag: `${url}-${Date.now()}` });
    n.onclick = () => {
      window.focus();
      window.location.href = url;
      n.close();
    };
  },

  // ── Badge de aprovações realmente acionáveis pelo usuário ──
  async atualizarBadgeAprovacoes(user) {
    const badge = document.getElementById('badge-aprovacoes');
    if (!badge) return;

    const [{ data: ucc }, { data: cart }] = await Promise.all([
      supabase.from('usuario_centros_custo')
        .select('centro_custo_id')
        .eq('usuario_id', user.id)
        .eq('papel_no_centro', 'GESTOR')
        .eq('ativo', true),
      supabase.from('cartoes_credito')
        .select('id')
        .eq('aprovador_usuario_id', user.id),
    ]);
    const centros = (ucc || []).map(r => r.centro_custo_id);
    const cartoes = (cart || []).map(r => r.id);

    badge.classList.add('hidden'); // reseta antes de recalcular (polling pode zerar a contagem)

    if (!centros.length && !cartoes.length) return; // sem alçada nenhuma, sem badge (inclui ADMIN puro)

    const { data: pendentes } = await supabase.from('despesas')
      .select('centro_custo_id, cartao_id, aprovado_por_usuario_id, aprovado_cartao_por_usuario_id')
      .eq('status', 'ENVIADA')
      .neq('usuario_id', user.id);

    const count = (pendentes || []).filter(d =>
      (centros.includes(d.centro_custo_id) && !d.aprovado_por_usuario_id)
      || (cartoes.includes(d.cartao_id) && !d.aprovado_cartao_por_usuario_id)
    ).length;

    if (count > 0) {
      badge.textContent = count > 99 ? '99+' : String(count);
      badge.classList.remove('hidden');
    }

    const anterior = Layout._lerContagemAnterior(user, 'aprovacoes');
    if (anterior !== null && count > anterior) {
      Layout.notificar(
        'Nova despesa para aprovar',
        `Você tem ${count} despesa(s) aguardando sua aprovação.`,
        'aprovacoes.html'
      );
    }
    Layout._salvarContagem(user, 'aprovacoes', count);
  },

  // ── Badge de mensagens não lidas endereçadas ao usuário ────
  async atualizarBadgeMensagens(user) {
    const badge = document.getElementById('badge-mensagens');
    if (!badge) return;

    badge.classList.add('hidden'); // reseta antes de recalcular (polling pode zerar a contagem)

    const { count } = await supabase.from('despesa_mensagens')
      .select('id', { count: 'exact', head: true })
      .eq('destinatario_usuario_id', user.id)
      .is('lido_em', null);

    if (count > 0) {
      badge.textContent = count > 99 ? '99+' : String(count);
      badge.classList.remove('hidden');
    }

    const anterior = Layout._lerContagemAnterior(user, 'mensagens');
    if (anterior !== null && count > anterior) {
      Layout.notificar(
        'Nova mensagem',
        `Você tem ${count} mensagem(ns) não lida(s).`,
        'mensagens.html'
      );
    }
    Layout._salvarContagem(user, 'mensagens', count);
  },

  // ── Ponto de entrada principal ─────────────────────────────
  // Toda página autenticada chama Layout.init() no seu script.
  // Retorna o usuário operacional ou null (após mostrar erro na tela).
  async init(currentPage, allowedRoles = ['ADMIN','GESTOR','USUARIO']) {

    // 1. Validar config.js antes de qualquer chamada de rede
    const configCheck = validateAppConfig();
    if (!configCheck.valid) {
      console.error('[Layout.init] Configuração inválida:', configCheck.reason);
      Layout.showError(
        'Configuração incompleta',
        configCheck.reason,
        'config'
      );
      return null;
    }

    try {
      // 2. Verificar sessão (com timeout)
      const session = await Auth.requireAuth();
      if (!session) return null; // redirecionou para login.html

      // 3. Carregar usuário operacional (com timeout)
      const user = await Auth.getCurrentUser();

      // 4. Tratar ausência de usuário na tabela usuarios
      if (!user) {
        Layout.showError(
          'Perfil não encontrado',
          'Sua conta está autenticada, mas não tem um registro na tabela de usuários do sistema.',
          'auth'
        );
        return null;
      }

      // 5. Verificar perfil permitido para esta página
      if (!allowedRoles.includes(user.perfil)) {
        Layout.showError(
          'Acesso não autorizado',
          `Seu perfil (${user.perfil}) não tem permissão para acessar esta página.`,
          'auth'
        );
        return null;
      }

      // 6. Montar sidebar e exibir app
      const sidebar = document.getElementById('sidebar-container');
      if (sidebar) sidebar.innerHTML = Layout.buildSidebar(user, currentPage);

      document.getElementById('app-loading')?.classList.add('hidden');
      document.getElementById('app')?.classList.remove('hidden');

      // Badge de despesas realmente acionáveis pelo usuário — não é a
      // fila inteira visível (RLS), é só o que falta ELE aprovar.
      // ADMIN é analista do processo e não tem alçada de aprovação, então
      // só conta se ele também for gestor/aprovador designado em algo.
      Layout.pedirPermissaoNotificacao();
      Layout.atualizarBadgeAprovacoes(user);
      Layout.atualizarBadgeMensagens(user);

      // Atualização periódica dos alertas (a cada 60s), enquanto a aba
      // estiver aberta — evita badge ficar parado até a próxima navegação.
      clearInterval(Layout._alertasInterval);
      Layout._alertasInterval = setInterval(() => {
        Layout.atualizarBadgeAprovacoes(user);
        Layout.atualizarBadgeMensagens(user);
      }, 60000);

      // Atualizar ultimo_login de forma assíncrona (fire-and-forget)
      supabase.from('usuarios')
        .update({ ultimo_login_em: new Date().toISOString() })
        .eq('id', user.id)
        .then(() => {});

      return user;

    } catch (err) {
      console.error('[Layout.init] Erro:', err.message);

      // Erros com causa conhecida → mensagem específica
      if (err.message === 'CONFIG_INVALID') {
        Layout.showError(
          'Configuração inválida',
          'O cliente Supabase não foi inicializado. Verifique config.js.',
          'config'
        );
        return null;
      }

      if (err.message === 'DB_TABLE_MISSING') {
        Layout.showError(
          'Banco de dados não configurado',
          'As tabelas do sistema ainda não foram criadas. Execute os arquivos SQL no Supabase Dashboard.',
          'db'
        );
        return null;
      }

      if (err.message === 'DB_USER_NOT_FOUND') {
        Layout.showError(
          'Perfil não encontrado',
          'Sua conta Auth existe, mas não há registro correspondente na tabela de usuários. Contate o administrador.',
          'auth'
        );
        return null;
      }

      // Timeout ou erro de rede genérico
      if (err.message.startsWith('Timeout:')) {
        Layout.showError(
          'Servidor não respondeu',
          `A conexão com o Supabase demorou mais de ${SUPABASE_TIMEOUT_MS / 1000} segundos. Verifique sua internet e se o SUPABASE_URL está correto.`,
          'network'
        );
        return null;
      }

      // Qualquer outro erro inesperado
      Layout.showError(
        'Erro inesperado',
        `Não foi possível carregar a página: ${err.message}`,
        'network'
      );
      return null;
    }
  },
};
