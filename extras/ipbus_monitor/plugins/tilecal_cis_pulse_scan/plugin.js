(function () {
  const ID = 'tilecal_cis_pulse_scan';
  const PREFS_KEY = 'ipbus_monitor.tilecal_cis_pulse_scan.prefs';
  const GAIN_COLOR = { hg: '#4f8cff', lg: '#3ecf8e' };
  const ADC_COLORS = [
    '#4f8cff', '#3ecf8e', '#f0a500', '#e85d75', '#9b7bff', '#2ec4b6',
    '#ff7a59', '#7bdff2', '#c3a6ff', '#ffd166', '#06d6a0', '#ef476f',
  ];
  const Y_MAX = 4095;
  const FORM_IDS = [
    'cispsBcr', 'cispsSamples', 'cispsDac', 'cispsCap', 'cispsPed',
    'cispsBcidCharge', 'cispsBcidDischarge', 'cispsDbSide',
    'cispsPhaseStart', 'cispsPhaseStop', 'cispsPhaseStep', 'cispsSkipConfig',
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

  function sortedChannels(data) {
    return []
      .concat((data && data.sides && data.sides.A) || [])
      .concat((data && data.sides && data.sides.B) || [])
      .slice()
      .sort(function (a, b) { return Number(a.adc) - Number(b.adc); });
  }

  function pathForPoints(points, xOf, yOf) {
    let d = '';
    let started = false;
    points.forEach(function (p) {
      if (p == null || p.v == null) { started = false; return; }
      d += (started ? ' L' : ' M') + xOf(p.t_ns).toFixed(1) + ' ' + yOf(p.v).toFixed(1);
      started = true;
    });
    return d;
  }

  function markersForPoints(points, xOf, yOf, color) {
    let dots = '';
    points.forEach(function (p) {
      if (p == null || p.v == null) return;
      dots += '<circle cx="' + xOf(p.t_ns).toFixed(1) + '" cy="' + yOf(p.v).toFixed(1) +
        '" r="1.8" fill="' + color + '"/>';
    });
    return dots;
  }

  function dualGainPlot(ch, tMax) {
    const hg = ch.hg || [];
    const lg = ch.lg || [];
    const tmax = Math.max(tMax || 0, 1);
    const W = 320;
    const H = 148;
    const L = 44;
    const R = 8;
    const T = 10;
    const B = 28;
    const innerW = W - L - R;
    const innerH = H - T - B;
    const xOf = function (t) {
      return L + (Math.max(0, Math.min(tmax, t)) / tmax) * innerW;
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
    const xTicks = 5;
    for (let i = 0; i <= xTicks; i += 1) {
      const t = (tmax * i) / xTicks;
      grid += '<text x="' + xOf(t) + '" y="' + (H - 6) +
        '" text-anchor="middle" fill="#8b9bb4" font-size="8">' + t.toFixed(0) + '</text>';
    }
    const hgPath = pathForPoints(hg, xOf, yOf);
    const lgPath = pathForPoints(lg, xOf, yOf);
    const mh = (ch.metrics && ch.metrics.hg) || {};
    const ml = (ch.metrics && ch.metrics.lg) || {};
    return '<div class="adcrd-plot adcrd-plot-analog"><h3>ADC ' + ch.adc +
      ' <span class="adcrd-gain-swatch hg"></span>HG' +
      ' <span class="adcrd-gain-swatch lg"></span>LG' +
      ' · pk ' + (mh.peak != null ? mh.peak.toFixed(0) : '—') +
      '/' + (ml.peak != null ? ml.peak.toFixed(0) : '—') +
      '</h3><svg viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' +
      grid +
      (lgPath ? '<path d="' + lgPath + '" fill="none" stroke="' + GAIN_COLOR.lg + '" stroke-width="1.2"/>' : '') +
      (hgPath ? '<path d="' + hgPath + '" fill="none" stroke="' + GAIN_COLOR.hg + '" stroke-width="1.2"/>' : '') +
      markersForPoints(lg, xOf, yOf, GAIN_COLOR.lg) +
      markersForPoints(hg, xOf, yOf, GAIN_COLOR.hg) +
      '</svg></div>';
  }

  function metricsTable(channels) {
    let html = '<div class="adcrd-table-wrap"><h3>Pulse metrics (phase-merged)</h3>' +
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

  function buildCsv(data) {
    const lines = ['side,adc,phase,phase_ns,sample,t_ns,hg,lg'];
    ['A', 'B'].forEach(function (sideId) {
      (data.sides[sideId] || []).forEach(function (ch) {
        const n = Math.max((ch.hg || []).length, (ch.lg || []).length);
        for (let i = 0; i < n; i += 1) {
          const hp = (ch.hg || [])[i] || {};
          const lp = (ch.lg || [])[i] || {};
          const phase = hp.phase != null ? hp.phase : lp.phase;
          const sample = hp.sample != null ? hp.sample : lp.sample;
          const t = hp.t_ns != null ? hp.t_ns : lp.t_ns;
          const phaseNs = hp.phase_ns != null ? hp.phase_ns
            : (lp.phase_ns != null ? lp.phase_ns : '');
          lines.push([
            sideId, ch.adc,
            phase == null ? '' : phase,
            phaseNs === '' ? '' : Number(phaseNs).toFixed(6),
            sample == null ? '' : sample,
            t == null ? '' : Number(t).toFixed(6),
            hp.v == null ? '' : hp.v,
            lp.v == null ? '' : lp.v,
          ].join(','));
        }
      });
    });
    return lines.join('\n') + '\n';
  }

  function maxTime(channels) {
    let tmax = 0;
    channels.forEach(function (ch) {
      (ch.hg || []).forEach(function (p) {
        if (p && p.t_ns > tmax) tmax = p.t_ns;
      });
      (ch.lg || []).forEach(function (p) {
        if (p && p.t_ns > tmax) tmax = p.t_ns;
      });
    });
    return tmax;
  }

  function buildPlotlyTraces(channels, showHg, showLg) {
    const traces = [];
    channels.forEach(function (ch) {
      const color = ADC_COLORS[ch.adc % ADC_COLORS.length];
      if (showHg) {
        const pts = ch.hg || [];
        traces.push({
          type: 'scatter',
          mode: 'lines+markers',
          name: 'ADC ' + ch.adc + ' HG',
          x: pts.map(function (p) { return p.t_ns; }),
          y: pts.map(function (p) { return p.v; }),
          customdata: pts.map(function (p) {
            return [p.sample, p.phase, p.phase_ns];
          }),
          line: { color: color, width: 1.6 },
          marker: { color: color, size: 5, symbol: 'circle' },
          hovertemplate:
            'ADC ' + ch.adc + ' HG<br>t %{x:.3f} ns<br>ADC %{y}' +
            '<br>sample %{customdata[0]} · phase %{customdata[1]}' +
            '<br>offset %{customdata[2]:.3f} ns<extra></extra>',
        });
      }
      if (showLg) {
        const pts = ch.lg || [];
        traces.push({
          type: 'scatter',
          mode: 'lines+markers',
          name: 'ADC ' + ch.adc + ' LG',
          x: pts.map(function (p) { return p.t_ns; }),
          y: pts.map(function (p) { return p.v; }),
          customdata: pts.map(function (p) {
            return [p.sample, p.phase, p.phase_ns];
          }),
          line: { color: color, width: 1.4, dash: 'dot' },
          marker: { color: color, size: 4, symbol: 'diamond', opacity: 0.85 },
          opacity: 0.85,
          hovertemplate:
            'ADC ' + ch.adc + ' LG<br>t %{x:.3f} ns<br>ADC %{y}' +
            '<br>sample %{customdata[0]} · phase %{customdata[1]}' +
            '<br>offset %{customdata[2]:.3f} ns<extra></extra>',
        });
      }
    });
    return traces;
  }

  function plotlyLayout(tmax) {
    return {
      title: {
        text: 'CIS phase scan · all ADCs',
        font: { color: '#c5d0e6', size: 14 },
      },
      paper_bgcolor: 'rgba(0,0,0,0)',
      plot_bgcolor: '#0d1424',
      font: { color: '#8b9bb4', family: 'ui-monospace, SFMono-Regular, Menlo, monospace', size: 11 },
      margin: { l: 58, r: 18, t: 48, b: 120 },
      xaxis: {
        title: { text: 't [ns]  ·  sample×25 + (31−phase)×(25/32)', standoff: 8 },
        range: [0, Math.max(tmax || 1, 1)],
        autorange: false,
        gridcolor: '#1c2538',
        zerolinecolor: '#2a3654',
        color: '#8b9bb4',
      },
      yaxis: {
        title: { text: 'ADC counts' },
        range: [0, Y_MAX],
        autorange: false,
        gridcolor: '#1c2538',
        zerolinecolor: '#2a3654',
        color: '#8b9bb4',
      },
      legend: {
        orientation: 'h',
        yanchor: 'top',
        y: -0.28,
        xanchor: 'center',
        x: 0.5,
        bgcolor: 'rgba(13,20,36,0.85)',
        bordercolor: '#2a3654',
        borderwidth: 1,
        font: { size: 10 },
      },
      hovermode: 'closest',
      uirevision: 'cisps-phase-scan',
    };
  }

  function plotlyConfig() {
    return {
      responsive: true,
      displaylogo: false,
      scrollZoom: true,
      modeBarButtonsToRemove: ['lasso2d', 'select2d', 'autoScale2d'],
      toImageButtonOptions: {
        format: 'png',
        filename: 'cis_phase_scan',
        height: 700,
        width: 1200,
        scale: 2,
      },
    };
  }

  function renderFullWindow() {
    const plot = document.getElementById('cispsFullPlot');
    const meta = document.getElementById('cispsFullMeta');
    if (!plot || !last) return;
    if (!window.Plotly) {
      plot.innerHTML = '<p class="empty">Plotly failed to load — check network / CDN.</p>';
      return;
    }
    const channels = sortedChannels(last);
    const showHg = !!(document.getElementById('cispsFullHg') || {}).checked;
    const showLg = !!(document.getElementById('cispsFullLg') || {}).checked;
    if (!showHg && !showLg) {
      plot.innerHTML = '<p class="empty">Enable HG and/or LG.</p>';
      return;
    }
    const tmax = maxTime(channels);
    const traces = buildPlotlyTraces(channels, showHg, showLg);
    const layout = plotlyLayout(tmax);
    const config = plotlyConfig();
    layout.height = Math.min(560, Math.max(400, Math.floor(window.innerHeight * 0.62)));
    const draw = plot.data
      ? Plotly.react(plot, traces, layout, config)
      : Plotly.newPlot(plot, traces, layout, config);
    Promise.resolve(draw).then(function () {
      Plotly.Plots.resize(plot);
    });
    const s = last.settings || {};
    if (meta) {
      meta.textContent = 'MD ' + (last.md + 1) +
        ' · ' + (s.n_phases || 0) + ' phases' +
        ' · step ' + ((last.phase_step_ns != null) ? last.phase_step_ns.toFixed(4) : '0.7813') + ' ns' +
        ' · reversed phase' +
        (showHg ? ' · HG' : '') +
        (showLg ? ' · LG' : '');
    }
  }

  function openFullWindow() {
    const overlay = document.getElementById('cispsFullOverlay');
    if (!overlay) return;
    if (!last) {
      setStatus('Run a phase scan first', true);
      return;
    }
    overlay.classList.remove('hidden');
    overlay.setAttribute('aria-hidden', 'false');
    renderFullWindow();
  }

  function closeFullWindow() {
    const overlay = document.getElementById('cispsFullOverlay');
    if (!overlay) return;
    overlay.classList.add('hidden');
    overlay.setAttribute('aria-hidden', 'true');
  }

  function render(data) {
    const s = data.settings || {};
    const channels = sortedChannels(data);
    const tmax = maxTime(channels);
    const stepNs = data.phase_step_ns != null ? data.phase_step_ns : (25 / 32);

    let html = '<p class="adcrd-legend">MD ' + (data.md + 1) +
      ' · BCR ' + data.bcr +
      ' · DAC ' + s.dac_charge +
      ' · cap ' + String(s.capacitor || '').toUpperCase() +
      ' · ped ' + s.adc_pedestal +
      ' · charge/discharge BCID ' + s.bcid_charge + '/' + s.bcid_discharge +
      ' · dbside ' + s.dbside +
      ' · phases ' + s.phase_start + '…' + s.phase_stop +
      ' step ' + s.phase_step + ' (' + s.n_phases + ' × ' + stepNs.toFixed(4) + ' ns)' +
      ' · t = sample×25 + (31−phase)×(25/32) ns' +
      (data.configure ? '' : ' · readout only') +
      '. <span class="adcrd-gain-swatch hg"></span>HG <span class="adcrd-gain-swatch lg"></span>LG' +
      ' · X = time [ns] · markers = samples</p>';

    html += '<div class="adcrd-plot-section"><h2>HG + LG · CIS pulse vs time (phase interleaved, reversed)' +
      ' · row1 ADC 0–5 · row2 ADC 6–11</h2>' +
      '<div class="adcrd-analog-grid cis-adc-grid">';
    channels.forEach(function (ch) { html += dualGainPlot(ch, tmax); });
    html += '</div></div>';

    html += metricsTable(channels);

    document.getElementById('wrap-tilecal_cis_pulse_scan').innerHTML = html;
    lastCsv = buildCsv(data);
  }

  function setStatus(text, warn) {
    const el = document.getElementById('status-tilecal_cis_pulse_scan');
    if (!el) return;
    el.textContent = text || '';
    el.className = 'adcrd-status-hint' + (warn ? ' warn' : (text ? ' ok' : ''));
  }

  async function refresh() {
    if (!HWMonitor.state.connected) return;
    savePrefs();
    const skip = document.getElementById('cispsSkipConfig').checked;
    const phaseStart = num('cispsPhaseStart', 0);
    const phaseStop = num('cispsPhaseStop', 31);
    const phaseStep = num('cispsPhaseStep', 1);
    const nApprox = Math.floor(Math.abs(phaseStop - phaseStart) / Math.max(1, phaseStep)) + 1;
    const body = {
      bcr: num('cispsBcr', 2256),
      samples: num('cispsSamples', 16),
      dac_charge: num('cispsDac', 2000),
      capacitor: document.getElementById('cispsCap').value,
      adc_pedestal: num('cispsPed', 100),
      bcid_charge: num('cispsBcidCharge', 500),
      bcid_discharge: num('cispsBcidDischarge', 2200),
      dbside: document.getElementById('cispsDbSide').value,
      phase_start: phaseStart,
      phase_stop: phaseStop,
      phase_step: phaseStep,
      configure: skip ? 0 : 1,
    };
    setStatus(
      (skip ? 'Phase + L1A + readout' : 'Configuring CIS, then phase scan') +
      ' · ~' + nApprox + ' phases…'
    );
    last = await HWMonitor.fetchJson('/api/plugins/tilecal_cis_pulse_scan/data', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    document.getElementById('time-tilecal_cis_pulse_scan').textContent =
      'Updated ' + new Date().toLocaleTimeString();
    setStatus('OK · ' + ((last.settings && last.settings.n_phases) || nApprox) +
      ' phases · reversed · step ' +
      ((last.phase_step_ns != null) ? last.phase_step_ns.toFixed(4) : '0.7813') + ' ns');
    render(last);
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_cis_pulse_scan'],
    refresh: refresh,
    refreshLabel: 'CIS phase scan (configure / trigger / readout)…',
    onInit() {
      applyPrefs(loadPrefs());
      bindPrefs();
      const copy = document.getElementById('cispsCopyCsv');
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
      const showFull = document.getElementById('cispsShowFull');
      if (showFull) showFull.addEventListener('click', openFullWindow);
      const closeFull = document.getElementById('cispsFullClose');
      if (closeFull) closeFull.addEventListener('click', closeFullWindow);
      const overlay = document.getElementById('cispsFullOverlay');
      if (overlay) {
        overlay.addEventListener('click', function (ev) {
          if (ev.target === overlay) closeFullWindow();
        });
      }
      ['cispsFullHg', 'cispsFullLg'].forEach(function (id) {
        const el = document.getElementById(id);
        if (el) el.addEventListener('change', function () {
          if (!document.getElementById('cispsFullOverlay').classList.contains('hidden')) {
            renderFullWindow();
          }
        });
      });
      const wrap = document.getElementById('wrap-tilecal_cis_pulse_scan');
      if (wrap) {
        wrap.innerHTML = '<p class="empty">Connect, set CIS parameters, then Scan phases (32 steps × 25&nbsp;ns).</p>';
      }
    },
    onMdChange() {
      last = null;
      lastCsv = '';
      savePrefs();
      closeFullWindow();
      const wrap = document.getElementById('wrap-tilecal_cis_pulse_scan');
      if (wrap) wrap.innerHTML = '<p class="empty">No CIS phase scan yet for this MD.</p>';
      const timeEl = document.getElementById('time-tilecal_cis_pulse_scan');
      if (timeEl) timeEl.textContent = '';
      setStatus('');
    },
    onDisconnect() {
      last = null;
      lastCsv = '';
      savePrefs();
      closeFullWindow();
      const wrap = document.getElementById('wrap-tilecal_cis_pulse_scan');
      if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
      setStatus('');
    },
  });
})();
