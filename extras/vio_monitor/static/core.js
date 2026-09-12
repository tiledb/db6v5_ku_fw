/* HW Monitor core framework — connection, tree, plugin loader, polling. */
window.HWMonitor = {
  plugins: new Map(),
  pluginMeta: [],
  state: {
    servers: [],
    targets: [],
    devices: [],
    serverUrl: '',
    target: '',
    device: '',
    connected: false,
    targetOpen: false,
    activeTab: null,
  },
  pollTimers: {},
  pollLoops: {},
  pollBusy: {},
  ltxPluginStatus: {},
  ltxPluginInfo: {},
  vivadoInstalls: [],
  vivadoCurrent: '',
};

const pollState = HWMonitor;

function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
HWMonitor.esc = esc;

const busyStack = [];

function updateBusyUI() {
  const overlay = document.getElementById('busyOverlay');
  const labelEl = document.getElementById('busyLabel');
  const bar = document.getElementById('statusBar');
  const spinner = document.getElementById('statusSpinner');
  const text = document.getElementById('statusText');
  const active = busyStack.length > 0;
  const label = active ? busyStack[busyStack.length - 1] : '';

  if (overlay) {
    overlay.classList.toggle('hidden', !active);
    overlay.setAttribute('aria-busy', active ? 'true' : 'false');
  }
  if (labelEl) labelEl.textContent = label || 'Working…';
  if (bar) bar.classList.toggle('busy', active);
  if (spinner) spinner.classList.toggle('hidden', !active);
  if (text && active) text.textContent = label;
  document.body.classList.toggle('hw-busy', active);
}

function setBusy(label) {
  busyStack.push(label);
  updateBusyUI();
}
HWMonitor.setBusy = setBusy;

function clearBusy() {
  if (busyStack.length) busyStack.pop();
  updateBusyUI();
}
HWMonitor.clearBusy = clearBusy;

function clearAllBusy() {
  busyStack.length = 0;
  updateBusyUI();
}
HWMonitor.clearAllBusy = clearAllBusy;

async function withBusy(label, fn) {
  setBusy(label);
  try {
    return await fn();
  } finally {
    clearBusy();
  }
}
HWMonitor.withBusy = withBusy;

function setStatus(msg, isErr) {
  const bar = document.getElementById('statusBar');
  const text = document.getElementById('statusText');
  if (text) text.textContent = msg;
  if (bar) bar.className = 'status-bar' + (isErr ? ' err' : '') + (busyStack.length ? ' busy' : '');
  if (isErr) clearAllBusy();
}
HWMonitor.setStatus = setStatus;

function pluginRefreshLabel(pluginId) {
  const meta = HWMonitor.pluginMeta.find(function (p) { return p.id === pluginId; });
  const name = meta ? meta.name : pluginId;
  if (pluginId === 'tilecal_sfp_i2c') return 'Scanning SFP+ I2C registers…';
  return 'Reading ' + name + '…';
}
HWMonitor.pluginRefreshLabel = pluginRefreshLabel;

function shortName(full) {
  if (!full) return '';
  const p = full.split('/');
  return p[p.length - 1] || full;
}
HWMonitor.shortName = shortName;

function deviceQuery() {
  return HWMonitor.state.device ? '?device=' + encodeURIComponent(HWMonitor.state.device) : '';
}
HWMonitor.deviceQuery = deviceQuery;

HWMonitor.registerPlugin = function (spec) {
  const wrapped = Object.assign({}, spec);
  if (spec.refresh) {
    const origRefresh = spec.refresh;
    wrapped.refresh = async function (manual) {
      if (!manual && !pluginCanAutoRun(spec.id)) return;
      if (manual) {
        const label = spec.refreshLabel || pluginRefreshLabel(spec.id);
        return withBusy(label, function () { return origRefresh(); });
      }
      return origRefresh();
    };
  }
  HWMonitor.plugins.set(spec.id, wrapped);
  if (spec.onInit) spec.onInit();
};

function bindRefreshButtons() {
  document.querySelectorAll('[data-refresh]').forEach(function (btn) {
    const id = btn.dataset.refresh;
    if (!id || !HWMonitor.plugins.has(id)) return;
    btn.addEventListener('click', function () {
      const plugin = HWMonitor.plugins.get(id);
      if (plugin && plugin.refresh) plugin.refresh(true);
    });
  });
}

function pluginRequiresReadiness(meta) {
  return !!(meta && meta.requires_readiness);
}

function pluginRequiresLtx(meta) {
  return !!(meta && meta.requires_ltx);
}

function pluginAutoReadEnabled(pluginId) {
  const meta = HWMonitor.pluginMeta.find(function (p) { return p.id === pluginId; });
  return !!(meta && meta.auto_read_on_ready);
}

function getLtxPath() {
  const pathEl = document.getElementById('ltxPath');
  if (pathEl && pathEl.value.trim()) return pathEl.value.trim();
  const cfg = window.INITIAL_CONFIG || {};
  return (cfg.last_ltx || '').trim();
}

function pluginCanAutoRun(pluginId) {
  const meta = HWMonitor.pluginMeta.find(p => p.id === pluginId);
  if (!meta || !pluginRequiresReadiness(meta)) return true;
  const state = HWMonitor.ltxPluginStatus[pluginId];
  return state === 'ok';
}

async function updateLtxPluginStatus() {
  const path = getLtxPath();
  const params = new URLSearchParams();
  if (path) params.set('path', path);
  if (HWMonitor.state.device) params.set('device', HWMonitor.state.device);
  const qs = params.toString();
  let j;
  try {
    j = await fetchJson('/api/plugins/ltx_check' + (qs ? '?' + qs : ''));
  } catch (e) {
    console.warn('Probe readiness check failed:', e);
    return;
  }
  HWMonitor.ltxPluginStatus = {};
  HWMonitor.ltxPluginInfo = {};
  for (const meta of HWMonitor.pluginMeta) {
    if (!pluginRequiresReadiness(meta)) continue;
    const info = (j.plugins || {})[meta.id] || {
      state: 'not_connected',
      missing: [],
      message: 'Plugin not ready',
    };
    HWMonitor.ltxPluginInfo[meta.id] = info;
    HWMonitor.ltxPluginStatus[meta.id] = info.state === 'ok' ? 'ok' : 'error';
  }
  updateTabLtxIndicators();
}
HWMonitor.updateLtxPluginStatus = updateLtxPluginStatus;

function updateTabLtxIndicators() {
  document.querySelectorAll('.tab').forEach(function (tab) {
    const id = tab.dataset.tab;
    tab.classList.remove('ltx-error');
    tab.removeAttribute('title');
    const meta = HWMonitor.pluginMeta.find(function (p) { return p.id === id; });
    if (!pluginRequiresReadiness(meta)) return;
    const info = HWMonitor.ltxPluginInfo[id];
    if (!info || info.state === 'ok') return;
    tab.classList.add('ltx-error');
    tab.title = info.message || 'Plugin not ready';
  });
}

function pluginByTreeType(type) {
  for (const p of HWMonitor.pluginMeta) {
    if ((p.tree_node_types || []).includes(type)) return p.id;
  }
  for (const [id, spec] of HWMonitor.plugins) {
    if ((spec.treeNodeTypes || []).includes(type)) return id;
  }
  return null;
}

