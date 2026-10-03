/* IPBus monitor shell: connection, both-side tree, plugin loader. */
window.HWMonitor = {
  plugins: new Map(),
  pluginMeta: [],
  state: { connected: false, controlhub: '', ppr: '', md: 0, activeTab: null },
  history: { controlhubs: [], pprs: [] },
  pollTimers: {},
  pollBusy: {},
};

const HW = HWMonitor;
const busyStack = [];

function esc(s) {
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
HW.esc = esc;

function updateBusyUI() {
  const active = busyStack.length > 0;
  const label = active ? busyStack[busyStack.length - 1] : '';
  const overlay = document.getElementById('busyOverlay');
  const labelEl = document.getElementById('busyLabel');
  const bar = document.getElementById('statusBar');
  const spinner = document.getElementById('statusSpinner');
  const text = document.getElementById('statusText');
  if (overlay) {
    overlay.classList.toggle('hidden', !active);
    overlay.setAttribute('aria-busy', active ? 'true' : 'false');
  }
  if (labelEl) labelEl.textContent = label || 'Working…';
  if (bar) bar.classList.toggle('busy', active);
  if (spinner) spinner.classList.toggle('hidden', !active);
  if (text && active) text.textContent = label;
}

function setBusy(label) {
  busyStack.push(label);
  updateBusyUI();
}
function clearBusy() {
  if (busyStack.length) busyStack.pop();
  updateBusyUI();
}
function clearAllBusy() {
  busyStack.length = 0;
  updateBusyUI();
}
async function withBusy(label, fn) {
  setBusy(label);
  try {
    return await fn();
  } finally {
    clearBusy();
  }
}
HW.withBusy = withBusy;

function setStatus(msg, isErr) {
  const bar = document.getElementById('statusBar');
  const text = document.getElementById('statusText');
  if (text) text.textContent = msg;
  if (bar) bar.className = 'status-bar' + (isErr ? ' err' : '') + (busyStack.length ? ' busy' : '');
  if (isErr) clearAllBusy();
}
HW.setStatus = setStatus;

async function fetchJson(url, opts) {
  const response = await fetch(url, opts);
  const ctype = response.headers.get('content-type') || '';
  const body = ctype.includes('json') ? await response.json() : { error: await response.text() };
  if (!response.ok || body.success === false) {
    throw new Error(body.error || ('HTTP ' + response.status));
  }
  return body;
}
HW.fetchJson = fetchJson;

function loadScript(src) {
  return new Promise(function (resolve, reject) {
    const existing = document.querySelector('script[src="' + src + '"]');
    if (existing) { resolve(); return; }
    const script = document.createElement('script');
    script.src = src;
    script.onload = resolve;
    script.onerror = function () { reject(new Error('Failed to load ' + src)); };
    document.body.appendChild(script);
  });
}

function loadStylesheet(href) {
  if (document.querySelector('link[href="' + href + '"]')) return;
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = href;
  document.head.appendChild(link);
}

HW.registerPlugin = function (spec) {
  const wrapped = Object.assign({}, spec);
  if (spec.refresh) {
    const orig = spec.refresh;
    wrapped.refresh = async function (manual) {
      const run = async function () {
        try {
          await orig();
        } catch (err) {
          setStatus((spec.id || 'plugin') + ': ' + (err.message || err), true);
        }
      };
      if (HW.pollBusy[spec.id]) return;
      HW.pollBusy[spec.id] = true;
      try {
        if (manual) await withBusy(spec.refreshLabel || ('Reading ' + spec.id + '…'), run);
        else await run();
      } finally {
        HW.pollBusy[spec.id] = false;
      }
    };
  }
  HW.plugins.set(spec.id, wrapped);
  if (spec.onInit) {
    Promise.resolve(spec.onInit()).catch(function (err) {
      setStatus(spec.id + ' init: ' + err, true);
    });
  }
};

/** Notify every plugin that the selected mini-drawer changed. */
HW.notifyMdChange = function (md) {
  const mdI = Number(md) || 0;
  HW.state.md = mdI;
  HW.plugins.forEach(function (plugin) {
    if (!plugin || typeof plugin.onMdChange !== 'function') return;
    try {
      plugin.onMdChange(mdI);
    } catch (err) {
      setStatus((plugin.id || 'plugin') + ' MD change: ' + (err.message || err), true);
    }
  });
};

function bindRefreshButtons() {
  document.querySelectorAll('[data-refresh]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      const plugin = HW.plugins.get(btn.dataset.refresh);
      if (plugin && plugin.refresh) plugin.refresh(true);
    });
  });
}

