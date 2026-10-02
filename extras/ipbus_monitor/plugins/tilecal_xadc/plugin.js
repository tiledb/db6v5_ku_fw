(function () {
  const ID = 'tilecal_xadc';

  function esc(s) { return HWMonitor.esc(s); }

  function fmt(value, digits, unit) {
    if (value == null || Number.isNaN(value)) return '—';
    return Number(value).toFixed(digits) + (unit ? ' ' + unit : '');
  }

  function cell(side) {
    const analog = fmt(side.analog, side.analog_unit === 'C' ? 1 : 1, side.analog_unit);
    const current = side.has_current ? fmt(side.current, 3, side.current_unit) : '—';
    return '<td class="num">' + esc(side.raw_hex) + '</td><td class="num">' + esc(analog) +
      '</td><td class="num">' + esc(current) + '</td>';
  }

  function render(data) {
    const wrap = document.getElementById('wrap-tilecal_xadc');
    let html = '<table class="data"><tr><th>Channel</th><th>DRP</th>' +
      '<th class="num">A raw</th><th class="num">A analog</th><th class="num">A scaled</th>' +
      '<th class="num">B raw</th><th class="num">B analog</th><th class="num">B scaled</th></tr>';
    for (const ch of data.channels) {
      html += '<tr><td>' + esc(ch.label) + '</td><td class="num">' + esc(ch.address_hex) + '</td>' +
        cell(ch.sides.A) + cell(ch.sides.B) + '</tr>';
    }
    html += '</table>';
    wrap.innerHTML = html;
  }

  async function refresh() {
    if (!HWMonitor.state.connected) return;
    const j = await HWMonitor.fetchJson('/api/plugins/tilecal_xadc/data');
    document.getElementById('time-tilecal_xadc').textContent = 'Updated ' + new Date().toLocaleTimeString();
    render(j);
  }

  function renderEmpty() {
    const wrap = document.getElementById('wrap-tilecal_xadc');
    if (!wrap) return;
    const md = Number(HWMonitor.state && HWMonitor.state.md) || 0;
    let html = '<p class="adcrd-legend">MD ' + (md + 1) +
      ' · xADC table (empty until Refresh).</p>' +
      '<table class="data"><tr><th>Channel</th><th>DRP</th>' +
      '<th class="num">A raw</th><th class="num">A analog</th><th class="num">A scaled</th>' +
      '<th class="num">B raw</th><th class="num">B analog</th><th class="num">B scaled</th></tr>' +
      '<tr><td colspan="8" class="empty">No readout yet.</td></tr></table>';
    wrap.innerHTML = html;
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_xadc'],
    refresh: refresh,
    refreshLabel: 'Reading xADC on side A and side B…',
    onInit() { renderEmpty(); },
    onMdChange() {
      renderEmpty();
      const timeEl = document.getElementById('time-tilecal_xadc');
      if (timeEl) timeEl.textContent = '';
    },
    onDisconnect() { renderEmpty(); },
  });
})();
