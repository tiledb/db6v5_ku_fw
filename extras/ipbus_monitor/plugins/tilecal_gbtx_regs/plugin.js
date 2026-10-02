(function () {
  const ID = 'tilecal_gbtx_regs';

  function esc(s) { return HWMonitor.esc(s); }

  function parseRange(value) {
    const trigger = value.endsWith(':i2c');
    const range = trigger ? value.slice(0, -4) : value;
    const parts = range.split('-').map(Number);
    return { min: parts[0], max: parts[1], trigger: trigger };
  }

  function sideTable(sideId, entries, hideZero, hideMatch) {
    let html = '<table class="data"><tr>' +
      '<th>Address</th><th>Name</th><th>Block</th><th>Access</th><th>Description</th>' +
      '<th class="num">Actual</th><th class="num">Config</th>' +
      '<th>Match</th></tr>';
    let shown = 0;
    for (const row of entries) {
      const nonzero = row.actual.raw || row.config.raw;
      if (hideZero && !nonzero) continue;
      if (hideMatch && row.match) continue;
      shown += 1;
      const mismatch = !row.match;
      const tip = row.bit_tooltip ? ' title="' + esc(row.bit_tooltip) + '"' : '';
      const addrLabel = row.address_label || (row.address_hex + ' (' + row.address + ')');
      html += '<tr class="' + (mismatch ? 'nonzero' : '') + '">' +
        '<td class="num">' + esc(addrLabel) + '</td>' +
        '<td' + tip + '>' + esc(row.name || '') + '</td>' +
        '<td>' + esc(row.block || '') + '</td>' +
        '<td>' + esc(row.access || '') + '</td>' +
        '<td>' + esc(row.description || '') + '</td>' +
        '<td class="num" title="' + esc(row.actual.raw_bin) + '">' + esc(row.actual.raw_hex) + '</td>' +
        '<td class="num" title="' + esc(row.config.raw_bin) + '">' + esc(row.config.raw_hex) + '</td>' +
        '<td>' + (row.match ? 'yes' : 'NO') + '</td></tr>';
    }
    if (!shown) html += '<tr><td colspan="8">No rows in this filter.</td></tr>';
    html += '</table>';
    return '<div class="side-card side-' + sideId.toLowerCase() + '"><h3>Side ' + sideId + '</h3>' + html + '</div>';
  }

  function render(data) {
    const hideZero = document.getElementById('gbtxRegsHideZero').checked;
    const hideMatch = document.getElementById('gbtxRegsHideMatch').checked;
    const legend = data.spec
      ? '<p class="sfp-legend">' + esc(data.spec) +
        '. Hover register name for bit fields. Mismatches (actual ≠ config) are highlighted.</p>'
      : '';
    document.getElementById('wrap-tilecal_gbtx_regs').innerHTML =
      legend +
      '<div class="side-grid">' +
      sideTable('A', data.sides.A, hideZero, hideMatch) +
      sideTable('B', data.sides.B, hideZero, hideMatch) +
      '</div>';
  }

  let last = null;

  function rerender() {
    if (last) render(last);
  }

  async function refresh() {
    if (!HWMonitor.state.connected) return;
    const sel = parseRange(document.getElementById('gbtxRegsRange').value);
    const q = 'min_addr=' + encodeURIComponent(sel.min) +
      '&max_addr=' + encodeURIComponent(sel.max) +
      '&trigger_i2c=' + (sel.trigger ? '1' : '0');
    last = await HWMonitor.fetchJson('/api/plugins/tilecal_gbtx_regs/data?' + q);
    const trig = last.trigger_i2c ? (' · I2C wait ' + last.i2c_wait_s + 's') : ' · BRAM only';
    document.getElementById('time-tilecal_gbtx_regs').textContent =
      'Updated ' + new Date().toLocaleTimeString() +
      ' · ' + last.min_addr + '–' + last.max_addr + trig;
    render(last);
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_gbtx_regs'],
    refresh: refresh,
    refreshLabel: 'GBTx register scan (may trigger I2C first)…',
    onInit() {
      document.getElementById('gbtxRegsHideZero').addEventListener('change', rerender);
      document.getElementById('gbtxRegsHideMatch').addEventListener('change', rerender);
      const wrap = document.getElementById('wrap-tilecal_gbtx_regs');
      if (wrap) wrap.innerHTML = '<p class="empty">No readout yet. Status regs need an I2C-triggered scan.</p>';
    },
    onMdChange() {
      last = null;
      const wrap = document.getElementById('wrap-tilecal_gbtx_regs');
      if (wrap) wrap.innerHTML = '<p class="empty">No readout yet for this MD.</p>';
      const timeEl = document.getElementById('time-tilecal_gbtx_regs');
      if (timeEl) timeEl.textContent = '';
    },
    onDisconnect() {
      last = null;
      const wrap = document.getElementById('wrap-tilecal_gbtx_regs');
      if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
    },
  });
})();