function switchTab(name) {
  HWMonitor.state.activeTab = name;
  document.querySelectorAll('.tab').forEach(t => t.classList.toggle('active', t.dataset.tab === name));
  document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
  const panel = document.getElementById('panel-' + name);
  if (panel) panel.classList.add('active');
  const plugin = HWMonitor.plugins.get(name);
  if (plugin && plugin.onTabActivate) plugin.onTabActivate();
}
HWMonitor.switchTab = switchTab;

function stopPoller(key) {
  if (pollState.pollTimers[key]) {
    clearInterval(pollState.pollTimers[key]);
    pollState.pollTimers[key] = null;
  }
  if (pollState.pollLoops[key]) {
    pollState.pollLoops[key].running = false;
    pollState.pollLoops[key] = null;
  }
}

function startContinuousPoll(key, fn) {
  pollState.pollLoops[key] = { running: true };
  (async () => {
    while (pollState.pollLoops[key] && pollState.pollLoops[key].running) {
      if (!pollState.pollBusy[key]) {
        pollState.pollBusy[key] = true;
        try { await fn(); } catch (_) {}
        pollState.pollBusy[key] = false;
      }
      await new Promise(r => setTimeout(r, 50));
    }
  })();
}

function syncPoller(key, fn, opts) {
  stopPoller(key);
  const sel = document.getElementById('pollRate-' + key);
  if (!sel) return;
  const rate = sel.value;
  if (!rate || rate === 'off') return;
  const st = HWMonitor.state;
  if (!st.targetOpen) return;
  if (opts && opts.requiresDevice && !st.device) return;

  if (rate === '0') {
    startContinuousPoll(key, fn);
    return;
  }
  const ms = parseInt(rate, 10) * 1000;
  if (ms > 0) pollState.pollTimers[key] = setInterval(fn, ms);
}

function syncPollers() {
  for (const [id, plugin] of HWMonitor.plugins) {
    if (!plugin.refresh || !pluginCanAutoRun(id)) continue;
    const meta = HWMonitor.pluginMeta.find(p => p.id === id) || {};
    syncPoller(id, plugin.refresh, {
      requiresDevice: meta.requires_device || plugin.requiresDevice,
    });
  }
}
HWMonitor.syncPollers = syncPollers;

function stopAllPollers() {
  for (const id of HWMonitor.plugins.keys()) stopPoller(id);
}

async function refreshPluginsIfAutoRead() {
  const tasks = [];
  for (const entry of HWMonitor.plugins) {
    const id = entry[0];
    const plugin = entry[1];
    if (!plugin.refresh || !pluginCanAutoRun(id) || !pluginAutoReadEnabled(id)) continue;
    tasks.push(plugin.refresh().catch(function (err) {
      console.error('Plugin auto-read failed:', id, err);
    }));
  }
  await Promise.allSettled(tasks);
}

async function refreshAllPlugins() {
  const tasks = [...HWMonitor.plugins.entries()]
    .filter(function (entry) { return entry[1].refresh && pluginCanAutoRun(entry[0]); })
    .map(function (entry) {
      return entry[1].refresh().catch(function (err) {
        console.error('Plugin refresh failed:', entry[0], err);
      });
    });
  await Promise.allSettled(tasks);
}

async function onPluginDeviceChange() {
  for (const plugin of HWMonitor.plugins.values()) {
    if (plugin.onDeviceChange) plugin.onDeviceChange();
  }
}

async function onPluginDisconnect() {
  for (const plugin of HWMonitor.plugins.values()) {
    if (plugin.onDisconnect) plugin.onDisconnect();
  }
}

// ---- plugin loader ----
function loadStylesheet(href) {
  if (document.querySelector('link[data-href="' + href + '"]')) return;
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = href;
  link.dataset.href = href;
  document.head.appendChild(link);
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-src="' + src + '"]');
    if (existing) existing.remove();
    const s = document.createElement('script');
    s.src = src + (src.includes('?') ? '&' : '?') + 'v=' + Date.now();
    s.dataset.src = src;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error('Failed to load ' + src));
    document.head.appendChild(s);
  });
}

async function loadPlugins(pluginList) {
  HWMonitor.plugins.clear();
  HWMonitor.pluginMeta = pluginList.filter(p => p.enabled);
  const tabsEl = document.getElementById('pluginTabs');
  const panelsEl = document.getElementById('pluginPanels');
  tabsEl.innerHTML = '';
  panelsEl.innerHTML = '';

  const externalScripts = new Set();
  for (const p of HWMonitor.pluginMeta) {
    for (const src of (p.assets.external_scripts || [])) externalScripts.add(src);
  }
  for (const src of externalScripts) await loadScript(src);

  for (const p of HWMonitor.pluginMeta) {
    for (const css of (p.assets.styles || [])) {
      loadStylesheet('/plugins/' + p.id + '/assets/' + css);
    }

    const tab = document.createElement('div');
    tab.className = 'tab';
    tab.dataset.tab = p.id;
    tab.textContent = p.name;
    tab.onclick = () => switchTab(p.id);
    tabsEl.appendChild(tab);

    const panel = document.createElement('div');
    panel.id = 'panel-' + p.id;
    panel.className = 'tab-panel';
    panel.dataset.plugin = p.id;
    panelsEl.appendChild(panel);

    const panelResp = await fetch('/plugins/' + p.id + '/assets/' + p.assets.panel);
    panel.innerHTML = await panelResp.text();

    const pollSel = panel.querySelector('[data-poll-rate]');
    if (pollSel) pollSel.addEventListener('change', syncPollers);

    await loadScript('/plugins/' + p.id + '/assets/' + p.assets.script);
  }

  bindRefreshButtons();

  if (HWMonitor.pluginMeta.length) {
    tabsEl.firstChild.classList.add('active');
    panelsEl.firstChild.classList.add('active');
    HWMonitor.state.activeTab = HWMonitor.pluginMeta[0].id;
  }
  await updateLtxPluginStatus();
}

// ---- config modal ----
let probeConfigPluginId = null;
let probeConfigFields = [];
let vioProbeCatalog = [];
let sysmonPropCatalog = [];

async function loadSysmonPropCatalog() {
  if (sysmonPropCatalog.length) return sysmonPropCatalog;
  const j = await fetchJson('/api/sysmon/properties');
  sysmonPropCatalog = j.properties || [];
  return sysmonPropCatalog;
}

function probeDatalistId(key) {
  return 'probe-dl-' + key.replace(/[^a-zA-Z0-9_]/g, '_');
}

function probeComboMarkup(field, currentValue) {
  const key = field.key;
  const dlId = probeDatalistId(key);
  const val = currentValue || field.default || '';
  let opts = '';
  if (field.kind === 'sysmon_prop') {
    for (const p of sysmonPropCatalog) {
      opts += '<option value="' + esc(p) + '"></option>';
    }
  } else {
    const sorted = vioProbeCatalog.slice().sort(function (a, b) {
      return a.name.localeCompare(b.name);
    });
    for (const p of sorted) {
      opts += '<option value="' + esc(p.name) + '">' + esc(p.name + ' (' + p.direction + ')') + '</option>';
    }
  }
  return '<input type="text" class="probe-combo" list="' + dlId + '" data-probe-key="' + esc(key) + '" ' +
    'value="' + esc(val) + '" placeholder="type or pick…" autocomplete="off">' +
    '<datalist id="' + dlId + '">' + opts + '</datalist>';
}

async function openConfigModal() {
  document.getElementById('configModal').classList.add('open');
  await loadVivadoVersions();
  renderVivadoInstalls();
  renderServerConfig();
  renderPluginConfig();
}

