// ============================================================
// js/utils.js – Utilitários de formatação, UI e exportação
// ============================================================

const Utils = {
  formatCurrency(v) {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(v ?? 0);
  },

  formatDate(s) {
    if (!s) return '–';
    // Datas tipo "YYYY-MM-DD" não têm fuso; forçar UTC para evitar off-by-one
    return new Date(s + 'T00:00:00').toLocaleDateString('pt-BR');
  },

  formatDateTime(s) {
    if (!s) return '–';
    return new Date(s).toLocaleString('pt-BR');
  },

  formatCompetencia(s) {
    if (!s) return '–';
    const [y, m] = s.split('-');
    return `${m}/${y}`;
  },

  formatBytes(b) {
    if (b < 1024) return b + ' B';
    if (b < 1048576) return (b / 1024).toFixed(1) + ' KB';
    return (b / 1048576).toFixed(1) + ' MB';
  },

  statusBadge(status) {
    const map = {
      RASCUNHO:  'bg-gray-100 text-gray-700',
      ENVIADA:   'bg-blue-100 text-blue-800',
      APROVADA:  'bg-green-100 text-green-800',
      REPROVADA: 'bg-red-100 text-red-800',
    };
    const cls = map[status] || 'bg-gray-100 text-gray-600';
    return `<span class="px-2.5 py-0.5 rounded-full text-xs font-medium ${cls}">${status}</span>`;
  },

  ativoBadge(ativo) {
    return ativo
      ? '<span class="px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">Ativo</span>'
      : '<span class="px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800">Inativo</span>';
  },

  toast(msg, type = 'success') {
    const colors = { success: 'bg-green-600', error: 'bg-red-600', warning: 'bg-yellow-600', info: 'bg-blue-600' };
    const el = document.createElement('div');
    el.className = `fixed bottom-5 right-5 z-[9999] px-5 py-3 rounded-lg text-white text-sm font-medium shadow-xl ${colors[type] || colors.info}`;
    el.textContent = msg;
    document.body.appendChild(el);
    setTimeout(() => { el.style.transition = 'opacity .3s'; el.style.opacity = '0'; setTimeout(() => el.remove(), 350); }, 3500);
  },

  exportCSV(rows, filename = 'relatorio.csv') {
    if (!rows?.length) { Utils.toast('Nenhum dado para exportar', 'warning'); return; }
    const headers = Object.keys(rows[0]);
    const lines = [
      headers.join(';'),
      ...rows.map(r => headers.map(h => `"${String(r[h] ?? '').replace(/"/g, '""')}"`).join(';')),
    ];
    const blob = new Blob(['﻿' + lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a'); a.href = url; a.download = filename; a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  },

  debounce(fn, ms = 300) {
    let t;
    return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
  },

  // Popula um <select> com opções de array
  populateSelect(el, items, valueKey, labelKey, placeholder = 'Selecione...') {
    el.innerHTML = `<option value="">${placeholder}</option>`;
    items.forEach(i => {
      const opt = document.createElement('option');
      opt.value = i[valueKey];
      opt.textContent = i[labelKey];
      el.appendChild(opt);
    });
  },

  // Render de tabela simples
  renderTable(tbodyEl, rows, renderRow) {
    if (!rows?.length) {
      tbodyEl.innerHTML = `<tr><td colspan="99" class="px-4 py-8 text-center text-sm text-slate-400">Nenhum registro encontrado.</td></tr>`;
      return;
    }
    tbodyEl.innerHTML = rows.map(renderRow).join('');
  },
};
