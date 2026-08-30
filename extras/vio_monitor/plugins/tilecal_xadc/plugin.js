(function () {
  const ID = 'tilecal_xadc';
  let lastAnalog = {};
  let scanAccum = {};

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function fmtNum(v, digits) {
    if (v === null || v === undefined || Number.isNaN(v)) return '—';
    return Number(v).toFixed(digits);
  }

  function formatAnalog(ch) {
    if (ch.analog === null || ch.analog === undefined) return '—';
    const unit = ch.analog_unit || '';
    if (unit === '°C') return fmtNum(ch.analog, 1) + ' °C';
    if (unit === 'mV') return fmtNum(ch.analog, 1) + ' mV';
    return fmtNum(ch.analog, 3) + (unit ? ' ' + unit : '');
  }

  function formatCurrent(ch) {
    if (!ch.has_current) return '—';
    if (ch.current === null || ch.current === undefined) return '—';
    const unit = ch.current_unit || 'mA';
    return fmtNum(ch.current, 3) + ' ' + unit;
  }

  function renderLiveScan(live) {
    const el = document.getElementById('live-tilecal_xadc');
    if (!el) return;
    if (!live || live.address_hex == null) {
      el.textContent = '';
      return;
    }
    el.textContent = 'Live VIO scan: ' + live.address_hex +
      ' raw=' + (live.raw != null ? '0x' + live.raw.toString(16).toUpperCase() : '—');
  }

  function renderChannels(channels) {
    const wrap = document.getElementById('wrap-tilecal_xadc');
    if (!wrap) return;
    if (!channels || !channels.length) {
      wrap.innerHTML = '<p class="empty">No TileCal xADC channels returned.</p>';
      return;
    }

    let html = '<p class="tilecal-legend">' +
      'Analog = raw × fa + fb · Current = analog × fg (monitor channels). ' +
      'Values from hw_sysmon (VAUXP<i>_VAUXN<i>); live VIO xadc_channel / xadc_channel_voltage overrides the scanned address.</p>';
    html += '<table class="data"><tr>' +
      '<th>Channel</th><th>Addr</th><th>Raw</th><th>Analog</th><th>Current</th><th>Source</th></tr>';

    let lastGroup = '';
    for (const ch of channels) {
      const group = ch.index < 19 ? 'On-chip &amp; VAUX monitors' :
        (ch.index < 23 ? 'Reference rails' : 'Min / max registers');
      if (group !== lastGroup) {
        html += '<tr class="section"><td colspan="6">' + group + '</td></tr>';
        lastGroup = group;
      }

      const key = ch.index;
      const changed = lastAnalog[key] !== undefined && lastAnalog[key] !== ch.analog;
      lastAnalog[key] = ch.analog;

      const isLive = ch.source && ch.source.startsWith('vio:');
      const missing = ch.raw === null || ch.raw === undefined;
      const rawHex = missing ? '—' : ('0x' + ch.raw.toString(16).toUpperCase().padStart(4, '0'));

      html += '<tr class="' +
        (missing ? 'missing ' : '') +
        (isLive ? 'current-row ' : '') +
        (changed ? 'val-changed' : '') + '">' +
        '<td class="label-col">' + esc(ch.label) + '</td>' +
        '<td class="num">' + esc(ch.address_hex) + '</td>' +
        '<td class="num">' + rawHex + '</td>' +
        '<td class="num">' + esc(formatAnalog(ch)) + '</td>' +
        '<td class="num">' + esc(formatCurrent(ch)) + '</td>' +
        '<td>' + esc(ch.source || '—') + '</td></tr>';
    }
    html += '</table>';
    wrap.innerHTML = html;
  }

  async function refresh() {
    if (!HWMonitor.state.targetOpen) return;
    try {
      const r = await fetch('/api/plugins/tilecal_xadc/data' + HWMonitor.deviceQuery());
      const ctype = r.headers.get('content-type') || '';
      if (!r.ok || !ctype.includes('json')) {
        throw new Error(
          'API returned HTTP ' + r.status +
          ' — restart python3 app.py after adding or updating plugins'
        );
      }
      const j = await r.json();
      const timeEl = document.getElementById('time-tilecal_xadc');
      if (timeEl) {
        timeEl.textContent = 'Updated ' + new Date().toLocaleTimeString();
      }
      renderLiveScan(j.live_scan);
      renderChannels(j.channels);
    } catch (e) {
      HWMonitor.setStatus('TileCal xADC refresh error: ' + e, true);
    }
  }

  function onDisconnect() {
    lastAnalog = {};
    scanAccum = {};
    renderLiveScan(null);
    const wrap = document.getElementById('wrap-tilecal_xadc');
    if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
    const live = document.getElementById('live-tilecal_xadc');
    if (live) live.textContent = '';
  }

  function onDeviceChange() {
    lastAnalog = {};
    scanAccum = {};
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_xadc'],
    onInit() {
      const btn = document.querySelector('[data-refresh="' + ID + '"]');
      if (btn) btn.addEventListener('click', refresh);
    },
    refresh,
    onDisconnect,
    onDeviceChange,
    onTabActivate() {},
  });
})();