function closeConfigModal() {
  document.getElementById('configModal').classList.remove('open');
}

function openProbeConfigModal(pluginId, pluginName, probeFields) {
  probeConfigPluginId = pluginId;
  probeConfigFields = probeFields || [];
  const title = document.getElementById('probeConfigTitle');
  if (title) title.textContent = 'VIO probe mapping — ' + (pluginName || pluginId);
  document.getElementById('probeConfigModal').classList.add('open');
  renderProbeConfigModal();
}

function closeProbeConfigModal() {
  document.getElementById('probeConfigModal').classList.remove('open');
  probeConfigPluginId = null;
  probeConfigFields = [];
}

async function fetchJson(url) {
  const r = await fetch(url);
  const text = await r.text();
  let j;
  try {
    j = JSON.parse(text);
  } catch (_) {
    const snippet = text.trim().slice(0, 80).replace(/\s+/g, ' ');
    throw new Error('Server returned non-JSON (restart app.py?): ' + snippet);
  }
  if (!r.ok) throw new Error(j.error || ('HTTP ' + r.status));
  return j;
}

function probeLtxPathFromUi() {
  const probePath = document.getElementById('probeLtxPath');
  if (probePath && probePath.value.trim()) return probePath.value.trim();
  const mainPath = document.getElementById('ltxPath');
  if (mainPath && mainPath.value.trim()) return mainPath.value.trim();
  const cfg = window.INITIAL_CONFIG || {};
  return (cfg.last_ltx || '').trim();
}

async function loadProbeLtxFileList() {
  const sel = document.getElementById('probeLtxSelect');
  const pathEl = document.getElementById('probeLtxPath');
  if (!sel) return '';
  try {
    const j = await fetchJson('/api/ltx');
    const all = [...new Set([...(j.saved || []), ...(j.candidates || [])])];
    const last = j.last_ltx || probeLtxPathFromUi() || '';
    fillFileSelect(sel, all, last, 'ltx');
    const path = last || probeLtxPathFromUi();
    if (path) {
      if (pathEl) pathEl.value = path;
      sel.value = path;
    }
    return path;
  } catch (e) {
    setStatus('Failed to load LTX file list: ' + e, true);
    return probeLtxPathFromUi();
  }
}

function onProbeLtxSelect() {
  const sel = document.getElementById('probeLtxSelect');
  const pathEl = document.getElementById('probeLtxPath');
  if (!sel || !pathEl) return;
  const v = sel.value;
  if (v) pathEl.value = v;
}

async function loadVioProbeCatalog(ltxPath) {
  const path = (ltxPath || probeLtxPathFromUi()).trim();
  if (!path) {
    vioProbeCatalog = [];
    return [];
  }
  const j = await fetchJson('/api/ltx/probes?path=' + encodeURIComponent(path));
  vioProbeCatalog = j.probes || [];
  return vioProbeCatalog;
}

async function loadProbeCatalogFromLtx() {
  const pathEl = document.getElementById('probeLtxPath');
  const path = (pathEl && pathEl.value.trim()) || probeLtxPathFromUi();
  if (!path) {
    setStatus('Select or enter an LTX file path', true);
    return;
  }
  if (pathEl) pathEl.value = path;
  await rememberFileChoice('ltx', path);
  await renderProbeConfigModal();
}


async function renderProbeConfigModal() {
  const body = document.getElementById('probeConfigBody');
  const hint = document.getElementById('probeConfigHint');
  if (!body) return;
  body.innerHTML = '<p class="empty">Loading VIO probes from LTX…</p>';
  const ltxPath = await loadProbeLtxFileList();
  if (!ltxPath) {
    body.innerHTML = '<p class="empty">Select or enter an LTX file above, then click Load LTX.</p>';
    if (hint) hint.textContent = 'Load an LTX file to populate VIO probe names. No Vivado connection is required.';
    return;
  }
  try {
    await loadSysmonPropCatalog();
    await loadVioProbeCatalog(ltxPath);
  } catch (e) {
    body.innerHTML = '<p class="empty">Failed to load probes: ' + esc(String(e)) + '</p>';
    return;
  }
  const liveNote = HWMonitor.state.targetOpen && HWMonitor.state.device
    ? ' (device connected — live probes used at runtime)'
    : '';
  if (hint) {
    hint.innerHTML = 'LTX <code>' + esc(ltxPath) + '</code> — ' +
      vioProbeCatalog.length + ' probes' + liveNote + '. Pick the exact VIO name for each parameter.';
  }
  if (!probeConfigFields.length) {
    body.innerHTML = '<p class="empty">This plugin has no probe parameters.</p>';
    return;
  }
  let html = '<table class="probe-map"><tr><th>Parameter</th><th>Probe / property name</th></tr>';
  let lastGroup = '';
  for (const pf of probeConfigFields) {
    const grp = pf.group || '';
    if (grp && grp !== lastGroup) {
      html += '<tr class="probe-group-row"><td colspan="2">' + esc(grp) + '</td></tr>';
      lastGroup = grp;
    }
    html += '<tr><td class="param">' + esc(pf.label || pf.key) +
      (pf.hint ? '<span class="probe-hint">' + esc(pf.hint) + '</span>' : '') +
      '</td><td>' + probeComboMarkup(pf, pf.value || pf.default || '') + '</td></tr>';
  }
  html += '</table>';
  body.innerHTML = html;
}

async function saveProbeConfigModal() {
  if (!probeConfigPluginId) return;
  const probes = {};
  document.querySelectorAll('#probeConfigBody input[data-probe-key]').forEach(function (inp) {
    const val = inp.value.trim();
    if (val) probes[inp.dataset.probeKey] = val;
  });
  await withBusy('Saving probe mapping…', async function () {
    const r = await fetch('/api/plugins/' + encodeURIComponent(probeConfigPluginId) + '/probes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ probes }),
    });
    const j = await r.json();
    if (!j.success) {
      setStatus('Failed to save probe mapping: ' + (j.error || ''), true);
      return;
    }
    closeProbeConfigModal();
    setStatus('Probe mapping saved for ' + probeConfigPluginId);
    await updateLtxPluginStatus();
  });
}

function renderServerConfig() {
  const wrap = document.getElementById('serverConfigList');
  if (!wrap) return;
  const servers = HWMonitor.state.servers.length
    ? HWMonitor.state.servers
    : [{ url: '', name: '' }];
  wrap.innerHTML = servers.map(function (s, idx) {
    return '<div class="server-config-row" data-idx="' + idx + '">' +
      '<input type="text" class="server-name" placeholder="label" value="' + esc(s.name || '') + '">' +
      '<input type="text" class="server-url" placeholder="host:port" value="' + esc(s.url || '') + '">' +
      '<button type="button" class="btn-remove-row" onclick="removeServerConfigRow(this)">✕</button>' +
      '</div>';
  }).join('');
}

function addServerConfigRow() {
  const wrap = document.getElementById('serverConfigList');
  if (!wrap) return;
  const row = document.createElement('div');
  row.className = 'server-config-row';
  row.innerHTML =
    '<input type="text" class="server-name" placeholder="label">' +
    '<input type="text" class="server-url" placeholder="host:port">' +
    '<button type="button" class="btn-remove-row" onclick="removeServerConfigRow(this)">✕</button>';
  wrap.appendChild(row);
}

