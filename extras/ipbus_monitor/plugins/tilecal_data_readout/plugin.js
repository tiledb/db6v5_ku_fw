(function () {
  const ID = 'tilecal_data_readout';
  const GAIN_COLOR = { hg: '#4f8cff', lg: '#3ecf8e' };
  const ADC_COLORS = [
    '#4f8cff', '#3ecf8e', '#f0a500', '#e85d75', '#9b7bff', '#2ec4b6',
    '#ff7a59', '#7bdff2', '#c3a6ff', '#ffd166', '#06d6a0', '#ef476f',
  ];
  const SIDE_ADCS = { A: [0, 1, 2, 3, 4, 5], B: [6, 7, 8, 9, 10, 11] };
  const BCR_MAX = 3564;
  const Y_MAX = 4095;

  const PREFS_KEY = 'ipbus_monitor.tilecal_data_readout.prefs';

  let lastCsv = '';
  let lastData = null;
  let selectedAdc = 0;
  let sweepAbort = false;
  let sweepRunning = false;
  let sweep = emptySweep();
  let view = defaultView();
  /** First BCR slot shown in the channel sample plots (length = sample count). */
  let bracketStart = 0;
  let previewAllTraces = true;
  let currentMd = 0;
  /** Per-MD runtime cache (pipeline window + last readout). Prefs also keyed by MD. */
  const mdCache = {};

  function prefsKey(md) {
    return PREFS_KEY + '.md' + (Number(md) || 0);
  }

  function activeMd() {
    return Number(HWMonitor.state && HWMonitor.state.md) || currentMd || 0;
  }

  function loadPrefs() {
    try {
      const raw = localStorage.getItem(prefsKey(currentMd));
      if (!raw) {
        // Migrate legacy single-key prefs once.
        const legacy = localStorage.getItem(PREFS_KEY);
        if (!legacy) return null;
        return JSON.parse(legacy);
      }
      return JSON.parse(raw);
    } catch (err) {
      return null;
    }
  }

  function collectFormPrefs() {
    return {
      bcr: document.getElementById('adcrdBcr') && document.getElementById('adcrdBcr').value,
      samples: document.getElementById('adcrdSamples') && document.getElementById('adcrdSamples').value,
      bitMode: document.getElementById('adcrdBitMode') && document.getElementById('adcrdBitMode').value,
      injectSide: document.getElementById('adcrdInjectSide') && document.getElementById('adcrdInjectSide').value,
      sweepFrom: document.getElementById('adcrdSweepFrom') && document.getElementById('adcrdSweepFrom').value,
      sweepTo: document.getElementById('adcrdSweepTo') && document.getElementById('adcrdSweepTo').value,
      sweepStep: document.getElementById('adcrdSweepStep') && document.getElementById('adcrdSweepStep').value,
      sweepGain: document.getElementById('adcrdSweepGain') && document.getElementById('adcrdSweepGain').value,
      allTraces: showAllTraces(),
      previewAllTraces: previewAllTraces,
      selectedAdc: selectedAdc,
      bracketStart: bracketStart,
    };
  }

  function savePrefs() {
    try {
      localStorage.setItem(prefsKey(currentMd), JSON.stringify(collectFormPrefs()));
    } catch (err) { /* ignore quota / private mode */ }
  }

  function applyPrefs(prefs) {
    if (!prefs || typeof prefs !== 'object') return;
    function setVal(id, value, allowed) {
      if (value == null || value === '') return;
      const el = document.getElementById(id);
      if (!el) return;
      const text = String(value);
      if (allowed && allowed.indexOf(text) < 0) return;
      el.value = text;
    }
    setVal('adcrdSamples', prefs.samples, ['8', '16', '32']);
    setVal('adcrdBitMode', prefs.bitMode, ['12', '14']);
    setVal('adcrdInjectSide', prefs.injectSide, ['both', 'A', 'B']);
    setVal('adcrdSweepGain', prefs.sweepGain, ['hg', 'lg']);
    setVal('adcrdBcr', prefs.bcr);
    setVal('adcrdSweepFrom', prefs.sweepFrom);
    setVal('adcrdSweepTo', prefs.sweepTo);
    setVal('adcrdSweepStep', prefs.sweepStep);
    const allEl = document.getElementById('adcrdAllTraces');
    if (allEl && typeof prefs.allTraces === 'boolean') allEl.checked = prefs.allTraces;
    if (typeof prefs.previewAllTraces === 'boolean') previewAllTraces = prefs.previewAllTraces;
    if (prefs.selectedAdc != null && Number.isFinite(Number(prefs.selectedAdc))) {
      selectedAdc = Math.max(0, Math.min(11, Number(prefs.selectedAdc) | 0));
    }
    syncBcrLimits();
    if (prefs.bracketStart != null && Number.isFinite(Number(prefs.bracketStart))) {
      clampBracket(prefs.bracketStart);
    }
  }

  function cloneSweep(src) {
    try {
      return JSON.parse(JSON.stringify(src || emptySweep()));
    } catch (err) {
      return emptySweep();
    }
  }

  function stashMdState(md) {
    mdCache[Number(md) || 0] = {
      lastCsv: lastCsv,
      lastData: lastData,
      selectedAdc: selectedAdc,
      sweep: cloneSweep(sweep),
      view: Object.assign({}, view),
      bracketStart: bracketStart,
      previewAllTraces: previewAllTraces,
    };
    savePrefs();
  }

  function loadMdState(md) {
    const mdI = Number(md) || 0;
    currentMd = mdI;
    const cached = mdCache[mdI];
    if (cached) {
      lastCsv = cached.lastCsv || '';
      lastData = cached.lastData || null;
      selectedAdc = cached.selectedAdc || 0;
      sweep = cloneSweep(cached.sweep);
      view = Object.assign(defaultView(), cached.view || {});
      bracketStart = cached.bracketStart || 0;
      previewAllTraces = cached.previewAllTraces !== false;
    } else {
      lastCsv = '';
      lastData = null;
      selectedAdc = 0;
      sweep = emptySweep();
      view = defaultView();
      bracketStart = 0;
      previewAllTraces = true;
    }
    applyPrefs(loadPrefs());
    clampBracket(bracketStart);
  }

  function switchToMd(md) {
    const mdI = Number(md) || 0;
    if (mdI !== currentMd) {
      if (sweepRunning) sweepAbort = true;
      stashMdState(currentMd);
      closeFullWindow();
    }
    loadMdState(mdI);
    setProgress('');
    renderLayout({ skipRecord: true });
  }

  function emptySweep() {
    return { byBcr: {}, filled: 0, lastBcr: null, lastRange: null };
  }

  function defaultView() {
    return { xmin: 0, xmax: BCR_MAX, ymin: 0, ymax: Y_MAX };
  }

  function esc(s) { return HWMonitor.esc(s); }

  function bitMode() {
    const el = document.getElementById('adcrdBitMode');
    return el && el.value === '14' ? 14 : 12;
  }

  function adcMax() {
    return (1 << bitMode()) - 1;
  }

  function sweepGain() {
    const el = document.getElementById('adcrdSweepGain');
    return el && el.value === 'lg' ? 'lg' : 'hg';
  }

  function selectedSamples() {
    const el = document.getElementById('adcrdSamples');
    const n = Number(el && el.value);
    return (n === 8 || n === 16 || n === 32) ? n : 16;
  }

  function showAllTraces() {
    const el = document.getElementById('adcrdAllTraces');
    return !el || el.checked;
  }

  function showPreviewAllTraces() {
    return previewAllTraces;
  }

  function displayValue(sample) {
    if (sample == null || sample === '') return null;
    const raw = Number(sample) & 0xFFF;
    if (bitMode() === 14) return raw << 2;
    return raw;
  }

  function cellStyle(adc) {
    if (adc == null) return '';
    const t = Math.max(0, Math.min(1, adc / adcMax()));
    return 'background: rgba(79, 140, 255, ' + (0.06 + 0.5 * t).toFixed(3) + ')';
  }

  function clampBcr(bcr) {
    const n = selectedSamples();
    return Math.max(n, Math.min(BCR_MAX, Math.floor(Number(bcr) || n)));
  }

  function syncBcrLimits() {
    const n = selectedSamples();
    ['adcrdBcr', 'adcrdSweepFrom', 'adcrdSweepTo'].forEach(function (id) {
      const el = document.getElementById(id);
      if (!el) return;
      el.min = String(n);
      el.max = String(BCR_MAX);
      if (Number(el.value) < n) el.value = String(n);
      if (Number(el.value) > BCR_MAX) el.value = String(BCR_MAX);
    });
    clampBracket(bracketStart);
  }

  function sortedBcrs() {
    return Object.keys(sweep.byBcr).map(Number).sort(function (a, b) { return a - b; });
  }

  function clampBracket(start) {
    const n = selectedSamples();
    bracketStart = Math.max(0, Math.min(BCR_MAX - n + 1, Math.floor(Number(start) || 0)));
    return bracketStart;
  }

  function bracketEnd() {
    return bracketStart + selectedSamples() - 1;
  }

  function samplesFromWindow(adc, gain) {
    const n = selectedSamples();
    const out = [];
    for (let i = 0; i < n; i += 1) {
      const row = sweep.byBcr[bracketStart + i];
      if (!row || !row[adc] || row[adc][gain] == null) out.push(null);
      else out.push(row[adc][gain]);
    }
    return out;
  }

  function channelsForSide(sideId) {
    const meta = {};
    if (lastData && lastData.sides && lastData.sides[sideId]) {
      lastData.sides[sideId].forEach(function (ch) {
        meta[Number(ch.adc)] = ch;
      });
    }
    return SIDE_ADCS[sideId].map(function (adc) {
      const m = meta[adc] || {};
      return {
        adc: adc,
        fpga: m.fpga != null ? m.fpga : '—',
        fpga_channel: m.fpga_channel != null ? m.fpga_channel : '—',
        hg: samplesFromWindow(adc, 'hg'),
        lg: samplesFromWindow(adc, 'lg'),
      };
    });
  }

  function recordReadout(data) {
    if (!data || data.bcr == null) return;
    const bcr = clampBcr(data.bcr);
    let n = 0;
    ['A', 'B'].forEach(function (sideId) {
      (data.sides[sideId] || []).forEach(function (ch) {
        n = Math.max(n, (ch.hg || []).length, (ch.lg || []).length);
      });
    });
    if (n < 1) n = selectedSamples();
    const channels = {};
    ['A', 'B'].forEach(function (sideId) {
      (data.sides[sideId] || []).forEach(function (ch) {
        channels[Number(ch.adc)] = ch;
      });
    });
    const firstSlot = bcr - n;
    const lastSlot = bcr - 1;
    for (let i = 0; i < n; i += 1) {
      const slot = firstSlot + i;
      if (slot < 0 || slot > BCR_MAX) continue;
      const row = {};
      for (let adc = 0; adc < 12; adc += 1) {
        const ch = channels[adc];
        const hg = ch ? displayValue((ch.hg || [])[i]) : null;
        const lg = ch ? displayValue((ch.lg || [])[i]) : null;
        row[adc] = { hg: hg == null ? 0 : hg, lg: lg == null ? 0 : lg };
      }
      if (!Object.prototype.hasOwnProperty.call(sweep.byBcr, slot)) sweep.filled += 1;
      sweep.byBcr[slot] = row;
    }
    sweep.lastBcr = lastSlot;
    sweep.lastRange = {
      from: Math.max(0, firstSlot),
      to: Math.min(BCR_MAX, lastSlot),
      l1a: bcr,
      n: n,
    };
    clampBracket(firstSlot);
  }

  function clearWindow() {
    sweep = emptySweep();
    view = defaultView();
    clampBracket(0);
    lastCsv = '';
    lastData = null;
    stashMdState(currentMd);
    renderLayout({ skipRecord: true });
    HWMonitor.setStatus('BCR window cleared for MD ' + (currentMd + 1) + ' (0–' + BCR_MAX + ')');
  }

  function selectAdc(adc) {
    selectedAdc = Number(adc) & 0xFF;
    savePrefs();
    renderLayout({ skipRecord: true });
  }

  function pathForValues(values, xOf, yOf) {
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
    return d;
  }

  /** One card per ADC with HG and LG overlaid. */
  function dualGainPlot(ch) {
    const ymax = adcMax();
    const hg = ch.hg || [];
    const lg = ch.lg || [];
    const n = Math.max(hg.length, lg.length, selectedSamples(), 1);
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
    const selected = Number(ch.adc) === selectedAdc;
    return '<div class="adcrd-plot adcrd-plot-analog' + (selected ? ' is-selected' : '') +
      '" data-adc="' + ch.adc + '"><h3>ADC ' + ch.adc +
      ' <span class="adcrd-gain-swatch hg"></span>HG' +
      ' <span class="adcrd-gain-swatch lg"></span>LG' +
      (selected ? ' · selected' : '') +
      '</h3><svg viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' +
      grid +
      (lgPath ? '<path d="' + lgPath + '" fill="none" stroke="' + GAIN_COLOR.lg + '" stroke-width="1.5"/>' : '') +
      (hgPath ? '<path d="' + hgPath + '" fill="none" stroke="' + GAIN_COLOR.hg + '" stroke-width="1.5"/>' : '') +
      dots + '</svg></div>';
  }

  function dualGainGrid(sideId, channels) {
    let html = '<div class="adcrd-plot-section"><h2>HG + LG · value vs sample index' +
      ' (' + bitMode() + '-bit, 0–' + adcMax() + ')' +
      ' · bracket BCR ' + bracketStart + '–' + bracketEnd() +
      '</h2><div class="adcrd-analog-grid">';
    channels.forEach(function (ch) { html += dualGainPlot(ch); });
    return html + '</div></div>';
  }

  function renderTable(gain, channels) {
    const n = selectedSamples();
    let html = '<div class="adcrd-table-wrap"><h3>' + esc(gain.toUpperCase()) +
      ' (' + bitMode() + '-bit) · BCR ' + bracketStart + '–' + bracketEnd() +
      '</h3><table class="adcrd-samples"><tr><th>Sample</th><th>BCR</th>';
    channels.forEach(function (ch) {
      const sel = Number(ch.adc) === selectedAdc ? ' class="is-selected"' : '';
      html += '<th' + sel + ' title="FPGA ' + ch.fpga + ' ch ' + ch.fpga_channel +
        '">ADC ' + ch.adc + '</th>';
    });
    html += '</tr>';
    for (let s = 0; s < n; s += 1) {
      html += '<tr><td class="samp">' + s + '</td><td class="samp">' + (bracketStart + s) + '</td>';
      channels.forEach(function (ch) {
        const adc = (ch[gain] || [])[s];
        const sel = Number(ch.adc) === selectedAdc ? ' is-selected' : '';
        html += '<td class="' + sel.trim() + '" style="' + cellStyle(adc) + '">' +
          (adc == null ? '—' : adc) + '</td>';
      });
      html += '</tr>';
    }
    return html + '</table></div>';
  }

  function buildCsv() {
    const lines = ['side,adc,fpga,fpga_channel,sample,bcr,hg,lg'];
    ['A', 'B'].forEach(function (sideId) {
      channelsForSide(sideId).forEach(function (ch) {
        const n = selectedSamples();
        for (let s = 0; s < n; s += 1) {
          const hg = (ch.hg || [])[s];
          const lg = (ch.lg || [])[s];
          lines.push([
            sideId, ch.adc, ch.fpga, ch.fpga_channel, s, bracketStart + s,
            hg == null ? '' : hg, lg == null ? '' : lg,
          ].join(','));
        }
      });
    });
    return lines.join('\n') + '\n';
  }

  function clampView() {
    let xmin = view.xmin;
    let xmax = view.xmax;
    if (!(xmax > xmin)) xmax = xmin + 1;
    const span = Math.max(1, Math.min(BCR_MAX, xmax - xmin));
    xmin = Math.max(0, Math.min(BCR_MAX - span, xmin));
    xmax = xmin + span;
    if (xmax > BCR_MAX) {
      xmax = BCR_MAX;
      xmin = Math.max(0, xmax - span);
    }
    view.xmin = xmin;
    view.xmax = xmax;
    view.ymin = 0;
    view.ymax = Y_MAX;
  }

  function restoreView() {
    view = defaultView();
    const plot = document.getElementById('adcrdFullPlot');
    if (plot && window.Plotly && plot.data) {
      Plotly.relayout(plot, {
        'xaxis.range': [0, BCR_MAX],
        'yaxis.range': [0, Y_MAX],
        'xaxis.autorange': false,
        'yaxis.autorange': false,
      });
    }
    renderPreview();
  }

  function buildSparseSeries(adc, gain) {
    const x = [];
    const y = [];
    let prev = null;
    sortedBcrs().forEach(function (bcr) {
      const row = sweep.byBcr[bcr];
      if (!row || !row[adc]) return;
      if (prev != null && bcr - prev > 1) {
        x.push(null);
        y.push(null);
      }
      x.push(bcr);
      y.push(row[adc][gain]);
      prev = bcr;
    });
    return { x: x, y: y };
  }

  function buildPlotlyTraces(gain) {
    const all = showAllTraces();
    const traces = [];
    for (let adc = 0; adc < 12; adc += 1) {
      if (!all && adc !== selectedAdc) continue;
      const series = buildSparseSeries(adc, gain);
      const selected = adc === selectedAdc;
      traces.push({
        type: 'scatter',
        mode: 'lines+markers',
        name: 'ADC ' + adc,
        x: series.x,
        y: series.y,
        line: {
          color: ADC_COLORS[adc % ADC_COLORS.length],
          width: selected ? 3 : (all ? 1.4 : 2.2),
        },
        marker: {
          color: ADC_COLORS[adc % ADC_COLORS.length],
          size: selected ? 6 : 3.5,
        },
        opacity: all && !selected ? 0.55 : 1,
        hovertemplate: 'ADC ' + adc + '<br>BCR %{x}<br>ADC %{y}<extra></extra>',
      });
    }
    // Sample-window bracket as a translucent shape is done in layout.shapes.
    return traces;
  }

  function plotlyLayout(gain) {
    const n = selectedSamples();
    return {
      title: {
        text: 'BCR window · ' + gain.toUpperCase() +
          (showAllTraces() ? ' · all ADCs' : (' · ADC ' + selectedAdc)),
        font: { color: '#c5d0e6', size: 14 },
      },
      paper_bgcolor: 'rgba(0,0,0,0)',
      plot_bgcolor: '#0d1424',
      font: { color: '#8b9bb4', family: 'ui-monospace, SFMono-Regular, Menlo, monospace', size: 11 },
      margin: { l: 58, r: 18, t: 48, b: 110 },
      xaxis: {
        title: { text: 'BCR', standoff: 8 },
        range: [0, BCR_MAX],
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
        y: -0.22,
        xanchor: 'center',
        x: 0.5,
        bgcolor: 'rgba(13,20,36,0.85)',
        bordercolor: '#2a3654',
        borderwidth: 1,
        font: { size: 11 },
      },
      shapes: [{
        type: 'rect',
        xref: 'x',
        yref: 'paper',
        x0: bracketStart,
        x1: bracketStart + n - 1,
        y0: 0,
        y1: 1,
        fillcolor: 'rgba(79, 140, 255, 0.12)',
        line: { color: '#4f8cff', width: 1 },
        layer: 'below',
      }],
      annotations: [{
        x: bracketStart + (n - 1) / 2,
        y: 1.02,
        xref: 'x',
        yref: 'paper',
        text: 'samples BCR ' + bracketStart + '–' + bracketEnd(),
        showarrow: false,
        font: { color: '#4f8cff', size: 11 },
      }],
      hovermode: 'closest',
      uirevision: 'adcrd-bcr-window',
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
        filename: 'bcr_window',
        height: 700,
        width: 1200,
        scale: 2,
      },
    };
  }

  function previewPlotSvg() {
    const gain = sweepGain();
    const all = showPreviewAllTraces();
    const W = 960;
    const H = 180;
    const L = 52;
    const R = 18;
    const T = 14;
    const B = 28;
    const innerW = W - L - R;
    const innerH = H - T - B;
    const xmin = 0;
    const xmax = BCR_MAX;
    const xspan = BCR_MAX;
    const xOf = function (bcr) {
      return L + (bcr / xspan) * innerW;
    };
    const yOf = function (v) {
      return T + innerH - (Math.max(0, Math.min(Y_MAX, v)) / Y_MAX) * innerH;
    };

    let grid = '';
    [0, Math.floor(Y_MAX / 2), Y_MAX].forEach(function (tick) {
      const y = yOf(tick);
      grid += '<line x1="' + L + '" y1="' + y + '" x2="' + (W - R) + '" y2="' + y +
        '" stroke="#2a3654" stroke-width="1"/>';
      grid += '<text x="' + (L - 6) + '" y="' + (y + 3) +
        '" text-anchor="end" fill="#8b9bb4" font-size="9">' + tick + '</text>';
    });
    for (let i = 0; i <= 8; i += 1) {
      const bcr = Math.round((i / 8) * BCR_MAX);
      grid += '<text x="' + xOf(bcr) + '" y="' + (H - 8) +
        '" text-anchor="middle" fill="#8b9bb4" font-size="9">' + bcr + '</text>';
    }

    const bcrs = sortedBcrs();
    let paths = '<defs><clipPath id="adcrdPrevClip"><rect x="' + L + '" y="' + T +
      '" width="' + innerW + '" height="' + innerH + '"/></clipPath></defs>';
    paths += '<g clip-path="url(#adcrdPrevClip)">';

    const order = [];
    for (let adc = 0; adc < 12; adc += 1) {
      if (all) {
        if (adc !== selectedAdc) order.push(adc);
      } else if (adc === selectedAdc) {
        order.push(adc);
      }
    }
    if (all) order.push(selectedAdc);

    order.forEach(function (adc) {
      let d = '';
      let started = false;
      let lastPt = null;
      bcrs.forEach(function (bcr) {
        const row = sweep.byBcr[bcr];
        if (!row || !row[adc]) return;
        if (started && lastPt != null && bcr - lastPt > 1) started = false;
        d += (started ? ' L' : ' M') + xOf(bcr).toFixed(1) + ' ' + yOf(row[adc][gain]).toFixed(1);
        started = true;
        lastPt = bcr;
      });
      if (!d) return;
      const selected = adc === selectedAdc;
      paths += '<path d="' + d + '" fill="none" stroke="' + ADC_COLORS[adc % ADC_COLORS.length] +
        '" stroke-width="' + (selected ? 2.6 : 1.1) + '" opacity="' +
        (selected ? 1 : 0.45) + '"/>';
    });
    paths += '</g>';

    // Movable sample bracket (thin outline, no side handles).
    const n = selectedSamples();
    const x0 = xOf(bracketStart);
    const x1 = xOf(bracketStart + n - 1);
    const bw = Math.max(4, x1 - x0);
    paths += '<rect class="adcrd-bracket" id="adcrdBracket" data-role="move" x="' +
      x0.toFixed(1) + '" y="' + T + '" width="' + bw.toFixed(1) + '" height="' + innerH +
      '"/>';
    paths += '<text x="' + ((x0 + x1) / 2).toFixed(1) + '" y="' + (T + 11) +
      '" text-anchor="middle" fill="#9ec1ff" font-size="9" opacity="0.85">samples ' +
      bracketStart + '–' + bracketEnd() + '</text>';

    if (!bcrs.length) {
      paths += '<text x="' + (W / 2) + '" y="' + (H / 2) +
        '" text-anchor="middle" fill="#8b9bb4" font-size="13">' +
        'Empty BCR window · drag the bracket · read/sweep to fill</text>';
    }

    return '<svg id="adcrdPreviewSvg" viewBox="0 0 ' + W + ' ' + H +
      '" preserveAspectRatio="none" data-l="' + L + '" data-iw="' + innerW + '">' +
      grid + paths + '</svg>';
  }

  function sweepLegendHtml() {
    let html = '<div class="adcrd-sweep-legend">';
    for (let adc = 0; adc < 12; adc += 1) {
      const color = ADC_COLORS[adc % ADC_COLORS.length];
      const selected = adc === selectedAdc ? ' is-selected' : '';
      html += '<button type="button" class="' + selected.trim() + '" data-adc="' + adc +
        '" style="color:' + color + '">ADC ' + adc + '</button>';
    }
    return html + '</div>';
  }

  function bindBracketDrag(svg) {
    if (!svg) return;
    const L = Number(svg.dataset.l);
    const iw = Number(svg.dataset.iw);
    let dragging = false;
    let grabOffset = 0;

    function clientToBcr(clientX) {
      const rect = svg.getBoundingClientRect();
      const vbW = svg.viewBox.baseVal.width || 960;
      const px = ((clientX - rect.left) / Math.max(1, rect.width)) * vbW;
      const frac = Math.max(0, Math.min(1, (px - L) / Math.max(1, iw)));
      return frac * BCR_MAX;
    }

    function onDown(ev) {
      const t = ev.target;
      const isBracket = t && (
        t.getAttribute('data-role') === 'move' ||
        (t.classList && t.classList.contains('adcrd-bracket'))
      );
      if (!isBracket) return;
      ev.preventDefault();
      svg.setPointerCapture(ev.pointerId);
      dragging = true;
      svg.classList.add('is-dragging');
      grabOffset = clientToBcr(ev.clientX) - bracketStart;
    }

    function onMove(ev) {
      if (!dragging) return;
      clampBracket(clientToBcr(ev.clientX) - grabOffset);
      // Live-update bracket geometry without full re-render.
      const n = selectedSamples();
      const x0 = L + (bracketStart / BCR_MAX) * iw;
      const x1 = L + ((bracketStart + n - 1) / BCR_MAX) * iw;
      const bracket = svg.querySelector('#adcrdBracket');
      if (bracket) {
        bracket.setAttribute('x', x0);
        bracket.setAttribute('width', Math.max(4, x1 - x0));
      }
    }

    function onUp() {
      if (!dragging) return;
      dragging = false;
      svg.classList.remove('is-dragging');
      savePrefs();
      renderLayout({ skipRecord: true });
    }

    svg.addEventListener('pointerdown', onDown);
    svg.addEventListener('pointermove', onMove);
    svg.addEventListener('pointerup', onUp);
    svg.addEventListener('pointercancel', onUp);
  }

  function renderPreview() {
    const preview = document.getElementById('adcrdSweepPreview');
    if (!preview) return;
    const gain = sweepGain();
    preview.innerHTML =
      '<div class="adcrd-sweep-preview-head">' +
      '<h3>BCR window preview · MD ' + (currentMd + 1) + ' · 0–' + BCR_MAX + '</h3>' +
      '<label class="adcrd-full-all"><input id="adcrdPreviewAll" type="checkbox"' +
      (showPreviewAllTraces() ? ' checked' : '') +
      '/> All traces</label>' +
      '<span class="adcrd-preview-meta">' + gain.toUpperCase() + ' · ' +
      sweep.filled + '/' + (BCR_MAX + 1) + ' filled · bracket ' +
      bracketStart + '–' + bracketEnd() +
      (sweep.lastRange
        ? (' · last L1A ' + sweep.lastRange.l1a + ' → ' +
          sweep.lastRange.from + '–' + sweep.lastRange.to)
        : '') +
      '</span></div>' +
      previewPlotSvg() +
      sweepLegendHtml();

    const allEl = document.getElementById('adcrdPreviewAll');
    if (allEl) {
      allEl.addEventListener('change', function () {
        previewAllTraces = !!allEl.checked;
        savePrefs();
        renderPreview();
      });
    }
    preview.querySelectorAll('[data-adc]').forEach(function (el) {
      el.addEventListener('click', function (ev) {
        ev.preventDefault();
        selectAdc(el.getAttribute('data-adc'));
      });
    });
    bindBracketDrag(document.getElementById('adcrdPreviewSvg'));
  }

  function renderFullWindow() {
    const plot = document.getElementById('adcrdFullPlot');
    const meta = document.getElementById('adcrdFullMeta');
    if (!plot) return;
    const gain = sweepGain();
    if (!window.Plotly) {
      plot.innerHTML = '<p class="empty">Plotly failed to load — check network / CDN.</p>';
      return;
    }
    const traces = buildPlotlyTraces(gain);
    const layout = plotlyLayout(gain);
    const config = plotlyConfig();
    layout.height = Math.min(560, Math.max(400, Math.floor(window.innerHeight * 0.62)));
    const draw = plot.data
      ? Plotly.react(plot, traces, layout, config)
      : Plotly.newPlot(plot, traces, layout, config);
    Promise.resolve(draw).then(function () {
      if (!plot._adcrdClickBound) {
        plot._adcrdClickBound = true;
        plot.on('plotly_click', function (ev) {
          if (!ev || !ev.points || !ev.points.length) return;
          const name = ev.points[0].data && ev.points[0].data.name;
          const match = String(name || '').match(/ADC\s+(\d+)/i);
          if (match) selectAdc(match[1]);
        });
      }
      Plotly.Plots.resize(plot);
    });
    if (meta) {
      meta.textContent = sweep.filled + '/' + (BCR_MAX + 1) + ' filled · Y 0–' + Y_MAX +
        ' · ' + gain.toUpperCase() +
        (showAllTraces() ? ' · all traces' : (' · ADC ' + selectedAdc)) +
        ' · bracket ' + bracketStart + '–' + bracketEnd();
    }
  }

  function openFullWindow() {
    const overlay = document.getElementById('adcrdFullOverlay');
    if (!overlay) return;
    overlay.classList.remove('hidden');
    overlay.setAttribute('aria-hidden', 'false');
    renderFullWindow();
  }

  function closeFullWindow() {
    const overlay = document.getElementById('adcrdFullOverlay');
    if (!overlay) return;
    overlay.classList.add('hidden');
    overlay.setAttribute('aria-hidden', 'true');
  }

  function setSweepUi(running) {
    sweepRunning = running;
    const start = document.getElementById('adcrdSweepStart');
    const stop = document.getElementById('adcrdSweepStop');
    const progress = document.getElementById('adcrdSweepProgress');
    if (start) start.disabled = running;
    if (stop) stop.disabled = !running;
    if (progress) progress.classList.toggle('run', running);
  }

  function setProgress(text) {
    const progress = document.getElementById('adcrdSweepProgress');
    if (progress) progress.textContent = text || '';
  }

  function bindChannelClicks(root) {
    if (!root) return;
    root.querySelectorAll('.adcrd-plot[data-adc]').forEach(function (el) {
      el.addEventListener('click', function () {
        selectAdc(el.getAttribute('data-adc'));
      });
    });
  }

  function syncInjectFlag(inject) {
    const el = document.getElementById('adcrdInjectActive');
    if (!el) return;
    if (!inject) {
      el.textContent = 'inject active: —';
      el.classList.remove('on');
      return;
    }
    const parts = ['A', 'B'].map(function (sideId) {
      const row = inject[sideId] || {};
      const word = row.word_active == null ? '' : (' 0x' + Number(row.word_active).toString(16).toUpperCase());
      return sideId + (row.active ? ' active' : ' idle') + word;
    });
    el.textContent = parts.join(' · ');
    el.classList.toggle('on', !!(inject.A && inject.A.active) || !!(inject.B && inject.B.active));
  }

  function renderLayout(opts) {
    const wrap = document.getElementById('wrap-tilecal_data_readout');
    if (!wrap) return;
    clampBracket(bracketStart);
    lastCsv = buildCsv();

    const modeNote = bitMode() === 12
      ? '12-bit shows the pipeline word (0–4095).'
      : '14-bit places that 12-bit word in bits 13:2.';
    let html = '<p class="adcrd-legend">' +
      '<strong>MD ' + (currentMd + 1) + '</strong> · ' +
      'Channel plots show the N samples under the preview bracket (BCR ' +
      bracketStart + '–' + bracketEnd() + '). ' +
      'L1A at BCR maps sample[i] → window BCR (BCR−N+i). ' +
      'Drag the blue bracket to change which window feeds the subplots. ' +
      'Each mini-drawer keeps its own window and options. ' +
      modeNote +
      '</p>';
    if (lastData) syncInjectFlag(lastData.inject);
    else syncInjectFlag(null);

    ['A', 'B'].forEach(function (sideId) {
      const channels = channelsForSide(sideId);
      html += '<h3 class="adcrd-side-head side-' + sideId.toLowerCase() + '">Side ' + sideId + '</h3>';
      html += dualGainGrid(sideId, channels);
      html += renderTable('lg', channels);
      html += renderTable('hg', channels);
    });
    wrap.innerHTML = html;
    bindChannelClicks(wrap);
    renderPreview();
    const full = document.getElementById('adcrdFullOverlay');
    if (full && !full.classList.contains('hidden')) renderFullWindow();

    const hint = document.getElementById('status-tilecal_data_readout');
    if (hint) {
      hint.textContent = selectedSamples() + ' samples · ' + bitMode() + '-bit · ADC ' +
        selectedAdc + ' · window ' + sweep.filled + '/' + (BCR_MAX + 1) +
        ' · bracket ' + bracketStart + '–' + bracketEnd();
      hint.classList.add('ok');
    }
  }

  function render(data, opts) {
    if (!data) {
      renderLayout(opts);
      stashMdState(currentMd);
      return;
    }
    lastData = data;
    if (!(opts && opts.skipRecord)) recordReadout(data);
    const t = document.getElementById('time-tilecal_data_readout');
    if (t) t.textContent = 'Updated ' + new Date().toLocaleTimeString();
    renderLayout(opts);
    stashMdState(currentMd);
  }

  async function setInject() {
    const enable = document.getElementById('adcrdInjectEnable').checked;
    const side = document.getElementById('adcrdInjectSide').value;
    const j = await HWMonitor.fetchJson('/api/plugins/tilecal_data_readout/inject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ side: side, enable: enable }),
    });
    syncInjectFlag(j.inject);
    const where = side === 'both' ? 'side A and side B' : ('side ' + side);
    HWMonitor.setStatus((enable ? 'Inject enabled' : 'Inject disabled') + ' on ' + where);
  }

  async function fetchPipeline(bcr) {
    const samples = document.getElementById('adcrdSamples').value;
    const params = new URLSearchParams({ samples: samples, bcr: String(bcr) });
    return HWMonitor.fetchJson('/api/plugins/tilecal_data_readout/data?' + params.toString());
  }

  async function refresh() {
    if (!HWMonitor.state.connected) return;
    if (sweepRunning) throw new Error('BCR sweep is running — stop it first');
    syncBcrLimits();
    const bcr = clampBcr(document.getElementById('adcrdBcr').value);
    document.getElementById('adcrdBcr').value = String(bcr);
    const j = await fetchPipeline(bcr);
    render(j);
  }

  async function runSweep() {
    if (!HWMonitor.state.connected) {
      HWMonitor.setStatus('Connect before sweeping BCR', true);
      return;
    }
    if (sweepRunning) return;
    syncBcrLimits();
    const fromEl = document.getElementById('adcrdSweepFrom');
    const toEl = document.getElementById('adcrdSweepTo');
    const stepEl = document.getElementById('adcrdSweepStep');
    let from = clampBcr(Number(fromEl && fromEl.value));
    let to = clampBcr(Number(toEl && toEl.value));
    let step = Math.max(1, Math.min(BCR_MAX, Math.floor(Number(stepEl && stepEl.value) || 16)));
    if (from > to) {
      const tmp = from;
      from = to;
      to = tmp;
    }
    if (fromEl) fromEl.value = String(from);
    if (toEl) toEl.value = String(to);
    if (stepEl) stepEl.value = String(step);

    const points = [];
    for (let bcr = from; bcr <= to; bcr += step) points.push(bcr);
    if (!points.length) {
      HWMonitor.setStatus('Empty BCR sweep range', true);
      return;
    }

    sweepAbort = false;
    setSweepUi(true);
    HWMonitor.setStatus('Sweeping BCR ' + from + ' → ' + to + ' (step ' + step + ')…');
    try {
      for (let i = 0; i < points.length; i += 1) {
        if (sweepAbort) break;
        const bcr = points[i];
        const bcrInput = document.getElementById('adcrdBcr');
        if (bcrInput) bcrInput.value = String(bcr);
        setProgress('BCR ' + bcr + ' · ' + (i + 1) + '/' + points.length +
          ' · window ' + sweep.filled + '/' + (BCR_MAX + 1));
        const j = await fetchPipeline(bcr);
        render(j);
        await new Promise(function (resolve) { setTimeout(resolve, 0); });
      }
      const done = sweepAbort ? 'stopped' : 'done';
      setProgress(done + ' · ' + sweep.filled + ' BCR filled');
      HWMonitor.setStatus(
        'BCR sweep ' + done + ': window now ' + sweep.filled + '/' + (BCR_MAX + 1)
      );
    } catch (err) {
      setProgress('error');
      HWMonitor.setStatus('BCR sweep: ' + (err.message || err), true);
    } finally {
      setSweepUi(false);
      renderLayout({ skipRecord: true });
    }
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_data_readout'],
    refresh: refresh,
    refreshLabel: 'Triggering the PPr at the BCR, then reading both sides…',
    onInit() {
      currentMd = activeMd();
      loadMdState(currentMd);
      renderLayout({ skipRecord: true });
      savePrefs();

      const samplesEl = document.getElementById('adcrdSamples');
      if (samplesEl) {
        samplesEl.addEventListener('change', function () {
          syncBcrLimits();
          const stepEl = document.getElementById('adcrdSweepStep');
          if (stepEl) stepEl.value = String(selectedSamples());
          clampBracket(bracketStart);
          savePrefs();
          renderLayout({ skipRecord: true });
        });
      }
      ['adcrdBcr', 'adcrdSweepFrom', 'adcrdSweepTo', 'adcrdSweepStep'].forEach(function (id) {
        const el = document.getElementById(id);
        if (!el) return;
        el.addEventListener('change', function () {
          syncBcrLimits();
          if (id !== 'adcrdSweepStep') el.value = String(clampBcr(el.value));
          savePrefs();
        });
      });
      const sideEl = document.getElementById('adcrdInjectSide');
      if (sideEl) {
        sideEl.addEventListener('change', function () { savePrefs(); });
      }
      const modeEl = document.getElementById('adcrdBitMode');
      if (modeEl) {
        modeEl.addEventListener('change', function () {
          savePrefs();
          renderLayout({ skipRecord: true });
        });
      }
      const gainEl = document.getElementById('adcrdSweepGain');
      if (gainEl) {
        gainEl.addEventListener('change', function () {
          savePrefs();
          renderLayout({ skipRecord: true });
        });
      }
      const injEl = document.getElementById('adcrdInjectEnable');
      if (injEl) {
        injEl.addEventListener('change', function () {
          HWMonitor.withBusy('Setting inject enable…', setInject).catch(function (err) {
            injEl.checked = !injEl.checked;
            HWMonitor.setStatus(String(err), true);
          });
        });
      }
      const csvBtn = document.getElementById('adcrdCopyCsv');
      if (csvBtn) {
        csvBtn.addEventListener('click', function () {
          navigator.clipboard.writeText(lastCsv || buildCsv()).then(function () {
            HWMonitor.setStatus('ADC readout CSV copied');
          });
        });
      }
      const startBtn = document.getElementById('adcrdSweepStart');
      if (startBtn) startBtn.addEventListener('click', function () { runSweep(); });
      const stopBtn = document.getElementById('adcrdSweepStop');
      if (stopBtn) {
        stopBtn.addEventListener('click', function () {
          sweepAbort = true;
          setProgress('stopping…');
        });
      }
      const showBtn = document.getElementById('adcrdShowFull');
      if (showBtn) showBtn.addEventListener('click', openFullWindow);
      const clearBtn = document.getElementById('adcrdClearWindow');
      if (clearBtn) clearBtn.addEventListener('click', clearWindow);
      const closeBtn = document.getElementById('adcrdFullClose');
      if (closeBtn) closeBtn.addEventListener('click', closeFullWindow);
      const restoreBtn = document.getElementById('adcrdRestoreView');
      if (restoreBtn) restoreBtn.addEventListener('click', restoreView);
      const allEl = document.getElementById('adcrdAllTraces');
      if (allEl) {
        allEl.addEventListener('change', function () {
          savePrefs();
          const full = document.getElementById('adcrdFullOverlay');
          if (full && !full.classList.contains('hidden')) renderFullWindow();
        });
      }
      const overlay = document.getElementById('adcrdFullOverlay');
      if (overlay) {
        overlay.addEventListener('click', function (ev) {
          if (ev.target === overlay) closeFullWindow();
        });
      }
    },
    onMdChange(md) {
      switchToMd(md);
    },
    onConnect() {
      loadMdState(activeMd());
      renderLayout({ skipRecord: true });
    },
    onDisconnect() {
      sweepAbort = true;
      sweepRunning = false;
      stashMdState(currentMd);
      closeFullWindow();
      setSweepUi(false);
      setProgress('');
      // Keep mdCache; show an empty page until reconnect restores it.
      lastCsv = '';
      lastData = null;
      sweep = emptySweep();
      view = defaultView();
      renderLayout({ skipRecord: true });
      const hint = document.getElementById('status-tilecal_data_readout');
      if (hint) hint.textContent = 'Disconnected · MD ' + (currentMd + 1);
    },
  });
})();
