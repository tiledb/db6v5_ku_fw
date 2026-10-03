(function () {
  const ID = 'tilecal_cis';
  const PREFS_KEY = 'ipbus_monitor.tilecal_cis.prefs';
  const GAIN_COLOR = { hg: '#4f8cff', lg: '#3ecf8e' };
  const Y_MAX = 4095;
  const FORM_IDS = [
    'cisBcr', 'cisSamples', 'cisDac', 'cisCap', 'cisPed',
    'cisBcidCharge', 'cisBcidDischarge', 'cisDbSide', 'cisPhase', 'cisSkipConfig',
  ];

  let last = null;
  let lastCsv = '';

  function esc(s) { return HWMonitor.esc(s); }

  function num(id, fallback) {
    const el = document.getElementById(id);
    const v = Number(el && el.value);
    return Number.isFinite(v) ? v : fallback;
  }

  function collectPrefs() {
    const prefs = {};
    FORM_IDS.forEach(function (id) {
      const el = document.getElementById(id);
      if (!el) return;
      prefs[id] = el.type === 'checkbox' ? !!el.checked : el.value;
    });
    return prefs;
  }

  function savePrefs() {
    try {
      localStorage.setItem(PREFS_KEY, JSON.stringify(collectPrefs()));
    } catch (err) { /* ignore quota / private mode */ }
  }

  function loadPrefs() {
    try {
      const raw = localStorage.getItem(PREFS_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (err) {
      return null;
    }
  }

  function applyPrefs(prefs) {
    if (!prefs || typeof prefs !== 'object') return;
    FORM_IDS.forEach(function (id) {
      if (prefs[id] == null) return;
      const el = document.getElementById(id);
      if (!el) return;
      if (el.type === 'checkbox') {
        el.checked = !!prefs[id];
      } else {
        el.value = String(prefs[id]);
      }
    });
  }

  function bindPrefs() {
    FORM_IDS.forEach(function (id) {
      const el = document.getElementById(id);
      if (!el) return;
      el.addEventListener('change', savePrefs);
      if (el.tagName === 'INPUT' && el.type !== 'checkbox') {
        el.addEventListener('input', savePrefs);
      }
    });
  }

  function pathForValues(values, xOf, yOf) {
    let d = '';
    let started = false;
    values.forEach(function (v, i) {
      if (v == null) { started = false; return; }
      d += (started ? ' L' : ' M') + xOf(i).toFixed(1) + ' ' + yOf(v).toFixed(1);
      started = true;
    });
    return d;
  }

  function dualGainPlot(ch) {
    const hg = ch.hg || [];
    const lg = ch.lg || [];
    const n = Math.max(hg.length, lg.length, 1);
    const W = 320;
    const H = 132;
    const L = 44;
    const R = 8;
    const T = 10;
    const B = 22;
    const innerW = W - L - R;
    const innerH = H - T - B;
    const xOf = function (i) {
      return L + (n <= 1 ? innerW / 2 : i * innerW / (n - 1));
    };
    const yOf = function (v) {
      return T + innerH - (Math.max(0, Math.min(Y_MAX, v)) / Y_MAX) * innerH;
    };
    let grid = '';
    [0, Math.floor(Y_MAX / 2), Y_MAX].forEach(function (tick) {
      const y = yOf(tick);
      grid += '<line x1="' + L + '" y1="' + y + '" x2="' + (W - R) + '" y2="' + y +
        '" stroke="#2a3654" stroke-width="1"/>';
      grid += '<text x="' + (L - 4) + '" y="' + (y + 3) +
        '" text-anchor="end" fill="#8b9bb4" font-size="8">' + tick + '</text>';
    });
    const step = n > 16 ? 4 : (n > 8 ? 2 : 1);
    for (let s = 0; s < n; s += step) {
      grid += '<text x="' + xOf(s) + '" y="' + (H - 6) +
        '" text-anchor="middle" fill="#8b9bb4" font-size="8">' + s + '</text>';
    }
    const hgPath = pathForValues(hg, xOf, yOf);
    const lgPath = pathForValues(lg, xOf, yOf);
    let dots = '';
    [['hg', hg], ['lg', lg]].forEach(function (pair) {
      const color = GAIN_COLOR[pair[0]];
      pair[1].forEach(function (v, i) {
        if (v == null) return;
        dots += '<circle cx="' + xOf(i).toFixed(1) + '" cy="' + yOf(v).toFixed(1) +
          '" r="2" fill="' + color + '"/>';
      });
    });
    const mh = (ch.metrics && ch.metrics.hg) || {};
    const ml = (ch.metrics && ch.metrics.lg) || {};
    return '<div class="adcrd-plot adcrd-plot-analog"><h3>ADC ' + ch.adc +
      ' <span class="adcrd-gain-swatch hg"></span>HG' +
      ' <span class="adcrd-gain-swatch lg"></span>LG' +
      ' · pk ' + (mh.peak != null ? mh.peak.toFixed(0) : '—') +
      '/' + (ml.peak != null ? ml.peak.toFixed(0) : '—') +
      '</h3><svg viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' +
      grid +
      (lgPath ? '<path d="' + lgPath + '" fill="none" stroke="' + GAIN_COLOR.lg + '" stroke-width="1.5"/>' : '') +
      (hgPath ? '<path d="' + hgPath + '" fill="none" stroke="' + GAIN_COLOR.hg + '" stroke-width="1.5"/>' : '') +
      dots + '</svg></div>';
  }

  function metricsTable(channels) {
    let html = '<div class="adcrd-table-wrap"><h3>Pulse metrics</h3>' +
      '<table class="adcrd-samples"><tr>' +
      '<th>ADC</th><th>HG ped</th><th>HG peak</th><th>HG idx</th><th>HG CoM</th><th>HG FWHM</th>' +
      '<th>LG ped</th><th>LG peak</th><th>LG idx</th><th>LG CoM</th><th>LG FWHM</th></tr>';
    channels.forEach(function (ch) {
      const mh = (ch.metrics && ch.metrics.hg) || {};
      const ml = (ch.metrics && ch.metrics.lg) || {};
      html += '<tr><td class="samp">' + ch.adc + '</td>' +
        '<td>' + fmt(mh.pedestal) + '</td><td>' + fmt(mh.peak) + '</td><td>' + (mh.peak_index || 0) + '</td>' +
        '<td>' + fmt(mh.center) + '</td><td>' + fmt(mh.fwhm) + '</td>' +
        '<td>' + fmt(ml.pedestal) + '</td><td>' + fmt(ml.peak) + '</td><td>' + (ml.peak_index || 0) + '</td>' +
        '<td>' + fmt(ml.center) + '</td><td>' + fmt(ml.fwhm) + '</td></tr>';
    });
    return html + '</table></div>';
  }

  function fmt(v) {
    if (v == null || !Number.isFinite(Number(v))) return '—';
    return Number(v).toFixed(1);
  }

  function samplesTable(gain, channels) {
    const n = (channels[0] && channels[0][gain] && channels[0][gain].length) || 0;
    let html = '<div class="adcrd-table-wrap"><h3>' + esc(gain.toUpperCase()) + ' samples</h3>' +
      '<table class="adcrd-samples"><tr><th>Sample</th>';
    channels.forEach(function (ch) {
      html += '<th>ADC ' + ch.adc + '</th>';
    });
    html += '</tr>';
    for (let s = 0; s < n; s += 1) {
      html += '<tr><td class="samp">' + s + '</td>';
      channels.forEach(function (ch) {
        const v = (ch[gain] || [])[s];
        html += '<td>' + (v == null ? '—' : v) + '</td>';
      });
      html += '</tr>';
    }
    return html + '</table></div>';
  }

  function buildCsv(data) {
    const lines = ['side,adc,sample,hg,lg,hg_ped,hg_peak,lg_ped,lg_peak'];
    ['A', 'B'].forEach(function (sideId) {
      (data.sides[sideId] || []).forEach(function (ch) {
        const n = Math.max((ch.hg || []).length, (ch.lg || []).length);
        const mh = (ch.metrics && ch.metrics.hg) || {};
        const ml = (ch.metrics && ch.metrics.lg) || {};
        for (let s = 0; s < n; s += 1) {
          lines.push([
            sideId, ch.adc, s,
            (ch.hg || [])[s] == null ? '' : (ch.hg || [])[s],
            (ch.lg || [])[s] == null ? '' : (ch.lg || [])[s],
            mh.pedestal == null ? '' : mh.pedestal,
            mh.peak == null ? '' : mh.peak,
            ml.pedestal == null ? '' : ml.pedestal,
            ml.peak == null ? '' : ml.peak,
          ].join(','));
        }
      });
    });
    return lines.join('\n') + '\n';
  }

  function render(data) {
    const s = data.settings || {};
    const channels = []
      .concat(data.sides.A || [])
      .concat(data.sides.B || [])
      .slice()
      .sort(function (a, b) { return Number(a.adc) - Number(b.adc); });

    let html = '<p class="adcrd-legend">MD ' + (data.md + 1) +
      ' · BCR ' + data.bcr +
      ' · DAC ' + s.dac_charge +
      ' · cap ' + String(s.capacitor || '').toUpperCase() +
      ' · ped ' + s.adc_pedestal +
      ' · charge/discharge BCID ' + s.bcid_charge + '/' + s.bcid_discharge +
      ' · dbside ' + s.dbside +
      ' · phase ' + (s.phase != null ? s.phase : '—') +
      (s.phase_ns != null ? ' (' + Number(s.phase_ns).toFixed(3) + ' ns offset)' : '') +
      (data.configure ? '' : ' · readout only') +
      '. <span class="adcrd-gain-swatch hg"></span>HG <span class="adcrd-gain-swatch lg"></span>LG</p>';

    html += '<div class="adcrd-plot-section"><h2>HG + LG · CIS pulse vs sample' +
      ' · row1 ADC 0–5 · row2 ADC 6–11</h2>' +
      '<div class="adcrd-analog-grid cis-adc-grid">';
    channels.forEach(function (ch) { html += dualGainPlot(ch); });
    html += '</div></div>';

    html += metricsTable(channels);
    html += samplesTable('hg', channels);
    html += samplesTable('lg', channels);

    document.getElementById('wrap-tilecal_cis').innerHTML = html;
    lastCsv = buildCsv(data);
  }

  function setStatus(text, warn) {
    const el = document.getElementById('status-tilecal_cis');
    if (!el) return;
    el.textContent = text || '';
    el.className = 'adcrd-status-hint' + (warn ? ' warn' : (text ? ' ok' : ''));
  }

  async function refresh() {
    if (!HWMonitor.state.connected) return;
    savePrefs();
    const skip = document.getElementById('cisSkipConfig').checked;
    const body = {
      bcr: num('cisBcr', 2256),
      samples: num('cisSamples', 16),
      dac_charge: num('cisDac', 2000),
      capacitor: document.getElementById('cisCap').value,
      adc_pedestal: num('cisPed', 100),
      bcid_charge: num('cisBcidCharge', 500),
      bcid_discharge: num('cisBcidDischarge', 2200),
      dbside: document.getElementById('cisDbSide').value,
      phase: num('cisPhase', 0),
      configure: skip ? 0 : 1,
    };
    setStatus(skip ? 'Phase + L1A + readout…' : 'Configuring CIS / phase, then L1A + readout…');
    last = await HWMonitor.fetchJson('/api/plugins/tilecal_cis/data', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    document.getElementById('time-tilecal_cis').textContent =
      'Updated ' + new Date().toLocaleTimeString();
    setStatus('OK · peak HG avg shown in plot titles');
    render(last);
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_cis'],
    refresh: refresh,
    refreshLabel: 'CIS configure / trigger / readout…',
    onInit() {
      applyPrefs(loadPrefs());
      bindPrefs();
      const copy = document.getElementById('cisCopyCsv');
      if (copy) {
        copy.addEventListener('click', async function () {
          if (!lastCsv) return;
          try {
            await navigator.clipboard.writeText(lastCsv);
            setStatus('CSV copied');
          } catch (err) {
            setStatus('Copy failed', true);
          }
        });
      }
      const wrap = document.getElementById('wrap-tilecal_cis');
      if (wrap) wrap.innerHTML = '<p class="empty">Connect, set CIS parameters, then Configure &amp; fire.</p>';
    },
    onMdChange() {
      // Keep form values; only clear plots for the new MD.
      last = null;
      lastCsv = '';
      savePrefs();
      const wrap = document.getElementById('wrap-tilecal_cis');
      if (wrap) wrap.innerHTML = '<p class="empty">No CIS readout yet for this MD.</p>';
      const timeEl = document.getElementById('time-tilecal_cis');
      if (timeEl) timeEl.textContent = '';
      setStatus('');
    },
    onDisconnect() {
      // Keep form values across reconnect / UI reset.
      last = null;
      lastCsv = '';
      savePrefs();
      const wrap = document.getElementById('wrap-tilecal_cis');
      if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
      setStatus('');
    },
  });
})();