function syncPollers() {
  document.querySelectorAll('[data-poll-rate]').forEach(function (sel) {
    const id = sel.dataset.pollRate;
    clearInterval(HW.pollTimers[id]);
    if (!sel.value || sel.value === 'off') return;
    const seconds = Number(sel.value);
    if (!Number.isFinite(seconds) || seconds <= 0) return;
    HW.pollTimers[id] = setInterval(function () {
      const plugin = HW.plugins.get(id);
      if (plugin && plugin.refresh && HW.state.connected) plugin.refresh(false);
    }, seconds * 1000);
  });
}

function switchTab(id) {
  HW.state.activeTab = id;
  document.querySelectorAll('.tab').forEach(function (tab) {
    tab.classList.toggle('active', tab.dataset.tab === id);
  });
  document.querySelectorAll('.tab-panel').forEach(function (panel) {
    panel.classList.toggle('active', panel.dataset.plugin === id);
  });
  const plugin = HW.plugins.get(id);
  if (plugin && plugin.onTabActivate) plugin.onTabActivate();
}

async function loadPlugins(list) {
  HW.pluginMeta = list.filter(function (p) { return p.enabled; });
  const tabs = document.getElementById('pluginTabs');
  const panels = document.getElementById('pluginPanels');
  tabs.innerHTML = '';
  panels.innerHTML = '';
  const external = new Set();
  HW.pluginMeta.forEach(function (meta) {
    (meta.assets.external_scripts || []).forEach(function (src) { external.add(src); });
  });
  for (const src of external) {
    try { await loadScript(src); } catch (err) { console.warn(err); }
  }
  for (const meta of HW.pluginMeta) {
    (meta.assets.styles || []).forEach(function (css) {
      loadStylesheet('/plugins/' + meta.id + '/assets/' + css);
    });
    const tab = document.createElement('div');
    tab.className = 'tab';
    tab.dataset.tab = meta.id;
    tab.textContent = meta.name;
    tab.onclick = function () { switchTab(meta.id); };
    tabs.appendChild(tab);
    const panel = document.createElement('div');
    panel.id = 'panel-' + meta.id;
    panel.className = 'tab-panel';
    panel.dataset.plugin = meta.id;
    const response = await fetch('/plugins/' + meta.id + '/assets/' + meta.assets.panel);
    panel.innerHTML = await response.text();
    panels.appendChild(panel);
    panel.querySelectorAll('[data-poll-rate]').forEach(function (sel) {
      sel.addEventListener('change', syncPollers);
    });
    await loadScript('/plugins/' + meta.id + '/assets/' + meta.assets.script);
  }
  bindRefreshButtons();
  if (HW.pluginMeta.length) switchTab(HW.pluginMeta[0].id);
}

function renderTree(tree) {
  const wrap = document.getElementById('hwTree');
  if (!tree) {
    wrap.innerHTML = '<p class="empty">Not connected</p>';
    return;
  }
  wrap.innerHTML = '';
  const icons = {
    ppr: '🖧', md: '▣', side: '◆', properties: 'ℹ', registers: '☰',
    tilecal_xadc: '⚡', sfp_ddm: '📡', tilecal_sfp_i2c: '🔌',
    tilecal_gbtx_regs: '🧬', tilecal_flash_driver: '💾',
    tilecal_data_readout: '📈', tilecal_cis: '✦', tilecal_cis_pulse_scan: '↯',
  };
  function walk(node) {
    const div = document.createElement('div');
    div.className = 'tree-node ' + node.type;
    div.innerHTML = '<span class="icon">' + (icons[node.type] || '·') + '</span><span>' + esc(node.name) + '</span>';
    div.title = node.full || node.name;
    div.onclick = function (event) {
      event.stopPropagation();
      if (node.plugin) switchTab(node.plugin);
    };
    wrap.appendChild(div);
    (node.children || []).forEach(walk);
  }
  walk(tree);
}

async function refreshTree() {
  const body = await fetchJson('/api/tree');
  HW.state.connected = !!body.connected;
  renderTree(body.tree);
}

