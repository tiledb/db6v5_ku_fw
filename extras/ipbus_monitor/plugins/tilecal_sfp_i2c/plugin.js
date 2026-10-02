(function () {
  const ID = 'tilecal_sfp_i2c';

  function esc(s) { return HWMonitor.esc(s); }

  function sideTable(sideId, entries, hideZero) {
    let html = '<table class="data"><tr><th>Address</th><th class="num">SFP+0</th><th class="num">SFP+0 bin</th>' +
      '<th class="num">SFP+1</th><th class="num">SFP+1 bin</th></tr>';
    let shown = 0;
    for (const row of entries) {
      const nonzero = row.sfp0.raw || row.sfp1.raw;
      if (hideZero && !nonzero) continue;
      shown += 1;
      html += '<tr class="' + (nonzero ? 'nonzero' : '') + '"><td class="num">' + esc(row.address_hex) +
        '</td><td class="num">' + esc(row.sfp0.raw_hex) + '</td><td class="num">' + esc(row.sfp0.raw_bin) +
        '</td><td class="num">' + esc(row.sfp1.raw_hex) + '</td><td class="num">' + esc(row.sfp1.raw_bin) +
        '</td></tr>';
    }
    if (!shown) html += '<tr><td colspan="5">No non-zero bytes in this range.</td></tr>';
    html += '</table>';
    return '<div class="side-card side-' + sideId.toLowerCase() + '"><h3>Side ' + sideId + '</h3>' + html + '</div>';
  }

  function render(data) {
    const hide = document.getElementById('sfpI2cHideZero').checked;
    document.getElementById('wrap-tilecal_sfp_i2c').innerHTML =
      '<div class="side-grid">' + sideTable('A', data.sides.A, hide) + sideTable('B', data.sides.B, hide) + '</div>';
  }

  let last = null;

  async function refresh() {
    if (!HWMonitor.state.connected) return;
    const maxAddr = document.getElementById('sfpI2cMax').value;
    last = await HWMonitor.fetchJson('/api/plugins/tilecal_sfp_i2c/data?max_addr=' + encodeURIComponent(maxAddr));
    document.getElementById('time-tilecal_sfp_i2c').textContent =
      'Updated ' + new Date().toLocaleTimeString() + ' · 0x00–0x' + Number(last.max_addr).toString(16).toUpperCase();
    render(last);
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_sfp_i2c'],
    refresh: refresh,
    refreshLabel: 'Scanning SFP+ registers on side A and side B…',
    onInit() {
      document.getElementById('sfpI2cHideZero').addEventListener('change', function () {
        if (last) render(last);
      });
      const wrap = document.getElementById('wrap-tilecal_sfp_i2c');
      if (wrap) wrap.innerHTML = '<p class="empty">No readout yet. Refresh to scan SFP+ I2C on both sides.</p>';
    },
    onMdChange() {
      last = null;
      const wrap = document.getElementById('wrap-tilecal_sfp_i2c');
      if (wrap) wrap.innerHTML = '<p class="empty">No readout yet for this MD.</p>';
      const timeEl = document.getElementById('time-tilecal_sfp_i2c');
      if (timeEl) timeEl.textContent = '';
    },
    onDisconnect() {
      last = null;
      const wrap = document.getElementById('wrap-tilecal_sfp_i2c');
      if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
    },
  });
})();
