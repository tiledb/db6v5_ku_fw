(function () {
  const ID = 'tilecal_data_readout';
  const GAINS = ['hg', 'lg', 'fc'];
  const GAIN_COLOR = { hg: '#4f8cff', lg: '#3ecf8e', fc: '#fdba74' };
  const SAMPLE_COUNT = 16;
  const CHANNEL_COUNT = 6;
  const ADC_BITS = 14;
  const ADC12_BITS = 12;
  const BCR_MIN = 16;
  const BCR_MAX = 3564 + 16;
  const BCR_DEFAULT = BCR_MIN;

  let lastCsv = '';
  let bcrSaveTimer = null;
  let lastTables = null;
  let lastSamples = [];
  let lastView = { captured: null, operation: 'idle' };
  let lastLtxState = null;
  let lastLtxPath = '';

  function bitMode() {
    const el = document.getElementById('adcrdBitMode');
    return el && el.value === '14' ? 14 : 12;
  }

  function adcMax() {
    return (1 << bitMode()) - 1;
  }

  function displayValue(cell) {
    if (!cell || cell.raw == null) return null;
    if (bitMode() === 14) return cell.raw & ((1 << ADC_BITS) - 1);
    return (cell.raw >> (ADC_BITS - ADC12_BITS)) & ((1 << ADC12_BITS) - 1);
  }

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function parseIntFlex(text, fallback) {
    if (text == null || !String(text).trim()) return fallback;
    const t = String(text).trim().toLowerCase();
    const n = parseInt(t.startsWith('0x') ? t : t, t.startsWith('0x') ? 16 : 10);
    return Number.isFinite(n) ? n : fallback;
  }

  function bcrLimits() {
    const meta = (HWMonitor.pluginMeta || []).find(function (p) { return p.id === ID; });
    const min = meta && meta.bcr_number_min != null ? Number(meta.bcr_number_min) : BCR_MIN;
    const max = meta && meta.bcr_number_max != null ? Number(meta.bcr_number_max) : BCR_MAX;
    return {
      min: Number.isFinite(min) ? min : BCR_MIN,
      max: Number.isFinite(max) ? max : BCR_MAX,
    };
  }

  function clampBcr(n) {
    const lim = bcrLimits();
    if (!Number.isFinite(n)) return BCR_DEFAULT;
    return Math.max(lim.min, Math.min(lim.max, n));
  }

  function currentBcrNumber() {
    const el = document.getElementById('adcrdBcr');
    const parsed = parseIntFlex(el && el.value, NaN);
    if (Number.isFinite(parsed)) return clampBcr(parsed);
    const meta = (HWMonitor.pluginMeta || []).find(function (p) { return p.id === ID; });
    const fallback = meta && meta.bcr_number != null ? Number(meta.bcr_number) : BCR_DEFAULT;
    return clampBcr(Number.isFinite(fallback) ? fallback : BCR_DEFAULT);
  }

  function applyBcrToInput(n) {
    const el = document.getElementById('adcrdBcr');
    if (!el) return clampBcr(n);
    const v = clampBcr(n);
    const lim = bcrLimits();
    el.min = String(lim.min);
    el.max = String(lim.max);
    el.value = String(v);
    return v;
  }

  function currentBcrOffset() {
    const el = document.getElementById('adcrdBcrOffset');
    if (el && String(el.value).trim() !== '') {
      const n = parseInt(el.value, 10);
      if (Number.isFinite(n)) return n;
    }
    const meta = (HWMonitor.pluginMeta || []).find(function (p) { return p.id === ID; });
    const fallback = meta && meta.bcr_offset != null ? Number(meta.bcr_offset) : -16;
    return Number.isFinite(fallback) ? fallback : -16;
  }

  function fmtBcr(n) {
    const v = (Number(n) >>> 0);
    return '0x' + v.toString(16).toUpperCase().padStart(8, '0') + ' (' + v + ')';
  }

  async function persistBcrSettings(opts) {
    opts = opts || {};
    const offset = currentBcrOffset();
    let bcr;
    if (opts.clamp) {
      bcr = applyBcrToInput(currentBcrNumber());
    } else {
      const parsed = parseIntFlex(document.getElementById('adcrdBcr') && document.getElementById('adcrdBcr').value, NaN);
      if (!Number.isFinite(parsed)) return;
      const lim = bcrLimits();
      if (parsed < lim.min || parsed > lim.max) return;
      bcr = parsed;
    }
    const meta = (HWMonitor.pluginMeta || []).find(function (p) { return p.id === ID; });
    if (meta) {
      meta.bcr_offset = offset;
      meta.bcr_number = bcr;
    }
    try {
      await fetch('/api/plugins/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          plugins: { tilecal_data_readout: { bcr_offset: offset, bcr_number: bcr } },
        }),
      });
    } catch (e) {
      HWMonitor.setStatus('Failed to save BCR settings: ' + e, true);
    }
    if (opts.rerender && lastView) renderResult(lastView);
  }

  function persistBcrNumberSoon() {
    if (bcrSaveTimer) clearTimeout(bcrSaveTimer);
    bcrSaveTimer = setTimeout(function () {
      bcrSaveTimer = null;
      persistBcrSettings({ rerender: true });
    }, 300);
  }

  function pluginReady() {
    return HWMonitor.ltxPluginStatus[ID] === 'ok';
  }

  function emptyCell() {
    return { raw: null, raw_hex: '—', adc12: null, adc12_hex: '—', adc14: null, adc14_hex: '—' };
  }

  function emptyTables() {
    const tables = {};
    GAINS.forEach(function (gain) {
      const entries = [];
      for (let s = 0; s < SAMPLE_COUNT; s++) {
        const channels = [];
        for (let ch = 0; ch < CHANNEL_COUNT; ch++) channels.push(emptyCell());
        entries.push({ sample: s, channels: channels });
      }
      tables[gain] = { label: gain.toUpperCase(), entries: entries };
    });
    return tables;
  }

  function tablesHaveSamples(tables) {
    if (!tables) return false;
    return GAINS.some(function (gain) {
      const entries = tables[gain] && tables[gain].entries;
      if (!entries || !entries.length) return false;
      return entries.some(function (row) {
        return (row.channels || []).some(function (cell) { return cell && cell.raw != null; });
      });
    });
  }

  function resolveTables(data) {
    const incoming = (data && data.tables) || {};
    if (tablesHaveSamples(incoming) || (data && data.samples && data.samples.length)) {
      lastTables = incoming;
      lastSamples = data.samples || [];
      return incoming;
    }
    return lastTables || emptyTables();
  }

  function channelSeries(tables, gain, ch) {
    const entries = (tables[gain] && tables[gain].entries) || [];
    const pts = [];
    for (let s = 0; s < SAMPLE_COUNT; s++) {
      const cell = ((entries[s] && entries[s].channels) || [])[ch] || {};
      pts.push(displayValue(cell));
    }
    return pts;
  }

  function flag(label, val, warn) {
    const cls = val ? (warn ? 'flag-warn' : 'flag-true') : 'flag-false';
    const text = val == null ? '—' : (val ? 'yes' : 'no');
    return '<span class="' + cls + '">' + esc(label) + ': ' + text + '</span>';
  }

  function cellStyle(adc) {
    if (adc == null) return '';
    const t = Math.max(0, Math.min(1, adc / adcMax()));
    return 'background: rgba(79, 140, 255, ' + (0.06 + 0.5 * t).toFixed(3) + ')';
  }

  function analogPlot(gain, ch, values) {
    const color = GAIN_COLOR[gain] || '#8b9bb4';
    const ymax = adcMax();
    const W = 320;
    const H = 118;
    const L = 44;
    const R = 8;
    const T = 10;
    const B = 22;
    const innerW = W - L - R;
    const innerH = H - T - B;
    const xOf = function (i) {
      return L + (SAMPLE_COUNT <= 1 ? innerW / 2 : i * innerW / (SAMPLE_COUNT - 1));
    };
    const yOf = function (v) {
      return T + innerH - (Math.max(0, Math.min(ymax, v)) / ymax) * innerH;
    };

    let grid = '';
    [0, Math.floor(ymax / 2), ymax].forEach(function (tick) {
      const y = yOf(tick);
      grid += '<line x1="' + L + '" y1="' + y + '" x2="' + (W - R) + '" y2="' + y +
        '" stroke="#2a3654" stroke-width="1"/>';
      grid += '<text x="' + (L - 4) + '" y="' + (y + 3) +
        '" text-anchor="end" fill="#8b9bb4" font-size="8">' + tick + '</text>';
    });
    for (let s = 0; s < SAMPLE_COUNT; s += 5) {
      const x = xOf(s);
      grid += '<text x="' + x + '" y="' + (H - 6) +
        '" text-anchor="middle" fill="#8b9bb4" font-size="8">' + s + '</text>';
    }

    let d = '';
    let started = false;
    values.forEach(function (v, i) {
      if (v == null) {
        started = false;
        return;
      }
      d += (started ? ' L' : ' M') + xOf(i).toFixed(1) + ' ' + yOf(v).toFixed(1);
      started = true;
    });
    let dots = '';
    values.forEach(function (v, i) {
      if (v == null) return;
      dots += '<circle cx="' + xOf(i).toFixed(1) + '" cy="' + yOf(v).toFixed(1) +
        '" r="2.1" fill="' + color + '"/>';
    });
    const path = d
      ? '<path d="' + d.trim() + '" fill="none" stroke="' + color + '" stroke-width="1.5"/>'
      : '';

    return '<div class="adcrd-plot adcrd-plot-analog">' +
      '<h3>' + esc(gain.toUpperCase()) + ' Ch' + ch + '</h3>' +
      '<svg viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' +
      grid + path + dots + '</svg></div>';
  }

  function analogGrid(gain, tables) {
    let html = '<div class="adcrd-plot-section"><h2>' + esc(gain.toUpperCase()) +
      ' · value vs sample (' + bitMode() + '-bit, 0–' + adcMax() + ')</h2><div class="adcrd-analog-grid">';
    for (let ch = 0; ch < CHANNEL_COUNT; ch++) {
      html += analogPlot(gain, ch, channelSeries(tables, gain, ch));
    }
    html += '</div></div>';
    return html;
  }

  function bitsPerSample() {
    return bitMode();
  }

  function fcBits(tables, ch) {
    const entries = (tables.fc && tables.fc.entries) || [];
    const width = bitsPerSample();
    const shift = ADC_BITS - width;
    const bits = [];
    for (let s = 0; s < SAMPLE_COUNT; s++) {
      const cell = ((entries[s] && entries[s].channels) || [])[ch] || {};
      const word = cell.raw == null ? null : ((cell.raw >> shift) & ((1 << width) - 1));
      for (let b = 0; b < width; b++) {
        bits.push(word == null ? null : ((word >> b) & 1));
      }
    }
    return bits;
  }

  function fcDigitalPlot(ch, bits) {
    const color = GAIN_COLOR.fc;
    const W = 720;
    const H = 40;
    const L = 18;
    const R = 8;
    const T = 5;
    const B = 5;
    const width = bitsPerSample();
    const innerW = W - L - R;
    const innerH = H - T - B;
    const nPts = SAMPLE_COUNT * width;
    const xOf = function (idx) {
      return L + (idx / nPts) * innerW;
    };
    const yOf = function (bit) {
      const one = T + innerH * 0.18;
      const zero = T + innerH * 0.82;
      return bit ? one : zero;
    };

    let grid = '';
    grid += '<line x1="' + L + '" y1="' + yOf(0) + '" x2="' + (W - R) + '" y2="' + yOf(0) +
      '" stroke="#2a3654" stroke-width="1"/>';
    grid += '<line x1="' + L + '" y1="' + yOf(1) + '" x2="' + (W - R) + '" y2="' + yOf(1) +
      '" stroke="#2a3654" stroke-width="1" stroke-dasharray="2 3"/>';
    grid += '<text x="4" y="' + (yOf(1) + 3) +
      '" text-anchor="start" fill="#8b9bb4" font-size="8">1</text>';
    grid += '<text x="4" y="' + (yOf(0) + 3) +
      '" text-anchor="start" fill="#8b9bb4" font-size="8">0</text>';

    for (let s = 0; s <= SAMPLE_COUNT; s++) {
      const x = xOf(s * width);
      grid += '<line x1="' + x + '" y1="' + T + '" x2="' + x + '" y2="' + (T + innerH) +
        '" stroke="#2a3654" stroke-width="' + (s === 0 || s === SAMPLE_COUNT ? 1.2 : 0.7) + '"/>';
    }

    let d = '';
    let prev = null;
    for (let i = 0; i < bits.length; i++) {
      const v = bits[i];
      if (v == null) {
        prev = null;
        continue;
      }
      const x0 = xOf(i);
      const x1 = xOf(i + 1);
      const y = yOf(v);
      if (prev == null) {
        d += ' M' + x0.toFixed(1) + ' ' + y.toFixed(1);
      } else if (prev !== v) {
        d += ' L' + x0.toFixed(1) + ' ' + yOf(prev).toFixed(1);
        d += ' L' + x0.toFixed(1) + ' ' + y.toFixed(1);
      }
      d += ' L' + x1.toFixed(1) + ' ' + y.toFixed(1);
      prev = v;
    }

    let dots = '';
    bits.forEach(function (v, i) {
      if (v == null) return;
      const cx = ((xOf(i) + xOf(i + 1)) / 2).toFixed(1);
      dots += '<circle cx="' + cx + '" cy="' + yOf(v).toFixed(1) +
        '" r="1.35" fill="' + color + '"/>';
    });

    const path = d
      ? '<path d="' + d.trim() + '" fill="none" stroke="' + color + '" stroke-width="1.4"/>'
      : '';

    return '<div class="adcrd-fc-row">' +
      '<div class="adcrd-fc-label">FC Ch' + ch + '</div>' +
      '<svg viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' +
      grid + path + dots + '</svg></div>';
  }

  function fcAxis() {
    const W = 720;
    const H = 22;
    const L = 18;
    const R = 8;
    const width = bitsPerSample();
    const innerW = W - L - R;
    const nPts = SAMPLE_COUNT * width;
    const xOf = function (idx) {
      return L + (idx / nPts) * innerW;
    };
    let ticks = '';
    for (let s = 0; s < SAMPLE_COUNT; s++) {
      const mid = xOf(s * width + width / 2);
      ticks += '<text x="' + mid + '" y="14" text-anchor="middle" fill="#8b9bb4" font-size="8">' +
        s + '</text>';
    }
    return '<div class="adcrd-fc-row adcrd-fc-axis">' +
      '<div class="adcrd-fc-label">sample</div>' +
      '<svg viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' + ticks + '</svg></div>';
  }

  function fcStack(tables) {
    let html = '<div class="adcrd-plot-section">' +
      '<h2>FC · sampled clock (' + bitsPerSample() + ' bits / sample, bit 0 LSB left → bit ' +
      (bitsPerSample() - 1) + ' right)</h2>' +
      '<div class="adcrd-fc-stack">';
    for (let ch = 0; ch < CHANNEL_COUNT; ch++) {
      html += fcDigitalPlot(ch, fcBits(tables, ch));
    }
    html += fcAxis();
    html += '</div></div>';
    return html;
  }

  function buildCsv(tables) {
    const lines = ['sample,channel,hg,lg,fc,hg_raw,lg_raw,fc_raw'];
    for (let s = 0; s < SAMPLE_COUNT; s++) {
      for (let ch = 0; ch < CHANNEL_COUNT; ch++) {
        const cols = [String(s), String(ch)];
        GAINS.forEach(function (gain) {
          const cell = (((tables[gain] || {}).entries || [])[s] || {}).channels || [];
          const val = displayValue(cell[ch] || emptyCell());
          cols.push(val == null ? '' : String(val));
        });
        GAINS.forEach(function (gain) {
          const cell = (((tables[gain] || {}).entries || [])[s] || {}).channels || [];
          const raw = (cell[ch] || {}).raw;
          cols.push(raw == null ? '' : String(raw));
        });
        lines.push(cols.join(','));
      }
    }
    return lines.join('\n') + '\n';
  }

  function renderTable(gain, tables) {
    const fallback = emptyTables()[gain];
    const block = (tables && tables[gain] && tables[gain].entries && tables[gain].entries.length)
      ? tables[gain]
      : fallback;
    const nCh = CHANNEL_COUNT;
    let html = '<div class="adcrd-table-wrap"><h3>' + esc(block.label || gain.toUpperCase()) +
      ' (' + bitMode() + '-bit ADC)</h3><table class="adcrd-samples"><tr><th>Sample</th>';
    for (let ch = 0; ch < nCh; ch++) html += '<th>Ch' + ch + '</th>';
    html += '</tr>';
    for (let s = 0; s < SAMPLE_COUNT; s++) {
      const row = (block.entries && block.entries[s]) || { sample: s, channels: [] };
      html += '<tr><td class="samp">' + s + '</td>';
      for (let ch = 0; ch < nCh; ch++) {
        const cell = (row.channels || [])[ch] || emptyCell();
        const adc = displayValue(cell);
        const title = cell.raw_hex && cell.raw_hex !== '—' ? ('14-bit VIO ' + cell.raw_hex) : '';
        html += '<td style="' + cellStyle(adc) + '" title="' + esc(title) + '">' +
          (adc == null ? '—' : adc) + '</td>';
      }
      html += '</tr>';
    }
    html += '</table></div>';
    return html;
  }

  function renderResult(data) {
    const wrap = document.getElementById('wrap-tilecal_data_readout');
    if (!wrap) return;
    data = data || {};
    lastView = data;
    const tables = resolveTables(data);

    let html = '';
    if (data.errors && data.errors.length) {
      html += '<div class="adcrd-errors">' + data.errors.map(esc).join('<br>') + '</div>';
    }
    if (data.idleMessage) {
      html += '<p class="adcrd-idle">' + esc(data.idleMessage) + '</p>';
    }

    html += '<p class="adcrd-legend">' +
      'Capture arms on a 0→1 <code>data_readout.trigger</code> edge and freezes the 16-deep pipeline ' +
      'equals the requested BCR plus the configured offset (default −16, pipeline compensation). Readout muxes ' +
      '<code>sample_index</code> (0 newest … 15 oldest) and <code>channel_select</code> (0–5) onto ' +
      'the 14-bit HG/LG/FC probes. Data mode ' + bitMode() + '-bit ' +
      (bitMode() === 12 ? 'takes the 12 MSBs (bits 13:2).' : 'uses the full 14-bit word.') +
      ' Y range is 0–' + adcMax() + '.</p>';

    const offset = data.bcr_offset != null ? data.bcr_offset : currentBcrOffset();
    const requested = (data.operation !== 'status' && data.bcr_requested != null)
      ? data.bcr_requested
      : currentBcrNumber();
    const programmed = (data.operation !== 'status' && data.bcr_number != null)
      ? (data.bcr_number >>> 0)
      : ((requested + offset) >>> 0);

    html += '<div class="adcrd-flags">' +
      flag('captured', data.captured) +
      '<span>BCR requested: ' + fmtBcr(requested) + '</span>' +
      '<span>offset: ' + offset + '</span>' +
      '<span>programmed: ' + fmtBcr(programmed) + '</span>' +
      '<span>op: ' + esc(data.operation || '—') + '</span>' +
      '</div>';

    html += analogGrid('lg', tables);
    html += analogGrid('hg', tables);
    html += fcStack(tables);
    html += GAINS.map(function (g) { return renderTable(g, tables); }).join('');

    if (data.probes && Object.keys(data.probes).length) {
      html += '<div class="adcrd-probes">' +
        Object.entries(data.probes).map(function (e) {
          return esc(e[0] + ': ' + e[1]);
        }).join('<br>') + '</div>';
    }

    wrap.innerHTML = html;

    lastCsv = buildCsv(tables);
    const csvBtn = document.getElementById('adcrdCopyCsv');
    if (csvBtn) csvBtn.hidden = !tablesHaveSamples(tables);

    const hint = document.getElementById('status-tilecal_data_readout');
    if (hint) {
      const n = lastSamples.length;
      hint.textContent = data.captured
        ? ('captured' + (n ? (' · ' + n + ' samples') : ''))
        : (data.operation === 'status' ? 'not captured' : (data.operation || 'idle'));
      hint.classList.toggle('warn', !!(data.errors && data.errors.length) ||
        ((data.operation === 'trigger' || data.operation === 'trigger_readout') && data.captured === false));
      hint.classList.toggle('ok', !!data.captured && !(data.errors && data.errors.length));
    }
  }

  function showIdleMessage(message) {
    renderResult({ idleMessage: message, captured: null, operation: 'idle' });
    const hint = document.getElementById('status-tilecal_data_readout');
    if (hint) {
      hint.textContent = message;
      hint.classList.remove('warn', 'ok');
    }
  }

  async function runOp(operation, opts) {
    opts = opts || {};
    if (!HWMonitor.state.targetOpen || !HWMonitor.state.device) {
      HWMonitor.setStatus('Select a device before ADC data readout', true);
      return;
    }
    if (!pluginReady()) {
      const info = (HWMonitor.ltxPluginInfo || {})[ID] || {};
      showIdleMessage(info.message || 'Load LTX to the device before using ADC data readout.');
      return;
    }

    const body = {
      device: HWMonitor.state.device,
      operation: operation,
      bcr_number: applyBcrToInput(currentBcrNumber()),
      bcr_offset: currentBcrOffset(),
      timeout_ms: parseIntFlex(document.getElementById('adcrdTimeout') && document.getElementById('adcrdTimeout').value, 15000),
    };
    if (operation !== 'status') persistBcrSettings();

    const isStatus = operation === 'status';
    const url = isStatus
      ? '/api/plugins/tilecal_data_readout/status' + HWMonitor.deviceQuery()
      : '/api/plugins/tilecal_data_readout/execute';

    const busyLabel = operation === 'trigger' ? 'Arming ADC capture…'
      : (operation === 'readout' ? 'Reading 16×6 ADC samples…'
        : (operation === 'trigger_readout' ? 'Capturing and reading ADC samples…'
          : 'Reading captured flag…'));

    const alreadyBusy = !!(document.body && document.body.classList.contains('hw-busy'));
    const exec = async function () {
      const r = isStatus
        ? await fetch(url)
        : await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || ('HTTP ' + r.status));
      j.operation = j.operation || operation;
      const timeEl = document.getElementById('time-tilecal_data_readout');
      if (timeEl) timeEl.textContent = new Date().toLocaleTimeString();
      renderResult(j);
      if (j.errors && j.errors.length) {
        HWMonitor.setStatus('ADC readout: ' + j.errors.join('; '), true);
      } else if (operation === 'trigger' && !j.captured) {
        HWMonitor.setStatus('ADC capture did not set captured (BCR timeout?)', true);
      } else if (!opts.quiet) {
        HWMonitor.setStatus('ADC data readout ' + operation + ' complete');
      }
    };

    try {
      if (opts.quiet || alreadyBusy) await exec();
      else await HWMonitor.withBusy(busyLabel, exec);
    } catch (e) {
      HWMonitor.setStatus('ADC data readout error: ' + e, true);
    }
  }

  function onDisconnect() {
    lastCsv = '';
    lastTables = null;
    lastSamples = [];
    lastLtxState = null;
    lastLtxPath = '';
    const csvBtn = document.getElementById('adcrdCopyCsv');
    if (csvBtn) csvBtn.hidden = true;
    showIdleMessage('Disconnected.');
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_data_readout'],
    onInit() {
      const meta = (HWMonitor.pluginMeta || []).find(function (p) { return p.id === ID; });
      const offsetEl = document.getElementById('adcrdBcrOffset');
      if (offsetEl) {
        const off = meta && meta.bcr_offset != null ? Number(meta.bcr_offset) : -16;
        offsetEl.value = String(Number.isFinite(off) ? off : -16);
        offsetEl.addEventListener('change', function () { persistBcrSettings(); });
      }
      const bcrEl = document.getElementById('adcrdBcr');
      if (bcrEl) {
        const saved = meta && meta.bcr_number != null ? Number(meta.bcr_number) : BCR_DEFAULT;
        applyBcrToInput(Number.isFinite(saved) ? saved : BCR_DEFAULT);
        bcrEl.addEventListener('input', persistBcrNumberSoon);
        bcrEl.addEventListener('change', function () {
          if (bcrSaveTimer) {
            clearTimeout(bcrSaveTimer);
            bcrSaveTimer = null;
          }
          persistBcrSettings({ clamp: true, rerender: true });
        });
      }
      renderResult({ captured: null, operation: 'idle' });
      document.querySelectorAll('[data-adcrd-op]').forEach(function (btn) {
        btn.addEventListener('click', function () {
          runOp(btn.getAttribute('data-adcrd-op'));
        });
      });
      const modeEl = document.getElementById('adcrdBitMode');
      if (modeEl) {
        modeEl.addEventListener('change', function () {
          renderResult(lastView);
        });
      }
      const csvBtn = document.getElementById('adcrdCopyCsv');
      if (csvBtn) {
        csvBtn.addEventListener('click', async function () {
          if (!lastCsv) return;
          try {
            await navigator.clipboard.writeText(lastCsv);
            HWMonitor.setStatus('ADC readout CSV copied');
          } catch (e) {
            HWMonitor.setStatus('CSV copy failed: ' + e, true);
          }
        });
      }
    },
    refresh() {
      if (!pluginReady()) {
        const info = (HWMonitor.ltxPluginInfo || {})[ID] || {};
        showIdleMessage(info.message || 'Load LTX to the device before using ADC data readout.');
        return Promise.resolve();
      }
      return runOp('status');
    },
    onDisconnect,
    onDeviceChange() {
      if (!pluginReady()) {
        const info = (HWMonitor.ltxPluginInfo || {})[ID] || {};
        showIdleMessage(info.message || 'Load LTX to the device before using ADC data readout.');
        return;
      }
      return runOp('status', { quiet: true });
    },
    onLtxStatus(info) {
      const path = (HWMonitor.getLtxPath && HWMonitor.getLtxPath()) || '';
      const state = info && info.state;
      const shouldRead = state === 'ok' && (lastLtxState !== 'ok' || path !== lastLtxPath);
      lastLtxState = state || 'error';
      lastLtxPath = path;
      if (state !== 'ok') {
        showIdleMessage((info && info.message) || 'Load LTX to the device before using ADC data readout.');
        return;
      }
      if (lastView && lastView.idleMessage) {
        lastView = Object.assign({}, lastView);
        delete lastView.idleMessage;
        renderResult(lastView);
      }
      if (shouldRead && HWMonitor.state.targetOpen && HWMonitor.state.device) {
        return runOp('status', { quiet: true });
      }
    },
    onTabActivate() {},
  });
})();
