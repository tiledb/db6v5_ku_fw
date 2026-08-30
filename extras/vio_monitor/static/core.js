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
};

const pollState = HWMonitor;

function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
HWMonitor.esc = esc;

function setStatus(msg, isErr) {
  const el = document.getElementById('statusBar');
  el.textContent = msg;
  el.className = isErr ? 'err' : '';
}
HWMonitor.setStatus = setStatus;

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
  HWMonitor.plugins.set(spec.id, spec);
  if (spec.onInit) spec.onInit();
};

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
    if (!plugin.refresh) continue;
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

async function refreshAllPlugins() {
  for (const plugin of HWMonitor.plugins.values()) {
    if (plugin.refresh) await plugin.refresh();
  }
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
    if (document.querySelector('script[data-src="' + src + '"]')) {
      resolve();
      return;
    }
    const s = document.createElement('script');
    s.src = src;
    s.dataset.src = src;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error('Failed to load ' + src));
    document.head.appendChild(s);
  });
}

async function loadPlugins(pluginList) {
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

  if (HWMonitor.pluginMeta.length) {
    tabsEl.firstChild.classList.add('active');
    panelsEl.firstChild.classList.add('active');
    HWMonitor.state.activeTab = HWMonitor.pluginMeta[0].id;
  }
}

// ---- config modal ----
function openConfigModal() {
  document.getElementById('configModal').classList.add('open');
  renderPluginConfig();
}

function closeConfigModal() {
  document.getElementById('configModal').classList.remove('open');
}

async function renderPluginConfig() {
  const wrap = document.getElementById('pluginConfigList');
  wrap.innerHTML = '<p class="empty">Loading…</p>';
  const r = await fetch('/api/plugins');
  const j = await r.json();
  let html = '';
  for (const p of (j.plugins || [])) {
    html += '<label class="plugin-config-row">' +
      '<input type="checkbox" data-plugin-id="' + esc(p.id) + '"' + (p.enabled ? ' checked' : '') + '>' +
      '<span class="plugin-config-info">' +
      '<strong>' + esc(p.name) + '</strong>' +
      '<span class="plugin-config-desc">' + esc(p.description || '') + '</span>' +
      '<span class="plugin-config-meta">v' + esc(p.version || '1.0') + ' · ' + esc(p.id) + '</span>' +
      '</span></label>';
  }
  wrap.innerHTML = html || '<p class="empty">No plugins found.</p>';
}

async function savePluginConfig() {
  const toggles = document.querySelectorAll('#pluginConfigList input[data-plugin-id]');
  const plugins = {};
  toggles.forEach(el => {
    plugins[el.dataset.pluginId] = { enabled: el.checked };
  });
  const r = await fetch('/api/plugins/config', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ plugins }),
  });
  const j = await r.json();
  if (!j.success) {
    setStatus('Failed to save plugin config: ' + (j.error || ''), true);
    return;
  }
  closeConfigModal();
  setStatus('Plugin configuration saved — reloading…');
  window.location.reload();
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
  } catch (e) {
    setStatus('Failed to load .' + cfg.ext + ' file list: ' + e, true);
  }
}

async function loadAllFileLists() {
  await Promise.all(Object.keys(FILE_LIST_CFG).map(loadFileList));
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
  setStatus('Uploading ' + file.name + '…');
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
}

async function loadVivadoVersions() {
  const r = await fetch('/api/vivado/versions');
  const j = await r.json();
  const sel = document.getElementById('selVivado');
  sel.innerHTML = '';
  for (const v of (j.versions || [])) {
    const opt = document.createElement('option');
    opt.value = v.path;
    opt.textContent = v.version;
    if (v.path === j.current) opt.selected = true;
    sel.appendChild(opt);
  }
}

