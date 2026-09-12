(function () {
  const ID = 'sfp_ddm';
  const HIST_MAX = 120;
  const PLOT_COLORS = [
    '#f0b429', '#4f8cff', '#3ecf8e', '#ff6b6b', '#5eead4', '#fdba74',
    '#c084fc', '#f472b6', '#a3e635', '#38bdf8', '#fb923c', '#e879f9',
  ];
  const PLOT_GROUPS = {
    temp: ['temperature', 'laser_temperature'],
    volt: ['vcc'],
    current: ['tx_bias_current', 'tec_current'],
  };

  let lastValues = {};
  let charts = { temp: null, volt: null, current: null };
  let hist = { temp: {}, volt: {}, current: {} };
  let legendFilter = { temp: null, volt: null, current: null };

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function seriesLabel(side, rowLabel) {
    return 'SFP+' + side + ' ' + rowLabel;
  }

  function plotValue(fieldId, cell) {
    if (!cell || cell.value == null || Number.isNaN(cell.value)) return null;
    if (fieldId === 'tx_bias_current') return cell.value * 1e3;
    return cell.value;
  }

  function plotUnit(chartKey) {
    if (chartKey === 'temp') return '°C';
    if (chartKey === 'volt') return 'V';
    return 'mA';
  }

  function axisStyle() {
    return { muted: '#8b9bb4', grid: '#2a3654' };
  }

  function timeScale() {
    const { muted, grid } = axisStyle();
    return {
      type: 'time',
      time: {
        displayFormats: { second: 'HH:mm:ss', minute: 'HH:mm:ss', hour: 'HH:mm' },
        tooltipFormat: 'HH:mm:ss',
      },
      title: { display: true, text: 'Time', color: muted, font: { size: 10 } },
      ticks: { color: muted, maxTicksLimit: 8, font: { size: 9 }, autoSkip: true },
      grid: { color: grid },
    };
  }

  function chartOptions(yLabel) {
    const { muted, grid } = axisStyle();
    return {
      responsive: true,
      maintainAspectRatio: false,
      animation: false,
      interaction: { mode: 'nearest', intersect: false },
      scales: {
        x: timeScale(),
        y: {
          title: { display: true, text: yLabel, color: muted, font: { size: 10 } },
          ticks: { color: muted, font: { size: 9 } },
          grid: { color: grid },
        },
      },
      plugins: {
        legend: {
          display: true,
          position: 'bottom',
          labels: { color: muted, boxWidth: 10, font: { size: 9 }, padding: 4 },
        },
        tooltip: {
          callbacks: {
            title(items) {
              if (!items.length) return '';
              return new Date(items[0].parsed.x).toLocaleTimeString();
            },
            label(ctx) {
              return ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(3) + ' ' + yLabel;
            },
          },
        },
      },
    };
  }

  function destroyCharts() {
    for (const key of ['temp', 'volt', 'current']) {
      if (charts[key]) {
        charts[key].destroy();
        charts[key] = null;
      }
    }
  }

  function resetPlots() {
    hist = { temp: {}, volt: {}, current: {} };
    legendFilter = { temp: null, volt: null, current: null };
    destroyCharts();
  }

  function applyLegendFilter(chart, key) {
    if (!chart) return;
    const filter = legendFilter[key];
    chart.data.datasets.forEach(ds => {
      ds.hidden = filter !== null && ds.label !== filter;
    });
  }

  function bindLegendIsolate(chart, key) {
    if (!chart || chart._legendIsolateBound) return;
    chart._legendIsolateBound = true;
    chart.canvas.addEventListener('dblclick', (evt) => {
      const legend = chart.legend;
      if (!legend || !legend.legendHitBoxes) return;
      const rect = chart.canvas.getBoundingClientRect();
      const x = evt.clientX - rect.left;
      const y = evt.clientY - rect.top;
      let hitLabel = null;
      legend.legendHitBoxes.forEach((box, i) => {
        if (x >= box.left && x <= box.left + box.width && y >= box.top && y <= box.top + box.height) {
          const item = legend.legendItems[i];
          if (item) hitLabel = item.text;
        }
      });
      if (!hitLabel) return;
      legendFilter[key] = legendFilter[key] === hitLabel ? null : hitLabel;
      applyLegendFilter(chart, key);
      chart.update('none');
    });
  }

  function ensureCharts() {
    if (typeof Chart === 'undefined') return;
    const specs = [
      ['temp', 'sfpTempChart'],
      ['volt', 'sfpVoltChart'],
      ['current', 'sfpCurrentChart'],
    ];
    for (const [key, canvasId] of specs) {
      if (charts[key]) continue;
      const ctx = document.getElementById(canvasId);
      if (!ctx) continue;
      charts[key] = new Chart(ctx, {
        type: 'line',
        data: { datasets: [] },
        options: chartOptions(plotUnit(key)),
      });
      bindLegendIsolate(charts[key], key);
    }
  }

  function appendHistory(table) {
    const ts = Date.now();
    for (const row of table.rows || []) {
      for (const chartKey of Object.keys(PLOT_GROUPS)) {
        if (!PLOT_GROUPS[chartKey].includes(row.field_id)) continue;
        for (const side of ['0', '1']) {
          const cell = row.sides[side];
          const y = plotValue(row.field_id, cell);
          if (y == null) continue;
          const label = seriesLabel(side, row.label);
          if (!hist[chartKey][label]) hist[chartKey][label] = [];
          hist[chartKey][label].push({ x: ts, y });
          if (hist[chartKey][label].length > HIST_MAX) hist[chartKey][label].shift();
        }
      }
    }
  }

  function syncChart(chartKey) {
    const chart = charts[chartKey];
    if (!chart) return;
    const bucket = hist[chartKey];
    const labels = Object.keys(bucket).sort();
    chart.data.datasets = labels.map((label, idx) => {
      const color = PLOT_COLORS[idx % PLOT_COLORS.length];
      return {
        label,
        data: bucket[label] || [],
        borderColor: color,
        backgroundColor: color + '33',
        borderWidth: 1.5,
        pointRadius: 0,
        pointHitRadius: 6,
        tension: 0.15,
        fill: false,
      };
    });
    applyLegendFilter(chart, chartKey);
    chart.update('none');
  }

  function updateCharts() {
    ensureCharts();
    for (const key of ['temp', 'volt', 'current']) syncChart(key);
  }

  function renderStatus(table) {
    const el = document.getElementById('status-sfp_ddm');
    if (!el || !table) {
      if (el) el.textContent = '';
      return;
    }
    const text = table.found_probes + ' / ' + table.expected_probes + ' DDM probes';
    el.textContent = text;
    el.classList.toggle('warn', !table.complete);
  }

  function renderTable(table) {
    const wrap = document.getElementById('sfp-table-wrap');
    if (!wrap) return;
    if (!table || !table.rows || !table.rows.length) {
      wrap.innerHTML = '<p class="empty">No SFP+ DDM data returned.</p>';
      renderStatus(null);
      resetPlots();
      return;
    }

    appendHistory(table);

    let html = '<p class="sfp-legend">' +
      'SFF-8472 A2h diagnostics from <code>s_sfp_interface[ddm]</code> VIO probes. ' +
      'Configure probe names in ⚙ → Probe mapping…. ' +
      'Calibrated values follow vendor DDM encoding (temp 1/256 °C, VCC 100 µV/LSB, bias 2 µA/LSB, optical 0.1 µW/LSB).</p>';

    html += '<table class="data sfp-ddm"><tr>' +
      '<th>Parameter</th>' +
      '<th class="num">SFP+ 0 raw</th><th class="num">SFP+ 0 value</th>' +
      '<th class="num">SFP+ 1 raw</th><th class="num">SFP+ 1 value</th>' +
      '</tr>';

    for (const row of table.rows) {
      html += '<tr><td colspan="5" class="group"><strong>' + esc(row.label) + '</strong> — ' +
        esc(row.spec) + '</td></tr>';

      const keyBase = row.field_id;
      const s0 = row.sides['0'];
      const s1 = row.sides['1'];
      const changed0 = lastValues[keyBase + '|0'] !== undefined &&
        lastValues[keyBase + '|0'] !== (s0 && s0.raw_hex);
      const changed1 = lastValues[keyBase + '|1'] !== undefined &&
        lastValues[keyBase + '|1'] !== (s1 && s1.raw_hex);
      if (s0) lastValues[keyBase + '|0'] = s0.raw_hex;
      if (s1) lastValues[keyBase + '|1'] = s1.raw_hex;

      const missing0 = !s0 || s0.probe == null;
      const missing1 = !s1 || s1.probe == null;

      html += '<tr class="' +
        ((missing0 && missing1) ? 'missing ' : '') +
        ((changed0 || changed1) ? 'val-changed' : '') + '">' +
        '<td>' + esc(row.label) + '</td>' +
        '<td class="num">' + esc((s0 && s0.raw_hex) || '—') + '</td>' +
        '<td class="num value-col">' + esc((s0 && s0.value_text) || '—') + '</td>' +
        '<td class="num">' + esc((s1 && s1.raw_hex) || '—') + '</td>' +
        '<td class="num value-col">' + esc((s1 && s1.value_text) || '—') + '</td>' +
        '</tr>';

      if (!missing0 || !missing1) {
        html += '<tr class="probe-row"><td></td>' +
          '<td colspan="2" class="probe-name">' +
          esc(missing0 ? 'probe not found' : s0.probe) + '</td>' +
          '<td colspan="2" class="probe-name">' +
          esc(missing1 ? 'probe not found' : s1.probe) + '</td></tr>';
      }
    }
    html += '</table>';

    if (table.unmatched_probes && table.unmatched_probes.length) {
      html += '<details class="sfp-unmatched"><summary>' +
        table.unmatched_probes.length + ' unmatched ddm probe(s)</summary><ul>';
      for (const p of table.unmatched_probes) {
        html += '<li class="probe-name">' + esc(p.probe) + ' = ' + esc(p.value) + '</li>';
      }
      html += '</ul></details>';
    }

    wrap.innerHTML = html;
    renderStatus(table);
    updateCharts();
  }

  async function refresh() {
    if (!HWMonitor.state.targetOpen) return;
    try {
      const r = await fetch('/api/plugins/sfp_ddm/data' + HWMonitor.deviceQuery());
      const ctype = r.headers.get('content-type') || '';
      if (!r.ok || !ctype.includes('json')) {
        throw new Error('API returned HTTP ' + r.status);
      }
      const j = await r.json();
      const timeEl = document.getElementById('time-sfp_ddm');
      if (timeEl) {
        timeEl.textContent = 'Updated ' + new Date().toLocaleTimeString();
      }
      renderTable(j.table);
    } catch (e) {
      HWMonitor.setStatus('TileCal SFP+ DDM refresh error: ' + e, true);
    }
  }

  function onDisconnect() {
    lastValues = {};
    resetPlots();
    renderStatus(null);
    const wrap = document.getElementById('sfp-table-wrap');
    if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
  }

  function onDeviceChange() {
    lastValues = {};
    resetPlots();
  }

  function onTabActivate() {
    requestAnimationFrame(() => {
      for (const key of ['temp', 'volt', 'current']) {
        if (charts[key]) charts[key].resize();
      }
    });
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['sfp_ddm'],
    onInit() {},
    refresh,
    onDisconnect,
    onDeviceChange,
    onTabActivate,
  });
})();