function removeServerConfigRow(btn) {
  const row = btn.closest('.server-config-row');
  const wrap = document.getElementById('serverConfigList');
  if (!row || !wrap) return;
  if (wrap.querySelectorAll('.server-config-row').length <= 1) {
    row.querySelector('.server-name').value = '';
    row.querySelector('.server-url').value = '';
    return;
  }
  row.remove();
}

function collectServerConfig() {
  const rows = document.querySelectorAll('#serverConfigList .server-config-row');
  const servers = [];
  rows.forEach(function (row) {
    const url = (row.querySelector('.server-url')?.value || '').trim();
    if (!url) return;
    servers.push({
      url: url,
      name: (row.querySelector('.server-name')?.value || '').trim(),
    });
  });
  return servers;
}

async function saveAppConfig() {
  await withBusy('Saving configuration…', async function () {
    const installs = collectVivadoInstalls();
    const ir = await fetch('/api/vivado/installs/replace', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ installs: installs }),
    });
    const ij = await ir.json();
    if (!ij.success) {
      setStatus('Failed to save Vivado installs: ' + (ij.error || ''), true);
      return;
    }

    const sessionPath = document.getElementById('selVivado')?.value;
    if (sessionPath) {
      const vr = await fetch('/api/vivado/select', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ path: sessionPath }),
      });
      const vj = await vr.json();
      if (!vj.success) {
        setStatus('Failed to set Vivado path: ' + (vj.error || ''), true);
        return;
      }
    }

    const servers = collectServerConfig();
    const sr = await fetch('/api/hw_servers/replace', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ hw_servers: servers }),
    });
    const sj = await sr.json();
    if (!sj.success) {
      setStatus('Failed to save servers: ' + (sj.error || ''), true);
      return;
    }

    const rows = document.querySelectorAll('#pluginConfigList .plugin-config-row');
    const plugins = {};
    rows.forEach(function (row, idx) {
      const id = row.dataset.pluginId;
      const cb = row.querySelector('input[type=checkbox][data-plugin-id]');
      const autoCb = row.querySelector('input[data-auto-read]');
      if (!id || !cb) return;
      plugins[id] = {
        enabled: cb.checked,
        order: idx * 10,
        auto_read_on_ready: !!(autoCb && autoCb.checked),
      };
    });
    const r = await fetch('/api/plugins/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ plugins: plugins }),
    });
    const j = await r.json();
    if (!j.success) {
      setStatus('Failed to save plugin config: ' + (j.error || ''), true);
      return;
    }
    closeConfigModal();
    setStatus('Configuration saved — reloading…');
    window.location.reload();
  });
}

async function savePluginConfig() {
  return saveAppConfig();
}

async function renderPluginConfig() {
  const wrap = document.getElementById('pluginConfigList');
  wrap.innerHTML = '<p class="empty">Loading…</p>';
  const r = await fetch('/api/plugins');
  const j = await r.json();
  let html = '';
  for (const p of (j.plugins || [])) {
    html += '<div class="plugin-config-row" data-plugin-id="' + esc(p.id) + '">' +
      '<div class="plugin-config-order">' +
      '<button type="button" class="btn-order" data-dir="up" title="Move up">▲</button>' +
      '<button type="button" class="btn-order" data-dir="down" title="Move down">▼</button>' +
      '</div>' +
      '<div class="plugin-config-body">' +
      '<label class="plugin-config-main">' +
      '<input type="checkbox" data-plugin-id="' + esc(p.id) + '"' + (p.enabled ? ' checked' : '') + '>' +
      '<span class="plugin-config-info">' +
      '<strong>' + esc(p.name) + '</strong>' +
      '<span class="plugin-config-desc">' + esc(p.description || '') + '</span>' +
      '<span class="plugin-config-meta">v' + esc(p.version || '1.0') + ' · ' + esc(p.id) + '</span>' +
      '</span></label>';
    if (p.probe_config && p.probe_config.length) {
      html += '<button type="button" class="btn-probes" data-probe-plugin="' + esc(p.id) + '">Probe mapping…</button>';
    }
    html += '<label class="plugin-auto-read">' +
      '<input type="checkbox" data-auto-read="' + esc(p.id) + '"' +
      (p.auto_read_on_ready ? ' checked' : '') + '> Auto-read when probes ready</label>';
    html += '</div></div>';
  }
  wrap.innerHTML = html || '<p class="empty">No plugins found.</p>';
  wrap.querySelectorAll('.btn-order').forEach(btn => {
    btn.addEventListener('click', (evt) => {
      evt.preventDefault();
      evt.stopPropagation();
      movePluginConfigRow(btn.closest('.plugin-config-row'), btn.dataset.dir);
    });
  });
  wrap.querySelectorAll('.btn-probes').forEach(btn => {
    btn.addEventListener('click', (evt) => {
      evt.preventDefault();
      const pid = btn.dataset.probePlugin;
      const plugin = (j.plugins || []).find(function (x) { return x.id === pid; });
      if (plugin) openProbeConfigModal(plugin.id, plugin.name, plugin.probe_config);
    });
  });
}

function movePluginConfigRow(row, dir) {
  if (!row) return;
  if (dir === 'up' && row.previousElementSibling) {
    row.parentNode.insertBefore(row, row.previousElementSibling);
  } else if (dir === 'down' && row.nextElementSibling) {
    row.parentNode.insertBefore(row.nextElementSibling, row);
  }
}

// ---- dropdowns / files (unchanged core) ----
function fillServerSelect() {
  const sel = document.getElementById('selServer');
  const cur = HWMonitor.state.serverUrl;
  sel.innerHTML = '<option value="">— custom —</option>';
  for (const s of HWMonitor.state.servers) {
    const opt = document.createElement('option');
    opt.value = s.url;
    opt.textContent = (s.name ? s.name + ' · ' : '') + s.url;
    if (s.url === cur) opt.selected = true;
    sel.appendChild(opt);
  }
  if (cur && !HWMonitor.state.servers.some(s => s.url === cur)) {
    const opt = document.createElement('option');
    opt.value = cur; opt.textContent = cur; opt.selected = true;
    sel.appendChild(opt);
  }
  document.getElementById('serverUrl').value = cur || '';
}

function fillTargetSelect() {
  const sel = document.getElementById('selTarget');
  sel.innerHTML = '<option value="">— select —</option>';
  for (const t of HWMonitor.state.targets) {
    const opt = document.createElement('option');
    opt.value = t;
    opt.textContent = shortName(t);
    if (t === HWMonitor.state.target) opt.selected = true;
    sel.appendChild(opt);
  }
}

function fillDeviceSelect() {
  const sel = document.getElementById('selDevice');
  sel.innerHTML = '';
  if (!HWMonitor.state.targetOpen) {
    sel.innerHTML = '<option value="">— open target first —</option>';
    sel.disabled = true;
    return;
  }
  sel.disabled = false;
  sel.innerHTML = '<option value="">— select device —</option>';
  const listed = new Set();
  for (const d of HWMonitor.state.devices) {
    listed.add(d.name);
    const opt = document.createElement('option');
    opt.value = d.name;
    opt.textContent = shortName(d.name) + (d.part ? ' (' + d.part + ')' : '');
    if (d.name === HWMonitor.state.device) opt.selected = true;
    sel.appendChild(opt);
  }
  if (HWMonitor.state.device && !listed.has(HWMonitor.state.device)) {
    const opt = document.createElement('option');
    opt.value = HWMonitor.state.device;
    opt.textContent = shortName(HWMonitor.state.device);
    opt.selected = true;
    sel.appendChild(opt);
  }
  if (HWMonitor.state.device) sel.value = HWMonitor.state.device;
}