async function selectVivado() {
  const path = document.getElementById('selVivado').value;
  setStatus('Switching Vivado…');
  const r = await fetch('/api/vivado/select', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ path }),
  });
  const j = await r.json();
  setStatus(j.restarted ? 'Vivado restarted — reconnect required' : 'Vivado path saved', !j.success);
  await refreshTree();
}

async function programDevice(kind) {
  const st = HWMonitor.state;
  if (!st.targetOpen) { setStatus('Open a target first', true); return; }
  if (!st.device) { setStatus('Select a device first', true); return; }
  const pathId = kind === 'bit' ? 'bitPath' : 'binPath';
  const path = document.getElementById(pathId).value.trim();
  if (!path) { setStatus('Enter a .' + kind + ' file path', true); return; }
  if (!confirm('Program ' + st.device + ' with\n' + path + '?')) return;
  setStatus('Programming ' + kind.toUpperCase() + '… (this may take several minutes)');
  const r = await fetch('/api/program', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ type: kind, path, device: st.device }),
  });
  const j = await r.json();
  setStatus(
    j.success ? ('Programmed .' + kind + ': ' + shortName(path)) : ('Program failed: ' + (j.detail || j.error || '')),
    !j.success
  );
  if (j.success) { await loadAllFileLists(); await refreshAll(); }
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
  setStatus('Connecting to ' + url + '…');
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
  if (HWMonitor.state.targets.length === 1) {
    document.getElementById('selTarget').value = HWMonitor.state.targets[0];
    await onTargetChange();
  }
}

async function onTargetChange() {
  const target = document.getElementById('selTarget').value;
  if (!target) return;
  setStatus('Opening target ' + shortName(target) + '…');
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
    await onDeviceChange();
  }
  setStatus('Target open — select a device (' + HWMonitor.state.devices.length + ' found)');
  await refreshTree();
}

async function loadDeviceData() {
  if (!HWMonitor.state.device) return;
  await refreshAllPlugins();
  syncPollers();
}

async function onDeviceChange() {
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

async function applyLtx() {
  const path = document.getElementById('ltxPath').value.trim();
  if (!path) { setStatus('Enter an .ltx file path', true); return; }
  if (!HWMonitor.state.targetOpen) { setStatus('Open a target first', true); return; }
  if (!HWMonitor.state.device) { setStatus('Select a device first', true); return; }
  setStatus('Loading LTX…');
  const r = await fetch('/api/ltx', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ path, device: HWMonitor.state.device }),
  });
  const j = await r.json();
  setStatus(j.success ? 'LTX loaded: ' + shortName(path) : ('LTX failed: ' + (j.error || '')), !j.success);
  if (j.success) { await loadAllFileLists(); await refreshTree(); await refreshAll(); }
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
    const icons = { vivado: '⚙', server: '🖧', target: '🎯', device: '🔲', vio: '📊', sysmon: '🌡' };
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

async function refreshAll() {
  if (!HWMonitor.state.targetOpen) {
    setStatus('Open a target to refresh monitoring data', true);
    return;
  }
  try {
    await refreshAllPlugins();
    await refreshTree();
    if (HWMonitor.state.targetOpen && HWMonitor.state.device) syncPollers();
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
  try { await fetch('/api/disconnect', { method: 'POST' }); } catch (_) {}
  setStatus('Disconnected');
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
  }
}

async function initApp(initialConfig) {
  HWMonitor.state.servers = initialConfig.hw_servers || [];
  HWMonitor.state.serverUrl = initialConfig.last_connected || '';

  const pluginsResp = await fetch('/api/plugins');
  const pluginsJson = await pluginsResp.json();
  await loadPlugins(pluginsJson.plugins || []);

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
  const r = await fetch('/api/tcl', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ cmd }),
  });
  const j = await r.json();
  if (j.history) tclHistory = j.history;
  pollConsole();
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
window.savePluginConfig = savePluginConfig;
window.syncPollers = syncPollers;

document.addEventListener('DOMContentLoaded', () => {
  initApp(window.INITIAL_CONFIG || {});
});