function mdLabel(index) {
  return Number(index) + 1;
}

function escAttr(s) {
  return esc(s).replace(/"/g, '&quot;');
}

function closeCombos() {
  document.querySelectorAll('.combo-menu').forEach(function (menu) {
    menu.classList.add('hidden');
  });
}

function renderCombo(combo) {
  const menu = combo.querySelector('.combo-menu');
  const items = HW.history[combo.dataset.history] || [];
  if (!items.length) {
    menu.innerHTML = '<div class="combo-empty">No saved addresses</div>';
    return;
  }
  menu.innerHTML = items.map(function (item) {
    return '<div class="combo-row">' +
      '<button type="button" class="combo-pick" data-value="' + escAttr(item) + '">' + esc(item) + '</button>' +
      '<button type="button" class="combo-remove" data-value="' + escAttr(item) + '" title="Remove">−</button>' +
      '</div>';
  }).join('');
}

function applyHistory(body) {
  HW.history.controlhubs = body.controlhubs || HW.history.controlhubs;
  HW.history.pprs = body.pprs || HW.history.pprs;
  document.querySelectorAll('.combo').forEach(renderCombo);
}

async function connectFlow() {
  const payload = {
    controlhub: document.getElementById('controlhub').value.trim() || 'localhost',
    ppr: document.getElementById('pprIp').value.trim() || '192.168.0.1',
    md: Number(document.getElementById('selMd').value),
  };
  let connected;
  try {
    connected = await withBusy('Connecting to ' + payload.ppr + '…', async function () {
      return fetchJson('/api/connect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    });
  } catch (err) {
    setStatus(String(err.message || err), true);
    return;
  }
  applyHistory(connected);
  HW.state.connected = true;
  HW.state.md = payload.md;
  setStatus('Connected to ' + payload.ppr + ' MD ' + mdLabel(payload.md));
  await refreshTree();
  HW.plugins.forEach(function (plugin) {
    if (plugin && typeof plugin.onConnect === 'function') {
      try { plugin.onConnect(); } catch (err) {
        setStatus((plugin.id || 'plugin') + ' connect: ' + (err.message || err), true);
      }
    }
  });
  const active = HW.plugins.get(HW.state.activeTab);
  if (active && active.refresh && active.id !== 'tilecal_data_readout' &&
      active.id !== 'tilecal_cis' && active.id !== 'tilecal_cis_pulse_scan') {
    active.refresh(true);
  }
}

async function disconnect() {
  try {
    await fetchJson('/api/disconnect', { method: 'POST' });
  } catch (err) {
    setStatus(String(err.message || err), true);
  }
  HW.state.connected = false;
  for (const plugin of HW.plugins.values()) {
    if (plugin.onDisconnect) plugin.onDisconnect();
  }
  renderTree(null);
  setStatus('Disconnected');
}

function refreshActive() {
  const plugin = HW.plugins.get(HW.state.activeTab);
  if (plugin && plugin.refresh) plugin.refresh(true);
}

function toggleTerminal() {
  const body = document.getElementById('termBody');
  const arrow = document.getElementById('termArrow');
  const open = body.classList.toggle('open');
  arrow.textContent = open ? '▾' : '▸';
}

function renderConsole(lines) {
  const term = document.getElementById('terminal');
  term.innerHTML = (lines || []).map(function (line) {
    const cls = line.error ? 'term-err' : (String(line.text).startsWith('>') ? 'term-cmd' : 'term-out');
    return '<div class="' + cls + '">' + esc(line.t) + '  ' + esc(line.text) + '</div>';
  }).join('');
  term.scrollTop = term.scrollHeight;
}

async function pollConsole() {
  try {
    const body = await fetchJson('/api/console');
    renderConsole(body.lines);
  } catch (err) {
    /* console poll is best-effort */
  }
}

async function sendConsole() {
  const input = document.getElementById('termInput');
  const command = input.value.trim();
  if (!command) return;
  input.value = '';
  try {
    const body = await fetchJson('/api/console', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ command: command }),
    });
    renderConsole(body.lines);
  } catch (err) {
    setStatus(String(err.message || err), true);
    pollConsole();
  }
}

function openConfigModal() {
  const list = document.getElementById('pluginConfigList');
  list.innerHTML = HW.pluginMetaAll.map(function (meta, index) {
    return '<div class="plugin-config-row" data-id="' + esc(meta.id) + '">' +
      '<label class="plugin-config-main"><input type="checkbox" ' + (meta.enabled ? 'checked' : '') + '>' +
      '<span class="plugin-config-body"><strong>' + esc(meta.name) + '</strong>' +
      '<span class="plugin-config-desc">' + esc(meta.description) + '</span></span></label></div>';
  }).join('');
  document.getElementById('configModal').classList.add('open');
}
function closeConfigModal() {
  document.getElementById('configModal').classList.remove('open');
}
async function savePluginConfig() {
  const plugins = [];
  document.querySelectorAll('#pluginConfigList .plugin-config-row').forEach(function (row, index) {
    plugins.push({
      id: row.dataset.id,
      enabled: row.querySelector('input').checked,
      order: (index + 1) * 10,
    });
  });
  await fetchJson('/api/plugins/config', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ plugins: plugins }),
  });
  location.reload();
}