function updateTargetGatedControls() {
  fillDeviceSelect();
  const needTarget = !HWMonitor.state.targetOpen;
  for (const id of ['ltxSelect', 'ltxPath', 'bitSelect', 'bitPath', 'binSelect', 'binPath',
                     'btnLoadLtx', 'btnProgramBit', 'btnProgramBin']) {
    const el = document.getElementById(id);
    if (el) el.disabled = needTarget;
  }
}

const FILE_LIST_CFG = {
  ltx: { url: '/api/ltx', select: 'ltxSelect', path: 'ltxPath', ext: 'ltx', lastKey: 'last_ltx', upload: 'uploadLtx' },
  bit: { url: '/api/bit', select: 'bitSelect', path: 'bitPath', ext: 'bit', lastKey: 'last_bit', upload: 'uploadBit' },
  bin: { url: '/api/bin', select: 'binSelect', path: 'binPath', ext: 'bin', lastKey: 'last_bin', upload: 'uploadBin' },
};

const FOLDER_COLORS = [
  '#4f8cff', '#3ecf8e', '#f0b429', '#c084fc', '#5eead4',
  '#fdba74', '#f472b6', '#38bdf8', '#a3e635', '#fb923c',
];

function folderKey(path) {
  const i = path.lastIndexOf('/');
  return i >= 0 ? path.slice(0, i) : path;
}

function folderColor(folder) {
  let h = 0;
  for (let i = 0; i < folder.length; i++) h = ((h << 5) - h + folder.charCodeAt(i)) | 0;
  return FOLDER_COLORS[Math.abs(h) % FOLDER_COLORS.length];
}

function folderLabel(folder) {
  const marker = '/bin/';
  const idx = folder.indexOf(marker);
  if (idx >= 0) return folder.slice(idx + 1);
  const parts = folder.split('/');
  return parts.length > 2 ? '.../' + parts.slice(-2).join('/') : folder;
}

function basename(path) {
  const i = path.lastIndexOf('/');
  return i >= 0 ? path.slice(i + 1) : path;
}

function siblingLtxPath(bitOrBinPath) {
  if (!bitOrBinPath) return '';
  const i = bitOrBinPath.lastIndexOf('.');
  if (i <= 0) return '';
  return bitOrBinPath.slice(0, i) + '.ltx';
}

function appendFileOption(parent, path, label) {
  const opt = document.createElement('option');
  opt.value = path;
  opt.textContent = label || path;
  opt.title = path;
  opt.style.color = folderColor(folderKey(path));
  parent.appendChild(opt);
}

function appendSeparator(sel) {
  const sep = document.createElement('option');
  sep.disabled = true;
  sep.textContent = '────────────────────────';
  sel.appendChild(sep);
}

function fillFileSelect(sel, all, last, ext) {
  sel.innerHTML = '<option value="">— pick .' + ext + ' file —</option>';
  const sorted = [...all].sort();
  const others = last ? sorted.filter(p => p !== last) : sorted;
  if (last && all.includes(last)) appendFileOption(sel, last, basename(last) + '  (recent)');
  if (last && all.includes(last) && others.length) appendSeparator(sel);
  const byFolder = {};
  for (const p of others) {
    const f = folderKey(p);
    if (!byFolder[f]) byFolder[f] = [];
    byFolder[f].push(p);
  }
  for (const folder of Object.keys(byFolder).sort()) {
    const group = document.createElement('optgroup');
    group.label = folderLabel(folder);
    group.style.color = folderColor(folder);
    for (const p of byFolder[folder]) appendFileOption(group, p, basename(p));
    sel.appendChild(group);
  }
}

async function rememberFileChoice(kind, path) {
  if (!path) return;
  try {
    await fetch('/api/file_last', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: kind, path }),
    });
  } catch (_) {}
}

function applyLtxSelection(ltxPath, remember) {
  if (!ltxPath) return;
  document.getElementById('ltxPath').value = ltxPath;
  const ltxSel = document.getElementById('ltxSelect');
  for (const opt of ltxSel.options) {
    if (opt.value === ltxPath) { ltxSel.value = ltxPath; break; }
  }
  if (remember) rememberFileChoice('ltx', ltxPath);
}

async function loadFileList(kind) {
  const cfg = FILE_LIST_CFG[kind];
  if (!cfg) return;
  try {
    const r = await fetch(cfg.url);
    if (!r.ok) { setStatus('Could not load .' + cfg.ext + ' file list (HTTP ' + r.status + ')', true); return; }
    const j = await r.json();
    const sel = document.getElementById(cfg.select);
    if (!sel) return;
    const all = [...new Set([...(j.saved || []), ...(j.candidates || [])])];
    const last = j[cfg.lastKey] || '';
    fillFileSelect(sel, all, last, cfg.ext);
    if (last) {
      document.getElementById(cfg.path).value = last;
      sel.value = last;
    }
    if (kind === 'ltx') await updateLtxPluginStatus();
  } catch (e) {
    setStatus('Failed to load .' + cfg.ext + ' file list: ' + e, true);
  }
}

async function loadAllFileLists() {
  await Promise.all(Object.keys(FILE_LIST_CFG).map(loadFileList));
  await updateLtxPluginStatus();
}

async function refreshFileList(kind) {
  await loadFileList(kind);
  setStatus('Refreshed .' + FILE_LIST_CFG[kind].ext + ' file list');
}

function triggerUpload(kind) {
  document.getElementById(FILE_LIST_CFG[kind].upload).click();
}

async function uploadFile(kind, input) {
  const file = input.files && input.files[0];
  input.value = '';
  if (!file) return;
  await withBusy('Uploading ' + file.name + '…', async function () {
    const fd = new FormData();
    fd.append('file', file);
    fd.append('type', kind);
    try {
      const r = await fetch('/api/upload', { method: 'POST', body: fd });
      const j = await r.json();
      if (!j.success) { setStatus('Upload failed: ' + (j.error || ''), true); return; }
      setStatus('Uploaded to ' + j.path);
      await loadAllFileLists();
      const cfg = FILE_LIST_CFG[kind];
      document.getElementById(cfg.path).value = j.path;
      document.getElementById(cfg.select).value = j.path;
      if (kind === 'bit' || kind === 'bin') {
        applyLtxSelection(siblingLtxPath(j.path), !!siblingLtxPath(j.path));
        await loadFileList('ltx');
      }
    } catch (e) {
      setStatus('Upload error: ' + e, true);
    }
  });
}

async function onFileSelect(kind) {
  const cfg = FILE_LIST_CFG[kind];
  const v = document.getElementById(cfg.select).value;
  if (!v) return;
  document.getElementById(cfg.path).value = v;
  await rememberFileChoice(kind, v);
  if (kind === 'bit' || kind === 'bin') applyLtxSelection(siblingLtxPath(v), !!siblingLtxPath(v));
  await loadFileList(kind);
  if (kind === 'bit' || kind === 'bin') await loadFileList('ltx');
  if (kind === 'ltx') await updateLtxPluginStatus();
}

function vivadoPathShort(path) {
  if (!path) return '';
  const parts = path.split('/');
  if (parts.length <= 3) return path;
  return '.../' + parts.slice(-3).join('/');
}

