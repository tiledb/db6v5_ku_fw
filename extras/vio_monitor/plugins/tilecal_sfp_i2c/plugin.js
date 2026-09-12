(function () {
  const ID = 'tilecal_sfp_i2c';
  let lastTable = {};

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function renderStatus(data) {
    const el = document.getElementById('status-tilecal_sfp_i2c');
    if (!el) return;
    if (!data || !data.table) {
      el.textContent = '';
      el.classList.remove('warn');
      return;
    }
    const n = data.table.read_count || 0;
    el.textContent = n + ' reads · addr 0x00–0x' +
      (data.table.max_addr || 127).toString(16).toUpperCase();
    el.classList.toggle('warn', !!(data.errors && data.errors.length));
  }

  function renderProbes(probes, errors) {
    let html = '';
    if (errors && errors.length) {
      html += '<div class="sfp-i2c-errors">' +
        errors.map(e => esc(e)).join('<br>') + '</div>';
    }
    if (!probes) return html;
    const lines = [];
    for (const role of ['addr', 'data']) {
      for (const side of ['0', '1']) {
        const name = probes[role] && probes[role][side];
        if (name) {
          lines.push((role === 'addr' ? 'addr' : 'data') + ' SFP+' + side + ': ' + name);
        }
      }
    }
    if (lines.length) {
      html += '<div class="sfp-i2c-probes">' + lines.map(esc).join('<br>') + '</div>';
    }
    return html;
  }

  function renderTable(data) {
    const wrap = document.getElementById('wrap-tilecal_sfp_i2c');
    if (!wrap) return;
    const table = data && data.table;
    if (!table || !table.entries || !table.entries.length) {
      wrap.innerHTML = '<p class="empty">No register data returned.</p>' +
        renderProbes(data && data.probes, data && data.errors);
      renderStatus(null);
      return;
    }

    let html = renderProbes(data.probes, data.errors);
    html += '<p class="sfp-i2c-legend">' +
      'Per address: <code>set_property OUTPUT_VALUE</code> (2-digit hex) → ' +
      '<code>commit_hw_vio</code> → <code>refresh_hw_vio</code> → read ' +
      '<code>s_sfp_ku_mgt[sfp_tx_register][x]</code>. Configure probe names in ⚙.</p>';

    html += '<table class="data sfp-i2c-reg"><tr>' +
      '<th>Address</th>' +
      '<th class="num">SFP+ 0</th><th class="num">SFP+ 0 bin</th>' +
      '<th class="num">SFP+ 1</th><th class="num">SFP+ 1 bin</th>' +
      '</tr>';

    for (const row of table.entries) {
      const s0 = row.sides['0'];
      const s1 = row.sides['1'];
      const changed = lastTable[row.address_hex] !== undefined &&
        (lastTable[row.address_hex].s0 !== s0.raw_hex || lastTable[row.address_hex].s1 !== s1.raw_hex);
      lastTable[row.address_hex] = { s0: s0.raw_hex, s1: s1.raw_hex };

      const nonzero = (s0.raw && s0.raw !== 0) || (s1.raw && s1.raw !== 0);
      html += '<tr class="' + (nonzero ? 'nonzero ' : '') + (changed ? 'val-changed' : '') + '">' +
        '<td class="num">' + esc(row.address_hex) + '</td>' +
        '<td class="num">' + esc(s0.raw_hex) + '</td>' +
        '<td class="num">' + esc(s0.raw_bin) + '</td>' +
        '<td class="num">' + esc(s1.raw_hex) + '</td>' +
        '<td class="num">' + esc(s1.raw_bin) + '</td>' +
        '</tr>';
    }
    html += '</table>';
    wrap.innerHTML = html;
    renderStatus(data);
  }

  async function refresh() {
    if (!HWMonitor.state.targetOpen || !HWMonitor.state.device) {
      HWMonitor.setStatus('Select a device before scanning SFP+ I2C registers', true);
      return;
    }
    const maxSel = document.getElementById('sfpI2cMaxAddr');
    const maxAddr = maxSel ? maxSel.value : '127';
    const q = HWMonitor.deviceQuery();
    const sep = q ? '&' : '?';
    try {
      const r = await fetch(
        '/api/plugins/tilecal_sfp_i2c/data' + q + sep + 'max_addr=' + encodeURIComponent(maxAddr)
      );
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || ('HTTP ' + r.status));
      const timeEl = document.getElementById('time-tilecal_sfp_i2c');
      if (timeEl) {
        timeEl.textContent = 'Scanned ' + new Date().toLocaleTimeString();
      }
      renderTable(j);
      if (j.errors && j.errors.length) {
        HWMonitor.setStatus('SFP+ I2C scan partial: ' + j.errors.join('; '), true);
      } else {
        HWMonitor.setStatus('SFP+ I2C scan complete');
      }
    } catch (e) {
      HWMonitor.setStatus('TileCal SFP+ I2C error: ' + e, true);
    }
  }

  function onDisconnect() {
    lastTable = {};
    renderStatus(null);
    const wrap = document.getElementById('wrap-tilecal_sfp_i2c');
    if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
  }

  function onDeviceChange() {
    lastTable = {};
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_sfp_i2c'],
    onInit() {},
    refresh,
    onDisconnect,
    onDeviceChange,
    onTabActivate() {},
  });
})();
