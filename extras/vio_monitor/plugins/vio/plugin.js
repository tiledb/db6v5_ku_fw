(function () {
  const ID = 'vio';
  let lastValues = {};

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function renderVios(vios) {
    const wrap = document.getElementById('wrap-vio');
    if (!wrap) return;
    if (!vios || !Object.keys(vios).length) {
      wrap.innerHTML = '<p class="empty">No VIO probes. Load an .ltx file or program a bitstream with VIO cores.</p>';
      return;
    }
    let html = '<table class="data"><tr><th>VIO core</th><th>Probe</th><th>Dir</th><th>Value</th><th>Activity</th></tr>';
    for (const [vio, probes] of Object.entries(vios)) {
      html += '<tr class="group"><td colspan="5">' + esc(vio) + '</td></tr>';
      for (const p of probes) {
        const key = vio + '|' + p.probe;
        const changed = lastValues[key] !== undefined && lastValues[key] !== p.value;
        lastValues[key] = p.value;
        const act = p.activity || '-';
        const actLive = act !== '-' && act !== '0' && act !== '0x0' && act !== '0X0';
        html += '<tr><td></td><td>' + esc(p.probe) + '</td>' +
          '<td class="dir-' + p.direction + '">' + p.direction + '</td>' +
          '<td class="' + (changed ? 'val-changed' : '') + '">' + esc(p.value) + '</td>' +
          '<td class="' + (actLive ? 'act-live' : 'act-idle') + '" title="Input probe transitions since last refresh">' +
          esc(act) + '</td></tr>';
      }
    }
    html += '</table>';
    wrap.innerHTML = html;
  }

  async function refresh() {
    if (!HWMonitor.state.targetOpen) return;
    try {
      const r = await fetch('/api/plugins/vio/data' + HWMonitor.deviceQuery());
      const j = await r.json();
      const timeEl = document.getElementById('time-vio');
      if (timeEl) timeEl.textContent = 'Updated ' + new Date().toLocaleTimeString();
      renderVios(j.vios);
    } catch (e) {
      HWMonitor.setStatus('VIO refresh error: ' + e, true);
    }
  }

  function onDisconnect() {
    lastValues = {};
    const wrap = document.getElementById('wrap-vio');
    if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
  }

  function onDeviceChange() {
    lastValues = {};
  }

  function onTabActivate() {}

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['vio'],
    onInit() {
      const btn = document.querySelector('[data-refresh="' + ID + '"]');
      if (btn) btn.addEventListener('click', refresh);
    },
    refresh,
    onDisconnect,
    onDeviceChange,
    onTabActivate,
  });
})();
