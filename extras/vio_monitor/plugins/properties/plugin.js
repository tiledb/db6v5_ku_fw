(function () {
  const ID = 'properties';
  let lastValues = {};

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function renderProperties(properties) {
    const wrap = document.getElementById('wrap-properties');
    if (!wrap) return;
    if (!properties || !properties.length) {
      wrap.innerHTML = '<p class="empty">No properties returned.</p>';
      return;
    }
    const sorted = properties.slice().sort((a, b) => a.name.localeCompare(b.name));
    let html = '<table class="data"><tr><th>Property</th><th>Value</th></tr>';
    for (const p of sorted) {
      const changed = lastValues[p.name] !== undefined && lastValues[p.name] !== p.value;
      lastValues[p.name] = p.value;
      html += '<tr class="' + (changed ? 'val-changed' : '') + '">' +
        '<td>' + esc(p.name) + '</td>' +
        '<td class="value" style="font-family:var(--mono);font-size:.74rem">' + esc(p.value) + '</td></tr>';
    }
    html += '</table>';
    wrap.innerHTML = html;
  }

  async function refresh() {
    if (!HWMonitor.state.targetOpen || !HWMonitor.state.device) return;
    try {
      const url = '/api/plugins/properties/data?device=' + encodeURIComponent(HWMonitor.state.device);
      const resp = await fetch(url);
      const j = await resp.json();
      if (!j.success) {
        const wrap = document.getElementById('wrap-properties');
        if (wrap && !wrap.querySelector('table')) {
          wrap.innerHTML = '<p class="empty">Failed to load properties.</p>';
        }
        return;
      }
      renderProperties(j.properties);
      const timeEl = document.getElementById('time-properties');
      if (timeEl) timeEl.textContent = 'Updated ' + new Date().toLocaleTimeString();
    } catch (e) {
      HWMonitor.setStatus('Properties refresh error: ' + e, true);
    }
  }

  function onDisconnect() {
    lastValues = {};
    const wrap = document.getElementById('wrap-properties');
    if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
  }

  function onDeviceChange() {
    lastValues = {};
    if (!HWMonitor.state.targetOpen) {
      const wrap = document.getElementById('wrap-properties');
      if (wrap) wrap.innerHTML = '<p class="empty">Open a target and select a device first.</p>';
      return;
    }
    if (!HWMonitor.state.device) {
      const wrap = document.getElementById('wrap-properties');
      if (wrap) wrap.innerHTML = '<p class="empty">Select a device to view properties.</p>';
      return;
    }
    refresh();
  }

  function onTabActivate() {
    if (!HWMonitor.state.targetOpen) {
      const wrap = document.getElementById('wrap-properties');
      if (wrap) wrap.innerHTML = '<p class="empty">Open a target and select a device first.</p>';
      return;
    }
    if (!HWMonitor.state.device) {
      const wrap = document.getElementById('wrap-properties');
      if (wrap) wrap.innerHTML = '<p class="empty">Select a device to view properties.</p>';
      return;
    }
    refresh();
  }

  HWMonitor.registerPlugin({
    id: ID,
    requiresDevice: true,
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