function fillVivadoToolbar(installs, currentPath) {
  const sel = document.getElementById('selVivado');
  if (!sel) return;
  sel.innerHTML = '';
  const list = installs && installs.length ? installs : [];
  if (!list.length && currentPath) {
    list.push({ label: 'Custom', path: currentPath });
  }
  for (const item of list) {
    const opt = document.createElement('option');
    opt.value = item.path;
    opt.textContent = (item.label || 'Vivado') + ' — ' + vivadoPathShort(item.path);
    if (item.path === currentPath) opt.selected = true;
    sel.appendChild(opt);
  }
  if (currentPath && !list.some(function (i) { return i.path === currentPath; })) {
    const opt = document.createElement('option');
    opt.value = currentPath;
    opt.textContent = 'Custom — ' + vivadoPathShort(currentPath);
    opt.selected = true;
    sel.appendChild(opt);
  }
  const curEl = document.getElementById('vivadoCurrentPath');
  if (curEl) curEl.textContent = currentPath || '(not set)';
}

function renderVivadoInstalls() {
  const wrap = document.getElementById('vivadoInstallList');
  if (!wrap) return;
  const installs = HWMonitor.state.vivadoInstalls.length
    ? HWMonitor.state.vivadoInstalls
    : [{ label: '', path: '' }];
  wrap.innerHTML = installs.map(function (item, idx) {
    return '<div class="server-config-row vivado-install-row" data-idx="' + idx + '">' +
      '<input type="text" class="server-name vivado-label" placeholder="label" value="' + esc(item.label || '') + '">' +
      '<input type="text" class="server-url vivado-path" placeholder="/path/to/vivado" value="' + esc(item.path || '') + '">' +
      '<button type="button" class="btn-remove-row" onclick="removeVivadoInstallRow(this)">✕</button>' +
      '</div>';
  }).join('');
  const curEl = document.getElementById('vivadoCurrentPath');
  if (curEl) curEl.textContent = HWMonitor.state.vivadoCurrent || '(not set)';
}

function addVivadoInstallRow() {
  const wrap = document.getElementById('vivadoInstallList');
  if (!wrap) return;
  const row = document.createElement('div');
  row.className = 'server-config-row vivado-install-row';
  row.innerHTML =
    '<input type="text" class="server-name vivado-label" placeholder="label">' +
    '<input type="text" class="server-url vivado-path" placeholder="/path/to/vivado">' +
    '<button type="button" class="btn-remove-row" onclick="removeVivadoInstallRow(this)">✕</button>';
  wrap.appendChild(row);
}

function removeVivadoInstallRow(btn) {
  const row = btn.closest('.vivado-install-row');
  const wrap = document.getElementById('vivadoInstallList');
  if (!row || !wrap) return;
  if (wrap.querySelectorAll('.vivado-install-row').length <= 1) {
    row.querySelector('.vivado-label').value = '';
    row.querySelector('.vivado-path').value = '';
    return;
  }
  row.remove();
}

function collectVivadoInstalls() {
  const rows = document.querySelectorAll('#vivadoInstallList .vivado-install-row');
  const installs = [];
  rows.forEach(function (row) {
    const path = (row.querySelector('.vivado-path')?.value || '').trim();
    if (!path) return;
    installs.push({
      label: (row.querySelector('.vivado-label')?.value || '').trim() || vivadoPathShort(path),
      path: path,
    });
  });
  return installs;
}

async function autodetectVivadoInstalls() {
  await withBusy('Scanning for Vivado installs…', async function () {
    const r = await fetch('/api/vivado/autodetect', { method: 'POST' });
    const j = await r.json();
    if (!j.success) {
      setStatus('Autodetect failed: ' + (j.error || ''), true);
      return;
    }
    HWMonitor.state.vivadoInstalls = j.installs || [];
    renderVivadoInstalls();
    fillVivadoToolbar(HWMonitor.state.vivadoInstalls, HWMonitor.state.vivadoCurrent);
    setStatus('Autodetect added ' + (j.added || 0) + ' install(s)');
  });
}

async function loadVivadoVersions() {
  const r = await fetch('/api/vivado/versions');
  const j = await r.json();
  HWMonitor.state.vivadoInstalls = j.installs || [];
  HWMonitor.state.vivadoCurrent = j.current || '';
  fillVivadoToolbar(HWMonitor.state.vivadoInstalls, HWMonitor.state.vivadoCurrent);
}

async function selectVivado() {
  const path = document.getElementById('selVivado').value;
  if (!path) return;
  await withBusy('Switching Vivado…', async function () {
    const r = await fetch('/api/vivado/select', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ path: path }),
    });
    const j = await r.json();
    HWMonitor.state.vivadoCurrent = j.path || path;
    setStatus(j.restarted ? 'Vivado restarted — reconnect required' : 'Vivado path saved', !j.success);
    fillVivadoToolbar(HWMonitor.state.vivadoInstalls, HWMonitor.state.vivadoCurrent);
    await refreshTree();
  });
}

async function programDevice(kind) {
  const st = HWMonitor.state;
  if (!st.targetOpen) { setStatus('Open a target first', true); return; }
  if (!st.device) { setStatus('Select a device first', true); return; }
  const pathId = kind === 'bit' ? 'bitPath' : 'binPath';
  const path = document.getElementById(pathId).value.trim();
  if (!path) { setStatus('Enter a .' + kind + ' file path', true); return; }
  if (!confirm('Program ' + st.device + ' with\n' + path + '?')) return;
  await withBusy('Programming ' + kind.toUpperCase() + '…', async function () {
    const r = await fetch('/api/program', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: kind, path, device: st.device }),
    });
    const j = await r.json();
    setStatus(
      j.success ? ('Programmed .' + kind + ': ' + shortName(path)) : ('Program failed: ' + (j.detail || j.error || '')),
      !j.success
    );
    if (j.success) { await loadAllFileLists(); await refreshAllInner(); }
  });
}

function programBit() { return programDevice('bit'); }
function programBin() { return programDevice('bin'); }

function onServerChange() {
  const v = document.getElementById('selServer').value;
  if (v) document.getElementById('serverUrl').value = v;
  HWMonitor.state.serverUrl = document.getElementById('serverUrl').value.trim();
}

async function connectFlow() {
  const url = document.getElementById('serverUrl').value.trim() ||
              document.getElementById('selServer').value.trim();
  if (!url) { setStatus('Select or add a server URL', true); return; }
  await withBusy('Connecting to ' + url + '…', async function () {
    const r = await fetch('/api/hw_servers/connect', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url }),
    });
    const j = await r.json();
    if (!j.success) {
      HWMonitor.state.connected = false;
      HWMonitor.state.targetOpen = false;
      HWMonitor.state.targets = [];
      HWMonitor.state.devices = [];
      updateTargetGatedControls();
      renderTree(buildMinimalTree('(not connected)'));
      setStatus('Connect failed — see Tcl console', true);
      await updateLtxPluginStatus();
      return;
    }
    HWMonitor.state.connected = true;
    HWMonitor.state.serverUrl = url;
    HWMonitor.state.targets = j.targets || [];
    HWMonitor.state.target = '';
    HWMonitor.state.device = '';
    HWMonitor.state.devices = [];
    HWMonitor.state.targetOpen = false;
    fillServerSelect();
    fillTargetSelect();
    updateTargetGatedControls();
    setStatus('Connected — select a target');
    await refreshTree();
    await updateLtxPluginStatus();
    if (HWMonitor.state.targets.length === 1) {
      document.getElementById('selTarget').value = HWMonitor.state.targets[0];
      await onTargetChange();
    }
  });
}