document.getElementById('selMd').addEventListener('change', async function () {
  if (!HW.state.connected) return;
  try {
    const md = Number(document.getElementById('selMd').value);
    await fetchJson('/api/md', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ md: md }),
    });
    HW.notifyMdChange(md);
    await refreshTree();
    setStatus('Selected MD ' + mdLabel(HW.state.md));
    const active = HW.plugins.get(HW.state.activeTab);
    if (active && active.refresh && HW.state.connected) {
      // Soft refresh for live tabs; readout restores its own per-MD cache instead.
      if (active.id !== 'tilecal_data_readout' && active.id !== 'tilecal_cis' &&
          active.id !== 'tilecal_cis_pulse_scan') {
        active.refresh(false);
      }
    }
  } catch (err) {
    setStatus(String(err.message || err), true);
  }
});

document.getElementById('termInput').addEventListener('keydown', function (event) {
  if (event.key === 'Enter') sendConsole();
});

document.querySelectorAll('.combo').forEach(function (combo) {
  const input = combo.querySelector('input');
  const menu = combo.querySelector('.combo-menu');
  combo.querySelector('.combo-toggle').addEventListener('click', function (event) {
    event.stopPropagation();
    const willOpen = menu.classList.contains('hidden');
    closeCombos();
    if (willOpen) menu.classList.remove('hidden');
  });
  menu.addEventListener('click', async function (event) {
    const remove = event.target.closest('.combo-remove');
    const pick = event.target.closest('.combo-pick');
    if (remove) {
      event.stopPropagation();
      try {
        const body = await fetchJson('/api/history', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            kind: combo.dataset.history === 'controlhubs' ? 'controlhub' : 'ppr',
            value: remove.dataset.value,
          }),
        });
        applyHistory(body);
        if (input.value === remove.dataset.value) {
          input.value = combo.dataset.history === 'controlhubs' ? body.controlhub : body.ppr;
        }
        menu.classList.remove('hidden');
      } catch (err) {
        setStatus(String(err.message || err), true);
      }
      return;
    }
    if (pick) {
      input.value = pick.dataset.value;
      closeCombos();
    }
  });
});

document.addEventListener('click', function (event) {
  if (!event.target.closest('.combo')) closeCombos();
});

async function boot() {
  const cfg = window.INITIAL_CONFIG || {};
  HW.history = {
    controlhubs: cfg.controlhubs || ['localhost'],
    pprs: cfg.pprs || ['192.168.0.1'],
  };
  document.querySelectorAll('.combo').forEach(renderCombo);
  document.getElementById('controlhub').value = cfg.controlhub || 'localhost';
  document.getElementById('pprIp').value = cfg.ppr || '192.168.0.1';
  document.getElementById('selMd').value = String(cfg.md == null ? 0 : cfg.md);
  const listed = await fetchJson('/api/plugins');
  HW.pluginMetaAll = listed.plugins || [];
  await loadPlugins(HW.pluginMetaAll);
  const status = await fetchJson('/api/status');
  setStatus(status.connected ? 'Connected' : 'Ready · ' + status.python.split('/').slice(-3).join('/'));
  setInterval(pollConsole, 2000);
  pollConsole();
}

boot().catch(function (err) {
  setStatus('Startup failed: ' + err, true);
});
