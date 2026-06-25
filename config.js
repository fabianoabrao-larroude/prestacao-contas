// ============================================================
// config.js – Configuração do Supabase
// ============================================================

const SUPABASE_URL = 'https://chqgrqhovhuhhdycboeb.supabase.co';

const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNocWdycWhvdmh1aGhkeWNib2ViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyNzEzNDQsImV4cCI6MjA5Nzg0NzM0NH0.hpf9MIQsavBd84uK5D01fbMJEC9bFOfQ5g0oeGra8k8';

const APP_BASE_URL = 'http://localhost:5500';

const FUNCTIONS_URL = `${SUPABASE_URL}/functions/v1`;

function validateAppConfig() {
  const PLACEHOLDERS_URL = ['SEU_PROJECT_ID', 'seu_project_id', 'YOUR_PROJECT'];
  const PLACEHOLDERS_KEY = ['SUA_ANON_KEY_AQUI', 'SUA_ANON_KEY', 'YOUR_ANON_KEY'];

  if (!SUPABASE_URL || typeof SUPABASE_URL !== 'string' || SUPABASE_URL.trim() === '') {
    return { valid: false, reason: 'SUPABASE_URL está vazia ou indefinida.' };
  }

  if (!SUPABASE_ANON_KEY || typeof SUPABASE_ANON_KEY !== 'string' || SUPABASE_ANON_KEY.trim() === '') {
    return { valid: false, reason: 'SUPABASE_ANON_KEY está vazia ou indefinida.' };
  }

  if (PLACEHOLDERS_URL.some(p => SUPABASE_URL.includes(p))) {
    return { valid: false, reason: 'SUPABASE_URL ainda contém valor de exemplo. Substitua pelo Project URL real.' };
  }

  if (PLACEHOLDERS_KEY.some(p => SUPABASE_ANON_KEY.includes(p))) {
    return { valid: false, reason: 'SUPABASE_ANON_KEY ainda contém valor de exemplo. Substitua pela chave anon real.' };
  }

  if (!SUPABASE_URL.startsWith('https://')) {
    return { valid: false, reason: 'SUPABASE_URL deve começar com https://.' };
  }

  if (SUPABASE_URL.includes('/rest/v1')) {
    return { valid: false, reason: 'SUPABASE_URL não deve conter /rest/v1. Use apenas https://PROJECT_ID.supabase.co.' };
  }

  return { valid: true, reason: null };
}

const _configCheck = validateAppConfig();

// A biblioteca carregada por CDN usa window.supabase.
// Guardamos a referência do SDK antes de criar o client.
const SupabaseSDK = window.supabase;

// Usar var evita conflito de redeclaração em escopo global com o SDK CDN.
var supabase = null;

if (_configCheck.valid) {
  if (!SupabaseSDK || typeof SupabaseSDK.createClient !== 'function') {
    console.error('[config.js] Supabase SDK não carregado. Verifique se o script CDN vem antes de config.js.');
    supabase = null;
  } else {
    supabase = SupabaseSDK.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true,
      },
    });
  }
} else {
  supabase = null;
  console.error('[config.js] Configuração inválida:', _configCheck.reason);
}