async function onTargetChange() {
  const target = document.getElementById('selTarget').value;
  if (!target) return;
  await withBusy('Opening target ' + shortName(target) + '…', async function () {
    const r = await fetch('/api/targets/open', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ target }),
    });
    const j = await r.json();
    if (!j.success) {
      HWMonitor.state.targetOpen = false;
      HWMonitor.state.devices = [];
      HWMonitor.state.device = '';
      updateTargetGatedControls();
      await refreshTree();
      setStatus('Open target failed — see Tcl console', true);
      await updateLtxPluginStatus();
      return;
    }
    HWMonitor.state.target = target;
    HWMonitor.state.targetOpen = true;
    HWMonitor.state.devices = j.devices || [];
    HWMonitor.state.device = '';
    updateTargetGatedControls();
    if (HWMonitor.state.devices.length === 1) {
      HWMonitor.state.device = HWMonitor.state.devices[0].name;
      document.getElementById('selDevice').value = HWMonitor.state.device;
      await onDeviceChangeInner();
    }
    setStatus('Target open — select a device (' + HWMonitor.state.devices.length + ' found)');
    await refreshTree();
    await updateLtxPluginStatus();
  });
}

async function loadDeviceData() {
  if (!HWMonitor.state.device) return;
  await updateLtxPluginStatus();
  await refreshPluginsIfAutoRead();
  syncPollers();
}

async function onDeviceChangeInner() {
  if (!HWMonitor.state.targetOpen) {
    setStatus('Open a target before selecting a device', true);
    HWMonitor.state.device = '';
    document.getElementById('selDevice').value = '';
    return;
  }
  HWMonitor.state.device = document.getElementById('selDevice').value;
  if (!HWMonitor.state.device) return;
  await fetch('/api/devices/' + encodeURIComponent(HWMonitor.state.device) + '/select', { method: 'POST' });
  await onPluginDeviceChange();
  await loadDeviceData();
  highlightTreeSelection();
}

async function onDeviceChange() {
  if (!HWMonitor.state.targetOpen) {
    setStatus('Open a target before selecting a device', true);
    HWMonitor.state.device = '';
    document.getElementById('selDevice').value = '';
    return;
  }
  const device = document.getElementById('selDevice').value;
  if (!device) return;
  await withBusy('Selecting device ' + shortName(device) + '…', onDeviceChangeInner);
}

async function applyLtx() {
  const path = document.getElementById('ltxPath').value.trim();
  if (!path) { setStatus('Enter an .ltx file path', true); return; }
  if (!HWMonitor.state.targetOpen) { setStatus('Open a target first', true); return; }
  if (!HWMonitor.state.device) { setStatus('Select a device first', true); return; }
  await withBusy('Loading LTX to device…', async function () {
    const r = await fetch('/api/ltx', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ path, device: HWMonitor.state.device }),
    });
    const j = await r.json();
    setStatus(j.success ? 'LTX loaded: ' + shortName(path) : ('LTX failed: ' + (j.error || '')), !j.success);
    if (j.success) {
      window.INITIAL_CONFIG = window.INITIAL_CONFIG || {};
      window.INITIAL_CONFIG.last_ltx = path;
      await loadAllFileLists();
      await updateLtxPluginStatus();
      await refreshTree();
      await refreshPluginsIfAutoRead();
    }
  });
}

function vivadoTreeLabel() {
  const sel = document.getElementById('selVivado');
  return sel && sel.selectedOptions.length ? sel.selectedOptions[0].textContent : 'Vivado';
}

function buildMinimalTree(serverLabel) {
  return {
    type: 'vivado', name: vivadoTreeLabel(), full: '',
    children: [{ type: 'server', name: serverLabel || '(not connected)', full: '', children: [] }],
  };
}

function renderTree(tree) {
  const wrap = document.getElementById('hwTree');
  if (!tree) { wrap.innerHTML = '<p class="empty">Not connected</p>'; return; }

  function isActive(n) {
    const st = HWMonitor.state;
    if (n.type === 'server') return st.connected && n.full === st.serverUrl;
    if (n.type === 'device') return n.full === st.device;
    if (n.type === 'target') return n.full === st.target;
    return false;
  }

  function nodeEl(n) {
    const div = document.createElement('div');
    div.className = 'tree-node ' + n.type + (isActive(n) ? ' active' : '');
    const icons = {
      vivado: '⚙', server: '🖧', target: '🎯', device: '🔲',
      vio: '📊', sysmon: '🌡', tilecal_xadc: '⚡',
      sfp_ddm: '📡', tilecal_sfp_i2c: '🔌', tilecal_flash_driver: '💾',
    };
    let label = n.name;
    if (n.type === 'device' && n.part) label += ' (' + n.part + ')';
    div.innerHTML = '<span class="icon">' + (icons[n.type] || '·') + '</span><span>' + esc(label) + '</span>';
    div.title = n.full || n.name;
    div.onclick = (ev) => { ev.stopPropagation(); onTreeClick(n); };
    return div;
  }

  wrap.innerHTML = '';
  const frag = document.createDocumentFragment();
  function walk(n) {
    frag.appendChild(nodeEl(n));
    for (const c of (n.children || [])) walk(c);
  }
  walk(tree);
  wrap.appendChild(frag);
}

function highlightTreeSelection() {
  document.querySelectorAll('.tree-node').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.tree-node.device').forEach(el => {
    if (el.textContent.includes(shortName(HWMonitor.state.device))) el.classList.add('active');
  });
}

async function onTreeClick(n) {
  if (n.type === 'target' && n.full) {
    document.getElementById('selTarget').value = n.full;
    await onTargetChange();
  } else if (n.type === 'device' && n.full) {
    if (!HWMonitor.state.targetOpen) { setStatus('Open a target before selecting a device', true); return; }
    document.getElementById('selDevice').value = n.full;
    await onDeviceChange();
  } else if (n.plugin || pluginByTreeType(n.type)) {
    const tabId = n.plugin || pluginByTreeType(n.type);
    switchTab(tabId);
    if (n.type === 'sysmon' && n.full) {
      document.getElementById('selDevice').value = n.full;
      await onDeviceChange();
    }
  }
}

function isValidServerUrl(url) {
  return url && !/^WARNING:/i.test(url) && !/no matching hw_servers/i.test(url);
}

function isValidTargetPath(t) {
  return t && t.includes('/') && !t.includes(' ');
}

async function refreshTree() {
  try {
    const r = await fetch('/api/tree');
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const j = await r.json();
    const st = HWMonitor.state;
    if (typeof j.connected === 'boolean') st.connected = j.connected;
    if (isValidServerUrl(j.server_url) && st.connected) st.serverUrl = j.server_url;
    st.targets = (j.targets || []).filter(isValidTargetPath);
    if (j.devices && j.devices.length) st.devices = j.devices;
    else if (!st.connected) st.devices = [];
    if (!st.connected) {
      st.targetOpen = false; st.target = ''; st.device = '';
      st.targets = []; st.devices = [];
    } else {
      if (j.last_target && !st.target) st.target = j.last_target;
      if (j.last_device && !st.device) st.device = j.last_device;
      if (typeof j.target_open === 'boolean') st.targetOpen = j.target_open;
    }
    fillTargetSelect();
    updateTargetGatedControls();
    if (j.error) setStatus(String(j.error), true);
    if (!st.connected) { renderTree(buildMinimalTree('(not connected)')); return; }
    renderTree(j.tree || buildMinimalTree(st.serverUrl || '(connected)'));
  } catch (e) {
    const st = HWMonitor.state;
    st.connected = false; st.targetOpen = false; st.target = ''; st.device = '';
    st.targets = []; st.devices = [];
    fillTargetSelect();
    updateTargetGatedControls();
    renderTree(buildMinimalTree('(unavailable)'));
    setStatus('Hardware tree refresh failed: ' + e, true);
  }
}

async function refreshAllInner() {
  await updateLtxPluginStatus();
  await refreshAllPlugins();
  await refreshTree();
  if (HWMonitor.state.targetOpen && HWMonitor.state.device) syncPollers();
}

async function refreshAll() {
  if (!HWMonitor.state.targetOpen) {
    setStatus('Open a target to refresh monitoring data', true);
    return;
  }
  try {
    await withBusy('Refreshing monitoring data…', refreshAllInner);
    setStatus('Monitoring data refreshed');
  } catch (e) {
    setStatus('Refresh error: ' + e, true);
  }
}

async function disconnect() {
  stopAllPollers();
  await onPluginDisconnect();
  const st = HWMonitor.state;
  st.connected = false; st.targets = []; st.devices = [];
  st.target = ''; st.device = ''; st.targetOpen = false;
  fillTargetSelect();
  updateTargetGatedControls();
  renderTree(buildMinimalTree('(not connected)'));
  await withBusy('Disconnecting…', async function () {
    try { await fetch('/api/disconnect', { method: 'POST' }); } catch (_) {}
  });
  setStatus('Disconnected');
  await updateLtxPluginStatus();
}

function toggleTerminal() {
  const body = document.getElementById('termBody');
  body.classList.toggle('open');
  document.getElementById('termArrow').textContent = body.classList.contains('open') ? '▾' : '▸';
}

function updateTermHeadHint(text) {
  document.getElementById('termHint').textContent = text;
}

let consoleCursor = 0;
let tclHistory = [];
let tclHistPos = -1;
let tclDraft = '';

async function loadTclHistory() {
  try {
    const r = await fetch('/api/tcl/history');
    const j = await r.json();
    tclHistory = j.history || [];
  } catch (_) { tclHistory = []; }
}

function resetTclHistBrowse() {
  tclHistPos = -1;
  tclDraft = '';
}

async function pollConsole() {
  try {
    const r = await fetch('/api/console?after=' + consoleCursor);
    const j = await r.json();
    if (j.entries && j.entries.length) {
      const term = document.getElementById('terminal');
      for (const e of j.entries) {
        const cmd = document.createElement('div');
        cmd.className = 'term-cmd';
        cmd.textContent = '[' + e.ts + '] vivado% ' + e.cmd;
        term.appendChild(cmd);
        if (e.output) {
          const out = document.createElement('div');
          out.className = e.success ? 'term-out' : 'term-err';
          out.textContent = e.output;
          term.appendChild(out);
        }
      }
      consoleCursor = j.last_id;
      term.scrollTop = term.scrollHeight;
      updateTermHeadHint('(' + j.last_id + ' cmds)');
    }
  } catch (_) {}
}

async function restoreSession() {
  const r = await fetch('/api/session/hw_state');
  const j = await r.json();
  const st = HWMonitor.state;
  if (j.saved_hw_servers) st.servers = j.saved_hw_servers;
  fillServerSelect();
  if (j.server_url) {
    st.serverUrl = j.server_url;
    document.getElementById('selServer').value = j.server_url;
    document.getElementById('serverUrl').value = j.server_url;
  }
  if (!j.connected) return;
  st.connected = true;
  st.targets = j.targets || [];
  st.devices = j.devices || [];
  if (j.last_target) st.target = j.last_target;
  if (j.last_device) st.device = j.last_device;
  st.targetOpen = !!j.target_open;
  fillTargetSelect();
  updateTargetGatedControls();
  if (st.target) document.getElementById('selTarget').value = st.target;
  if (st.device && st.targetOpen) document.getElementById('selDevice').value = st.device;
  setStatus('Session restored — ' + (j.server_url || ''));
  if (st.target && !st.targetOpen) await onTargetChange();
  else {
    await refreshTree();
    if (st.device && st.targetOpen) await loadDeviceData();
    else await updateLtxPluginStatus();
  }
}

async function initApp(initialConfig) {
  HWMonitor.state.servers = initialConfig.hw_servers || [];
  HWMonitor.state.serverUrl = initialConfig.last_connected || '';

  const pluginsResp = await fetch('/api/plugins');
  const pluginsJson = await pluginsResp.json();
  await loadPlugins(pluginsJson.plugins || []);
  await updateLtxPluginStatus();

  loadVivadoVersions();
  fillServerSelect();
  updateTargetGatedControls();
  loadAllFileLists();
  loadTclHistory();
  refreshTree();
  restoreSession();
  pollConsole();
  setInterval(pollConsole, 800);
}

document.getElementById('termInput').addEventListener('keydown', async (ev) => {
  const input = ev.target;
  if (ev.key === 'ArrowUp') {
    ev.preventDefault();
    if (tclHistory.length === 0) return;
    if (tclHistPos === -1) tclDraft = input.value;
    tclHistPos = Math.min(tclHistPos + 1, tclHistory.length - 1);
    input.value = tclHistory[tclHistory.length - 1 - tclHistPos];
    return;
  }
  if (ev.key === 'ArrowDown') {
    ev.preventDefault();
    if (tclHistPos <= 0) { resetTclHistBrowse(); input.value = tclDraft; return; }
    tclHistPos--;
    input.value = tclHistory[tclHistory.length - 1 - tclHistPos];
    return;
  }
  if (ev.key !== 'Enter') {
    if (tclHistPos !== -1) resetTclHistBrowse();
    return;
  }
  const cmd = input.value.trim();
  if (!cmd) return;
  input.value = '';
  resetTclHistBrowse();
  const label = 'Running Tcl: ' + (cmd.length > 48 ? cmd.slice(0, 48) + '…' : cmd);
  await withBusy(label, async function () {
    const r = await fetch('/api/tcl', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ cmd }),
    });
    const j = await r.json();
    if (j.history) tclHistory = j.history;
    pollConsole();
    setStatus('Tcl command finished');
  });
});

// expose globals for inline handlers
window.switchTab = switchTab;
window.connectFlow = connectFlow;
window.onServerChange = onServerChange;
window.onTargetChange = onTargetChange;
window.onDeviceChange = onDeviceChange;
window.refreshAll = refreshAll;
window.disconnect = disconnect;
window.selectVivado = selectVivado;
window.addVivadoInstallRow = addVivadoInstallRow;
window.removeVivadoInstallRow = removeVivadoInstallRow;
window.autodetectVivadoInstalls = autodetectVivadoInstalls;
window.applyLtx = applyLtx;
window.programBit = programBit;
window.programBin = programBin;
window.refreshFileList = refreshFileList;
window.triggerUpload = triggerUpload;
window.uploadFile = uploadFile;
window.onFileSelect = onFileSelect;
window.toggleTerminal = toggleTerminal;
window.openConfigModal = openConfigModal;
window.closeConfigModal = closeConfigModal;
window.saveAppConfig = saveAppConfig;
window.savePluginConfig = savePluginConfig;
window.addServerConfigRow = addServerConfigRow;
window.removeServerConfigRow = removeServerConfigRow;
window.syncPollers = syncPollers;

document.addEventListener('DOMContentLoaded', () => {
  initApp(window.INITIAL_CONFIG || {});
});
